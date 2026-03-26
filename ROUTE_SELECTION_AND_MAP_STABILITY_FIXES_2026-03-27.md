# Route Selection + Map Stability Fixes - 2026-03-27

## What was changed

1. Wired route selection into runtime flow before navigation starts.
- File: `Sierra/Driver/Views/TripNavigationContainerView.swift`
- Navigation now requires explicit route confirmation before tracking starts.

2. Added 3-choice route picker with large Apple-maps-style GO button.
- File: `Sierra/Driver/Views/RouteSelectionSheet.swift`
- Displays up to 3 alternatives from Mapbox response.
- Labels include `Fastest`, `Green Route`, and an additional route card.
- Added driver route-preference toggles: `Avoid Tolls` and `Avoid Highways`.
- Toggle changes rebuild route choices before GO.

3. Route engine upgraded to support explicit route-choice selection.
- File: `Sierra/Driver/ViewModels/RouteEngine.swift`
- Added route-choice list model (up to 3 routes).
- Added `selectRouteChoice(at:)` API.
- Selected route now drives primary route state for rendering/HUD.

4. Coordinator updated to expose route choices and enforce confirmation.
- File: `Sierra/Driver/ViewModels/TripNavigationCoordinator.swift`
- Added route-choice forwarding APIs.
- Added explicit route confirmation method.
- Active-guidance auto-start is constrained to the primary route choice to avoid unwanted route resets.

5. Admin map rendering stability tweak.
- File: `Sierra/FleetManager/Views/FleetLiveMapView.swift`
- Removed per-update global map animation hook tied to vehicle coordinate signature to reduce jitter and unnecessary redraw pressure.

## Behavior result

- Driver now sees route choices first, then taps a large `GO` button.
- Navigation does not auto-start until route selection is confirmed.
- Camera/zoom changes are no longer forced by per-update animation on admin map.

## Validation notes

- Build verification in this environment is currently blocked by local simulator/service/package-resolution issues unrelated to these edits.
- Prior known compile issue in `AskAIChatView.swift` still exists in this branch and should be fixed separately.
