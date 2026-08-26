// supabase/functions/challenge-scheduler/index.ts
// Cron job edge function: flips scheduled -> live at starts_at, and live -> closed at ends_at.
// Triggers notifications on status transitions (only if not already notified).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FCM_PROJECT_ID = Deno.env.get("FCM_PROJECT_ID") ?? "matricmate-a1bf6";

function getSupabaseClient() {
  return createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
}

// ── Google OAuth2 Token for FCM ───────────────────────────────────────────────

function base64urlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/=+$/, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN[ A-Z0-9_-]+-----/g, "")
    .replace(/-----END[ A-Z0-9_-]+-----/g, "")
    .replace(/\\n/g, "")
    .replace(/\r/g, "")
    .replace(/\n/g, "")
    .replace(/\s/g, "");
  const raw = atob(b64);
  const buf = new ArrayBuffer(raw.length);
  const view = new Uint8Array(buf);
  for (let i = 0; i < raw.length; i++) view[i] = raw.charCodeAt(i);
  return buf;
}

async function getAccessToken(): Promise<string | null> {
  const rawSa = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!rawSa) return null;

  try {
    let trimmed = rawSa.trim();
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      trimmed = JSON.parse(trimmed);
    }
    const serviceAccount = typeof trimmed === "string" ? JSON.parse(trimmed) : trimmed;
    if (!serviceAccount.client_email || !serviceAccount.private_key) return null;

    const now = Math.floor(Date.now() / 1000);
    const header = { alg: "RS256", typ: "JWT" };
    const claim = {
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: now + 3600,
      iat: now,
    };

    const encode = (o: unknown) =>
      base64urlEncode(new TextEncoder().encode(JSON.stringify(o)));
    const unsigned = `${encode(header)}.${encode(claim)}`;

    const keyBuffer = pemToArrayBuffer(serviceAccount.private_key);
    const key = await crypto.subtle.importKey(
      "pkcs8",
      keyBuffer,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"],
    );

    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(unsigned),
    );

    const jwt = `${unsigned}.${base64urlEncode(new Uint8Array(signature))}`;

    const res = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });

    if (!res.ok) return null;
    const data = await res.json();
    return data.access_token ?? null;
  } catch (err) {
    console.error("Scheduler FCM auth error:", err);
    return null;
  }
}

async function sendFcmToStream(
  stream: string | null,
  data: Record<string, string>,
) {
  try {
    const supabase = getSupabaseClient();
    let query = supabase
      .from("users")
      .select("fcm_token")
      .not("fcm_token", "is", null)
      .neq("fcm_token", "");

    if (stream && stream !== "both" && stream !== "common" && stream !== "all") {
      query = query.ilike("stream", stream);
    }

    const { data: users } = await query;
    const tokens: string[] = (users ?? [])
      .map((u: { fcm_token?: string | null }) => u.fcm_token?.trim() ?? "")
      .filter((t) => t.length > 0);

    if (tokens.length === 0) return;

    const accessToken = await getAccessToken();
    if (!accessToken) return;

    console.log(`Scheduler FCM: sending to ${tokens.length} token(s), stream=${stream ?? "all"}`);

    // Data-only FCM messages — no notification field.
    // The Flutter app handles display via background handler and foreground listener.
    const batchSize = 50;
    for (let i = 0; i < tokens.length; i += batchSize) {
      const batch = tokens.slice(i, i + batchSize);
      await Promise.allSettled(
        batch.map((token) =>
          fetch(
            `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
            {
              method: "POST",
              headers: {
                Authorization: `Bearer ${accessToken}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                message: {
                  token,
                  data,
                  android: {
                    priority: "high",
                  },
                  apns: {
                    headers: {
                      "apns-priority": "10",
                      "apns-push-type": "background",
                    },
                    payload: {
                      aps: {
                        "content-available": 1,
                        sound: "default",
                      },
                    },
                  },
                },
              }),
            },
          ),
        ),
      );
    }
  } catch (err) {
    console.error("Scheduler FCM broadcast error:", err);
  }
}

// ── Main Scheduler Entrypoint ─────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const supabase = getSupabaseClient();
  try {
    const now = new Date().toISOString();

    // 0. Expired scheduled challenges (ends_at <= now): flip directly to closed without firing live notification
    await supabase
      .from("leaderboard_challenges")
      .update({ status: "closed" })
      .eq("status", "scheduled")
      .lte("ends_at", now);

    // 1. Flip scheduled -> live (only if currently within the active window)
    const { data: newlyLive, error: liveErr } = await supabase
      .from("leaderboard_challenges")
      .update({ status: "live" })
      .eq("status", "scheduled")
      .lte("starts_at", now)
      .gt("ends_at", now)
      .select("id, title, audience, subject_id");

    if (liveErr) {
      console.error("Error flipping scheduled to live:", liveErr);
    } else if (newlyLive && newlyLive.length > 0) {
      console.log(`Flipped ${newlyLive.length} challenges to live`);

      for (const ch of newlyLive) {
        // Check if a live notification was already created for this challenge
        const { data: existing } = await supabase
          .from("notifications")
          .select("id")
          .eq("type", "challenge")
          .contains("payload", { challenge_id: String(ch.id), type: "challenge_live" })
          .limit(1);

        if (existing && existing.length > 0) {
          console.log(`Skipping live notification for challenge ${ch.id} — already notified (notification ${existing[0].id})`);
          continue;
        }

        const { data: subject } = await supabase
          .from("subjects")
          .select("name")
          .eq("id", ch.subject_id)
          .single();

        const subjName = subject?.name ?? "Subject";
        const notifTitle = "🔥 Challenge is LIVE!";
        const notifBody = `${ch.title} (${subjName}) is now open. Test your skills and compete for the leaderboard!`;
        const targetStream = ch.audience === "both" ? null : ch.audience;

        // Insert exactly one notification row
        const { data: inserted } = await supabase
          .from("notifications")
          .insert({
            title: notifTitle,
            body: notifBody,
            type: "challenge",
            target_stream: targetStream,
            payload: {
              type: "challenge_live",
              challenge_id: String(ch.id),
            },
            is_read: false,
            created_at: new Date().toISOString(),
          })
          .select("id")
          .single();

        // Send data-only FCM push to student devices
        await sendFcmToStream(
          targetStream,
          {
            type: "challenge_live",
            challenge_id: String(ch.id),
            notification_id: String(inserted?.id ?? ""),
            title: notifTitle,
            body: notifBody,
          },
        );
      }
    }

    // 2. Flip live -> closed (In-app Supabase notification only, no FCM push interrupt)
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
        // Check if a closed notification was already created for this challenge
        const { data: existing } = await supabase
          .from("notifications")
          .select("id")
          .eq("type", "challenge")
          .contains("payload", { challenge_id: String(ch.id), type: "challenge_closed" })
          .limit(1);

        if (existing && existing.length > 0) {
          continue;
        }

        const notifTitle = "🏆 Challenge Closed — Results In!";
        const notifBody = `${ch.title} has ended. Check the leaderboard to see your rank and download the practice set!`;
        const targetStream = ch.audience === "both" ? null : ch.audience;

        // Insert in Supabase notifications table for in-app feed
        await supabase
          .from("notifications")
          .insert({
            title: notifTitle,
            body: notifBody,
            type: "challenge",
            target_stream: targetStream,
            payload: {
              type: "challenge_closed",
              challenge_id: String(ch.id),
            },
            is_read: false,
            created_at: new Date().toISOString(),
          });

        // NOTE: No FCM push is sent for 'closed' to keep mobile notification panel clean & avoid fatigue.
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
