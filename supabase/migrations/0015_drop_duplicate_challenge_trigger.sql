-- 0015_drop_duplicate_challenge_trigger.sql
-- Drop the database trigger that was creating duplicate notification rows
-- on challenge status transitions.
-- The challenge-scheduler edge function is the single source of truth that
-- inserts the notification and sends the data-only FCM push notification.

DROP TRIGGER IF EXISTS trg_challenge_auto_notify ON public.leaderboard_challenges;
DROP FUNCTION IF EXISTS public.trg_fn_on_challenge_notify();
