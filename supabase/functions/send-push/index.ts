// supabase/functions/send-push/index.ts
// MatricMate push notification dispatcher.
// Events: new_test | payment_status | announcement

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// ── FCM auth ──────────────────────────────────────────────────────────────────

async function getFcmAccessToken(): Promise<string> {
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

// ── FCM sender ────────────────────────────────────────────────────────────────

async function sendToToken(
  accessToken: string,
  fcmToken: string,
  notification: { title: string; body: string },
  data: Record<string, string>,
): Promise<void> {
  const projectId = Deno.env.get("FCM_PROJECT_ID")!;
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
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
  if (!res.ok) {
    const body = await res.text();
    // Log but don't throw — one bad token must not stop the rest.
    console.error(`FCM send to token failed ${res.status}: ${body}`);
  }
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

  // Determine which stream this subject belongs to.
  const stream: string = subject.is_common
    ? "common"
    : subject.is_natural
    ? "Natural"
    : "Social";

  // Fetch all users in that stream who have an FCM token.
  let q = sb.from("users").select("fcm_token").not("fcm_token", "is", null);
  if (!subject.is_common) {
    q = q.ilike("stream", stream); // case-insensitive
  }
  const { data: users } = await q;
  if (!users || users.length === 0) return;

  const accessToken = await getFcmAccessToken();
  const notification = {
    title: "New Test Available",
    body: `${title} — ${subject.name}`,
  };
  const data = { type: "new_test", test_id: String(test_id) };

  await Promise.all(
    users
      .filter((u: any) => u.fcm_token)
      .map((u: any) => sendToToken(accessToken, u.fcm_token, notification, data)),
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

  const isApproved = status === "approved" || status === "active";
  const isRejected = status === "rejected";
  const isRevoked = status === "inactive";
  if (!isApproved && !isRejected && !isRevoked) return;

  let notifTitle: string;
  let notifBody: string;
  let payloadStatus: string;

  if (isApproved) {
    notifTitle = "Payment Approved ✓";
    notifBody =
      "Your payment has been approved! Refresh the app to access premium features.";
    payloadStatus = "approved";
  } else if (isRevoked) {
    notifTitle = "Premium Access Revoked";
    notifBody = rejection_reason
      ? `Your premium access has been revoked. Reason: ${rejection_reason}`
      : "Your premium access has been revoked. Contact support for details.";
    payloadStatus = "revoked";
  } else {
    notifTitle = "Payment Not Approved";
    notifBody =
      rejection_reason ||
      "Your payment was not approved. Contact support for details.";
    payloadStatus = "rejected";
  }

  // Insert into notifications so the student's in-app feed shows the result.
  await sb.from("notifications").insert({
    title: notifTitle,
    body: notifBody,
    type: "payment",
    user_id,
    payload: { status: payloadStatus },
    is_read: false,
    created_at: new Date().toISOString(),
  });

  if (user?.fcm_token) {
    const accessToken = await getFcmAccessToken();
    await sendToToken(
      accessToken,
      user.fcm_token,
      { title: notifTitle, body: notifBody },
      { type: "payment_status", status: payloadStatus },
    );
  }
}

async function handleAnnouncement(
  sb: ReturnType<typeof createClient>,
  body: any,
) {
  // The Flutter admin app already inserted the notifications DB row.
  // This function ONLY sends the FCM push.
  // audience: { type: 'all' | 'stream' | 'user', value?: string }
  const { title, message, audience } = body;

  const notification = { title: title ?? "", body: message ?? "" };
  const data = { type: "announcement" };

  let tokens: string[] = [];

  if (audience.type === "all") {
    // All users who have an FCM token.
    const { data: users } = await sb
      .from("users")
      .select("fcm_token")
      .not("fcm_token", "is", null)
      .not("fcm_token", "eq", "");
    tokens = (users ?? []).map((u: any) => u.fcm_token).filter(Boolean);

  } else if (audience.type === "stream" && audience.value) {
    // Case-insensitive match so it works whether the student app stores
    // "Natural", "natural", or "NATURAL".
    const { data: users } = await sb
      .from("users")
      .select("fcm_token")
      .ilike("stream", audience.value)
      .not("fcm_token", "is", null)
      .not("fcm_token", "eq", "");
    tokens = (users ?? []).map((u: any) => u.fcm_token).filter(Boolean);

  } else if (audience.type === "user" && audience.value) {
    // Single user by their Firebase UID (= users.id).
    const { data: user } = await sb
      .from("users")
      .select("fcm_token")
      .eq("id", audience.value)
      .single();
    if (user?.fcm_token) tokens = [user.fcm_token];
  }

  if (tokens.length === 0) return;

  const accessToken = await getFcmAccessToken();
  await Promise.all(
    tokens.map((token) => sendToToken(accessToken, token, notification, data)),
  );
}

// ── Main handler ──────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
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
