
-- Storage policies for new buckets

-- kyc-documents: authenticated users can upload to their own folder, admins can read all
CREATE POLICY kyc_upload_own
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'kyc-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY kyc_read_admin
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'kyc-documents' AND (
        get_my_role() IN ('fleetManager')
        OR (storage.foldername(name))[1] = auth.uid()::text
    ));

-- delivery-proofs: drivers can upload, all authenticated can read
CREATE POLICY delivery_proofs_upload
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'delivery-proofs');

CREATE POLICY delivery_proofs_read
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'delivery-proofs');

-- fuel-receipts: drivers can upload, all authenticated can read
CREATE POLICY fuel_receipts_upload
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'fuel-receipts');

CREATE POLICY fuel_receipts_read
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'fuel-receipts');
;
