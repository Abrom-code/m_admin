-- =============================================================================
-- 0002_payment_rpcs.sql
-- Atomic payment approve/reject RPCs for the admin app (Phase 7).
-- These run inside a single transaction so a crash mid-action cannot leave
-- the DB in a half-approved state.
-- =============================================================================

-- ── admin_approve_payment ─────────────────────────────────────────────────────
-- Steps (atomic):
--   1. Lock the receipt row and check it is still 'pending' (double-action guard)
--   2. Update payment_receipts → approved
--   3. Update users → subscription_status = 'active'
--   4. Insert admin_audit_log row
-- The push notification is sent by the Dart caller AFTER this RPC succeeds,
-- so a push failure never rolls back DB state.

CREATE OR REPLACE FUNCTION admin_approve_payment(
  p_receipt_id  bigint,
  p_user_id     text,
  p_admin_uid   text,
  p_amount      numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_receipt   payment_receipts%ROWTYPE;
  v_before    jsonb;
  v_after     jsonb;
BEGIN
  -- Lock the row for the duration of this transaction.
  SELECT * INTO v_receipt
  FROM   payment_receipts
  WHERE  id = p_receipt_id
  FOR    UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'receipt_not_found' USING HINT = p_receipt_id::text;
  END IF;

  -- Double-action guard: abort if already reviewed.
  IF v_receipt.status <> 'pending' THEN
    RAISE EXCEPTION 'already_reviewed'
      USING HINT = coalesce(v_receipt.reviewed_by, 'unknown');
  END IF;

  v_before := to_jsonb(v_receipt);

  -- 1. Update the receipt.
  UPDATE payment_receipts
  SET    status      = 'approved',
         reviewed_by = p_admin_uid,
         reviewed_at = now(),
         amount      = coalesce(p_amount, amount, 250)
  WHERE  id = p_receipt_id;

  -- 2. Activate the user.
  UPDATE users
  SET    subscription_status = 'active'
  WHERE  id = p_user_id;

  -- 3. Capture the after state and write the audit row.
  SELECT to_jsonb(pr) INTO v_after
  FROM   payment_receipts pr WHERE id = p_receipt_id;

  INSERT INTO admin_audit_log
    (admin_uid, action, entity_type, entity_id, before, after)
  VALUES
    (p_admin_uid, 'approve_payment', 'payment_receipt',
     p_receipt_id::text, v_before, v_after);

  RETURN jsonb_build_object('ok', true, 'receipt_id', p_receipt_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION admin_approve_payment(bigint,text,text,numeric) FROM anon, public;
GRANT  EXECUTE ON FUNCTION admin_approve_payment(bigint,text,text,numeric) TO authenticated;

-- ── admin_reject_payment ──────────────────────────────────────────────────────
-- ⚠️  Writes subscription_status = 'inactive', NOT 'rejected'.
-- Reason: UserModel has three getters — isActive, isPending, isInactive — all
-- of which return false for the string 'rejected'. A rejected student would land
-- in a UI dead zone with no call to action. 'inactive' shows the upgrade prompt.
-- The rejection reason is stored in payment_receipts.rejection_reason and also
-- sent in the push payload so the student sees it in the notification.

CREATE OR REPLACE FUNCTION admin_reject_payment(
  p_receipt_id  bigint,
  p_user_id     text,
  p_admin_uid   text,
  p_reason      text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_receipt   payment_receipts%ROWTYPE;
  v_before    jsonb;
  v_after     jsonb;
BEGIN
  SELECT * INTO v_receipt
  FROM   payment_receipts
  WHERE  id = p_receipt_id
  FOR    UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'receipt_not_found' USING HINT = p_receipt_id::text;
  END IF;

  IF v_receipt.status <> 'pending' THEN
    RAISE EXCEPTION 'already_reviewed'
      USING HINT = coalesce(v_receipt.reviewed_by, 'unknown');
  END IF;

  v_before := to_jsonb(v_receipt);

  UPDATE payment_receipts
  SET    status           = 'rejected',
         reviewed_by      = p_admin_uid,
         reviewed_at      = now(),
         rejection_reason = p_reason
  WHERE  id = p_receipt_id;

  -- Write 'inactive' not 'rejected' — see comment above.
  UPDATE users
  SET    subscription_status = 'inactive'
  WHERE  id = p_user_id;

  SELECT to_jsonb(pr) INTO v_after
  FROM   payment_receipts pr WHERE id = p_receipt_id;

  INSERT INTO admin_audit_log
    (admin_uid, action, entity_type, entity_id, before, after, note)
  VALUES
    (p_admin_uid, 'reject_payment', 'payment_receipt',
     p_receipt_id::text, v_before, v_after, p_reason);

  RETURN jsonb_build_object('ok', true, 'receipt_id', p_receipt_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION admin_reject_payment(bigint,text,text,text) FROM anon, public;
GRANT  EXECUTE ON FUNCTION admin_reject_payment(bigint,text,text,text) TO authenticated;

-- =============================================================================
-- ROLLBACK (reference only)
-- =============================================================================
-- DROP FUNCTION IF EXISTS admin_approve_payment(bigint,text,text,numeric);
-- DROP FUNCTION IF EXISTS admin_reject_payment(bigint,text,text,text);
-- =============================================================================
