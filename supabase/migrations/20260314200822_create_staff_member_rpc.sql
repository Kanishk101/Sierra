
-- SECURITY DEFINER function: creates an auth user + staff_members row atomically.
-- Called from iOS via supabase.rpc() — no Edge Function needed.
-- The SECURITY DEFINER allows this function to write to auth.users (which RLS normally blocks).
-- Caller must be authenticated (verified by Supabase before RPC is invoked).

CREATE OR REPLACE FUNCTION public.create_staff_member(
    p_email             text,
    p_raw_password      text,
    p_name              text,
    p_role              text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id       uuid;
    v_caller_role   text;
BEGIN
    -- Only fleet managers can call this function
    SELECT role INTO v_caller_role
    FROM public.staff_members
    WHERE id = auth.uid();

    IF v_caller_role IS DISTINCT FROM 'fleetManager' THEN
        RAISE EXCEPTION 'Only fleet managers can create staff accounts';
    END IF;

    -- Validate role
    IF p_role NOT IN ('driver', 'maintenancePersonnel') THEN
        RAISE EXCEPTION 'Invalid role: must be driver or maintenancePersonnel';
    END IF;

    -- Validate email not already taken
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
        RAISE EXCEPTION 'An account with this email already exists';
    END IF;

    -- Generate UUID for the new user
    v_user_id := gen_random_uuid();

    -- Insert into auth.users with bcrypt-hashed password
    INSERT INTO auth.users (
        id,
        instance_id,
        email,
        encrypted_password,
        email_confirmed_at,
        created_at,
        updated_at,
        role,
        aud,
        raw_app_meta_data,
        raw_user_meta_data,
        is_super_admin
    ) VALUES (
        v_user_id,
        '00000000-0000-0000-0000-000000000000',
        p_email,
        crypt(p_raw_password, gen_salt('bf')),
        now(),
        now(),
        now(),
        'authenticated',
        'authenticated',
        jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
        jsonb_build_object('name', p_name),
        false
    );

    -- Insert into staff_members
    INSERT INTO public.staff_members (
        id,
        name,
        email,
        role,
        status,
        availability,
        is_first_login,
        is_profile_complete,
        is_approved
    ) VALUES (
        v_user_id,
        p_name,
        p_email,
        p_role,
        'Pending Approval',
        'Unavailable',
        true,
        false,
        false
    );

    RETURN v_user_id;
END;
$$;

-- Grant execute to authenticated users (RLS on the function body handles fleetManager check)
GRANT EXECUTE ON FUNCTION public.create_staff_member(text, text, text, text) TO authenticated;
;
