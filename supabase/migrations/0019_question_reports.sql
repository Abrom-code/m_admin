-- ==============================================================================
-- 0007_question_reports.sql
-- Description: Creates public.question_reports table for student error reporting
--              with RLS policies and indexes.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.question_reports (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id               uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    question_id           integer REFERENCES public.questions(id) ON DELETE CASCADE,
    challenge_question_id uuid REFERENCES public.challenge_questions(id) ON DELETE CASCADE,
    test_id               integer REFERENCES public.tests(id) ON DELETE SET NULL,
    reason                text NOT NULL, -- 'wrong_answer', 'typo', 'unclear', 'broken_image', 'bad_explanation', 'other'
    comment               text,          -- optional student notes/feedback
    status                text NOT NULL DEFAULT 'pending', -- 'pending', 'resolved', 'dismissed'
    admin_notes           text,          -- optional notes added by administrator
    created_at            timestamptz NOT NULL DEFAULT now(),
    resolved_at           timestamptz,
    resolved_by           uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    CONSTRAINT chk_question_or_challenge CHECK (question_id IS NOT NULL OR challenge_question_id IS NOT NULL)
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_question_reports_status      ON public.question_reports (status);
CREATE INDEX IF NOT EXISTS idx_question_reports_question    ON public.question_reports (question_id);
CREATE INDEX IF NOT EXISTS idx_question_reports_challenge_q ON public.question_reports (challenge_question_id);
CREATE INDEX IF NOT EXISTS idx_question_reports_user        ON public.question_reports (user_id);
CREATE INDEX IF NOT EXISTS idx_question_reports_created_at  ON public.question_reports (created_at DESC);

-- Enable RLS
ALTER TABLE public.question_reports ENABLE ROW LEVEL SECURITY;

-- Students can submit reports
DROP POLICY IF EXISTS "Users can insert question reports" ON public.question_reports;
CREATE POLICY "Users can insert question reports"
    ON public.question_reports
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Students can read their own submissions
DROP POLICY IF EXISTS "Users can view own reports" ON public.question_reports;
CREATE POLICY "Users can view own reports"
    ON public.question_reports
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id OR public.is_admin());

-- Admins have full access (select, update status, delete)
DROP POLICY IF EXISTS "Admins full management of question reports" ON public.question_reports;
CREATE POLICY "Admins full management of question reports"
    ON public.question_reports
    FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
