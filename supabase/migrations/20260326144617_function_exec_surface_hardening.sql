-- Lock down function execute surface in public schema.
-- Keeps only the minimal function needed by RLS expressions.

-- 1) Revoke execute from app-facing roles on all existing public functions.
do $$
declare
  fn regprocedure;
begin
  for fn in
    select p.oid::regprocedure
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
  loop
    execute format(
      'revoke execute on function %s from anon, authenticated, public',
      fn
    );
  end loop;
end
$$;

-- 2) Allow only the helper used in active RLS policies.
grant execute on function public.get_my_role() to authenticated;

-- 3) Prevent future drift where possible. In managed projects this can be
-- restricted; keep non-fatal if insufficient privilege.
do $$
begin
  alter default privileges in schema public
    revoke execute on functions from anon, authenticated, public;
exception
  when insufficient_privilege then
    raise notice 'Skipping default function privilege hardening (insufficient privilege)';
end
$$;

do $$
begin
  alter default privileges in schema public
    revoke all on tables from anon, authenticated, public;
exception
  when insufficient_privilege then
    raise notice 'Skipping default table privilege hardening (insufficient privilege)';
end
$$;

do $$
begin
  alter default privileges in schema public
    revoke all on sequences from anon, authenticated, public;
exception
  when insufficient_privilege then
    raise notice 'Skipping default sequence privilege hardening (insufficient privilege)';
end
$$;;
