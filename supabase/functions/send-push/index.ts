// supabase/functions/send-push/index.ts
// MatricMate push notification dispatcher.
// Handles three events: new_test | payment_status | announcement
//
// ⚠️  Any Postgres trigger that calls this function must send the
//     x-webhook-secret header, or it will start receiving 401 responses
//     after this version is deployed.  Update those triggers before deploying.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// ── FCM helpers ───────────────────────────────────────────────────────────────

async function getFcmToken(): Promise<string> {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")!;
  const sa = JSON.parse(raw);
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = btoa(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsigned = `${header}.${payload}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBuf(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, enc(unsigned));
  const jwt = `${unsigned}.${b64url(sig)}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  const { access_token } = await res.json();
  return access_token;
}

async function sendFcmToTopic(
  topic: string,
  notification: { title: string; body: string },
  data: Record<string, string>,
) {
  const token = await getFcmToken();
  const projectId = Deno.env.get("FCM_PROJECT_ID")!;
  return fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          topic,
          notification,
          data,
          android: { notification: { channel_id: "matricmate_default" } },
        },
      }),
    },
  );
}

async function sendFcmToToken(
  fcmToken: string,
  notification: { title: string; body: string },
  data: Record<string, string>,
) {
  const token = await getFcmToken();
  const projectId = Deno.env.get("FCM_PROJECT_ID")!;
  return fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification,
          data,
          android: { notification: { channel_id: "matricmate_default" } },
        },
      }),
    },
  );
}

// ── Utilities ─────────────────────────────────────────────────────────────────

function pemToBuf(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)).buffer;
}

function enc(s: string): Uint8Array {
  return new TextEncoder().encode(s);
}

function b64url(buf: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buf)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

// ── Event handlers ────────────────────────────────────────────────────────────

async function handleNewTest(
  sb: ReturnType<typeof createClient>,
  body: any,
) {
  const { test_id, subject_id, title, grade } = body;
  const { data: subject } = await sb
    .from("subjects")
    .select("name, is_natural, is_common")
    .eq("id", subject_id)
    .single();
  if (!subject) return;

  const stream = subject.is_common
    ? "common"
    : subject.is_natural
    ? "natural"
    : "social";
  const topic = grade ? `grade_${grade}_${stream}` : `stream_${stream}`;

  await sendFcmToTopic(
    topic,
    { title: "New Test Available", body: `${title} — ${subject.name}` },
    { type: "new_test", test_id: String(test_id) },
  );
}

async function handlePaymentStatus(
  sb: ReturnType<typeof createClient>,
  body: any,
) {
  const { user_id, status, rejection_reason } = body;
  const { data: user } = await sb
    .from("users")
    .select("fcm_token")
    .eq("id", user_id)
    .single();
  if (!user?.fcm_token) return;

  if (status === "approved" || status === "active") {
    await sendFcmToToken(
      user.fcm_token,
      {
        title: "Payment Approved ✓",
        body: "Your payment has been approved! Please refresh the app to access premium features."
      },
      { type: "payment_status", status: "approved" },
    );
  } else if (status === "rejected") {
    await sendFcmToToken(
      user.fcm_token,
      {
        title: "Payment Not Approved",
        body: rejection_reason || "Your payment was not approved. Please contact support for more details.",
      },
      { type: "payment_status", status: "rejected" },
    );
  }
}

async function handleAnnouncement(
  sb: ReturnType<typeof createClient>,
  body: any,
) {
  const { title, message, audience, admin_uid } = body;
  // audience: { type: 'all' | 'stream' | 'user', value?: string }

  // Insert notification row so it appears in the in-app feed
  const { data: notif } = await sb
    .from("notifications")
    .insert({
      type: "announcement",
      payload: { title, body: message },
      is_read: false,
      created_by: admin_uid,
    })
    .select("id")
    .single();

  const notification = { title, body: message };
  const data = {
    type: "announcement",
    notification_id: notif ? String(notif.id) : "",
  };

  if (audience.type === "all") {
    // Broadcast to all three streams
    await Promise.all([
      sendFcmToTopic("stream_natural", notification, data),
      sendFcmToTopic("stream_social", notification, data),
      sendFcmToTopic("stream_common", notification, data),
    ]);
  } else if (audience.type === "stream" && audience.value) {
    await sendFcmToTopic(`stream_${audience.value}`, notification, data);
  } else if (audience.type === "user" && audience.value) {
    const { data: user } = await sb
      .from("users")
      .select("fcm_token")
      .eq("id", audience.value)
      .single();
    if (user?.fcm_token) {
      await sendFcmToToken(user.fcm_token, notification, data);
    }
  }
}

// ── Main handler ──────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  // ⚠️  Gate: Postgres triggers must send x-webhook-secret header
  if (req.headers.get("x-webhook-secret") !== Deno.env.get("PUSH_WEBHOOK_SECRET")) {
    return new Response("unauthorized", { status: 401 });
  }

  const body = await req.json();
  const { event } = body;

  try {
    switch (event) {
      case "new_test":
        await handleNewTest(supabase, body);
        break;
      case "payment_status":
        await handlePaymentStatus(supabase, body);
        break;
      case "announcement":
        await handleAnnouncement(supabase, body);
        break;
      default:
        return new Response(`unknown event: ${event}`, { status: 400 });
    }
    return new Response("ok", { status: 200 });
  } catch (err) {
    console.error(err);
    return new Response("internal error", { status: 500 });
  }
});
