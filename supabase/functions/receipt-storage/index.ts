// supabase/functions/receipt-storage/index.ts
//
// Handles Cloudflare R2 presigned URLs for payment receipts:
// 1. "get_upload_url": Student app requests a temporary S3 PUT URL to upload receipt directly to R2.
// 2. "get_view_url": Admin app requests a temporary S3 GET URL to view/audit receipt directly from R2.
//
// Deploy with:
//   supabase functions deploy receipt-storage --no-verify-jwt
//
// Secrets required in Supabase (same as get-note-url):
//   R2_ACCOUNT_ID             — Cloudflare Account ID
//   R2_ACCESS_KEY_ID          — Cloudflare R2 API Token Access Key ID
//   R2_SECRET_ACCESS_KEY      — Cloudflare R2 API Token Secret Access Key
//   R2_BUCKET_NAME            — Cloudflare bucket name (default: "matricet-notes")

import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  DeleteObjectsCommand,
} from "npm:@aws-sdk/client-s3@^3.600.0";
import { getSignedUrl } from "npm:@aws-sdk/s3-request-presigner@^3.600.0";

const R2_ACCOUNT_ID = Deno.env.get("R2_ACCOUNT_ID") ?? "";
const R2_ACCESS_KEY_ID = Deno.env.get("R2_ACCESS_KEY_ID") ?? "";
const R2_SECRET_ACCESS_KEY = Deno.env.get("R2_SECRET_ACCESS_KEY") ?? "";
const R2_BUCKET_NAME =
  Deno.env.get("R2_RECEIPTS_BUCKET") ||
  Deno.env.get("R2_BUCKET_NAME") ||
  "matricet-notes";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function getS3Client(): S3Client {
  return new S3Client({
    region: "auto",
    endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: R2_ACCESS_KEY_ID,
      secretAccessKey: R2_SECRET_ACCESS_KEY,
    },
  });
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      {
        status: 405,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      },
    );
  }

  try {
    let body: {
      action?: string;
      file_name?: string;
      file_key?: string;
    };

    try {
      body = await req.json();
    } catch (_) {
      return new Response(
        JSON.stringify({ error: "Invalid JSON body" }),
        {
          status: 400,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    const action = body.action?.trim();

    // ── 1. Action: Get Presigned Upload URL (PUT) ──────────────────────────
    if (action === "get_upload_url") {
      let rawName = (body.file_name || `receipt_${Date.now()}.jpg`).trim();
      // Sanitize filename to prevent directory traversal
      const cleanName = rawName
        .split("/")
        .pop()!
        .split("\\")
        .pop()!
        .replace(/[^a-zA-Z0-9._-]/g, "_");

      const key = `receipts/${cleanName}`;

      const s3 = getS3Client();
      const command = new PutObjectCommand({
        Bucket: R2_BUCKET_NAME,
        Key: key,
        ContentType: "image/jpeg",
      });

      // 5-minute expiry for upload
      const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 300 });

      return new Response(
        JSON.stringify({
          upload_url: uploadUrl,
          file_key: key,
        }),
        {
          status: 200,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    // ── 2. Action: Get Presigned View URL (GET) ────────────────────────────
    if (action === "get_view_url") {
      const fileKey = body.file_key?.trim();
      if (!fileKey || fileKey.includes("..")) {
        return new Response(
          JSON.stringify({ error: "Valid file_key is required" }),
          {
            status: 400,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
          },
        );
      }

      const s3 = getS3Client();
      const command = new GetObjectCommand({
        Bucket: R2_BUCKET_NAME,
        Key: fileKey,
      });

      // 15-minute expiry for viewing
      const viewUrl = await getSignedUrl(s3, command, { expiresIn: 900 });

      return new Response(
        JSON.stringify({
          view_url: viewUrl,
          expires_in: 900,
        }),
        {
          status: 200,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    // ── 3. Action: Delete Files from R2 (Admin cleanup) ─────────────────
    if (action === "delete_files" || action === "delete_file") {
      let rawKeys: string[] = [];
      const bodyKeys = (body as Record<string, unknown>)["file_keys"];
      if (Array.isArray(bodyKeys)) {
        rawKeys = bodyKeys.map((k) => String(k).trim()).filter(Boolean);
      } else if (body.file_key) {
        rawKeys = [String(body.file_key).trim()];
      }

      // Ensure keys are strictly under receipts/ and do not attempt directory traversal
      const keys = rawKeys.filter((k) => k.startsWith("receipts/") && !k.includes(".."));

      if (keys.length === 0) {
        return new Response(
          JSON.stringify({ success: true, count: 0 }),
          {
            status: 200,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
          },
        );
      }

      const s3 = getS3Client();
      if (keys.length === 1) {
        await s3.send(
          new DeleteObjectCommand({
            Bucket: R2_BUCKET_NAME,
            Key: keys[0],
          }),
        );
      } else {
        await s3.send(
          new DeleteObjectsCommand({
            Bucket: R2_BUCKET_NAME,
            Delete: {
              Objects: keys.map((Key) => ({ Key })),
              Quiet: true,
            },
          }),
        );
      }

      return new Response(
        JSON.stringify({ success: true, count: keys.length }),
        {
          status: 200,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        },
      );
    }

    return new Response(
      JSON.stringify({ error: "Unknown action. Use get_upload_url, get_view_url, or delete_files" }),
      {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      },
    );
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    console.error("receipt-storage error:", errorMsg);
    return new Response(
      JSON.stringify({ error: "Storage operation failed: " + errorMsg }),
      {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      },
    );
  }
});
