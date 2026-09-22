-- ==============================================================================
-- 0018_add_full_name_column.sql
-- Description: Unifies first_name and last_name into a stored generated full_name
--              column for blazing fast search, and updates handle_new_user() trigger
--              to gracefully accept both full_name and split names.
-- ==============================================================================

-- 1. Add full_name stored generated column to public.users if not already present
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'users' 
          AND column_name = 'full_name'
    ) THEN
        ALTER TABLE public.users 
        ADD COLUMN full_name text GENERATED ALWAYS AS (
            TRIM(COALESCE(first_name, '') || ' ' || COALESCE(last_name, ''))
        ) STORED;
    END IF;
END $$;

-- 2. Create B-Tree index for sorting & exact matches
CREATE INDEX IF NOT EXISTS idx_users_full_name ON public.users (full_name);

-- 3. Enable pg_trgm and create GIN trigram index for fast ILIKE '%query%' searches
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_users_full_name_trgm ON public.users USING gin (full_name gin_trgm_ops);

-- 4. Update handle_new_user() to accept full_name or first_name / last_name from auth metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_full text;
    v_first text;
    v_last text;
BEGIN
    v_full := TRIM(COALESCE(NEW.raw_user_meta_data->>'full_name', ''));
    v_first := COALESCE(NEW.raw_user_meta_data->>'first_name', '');
    v_last := COALESCE(NEW.raw_user_meta_data->>'last_name', '');

    -- If first_name was not provided, but full_name was, split it automatically
    IF v_first = '' AND v_full <> '' THEN
        v_first := split_part(v_full, ' ', 1);
        v_last := TRIM(SUBSTRING(v_full FROM LENGTH(v_first) + 1));
    END IF;

    INSERT INTO public.users (
        id,
        first_name,
        last_name,
        email,
        stream,
        subscription_status,
        created_at
    ) VALUES (
        NEW.id,
        v_first,
        v_last,
        COALESCE(NEW.email, ''),
        COALESCE(NEW.raw_user_meta_data->>'stream', 'natural'),
        'inactive',
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        first_name = CASE WHEN EXCLUDED.first_name <> '' THEN EXCLUDED.first_name ELSE public.users.first_name END,
        last_name = CASE WHEN EXCLUDED.last_name <> '' THEN EXCLUDED.last_name ELSE public.users.last_name END,
        stream = CASE WHEN EXCLUDED.stream <> '' THEN EXCLUDED.stream ELSE public.users.stream END;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
