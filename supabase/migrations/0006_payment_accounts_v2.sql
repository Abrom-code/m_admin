-- =============================================================================
-- 0006_payment_accounts_v2.sql
-- Adds holder/title fields per payment method, renames payment_awash →
-- payment_abyssinia, and adds a JSON bucket for extra payment accounts.
-- Safe to re-run (all statements are idempotent).
-- =============================================================================

BEGIN;

-- 1. Rename the awash key → abyssinia (copy value, delete old)
INSERT INTO public.app_config (key, value)
  SELECT 'payment_abyssinia', value
  FROM   public.app_config
  WHERE  key = 'payment_awash'
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

DELETE FROM public.app_config WHERE key = 'payment_awash';

-- 2. Add holder/title keys for every built-in method (empty by default)
INSERT INTO public.app_config (key, value) VALUES
  ('payment_cbe_birr_holder',    ''),
  ('payment_telebirr_holder',    ''),
  ('payment_abyssinia_holder',   ''),
  ('payment_mpesa_holder',       ''),
  -- JSON array: [{"key":"boa","label":"BOA","account":"...","holder":"..."}]
  ('payment_extra_accounts',     '[]')
ON CONFLICT (key) DO NOTHING;

COMMIT;
