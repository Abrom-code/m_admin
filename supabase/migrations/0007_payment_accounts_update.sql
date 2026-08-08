-- ── Rename payment_awash → payment_abyssinia ──────────────────────────

UPDATE public.app_config
SET key = 'payment_abyssinia'
WHERE key = 'payment_awash';

-- ── Add holder name fields for all payment methods ─────────────────────

INSERT INTO public.app_config (key, value)
VALUES
  ('payment_cbe_birr_holder', 'Beshasha Desmon'),
  ('payment_telebirr_holder', 'Beshasha Desmon'),
  ('payment_abyssinia_holder', 'Beshasha Desmon'),
  ('payment_mpesa_holder', 'Beshasha Desmon')
ON CONFLICT (key) DO NOTHING;

-- ── Add payment_extra_accounts for dynamic additional accounts ─────────

INSERT INTO public.app_config (key, value)
VALUES ('payment_extra_accounts', '[]')
ON CONFLICT (key) DO NOTHING;

COMMENT ON COLUMN public.app_config.key IS
  'Config keys: payment_{method}, payment_{method}_holder, payment_extra_accounts (JSON array), webhook_secret, trial_count, subscription_price';
