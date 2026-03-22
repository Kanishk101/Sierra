-- Migration: fuel-receipts Supabase Storage bucket
-- Needed by: FuelLogViewModel.uploadReceipt(), which calls supabase.storage.from("fuel-receipts")
-- Without this bucket, receipt uploads fail silently.

-- 1. Create the storage bucket (idempotent via DO block)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
    'fuel-receipts',
    'fuel-receipts',
    false,                          -- private bucket; URLs require signed tokens
    5242880,                        -- 5 MB per file
    array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
on conflict (id) do nothing;

-- 2. Storage RLS policies (storage.objects table)

-- Drivers can upload receipts into their own folder: fuel-receipts/{driver_id}/...
create policy "Drivers upload own receipts"
    on storage.objects for insert
    to authenticated
    with check (
        bucket_id = 'fuel-receipts'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

-- Drivers can read their own receipts
create policy "Drivers read own receipts"
    on storage.objects for select
    to authenticated
    using (
        bucket_id = 'fuel-receipts'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

-- Fleet Managers can read all receipts (for cost auditing)
create policy "Fleet managers read all fuel receipts"
    on storage.objects for select
    to authenticated
    using (
        bucket_id = 'fuel-receipts'
        and exists (
            select 1 from public.staff_members sm
            where sm.id = auth.uid()
              and sm.role = 'fleetManager'
        )
    );

-- Drivers can delete their own receipts (re-scan / correction flow)
create policy "Drivers delete own receipts"
    on storage.objects for delete
    to authenticated
    using (
        bucket_id = 'fuel-receipts'
        and (storage.foldername(name))[1] = auth.uid()::text
    );
