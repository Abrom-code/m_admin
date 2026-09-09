-- 0016_fix_live_challenge_start_attempt.sql
-- Fix: Prevent "challenge_not_started" / "not_open_yet" error when an admin makes a scheduled challenge live now.
-- 1. Auto-heals starts_at in the database if challenge status is 'live' and starts_at is in the future.
-- 2. Ensures only 'scheduled' challenges check starts_at.
-- 3. Performs a one-time healing update on all currently live challenges with future starts_at.

-- One-time repair for any existing live challenges in database
UPDATE public.leaderboard_challenges
SET starts_at = now() - interval '10 seconds'
WHERE status = 'live' AND starts_at IS NOT NULL AND starts_at > now();

-- Update rpc_start_attempt
CREATE OR REPLACE FUNCTION public.rpc_start_attempt(
  p_challenge_id uuid,
  p_user_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_challenge record;
  v_user record;
  v_attempt record;
  v_questions jsonb;
  v_target_uid uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  v_target_uid := p_user_id::uuid;
  IF auth.uid() != v_target_uid AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  SELECT * INTO v_challenge FROM public.leaderboard_challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'challenge_not_found';
  END IF;

  IF v_challenge.status NOT IN ('live', 'scheduled') THEN
    RAISE EXCEPTION 'challenge_not_active';
  END IF;

  -- Auto-heal starts_at if challenge is live but starts_at is in the future
  IF v_challenge.status = 'live' AND v_challenge.starts_at IS NOT NULL AND now() < v_challenge.starts_at THEN
    UPDATE public.leaderboard_challenges
    SET starts_at = now() - interval '10 seconds'
    WHERE id = v_challenge.id;
    v_challenge.starts_at := now() - interval '10 seconds';
  END IF;

  -- Only scheduled challenges block attempts before starts_at
  IF v_challenge.status = 'scheduled' AND v_challenge.starts_at IS NOT NULL AND now() < v_challenge.starts_at THEN
    RAISE EXCEPTION 'challenge_not_started';
  END IF;

  IF v_challenge.ends_at IS NOT NULL AND now() > v_challenge.ends_at THEN
    RAISE EXCEPTION 'challenge_ended';
  END IF;

  SELECT * INTO v_user FROM public.users WHERE id = v_target_uid;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found';
  END IF;

  IF v_challenge.audience != 'both' AND lower(v_challenge.audience) != lower(coalesce(v_user.stream, '')) THEN
    RAISE EXCEPTION 'stream_not_eligible';
  END IF;

  INSERT INTO public.challenge_attempts (
    challenge_id, user_id, stream, started_at, status
  )
  VALUES (
    v_challenge.id, v_user.id, coalesce(v_user.stream, 'natural'), now(), 'in_progress'
  )
  ON CONFLICT (challenge_id, user_id)
  DO UPDATE SET started_at = challenge_attempts.started_at
  RETURNING * INTO v_attempt;

  IF v_attempt.status = 'submitted' THEN
    RAISE EXCEPTION 'already_submitted';
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', q.id,
      'order_index', q.order_index,
      'question_text', q.question_text,
      'choices', q.choices,
      'image_url', q.image_url,
      'passage_id', q.passage_id
    ) ORDER BY q.order_index ASC
  ) INTO v_questions
  FROM public.challenge_questions q
  WHERE q.challenge_id = v_challenge.id;

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

-- Update rpc_start_challenge_attempt
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

  -- Check challenge exists
  SELECT * INTO v_challenge FROM public.leaderboard_challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'challenge_not_found';
  END IF;

  -- Auto-heal starts_at if challenge is live but starts_at is in the future
  IF v_challenge.status = 'live' AND v_challenge.starts_at IS NOT NULL AND now() < v_challenge.starts_at THEN
    UPDATE public.leaderboard_challenges
    SET starts_at = now() - interval '10 seconds'
    WHERE id = v_challenge.id;
    v_challenge.starts_at := now() - interval '10 seconds';
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
