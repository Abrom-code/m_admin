-- 0024_challenge_review_policy.sql
-- Migration: Add review_policy to leaderboard_challenges and check constraint
-- Policies:
--   1. 'when_closed' (or 'closed'): questions/answers can ONLY be reviewed after the challenge time has closed/ended.
--   2. 'on_completion' (or 'completed'): [DEFAULT] questions/answers can be reviewed immediately after completing the attempt.

-- 1. Add review_policy column to public.leaderboard_challenges
ALTER TABLE public.leaderboard_challenges
ADD COLUMN IF NOT EXISTS review_policy text NOT NULL DEFAULT 'on_completion';

-- 2. Add check constraint to ensure only valid review policies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'leaderboard_challenges_review_policy_check'
  ) THEN
    ALTER TABLE public.leaderboard_challenges
    ADD CONSTRAINT leaderboard_challenges_review_policy_check
    CHECK (review_policy IN ('on_completion', 'when_closed', 'completed', 'closed'));
  END IF;
END $$;

COMMENT ON COLUMN public.leaderboard_challenges.review_policy IS
'Policy for reviewing questions and correct answers: "on_completion" (default: review immediately after submitting attempt) or "when_closed" (review only after challenge time has closed/ended).';
