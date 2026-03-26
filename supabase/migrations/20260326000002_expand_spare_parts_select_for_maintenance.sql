-- Allow maintenance personnel to view full spare parts request pipeline
-- so Inventory tab can show awaiting approvals/deliveries across catalog.

drop policy if exists spr_select on public.spare_parts_requests;

create policy spr_select
on public.spare_parts_requests
for select
to authenticated
using (
  get_my_role() = 'fleetManager'
  or get_my_role() = 'maintenancePersonnel'
  or requested_by_id = auth.uid()
);
