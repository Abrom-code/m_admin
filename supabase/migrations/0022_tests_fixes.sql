-- ==============================================================================
-- 0022_tests_fixes.sql
-- Description: Sets safe default values for tests table columns to avoid NOT NULL
--              violations when inserting or updating tests via the admin app.
-- ==============================================================================

-- 1. Ensure question_count has a default of 0 and is not null
ALTER TABLE IF EXISTS public.tests
  ALTER COLUMN question_count SET DEFAULT 0;

-- 2. Ensure is_premium has a default of true (or false)
ALTER TABLE IF EXISTS public.tests
  ALTER COLUMN is_premium SET DEFAULT true;

-- 3. Ensure status has a default of 'draft'
ALTER TABLE IF EXISTS public.tests
  ALTER COLUMN status SET DEFAULT 'draft';
