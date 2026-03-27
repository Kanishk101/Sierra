
-- ================================================================
-- Migration: vehicle_inspections_odometer_fuel_fields
-- ================================================================
-- The new pre-inspection flow merges odometer reading + fuel level
-- into the inspection itself (instead of a separate "Log Fuel" tab).
-- These two columns store:
--   odometer_reading  — km reading at time of inspection (from OCR
--                       or manual entry fallback)
--   fuel_level_pct    — fuel level as a percentage 0–100
--                       (captured during pre-inspection only;
--                        NULL on post-inspection rows)
--   fuel_receipt_url  — URL of a fuel receipt photo uploaded during
--                       an active trip (mid-trip refuelling)
--                       NULL unless driver refuelled during the trip
-- ================================================================

ALTER TABLE public.vehicle_inspections
  ADD COLUMN IF NOT EXISTS odometer_reading   DOUBLE PRECISION NULL,
  ADD COLUMN IF NOT EXISTS fuel_level_pct     INTEGER          NULL
    CHECK (fuel_level_pct IS NULL OR (fuel_level_pct >= 0 AND fuel_level_pct <= 100)),
  ADD COLUMN IF NOT EXISTS fuel_receipt_url   TEXT             NULL;

COMMENT ON COLUMN public.vehicle_inspections.odometer_reading IS
  'Odometer km reading at inspection time. Set via OCR primary / manual fallback.';
COMMENT ON COLUMN public.vehicle_inspections.fuel_level_pct IS
  'Fuel level percentage (0-100) captured during pre-trip inspection only.';
COMMENT ON COLUMN public.vehicle_inspections.fuel_receipt_url IS
  'URL of a mid-trip fuel receipt photo (Active trip only). NULL otherwise.';
;
