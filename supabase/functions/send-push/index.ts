// supabase/functions/send-push/index.ts
//
// Deploy with:
//   supabase functions deploy send-push --no-verify-jwt
//
// Secrets required (set via `supabase secrets set` or the dashboard):
//   FCM_SERVICE_ACCOUNT_JSON  — full JSON of the Firebase service account key
//   FCM_PROJECT_ID            — e.g. "matricmate-a1bf6"
//   SUPABASE_URL              — auto-provided by Supabase
//   SUPABASE_SERVICE_ROLE_KEY — auto-provided by Supabase
//   PUSH_WEBHOOK_SECRET       — shared secret required in the
//                               `x-webhook-secret` request header
//
// Events handled:
//   - "new_test": triggered when a new test/chapter/exam is added
//   - "payment_status": triggered when user payment status changes
//   - "announcement": free-form or challenge notifications from admin

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
  Deno.env.get("SUPABASE_ANON_KEY") ||
  "";
const FCM_PROJECT_ID = Deno.env.get("FCM_PROJECT_ID") ?? "matricmate-a1bf6";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-webhook-secret",
};

function getSupabaseClient() {
  return createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
}

// ── Google OAuth2 Token for FCM HTTP v1 (RS256 JWT Flow) ──────────────────────

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

function encodeJsonBase64url(obj: unknown): string {
  return base64urlEncode(new TextEncoder().encode(JSON.stringify(obj)));
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

function parseJsonLenient(raw: string): any {
  const s = raw.trim();

  // 1. Try direct JSON.parse
  try {
    return JSON.parse(s);
  } catch (_) {}

  // 2. Try unescaping outer quotes if double stringified
  if (s.startsWith('"') && s.endsWith('"')) {
    try {
      return JSON.parse(JSON.parse(s));
    } catch (_) {}
  }

  // 3. Try base64 decode if base64-encoded
  if (!s.startsWith("{") && !s.startsWith("[")) {
    try {
      const decoded = atob(s);
      return JSON.parse(decoded);
    } catch (_) {}
  }

  // 4. Try JS object literal evaluation
  try {
    const obj = (new Function(`return (${s})`))();
    if (obj && typeof obj === "object") return obj;
  } catch (_) {}

  // 5. Try fixing unquoted keys and single quotes
  try {
    const fixed = s
      .replace(/([{,]\s*)([a-zA-Z0-9_]+)\s*:/g, '$1"$2":')
      .replace(/'/g, '"');
    return JSON.parse(fixed);
  } catch (_) {}

  throw new Error(`SyntaxError parsing JSON (len: ${s.length}, start: "${s.slice(0, 40)}...")`);
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null;
let lastFcmAuthError: string | null = null;

async function getAccessToken(): Promise<string | null> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.token;
  }

  const rawSa = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!rawSa) {
    lastFcmAuthError = "FCM_SERVICE_ACCOUNT_JSON environment variable is not set in Supabase secrets";
    console.warn(lastFcmAuthError);
    return null;
  }

  let serviceAccount: { client_email?: string; private_key?: string };
  try {
    serviceAccount = parseJsonLenient(rawSa);
  } catch (err) {
    lastFcmAuthError = `Failed to parse FCM_SERVICE_ACCOUNT_JSON: ${err}`;
    console.error(lastFcmAuthError);
    return null;
  }

  if (!serviceAccount.client_email || !serviceAccount.private_key) {
    lastFcmAuthError = `FCM_SERVICE_ACCOUNT_JSON is missing client_email or private_key (keys found: ${Object.keys(serviceAccount || {}).join(", ")})`;
    console.error(lastFcmAuthError);
    return null;
  }

  try {
    const header = { alg: "RS256", typ: "JWT" };
    const claim = {
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: now + 3600,
      iat: now,
    };

    const unsigned = `${encodeJsonBase64url(header)}.${encodeJsonBase64url(claim)}`;

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

    const encodedSig = base64urlEncode(new Uint8Array(signature));
    const jwt = `${unsigned}.${encodedSig}`;

    const res = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });

    if (!res.ok) {
      const errorBody = await res.text();
      lastFcmAuthError = `Google OAuth2 token request failed [${res.status}]: ${errorBody}`;
      console.error(lastFcmAuthError);
      return null;
    }

    const data = await res.json();
    if (!data.access_token) {
      lastFcmAuthError = `Google OAuth2 returned no access_token: ${JSON.stringify(data)}`;
      console.error(lastFcmAuthError);
      return null;
    }

    cachedAccessToken = {
      token: data.access_token,
      expiresAt: now + (data.expires_in ?? 3600),
    };

    return data.access_token;
  } catch (err) {
    lastFcmAuthError = `Exception generating FCM access token: ${err}`;
    console.error(lastFcmAuthError);
    return null;
  }
}

// ── FCM Delivery Helpers ──────────────────────────────────────────────────────

function sanitizeFcmData(data: Record<string, unknown> | null | undefined): Record<string, string> {
  const result: Record<string, string> = {};
  if (!data || typeof data !== "object") return result;

  for (const [key, value] of Object.entries(data)) {
    if (value != null) {
      result[key] = typeof value === "object" ? JSON.stringify(value) : String(value);
    }
  }
  return result;
}

async function sendFcmToToken(
  token: string,
  notification: { title: string; body: string },
  data: Record<string, string>,
) {
  const accessToken = await getAccessToken();
  if (!accessToken) {
    return { ok: false, error: "FCM authentication unavailable" };
  }

  // Data-only message: no "notification" field so the app has full control
  // over display. The Flutter background handler and foreground handler both
  // read title/body from data and show a local notification manually.
  const res = await fetch(
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
  );

  if (!res.ok) {
    const errText = await res.text();
    console.error(`FCM token send failed [${res.status}]:`, errText);
    return { ok: false, status: res.status, error: errText };
  }
  return { ok: true };
}

async function sendFcmToTokens(
  tokens: string[],
  notification: { title: string; body: string },
  data: Record<string, string>,
) {
  if (tokens.length === 0) return { total: 0, sent: 0, failed: 0, errors: [] as string[] };

  const accessToken = await getAccessToken();
  if (!accessToken) {
    console.warn("sendFcmToTokens: FCM access token unavailable, skipping dispatch");
    return {
      total: tokens.length,
      sent: 0,
      failed: tokens.length,
      errors: [lastFcmAuthError || "FCM access token unavailable (check FCM_SERVICE_ACCOUNT_JSON)"],
    };
  }

  let sent = 0;
  let failed = 0;
  const errors: string[] = [];

  // Process in batches of 50 concurrent requests
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
        ).then(async (res) => {
          if (!res.ok) {
            const errText = await res.text();
            console.error(`FCM token send failed [${res.status}] token=${token.slice(0, 15)}...:`, errText);
            if (errors.length < 5) {
              errors.push(`[${res.status}] ${errText}`);
            }
            failed++;
          } else {
            sent++;
          }
        }),
      ),
    );
  }

  console.log(`FCM batch send: ${sent}/${tokens.length} sent, ${failed} failed`);
  return { total: tokens.length, sent, failed, errors };
}

async function sendFcmToStream(
  stream: string | null,
  notification: { title: string; body: string },
  data: Record<string, string>,
) {
  const supabase = getSupabaseClient();

  let query = supabase
    .from("users")
    .select("fcm_token")
    .not("fcm_token", "is", null);

  if (stream && stream !== "both" && stream !== "common" && stream !== "all") {
    query = query.ilike("stream", stream);
  }

  const { data: users, error } = await query;
  if (error) {
    console.error("sendFcmToStream: failed to fetch tokens", error);
    return { total: 0, sent: 0, failed: 0, errors: [`DB query error: ${error.message}`] };
  }

  const tokens: string[] = (users ?? [])
    .map((u: { fcm_token?: string | null }) => u.fcm_token?.trim() ?? "")
    .filter((t) => t.length > 0);

  console.log(`sendFcmToStream: stream=${stream ?? "all"} → ${tokens.length} token(s)`);
  return await sendFcmToTokens(tokens, notification, data);
}

async function sendFcmToStatus(
  status: string,
  notification: { title: string; body: string },
  data: Record<string, string>,
) {
  const supabase = getSupabaseClient();
  const { data: users, error } = await supabase
    .from("users")
    .select("fcm_token")
    .not("fcm_token", "is", null)
    .ilike("subscription_status", status);

  if (error) {
    console.error("sendFcmToStatus: failed to fetch tokens", error);
    return { total: 0, sent: 0, failed: 0, errors: [`DB query error: ${error.message}`] };
  }

  const tokens: string[] = (users ?? [])
    .map((u: { fcm_token?: string | null }) => u.fcm_token?.trim() ?? "")
    .filter((t) => t.length > 0);

  console.log(`sendFcmToStatus: status=${status} → ${tokens.length} token(s) (found ${(users ?? []).length} users)`);
  return await sendFcmToTokens(tokens, notification, data);
}

// ── Event Handlers ────────────────────────────────────────────────────────────

function buildNewTestNotificationCopy(
  testType: string,
  subjectName: string,
  testTitle: string,
): { title: string; notifBody: string } {
  switch (testType) {
    case "chapter":
      return {
        title: "New chapter test",
        notifBody: `A new chapter test for ${subjectName} is now available`,
      };
    case "grade":
      return {
        title: "New grade test",
        notifBody: `A new grade test for ${subjectName} is now available`,
      };
    case "entrance":
      return {
        title: "New entrance exam",
        notifBody: `A new entrance exam for ${subjectName} is now available`,
      };
    case "model":
      return {
        title: "New model exam",
        notifBody: `A new model exam for ${subjectName} is now available`,
      };
    default:
      return {
        title: "New exam added",
        notifBody: `${testTitle || "A new exam"} is now available for ${subjectName}`,
      };
  }
}

interface NewTestBody {
  test_id: number;
  subject_id: number;
  test_type: string;
  title?: string;
  grade?: number | string;
  chapter_id?: number | string;
  chapter?: string;
  chapter_number?: number | string;
}

async function handleNewTest(body: NewTestBody) {
  if (!body.test_id || !body.subject_id) {
    console.error("handleNewTest: missing test_id or subject_id", body);
    return { ok: false, error: "missing test_id or subject_id" };
  }

  const supabase = getSupabaseClient();
  const { data: subject } = await supabase
    .from("subjects")
    .select("name, is_natural, is_common")
    .eq("id", body.subject_id)
    .single();

  if (!subject) {
    return { ok: false, error: `Subject ${body.subject_id} not found` };
  }

  const targetStream = subject.is_common
    ? null
    : (subject.is_natural ? "natural" : "social");

  const { title, notifBody } = buildNewTestNotificationCopy(
    body.test_type,
    subject.name,
    body.title ?? "",
  );

  const payload: Record<string, string> = {
    test_type: body.test_type,
    test_id: String(body.test_id),
    subject_id: String(body.subject_id),
    subject: subject.name,
    ...(body.grade != null && { grade: String(body.grade) }),
    ...(body.chapter_id != null && { chapter_id: String(body.chapter_id) }),
    ...(body.chapter != null && { chapter: String(body.chapter) }),
    ...(body.chapter_number != null && { chapter_number: String(body.chapter_number) }),
  };

  const { data: inserted, error: insertError } = await supabase
    .from("notifications")
    .insert({
      user_id: null,
      title,
      body: notifBody,
      type: "new_content",
      target_stream: targetStream,
      payload,
      is_read: false,
    })
    .select("id")
    .single();

  if (insertError) {
    console.error("handleNewTest: insert failed", insertError);
  }

  const fcmResult = await sendFcmToStream(
    targetStream,
    { title, body: notifBody },
    { type: "new_content", title, body: notifBody, ...payload },
  );

  return { ok: true, notification_id: inserted?.id ?? null, fcm: fcmResult };
}

function buildPaymentNotificationCopy(status: string): { title: string; notifBody: string } {
  switch (status.toLowerCase()) {
    case "active":
    case "approved":
      return {
        title: "Payment Approved! 🎉",
        notifBody: "Your premium access is now active. Enjoy full access to all tests!",
      };
    case "pending":
      return {
        title: "Payment Pending",
        notifBody: "Your payment is still being processed. We'll notify you once it's confirmed.",
      };
    case "rejected":
      return {
        title: "Payment Rejected",
        notifBody: "Your payment could not be processed. Please try again or contact support.",
      };
    case "inactive":
    case "revoked":
      return {
        title: "Subscription Inactive",
        notifBody: "Your premium subscription is no longer active. Renew to keep full access.",
      };
    default:
      return {
        title: "Payment Update",
        notifBody: `Your payment status has been updated to "${status}".`,
      };
  }
}

interface PaymentStatusBody {
  user_id: string;
  status: string;
  title?: string;
  body?: string;
  rejection_reason?: string;
}

async function handlePaymentStatus(body: PaymentStatusBody) {
  if (!body.user_id || !body.status) {
    return { ok: false, error: "missing user_id or status" };
  }

  const supabase = getSupabaseClient();
  const { data: user } = await supabase
    .from("users")
    .select("fcm_token")
    .eq("id", body.user_id)
    .single();

  const defaults = buildPaymentNotificationCopy(body.status);
  const title = body.title?.trim() || defaults.title;
  const notifBody = body.body?.trim() || defaults.notifBody;

  const notifPayload: Record<string, unknown> = { status: body.status };
  if (body.rejection_reason?.trim()) {
    notifPayload.rejection_reason = body.rejection_reason.trim();
  }

  const { data: inserted, error: insertError } = await supabase
    .from("notifications")
    .insert({
      user_id: body.user_id,
      title,
      body: notifBody,
      type: "payment",
      target_stream: null,
      payload: notifPayload,
      is_read: false,
    })
    .select("id")
    .single();

  if (insertError) {
    console.error("handlePaymentStatus: insert failed", insertError);
  }

  let fcmResult = { total: 0, sent: 0, failed: 0 };
  if (user?.fcm_token) {
    const data: Record<string, string> = {
      type: "payment",
      status: body.status,
      notification_id: String(inserted?.id ?? ""),
      title,
      body: notifBody,
    };
    if (body.rejection_reason?.trim()) {
      data.rejection_reason = body.rejection_reason.trim();
    }
    const res = await sendFcmToToken(user.fcm_token, { title, body: notifBody }, data);
    fcmResult = { total: 1, sent: res.ok ? 1 : 0, failed: res.ok ? 0 : 1 };
  }

  return { ok: true, notification_id: inserted?.id ?? null, fcm: fcmResult };
}

interface AnnouncementBody {
  title: string;
  body?: string;
  message?: string;
  type?: string;
  audience?: string | { type: string; value?: string };
  target_stream?: string | null;
  target_status?: string | null;
  user_id?: string | null;
  payload?: Record<string, unknown> | null;
  created_by?: string | null;
}

async function handleAnnouncement(body: AnnouncementBody) {
  const title = body.title?.trim();
  const notifBody = (body.body || body.message || "").trim();

  if (!title || !notifBody) {
    console.error("handleAnnouncement: missing title or body", body);
    return { ok: false, error: "missing title or body" };
  }

  // Normalize audience
  let audienceType = "all";
  let targetStream: string | null = null;
  let targetStatus: string | null = null;
  let targetUserId: string | null = null;

  if (typeof body.audience === "object" && body.audience !== null) {
    audienceType = body.audience.type ?? "all";
    if (audienceType === "stream") targetStream = body.audience.value ?? null;
    if (audienceType === "status") targetStatus = body.audience.value ?? null;
    if (audienceType === "user") targetUserId = body.audience.value ?? null;
  } else if (typeof body.audience === "string") {
    const audStr = body.audience.trim().toLowerCase();
    if (audStr.startsWith("stream:")) {
      audienceType = "stream";
      targetStream = audStr.substring(7).trim();
    } else if (audStr.startsWith("status:")) {
      audienceType = "status";
      targetStatus = audStr.substring(7).trim();
    } else if (audStr.startsWith("user:")) {
      audienceType = "user";
      targetUserId = body.audience.substring(5).trim();
    } else {
      audienceType = audStr;
    }
  }

  // Override with direct fields if provided
  if (body.target_stream) targetStream = body.target_stream.trim().toLowerCase();
  if (body.target_status) targetStatus = body.target_status.trim().toLowerCase();
  if (body.user_id) targetUserId = body.user_id.trim();

  // Normalize stream
  if (targetStream === "both" || targetStream === "common" || targetStream === "all") {
    targetStream = null;
  }

  const supabase = getSupabaseClient();
  let rowUserId: string | null = null;
  let token: string | null = null;

  if (audienceType === "user" && targetUserId) {
    rowUserId = targetUserId;
    const { data: user } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", targetUserId)
      .single();
    token = user?.fcm_token ?? null;
  }

  // Ensure notification type is valid for DB check constraint
  const allowedTypes = ["announcement", "payment", "new_content", "challenge"];
  const notifType = (body.type && allowedTypes.includes(body.type)) ? body.type : "announcement";

  // Build insert payload
  const insertPayload: Record<string, unknown> = {
    user_id: rowUserId,
    title,
    body: notifBody,
    type: notifType,
    target_stream: targetStream,
    payload: body.payload ?? {},
    is_read: false,
  };

  if (body.created_by != null && body.created_by.trim().length > 0) {
    insertPayload.created_by = body.created_by.trim();
  }

  // Save in notifications table with fallback if created_by FK fails
  let { data: inserted, error: insertError } = await supabase
    .from("notifications")
    .insert(insertPayload)
    .select("id")
    .single();

  if (insertError && insertPayload.created_by) {
    console.warn("Insert failed with created_by, retrying without created_by:", insertError);
    delete insertPayload.created_by;
    const retry = await supabase
      .from("notifications")
      .insert(insertPayload)
      .select("id")
      .single();
    inserted = retry.data;
    insertError = retry.error;
  }

  if (insertError) {
    console.error("handleAnnouncement: insert failed", insertError);
    return { ok: false, error: insertError.message };
  }

  // Build clean string-only FCM data payload
  // IMPORTANT: title and body MUST be in the data payload because the student
  // app's background handler reads from message.data['title'] / message.data['body']
  // (the notification field is not accessible in the background isolate on Android).
  const customData = sanitizeFcmData(body.payload);
  const data: Record<string, string> = {
    type: notifType,
    notification_id: String(inserted?.id ?? ""),
    title,
    body: notifBody,
    ...customData,
  };

  let fcmResult: Record<string, unknown> = { total: 0, sent: 0, failed: 0 };
  try {
    if (audienceType === "user" && token) {
      const res = await sendFcmToToken(token, { title, body: notifBody }, data);
      fcmResult = { total: 1, sent: res.ok ? 1 : 0, failed: res.ok ? 0 : 1 };
    } else if (audienceType === "stream" && targetStream) {
      fcmResult = await sendFcmToStream(targetStream, { title, body: notifBody }, data);
    } else if (audienceType === "status" && targetStatus) {
      fcmResult = await sendFcmToStatus(targetStatus, { title, body: notifBody }, data);
    } else {
      // Global broadcast to all users
      fcmResult = await sendFcmToStream(null, { title, body: notifBody }, data);
    }
  } catch (e: any) {
    console.error("handleAnnouncement: FCM dispatch error", e);
    fcmResult = { total: 0, sent: 0, failed: 0, error: e.message ?? String(e) };
  }

  return {
    ok: true,
    notification_id: inserted?.id ?? null,
    fcm: fcmResult,
  };
}

// ── Main Entrypoint ───────────────────────────────────────────────────────────

interface EventBody {
  event: string;
  [key: string]: unknown;
}

Deno.serve(async (req: Request) => {
  // CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  // Shared-secret check
  const webhookSecret = Deno.env.get("PUSH_WEBHOOK_SECRET");
  if (webhookSecret) {
    const providedSecret = req.headers.get("x-webhook-secret");
    if (providedSecret !== webhookSecret) {
      console.warn("send-push: unauthorized request (invalid or missing x-webhook-secret)");
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
  }

  try {
    const body = (await req.json()) as EventBody;
    const event = body.event;

    switch (event) {
      case "new_test": {
        const result = await handleNewTest(body as unknown as NewTestBody);
        return new Response(JSON.stringify(result), {
          status: result.ok ? 200 : 400,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
      }

      case "payment_status": {
        const result = await handlePaymentStatus(body as unknown as PaymentStatusBody);
        return new Response(JSON.stringify(result), {
          status: result.ok ? 200 : 400,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
      }

      case "announcement": {
        const result = await handleAnnouncement(body as unknown as AnnouncementBody);
        return new Response(JSON.stringify(result), {
          status: result.ok ? 200 : 400,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
      }

      default:
        return new Response(
          JSON.stringify({ error: `unknown event: ${event}` }),
          { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
        );
    }
  } catch (err: any) {
    console.error("send-push error:", err);
    return new Response(
      JSON.stringify({ error: err.message ?? String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  }
});
