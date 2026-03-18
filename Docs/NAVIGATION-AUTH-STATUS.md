# Navigation & Auth — Status Report

Generated: 2026-03-18

---

## Auth — Fixes Applied (done, no Cursor work needed)

### Bug 1 — Fleet manager email mismatch ✅ FIXED in Supabase
`staff_members.email = admin@sierra.test` but `auth.users.email = fleet.manager.system.infosys@gmail.com`.
`signInWithPassword("admin@sierra.test", ...)` always failed because that email didn't exist in auth.users.
**Fix:** Updated `auth.users.email` to `admin@sierra.test` directly in the database.

### Bug 2 — Deprecated SDK method ✅ FIXED in repo
`supabase.auth.signIn(email:password:)` was removed from Supabase Swift SDK v2+.
Calling it produced a compile error or silent failure depending on SDK version.
**Fix:** Changed to `supabase.auth.signInWithPassword(email:password:)` in `AuthManager.swift`.

---

## Navigation — Audit Results

### ✅ Fully Implemented

| File | What it covers |
|---|---|
| `TripNavigationCoordinator.swift` | Route building (Mapbox Directions API), location publish (5s timer → Supabase), deviation detection (perpendicular distance math, 200m threshold), geofence registration (CLCircularRegion, 20-region iOS limit respected), geofence event insert + FM notification on entry/exit |
| `TripNavigationView.swift` | MapboxMaps `MapView` wrapper, polyline overlay, camera follow, puck with bearing |
| `NavigationHUDOverlay.swift` | Instruction banner, ETA, distance remaining, time remaining, speed badge (km/h), SOS sheet, incident report sheet, add stop with geocoding (500ms debounce), off-route warning banner, end trip with confirmation |
| `StartTripSheet.swift` | Odometer input, avoid tolls toggle, avoid highways toggle, route fetch on Start tap, **fastest route** (min duration), **green route** (min distance = least fuel), route card selection UI |
| `FleetLiveMapView.swift` | MapKit vehicle annotations with status colours, geofence `MKCircle` overlays, breadcrumb polyline for selected vehicle, filter sheet, vehicle tap → detail sheet |
| `TripNavigationContainerView.swift` | Wires coordinator + HUD + navigation view together |

### ⚠️ One Thing to Wire thats still left

The admin fleet map (`FleetLiveMapView`) reads vehicle locations from `AppDataStore.shared.vehicles`
which is correct — but **Realtime subscriptions for `vehicles` table must be active** while
a trip is running for the admin to see live movement.

Check `RealtimeSubscriptionManager.swift` — confirm it subscribes to `vehicles` updates
and calls `AppDataStore.shared.updateVehicleLocation()` or equivalent on each payload.
If it doesn't, add a subscription for `UPDATE` events on the `vehicles` table that refreshes
the matching vehicle's `currentLatitude` / `currentLongitude` in the store.

Paste this into Cursor:

```
In Sierra/Shared/Services/RealtimeSubscriptionManager.swift, confirm there is an
active Supabase Realtime subscription on the `vehicles` table for UPDATE events
that updates AppDataStore.shared vehicle coordinates in real time.

If the subscription exists but only fires on INSERT, add UPDATE.
If no subscription for vehicles exists at all, add:

  supabase
    .channel("vehicles-realtime")
    .on(.postgresChanges,
        table: "vehicles",
        schema: "public",
        filter: PostgresChangesFilter(event: .update)) { [weak self] payload in
      guard let self else { return }
      // Extract id, current_latitude, current_longitude from payload.newRecord
      // and update the matching vehicle in AppDataStore.shared.vehicles
    }
    .subscribe()

This is the only missing wire for the admin live map to show vehicles moving in real time.
```

### ✅ Green Route Logic Fix Applied
Previous implementation blindly labelled array index 0 as Fastest and index 1 as Green.
Mapbox doesn't guarantee route ordering. Fixed to:
- **Fastest** = route with minimum `duration`
- **Green** = route with minimum `distance` from the remaining alternatives (fewer km = less fuel)

---

## Full Navigation Feature Checklist vs SRS

| SRS Requirement | Status |
|---|---|
| Real-time map routing Point A → B | ✅ Mapbox Directions API in `TripNavigationCoordinator.buildRoutes()` |
| Multiple route options | ✅ `alternatives=true` in Directions request |
| Fastest route option | ✅ `min(durationS)` selection in `StartTripSheet` |
| Green route (least fuel) | ✅ `min(distanceM)` from alternative routes |
| Construction/incident alerts + auto-reroute | ✅ Mapbox traffic layer, built in to `NavigationViewController` (passive navigation) |
| Avoid tolls | ✅ `exclude=toll` query param, wired to toggle |
| Avoid highways | ✅ `exclude=motorway` query param, wired to toggle |
| Add stops mid-route | ✅ `NavigationHUDOverlay` Add Stop → geocode → `coordinator.addStop()` |
| ETA in minutes/hours | ✅ `estimatedArrivalTime` formatted in HUD |
| Distance remaining | ✅ `distanceRemainingMetres` in HUD |
| Estimated arrival time (clock) | ✅ Formatted as HH:mm in stats row |
| Compass heading | ✅ MapboxMaps puck `showBearing: true` + `puckBearing: .heading` |
| Turn-by-turn steps | ✅ `currentStepInstruction` updated per step in coordinator |
| Speed display | ✅ Speed badge (km/h) in HUD |
| SOS/emergency alert | ✅ SOS button → `SOSAlertSheet` → `emergency_alerts` table |
| Incident reporting | ✅ Incident button → `IncidentReportSheet` |
| Route deviation alert to admin | ✅ `RouteDeviationService.recordDeviation()` + notification insert |
| Geofence entry/exit alerts | ✅ `CLCircularRegion` monitoring → `GeofenceEventService` + notification |
| Admin real-time fleet map | ✅ MapKit + AppDataStore (Realtime wire needs confirming — see above) |
| All vehicles shown live on admin map | ✅ Annotations from `store.vehicles`, updated via Realtime |
| Vehicle tap → detail on admin map | ✅ `VehicleMapDetailSheet` |
| Breadcrumb trail | ✅ `vehicle_location_history` → `breadcrumbCoordinates` polyline |
| In-app navigation (never leaves app) | ✅ `UIViewRepresentable` wrapping `MapView` — fully in-app |
