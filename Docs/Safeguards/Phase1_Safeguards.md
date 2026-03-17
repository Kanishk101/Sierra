# Phase 1 Safeguards — Swift Models
## Attach these instructions at the END of your Phase 1 prompt session before Claude writes any code.

---

## SAFEGUARD 1 — Never break existing CodingKeys

Every existing model already has CodingKeys defined. When adding new properties, you must ADD new cases to the existing CodingKeys enum — never replace or reorder the existing cases. Reordering CodingKeys causes all existing Supabase queries that return those models to silently mismap fields.

Verify by checking: every existing case in CodingKeys must still be present after your changes, in the same form.

## SAFEGUARD 2 — All new columns must be Optional unless they have a DB default

Cross-reference every new column against the Supabase schema:
- If the column has DEFAULT in the DB (e.g. DEFAULT '{}', DEFAULT false, DEFAULT 0) — it can be non-Optional in Swift BUT must have a default value in the Swift initialiser to match.
- If the column is nullable (no NOT NULL constraint) — it MUST be typed as Optional (?) in Swift.
- Never type a nullable column as non-Optional. This causes Codable decoding to throw and crash the fetch.

Specific checks for this phase:
- photo_urls: [String] DEFAULT '{}' → Swift: var photoUrls: [String] = []  ✓
- is_defect_raised: bool DEFAULT false → Swift: var isDefectRaised: Bool = false  ✓
- raised_task_id: uuid nullable → Swift: var raisedTaskId: UUID?  ✓
- origin_latitude/longitude: float nullable → Swift: var originLatitude: Double?  ✓
- route_polyline: text nullable → Swift: var routePolyline: String?  ✓
- driver_rating: smallint nullable → Swift: var driverRating: Int?  ✓
- failed_login_attempts: integer DEFAULT 0 → Swift: var failedLoginAttempts: Int = 0  ✓
- account_locked_until: timestamptz nullable → Swift: var accountLockedUntil: Date?  ✓
- repair_image_urls: text[] DEFAULT '{}' → Swift: var repairImageUrls: [String] = []  ✓
- estimated_completion_at: timestamptz nullable → Swift: var estimatedCompletionAt: Date?  ✓

## SAFEGUARD 3 — Enum raw values must match Postgres EXACTLY including spaces

Postgres enums are case-sensitive and space-sensitive. A single character mismatch causes decoding to fail silently (the field decodes as nil if Optional, or throws if not).

Check every new enum raw value character by character:
- GeofenceType: "Warehouse", "Delivery Point" (has space), "Restricted Zone" (has space), "Custom"
- NotificationType: "Trip Assigned" (space), "Trip Cancelled" (space), "Vehicle Assigned" (space), "Maintenance Approved" (space), "Maintenance Rejected" (space), "Maintenance Overdue" (space), "SOS Alert" (space), "Defect Alert" (space), "Route Deviation" (space), "Geofence Violation" (space), "Inspection Failed" (space), "General"
- TripExpenseType: "Toll", "Parking", "Other"
- SparePartsRequestStatus: "Pending", "Approved", "Rejected", "Fulfilled"
- EmergencyAlertType new value: "Defect" (capital D, no other characters)
- ActivityType new value: "Route Deviation" (capital R, capital D, one space)

## SAFEGUARD 4 — Date decoding strategy must be consistent

All Date fields in the existing models use ISO8601 with fractional seconds. Do not introduce any Date field that uses a different format. The Supabase Swift SDK's default decoder handles this, but if any new model uses a custom JSONDecoder, it must use:
  decoder.dateDecodingStrategy = .iso8601  
or the fractional-seconds variant already used in the codebase. Check the existing models for the decoder pattern before writing new ones.

## SAFEGUARD 5 — SierraNotification must NOT import or conflict with Foundation.Notification

Name the struct SierraNotification, not Notification. The file must have no line that says "import UserNotifications" at the model level — that import belongs in the service layer, not the model. The model is pure data, no framework dependencies beyond Foundation.

## SAFEGUARD 6 — Array columns use correct CodingKey snake_case

Postgres stores arrays as column names like photo_urls, repair_image_urls. The CodingKey must be photoUrls → "photo_urls" and repairImageUrls → "repair_image_urls". Verify every array property has the correct snake_case CodingKey.

## VERIFICATION CHECKLIST — Before committing

Claude must confirm each of these before committing:
- [ ] Every existing model file compiles with no changes to existing properties
- [ ] Every new Optional property is marked with ?
- [ ] Every new enum raw value matches the Postgres enum label exactly
- [ ] No existing CodingKeys case was removed or renamed
- [ ] SierraNotification does not conflict with Foundation.Notification
- [ ] All array columns default to empty array, not nil
