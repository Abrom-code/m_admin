// supabase/functions/admin-auth/index.ts
// Verify Firebase ID token and issue Supabase JWT with admin claims.
//
// POST /admin-auth
// Body: { "id_token": "<Firebase ID token>" }
// Returns: { "access_token": "<Supabase JWT>", "expires_in": 3600 }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, verify } from "https://deno.land/x/djwt@v3.0.1/mod.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// ── Firebase ID token verification ───────────────────────────────────────────

interface GooglePublicKeys {
  [kid: string]: string;
}

let cachedKeys: GooglePublicKeys | null = null;
let keysCacheExpiry = 0;

async function getGooglePublicKeys(): Promise<GooglePublicKeys> {
  const now = Date.now();
  if (cachedKeys && now < keysCacheExpiry) {
    return cachedKeys;
  }

  const res = await fetch(
    "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com",
  );
  const cacheControl = res.headers.get("cache-control");
  const maxAgeMatch = cacheControl?.match(/max-age=(\d+)/);
  const maxAge = maxAgeMatch ? parseInt(maxAgeMatch[1], 10) : 3600;

  cachedKeys = await res.json();
  keysCacheExpiry = now + maxAge * 1000;
  return cachedKeys!;
}

async function verifyFirebaseToken(
  idToken: string,
): Promise<{ email: string; uid: string } | null> {
  try {
    const keys = await getGooglePublicKeys();
    const [headerB64] = idToken.split(".");
    const header = JSON.parse(atob(headerB64.replace(/-/g, "+").replace(/_/g, "/")));
    const pemKey = keys[header.kid];
    if (!pemKey) return null;

    const cryptoKey = await crypto.subtle.importKey(
      "spki",
      pemToBuf(pemKey),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    );

    const payload = await verify(idToken, cryptoKey);
    const projectId = Deno.env.get("FIREBASE_PROJECT_ID")!;

    if (
      payload.iss !== `https://securetoken.google.com/${projectId}` ||
      payload.aud !== projectId ||
      !payload.email
    ) {
      return null;
    }

    return { email: payload.email as string, uid: payload.sub as string };
  } catch {
    return null;
  }
}

function pemToBuf(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN CERTIFICATE-----/, "")
    .replace(/-----END CERTIFICATE-----/, "")
    .replace(/\s/g, "");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)).buffer;
}

// ── Supabase JWT generation ──────────────────────────────────────────────────

async function issueSupabaseJwt(
  uid: string,
  email: string,
  appRole: string,
): Promise<string> {
  const secret = Deno.env.get("SUPABASE_JWT_SECRET")!;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    sub: uid,
    email,
    role: "authenticated",
    app_role: appRole,
    aud: "authenticated",
    iat: now,
    exp: now + 3600, // 1 hour
  };

  return await create({ alg: "HS256", typ: "JWT" }, payload, key);
}

// ── Main handler ──────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  try {
    const { id_token } = await req.json();
    if (!id_token) {
      return new Response(
        JSON.stringify({ error: "id_token required" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const firebaseUser = await verifyFirebaseToken(id_token);
    if (!firebaseUser) {
      return new Response(
        JSON.stringify({ error: "invalid Firebase token" }),
        { status: 401, headers: { "Content-Type": "application/json" } },
      );
    }

    // Look up admin record
    const { data: admin, error: adminError } = await supabase
      .from("admins")
      .select("id, role")
      .eq("email", firebaseUser.email)
      .single();

    if (adminError || !admin) {
      return new Response(
        JSON.stringify({ error: "not an admin" }),
        { status: 403, headers: { "Content-Type": "application/json" } },
      );
    }

    // Update last_login_at
    await supabase
      .from("admins")
      .update({ last_login_at: new Date().toISOString() })
      .eq("id", admin.id);

    const accessToken = await issueSupabaseJwt(
      firebaseUser.uid,
      firebaseUser.email,
      admin.role,
    );

    return new Response(
      JSON.stringify({ access_token: accessToken, expires_in: 3600 }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error(err);
    return new Response(
      JSON.stringify({ error: "internal error" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
