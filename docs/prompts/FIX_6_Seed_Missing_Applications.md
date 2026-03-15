# Fix 6 — Seed Missing Staff Applications for Existing Approved Staff

## Where
Supabase project `ldqcdngdlbbiojlnbnjg` — run via Supabase SQL editor or MCP.

## Problem

Arjun Sharma, Priya Mehta, and Ravi Kumar are `is_approved: true` in `staff_members`
but have **no rows in `staff_applications`**. The admin's application review list
shows only 2 entries (Neha: approved, Sanjay: rejected).

This means:
- The approval history for 3 active staff is missing
- `store.pendingApplicationsCount` is 0 even though there are active staff
- Testing the full application → approval flow requires real pending applications

## Fix — Insert seed applications for the 3 approved staff

Run this SQL on Sierra-FMS-v2:

```sql
INSERT INTO public.staff_applications (
    id, staff_member_id, role, submitted_date, status, reviewed_at,
    phone, date_of_birth, gender, address,
    emergency_contact_name, emergency_contact_phone,
    aadhaar_number, driver_license_number, driver_license_expiry,
    driver_license_class, driver_license_issuing_state, created_at
) VALUES
-- Arjun Sharma (driver, approved)
(
    gen_random_uuid(),
    'aaaaaaaa-0001-4000-8000-000000000001',
    'driver', now() - interval '30 days', 'Approved', now() - interval '29 days',
    '+91 9876543001', '1995-03-15', 'Male', '12 MG Road, Bengaluru 560001',
    'Rahul Sharma', '+91 9876543002',
    '1234 5678 9012', 'KA-0120220001234', '2028-03-15', 'LMV', 'Karnataka',
    now() - interval '30 days'
),
-- Priya Mehta (driver, approved)
(
    gen_random_uuid(),
    'aaaaaaaa-0002-4000-8000-000000000002',
    'driver', now() - interval '25 days', 'Approved', now() - interval '24 days',
    '+91 9876543003', '1998-07-22', 'Female', '45 Brigade Road, Bengaluru 560025',
    'Suresh Mehta', '+91 9876543004',
    '2345 6789 0123', 'KA-0120230005678', '2029-07-22', 'LMV', 'Karnataka',
    now() - interval '25 days'
),
-- Ravi Kumar (maintenance, approved)
(
    gen_random_uuid(),
    'aaaaaaaa-0003-4000-8000-000000000003',
    'maintenancePersonnel', now() - interval '20 days', 'Approved', now() - interval '19 days',
    '+91 9876543005', '1990-11-08', 'Male', '78 Industrial Area, Bengaluru 560058',
    'Sunita Kumar', '+91 9876543006',
    '3456 7890 1234', null, null, null, null,
    now() - interval '20 days'
);
```

Note: Ravi is maintenance so driver license fields are null.
For maintenance-specific fields (cert type, cert number, etc.) they can be updated
manually or left null for seed data — the approval flow works regardless.

## After seeding

`store.staffApplications` will have 5 entries: 4 approved + 1 rejected.
The admin's application review tab will show full history.
The `pendingApplicationsCount` badge will correctly show 0 (no pending).
