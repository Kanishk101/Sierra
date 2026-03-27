-- ============================================================
-- Migration: inspection-photos Supabase Storage bucket
-- Sierra Fleet Management System
-- Date: 2026-03-22 (seq 007)
--
-- Needed by: PreTripInspectionViewModel.uploadAllPhotos()
-- Called from: VehicleInspectionService.submitInspectionWithPhotos()
--
-- Upload path format:
--   {pre-trip|post-trip}/{tripId}/{itemId}/{uuid}.jpg
--   {pre-trip|post-trip}/{tripId}/general/{uuid}.jpg
--
-- Without this bucket:
--   supabase.storage.from("inspection-photos").upload() throws
--   "storage bucket not found" and all inspection photos are lost silently.
--   The inspection still submits (the photo URL array is empty) which means
--   defect photos don't exist even though the app thinks it uploaded them.
-- ============================================================

-- 1. Create bucket (idempotent)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'inspection-photos',
    'inspection-photos',
    false,      -- private: URLs require signed tokens or service-role access
    10485760,   -- 10 MB per file (inspection photos can be high-res for defect evidence)
    ARRAY[
        'image/jpeg',
        'image/jpg',
        'image/png',
        'image/webp',
        'image/heic',
        'image/heif'
    ]
)
ON CONFLICT (id) DO NOTHING;

-- 2. RLS policies for storage.objects
DROP POLICY IF EXISTS "Authenticated staff upload inspection photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated staff read inspection photos" ON storage.objects;
DROP POLICY IF EXISTS "Fleet managers update inspection photos" ON storage.objects;
DROP POLICY IF EXISTS "Fleet managers delete inspection photos" ON storage.objects;

-- Any authenticated staff member can upload inspection photos.
-- All three roles may conduct inspections (drivers pre/post-trip,
-- maintenance personnel for defect documentation, fleet managers for audits).
-- Path scoping is enforced at the app layer (trip ownership via TripService).
CREATE POLICY "Authenticated staff upload inspection photos"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'inspection-photos'
        AND EXISTS (
            SELECT 1 FROM public.staff_members
            WHERE id   = auth.uid()
              AND LOWER(role::text) IN ('driver', 'maintenancepersonnel', 'fleetmanager')
        )
    );

-- Any authenticated staff member can read inspection photos.
-- Fleet managers review defect evidence; maintenance assesses severity;
-- drivers can review their own inspection record.
CREATE POLICY "Authenticated staff read inspection photos"
    ON storage.objects FOR SELECT TO authenticated
    USING (
        bucket_id = 'inspection-photos'
        AND EXISTS (
            SELECT 1 FROM public.staff_members
            WHERE id = auth.uid()
        )
    );

-- Fleet managers can update photo metadata (move/rename for organisation)
CREATE POLICY "Fleet managers update inspection photos"
    ON storage.objects FOR UPDATE TO authenticated
    USING (
        bucket_id = 'inspection-photos'
        AND EXISTS (
            SELECT 1 FROM public.staff_members
            WHERE id = auth.uid() AND LOWER(role::text) = 'fleetmanager'
        )
    );

-- Fleet managers can delete photos (compliance retention management)
CREATE POLICY "Fleet managers delete inspection photos"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'inspection-photos'
        AND EXISTS (
            SELECT 1 FROM public.staff_members
            WHERE id = auth.uid() AND LOWER(role::text) = 'fleetmanager'
        )
    );

-- ============================================================
-- END OF MIGRATION 007
-- ============================================================
