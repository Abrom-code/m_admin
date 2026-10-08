-- =====================================================================
-- Migration 0017: Admin Permanent User Deletion RPC
-- =====================================================================

CREATE OR REPLACE FUNCTION public.admin_delete_user(
    p_user_id   text,
    p_admin_uid text,
    p_reason    text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_user record;
    v_uuid uuid;
BEGIN
    -- 1. Authorization: verify caller is an administrator
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Not authorized. Administrator privileges required.';
    END IF;

    -- 2. Guard against self-deletion
    IF p_user_id = auth.uid()::text OR p_user_id = p_admin_uid THEN
        RAISE EXCEPTION 'Cannot delete your own administrator account.';
    END IF;

    -- 3. Guard against deleting other administrators
    IF EXISTS (
        SELECT 1 FROM public.admins
        WHERE id::text = p_user_id OR lower(email) = lower(p_user_id)
    ) THEN
        RAISE EXCEPTION 'Cannot delete an administrator account via this method.';
    END IF;

    -- 4. Capture snapshot of user before deletion for audit logging
    SELECT * INTO v_user FROM public.users WHERE id::text = p_user_id;

    -- 5. Record to audit log
    INSERT INTO public.admin_audit_log
        (admin_uid, action, entity_type, entity_id, before, note)
    VALUES (
        p_admin_uid,
        'delete_user_permanently',
        'user',
        p_user_id,
        jsonb_build_object(
            'id', p_user_id,
            'email', coalesce(v_user.email, ''),
            'first_name', coalesce(v_user.first_name, ''),
            'last_name', coalesce(v_user.last_name, ''),
            'stream', coalesce(v_user.stream, ''),
            'subscription_status', coalesce(v_user.subscription_status, '')
        ),
        p_reason
    );

    -- 6. Attempt deletion from auth.users (cascades to public.users & all related tables)
    BEGIN
        v_uuid := p_user_id::uuid;
        DELETE FROM auth.users WHERE id = v_uuid;
    EXCEPTION WHEN OTHERS THEN
        -- If not a valid UUID or auth record already absent, continue
    END;

    -- 7. Fallback delete from public.users in case auth delete did not cascade
    DELETE FROM public.users WHERE id::text = p_user_id;

    -- 8. Clean up any duplicate records sharing this email
    IF v_user.email IS NOT NULL AND trim(v_user.email) <> '' THEN
        DELETE FROM public.users WHERE lower(trim(email)) = lower(trim(v_user.email));
    END IF;

    RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_delete_user(text, text, text) TO authenticated;