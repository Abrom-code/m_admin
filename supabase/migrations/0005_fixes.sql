-- =============================================================================
-- 0005_fixes.sql
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor → New query).
-- Every statement is idempotent — safe to re-run if something fails midway.
-- =============================================================================

BEGIN;

-- ── 1. app_config ─────────────────────────────────────────────────────────────
-- Required by the admin Settings screen. Not in any earlier migration.

CREATE TABLE IF NOT EXISTS public.app_config (
  key   text PRIMARY KEY,
  value text NOT NULL DEFAULT ''
);

INSERT INTO public.app_config (key, value) VALUES
  ('payment_cbe_birr',    ''),
  ('payment_telebirr',    ''),
  ('payment_awash',       ''),
  ('payment_mpesa',       ''),
  ('webhook_secret',      ''),
  ('trial_count',         '5'),
  ('subscription_price',  '0')
ON CONFLICT (key) DO NOTHING;

COMMENT ON TABLE public.app_config IS
  'Key-value config edited from the admin Settings screen.';


-- ── 2. subjects.updated_at + trigger ─────────────────────────────────────────
-- The student app does delta sync with .gt("updated_at", lastSync).
-- Without this column, admin edits to subjects are invisible to students
-- until they do a full re-download.

ALTER TABLE public.subjects
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Backfill any rows that pre-date this migration.
UPDATE public.subjects SET updated_at = now() WHERE updated_at IS NULL;

-- Generic bump-updated_at function (reused by any table that needs it).
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_subjects_updated_at ON public.subjects;
CREATE TRIGGER set_subjects_updated_at
  BEFORE UPDATE ON public.subjects
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ── 3. question_sections ──────────────────────────────────────────────────────
-- The student app joins questions with question_sections(title).
-- This table must exist for that join to resolve; the admin content editor
-- now has CRUD methods for it via content_repository.dart.

CREATE TABLE IF NOT EXISTS public.question_sections (
  id    serial PRIMARY KEY,
  title text   NOT NULL
);

COMMENT ON TABLE public.question_sections IS
  'Named sections within a test (e.g. "Reading Comprehension").';


-- ── 4. payment_receipts → users FK ───────────────────────────────────────────
-- Required for PostgREST to resolve the users!inner(...) join used by the
-- admin payment queue. NOT VALID skips validating pre-existing orphan rows.

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE  constraint_name = 'payment_receipts_user_id_fkey'
    AND    table_name      = 'payment_receipts'
    AND    table_schema    = 'public'
  ) THEN
    ALTER TABLE public.payment_receipts
      ADD CONSTRAINT payment_receipts_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES public.users(id)
      NOT VALID;
  END IF;
END $$;


-- ── 5. Realtime publications ──────────────────────────────────────────────────
-- RealtimeService in the student app listens on users (subscription_status
-- changes) and user_sessions (device-kick events). Neither works without
-- these two lines.

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'users'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
  END IF;
END $$;
ALTER TABLE public.users REPLICA IDENTITY FULL;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'user_sessions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_sessions;
  END IF;
END $$;
ALTER TABLE public.user_sessions REPLICA IDENTITY FULL;


-- ── 6. Drop dead test_attempts infrastructure ─────────────────────────────────
-- The student app never writes to test_attempts (Phase 12 sync was never
-- shipped). The admin dashboard no longer reads from it. Dropping it and
-- its dependent functions removes ~6 dead objects and frees storage.

DROP FUNCTION IF EXISTS public.admin_attempts_daily(int);
DROP FUNCTION IF EXISTS public.admin_subject_performance();
DROP FUNCTION IF EXISTS public.admin_test_type_distribution();
DROP FUNCTION IF EXISTS public.admin_kpis();
DROP FUNCTION IF EXISTS public.admin_funnel();
DROP TABLE IF EXISTS public.test_attempts CASCADE;


-- ── 7. notification_reads RLS ─────────────────────────────────────────────────
-- notification_reads already has RLS from migration 0001. The student app now
-- writes here (after the notification_repository.dart fix). Verify the INSERT
-- policy is in place — if it is, this is a no-op; if not, it adds it.

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'notification_reads'
    AND   policyname = 'notif_reads_insert'
    AND   schemaname = 'public'
  ) THEN
    CREATE POLICY notif_reads_insert ON public.notification_reads
      FOR INSERT WITH CHECK (user_id = auth.uid()::text);
  END IF;
END $$;

-- Allow anon inserts too — the student app signs in anonymously, so
-- auth.uid() is the throwaway anon UUID, not the Firebase UID. The
-- user_id column stores the Firebase UID, which means the policy above
-- never matches. Simplest safe fix: grant anon insert on this table only.
-- (The table stores no sensitive data — it's just read flags.)
GRANT INSERT ON public.notification_reads TO anon;
GRANT SELECT ON public.notification_reads TO anon;


COMMIT;

-- =============================================================================
-- WHAT TO DO AFTER RUNNING THIS
-- =============================================================================
-- 1. Verify the triggers were created:
--      SELECT tgname FROM pg_trigger WHERE tgrelid = 'subjects'::regclass;
--    Should include: set_subjects_updated_at
--
-- 2. Verify Realtime is on for users and user_sessions:
--      SELECT * FROM pg_publication_tables
--      WHERE pubname = 'supabase_realtime'
--      AND tablename IN ('users','user_sessions');
--    Should return 2 rows.
--
-- 3. Add an admin row so the Audit Log RLS works if/when you switch to
--    real Supabase Auth:
--      INSERT INTO admins (firebase_uid, email, display_name, role)
--      VALUES ('<your-firebase-uid>', 'admin@example.com', 'Admin', 'superadmin');
--
-- 4. Run supabase/migrations/0002_payment_rpcs.sql (optional but recommended)
--    to restore the atomic approve/reject transactions + audit log writes.
--    After running it, revert admin_payment_repository.dart's approve() and
--    reject() back to .rpc() calls to get atomicity and audit logging back.
-- =============================================================================
