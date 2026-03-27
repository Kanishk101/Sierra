
-- ============================================================
-- PHASE 3A: Ensure kanin21stcentury is correctly set up as driver
-- ============================================================
UPDATE staff_members SET
  name = 'Kanishk S',
  role = 'driver',
  status = 'Active',
  is_approved = true,
  is_profile_complete = true,
  is_first_login = false,
  phone = '+91-9876500001',
  date_of_birth = '1998-05-21',
  gender = 'Male',
  address = 'Mysuru, Karnataka',
  emergency_contact_name = 'Suresh S',
  emergency_contact_phone = '+91-9876500099',
  aadhaar_number = '1234-5678-9001',
  availability = 'Available',
  joined_date = now() - interval '30 days'
WHERE id = 'f3439b6b-e55e-4ac9-8608-f1ef8e4fd7d2';

-- Ensure driver_profile exists for kanin21stcentury
INSERT INTO driver_profiles (
  id, staff_member_id, license_number, license_expiry, license_class,
  license_issuing_state, total_trips_completed, total_distance_km, average_rating, notes
) VALUES (
  gen_random_uuid(),
  'f3439b6b-e55e-4ac9-8608-f1ef8e4fd7d2',
  'KA19-20240001', '2028-05-20', 'LMV-Transport',
  'Karnataka', 12, 480.5, 4.7, 'Test driver account'
) ON CONFLICT (staff_member_id) DO UPDATE SET
  license_number = EXCLUDED.license_number,
  license_expiry = EXCLUDED.license_expiry,
  license_class = EXCLUDED.license_class,
  license_issuing_state = EXCLUDED.license_issuing_state;

-- Ensure staff_application exists for kanin21stcentury
INSERT INTO staff_applications (
  id, staff_member_id, role, status, reviewed_by, reviewed_at,
  phone, date_of_birth, gender, address,
  emergency_contact_name, emergency_contact_phone, aadhaar_number,
  driver_license_number, driver_license_expiry, driver_license_class, driver_license_issuing_state
) VALUES (
  gen_random_uuid(),
  'f3439b6b-e55e-4ac9-8608-f1ef8e4fd7d2',
  'driver', 'Approved',
  '70c3213c-25ad-49e2-b175-f53dd5d00271', now() - interval '28 days',
  '+91-9876500001', '1998-05-21', 'Male', 'Mysuru, Karnataka',
  'Suresh S', '+91-9876500099', '1234-5678-9001',
  'KA19-20240001', '2028-05-20', 'LMV-Transport', 'Karnataka'
) ON CONFLICT DO NOTHING;

-- ============================================================
-- PHASE 3B: Seed 3 Active Approved Drivers
-- ============================================================

-- Driver 1: Rahul Nair
INSERT INTO staff_members (id, name, role, status, email, phone, availability,
  date_of_birth, gender, address, emergency_contact_name, emergency_contact_phone,
  aadhaar_number, is_first_login, is_profile_complete, is_approved, joined_date, password)
VALUES (
  'bbbbbbbb-0001-4000-8000-000000000001',
  'Rahul Nair', 'driver', 'Active', 'rahul.nair@sierra.fms',
  '+91-9800000001', 'Available', '1995-03-14', 'Male',
  '42 Marine Drive, Mumbai, Maharashtra',
  'Sita Nair', '+91-9800000091',
  '2345-6789-0012', false, true, true,
  now() - interval '25 days', 'Sierra@123'
);
INSERT INTO driver_profiles (id, staff_member_id, license_number, license_expiry, license_class, license_issuing_state, total_trips_completed, total_distance_km, average_rating)
VALUES (gen_random_uuid(), 'bbbbbbbb-0001-4000-8000-000000000001', 'MH01-20220014', '2027-03-13', 'LMV-Transport', 'Maharashtra', 34, 1420.8, 4.5);
INSERT INTO staff_applications (id, staff_member_id, role, status, reviewed_by, reviewed_at, phone, date_of_birth, gender, address, emergency_contact_name, emergency_contact_phone, aadhaar_number, driver_license_number, driver_license_expiry, driver_license_class, driver_license_issuing_state)
VALUES (gen_random_uuid(), 'bbbbbbbb-0001-4000-8000-000000000001', 'driver', 'Approved', '70c3213c-25ad-49e2-b175-f53dd5d00271', now() - interval '23 days', '+91-9800000001', '1995-03-14', 'Male', '42 Marine Drive, Mumbai, Maharashtra', 'Sita Nair', '+91-9800000091', '2345-6789-0012', 'MH01-20220014', '2027-03-13', 'LMV-Transport', 'Maharashtra');

-- Driver 2: Divya Krishnan
INSERT INTO staff_members (id, name, role, status, email, phone, availability,
  date_of_birth, gender, address, emergency_contact_name, emergency_contact_phone,
  aadhaar_number, is_first_login, is_profile_complete, is_approved, joined_date, password)
VALUES (
  'bbbbbbbb-0002-4000-8000-000000000002',
  'Divya Krishnan', 'driver', 'Active', 'divya.krishnan@sierra.fms',
  '+91-9800000002', 'On Trip', '1997-07-22', 'Female',
  '15 Anna Nagar, Chennai, Tamil Nadu',
  'Ramesh Krishnan', '+91-9800000092',
  '3456-7890-0123', false, true, true,
  now() - interval '20 days', 'Sierra@123'
);
INSERT INTO driver_profiles (id, staff_member_id, license_number, license_expiry, license_class, license_issuing_state, total_trips_completed, total_distance_km, average_rating)
VALUES (gen_random_uuid(), 'bbbbbbbb-0002-4000-8000-000000000002', 'TN07-20210057', '2026-07-21', 'LMV-Transport', 'Tamil Nadu', 51, 2180.3, 4.8);
INSERT INTO staff_applications (id, staff_member_id, role, status, reviewed_by, reviewed_at, phone, date_of_birth, gender, address, emergency_contact_name, emergency_contact_phone, aadhaar_number, driver_license_number, driver_license_expiry, driver_license_class, driver_license_issuing_state)
VALUES (gen_random_uuid(), 'bbbbbbbb-0002-4000-8000-000000000002', 'driver', 'Approved', '70c3213c-25ad-49e2-b175-f53dd5d00271', now() - interval '18 days', '+91-9800000002', '1997-07-22', 'Female', '15 Anna Nagar, Chennai, Tamil Nadu', 'Ramesh Krishnan', '+91-9800000092', '3456-7890-0123', 'TN07-20210057', '2026-07-21', 'LMV-Transport', 'Tamil Nadu');

-- Driver 3: Mohit Saxena
INSERT INTO staff_members (id, name, role, status, email, phone, availability,
  date_of_birth, gender, address, emergency_contact_name, emergency_contact_phone,
  aadhaar_number, is_first_login, is_profile_complete, is_approved, joined_date, password)
VALUES (
  'bbbbbbbb-0003-4000-8000-000000000003',
  'Mohit Saxena', 'driver', 'Active', 'mohit.saxena@sierra.fms',
  '+91-9800000003', 'Available', '1993-11-05', 'Male',
  '7 Sector 18, Noida, Uttar Pradesh',
  'Geeta Saxena', '+91-9800000093',
  '4567-8901-0234', false, true, true,
  now() - interval '15 days', 'Sierra@123'
);
INSERT INTO driver_profiles (id, staff_member_id, license_number, license_expiry, license_class, license_issuing_state, total_trips_completed, total_distance_km, average_rating)
VALUES (gen_random_uuid(), 'bbbbbbbb-0003-4000-8000-000000000003', 'UP16-20190088', '2029-11-04', 'HMV', 'Uttar Pradesh', 89, 5640.7, 4.3);
INSERT INTO staff_applications (id, staff_member_id, role, status, reviewed_by, reviewed_at, phone, date_of_birth, gender, address, emergency_contact_name, emergency_contact_phone, aadhaar_number, driver_license_number, driver_license_expiry, driver_license_class, driver_license_issuing_state)
VALUES (gen_random_uuid(), 'bbbbbbbb-0003-4000-8000-000000000003', 'driver', 'Approved', '70c3213c-25ad-49e2-b175-f53dd5d00271', now() - interval '13 days', '+91-9800000003', '1993-11-05', 'Male', '7 Sector 18, Noida, Uttar Pradesh', 'Geeta Saxena', '+91-9800000093', '4567-8901-0234', 'UP16-20190088', '2029-11-04', 'HMV', 'Uttar Pradesh');

-- ============================================================
-- PHASE 3C: Seed 1 Pending Driver (profile submitted, awaiting approval)
-- ============================================================

-- Driver 4: Sunita Yadav (Pending Approval)
INSERT INTO staff_members (id, name, role, status, email, phone, availability,
  date_of_birth, gender, address, emergency_contact_name, emergency_contact_phone,
  aadhaar_number, is_first_login, is_profile_complete, is_approved, joined_date, password)
VALUES (
  'bbbbbbbb-0004-4000-8000-000000000004',
  'Sunita Yadav', 'driver', 'Pending Approval', 'sunita.yadav@sierra.fms',
  '+91-9800000004', 'Unavailable', '2000-01-18', 'Female',
  '3 Civil Lines, Jaipur, Rajasthan',
  'Ramdev Yadav', '+91-9800000094',
  '5678-9012-0345', false, true, false,
  now() - interval '3 days', 'Sierra@123'
);
INSERT INTO staff_applications (id, staff_member_id, role, status, phone, date_of_birth, gender, address, emergency_contact_name, emergency_contact_phone, aadhaar_number, driver_license_number, driver_license_expiry, driver_license_class, driver_license_issuing_state)
VALUES (gen_random_uuid(), 'bbbbbbbb-0004-4000-8000-000000000004', 'driver', 'Pending', '+91-9800000004', '2000-01-18', 'Female', '3 Civil Lines, Jaipur, Rajasthan', 'Ramdev Yadav', '+91-9800000094', '5678-9012-0345', 'RJ14-20231234', '2028-01-17', 'LMV-Transport', 'Rajasthan');

-- ============================================================
-- PHASE 3D: Seed 2 Active Approved Maintenance Personnel
-- ============================================================

-- Maintenance 1: Vikram Reddy
INSERT INTO staff_members (id, name, role, status, email, phone, availability,
  date_of_birth, gender, address, emergency_contact_name, emergency_contact_phone,
  aadhaar_number, is_first_login, is_profile_complete, is_approved, joined_date, password)
VALUES (
  'bbbbbbbb-0005-4000-8000-000000000005',
  'Vikram Reddy', 'maintenancePersonnel', 'Active', 'vikram.reddy@sierra.fms',
  '+91-9800000005', 'On Task', '1990-08-30', 'Male',
  '22 Banjara Hills, Hyderabad, Telangana',
  'Lakshmi Reddy', '+91-9800000095',
  '6789-0123-0456', false, true, true,
  now() - interval '22 days', 'Sierra@123'
);
INSERT INTO maintenance_profiles (id, staff_member_id, certification_type, certification_number, issuing_authority, certification_expiry, years_of_experience, specializations, total_tasks_assigned, total_tasks_completed)
VALUES (gen_random_uuid(), 'bbbbbbbb-0005-4000-8000-000000000005', 'Automotive Technician', 'AT-HYD-20190023', 'ASDC Hyderabad', '2026-08-29', 7, ARRAY['Engine Overhaul','Transmission','Brakes','Electrical'], 43, 41);
INSERT INTO staff_applications (id, staff_member_id, role, status, reviewed_by, reviewed_at, phone, date_of_birth, gender, address, emergency_contact_name, emergency_contact_phone, aadhaar_number, maint_certification_type, maint_certification_number, maint_issuing_authority, maint_certification_expiry, maint_years_of_experience, maint_specializations)
VALUES (gen_random_uuid(), 'bbbbbbbb-0005-4000-8000-000000000005', 'maintenancePersonnel', 'Approved', '70c3213c-25ad-49e2-b175-f53dd5d00271', now() - interval '20 days', '+91-9800000005', '1990-08-30', 'Male', '22 Banjara Hills, Hyderabad, Telangana', 'Lakshmi Reddy', '+91-9800000095', '6789-0123-0456', 'Automotive Technician', 'AT-HYD-20190023', 'ASDC Hyderabad', '2026-08-29', 7, ARRAY['Engine Overhaul','Transmission','Brakes','Electrical']);

-- Maintenance 2: Aisha Patel
INSERT INTO staff_members (id, name, role, status, email, phone, availability,
  date_of_birth, gender, address, emergency_contact_name, emergency_contact_phone,
  aadhaar_number, is_first_login, is_profile_complete, is_approved, joined_date, password)
VALUES (
  'bbbbbbbb-0006-4000-8000-000000000006',
  'Aisha Patel', 'maintenancePersonnel', 'Active', 'aisha.patel@sierra.fms',
  '+91-9800000006', 'Available', '1994-04-12', 'Female',
  '8 Satellite Road, Ahmedabad, Gujarat',
  'Imran Patel', '+91-9800000096',
  '7890-1234-0567', false, true, true,
  now() - interval '18 days', 'Sierra@123'
);
INSERT INTO maintenance_profiles (id, staff_member_id, certification_type, certification_number, issuing_authority, certification_expiry, years_of_experience, specializations, total_tasks_assigned, total_tasks_completed)
VALUES (gen_random_uuid(), 'bbbbbbbb-0006-4000-8000-000000000006', 'Vehicle Diagnostics', 'VD-AMD-20210067', 'GTU Ahmedabad', '2027-04-11', 5, ARRAY['Diagnostics','Suspension','Tyre & Wheel','HVAC'], 27, 26);
INSERT INTO staff_applications (id, staff_member_id, role, status, reviewed_by, reviewed_at, phone, date_of_birth, gender, address, emergency_contact_name, emergency_contact_phone, aadhaar_number, maint_certification_type, maint_certification_number, maint_issuing_authority, maint_certification_expiry, maint_years_of_experience, maint_specializations)
VALUES (gen_random_uuid(), 'bbbbbbbb-0006-4000-8000-000000000006', 'maintenancePersonnel', 'Approved', '70c3213c-25ad-49e2-b175-f53dd5d00271', now() - interval '16 days', '+91-9800000006', '1994-04-12', 'Female', '8 Satellite Road, Ahmedabad, Gujarat', 'Imran Patel', '+91-9800000096', '7890-1234-0567', 'Vehicle Diagnostics', 'VD-AMD-20210067', 'GTU Ahmedabad', '2027-04-11', 5, ARRAY['Diagnostics','Suspension','Tyre & Wheel','HVAC']);

-- ============================================================
-- PHASE 3E: Seed 1 Pending Maintenance Personnel
-- ============================================================

-- Maintenance 3: Karan Malhotra (Pending Approval)
INSERT INTO staff_members (id, name, role, status, email, phone, availability,
  date_of_birth, gender, address, emergency_contact_name, emergency_contact_phone,
  aadhaar_number, is_first_login, is_profile_complete, is_approved, joined_date, password)
VALUES (
  'bbbbbbbb-0007-4000-8000-000000000007',
  'Karan Malhotra', 'maintenancePersonnel', 'Pending Approval', 'karan.malhotra@sierra.fms',
  '+91-9800000007', 'Unavailable', '1996-09-25', 'Male',
  '19 Patel Nagar, New Delhi',
  'Sunita Malhotra', '+91-9800000097',
  '8901-2345-0678', false, true, false,
  now() - interval '2 days', 'Sierra@123'
);
INSERT INTO staff_applications (id, staff_member_id, role, status, phone, date_of_birth, gender, address, emergency_contact_name, emergency_contact_phone, aadhaar_number, maint_certification_type, maint_certification_number, maint_issuing_authority, maint_certification_expiry, maint_years_of_experience, maint_specializations)
VALUES (gen_random_uuid(), 'bbbbbbbb-0007-4000-8000-000000000007', 'maintenancePersonnel', 'Pending', '+91-9800000007', '1996-09-25', 'Male', '19 Patel Nagar, New Delhi', 'Sunita Malhotra', '+91-9800000097', '8901-2345-0678', 'Diesel Mechanic', 'DM-DEL-20220098', 'ITI New Delhi', '2025-09-24', 3, ARRAY['Diesel Engine','Fuel Systems','Exhaust']);

-- ============================================================
-- PHASE 3F: Update the orphaned maintenance_task to point to Vikram Reddy
-- ============================================================
UPDATE maintenance_tasks
SET assigned_to_id = 'bbbbbbbb-0005-4000-8000-000000000005'
WHERE assigned_to_id IS NULL
  AND id = '0601bde0-769f-4d62-9da2-937a43886909';
;
