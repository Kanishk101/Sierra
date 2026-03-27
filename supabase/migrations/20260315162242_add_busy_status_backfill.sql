-- Back-fill: migrate any existing 'On Trip' driver rows → 'Busy'
UPDATE staff_members
   SET availability = 'Busy'
 WHERE availability = 'On Trip';

-- Back-fill: any vehicle with an active/scheduled trip → 'Busy'
UPDATE vehicles v
   SET status = 'Busy'
  FROM trips t
 WHERE t.vehicle_id = v.id
   AND t.status IN ('Scheduled', 'Active')
   AND v.status NOT IN ('In Maintenance', 'Out of Service', 'Decommissioned');;
