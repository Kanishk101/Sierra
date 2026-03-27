
-- Back-fill: migrate any 'On Trip' driver rows → 'Busy'
UPDATE staff_members
   SET availability = 'Busy'
 WHERE availability = 'On Trip';

-- Back-fill: mark vehicles that currently have an active/scheduled trip as Busy
-- trips.vehicle_id is TEXT (UUID string), vehicles.id is UUID — cast accordingly
UPDATE vehicles v
   SET status = 'Busy'
  FROM trips t
 WHERE v.id = t.vehicle_id::uuid
   AND t.status IN ('Scheduled', 'Active')
   AND v.status NOT IN ('In Maintenance', 'Out of Service', 'Decommissioned');
;
