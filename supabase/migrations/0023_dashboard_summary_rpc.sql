-- =============================================================================
-- 0023_dashboard_summary_rpc.sql
-- Lightweight server-side aggregation for the admin dashboard.
-- Eliminates fetching unbounded rows and summing/counting in Dart memory.
-- =============================================================================

CREATE OR REPLACE FUNCTION rpc_get_dashboard_summary()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_users bigint := 0;
  v_paid_users bigint := 0;
  v_pending_payments bigint := 0;
  v_new_users_week bigint := 0;
  v_total_revenue numeric := 0;
  v_reported_count bigint := 0;
  v_note_reviewers_count bigint := 0;
  v_note_reviews_count bigint := 0;
BEGIN
  -- 1. Users counts
  SELECT count(*) INTO v_total_users FROM users;
  SELECT count(*) INTO v_paid_users FROM users WHERE subscription_status = 'active';
  SELECT count(*) INTO v_new_users_week FROM users WHERE created_at >= (now() - interval '7 days');

  -- 2. Payment receipts aggregations
  SELECT count(*) INTO v_pending_payments FROM payment_receipts WHERE status = 'pending';
  SELECT coalesce(sum(amount), 0) INTO v_total_revenue FROM payment_receipts WHERE status = 'approved';

  -- 3. Question reports count (safe if table exists)
  BEGIN
    SELECT count(*) INTO v_reported_count FROM question_reports WHERE status = 'pending';
  EXCEPTION WHEN OTHERS THEN
    v_reported_count := 0;
  END;

  -- 4. Note reviews & reviewers count (safe if table exists)
  BEGIN
    SELECT count(*), count(DISTINCT user_id)
    INTO v_note_reviews_count, v_note_reviewers_count
    FROM note_ratings;
  EXCEPTION WHEN OTHERS THEN
    v_note_reviews_count := 0;
    v_note_reviewers_count := 0;
  END;

  RETURN jsonb_build_object(
    'total_users', v_total_users,
    'paid_users', v_paid_users,
    'pending_payments', v_pending_payments,
    'new_users_this_week', v_new_users_week,
    'total_revenue', v_total_revenue,
    'reported_questions_count', v_reported_count,
    'note_reviewers_count', v_note_reviewers_count,
    'note_reviews_count', v_note_reviews_count
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_get_dashboard_summary() FROM anon, public;
GRANT  EXECUTE ON FUNCTION rpc_get_dashboard_summary() TO authenticated;
