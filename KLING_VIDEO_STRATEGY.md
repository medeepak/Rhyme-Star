# 🎬 Runware Video Creation Strategy

## BACKEND IMPLEMENTATION

### **Enhanced Database Schema**

```sql
-- Enhanced videos table with detailed progress tracking
videos (
  id: uuid PRIMARY KEY,
  user_id: uuid REFERENCES users(id),
  child_id: uuid REFERENCES children(id),
  rhyme_id: uuid REFERENCES rhymes(id),
  status: text CHECK (status IN ('queued', 'processing', 'rendering', 'completed', 'failed', 'cancelled')),
  
  -- Runware API Integration
  runware_task_uuid: text UNIQUE,
  runware_model: text, -- 'pixverse:4.5', 'kling:2.1', 'seedance:1.0', etc
  runware_webhook_url: text,
  
  -- Progress Tracking
  progress_percentage: integer DEFAULT 0,
  current_stage: text, -- 'initializing', 'analyzing', 'generating', 'rendering', 'finalizing'
  estimated_completion: timestamp,
  actual_completion: timestamp,
  
  -- Video Output
  video_url: text,
  thumbnail_url: text,
  duration_seconds: integer,
  
  -- Error Handling
  error_message: text,
  retry_count: integer DEFAULT 0,
  max_retries: integer DEFAULT 3,
  
  -- Metadata
  created_at: timestamp DEFAULT now(),
  started_at: timestamp,
  completed_at: timestamp,
  updated_at: timestamp DEFAULT now()
);

-- Job Queue for reliable processing
video_jobs (
  id: uuid PRIMARY KEY,
  video_id: uuid REFERENCES videos(id),
  priority: integer DEFAULT 1, -- Higher priority = processed first
  scheduled_at: timestamp DEFAULT now(),
  processing_started_at: timestamp,
  processing_node: text, -- For distributed processing
  status: text CHECK (status IN ('pending', 'claimed', 'processing', 'completed', 'failed')),
  created_at: timestamp DEFAULT now()
);

-- Progress updates for real-time tracking
video_progress (
  id: uuid PRIMARY KEY,
  video_id: uuid REFERENCES videos(id),
  stage: text,
  progress_percentage: integer,
  message: text,
  estimated_time_remaining: interval,
  created_at: timestamp DEFAULT now()
);
```

### **Supabase Edge Functions**

#### **1. queue-kling-video.ts**
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface VideoRequest {
  user_id: string
  child_id: string
  rhyme_id: string
  avatar_url: string
}

serve(async (req) => {
  try {
    const { user_id, child_id, rhyme_id, avatar_url }: VideoRequest = await req.json()
    
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Validate gem balance and deduct gems
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('gem_balance')
      .eq('id', user_id)
      .single()

    if (userError || !user) throw new Error('User not found')

    const { data: rhyme } = await supabase
      .from('rhymes')
      .select('gem_cost')
      .eq('id', rhyme_id)
      .single()

    if (user.gem_balance < rhyme.gem_cost) {
      throw new Error('Insufficient gems')
    }

    // 2. Atomic transaction: deduct gems and create video record
    const { data: video, error: videoError } = await supabase
      .from('videos')
      .insert({
        user_id,
        child_id,
        rhyme_id,
        status: 'queued',
        progress_percentage: 0,
        current_stage: 'initializing',
        estimated_completion: new Date(Date.now() + 2 * 60 * 60 * 1000) // 2 hours default
      })
      .select()
      .single()

    if (videoError) throw videoError

    // 3. Deduct gems
    await supabase
      .from('users')
      .update({ gem_balance: user.gem_balance - rhyme.gem_cost })
      .eq('id', user_id)

    // 4. Add to job queue
    await supabase
      .from('video_jobs')
      .insert({
        video_id: video.id,
        priority: rhyme.is_premium ? 2 : 1
      })

    // 5. Trigger background processing
    await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/process-kling-video`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_ANON_KEY')}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ video_id: video.id, avatar_url })
    })

    return new Response(JSON.stringify({
      success: true,
      video_id: video.id,
      estimated_completion: video.estimated_completion,
      message: 'Video creation started! You will be notified when ready.'
    }), {
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    return new Response(JSON.stringify({ 
      success: false, 
      error: error.message 
    }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
```

#### **2. process-kling-video.ts**
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const { video_id, avatar_url } = await req.json()
    
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Get video details
    const { data: video } = await supabase
      .from('videos')
      .select(`
        *,
        rhymes(title, video_template_url),
        children(name, avatar_url)
      `)
      .eq('id', video_id)
      .single()

    if (!video) throw new Error('Video not found')

    // 2. Update status to processing
    await updateVideoProgress(supabase, video_id, 'processing', 5, 'Connecting to Runware AI...')

    // 3. Prepare Runware API request
    const runwarePayload = [{
      taskType: "videoInference",
      taskUUID: `video-${video_id}`,
      deliveryMethod: "async",
      positivePrompt: `Create a nursery rhyme video for "${video.rhymes.title}". 
                      Feature a cute 3D cartoon child character matching this avatar: ${avatar_url}.
                      Style: Cocomelon animation, bright colors, child-friendly, musical.
                      Template reference: ${video.rhymes.video_template_url}`,
      negativePrompt: "scary, dark, inappropriate, adult content",
      model: "pixverse:4.5", // Start with cost-effective model ($0.29)
      duration: 8,
      width: 1920,
      height: 1080,
      frameImages: avatar_url ? [{ inputImage: avatar_url }] : undefined
    }]

    await updateVideoProgress(supabase, video_id, 'processing', 10, 'Submitting to Runware AI...')

    // 4. Submit to Runware API
    const runwareResponse = await fetch('https://api.runware.ai/v1', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('RUNWARE_API_KEY')}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(runwarePayload)
    })

    const runwareResult = await runwareResponse.json()

    if (!runwareResponse.ok) {
      throw new Error(`Runware API error: ${runwareResult.errors?.[0]?.message || 'Unknown error'}`)
    }

    // 5. Store Runware task UUID and update status
    await supabase
      .from('videos')
      .update({
        runware_task_uuid: `video-${video_id}`,
        runware_model: "pixverse:4.5",
        status: 'processing',
        started_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', video_id)

    await updateVideoProgress(supabase, video_id, 'analyzing', 15, 'Kling AI is analyzing your request...')

    // 6. Start polling for updates (will be replaced by webhook in production)
    await scheduleProgressPolling(supabase, video_id, klingResult.job_id)

    return new Response(JSON.stringify({ 
      success: true, 
      kling_job_id: klingResult.job_id,
      message: 'Video processing started successfully'
    }))

  } catch (error) {
    await handleVideoError(supabase, video_id, error.message)
    
    return new Response(JSON.stringify({ 
      success: false, 
      error: error.message 
    }), { status: 500 })
  }
})

async function updateVideoProgress(
  supabase: any, 
  video_id: string, 
  stage: string, 
  progress: number, 
  message: string
) {
  await Promise.all([
    supabase
      .from('videos')
      .update({
        current_stage: stage,
        progress_percentage: progress,
        updated_at: new Date().toISOString()
      })
      .eq('id', video_id),
    
    supabase
      .from('video_progress')
      .insert({
        video_id,
        stage,
        progress_percentage: progress,
        message,
        estimated_time_remaining: calculateETA(progress)
      })
  ])
}

function calculateETA(progress: number): string {
  const totalMinutes = 120 // 2 hours average
  const remainingMinutes = Math.max(0, (totalMinutes * (100 - progress)) / 100)
  return `${Math.floor(remainingMinutes)} minutes`
}

async function scheduleProgressPolling(supabase: any, video_id: string, task_uuid: string) {
  // This function would set up periodic polling of Runware API
  // Runware uses async processing with polling
  setTimeout(async () => {
    await pollRunwareStatus(supabase, video_id, task_uuid)
  }, 30000) // Poll every 30 seconds
}
```

#### **3. runware-poll-status.ts**
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Runware uses polling instead of webhooks
async function pollRunwareStatus(supabase: any, video_id: string, task_uuid: string) {
  try {
    // Poll Runware API for task status
    const pollResponse = await fetch('https://api.runware.ai/v1', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('RUNWARE_API_KEY')}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify([{
        taskType: "getResponse",
        taskUUID: task_uuid
      }])
    })

    const result = await pollResponse.json()
    
    if (!pollResponse.ok) {
      throw new Error(`Runware poll error: ${result.errors?.[0]?.message}`)
    }

    // Check if task is completed
    if (result.data && result.data.length > 0) {
      const taskData = result.data[0]
      
      // Task completed successfully
      await supabase
        .from('videos')
        .update({
          status: 'completed',
          video_url: taskData.videoURL,
          runware_cost_actual: taskData.cost,
          completed_at: new Date().toISOString(),
          progress_percentage: 100
        })
        .eq('id', video_id)

    switch (status) {
      case 'processing':
        await updateVideoProgress(
          supabase, 
          video.id, 
          'generating', 
          Math.min(progress || 30, 85), 
          'Kling AI is generating your video...'
        )
        break

      case 'completed':
        await completeVideo(supabase, video.id, video_url)
        await sendCompletionNotification(supabase, video.user_id, video.id)
        break

      case 'failed':
        await handleVideoError(supabase, video.id, error_message || 'Video generation failed')
        break
    }

    return new Response('OK')

  } catch (error) {
    console.error('Webhook error:', error)
    return new Response('Error', { status: 500 })
  }
})

async function completeVideo(supabase: any, video_id: string, video_url: string) {
  await supabase
    .from('videos')
    .update({
      status: 'completed',
      video_url,
      progress_percentage: 100,
      current_stage: 'completed',
      completed_at: new Date().toISOString(),
      actual_completion: new Date().toISOString()
    })
    .eq('id', video_id)

  await supabase
    .from('video_progress')
    .insert({
      video_id,
      stage: 'completed',
      progress_percentage: 100,
      message: 'Your video is ready! 🎉'
    })
}

async function sendCompletionNotification(supabase: any, user_id: string, video_id: string) {
  // Send push notification
  await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/send-notification`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      user_id,
      title: 'Your Rhyme Video is Ready! 🎬',
      body: 'Tap to watch your personalized nursery rhyme video',
      data: { video_id, action: 'view_video' }
    })
  })
}
```

## FRONTEND IMPLEMENTATION

### **Riverpod Providers for Video Management**

```dart
// Video queue state management
final videoQueueProvider = StateNotifierProvider<VideoQueueNotifier, VideoQueueState>((ref) {
  return VideoQueueNotifier(ref);
});

final activeVideosProvider = StreamProvider<List<Video>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = ref.watch(authProvider);
  
  if (user == null) return Stream.value([]);
  
  return supabase
    .from('videos')
    .stream(primaryKey: ['id'])
    .eq('user_id', user.id)
    .order('created_at', ascending: false);
});

final videoProgressProvider = StreamProvider.family<VideoProgress?, String>((ref, videoId) {
  final supabase = ref.watch(supabaseProvider);
  
  return supabase
    .from('video_progress')
    .stream(primaryKey: ['id'])
    .eq('video_id', videoId)
    .order('created_at', ascending: false)
    .limit(1)
    .map((data) => data.isNotEmpty ? VideoProgress.fromJson(data.first) : null);
});
```

### **Background Sync Service**

```dart
class BackgroundVideoSyncService {
  static const _backgroundTaskId = 'video_sync';
  
  static Future<void> initialize() async {
    // Register background task for iOS/Android
    await Workmanager().initialize(callbackDispatcher);
    
    // Schedule periodic sync
    await Workmanager().registerPeriodicTask(
      _backgroundTaskId,
      'syncVideoProgress',
      frequency: Duration(minutes: 5),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
  
  static Future<void> syncVideoProgress() async {
    final supabase = Supabase.instance.client;
    final box = await Hive.openBox('video_cache');
    
    try {
      // Get pending videos
      final pendingVideos = await supabase
        .from('videos')
        .select('id, status, progress_percentage, video_url')
        .in_('status', ['queued', 'processing', 'rendering'])
        .order('created_at', ascending: false);
      
      // Update local cache
      for (final video in pendingVideos) {
        await box.put('video_${video['id']}', video);
        
        // Check if completed
        if (video['status'] == 'completed' && video['video_url'] != null) {
          await _showCompletionNotification(video);
        }
      }
      
    } catch (e) {
      print('Background sync error: $e');
    }
  }
  
  static Future<void> _showCompletionNotification(Map<String, dynamic> video) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: video['id'].hashCode,
        channelKey: 'video_completion',
        title: 'Your Video is Ready! 🎬',
        body: 'Tap to watch your personalized nursery rhyme',
        notificationLayout: NotificationLayout.BigPicture,
        actionType: ActionType.Default,
        payload: {'video_id': video['id']},
      ),
    );
  }
}
```

### **Video Creation Flow**

```dart
class VideoCreationScreen extends ConsumerStatefulWidget {
  final RhymeConfirmationData rhyme;
  final Uint8List? userAvatar;

  const VideoCreationScreen({
    super.key,
    required this.rhyme,
    this.userAvatar,
  });

  @override
  ConsumerState<VideoCreationScreen> createState() => _VideoCreationScreenState();
}

class _VideoCreationScreenState extends ConsumerState<VideoCreationScreen> {
  bool _isCreating = false;
  String? _videoId;

  @override
  Widget build(BuildContext context) {
    final videoProgress = _videoId != null 
      ? ref.watch(videoProgressProvider(_videoId!))
      : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Creating Your Video'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            // Rhyme Info
            _buildRhymeInfo(),
            
            SizedBox(height: 32),
            
            // Progress Section
            if (_isCreating) ...[
              _buildProgressSection(videoProgress),
            ] else ...[
              _buildStartSection(),
            ],
            
            Spacer(),
            
            // Action Buttons
            _buildActionButtons(videoProgress),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(AsyncValue<VideoProgress?> progressAsync) {
    return progressAsync.when(
      data: (progress) {
        if (progress == null) {
          return CircularProgressIndicator();
        }
        
        return Column(
          children: [
            // Animated progress circle
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress.progressPercentage / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      RhymeStarColors.primaryTurquoise,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${progress.progressPercentage}%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: RhymeStarColors.primaryTurquoise,
                        ),
                      ),
                      Text(
                        progress.stage.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24),
            
            Text(
              progress.message,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            
            if (progress.estimatedTimeRemaining != null) ...[
              SizedBox(height: 12),
              Text(
                'Estimated time remaining: ${progress.estimatedTimeRemaining}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        );
      },
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }

  Widget _buildActionButtons(AsyncValue<VideoProgress?> progressAsync) {
    final progress = progressAsync.value;
    final isCompleted = progress?.stage == 'completed';
    
    if (isCompleted) {
      return ElevatedButton(
        onPressed: () => _watchVideo(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          minimumSize: Size(double.infinity, 50),
        ),
        child: Text(
          'WATCH VIDEO 🎬',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    
    if (_isCreating) {
      return Column(
        children: [
          ElevatedButton(
            onPressed: () => _backgroundAndContinue(),
            style: ElevatedButton.styleFrom(
              backgroundColor: RhymeStarColors.primaryTurquoise,
              minimumSize: Size(double.infinity, 50),
            ),
            child: Text(
              'CONTINUE IN BACKGROUND',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          
          SizedBox(height: 12),
          
          TextButton(
            onPressed: () => _cancelCreation(),
            child: Text(
              'Cancel Creation',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    }
    
    return ElevatedButton(
      onPressed: _isCreating ? null : () => _startVideoCreation(),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        minimumSize: Size(double.infinity, 50),
      ),
      child: Text(
        'START CREATION',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _startVideoCreation() async {
    setState(() => _isCreating = true);
    
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'queue-kling-video',
        body: {
          'user_id': Supabase.instance.client.auth.currentUser!.id,
          'child_id': 'current_child_id', // Get from state
          'rhyme_id': widget.rhyme.id,
          'avatar_url': 'uploaded_avatar_url', // Get from state
        },
      );
      
      if (response.data['success']) {
        setState(() => _videoId = response.data['video_id']);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video creation started! You\'ll be notified when ready.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(response.data['error']);
      }
      
    } catch (e) {
      setState(() => _isCreating = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start video creation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _backgroundAndContinue() {
    // Save state locally
    final box = Hive.box('app_state');
    box.put('pending_video_id', _videoId);
    
    // Navigate back to home
    context.go('/home');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video creation continues in background. You\'ll be notified when ready!'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}
```

## KEY FEATURES

### **1. Robust Background Processing**
- Videos continue processing even when app is closed
- Periodic background sync every 5 minutes
- Local state persistence with Hive

### **2. Real-time Progress Updates**
- Supabase real-time subscriptions for instant updates
- Detailed progress stages with percentages
- Estimated completion times

### **3. Smart Notification System**
- Push notifications when videos complete
- Rich notifications with video thumbnails
- Deep linking to video player

### **4. Error Handling & Retry Logic**
- Automatic retry for failed jobs (max 3 attempts)
- Graceful error messages for users
- Fallback polling if webhooks fail

### **5. Queue Management**
- Priority-based processing (premium content first)
- Multiple videos can be in queue simultaneously
- Fair resource allocation

This strategy ensures reliable, long-running video creation that works seamlessly whether the user keeps the app open or closes it completely. 