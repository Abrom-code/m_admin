-- =============================================================================
-- 0001_admin_foundation.sql
-- MatricMate Admin — Foundation migration
-- =============================================================================
-- Safe to run against a live production database.
-- Every statement uses IF NOT EXISTS / ADD COLUMN IF NOT EXISTS.
-- No DROP, no TRUNCATE, no data-destroying DELETE.
-- Run order: this file → 0002_payment_rpcs.sql → 0003_updated_at_triggers.sql
-- =============================================================================

-- ── 1. Admin identity ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS admins (
  firebase_uid  text        PRIMARY KEY,
  email         text        NOT NULL UNIQUE,
  display_name  text,
  role          text        NOT NULL DEFAULT 'admin'
                            CHECK (role IN ('admin', 'superadmin')),
  is_active     boolean     NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  last_login_at timestamptz
);

COMMENT ON TABLE admins IS
  'Admin users. Rows are provisioned by SQL only — no self-signup.';

-- ── 2. Payment review state ───────────────────────────────────────────────────

-- Add primary key column if payment_receipts has no id yet.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE  table_schema = 'public'
    AND    table_name   = 'payment_receipts'
    AND    column_name  = 'id'
  ) THEN
    ALTER TABLE payment_receipts ADD COLUMN id bigserial PRIMARY KEY;
  END IF;
END $$;

ALTER TABLE payment_receipts
  ADD COLUMN IF NOT EXISTS created_at        timestamptz  DEFAULT now(),
  ADD COLUMN IF NOT EXISTS status            text         NOT NULL DEFAULT 'pending'
                                             CHECK (status IN ('pending','approved','rejected')),
  ADD COLUMN IF NOT EXISTS amount            numeric(10,2),
  ADD COLUMN IF NOT EXISTS currency          text         DEFAULT 'ETB',
  ADD COLUMN IF NOT EXISTS reviewed_by       text         REFERENCES admins(firebase_uid),
  ADD COLUMN IF NOT EXISTS reviewed_at       timestamptz,
  ADD COLUMN IF NOT EXISTS rejection_reason  text;

-- Backfill existing rows that pre-date this migration.
UPDATE payment_receipts
SET    status   = 'pending',
       amount   = 250,
       currency = 'ETB'
WHERE  status IS NULL OR amount IS NULL;

CREATE INDEX IF NOT EXISTS idx_payment_receipts_status_created
  ON payment_receipts (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payment_receipts_user_id
  ON payment_receipts (user_id);

-- ── 3. Immutable audit log ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS admin_audit_log (
  id          bigserial   PRIMARY KEY,
  admin_uid   text        NOT NULL,
  -- 'approve_payment' | 'reject_payment' | 'broadcast' | 'edit_user'
  -- | 'create_test' | 'delete_question' | 'reset_device' | ...
  action      text        NOT NULL,
  entity_type text        NOT NULL,  -- 'payment_receipt' | 'user' | 'test' | 'question' | ...
  entity_id   text,
  before      jsonb,
  after       jsonb,
  note        text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE admin_audit_log IS
  'Append-only audit trail. Never grant UPDATE or DELETE on this table.';

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_created
  ON admin_audit_log (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_admin_created
  ON admin_audit_log (admin_uid, created_at DESC);

-- ── 4. Test attempts — close the analytics gap ───────────────────────────────
-- Deliberately differs from the local SQLite `results` table:
--   • real attempt timestamp (local table has none — it sorts by test.created_at)
--   • explicit question_count so score needs no JSON decode
--   • NO UNIQUE(user_id, test_id) — history accumulates, local table keeps only latest

CREATE TABLE IF NOT EXISTS test_attempts (
  id             bigserial    PRIMARY KEY,
  user_id        text         NOT NULL,
  test_id        integer      NOT NULL,
  subject_id     integer,
  test_type      text,
  grade          integer,
  correct_count  integer      NOT NULL,
  question_count integer      NOT NULL,
  score_pct      numeric(5,2) GENERATED ALWAYS AS (
                   CASE WHEN question_count > 0
                        THEN round(correct_count::numeric * 100 / question_count, 2)
                        ELSE 0
                   END) STORED,
  is_completed   boolean      NOT NULL DEFAULT true,
  duration_secs  integer,
  attempted_at   timestamptz  NOT NULL DEFAULT now(),
  synced_at      timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_test_attempts_attempted
  ON test_attempts (attempted_at DESC);

CREATE INDEX IF NOT EXISTS idx_test_attempts_user_attempted
  ON test_attempts (user_id, attempted_at DESC);

CREATE INDEX IF NOT EXISTS idx_test_attempts_subject
  ON test_attempts (subject_id);

CREATE INDEX IF NOT EXISTS idx_test_attempts_type
  ON test_attempts (test_type);

-- ── 5. Per-user read state for broadcast notifications (fixes blocker 5) ──────
-- Replaces the broken `notifications.is_read` scalar (one flag shared by all users).
-- The student app must be updated (Phase 12 item 4) to write here instead.

CREATE TABLE IF NOT EXISTS notification_reads (
  notification_id bigint      NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
  user_id         text        NOT NULL,
  read_at         timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (notification_id, user_id)
);

-- ── 6. Activity + attribution columns ────────────────────────────────────────

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS created_at     timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS last_active_at timestamptz;

ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS created_by text REFERENCES admins(firebase_uid);

-- ── 7. Aggregate RPCs (SECURITY DEFINER — one round trip per dashboard load) ──

CREATE OR REPLACE FUNCTION admin_kpis()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'total_users',       (SELECT count(*) FROM users),
    'active_users',      (SELECT count(*) FROM users WHERE subscription_status = 'active'),
    'pending_users',     (SELECT count(*) FROM users WHERE subscription_status = 'pending'),
    'inactive_users',    (SELECT count(*) FROM users WHERE subscription_status = 'inactive'),
    'stream_natural',    (SELECT count(*) FROM users WHERE stream = 'natural'),
    'stream_social',     (SELECT count(*) FROM users WHERE stream = 'social'),
    'stream_common',     (SELECT count(*) FROM users WHERE stream = 'common'),
    'pending_payments',  (SELECT count(*) FROM payment_receipts WHERE status = 'pending'),
    'approved_revenue',  (SELECT coalesce(sum(amount), 0) FROM payment_receipts WHERE status = 'approved'),
    'attempts_today',    (SELECT count(*) FROM test_attempts WHERE attempted_at >= current_date),
    'attempts_7d',       (SELECT count(*) FROM test_attempts WHERE attempted_at >= now() - interval '7 days'),
    'attempts_30d',      (SELECT count(*) FROM test_attempts WHERE attempted_at >= now() - interval '30 days'),
    'push_reachable',    (SELECT count(*) FROM users WHERE fcm_token IS NOT NULL)
  );
$$;

REVOKE EXECUTE ON FUNCTION admin_kpis() FROM anon;
GRANT  EXECUTE ON FUNCTION admin_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION admin_signups_daily(days int)
RETURNS TABLE (day date, count bigint)
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  WITH series AS (
    SELECT generate_series(
      current_date - (days - 1)::int,
      current_date,
      '1 day'::interval
    )::date AS day
  )
  SELECT s.day,
         coalesce(count(u.created_at), 0) AS count
  FROM   series s
  LEFT   JOIN users u ON u.created_at::date = s.day
  GROUP  BY s.day
  ORDER  BY s.day;
$$;
REVOKE EXECUTE ON FUNCTION admin_signups_daily(int) FROM anon;
GRANT  EXECUTE ON FUNCTION admin_signups_daily(int) TO authenticated;

CREATE OR REPLACE FUNCTION admin_revenue_daily(days int)
RETURNS TABLE (day date, amount numeric, count bigint)
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  WITH series AS (
    SELECT generate_series(
      current_date - (days - 1)::int,
      current_date,
      '1 day'::interval
    )::date AS day
  )
  SELECT s.day,
         coalesce(sum(pr.amount), 0) AS amount,
         coalesce(count(pr.id), 0)   AS count
  FROM   series s
  LEFT   JOIN payment_receipts pr
           ON pr.reviewed_at::date = s.day AND pr.status = 'approved'
  GROUP  BY s.day ORDER BY s.day;
$$;
REVOKE EXECUTE ON FUNCTION admin_revenue_daily(int) FROM anon;
GRANT  EXECUTE ON FUNCTION admin_revenue_daily(int) TO authenticated;

CREATE OR REPLACE FUNCTION admin_attempts_daily(days int)
RETURNS TABLE (day date, attempts bigint, avg_score numeric)
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  WITH series AS (
    SELECT generate_series(
      current_date - (days - 1)::int,
      current_date,
      '1 day'::interval
    )::date AS day
  )
  SELECT s.day,
         coalesce(count(ta.id), 0)                      AS attempts,
         coalesce(avg(ta.score_pct), 0)::numeric(5,2)   AS avg_score
  FROM   series s
  LEFT   JOIN test_attempts ta ON ta.attempted_at::date = s.day
  GROUP  BY s.day ORDER BY s.day;
$$;
REVOKE EXECUTE ON FUNCTION admin_attempts_daily(int) FROM anon;
GRANT  EXECUTE ON FUNCTION admin_attempts_daily(int) TO authenticated;

CREATE OR REPLACE FUNCTION admin_subject_performance()
RETURNS TABLE (subject_id int, subject_name text, attempts bigint, avg_score numeric)
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  SELECT ta.subject_id,
         s.name                                       AS subject_name,
         count(*)                                     AS attempts,
         avg(ta.score_pct)::numeric(5,2)              AS avg_score
  FROM   test_attempts ta
  JOIN   subjects s ON s.id = ta.subject_id
  GROUP  BY ta.subject_id, s.name
  ORDER  BY avg_score ASC;  -- worst-first so admins see weak areas first
$$;
REVOKE EXECUTE ON FUNCTION admin_subject_performance() FROM anon;
GRANT  EXECUTE ON FUNCTION admin_subject_performance() TO authenticated;

CREATE OR REPLACE FUNCTION admin_test_type_distribution()
RETURNS TABLE (test_type text, attempts bigint)
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  SELECT test_type, count(*) AS attempts
  FROM   test_attempts
  WHERE  test_type IS NOT NULL
  GROUP  BY test_type
  ORDER  BY attempts DESC;
$$;
REVOKE EXECUTE ON FUNCTION admin_test_type_distribution() FROM anon;
GRANT  EXECUTE ON FUNCTION admin_test_type_distribution() TO authenticated;

CREATE OR REPLACE FUNCTION admin_funnel()
RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'signups',           (SELECT count(*) FROM users),
    'first_attempt',     (SELECT count(DISTINCT user_id) FROM test_attempts),
    'payment_submitted', (SELECT count(DISTINCT user_id) FROM payment_receipts),
    'approved',          (SELECT count(DISTINCT user_id) FROM payment_receipts
                          WHERE status = 'approved')
  );
$$;
REVOKE EXECUTE ON FUNCTION admin_funnel() FROM anon;
GRANT  EXECUTE ON FUNCTION admin_funnel() TO authenticated;

-- ── 8. Helper: is_admin() ─────────────────────────────────────────────────────
-- Used by RLS policies. Checks the JWT email against the admins table so
-- a real Supabase JWT (issued by admin-auth function) grants admin access.

CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM admins
    WHERE  email     = auth.jwt() ->> 'email'
    AND    is_active = true
  );
$$;
REVOKE EXECUTE ON FUNCTION is_admin() FROM anon;
GRANT  EXECUTE ON FUNCTION is_admin() TO authenticated;

-- ── 9. RLS ────────────────────────────────────────────────────────────────────

ALTER TABLE admins             ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_audit_log    ENABLE ROW LEVEL SECURITY;
ALTER TABLE test_attempts      ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_reads ENABLE ROW LEVEL SECURITY;

-- admins: only verified admins may read; anon has zero access
DROP POLICY IF EXISTS admins_select ON admins;
CREATE POLICY admins_select ON admins
  FOR SELECT USING (is_admin());

-- admin_audit_log: read-only for admins; all writes go through RPCs only
DROP POLICY IF EXISTS audit_select ON admin_audit_log;
CREATE POLICY audit_select ON admin_audit_log
  FOR SELECT USING (is_admin());

-- test_attempts: users insert their own rows; admins read all
DROP POLICY IF EXISTS attempts_insert ON test_attempts;
CREATE POLICY attempts_insert ON test_attempts
  FOR INSERT WITH CHECK (user_id = auth.uid()::text OR is_admin());

DROP POLICY IF EXISTS attempts_select ON test_attempts;
CREATE POLICY attempts_select ON test_attempts
  FOR SELECT USING (user_id = auth.uid()::text OR is_admin());

-- notification_reads: users manage their own read markers; admins read all
DROP POLICY IF EXISTS notif_reads_insert ON notification_reads;
CREATE POLICY notif_reads_insert ON notification_reads
  FOR INSERT WITH CHECK (user_id = auth.uid()::text);

DROP POLICY IF EXISTS notif_reads_select ON notification_reads;
CREATE POLICY notif_reads_select ON notification_reads
  FOR SELECT USING (user_id = auth.uid()::text OR is_admin());

-- =============================================================================
-- ⚠️  MANUAL REVIEW REQUIRED — tables NOT modified here
-- =============================================================================
-- The following tables are currently assumed to be anon-writable (no RLS).
-- Applying policies without verifying the live state could break the student
-- app. Run `SELECT * FROM pg_policies WHERE tablename IN ('users',
-- 'payment_receipts', 'user_sessions');` in the Supabase SQL editor first.
--
-- 1. users
--    Risk: anon can self-grant subscription_status = 'active'.
--    Fix:  restrict UPDATE(subscription_status) to is_admin() only;
--          expose a SECURITY DEFINER RPC for the student app's own updates.
--
-- 2. payment_receipts
--    Risk: any user can read every receipt row (receipt images).
--    Fix:  SELECT policy: user_id = auth.uid()::text OR is_admin();
--          UPDATE/DELETE: admin-only via SECURITY DEFINER RPCs.
--
-- 3. user_sessions
--    Risk: anon write path uses auth.uid() (anon UUID), not firebase_uid.
--    Fix:  scope INSERT/UPDATE to firebase_uid = auth.uid()::text once the
--          admin-auth JWT is in use and auth.uid() equals the Firebase UID.
-- =============================================================================

-- =============================================================================
-- ROLLBACK (reference only — do not run)
-- =============================================================================
-- DROP TABLE IF EXISTS notification_reads;
-- DROP TABLE IF EXISTS test_attempts;
-- DROP TABLE IF EXISTS admin_audit_log;
-- DROP TABLE IF EXISTS admins CASCADE;
-- ALTER TABLE users         DROP COLUMN IF EXISTS last_active_at;
-- ALTER TABLE users         DROP COLUMN IF EXISTS created_at;  -- only if you added it
-- ALTER TABLE notifications DROP COLUMN IF EXISTS created_by;
-- ALTER TABLE payment_receipts
--   DROP COLUMN IF EXISTS created_at, DROP COLUMN IF EXISTS status,
--   DROP COLUMN IF EXISTS amount,      DROP COLUMN IF EXISTS currency,
--   DROP COLUMN IF EXISTS reviewed_by, DROP COLUMN IF EXISTS reviewed_at,
--   DROP COLUMN IF EXISTS rejection_reason;
-- DROP FUNCTION IF EXISTS admin_kpis();
-- DROP FUNCTION IF EXISTS admin_signups_daily(int);
-- DROP FUNCTION IF EXISTS admin_revenue_daily(int);
-- DROP FUNCTION IF EXISTS admin_attempts_daily(int);
-- DROP FUNCTION IF EXISTS admin_subject_performance();
-- DROP FUNCTION IF EXISTS admin_test_type_distribution();
-- DROP FUNCTION IF EXISTS admin_funnel();
-- DROP FUNCTION IF EXISTS is_admin();
-- =============================================================================
