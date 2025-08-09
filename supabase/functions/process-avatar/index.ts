import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface AvatarRequest {
  user_id: string
  child_id: string
  photo_base64: string
  prompt?: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { user_id, child_id, photo_base64, prompt }: AvatarRequest = await req.json()
    
    // Validate required fields
    if (!user_id || !child_id || !photo_base64) {
      throw new Error('Missing required fields: user_id, child_id, photo_base64')
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

    // 2. Check rate limiting
    const { data: recentGenerations } = await supabase
      .from('gem_transactions')
      .select('created_at')
      .eq('user_id', user_id)
      .eq('type', 'avatar')
      .gte('created_at', new Date(Date.now() - 60 * 60 * 1000).toISOString()) // Last hour

    if (recentGenerations && recentGenerations.length >= 5) {
      throw new Error('Rate limit exceeded. Maximum 5 avatar generations per hour.')
    }

    // 3. Check if user has enough gems
    const { data: user } = await supabase
      .from('users')
      .select('gem_balance')
      .eq('id', user_id)
      .single()

    const avatarCost = 20
    if (!user || user.gem_balance < avatarCost) {
      throw new Error('Insufficient gems. Avatar generation costs 20 gems.')
    }

    // 4. Content moderation check
    console.log('Starting content moderation...')
    const moderationResult = await moderateImage(photo_base64)
    if (!moderationResult.safe) {
      throw new Error(`Content moderation failed: ${moderationResult.reason}`)
    }

    // 5. Generate avatar using OpenAI
    console.log('Starting avatar generation...')
    const avatarUrl = await generateAvatar(photo_base64, prompt || getDefaultPrompt())

    // 6. Upload avatar to Supabase Storage
    console.log('Uploading avatar to storage...')
    const storedAvatarUrl = await uploadAvatarToStorage(supabase, user_id, child_id, avatarUrl)

    // 7. Deduct gems atomically
    console.log('Processing payment...')
    await supabase.rpc('update_gem_balance', {
      p_user_id: user_id,
      p_amount: -avatarCost,
      p_type: 'avatar',
      p_description: `Avatar generation for ${child.name}`,
      p_reference_id: child_id
    })

    // 8. Update child record with new avatar
    await supabase
      .from('children')
      .update({
        avatar_url: storedAvatarUrl,
        avatar_cached: true,
        avatar_generated_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', child_id)

    // 9. Log analytics event
    await supabase
      .from('analytics_events')
      .insert({
        user_id,
        event_name: 'avatar_generated',
        properties: {
          child_id,
          child_name: child.name,
          generation_cost: avatarCost
        }
      })

    return new Response(JSON.stringify({
      success: true,
      avatar_url: storedAvatarUrl,
      gems_remaining: user.gem_balance - avatarCost,
      message: 'Avatar generated successfully!'
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('Avatar generation error:', error)
    
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})

async function moderateImage(base64Image: string): Promise<{ safe: boolean; reason?: string }> {
  try {
    const openaiKey = Deno.env.get('OPENAI_API_KEY')
    if (!openaiKey) {
      throw new Error('OpenAI API key not configured')
    }

    const response = await fetch('https://api.openai.com/v1/moderations', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        input: base64Image,
        model: 'text-moderation-latest'
      }),
    })

    const result = await response.json()
    
    if (!response.ok) {
      throw new Error(`Moderation API error: ${result.error?.message || 'Unknown error'}`)
    }

    const moderation = result.results[0]
    if (moderation.flagged) {
      const flaggedCategories = Object.keys(moderation.categories)
        .filter(key => moderation.categories[key])
        .join(', ')
      
      return {
        safe: false,
        reason: `Content flagged for: ${flaggedCategories}`
      }
    }

    return { safe: true }
  } catch (error) {
    console.error('Moderation error:', error)
    // Be conservative - if moderation fails, consider it unsafe
    return {
      safe: false,
      reason: 'Content moderation service unavailable'
    }
  }
}

async function generateAvatar(base64Image: string, prompt: string): Promise<string> {
  const openaiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiKey) {
    throw new Error('OpenAI API key not configured')
  }

  // Step 1: Use GPT-4o Vision to analyze the image
  const visionResponse = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o',
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: `Analyze this child's photo and create a detailed description for generating a Cocomelon-style 3D cartoon avatar. Focus on:
- Hair color, style, and length
- Eye color and shape  
- Skin tone
- Facial features and expressions
- Any distinctive characteristics
- Gender presentation

Create a DALL-E prompt that will generate a cute, family-friendly 3D cartoon avatar in Cocomelon animation style based on this child's features.`
            },
            {
              type: 'image_url',
              image_url: {
                url: `data:image/jpeg;base64,${base64Image}`
              }
            }
          ]
        }
      ],
      max_tokens: 300
    }),
  })

  if (!visionResponse.ok) {
    const errorData = await visionResponse.json()
    throw new Error(`Vision API Error: ${errorData.error?.message || 'Unknown error'}`)
  }

  const visionData = await visionResponse.json()
  const childDescription = visionData.choices[0].message.content

  // Step 2: Use DALL-E 3 to generate the avatar
  const enhancedPrompt = `${prompt}

${childDescription}

Style requirements:
- 3D Cocomelon animation style
- Big expressive cartoon eyes
- Soft rounded features  
- Bright child-friendly colors
- Warm friendly smile
- Professional quality suitable for nursery rhyme videos
- No text or logos
- Clean white background`

  const imageResponse = await fetch('https://api.openai.com/v1/images/generations', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'dall-e-3',
      prompt: enhancedPrompt,
      n: 1,
      size: '1024x1024',
      response_format: 'url',
      quality: 'hd',
      style: 'vivid',
    }),
  })

  if (!imageResponse.ok) {
    const errorData = await imageResponse.json()
    throw new Error(`DALL-E API Error: ${errorData.error?.message || 'Unknown error'}`)
  }

  const imageData = await imageResponse.json()
  return imageData.data[0].url
}

async function uploadAvatarToStorage(
  supabase: any, 
  userId: string, 
  childId: string, 
  avatarUrl: string
): Promise<string> {
  try {
    // Download the generated image
    const imageResponse = await fetch(avatarUrl)
    if (!imageResponse.ok) {
      throw new Error('Failed to download generated avatar')
    }
    
    const imageBlob = await imageResponse.blob()
    const fileName = `${userId}/${childId}/avatar_${Date.now()}.png`

    // Upload to Supabase Storage
    const { data, error } = await supabase.storage
      .from('avatars')
      .upload(fileName, imageBlob, {
        cacheControl: '3600',
        upsert: true
      })

    if (error) {
      throw new Error(`Storage upload error: ${error.message}`)
    }

    // Get public URL
    const { data: publicUrlData } = supabase.storage
      .from('avatars')
      .getPublicUrl(fileName)

    return publicUrlData.publicUrl
  } catch (error) {
    console.error('Avatar upload error:', error)
    // Fallback to original URL if upload fails
    return avatarUrl
  }
}

function getDefaultPrompt(): string {
  return `Create a beautiful 3D cartoon avatar of a child in the style of Cocomelon nursery rhyme videos. The character should be:
- Adorable and child-friendly
- Have large, expressive cartoon eyes
- Soft, rounded facial features
- Bright, cheerful colors
- A warm, happy smile
- Clean and simple design suitable for animation`
} 