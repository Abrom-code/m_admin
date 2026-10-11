-- ==============================================================================
-- 0021_pilot_exams_fixes.sql
-- Description: Adds grade column to pilot_exams and grants full admin RLS policies
--              for pilot_exams, pilot_exam_subjects, and related tables.
-- ==============================================================================

-- 1. Ensure grade column exists on pilot_exams table
ALTER TABLE IF EXISTS public.pilot_exams
ADD COLUMN IF NOT EXISTS grade INT DEFAULT 12;

-- 2. Enable RLS on pilot exam tables if not already enabled
ALTER TABLE IF EXISTS public.pilot_exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.pilot_exam_subjects ENABLE ROW LEVEL SECURITY;

-- 3. Full admin access policies for pilot_exams
DROP POLICY IF EXISTS "Admins full manage pilot exams" ON public.pilot_exams;
DROP POLICY IF EXISTS "Authenticated users manage pilot exams" ON public.pilot_exams;
CREATE POLICY "Admins full manage pilot exams" ON public.pilot_exams
    FOR ALL
    TO authenticated
    USING (
        public.is_admin() 
        OR lower(coalesce(auth.jwt() ->> 'email', '')) = 'howdes404@gmail.com'
    )
    WITH CHECK (
        public.is_admin() 
        OR lower(coalesce(auth.jwt() ->> 'email', '')) = 'howdes404@gmail.com'
    );

-- 4. Full admin access policies for pilot_exam_subjects
DROP POLICY IF EXISTS "Admins full manage pilot exam subjects" ON public.pilot_exam_subjects;
DROP POLICY IF EXISTS "Authenticated users manage pilot exam subjects" ON public.pilot_exam_subjects;
CREATE POLICY "Admins full manage pilot exam subjects" ON public.pilot_exam_subjects
    FOR ALL
    TO authenticated
    USING (
        public.is_admin() 
        OR lower(coalesce(auth.jwt() ->> 'email', '')) = 'howdes404@gmail.com'
    )
    WITH CHECK (
        public.is_admin() 
        OR lower(coalesce(auth.jwt() ->> 'email', '')) = 'howdes404@gmail.com'
    );

-- 5. Preserve public read access for pilot_exams (published & active for students, all for admins)
DROP POLICY IF EXISTS "Pilot exams select policy" ON public.pilot_exams;
DROP POLICY IF EXISTS "Allow public read access to active pilot exams" ON public.pilot_exams;
DROP POLICY IF EXISTS "Allow public read active pilot exams" ON public.pilot_exams;
CREATE POLICY "Pilot exams select policy" ON public.pilot_exams
    FOR SELECT
    TO public
    USING (
        public.is_admin()
        OR lower(coalesce(auth.jwt() ->> 'email', '')) = 'howdes404@gmail.com'
        OR (is_active = true AND status = 'published')
    );

-- 6. Preserve public read access for pilot_exam_subjects
DROP POLICY IF EXISTS "Pilot exam subjects select policy" ON public.pilot_exam_subjects;
DROP POLICY IF EXISTS "Allow public read access to pilot exam subjects" ON public.pilot_exam_subjects;
DROP POLICY IF EXISTS "Allow public read pilot exam subjects" ON public.pilot_exam_subjects;
CREATE POLICY "Pilot exam subjects select policy" ON public.pilot_exam_subjects
    FOR SELECT
    TO public
    USING (
        public.is_admin()
        OR lower(coalesce(auth.jwt() ->> 'email', '')) = 'howdes404@gmail.com'
        OR EXISTS (
            SELECT 1 FROM public.pilot_exams pe
            WHERE pe.id = pilot_exam_subjects.pilot_exam_id
              AND pe.is_active = true
              AND pe.status = 'published'
        )
    );

-- 7. Full admin access policies for leaderboard_challenges & question sets
ALTER TABLE IF EXISTS public.leaderboard_challenges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins full manage challenges" ON public.leaderboard_challenges;
CREATE POLICY "Admins full manage challenges" ON public.leaderboard_challenges
    FOR ALL
    TO authenticated
    USING (
        public.is_admin() 
        OR lower(coalesce(auth.jwt() ->> 'email', '')) = 'howdes404@gmail.com'
    )
    WITH CHECK (
        public.is_admin() 
        OR lower(coalesce(auth.jwt() ->> 'email', '')) = 'howdes404@gmail.com'
    );

ALTER TABLE IF EXISTS public.challenge_question_sets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins full manage challenge sets" ON public.challenge_question_sets;
CREATE POLICY "Admins full manage challenge sets" ON public.challenge_question_sets
    FOR ALL
    TO authenticated
    USING (
        public.is_admin() 
        OR lower(coalesce(auth.jwt() ->> 'email', '')) = 'howdes404@gmail.com'
    )
    WITH CHECK (
        public.is_admin() 
        OR lower(coalesce(auth.jwt() ->> 'email', '')) = 'howdes404@gmail.com'
    );

-- 8. Full admin access policies for device_history
ALTER TABLE IF EXISTS public.device_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins full manage device history" ON public.device_history;
CREATE POLICY "Admins full manage device history" ON public.device_history
    FOR ALL
    TO authenticated
    USING (
        public.is_admin() 
        OR lower(coalesce(auth.jwt() ->> 'email', '')) = 'howdes404@gmail.com'
    )
    WITH CHECK (
        public.is_admin() 
        OR lower(coalesce(auth.jwt() ->> 'email', '')) = 'howdes404@gmail.com'
    );
