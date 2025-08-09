import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ProcessVideoRequest {
  video_id: string;
  avatar_url?: string;
  priority?: "high" | "normal";
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { video_id, avatar_url, priority }: ProcessVideoRequest = await req.json();

    if (!video_id) {
      return json({ success: false, error: "Missing video_id" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ success: false, error: "Missing SUPABASE_URL or SERVICE_ROLE_KEY" }, 500);
    }

    const runwareKey = Deno.env.get("RUNWARE_API_KEY");
    if (!runwareKey) {
      return json({ success: false, error: "RUNWARE_API_KEY not configured" }, 500);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Load video + rhyme info
    const { data: video, error: videoErr } = await supabase
      .from("videos")
      .select("id, user_id, child_id, rhyme_id, runware_model, status, current_stage")
      .eq("id", video_id)
      .single();
    if (videoErr || !video) {
      return json({ success: false, error: "Video not found" }, 404);
    }

    // Get avatar_url fallback from child if not provided
    let resolvedAvatarUrl = avatar_url;
    if (!resolvedAvatarUrl) {
      const { data: child } = await supabase
        .from("children")
        .select("avatar_url")
        .eq("id", video.child_id)
        .single();
      resolvedAvatarUrl = child?.avatar_url ?? undefined;
    }

    // Kick off Runware generation task
    // NOTE: Replace with the specific Runware API endpoint/payload for your chosen model.
    const model = video.runware_model || "seedance:1.0";

    const runwarePayload = {
      model,
      input: {
        // Minimal example: pass avatar and rhyme_id; your backend can expand scene composition logic later
        avatar_url: resolvedAvatarUrl,
        rhyme_id: video.rhyme_id,
        priority: priority ?? "normal",
      },
    };

    const runwareResp = await fetch("https://api.runware.ai/v1/tasks", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${runwareKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(runwarePayload),
    });

    if (!runwareResp.ok) {
      const errText = await runwareResp.text();
      await markVideoFailed(supabase, video_id, `Runware request failed: ${errText}`);
      return json({ success: false, error: "Runware task creation failed" }, 502);
    }

    const runwareData = await runwareResp.json();
    const taskUuid: string | undefined = runwareData?.task_uuid ?? runwareData?.id;

    // Update videos row with task UUID and move to processing
    await supabase
      .from("videos")
      .update({
        runware_task_uuid: taskUuid ?? null,
        status: "processing",
        current_stage: "starting",
        updated_at: new Date().toISOString(),
      })
      .eq("id", video_id);

    // Initial progress log (optional)
    await supabase.from("video_progress").insert({
      video_id,
      stage: "starting",
      progress_percentage: 1,
      message: "Runware task created",
    });

    return json({ success: true, video_id, runware_task_uuid: taskUuid });
  } catch (e) {
    return json({ success: false, error: String(e?.message ?? e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function markVideoFailed(supabase: any, videoId: string, message: string) {
  try {
    await supabase
      .from("videos")
      .update({
        status: "failed",
        current_stage: "error",
        updated_at: new Date().toISOString(),
      })
      .eq("id", videoId);

    await supabase.from("video_progress").insert({
      video_id: videoId,
      stage: "error",
      progress_percentage: 0,
      message,
    });
  } catch (_) {
    // Best-effort; avoid throwing from error handler
  }
} 