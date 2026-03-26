# Driver Navigation Fixes (2026-03-26)

## Implemented in this pass

1. Driver map flow set to Mapbox view in active container flow.
- `TripNavigationContainerView` now renders `TripNavigationView` directly for driver navigation.
- Route-selection sheet is bypassed in active nav start flow so driver no longer picks fastest/green route manually.

2. Added top-right camera mode toggle (Overview <-> Follow).
- New control is in the top-right button slot of the navigation container.
- Toggle behavior:
  - Overview: route-wide zoom out.
  - Follow: snaps back to puck-follow mode.

3. Improved route/pointer alignment and clipped-path behavior.
- Pointer rendering now prioritizes live GPS coordinate.
- Route rendering now prepends current location to remaining route when needed to avoid visible gap.
- Route cursor snapping is more robust:
  - Wider local search window.
  - Global recovery scan when desynced.
  - Controlled backward correction when clearly better.

4. Locked pre-start driver flow to admin-defined route polyline.
- `StartTripSheet` no longer exposes driver route preference controls in UI.
- Trip start is blocked if admin route polyline is missing.
- Existing admin route polyline is reused when writing trip coordinates.

5. Voice guidance tuning upgraded.
- Replaced fixed `en-IN` voice with preferred high-quality `en-US` voice selection (fallback to best English voice).
- Adjusted rate/pitch/pauses for more natural delivery.

6. Driver route engine no longer falls back to MapKit when Mapbox token is missing.
- If token is absent, route uses stored polyline fallback or explicit configuration error.

7. Integrated Mapbox Navigation SDK Core for active guidance (while preserving your custom UI).
- `TripNavigationCoordinator` now starts a true SDK active-guidance session using `MapboxNavigationProvider`.
- Route progress, map-matched location, and voice instruction streams are consumed from SDK publishers.
- Route clipping/progress now uses SDK `shapeIndex` updates (better remaining-line accuracy and pointer alignment).
- Manual reroute triggering is disabled when SDK guidance is active, so rerouting stays SDK-controlled.

8. Improved breadcrumb and clipping stability while walking (no UI changes).
- Breadcrumb append threshold reduced from 2m to 1m for better blue-trail continuity at low speed.
- When SDK guidance is active, raw CLLocation ticks still feed breadcrumb updates.
- Added cursor advancement from live location (with local + global recovery) so remaining-route clipping tracks movement more tightly.
- Added guardrails to smooth SDK `shapeIndex` jumps and reduce abrupt clipping jumps.

9. Additional smoothing + anti-jump hardening (still no UI changes).
- Adaptive route-cursor advance cap based on speed (walking vs driving) to reduce clipping overshoot.
- Breadcrumb anti-spike filter ignores unrealistic GPS jumps at low speed.
- Breadcrumb list is capped to prevent unbounded growth during long navigation sessions.
- Driver puck update threshold in map rendering reduced for smoother low-speed movement.

## Build verification
- `xcodebuild` for scheme `Sierra` completed.
- Result: `BUILD SUCCEEDED`.

## Notes
- Admin map remains MapKit + Supabase realtime (unchanged).
- Driver flow remains custom UI on top of Mapbox map/route engine.
