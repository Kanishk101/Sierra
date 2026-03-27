
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Auth
CREATE TYPE user_role AS ENUM ('fleetManager','driver','maintenancePersonnel');
CREATE TYPE two_factor_method AS ENUM ('email','sms','authenticator');

-- Staff
CREATE TYPE staff_role AS ENUM ('driver','maintenance');
CREATE TYPE staff_status AS ENUM ('Active','Pending Approval','Suspended');
CREATE TYPE staff_availability AS ENUM ('Available','Unavailable','On Trip','On Task');
CREATE TYPE approval_status AS ENUM ('Pending','Approved','Rejected');

-- Vehicles
CREATE TYPE fuel_type AS ENUM ('Diesel','Petrol','Electric','CNG','Hybrid');
CREATE TYPE vehicle_status AS ENUM ('Active','Idle','In Maintenance','Out of Service','Decommissioned');
CREATE TYPE vehicle_document_type AS ENUM ('Registration','Insurance','Fitness Certificate','PUC Certificate','Permit','Other');

-- Operations
CREATE TYPE trip_status AS ENUM ('Scheduled','Active','Completed','Cancelled');
CREATE TYPE trip_priority AS ENUM ('Low','Normal','High','Urgent');
CREATE TYPE inspection_type AS ENUM ('Pre-Trip','Post-Trip');
CREATE TYPE inspection_result AS ENUM ('Passed','Failed','Passed with Warnings','Not Checked');
CREATE TYPE inspection_category AS ENUM ('Tyres','Engine','Lights','Body','Safety','Fluids');
CREATE TYPE proof_of_delivery_method AS ENUM ('Photo','Signature','OTP Verification');
CREATE TYPE emergency_alert_type AS ENUM ('SOS','Accident','Breakdown','Medical');
CREATE TYPE emergency_alert_status AS ENUM ('Active','Acknowledged','Resolved');

-- Maintenance
CREATE TYPE maintenance_task_type AS ENUM ('Scheduled','Breakdown','Inspection Defect','Urgent');
CREATE TYPE maintenance_task_status AS ENUM ('Pending','Assigned','In Progress','Completed','Cancelled');
CREATE TYPE task_priority AS ENUM ('Low','Medium','High','Urgent');
CREATE TYPE work_order_status AS ENUM ('Open','In Progress','On Hold','Completed','Closed');
CREATE TYPE maintenance_record_status AS ENUM ('Scheduled','In Progress','Completed','Cancelled');

-- Geofencing
CREATE TYPE geofence_event_type AS ENUM ('Entry','Exit');

-- Audit
CREATE TYPE activity_type AS ENUM (
    'Trip Started','Trip Completed','Trip Cancelled','Inspection Failed',
    'Vehicle Assigned','Maintenance Requested','Maintenance Completed',
    'Staff Approved','Staff Rejected','Emergency Alert','Geofence Violation',
    'Document Expiring Soon','Document Expired','Fuel Logged'
);
CREATE TYPE activity_severity AS ENUM ('Info','Warning','Critical');
;
