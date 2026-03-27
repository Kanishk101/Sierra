-- Phase locking + phase-level parts requests + phase target datetime.
-- Supports maintenance workflow where each phase is submitted/locked
-- with its own parts requests and completion target.

alter table public.work_order_phases
  add column if not exists planned_completion_at timestamptz;

alter table public.work_order_phases
  add column if not exists is_locked boolean not null default false;

alter table public.work_order_phases
  add column if not exists locked_at timestamptz;

create index if not exists idx_work_order_phases_work_order_id_phase_number
  on public.work_order_phases(work_order_id, phase_number);

alter table public.spare_parts_requests
  add column if not exists work_order_phase_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'spare_parts_requests_work_order_phase_id_fkey'
  ) then
    alter table public.spare_parts_requests
      add constraint spare_parts_requests_work_order_phase_id_fkey
      foreign key (work_order_phase_id)
      references public.work_order_phases(id)
      on delete set null;
  end if;
end $$;

create index if not exists idx_spare_parts_requests_work_order_phase_id
  on public.spare_parts_requests(work_order_phase_id);;
