
-- staff_members
CREATE INDEX idx_staff_role           ON staff_members(role);
CREATE INDEX idx_staff_status         ON staff_members(status);
CREATE INDEX idx_staff_availability   ON staff_members(availability);

-- driver_profiles / maintenance_profiles
CREATE INDEX idx_driver_profiles_sm   ON driver_profiles(staff_member_id);
CREATE INDEX idx_maint_profiles_sm    ON maintenance_profiles(staff_member_id);

-- staff_applications
CREATE INDEX idx_staff_apps_sm        ON staff_applications(staff_member_id);
CREATE INDEX idx_staff_apps_status    ON staff_applications(status);

-- two_factor_sessions
CREATE INDEX idx_2fa_user             ON two_factor_sessions(user_id);
CREATE INDEX idx_2fa_expires          ON two_factor_sessions(expires_at);

-- vehicles
CREATE INDEX idx_vehicles_status      ON vehicles(status);
CREATE INDEX idx_vehicles_driver      ON vehicles(assigned_driver_id);

-- vehicle_documents
CREATE INDEX idx_veh_docs_vehicle     ON vehicle_documents(vehicle_id);
CREATE INDEX idx_veh_docs_expiry      ON vehicle_documents(expiry_date);

-- trips
CREATE INDEX idx_trips_driver         ON trips(driver_id);
CREATE INDEX idx_trips_vehicle        ON trips(vehicle_id);
CREATE INDEX idx_trips_status         ON trips(status);
CREATE INDEX idx_trips_scheduled      ON trips(scheduled_date);

-- fuel_logs
CREATE INDEX idx_fuel_driver          ON fuel_logs(driver_id);
CREATE INDEX idx_fuel_vehicle         ON fuel_logs(vehicle_id);
CREATE INDEX idx_fuel_trip            ON fuel_logs(trip_id);

-- vehicle_inspections
CREATE INDEX idx_inspect_trip         ON vehicle_inspections(trip_id);
CREATE INDEX idx_inspect_vehicle      ON vehicle_inspections(vehicle_id);
CREATE INDEX idx_inspect_result       ON vehicle_inspections(overall_result);

-- proof_of_deliveries
CREATE INDEX idx_pod_trip             ON proof_of_deliveries(trip_id);
CREATE INDEX idx_pod_driver           ON proof_of_deliveries(driver_id);

-- emergency_alerts
CREATE INDEX idx_alerts_driver        ON emergency_alerts(driver_id);
CREATE INDEX idx_alerts_status        ON emergency_alerts(status);
CREATE INDEX idx_alerts_time          ON emergency_alerts(triggered_at);

-- maintenance_tasks
CREATE INDEX idx_maint_tasks_vehicle  ON maintenance_tasks(vehicle_id);
CREATE INDEX idx_maint_tasks_assigned ON maintenance_tasks(assigned_to_id);
CREATE INDEX idx_maint_tasks_status   ON maintenance_tasks(status);

-- work_orders
CREATE INDEX idx_work_orders_task     ON work_orders(maintenance_task_id);
CREATE INDEX idx_work_orders_assigned ON work_orders(assigned_to_id);
CREATE INDEX idx_work_orders_status   ON work_orders(status);

-- parts_used
CREATE INDEX idx_parts_work_order     ON parts_used(work_order_id);

-- maintenance_records
CREATE INDEX idx_maint_rec_vehicle    ON maintenance_records(vehicle_id);
CREATE INDEX idx_maint_rec_wo         ON maintenance_records(work_order_id);

-- geofences
CREATE INDEX idx_geofences_active     ON geofences(is_active);

-- geofence_events
CREATE INDEX idx_geo_events_geofence  ON geofence_events(geofence_id);
CREATE INDEX idx_geo_events_vehicle   ON geofence_events(vehicle_id);
CREATE INDEX idx_geo_events_time      ON geofence_events(triggered_at);

-- activity_logs
CREATE INDEX idx_logs_type            ON activity_logs(type);
CREATE INDEX idx_logs_severity        ON activity_logs(severity);
CREATE INDEX idx_logs_is_read         ON activity_logs(is_read);
CREATE INDEX idx_logs_timestamp       ON activity_logs(timestamp DESC);
CREATE INDEX idx_logs_actor           ON activity_logs(actor_id);
;
