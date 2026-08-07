-- =============================================================================
-- 0004_payment_receipts_fk.sql
-- Add FK from payment_receipts.user_id → users.id so PostgREST can resolve
-- the users!inner(...) join used by the admin payment screen.
--
-- NOT VALID: skips checking existing rows, so orphaned receipts that
-- pre-date this migration won't cause the ALTER to fail.
-- =============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE  constraint_name = 'payment_receipts_user_id_fkey'
    AND    table_name      = 'payment_receipts'
    AND    table_schema    = 'public'
  ) THEN
    ALTER TABLE payment_receipts
      ADD CONSTRAINT payment_receipts_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES users(id)
      NOT VALID;
  END IF;
END $$;
