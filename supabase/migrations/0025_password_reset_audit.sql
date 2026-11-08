-- =============================================================================
-- Migration 0025: Student Password Reset Audit Log & Policies
-- =============================================================================
-- Safe to run against production database.
-- Creates an immutable append-only audit trail for admin-initiated password resets.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.password_reset_audit_logs (
    id         bigserial   PRIMARY KEY,
    admin_id   text        NOT NULL,
    student_id text        NOT NULL,
    action     text        NOT NULL DEFAULT 'admin_reset_password',
    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.password_reset_audit_logs IS
  'Append-only audit trail for admin-initiated student password resets. Never stores temporary passwords or password hashes.';

CREATE INDEX IF NOT EXISTS idx_password_reset_audit_student
  ON public.password_reset_audit_logs (student_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_password_reset_audit_admin
  ON public.password_reset_audit_logs (admin_id, created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.password_reset_audit_logs ENABLE ROW LEVEL SECURITY;

-- 1. SELECT policy: only active administrators may read audit logs
DROP POLICY IF EXISTS password_reset_audit_select ON public.password_reset_audit_logs;
CREATE POLICY password_reset_audit_select ON public.password_reset_audit_logs
  FOR SELECT USING (public.is_admin());

-- 2. INSERT policy: allow service role (Edge Functions) and authenticated administrators
DROP POLICY IF EXISTS password_reset_audit_insert ON public.password_reset_audit_logs;
CREATE POLICY password_reset_audit_insert ON public.password_reset_audit_logs
  FOR INSERT WITH CHECK (true);

-- Ensure anon has no access
REVOKE ALL ON TABLE public.password_reset_audit_logs FROM anon;
GRANT SELECT ON TABLE public.password_reset_audit_logs TO authenticated;

