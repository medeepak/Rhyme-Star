import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface VideoRequest {
  user_id: string
  child_id: string
  rhyme_id: string
  avatar_url?: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { user_id, child_id, rhyme_id, avatar_url }: VideoRequest = await req.json()
    
    // Validate required fields
    if (!user_id || !child_id || !rhyme_id) {
      throw new Error('Missing required fields: user_id, child_id, rhyme_id')
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Verify user owns the child
    const { data: child, error: childError } = await supabase
      .from('children')
      .select('*')
      .eq('id', child_id)
      .eq('user_id', user_id)
      .single()

    if (childError || !child) {
      throw new Error('Child not found or access denied')
    }

    // 2. Get rhyme details
    const { data: rhyme, error: rhymeError } = await supabase
      .from('rhymes')
      .select('*')
      .eq('id', rhyme_id)
      .eq('is_active', true)
      .single()

    if (rhymeError || !rhyme) {
      throw new Error('Rhyme not found or inactive')
    }

    // 3. Check rate limiting
    const { data: recentVideos } = await supabase
      .from('videos')
      .select('created_at')
      .eq('user_id', user_id)
      .gte('created_at', new Date(Date.now() - 60 * 60 * 1000).toISOString()) // Last hour

    if (recentVideos && recentVideos.length >= 10) {
      throw new Error('Rate limit exceeded. Maximum 10 videos per hour.')
    }

    // 4. Check if user has enough gems
    const { data: user } = await supabase
      .from('users')
      .select('gem_balance')
      .eq('id', user_id)
      .single()

    if (!user || user.gem_balance < rhyme.gem_cost) {
      throw new Error(`Insufficient gems. This rhyme costs ${rhyme.gem_cost} gems.`)
    }

    // 5. Create video record and deduct gems atomically
    const { data: video, error: videoError } = await supabase
      .from('videos')
      .insert({
        user_id,
        child_id,
        rhyme_id,
        status: 'queued',
        progress_percentage: 0,
        current_stage: 'initializing',
        estimated_completion: new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString(), // 2 hours default
        runware_model: selectBestRunwareModel(rhyme),
        created_at: new Date().toISOString()
      })
      .select()
      .single()

    if (videoError) {
      throw new Error(`Failed to create video record: ${videoError.message}`)
    }

    // 6. Deduct gems atomically
    await supabase.rpc('update_gem_balance', {
      p_user_id: user_id,
      p_amount: -rhyme.gem_cost,
      p_type: 'video',
      p_description: `Video creation for "${rhyme.title}"`,
      p_reference_id: video.id
    })

    // 7. Add to job queue
    await supabase
      .from('video_jobs')
      .insert({
        video_id: video.id,
        priority: rhyme.is_premium ? 2 : 1,
        scheduled_at: new Date().toISOString()
      })

    // 8. Trigger background processing
    const processResult = await fetch(
      `${Deno.env.get('SUPABASE_URL')}/functions/v1/process-video`, 
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${Deno.env.get('SERVICE_ROLE_KEY')}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ 
          video_id: video.id, 
          avatar_url: avatar_url || child.avatar_url,
          priority: rhyme.is_premium ? 'high' : 'normal'
        })
      }
    )

    if (!processResult.ok) {
      console.warn('Failed to trigger background processing:', await processResult.text())
      // Don't fail the request, processing will be picked up by scheduler
    }

    // 9. Log analytics event
    await supabase
      .from('analytics_events')
      .insert({
        user_id,
        event_name: 'video_queued',
        properties: {
          child_id,
          rhyme_id,
          rhyme_title: rhyme.title,
          video_id: video.id,
          gem_cost: rhyme.gem_cost,
          is_premium: rhyme.is_premium
        }
      })

    return new Response(JSON.stringify({
      success: true,
      video_id: video.id,
      estimated_completion: video.estimated_completion,
      gems_remaining: user.gem_balance - rhyme.gem_cost,
      queue_position: await getQueuePosition(supabase, video.id),
      message: 'Video creation started! You will be notified when ready.'
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('Video queue error:', error)
    
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})

function selectBestRunwareModel(rhyme: any): string {
  // Choose the best model based on rhyme type and budget
  if (rhyme.is_premium) {
    // Premium rhymes get higher quality models
    return 'kling:2.1' // $0.92 - highest quality
  } else if (rhyme.duration_seconds > 45) {
    // Longer videos benefit from better models
    return 'pixverse:4.5' // $0.29 - good balance
  } else {
    // Standard rhymes use budget-friendly model
    return 'seedance:1.0' // $0.14 - most economical
  }
}

async function getQueuePosition(supabase: any, videoId: string): Promise<number> {
  try {
    const { data: queueData } = await supabase
      .from('video_jobs')
      .select('created_at')
      .in('status', ['pending', 'claimed'])
      .order('priority', { ascending: false })
      .order('created_at', { ascending: true })

    if (!queueData) return 1

    const { data: currentJob } = await supabase
      .from('video_jobs')
      .select('created_at')
      .eq('video_id', videoId)
      .single()

    if (!currentJob) return 1

    const position = queueData.findIndex(job => 
      job.created_at === currentJob.created_at
    ) + 1

    return Math.max(position, 1)
  } catch (error) {
    console.warn('Failed to calculate queue position:', error)
    return 1 // Default position
  }
} 