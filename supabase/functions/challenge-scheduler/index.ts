// supabase/functions/challenge-scheduler/index.ts
// Cron job edge function: flips scheduled -> live at starts_at, and live -> closed at ends_at.
// Triggers notifications on status transitions.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req: Request) => {
  try {
    const now = new Date().toISOString();

    // 1. Flip scheduled -> live
    const { data: newlyLive, error: liveErr } = await supabase
      .from("leaderboard_challenges")
      .update({ status: "live" })
      .eq("status", "scheduled")
      .lte("starts_at", now)
      .select("id, title, audience, subject_id");

    if (liveErr) {
      console.error("Error flipping scheduled to live:", liveErr);
    } else if (newlyLive && newlyLive.length > 0) {
      console.log(`Flipped ${newlyLive.length} challenges to live`);

      for (const ch of newlyLive) {
        // Fetch subject details
        const { data: subject } = await supabase
          .from("subjects")
          .select("name")
          .eq("id", ch.subject_id)
          .single();

        const subjName = subject?.name ?? "Subject";
        const notifTitle = "🔥 Challenge is LIVE!";
        const notifBody = `${ch.title} (${subjName}) is now open. Test your skills and compete for the leaderboard!`;

        // Send broadcast or stream-targeted notification
        await supabase.from("notifications").insert({
          title: notifTitle,
          body: notifBody,
          type: "announcement",
          target_stream: ch.audience === "both" ? null : ch.audience,
          payload: {
            type: "challenge_live",
            challenge_id: ch.id,
          },
          is_read: false,
          created_at: new Date().toISOString(),
        });
      }
    }

    // 2. Flip live -> closed
    const { data: newlyClosed, error: closeErr } = await supabase
      .from("leaderboard_challenges")
      .update({ status: "closed" })
      .eq("status", "live")
      .lte("ends_at", now)
      .select("id, title, audience, subject_id");

    if (closeErr) {
      console.error("Error flipping live to closed:", closeErr);
    } else if (newlyClosed && newlyClosed.length > 0) {
      console.log(`Flipped ${newlyClosed.length} challenges to closed`);

      for (const ch of newlyClosed) {
        const notifTitle = "🏆 Challenge Closed — Results In!";
        const notifBody = `${ch.title} has ended. Check the leaderboard to see your rank and download the practice set!`;

        await supabase.from("notifications").insert({
          title: notifTitle,
          body: notifBody,
          type: "announcement",
          target_stream: ch.audience === "both" ? null : ch.audience,
          payload: {
            type: "challenge_closed",
            challenge_id: ch.id,
          },
          is_read: false,
          created_at: new Date().toISOString(),
        });
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        live_count: newlyLive?.length ?? 0,
        closed_count: newlyClosed?.length ?? 0,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (err: any) {
    console.error("Scheduler error:", err);
    return new Response(
      JSON.stringify({ error: err.message ?? String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
