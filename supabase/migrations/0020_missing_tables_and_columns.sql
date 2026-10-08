-- ==============================================================================
-- 0020_missing_tables_and_columns.sql
-- Description: Adds is_premium to challenges, creates notification_dismissals table,
--              and cleans up unused tables.
-- ==============================================================================

-- 1. Add is_premium to challenge tables
ALTER TABLE IF EXISTS public.leaderboard_challenges
ADD COLUMN IF NOT EXISTS is_premium BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE IF EXISTS public.challenge_question_sets
ADD COLUMN IF NOT EXISTS is_premium BOOLEAN NOT NULL DEFAULT false;

-- 2. Create missing notification_dismissals table
CREATE TABLE IF NOT EXISTS public.notification_dismissals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  notification_id TEXT NOT NULL,
  dismissed_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, notification_id)
);

CREATE INDEX IF NOT EXISTS idx_notif_dismissals_user
  ON public.notification_dismissals(user_id);

-- Enable RLS
ALTER TABLE public.notification_dismissals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own dismissals" ON public.notification_dismissals;
CREATE POLICY "Users can manage own dismissals"
  ON public.notification_dismissals
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 3. Drop unused table
DROP TABLE IF EXISTS public.challenge_rewards;
