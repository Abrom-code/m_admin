-- =============================================================================
-- 0011_fix_challenge_leaderboard_rpcs.sql
-- Fix challenge RPC functions to remove obsolete set_id references
-- Questions now directly attach to leaderboard_challenges via challenge_id
-- =============================================================================

BEGIN;

-- 1. Get Leaderboard for a Challenge (Without obsolete set_id join)
CREATE OR REPLACE FUNCTION public.rpc_get_leaderboard(
  p_challenge_id uuid,
  p_stream text DEFAULT NULL,
  p_limit int DEFAULT 100
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_questions int := 0;
  v_rows jsonb;
BEGIN
  -- Count questions directly attached to this challenge
  SELECT count(*)::int INTO v_total_questions
  FROM public.challenge_questions
  WHERE challenge_id = p_challenge_id;

  SELECT jsonb_agg(
    jsonb_build_object(
      'rank', lb.rank,
      'user_id', lb.user_id,
      'first_name', u.first_name,
      'last_name', coalesce(u.last_name, ''),
      'stream', lb.stream,
      'score', lb.score,
      'total_time_seconds', lb.total_time_seconds,
      'correct_count', lb.score,
      'incorrect_count', (
        SELECT count(*)::int FROM public.challenge_answers ans
        JOIN public.challenge_attempts att ON att.id = ans.attempt_id
        WHERE att.challenge_id = p_challenge_id AND att.user_id = lb.user_id AND ans.is_correct = false
      ),
      'not_done_count', greatest(0, v_total_questions - (
        SELECT count(*)::int FROM public.challenge_answers ans
        JOIN public.challenge_attempts att ON att.id = ans.attempt_id
        WHERE att.challenge_id = p_challenge_id AND att.user_id = lb.user_id
      ))
    ) ORDER BY lb.rank ASC
  ) INTO v_rows
  FROM public.v_challenge_leaderboard lb
  JOIN public.users u ON u.id = lb.user_id
  WHERE lb.challenge_id = p_challenge_id
    AND (p_stream IS NULL OR lower(lb.stream) = lower(p_stream))
  LIMIT coalesce(p_limit, 100);

  RETURN coalesce(v_rows, '[]'::jsonb);
END;
$$;

-- 2. Start Challenge Attempt (Questions directly by challenge_id)
CREATE OR REPLACE FUNCTION public.rpc_start_challenge_attempt(
  p_challenge_id uuid,
  p_user_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_challenge record;
  v_user record;
  v_attempt record;
  v_questions jsonb;
BEGIN
  -- Check user & active premium status
  SELECT * INTO v_user FROM public.users WHERE id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found';
  END IF;

  IF v_user.subscription_status != 'active' OR (v_user.subscription_expires_at IS NOT NULL AND v_user.subscription_expires_at < now()) THEN
    RAISE EXCEPTION 'premium_required';
  END IF;

  -- Check challenge exists and is live
  SELECT * INTO v_challenge FROM public.leaderboard_challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'challenge_not_found';
  END IF;

  IF v_challenge.status != 'live' THEN
    IF v_challenge.status = 'scheduled' THEN
      RAISE EXCEPTION 'not_open_yet';
    ELSE
      RAISE EXCEPTION 'challenge_closed';
    END IF;
  END IF;

  IF v_challenge.ends_at IS NOT NULL AND now() > v_challenge.ends_at THEN
    RAISE EXCEPTION 'challenge_ended';
  END IF;

  -- Check stream audience match
  IF v_challenge.audience != 'both' AND lower(v_challenge.audience) != lower(coalesce(v_user.stream, '')) THEN
    RAISE EXCEPTION 'audience_mismatch';
  END IF;

  -- Get or create attempt stamped with user's stream
  SELECT * INTO v_attempt FROM public.challenge_attempts
  WHERE challenge_id = p_challenge_id AND user_id = p_user_id;

  IF NOT FOUND THEN
    INSERT INTO public.challenge_attempts (challenge_id, user_id, stream, started_at, status)
    VALUES (p_challenge_id, p_user_id, coalesce(v_user.stream, 'natural'), now(), 'in_progress')
    RETURNING * INTO v_attempt;
  END IF;

  IF v_attempt.status = 'submitted' THEN
    RAISE EXCEPTION 'already_submitted';
  END IF;

  -- Return questions WITHOUT correct_choice or explanation
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', q.id,
      'order_index', q.order_index,
      'question_text', q.question_text,
      'choices', q.choices,
      'image_url', q.image_url
    ) ORDER BY q.order_index ASC
  ) INTO v_questions
  FROM public.challenge_questions q
  WHERE q.challenge_id = p_challenge_id;

  RETURN jsonb_build_object(
    'attempt_id', v_attempt.id,
    'challenge_id', v_challenge.id,
    'title', v_challenge.title,
    'duration_seconds', v_challenge.duration_seconds,
    'started_at', v_attempt.started_at,
    'ends_at', v_challenge.ends_at,
    'questions', coalesce(v_questions, '[]'::jsonb)
  );
END;
$$;

-- 3. Get Challenge Answers & Review (Questions directly by challenge_id)
CREATE OR REPLACE FUNCTION public.rpc_get_challenge_answers(
  p_challenge_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_challenge record;
  v_questions jsonb;
BEGIN
  SELECT * INTO v_challenge FROM public.leaderboard_challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'challenge_not_found';
  END IF;

  IF v_challenge.status NOT IN ('closed', 'archived') THEN
    RAISE EXCEPTION 'challenge_not_closed';
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', q.id,
      'challenge_id', q.challenge_id,
      'order_index', q.order_index,
      'question_text', q.question_text,
      'choices', q.choices,
      'correct_choice', q.correct_choice,
      'explanation', coalesce(q.explanation, ''),
      'image_url', q.image_url
    ) ORDER BY q.order_index ASC
  ) INTO v_questions
  FROM public.challenge_questions q
  WHERE q.challenge_id = v_challenge.id;

  RETURN jsonb_build_object(
    'challenge_id', v_challenge.id,
    'subject_id', v_challenge.subject_id,
    'title', v_challenge.title,
    'audience', v_challenge.audience,
    'questions', coalesce(v_questions, '[]'::jsonb)
  );
END;
$$;

COMMIT;
