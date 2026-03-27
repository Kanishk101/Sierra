
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'inspection-photos',
    'inspection-photos',
    false,
    10485760,
    ARRAY['image/jpeg','image/jpg','image/png','image/webp','image/heic','image/heif']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Staff upload inspection photos"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'inspection-photos'
        AND EXISTS (SELECT 1 FROM public.staff_members WHERE id = auth.uid())
    );

CREATE POLICY "Staff read inspection photos"
    ON storage.objects FOR SELECT TO authenticated
    USING (
        bucket_id = 'inspection-photos'
        AND EXISTS (SELECT 1 FROM public.staff_members WHERE id = auth.uid())
    );

CREATE POLICY "Fleet managers delete inspection photos"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'inspection-photos'
        AND get_my_role() = 'fleetManager'
    );
;
