-- Add per-phase ETA support and allow maintenance personnel to create phases
-- on work orders assigned to them.

alter table public.work_order_phases
  add column if not exists estimated_minutes integer;

alter table public.work_order_phases
  drop constraint if exists work_order_phases_estimated_minutes_check;

alter table public.work_order_phases
  add constraint work_order_phases_estimated_minutes_check
  check (estimated_minutes is null or estimated_minutes >= 0);

drop policy if exists wo_phases_insert on public.work_order_phases;

create policy wo_phases_insert
on public.work_order_phases
for insert
to authenticated
with check (
  (select role from public.staff_members where id = auth.uid()) = 'fleetManager'::user_role
  or work_order_id in (
    select id from public.work_orders where assigned_to_id = auth.uid()
  )
);;
