# Navigation Audit And Fixes (2026-03-26)

## Scope audited
- Driver navigation stack (Mapbox route building, live map, HUD, reroute logic)
- Admin fleet map (MapKit + live vehicle updates)
- Realtime pipelines (Supabase updates/subscriptions)
- Requirement fit for: fastest/green route, traffic colors, incident alerts, auto-reroute, stops, ETA/distance/arrival, geofences, deviation alerts, and driver restrictions

## Build verification
- iOS build check executed with `xcodebuild` on iPhone 17 simulator target.
- Result: `BUILD SUCCEEDED`.

## What is implemented correctly
- Mapbox + MapKit hybrid architecture is present and compiling.
- Driver active guidance now runs on Mapbox Navigation SDK Core (`MapboxNavigationProvider` + `SessionController.startActiveGuidance`), not custom GPS-only progress logic.
- Driver route generation supports alternatives, traffic profile, waypoints, and avoid toll/highway flags.
- Route polyline + origin/destination coordinates are persisted on trips.
- Driver map renders traffic congestion colors on the route line.
- Driver HUD shows step instructions, ETA, remaining time, speed, and incident banner UI.
- Driver location publishing every ~5s updates:
  - `vehicle_location_history`
  - `vehicles.current_latitude/current_longitude`
- Admin fleet map shows all vehicles on MapKit and updates from realtime vehicle changes.
- Route deviation detection + recording + notification flow exists.
- Geofence monitoring/event insert path exists.

## Fixes applied in this audit
1. Minor compile-safety adjustment in `TrafficIncidentService.hasSevereIncidentNearby(...)` default threshold handling (no behavior regression).
2. Driver coordinator wired to SDK-native map matching and route progress streams.
3. Driver route cursor/path reduction now follows SDK `RouteProgress.shapeIndex`, improving pointer-to-route alignment.
4. Build re-verified after patch: `BUILD SUCCEEDED`.

## Already present (verified in current code)
1. Shared Mapbox token usage in incident polling via `MapService.accessToken`.
2. Incident parsing support for point/line geometry payloads.
3. Severity parsing hardening for string/numeric formats.
4. Auto-reroute threshold sourced from `TripConstants.autoRerouteProximityMetres`.

## Remaining gaps against your exact requirement
1. Driver runtime route-choice controls exist in code but are not exposed in the active flow.
- `StartTripSheet` is locked to admin preset route and the route-selection sheet is currently bypassed.
- Hard-delete or role-gate the unused route-choice UI files if you want strict policy enforcement at code level too.

2. Alerts inbox is not fully realtime for deviation feed.
- `AlertsInboxView` loads once + pull-to-refresh; no dedicated realtime subscription for `route_deviation_events`.
- For strict realtime admin alerts, add a channel subscription or drive the view entirely from `AppDataStore` realtime state.

3. Incidents are near-realtime, not true live-stream realtime.
- Polling interval is 90 seconds.
- To behave closer to Google Maps-style alert freshness, reduce interval (for example 15-30 seconds with sensible throttling).

4. Full drop-in Mapbox Navigation UIKit view controller is not used.
- Current implementation keeps your custom SwiftUI UI and map wrapper, while guidance logic is SDK-driven via Navigation Core.
- If you want built-in lane guidance cards/junction visuals exactly like Mapbox demo apps, migrate map surface to `NavigationViewController`/`NavigationMapView`.

## Requirement note: driver restrictions
- Driver currently does **not** choose start/destination/stops in the navigation flow.
- Driver route/stop selection is effectively locked in active flow; remaining route-choice UI code is currently dormant.

## Recommended next implementation order
1. Finalize fleet path policy at code level: remove/role-gate dormant driver route-option UI code.
2. Add realtime subscription for route deviations in alerts inbox.
3. Tighten incident freshness interval and keep incident polling synced to every reroute.
4. (Optional but recommended) Migrate driver nav UI to Mapbox `NavigationViewController` for complete production-grade in-app navigation behavior.
