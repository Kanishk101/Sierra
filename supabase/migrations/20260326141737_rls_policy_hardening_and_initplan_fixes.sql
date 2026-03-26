-- Tighten RLS policy role scope (public -> authenticated) where auth is required
alter policy al_insert on public.activity_logs to authenticated;
alter policy push_tokens_own on public.push_tokens to authenticated;
alter policy sa_insert on public.staff_applications to authenticated;
alter policy vehicles_update on public.vehicles to authenticated;
alter policy wo_phases_delete on public.work_order_phases to authenticated;
alter policy wo_phases_select on public.work_order_phases to authenticated;
alter policy wo_phases_update on public.work_order_phases to authenticated;

-- Fix initplan performance warnings by using (select auth.uid()) in policy expressions
alter policy inventory_parts_delete_admin on public.inventory_parts
  using (
    (
      select staff_members.role
      from public.staff_members
      where staff_members.id = (select auth.uid())
    ) = 'fleetManager'::public.user_role
  );

alter policy inventory_parts_insert_admin on public.inventory_parts
  with check (
    (
      select staff_members.role
      from public.staff_members
      where staff_members.id = (select auth.uid())
    ) = 'fleetManager'::public.user_role
  );

alter policy inventory_parts_update_admin on public.inventory_parts
  using (
    (
      select staff_members.role
      from public.staff_members
      where staff_members.id = (select auth.uid())
    ) = 'fleetManager'::public.user_role
  )
  with check (
    (
      select staff_members.role
      from public.staff_members
      where staff_members.id = (select auth.uid())
    ) = 'fleetManager'::public.user_role
  );

alter policy spr_select on public.spare_parts_requests
  using (
    (public.get_my_role() = 'fleetManager')
    or (public.get_my_role() = 'maintenancePersonnel')
    or (requested_by_id = (select auth.uid()))
  );

alter policy wo_phases_insert on public.work_order_phases
  with check (
    (
      (
        select staff_members.role
        from public.staff_members
        where staff_members.id = (select auth.uid())
      ) = 'fleetManager'::public.user_role
    )
    or (
      work_order_id in (
        select work_orders.id
        from public.work_orders
        where work_orders.assigned_to_id = (select auth.uid())
      )
    )
  );
