-- Migration: push_tokens table + fn_send_push_on_notification_insert trigger
-- Needed by: send-push-notification edge function (reads push_tokens table)
-- Without this table, push notifications silently fail for all users.

-- 1. push_tokens table
-- Stores expo/FCM push tokens per staff member (one row per device).
create table if not exists public.push_tokens (
    id            uuid primary key default gen_random_uuid(),
    staff_id      uuid not null references public.staff_members(id) on delete cascade,
    token         text not null,
    platform      text not null default 'expo'
                      check (platform in ('expo', 'apns', 'fcm')),
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    unique (staff_id, token)
);

-- Index for fast per-user lookups (edge function pattern: WHERE staff_id = ?)
create index if not exists push_tokens_staff_id_idx
    on public.push_tokens (staff_id);

-- 2. Enable Row-Level Security
alter table public.push_tokens enable row level security;

-- Fleet Managers can read all tokens (needed for broadcast notifications)
create policy "Fleet managers read all push tokens"
    on public.push_tokens for select
    using (
        exists (
            select 1 from public.staff_members sm
            where sm.id = auth.uid()
              and sm.role = 'fleetManager'
        )
    );

-- Staff can only insert/update/delete their own tokens
create policy "Staff manage own push tokens"
    on public.push_tokens for all
    using (staff_id = auth.uid())
    with check (staff_id = auth.uid());

-- 3. Auto-update updated_at on token refresh
create or replace function public.fn_push_tokens_set_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

create trigger trg_push_tokens_set_updated_at
    before update on public.push_tokens
    for each row execute function public.fn_push_tokens_set_updated_at();

-- 4. Trigger: fire send-push-notification edge function when a notification row is inserted.
--    The trigger calls net.http_post (pg_net extension) to invoke the edge function.
--    Requires pg_net extension enabled in Supabase dashboard.
create or replace function public.fn_send_push_on_notification_insert()
returns trigger language plpgsql security definer as $$
declare
    _project_ref text;
    _service_role_key text;
    _url text;
begin
    -- These are set via Supabase Vault or environment config.
    -- The edge function reads push_tokens itself, so we just need to trigger it.
    -- Read project ref from pg_settings (set by Supabase platform automatically).
    select current_setting('app.settings.supabase_url', true) into _url;

    if _url is null or _url = '' then
        -- Can't fire without URL; log and return gracefully.
        raise notice 'fn_send_push_on_notification_insert: no supabase_url configured, skipping push';
        return new;
    end if;

    -- Fire-and-forget HTTP post to the edge function.
    -- net.http_post is provided by the pg_net Supabase extension.
    perform net.http_post(
        url     := _url || '/functions/v1/send-push-notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json'
        ),
        body    := jsonb_build_object(
            'notificationId', new.id,
            'recipientId',    new.recipient_id
        )::text
    );

    return new;
exception when others then
    raise notice 'fn_send_push_on_notification_insert error: %', sqlerrm;
    return new;
end;
$$;

create trigger trg_send_push_on_notification_insert
    after insert on public.notifications
    for each row execute function public.fn_send_push_on_notification_insert();
