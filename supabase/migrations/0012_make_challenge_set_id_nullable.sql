-- =============================================================================
-- 0012_make_challenge_set_id_nullable.sql
-- Make set_id nullable in leaderboard_challenges so challenges can be saved
-- as drafts before questions are added.
-- =============================================================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'leaderboard_challenges' AND column_name = 'set_id'
  ) THEN
    ALTER TABLE public.leaderboard_challenges ALTER COLUMN set_id DROP NOT NULL;
  END IF;
END $$;
