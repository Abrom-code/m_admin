-- =============================================================================
-- 0010_leaderboard_challenges.sql
-- Stream Challenges & Multi-Period Leaderboard System
-- Supports Draft -> Scheduled -> Live -> Closed -> Archived lifecycle,
-- automatic ranking, server-side scoring, premium checks, and manual reward grants.
-- =============================================================================

BEGIN;

-- 1. Question sets scoped to subjects
CREATE TABLE IF NOT EXISTS public.challenge_question_sets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id integer NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
    title text NOT NULL,
    created_by text REFERENCES public.admins(firebase_uid),
    created_at timestamptz NOT NULL DEFAULT now()
);

-- 2. Questions in a challenge set
CREATE TABLE IF NOT EXISTS public.challenge_questions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    set_id uuid NOT NULL REFERENCES public.challenge_question_sets(id) ON DELETE CASCADE,
    order_index int NOT NULL DEFAULT 1,
    question_text text NOT NULL,
    choices jsonb NOT NULL,
    correct_choice text NOT NULL,
    explanation text,
    image_url text
);

-- 3. Published challenge rounds
CREATE TABLE IF NOT EXISTS public.leaderboard_challenges (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    set_id uuid NOT NULL REFERENCES public.challenge_question_sets(id) ON DELETE CASCADE,
    subject_id integer NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
    audience text NOT NULL DEFAULT 'both' CHECK (audience IN ('natural', 'social', 'both')),
    title text NOT NULL,
    starts_at timestamptz,
    ends_at timestamptz,
    duration_seconds int NOT NULL DEFAULT 3600,
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'scheduled', 'live', 'closed', 'archived')),
    created_by text REFERENCES public.admins(firebase_uid),
    created_at timestamptz NOT NULL DEFAULT now()
);

-- 4. User attempts per challenge
CREATE TABLE IF NOT EXISTS public.challenge_attempts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id uuid NOT NULL REFERENCES public.leaderboard_challenges(id) ON DELETE CASCADE,
    user_id text NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    stream text NOT NULL,
    started_at timestamptz NOT NULL DEFAULT now(),
    submitted_at timestamptz,
    score int DEFAULT 0,
    total_time_seconds int DEFAULT 0,
    status text NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress','submitted','expired')),
    UNIQUE (challenge_id, user_id)
);

-- 5. Individual answers per question
CREATE TABLE IF NOT EXISTS public.challenge_answers (
    attempt_id uuid NOT NULL REFERENCES public.challenge_attempts(id) ON DELETE CASCADE,
    question_id uuid NOT NULL REFERENCES public.challenge_questions(id) ON DELETE CASCADE,
    selected_choice text,
    is_correct boolean DEFAULT false,
    answered_at timestamptz DEFAULT now(),
    PRIMARY KEY (attempt_id, question_id)
);

-- 6. Rewards granted by admin
CREATE TABLE IF NOT EXISTS public.challenge_rewards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id uuid REFERENCES public.leaderboard_challenges(id) ON DELETE SET NULL,
    user_id text NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    rank int,
    reward_type text NOT NULL,
    reward_value text,
    period text,
    period_start date,
    granted_by text REFERENCES public.admins(firebase_uid),
    granted_at timestamptz DEFAULT now()
);

-- ── Indexes ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_challenge_sets_subject ON public.challenge_question_sets(subject_id);
CREATE INDEX IF NOT EXISTS idx_challenge_questions_set ON public.challenge_questions(set_id, order_index);
CREATE INDEX IF NOT EXISTS idx_leaderboard_challenges_status_starts ON public.leaderboard_challenges(status, starts_at);
CREATE INDEX IF NOT EXISTS idx_leaderboard_challenges_audience ON public.leaderboard_challenges(audience);
CREATE INDEX IF NOT EXISTS idx_challenge_attempts_user_challenge ON public.challenge_attempts(user_id, challenge_id);
CREATE INDEX IF NOT EXISTS idx_challenge_attempts_challenge_stream ON public.challenge_attempts(challenge_id, stream, status);
CREATE INDEX IF NOT EXISTS idx_challenge_answers_attempt ON public.challenge_answers(attempt_id);
CREATE INDEX IF NOT EXISTS idx_challenge_rewards_user ON public.challenge_rewards(user_id);

-- ── Views ────────────────────────────────────────────────────────────────────

-- Per-challenge leaderboard (ranked per challenge and stream)
CREATE OR REPLACE VIEW public.v_challenge_leaderboard AS
SELECT
  a.challenge_id,
  a.stream,
  a.user_id,
  a.score,
  a.total_time_seconds,
  ROW_NUMBER() OVER (
    PARTITION BY a.challenge_id, a.stream
    ORDER BY a.score DESC, a.total_time_seconds ASC, a.submitted_at ASC
  ) AS rank
FROM public.challenge_attempts a
WHERE a.status = 'submitted';

-- Weekly leaderboard (Mon-Sun)
CREATE OR REPLACE VIEW public.v_challenge_leaderboard_weekly AS
SELECT
  a.user_id,
  a.stream,
  date_trunc('week', c.starts_at)::date AS period_start,
  sum(a.score)::int AS total_score,
  sum(a.total_time_seconds)::int AS total_time_seconds,
  count(*)::int AS challenges_taken,
  ROW_NUMBER() OVER (
    PARTITION BY a.stream, date_trunc('week', c.starts_at)
    ORDER BY sum(a.score) DESC, count(*) ASC, sum(a.total_time_seconds) ASC
  ) AS rank
FROM public.challenge_attempts a
JOIN public.leaderboard_challenges c ON c.id = a.challenge_id
WHERE a.status = 'submitted' AND c.starts_at IS NOT NULL
GROUP BY a.user_id, a.stream, date_trunc('week', c.starts_at);

-- Monthly leaderboard (Calendar month)
CREATE OR REPLACE VIEW public.v_challenge_leaderboard_monthly AS
SELECT
  a.user_id,
  a.stream,
  date_trunc('month', c.starts_at)::date AS period_start,
  sum(a.score)::int AS total_score,
  sum(a.total_time_seconds)::int AS total_time_seconds,
  count(*)::int AS challenges_taken,
  ROW_NUMBER() OVER (
    PARTITION BY a.stream, date_trunc('month', c.starts_at)
    ORDER BY sum(a.score) DESC, count(*) ASC, sum(a.total_time_seconds) ASC
  ) AS rank
FROM public.challenge_attempts a
JOIN public.leaderboard_challenges c ON c.id = a.challenge_id
WHERE a.status = 'submitted' AND c.starts_at IS NOT NULL
GROUP BY a.user_id, a.stream, date_trunc('month', c.starts_at);

-- ── RPC Functions ────────────────────────────────────────────────────────────

-- 1. Publish / Schedule Challenge (Admin)
CREATE OR REPLACE FUNCTION public.rpc_publish_challenge(
  p_challenge_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_audience text DEFAULT 'both',
  p_duration_seconds int DEFAULT 3600
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.leaderboard_challenges
  SET
    starts_at = p_starts_at,
    ends_at = p_ends_at,
    audience = p_audience,
    duration_seconds = p_duration_seconds,
    status = 'scheduled'
  WHERE id = p_challenge_id AND status = 'draft';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Challenge not found or not in draft status';
  END IF;

  RETURN jsonb_build_object('success', true, 'challenge_id', p_challenge_id);
END;
$$;

-- 2. Start Attempt (Student) — Authoritative Premium & Timing Gate
CREATE OR REPLACE FUNCTION public.rpc_start_attempt(
  p_challenge_id uuid,
  p_user_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user record;
  v_challenge record;
  v_attempt record;
  v_questions jsonb;
BEGIN
  -- 1. Check user premium status
  SELECT * INTO v_user FROM public.users WHERE id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found';
  END IF;

  IF v_user.subscription_status != 'active' OR (v_user.subscription_expires_at IS NOT NULL AND v_user.subscription_expires_at < now()) THEN
    RAISE EXCEPTION 'premium_required';
  END IF;

  -- 2. Check challenge exists and is live
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

  -- 3. Check stream audience match
  IF v_challenge.audience != 'both' AND lower(v_challenge.audience) != lower(coalesce(v_user.stream, '')) THEN
    RAISE EXCEPTION 'audience_mismatch';
  END IF;

  -- 4. Get or create attempt stamped with user's stream
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

  -- 5. Return questions WITHOUT correct_choice or explanation
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
  WHERE q.set_id = v_challenge.set_id;

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

-- 3. Submit Answer (Student) — Server computes correctness
CREATE OR REPLACE FUNCTION public.rpc_submit_answer(
  p_attempt_id uuid,
  p_question_id uuid,
  p_selected_choice text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_attempt record;
  v_question record;
  v_is_correct boolean := false;
BEGIN
  SELECT * INTO v_attempt FROM public.challenge_attempts WHERE id = p_attempt_id;
  IF NOT FOUND OR v_attempt.status != 'in_progress' THEN
    RAISE EXCEPTION 'invalid_or_completed_attempt';
  END IF;

  SELECT * INTO v_question FROM public.challenge_questions WHERE id = p_question_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'question_not_found';
  END IF;

  IF trim(lower(v_question.correct_choice)) = trim(lower(p_selected_choice)) THEN
    v_is_correct := true;
  END IF;

  INSERT INTO public.challenge_answers (attempt_id, question_id, selected_choice, is_correct, answered_at)
  VALUES (p_attempt_id, p_question_id, p_selected_choice, v_is_correct, now())
  ON CONFLICT (attempt_id, question_id)
  DO UPDATE SET
    selected_choice = EXCLUDED.selected_choice,
    is_correct = EXCLUDED.is_correct,
    answered_at = EXCLUDED.answered_at;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- 4. Submit Attempt (Student / Timeout)
CREATE OR REPLACE FUNCTION public.rpc_submit_attempt(
  p_attempt_id uuid,
  p_total_time_seconds int DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_attempt record;
  v_challenge record;
  v_score int := 0;
  v_time int := 0;
BEGIN
  SELECT * INTO v_attempt FROM public.challenge_attempts WHERE id = p_attempt_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'attempt_not_found';
  END IF;

  IF v_attempt.status = 'submitted' THEN
    RETURN jsonb_build_object(
      'success', true,
      'score', v_attempt.score,
      'total_time_seconds', v_attempt.total_time_seconds,
      'status', v_attempt.status
    );
  END IF;

  SELECT * INTO v_challenge FROM public.leaderboard_challenges WHERE id = v_attempt.challenge_id;

  -- Compute correct count
  SELECT count(*)::int INTO v_score
  FROM public.challenge_answers
  WHERE attempt_id = p_attempt_id AND is_correct = true;

  -- Compute total time
  IF p_total_time_seconds IS NOT NULL AND p_total_time_seconds > 0 THEN
    v_time := p_total_time_seconds;
  ELSE
    v_time := EXTRACT(EPOCH FROM (now() - v_attempt.started_at))::int;
  END IF;

  IF v_challenge.duration_seconds > 0 AND v_time > (v_challenge.duration_seconds + 30) THEN
    v_time := v_challenge.duration_seconds;
  END IF;

  UPDATE public.challenge_attempts
  SET
    score = v_score,
    total_time_seconds = v_time,
    submitted_at = now(),
    status = 'submitted'
  WHERE id = p_attempt_id;

  RETURN jsonb_build_object(
    'success', true,
    'score', v_score,
    'total_time_seconds', v_time,
    'status', 'submitted'
  );
END;
$$;

-- 5. Get Leaderboard for a Challenge
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
  v_challenge record;
  v_rows jsonb;
BEGIN
  SELECT c.*, q.q_count INTO v_challenge
  FROM public.leaderboard_challenges c
  LEFT JOIN (
    SELECT set_id, count(*)::int as q_count
    FROM public.challenge_questions
    GROUP BY set_id
  ) q ON q.set_id = c.set_id
  WHERE c.id = p_challenge_id;

  v_total_questions := coalesce(v_challenge.q_count, 0);

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

-- 6. Get Period Leaderboard (Weekly / Monthly)
CREATE OR REPLACE FUNCTION public.rpc_get_period_leaderboard(
  p_stream text,
  p_period text, -- 'week' or 'month'
  p_period_start date DEFAULT NULL,
  p_limit int DEFAULT 100
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rows jsonb;
  v_start date := p_period_start;
BEGIN
  IF v_start IS NULL THEN
    IF p_period = 'week' THEN
      v_start := date_trunc('week', now())::date;
    ELSE
      v_start := date_trunc('month', now())::date;
    END IF;
  END IF;

  IF p_period = 'week' THEN
    SELECT jsonb_agg(
      jsonb_build_object(
        'rank', lb.rank,
        'user_id', lb.user_id,
        'first_name', u.first_name,
        'last_name', coalesce(u.last_name, ''),
        'stream', lb.stream,
        'total_score', lb.total_score,
        'total_time_seconds', lb.total_time_seconds,
        'challenges_taken', lb.challenges_taken,
        'period_start', lb.period_start
      ) ORDER BY lb.rank ASC
    ) INTO v_rows
    FROM public.v_challenge_leaderboard_weekly lb
    JOIN public.users u ON u.id = lb.user_id
    WHERE lower(lb.stream) = lower(p_stream) AND lb.period_start = v_start
    LIMIT coalesce(p_limit, 100);
  ELSE
    SELECT jsonb_agg(
      jsonb_build_object(
        'rank', lb.rank,
        'user_id', lb.user_id,
        'first_name', u.first_name,
        'last_name', coalesce(u.last_name, ''),
        'stream', lb.stream,
        'total_score', lb.total_score,
        'total_time_seconds', lb.total_time_seconds,
        'challenges_taken', lb.challenges_taken,
        'period_start', lb.period_start
      ) ORDER BY lb.rank ASC
    ) INTO v_rows
    FROM public.v_challenge_leaderboard_monthly lb
    JOIN public.users u ON u.id = lb.user_id
    WHERE lower(lb.stream) = lower(p_stream) AND lb.period_start = v_start
    LIMIT coalesce(p_limit, 100);
  END IF;

  RETURN coalesce(v_rows, '[]'::jsonb);
END;
$$;

-- 7. Get Challenge Bundle for Offline Practice (Closed & Premium Only)
CREATE OR REPLACE FUNCTION public.rpc_get_challenge_bundle(
  p_challenge_id uuid,
  p_user_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user record;
  v_challenge record;
  v_questions jsonb;
BEGIN
  -- Check user premium status
  SELECT * INTO v_user FROM public.users WHERE id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found';
  END IF;

  IF v_user.subscription_status != 'active' OR (v_user.subscription_expires_at IS NOT NULL AND v_user.subscription_expires_at < now()) THEN
    RAISE EXCEPTION 'premium_required';
  END IF;

  -- Check challenge is closed or archived
  SELECT * INTO v_challenge FROM public.leaderboard_challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'challenge_not_found';
  END IF;

  IF v_challenge.status NOT IN ('closed', 'archived') THEN
    RAISE EXCEPTION 'challenge_not_closed';
  END IF;

  -- Return questions WITH correct answers and explanations
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', q.id,
      'set_id', q.set_id,
      'order_index', q.order_index,
      'question_text', q.question_text,
      'choices', q.choices,
      'correct_choice', q.correct_choice,
      'explanation', coalesce(q.explanation, ''),
      'image_url', q.image_url
    ) ORDER BY q.order_index ASC
  ) INTO v_questions
  FROM public.challenge_questions q
  WHERE q.set_id = v_challenge.set_id;

  RETURN jsonb_build_object(
    'challenge_id', v_challenge.id,
    'set_id', v_challenge.set_id,
    'subject_id', v_challenge.subject_id,
    'title', v_challenge.title,
    'audience', v_challenge.audience,
    'questions', coalesce(v_questions, '[]'::jsonb)
  );
END;
$$;

-- 8. Grant Reward (Admin)
CREATE OR REPLACE FUNCTION public.rpc_grant_reward(
  p_challenge_id uuid,
  p_user_id text,
  p_rank int,
  p_reward_type text,
  p_reward_value text,
  p_admin_uid text,
  p_period text DEFAULT NULL,
  p_period_start date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_days int;
  v_current_expiry timestamptz;
  v_new_expiry timestamptz;
BEGIN
  INSERT INTO public.challenge_rewards (
    challenge_id, user_id, rank, reward_type, reward_value,
    period, period_start, granted_by, granted_at
  ) VALUES (
    p_challenge_id, p_user_id, p_rank, p_reward_type, p_reward_value,
    p_period, p_period_start, p_admin_uid, now()
  );

  -- Extend premium if reward_type is premium_days
  IF p_reward_type = 'premium_days' THEN
    v_days := coalesce(p_reward_value::int, 30);
    SELECT subscription_expires_at INTO v_current_expiry FROM public.users WHERE id = p_user_id;

    IF v_current_expiry IS NULL OR v_current_expiry < now() THEN
      v_new_expiry := now() + (v_days || ' days')::interval;
    ELSE
      v_new_expiry := v_current_expiry + (v_days || ' days')::interval;
    END IF;

    UPDATE public.users
    SET
      subscription_status = 'active',
      subscription_expires_at = v_new_expiry
    WHERE id = p_user_id;
  END IF;

  -- Insert notification for student feed
  INSERT INTO public.notifications (
    user_id,
    title,
    body,
    type,
    payload,
    is_read,
    created_at,
    created_by
  ) VALUES (
    p_user_id,
    '🎉 Challenge Reward Awarded!',
    'Congratulations! You received a reward (' || p_reward_type || ': ' || coalesce(p_reward_value, '') || ') for your rank #' || coalesce(p_rank::text, '1') || ' on the leaderboard.',
    'announcement',
    jsonb_build_object(
      'type', 'challenge_reward',
      'challenge_id', p_challenge_id,
      'reward_type', p_reward_type,
      'reward_value', p_reward_value,
      'rank', p_rank
    ),
    false,
    now(),
    p_admin_uid
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

COMMIT;
