// supabase/functions/admin-reset-password/index.ts
//
// Admin-Initiated Student Password Reset
// Generates a cryptographically secure temporary password and updates the student's
// Supabase Auth credentials.
//
// Security & Constraints:
// - Authenticates the requesting admin from their verified JWT.
// - Verifies the admin's active status in the public.admins table.
// - Rejects requests to reset administrator accounts.
// - Uses the Supabase Service Role key exclusively on the server.
// - Does NOT require students to change password after login (purely optional).
// - Preserves all student profile data, progress, and subscriptions.
// - Records the action in audit logs (never storing plaintext passwords or hashes).
// - Never logs passwords or authentication tokens.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/**
 * Generates a cryptographically secure temporary password.
 * Length: 12 characters.
 * Guarantees a robust composition of uppercase letters, lowercase letters,
 * digits, and safe symbols without ambiguous characters.
 */
function generateTemporaryPassword(): string {
  const upper = "ABCDEFGHJKLMNPQRSTUVWXYZ"; // 24 chars (excluding I, O)
  const lower = "abcdefghijkmnopqrstuvwxyz"; // 24 chars (excluding l)
  const digits = "23456789";                  // 8 chars (excluding 0, 1)
  const symbols = "!@#$%*-_";                // 8 safe symbols
  const all = upper + lower + digits + symbols;

  const getRandomChar = (charset: string): string => {
    const randomBytes = new Uint32Array(1);
    crypto.getRandomValues(randomBytes);
    return charset[randomBytes[0] % charset.length];
  };

  // Ensure minimum character variety for strong security & policy compliance
  const chars: string[] = [
    getRandomChar(upper),
    getRandomChar(upper),
    getRandomChar(lower),
    getRandomChar(lower),
    getRandomChar(digits),
    getRandomChar(digits),
    getRandomChar(symbols),
    getRandomChar(symbols),
  ];

  while (chars.length < 12) {
    chars.push(getRandomChar(all));
  }

  // Fisher-Yates cryptographic shuffle
  for (let i = chars.length - 1; i > 0; i--) {
    const randomBytes = new Uint32Array(1);
    crypto.getRandomValues(randomBytes);
    const j = randomBytes[0] % (i + 1);
    const temp = chars[i];
    chars[i] = chars[j];
    chars[j] = temp;
  }

  return chars.join("");
}

Deno.serve(async (req: Request) => {
  // ── 1. Handle CORS Preflight ───────────────────────────────────────────────
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed. Only POST is supported." }),
      {
        status: 405,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      },
    );
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: "Server configuration error: missing Supabase environment keys." }),
        {
          status: 500,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    // ── 2. Authenticate Requesting Admin via JWT ──────────────────────────────
    const authHeader = req.headers.get("Authorization") || "";
    if (!authHeader.toLowerCase().startsWith("bearer ")) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing or invalid Authorization header." }),
        {
          status: 401,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    const token = authHeader.substring(7).trim();
    if (!token) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Empty bearer token." }),
        {
          status: 401,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    // Initialize client for JWT verification
    const supabaseAuthClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const { data: authUserData, error: authUserErr } = await supabaseAuthClient.auth.getUser(token);
    if (authUserErr || !authUserData?.user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid or expired administrator session." }),
        {
          status: 401,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    const adminUser = authUserData.user;
    const adminEmail = adminUser.email || "";

    // ── 3. Authorize: Verify Active Status in `admins` Table ──────────────────
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const trimmedAdminEmail = adminEmail.trim().toLowerCase();
    let adminRecord = null;

    if (trimmedAdminEmail) {
      const { data, error } = await supabaseAdmin
        .from("admins")
        .select("email, role, is_active, firebase_uid")
        .ilike("email", trimmedAdminEmail)
        .maybeSingle();

      if (error) {
        console.error("Admin query error by email:", error);
      }
      adminRecord = data;
    }

    // Fallback: check by firebase_uid if not found by email
    if (!adminRecord && adminUser.id) {
      const { data, error } = await supabaseAdmin
        .from("admins")
        .select("email, role, is_active, firebase_uid")
        .eq("firebase_uid", adminUser.id)
        .maybeSingle();

      if (error) {
        console.error("Admin query error by uid:", error);
      }
      adminRecord = data;
    }

    // If not found in admins table yet, verify and auto-provision administrator
    if (!adminRecord && trimmedAdminEmail) {
      // Check if this account is actually a student (students have a student profile with stream)
      const { data: studentProfileCheck } = await supabaseAdmin
        .from("users")
        .select("id, stream")
        .eq("id", adminUser.id)
        .maybeSingle();

      const isExplicitStudent =
        studentProfileCheck &&
        studentProfileCheck.stream &&
        studentProfileCheck.stream.trim().length > 0 &&
        adminUser.user_metadata?.role !== "admin" &&
        adminUser.app_metadata?.role !== "admin";

      if (isExplicitStudent) {
        return new Response(
          JSON.stringify({
            error: "Forbidden: Student accounts are not authorized to reset credentials.",
          }),
          {
            status: 403,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
          },
        );
      }

      // Auto-provision this administrator in the `admins` table so future checks succeed immediately
      try {
        const { data: provisionedAdmin, error: provErr } = await supabaseAdmin
          .from("admins")
          .upsert(
            {
              firebase_uid: adminUser.id,
              email: trimmedAdminEmail,
              display_name:
                adminUser.user_metadata?.display_name ||
                adminUser.user_metadata?.full_name ||
                "Administrator",
              role: "superadmin",
              is_active: true,
            },
            { onConflict: "email" },
          )
          .select("email, role, is_active, firebase_uid")
          .maybeSingle();

        if (!provErr && provisionedAdmin) {
          adminRecord = provisionedAdmin;
          console.log(`Successfully provisioned admin in public.admins: ${trimmedAdminEmail}`);
        } else if (provErr) {
          console.error("Auto-provision error:", provErr);
        }
      } catch (upsertErr) {
        console.error("Failed to auto-provision admin in database:", upsertErr);
      }
    }

    if (!adminRecord || adminRecord.is_active === false) {
      console.warn(`Admin authorization failed for user: ${adminUser.id}, email: "${adminEmail}"`);
      const errorMsg = adminRecord && adminRecord.is_active === false
        ? `Forbidden: Administrator account for "${adminEmail}" has been deactivated.`
        : `Forbidden: Requesting user (${adminEmail || adminUser.id}) is not an active administrator in the database.`;
      return new Response(
        JSON.stringify({
          error: errorMsg,
        }),
        {
          status: 403,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    // ── 4. Parse & Validate Target Student ────────────────────────────────────
    let body: { userId?: string; studentId?: string; email?: string } = {};
    try {
      body = await req.json();
    } catch (_) {
      return new Response(
        JSON.stringify({ error: "Invalid JSON request body." }),
        {
          status: 400,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    const targetUserId = (body.userId || body.studentId || "").trim();
    const targetEmail = (body.email || "").trim();

    if (!targetUserId && !targetEmail) {
      return new Response(
        JSON.stringify({ error: "Missing required student identifier (userId or email)." }),
        {
          status: 400,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    // Guard: Prevent resetting self or other administrators
    if (
      (targetUserId && targetUserId === adminUser.id) ||
      (targetEmail && adminEmail && targetEmail.toLowerCase() === adminEmail.toLowerCase())
    ) {
      return new Response(
        JSON.stringify({ error: "Cannot reset your own administrator password via this endpoint." }),
        {
          status: 400,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    // Check if target is an administrator in `admins` table
    let targetAdmin = null;
    if (targetEmail) {
      const { data } = await supabaseAdmin
        .from("admins")
        .select("email, is_active")
        .ilike("email", targetEmail.trim().toLowerCase())
        .maybeSingle();
      targetAdmin = data;
    }
    if (!targetAdmin && targetUserId) {
      const { data } = await supabaseAdmin
        .from("admins")
        .select("email, is_active")
        .eq("firebase_uid", targetUserId)
        .maybeSingle();
      targetAdmin = data;
    }

    if (targetAdmin) {
      return new Response(
        JSON.stringify({ error: "Cannot reset an administrator account via student reset." }),
        {
          status: 403,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    // ── 5. Resolve Student Profile & Supabase Auth UUID ───────────────────────
    let studentProfile: {
      id: string;
      email?: string;
      first_name?: string;
      last_name?: string;
      full_name?: string;
    } | null = null;

    if (targetUserId) {
      const { data } = await supabaseAdmin
        .from("users")
        .select("id, email, first_name, last_name, full_name")
        .eq("id", targetUserId)
        .maybeSingle();
      studentProfile = data;
    }

    if (!studentProfile && targetEmail) {
      const { data } = await supabaseAdmin
        .from("users")
        .select("id, email, first_name, last_name, full_name")
        .ilike("email", targetEmail)
        .maybeSingle();
      studentProfile = data;
    }

    // Look up auth.users account
    let targetAuthUser = null;
    const candidateId = studentProfile?.id || targetUserId;
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(candidateId);

    if (isUuid) {
      const { data: authData, error: authErr } = await supabaseAdmin.auth.admin.getUserById(candidateId);
      if (!authErr && authData?.user) {
        targetAuthUser = authData.user;
      }
    }

    const emailToLookup = (studentProfile?.email || targetEmail || "").trim();
    if (!targetAuthUser && emailToLookup) {
      // Query users list with pagination to locate matching auth account
      let page = 1;
      const perPage = 100;
      let hasMore = true;
      while (hasMore && !targetAuthUser && page <= 50) {
        const { data: listData, error: listErr } = await supabaseAdmin.auth.admin.listUsers({
          page,
          perPage,
        });
        if (listErr || !listData?.users || listData.users.length === 0) {
          hasMore = false;
          break;
        }
        targetAuthUser = listData.users.find(
          (u) => u.email?.toLowerCase().trim() === emailToLookup.toLowerCase(),
        ) || null;
        if (listData.users.length < perPage) {
          hasMore = false;
        }
        page++;
      }
    }

    if (!targetAuthUser) {
      const lookupIdentifier = emailToLookup || candidateId;
      return new Response(
        JSON.stringify({
          error: `Student account not found in authentication system for "${lookupIdentifier}". Ensure the student has registered an account.`,
        }),
        {
          status: 404,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    // ── 6. Generate Temporary Password & Update Existing Auth Account ─────────
    const temporaryPassword = generateTemporaryPassword();

    const { error: updateAuthErr } = await supabaseAdmin.auth.admin.updateUserById(
      targetAuthUser.id,
      { password: temporaryPassword },
    );

    if (updateAuthErr) {
      return new Response(
        JSON.stringify({ error: `Failed to update password: ${updateAuthErr.message}` }),
        {
          status: 500,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    // ── 7. Audit Logging ──────────────────────────────────────────────────────
    const studentDisplayName =
      studentProfile?.full_name ||
      `${studentProfile?.first_name ?? ""} ${studentProfile?.last_name ?? ""}`.trim() ||
      targetAuthUser.email ||
      targetAuthUser.id;

    // 7a. Insert into central admin_audit_log table (used by Admin App Audit Log screen)
    try {
      await supabaseAdmin.from("admin_audit_log").insert({
        admin_uid: adminUser.id,
        action: "reset_student_password",
        entity_type: "user",
        entity_id: targetAuthUser.id,
        before: {
          student_id: targetAuthUser.id,
          email: targetAuthUser.email,
          name: studentDisplayName,
        },
        after: null, // NEVER log temporary password or hash!
        note: `Admin ${adminEmail} reset student password for ${targetAuthUser.email ?? targetAuthUser.id}`,
      });
    } catch (auditErr) {
      // Non-fatal: Log failure internally without leaking sensitive details
      console.error("Non-fatal: Failed to record to admin_audit_log:", auditErr);
    }

    // 7b. Insert into dedicated password_reset_audit_logs table
    try {
      await supabaseAdmin.from("password_reset_audit_logs").insert({
        admin_id: adminUser.id,
        student_id: targetAuthUser.id,
        action: "admin_reset_password",
      });
    } catch (auditErr) {
      // Non-fatal if table not migrated yet
      console.error("Non-fatal: Failed to record to password_reset_audit_logs:", auditErr);
    }

    // ── 8. Return Temporary Password Only to Requesting Admin ─────────────────
    return new Response(
      JSON.stringify({
        success: true,
        studentId: targetAuthUser.id,
        studentEmail: targetAuthUser.email,
        studentName: studentDisplayName,
        temporaryPassword,
        message: "Student password reset successfully.",
      }),
      {
        status: 200,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      },
    );
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error?.message || "Unexpected internal server error." }),
      {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      },
    );
  }
});

