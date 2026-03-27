-- Inventory add request workflow:
-- maintenance submits request -> fleet manager approves/rejects -> inventory updates in app layer

create table if not exists public.inventory_part_add_requests (
    id uuid primary key default gen_random_uuid(),
    requested_by_id uuid not null references public.staff_members(id) on delete cascade,
    part_name text not null,
    part_number text,
    supplier text,
    category text,
    unit text not null default 'pcs',
    quantity integer not null default 1 check (quantity > 0),
    notes text,
    status text not null default 'Pending' check (status in ('Pending', 'Approved', 'Rejected', 'Fulfilled')),
    reviewed_by uuid references public.staff_members(id) on delete set null,
    reviewed_at timestamptz,
    rejection_reason text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists idx_inventory_part_add_requests_requested_by
    on public.inventory_part_add_requests (requested_by_id, created_at desc);

create index if not exists idx_inventory_part_add_requests_status
    on public.inventory_part_add_requests (status, created_at desc);

create index if not exists idx_inventory_part_add_requests_part_lookup
    on public.inventory_part_add_requests (lower(part_name), lower(coalesce(part_number, '')));

create or replace function public.fn_inventory_part_add_requests_set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists trg_inventory_part_add_requests_set_updated_at on public.inventory_part_add_requests;
create trigger trg_inventory_part_add_requests_set_updated_at
    before update on public.inventory_part_add_requests
    for each row
    execute function public.fn_inventory_part_add_requests_set_updated_at();

alter table public.inventory_part_add_requests enable row level security;

drop policy if exists inventory_part_add_requests_select_own_or_admin on public.inventory_part_add_requests;
drop policy if exists inventory_part_add_requests_insert_maintenance on public.inventory_part_add_requests;
drop policy if exists inventory_part_add_requests_update_admin on public.inventory_part_add_requests;

create policy inventory_part_add_requests_select_own_or_admin
    on public.inventory_part_add_requests
    for select
    to authenticated
    using (
        requested_by_id = auth.uid()
        or exists (
            select 1
            from public.staff_members sm
            where sm.id = auth.uid()
              and sm.role = 'fleetManager'
        )
    );

create policy inventory_part_add_requests_insert_maintenance
    on public.inventory_part_add_requests
    for insert
    to authenticated
    with check (
        requested_by_id = auth.uid()
        and exists (
            select 1
            from public.staff_members sm
            where sm.id = auth.uid()
              and sm.role = 'maintenancePersonnel'
        )
    );

create policy inventory_part_add_requests_update_admin
    on public.inventory_part_add_requests
    for update
    to authenticated
    using (
        exists (
            select 1
            from public.staff_members sm
            where sm.id = auth.uid()
              and sm.role = 'fleetManager'
        )
    )
    with check (
        exists (
            select 1
            from public.staff_members sm
            where sm.id = auth.uid()
              and sm.role = 'fleetManager'
        )
    );

do $$
begin
    if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
       and not exists (
         select 1
         from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = 'inventory_part_add_requests'
       ) then
        alter publication supabase_realtime add table public.inventory_part_add_requests;
    end if;
end $$;
