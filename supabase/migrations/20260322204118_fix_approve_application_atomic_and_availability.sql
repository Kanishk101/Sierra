
-- ============================================================
-- MIGRATION: fix_approve_application_atomic_and_availability
-- Date: 2026-03-23
-- Fixes:
--   1. approve_staff_application_atomic — atomic approval that
--      copies ALL staff_application data into staff_members,
--      creates driver_profiles / maintenance_profiles row.
--   2. can_driver_become_unavailable — 30-minute window check.
--   3. trg_fn_enforce_availability — normalises On Trip/On Task
--      → Busy, enforces 30-min unavailability rule for drivers.
--   4. trg_fn_sync_driver_availability_from_trip — auto-sets
--      driver Busy on trip start, Available on completion.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1.  ATOMIC APPROVAL FUNCTION
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.approve_staff_application_atomic(
  p_application_id UUID,
  p_reviewed_by    UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_app  staff_applications%ROWTYPE;
BEGIN
  -- Lock the row to prevent concurrent approvals
  SELECT * INTO v_app
  FROM staff_applications
  WHERE id = p_application_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Application not found');
  END IF;

  IF v_app.status != 'Pending' THEN
    RETURN jsonb_build_object('success', false, 'error',
      'Application is already ' || v_app.status::text);
  END IF;

  -- 1a. Mark application approved
  UPDATE staff_applications
  SET status      = 'Approved',
      reviewed_by = p_reviewed_by,
      reviewed_at = NOW()
  WHERE id = p_application_id;

  -- 1b. Copy ALL personal data from application → staff_members + activate
  UPDATE staff_members
  SET phone                   = v_app.phone,
      date_of_birth           = v_app.date_of_birth,
      gender                  = v_app.gender,
      address                 = v_app.address,
      emergency_contact_name  = v_app.emergency_contact_name,
      emergency_contact_phone = v_app.emergency_contact_phone,
      aadhaar_number          = v_app.aadhaar_number,
      profile_photo_url       = COALESCE(v_app.profile_photo_url, profile_photo_url),
      is_approved             = TRUE,
      is_profile_complete     = TRUE,
      status                  = 'Active',
      availability            = 'Available',
      joined_date             = NOW(),
      updated_at              = NOW()
  WHERE id = v_app.staff_member_id;

  -- 1c. Create driver_profiles row if role = driver
  IF v_app.role = 'driver' AND v_app.driver_license_number IS NOT NULL THEN
    INSERT INTO driver_profiles (
      staff_member_id,
      license_number,
      license_expiry,
      license_class,
      license_issuing_state,
      license_document_url,
      aadhaar_document_url
    ) VALUES (
      v_app.staff_member_id,
      v_app.driver_license_number,
      v_app.driver_license_expiry,
      v_app.driver_license_class,
      v_app.driver_license_issuing_state,
      v_app.driver_license_document_url,
      v_app.aadhaar_document_url
    )
    ON CONFLICT (staff_member_id) DO UPDATE
      SET license_number        = EXCLUDED.license_number,
          license_expiry        = EXCLUDED.license_expiry,
          license_class         = EXCLUDED.license_class,
          license_issuing_state = EXCLUDED.license_issuing_state,
          license_document_url  = EXCLUDED.license_document_url,
          aadhaar_document_url  = EXCLUDED.aadhaar_document_url,
          updated_at            = NOW();
  END IF;

  -- 1d. Create maintenance_profiles row if role = maintenancePersonnel
  IF v_app.role = 'maintenancePersonnel' AND v_app.maint_certification_number IS NOT NULL THEN
    INSERT INTO maintenance_profiles (
      staff_member_id,
      certification_type,
      certification_number,
      issuing_authority,
      certification_expiry,
      certification_document_url,
      years_of_experience,
      specializations,
      aadhaar_document_url
    ) VALUES (
      v_app.staff_member_id,
      COALESCE(v_app.maint_certification_type, ''),
      v_app.maint_certification_number,
      COALESCE(v_app.maint_issuing_authority, ''),
      v_app.maint_certification_expiry,
      v_app.maint_certification_document_url,
      COALESCE(v_app.maint_years_of_experience, 0),
      COALESCE(v_app.maint_specializations, ARRAY[]::text[]),
      v_app.aadhaar_document_url
    )
    ON CONFLICT (staff_member_id) DO UPDATE
      SET certification_type         = EXCLUDED.certification_type,
          certification_number       = EXCLUDED.certification_number,
          issuing_authority          = EXCLUDED.issuing_authority,
          certification_expiry       = EXCLUDED.certification_expiry,
          certification_document_url = EXCLUDED.certification_document_url,
          years_of_experience        = EXCLUDED.years_of_experience,
          specializations            = EXCLUDED.specializations,
          updated_at                 = NOW();
  END IF;

  RETURN jsonb_build_object(
    'success',         TRUE,
    'staff_member_id', v_app.staff_member_id::text,
    'role',            v_app.role::text
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.approve_staff_application_atomic(UUID, UUID) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 2.  AVAILABILITY CHECK FUNCTION
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.can_driver_become_unavailable(p_driver_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_active_count   INTEGER;
  v_upcoming_count INTEGER;
BEGIN
  -- Any active / accepted trip right now
  SELECT COUNT(*) INTO v_active_count
  FROM trips
  WHERE driver_id = p_driver_id
    AND status IN ('Active', 'Accepted', 'PendingAcceptance');

  IF v_active_count > 0 THEN
    RETURN jsonb_build_object(
      'allowed', FALSE,
      'reason',  'You are currently on an active trip'
    );
  END IF;

  -- Any trip starting within the next 30 minutes
  SELECT COUNT(*) INTO v_upcoming_count
  FROM trips
  WHERE driver_id = p_driver_id
    AND status IN ('Scheduled', 'Accepted', 'PendingAcceptance')
    AND scheduled_date BETWEEN NOW() AND (NOW() + INTERVAL '30 minutes');

  IF v_upcoming_count > 0 THEN
    RETURN jsonb_build_object(
      'allowed', FALSE,
      'reason',  'A trip starts within 30 minutes — you cannot go unavailable now'
    );
  END IF;

  RETURN jsonb_build_object('allowed', TRUE, 'reason', NULL);
END;
$$;

GRANT EXECUTE ON FUNCTION public.can_driver_become_unavailable(UUID) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 3.  AVAILABILITY ENFORCEMENT TRIGGER
--     Normalises On Trip / On Task → Busy
--     Blocks going Unavailable within 30 min of a trip
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_fn_enforce_availability()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check JSONB;
BEGIN
  -- Normalise legacy granular statuses → Busy
  IF NEW.availability IN ('On Trip', 'On Task') THEN
    NEW.availability := 'Busy';
    RETURN NEW;
  END IF;

  -- For drivers: block going Unavailable within 30 min of a trip
  IF NEW.role = 'driver'
     AND NEW.availability = 'Unavailable'
     AND OLD.availability IS DISTINCT FROM 'Unavailable'
  THEN
    v_check := can_driver_become_unavailable(NEW.id);
    IF NOT (v_check->>'allowed')::BOOLEAN THEN
      RAISE EXCEPTION '%', v_check->>'reason';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_availability ON staff_members;
CREATE TRIGGER trg_enforce_availability
  BEFORE UPDATE OF availability ON staff_members
  FOR EACH ROW
  EXECUTE FUNCTION trg_fn_enforce_availability();

-- ─────────────────────────────────────────────────────────────
-- 4.  AUTO-SYNC DRIVER AVAILABILITY FROM TRIP STATUS
--     Active/Accepted trip  → driver becomes Busy
--     Completed/Cancelled   → driver becomes Available
--       (only if no other active trips exist)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_fn_sync_driver_availability_from_trip()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Trip became Active or Accepted → mark driver Busy
  IF NEW.driver_id IS NOT NULL
     AND NEW.status IN ('Active', 'Accepted')
     AND (OLD.status IS NULL OR OLD.status NOT IN ('Active', 'Accepted'))
  THEN
    UPDATE staff_members
    SET availability = 'Busy',
        updated_at   = NOW()
    WHERE id           = NEW.driver_id
      AND availability != 'Busy';
  END IF;

  -- Trip ended (Completed / Cancelled / Rejected) → return driver to Available
  -- only if no other trip has them Active/Accepted
  IF NEW.driver_id IS NOT NULL
     AND NEW.status IN ('Completed', 'Cancelled', 'Rejected')
     AND OLD.status IN ('Active', 'Accepted', 'PendingAcceptance', 'Scheduled')
  THEN
    IF NOT EXISTS (
      SELECT 1 FROM trips
      WHERE driver_id = NEW.driver_id
        AND id        != NEW.id
        AND status    IN ('Active', 'Accepted', 'PendingAcceptance')
    ) THEN
      UPDATE staff_members
      SET availability = 'Available',
          updated_at   = NOW()
      WHERE id           = NEW.driver_id
        AND availability = 'Busy';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_driver_availability_from_trip ON trips;
CREATE TRIGGER trg_sync_driver_availability_from_trip
  AFTER UPDATE OF status ON trips
  FOR EACH ROW
  EXECUTE FUNCTION trg_fn_sync_driver_availability_from_trip();
;
