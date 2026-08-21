-- =============================================================================
-- 0009_subscription_plans.sql
-- Adds subscription plan & expiration tracking.
-- Run in Supabase SQL Editor. Every statement is idempotent.
-- =============================================================================

BEGIN;

-- 1. users: plan & expiry columns
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS subscription_plan TEXT,
  ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ;

-- 2. payment_receipts: plan details submitted by student
ALTER TABLE public.payment_receipts
  ADD COLUMN IF NOT EXISTS plan_key TEXT,
  ADD COLUMN IF NOT EXISTS plan_duration_months INT;

-- 3. Admin-managed plan prices in app_config
INSERT INTO public.app_config (key, value) VALUES
  ('plan_price_6_months', '150'),
  ('plan_price_1_year',   '250'),
  ('plan_price_2_years',  '400'),
  ('plan_price_3_years',  '550'),
  ('plan_price_4_years',  '650')
ON CONFLICT (key) DO NOTHING;

COMMIT;
