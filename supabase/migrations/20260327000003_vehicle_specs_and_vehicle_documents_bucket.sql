-- Vehicle spec expansion + dedicated storage bucket for vehicle documents

-- 1) Vehicle spec columns
ALTER TABLE public.vehicles
    ADD COLUMN IF NOT EXISTS fuel_tank_capacity_liters NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS mileage_km_per_litre NUMERIC(10,2);

ALTER TABLE public.vehicles
    DROP CONSTRAINT IF EXISTS vehicles_fuel_tank_capacity_liters_positive;
ALTER TABLE public.vehicles
    ADD CONSTRAINT vehicles_fuel_tank_capacity_liters_positive
    CHECK (fuel_tank_capacity_liters IS NULL OR fuel_tank_capacity_liters > 0);

ALTER TABLE public.vehicles
    DROP CONSTRAINT IF EXISTS vehicles_mileage_km_per_litre_positive;
ALTER TABLE public.vehicles
    ADD CONSTRAINT vehicles_mileage_km_per_litre_positive
    CHECK (mileage_km_per_litre IS NULL OR mileage_km_per_litre > 0);

-- 2) Vehicle documents bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'vehicle-documents',
    'vehicle-documents',
    true,
    15728640,
    ARRAY[
        'application/pdf',
        'image/jpeg',
        'image/jpg',
        'image/png',
        'image/webp',
        'image/heic',
        'image/heif'
    ]
)
ON CONFLICT (id) DO NOTHING;

-- 3) Policies for storage.objects
DROP POLICY IF EXISTS "Authenticated staff upload vehicle documents" ON storage.objects;
CREATE POLICY "Authenticated staff upload vehicle documents"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'vehicle-documents'
        AND EXISTS (
            SELECT 1 FROM public.staff_members
            WHERE id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Authenticated staff read vehicle documents" ON storage.objects;
CREATE POLICY "Authenticated staff read vehicle documents"
    ON storage.objects FOR SELECT TO authenticated
    USING (
        bucket_id = 'vehicle-documents'
        AND EXISTS (
            SELECT 1 FROM public.staff_members
            WHERE id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Fleet managers update vehicle documents" ON storage.objects;
CREATE POLICY "Fleet managers update vehicle documents"
    ON storage.objects FOR UPDATE TO authenticated
    USING (
        bucket_id = 'vehicle-documents'
        AND EXISTS (
            SELECT 1 FROM public.staff_members
            WHERE id = auth.uid()
              AND role = 'fleetManager'
        )
    );

DROP POLICY IF EXISTS "Fleet managers delete vehicle documents" ON storage.objects;
CREATE POLICY "Fleet managers delete vehicle documents"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'vehicle-documents'
        AND EXISTS (
            SELECT 1 FROM public.staff_members
            WHERE id = auth.uid()
              AND role = 'fleetManager'
        )
    );
