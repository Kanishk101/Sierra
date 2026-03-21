# Phase 11 — Navigation: Route Selection Sheet + Admin Data Load Fix

## Context
- **Project:** Sierra FMS — iOS 17+, SwiftUI, MVVM, `@Observable`, no `@Published`
- **Files to modify:** `TripNavigationCoordinator.swift`, `TripNavigationContainerView.swift`, `AdminDashboardView.swift`
- **New file:** `Sierra/Driver/Views/RouteSelectionSheet.swift`
- **Architecture:** Mapbox SDK for driver navigation (`MapboxDirections`, `MapboxMaps`). MapKit for admin fleet map.

---

## CRITICAL: MBXAccessToken is empty

`Sierra/Info.plist` has `<key>MBXAccessToken</key><string></string>`. The value is an empty string.

**This is why the navigation map shows a blank screen.** MapboxMaps reads this key at `MapView` init time and renders nothing if it is empty or invalid.

**Fix:** In Xcode, open `Sierra/Info.plist` and set the value of `MBXAccessToken` to your Mapbox public token (starts with `pk.`). Get a free token at https://account.mapbox.com — the free tier provides 50,000 map loads/month and 100,000 Directions API calls/month.

This is a local secret and must NOT be committed to Git. The key in Info.plist stays empty in the repo. Set it via Xcode’s build settings or an `.xcconfig` file that is gitignored:

```
# Config/Secrets.xcconfig (gitignored)
MAPBOX_ACCESS_TOKEN = pk.eyJ1...
```

Then in Info.plist:
```xml
<key>MBXAccessToken</key>
<string>$(MAPBOX_ACCESS_TOKEN)</string>
```

This is already the intended pattern from earlier sprint work (`$(MAPBOX_ACCESS_TOKEN)` was the convention). If `Secrets.xcconfig` already exists and is gitignored, just fill in the token there.

---

## Gap 1 — `AdminDashboardView` never calls `loadAll()` → fleet map shows empty/static data

### Root Cause
`AdminDashboardView.swift` (the 5-tab root for fleet managers) has no `.task {}` modifier and never calls `store.loadAll()`. This means:
- `store.vehicles` is empty when the admin opens the map tab — no annotations appear
- `subscribeToVehicleUpdates()` in AppDataStore is never started — Realtime channel never opens
- All fleet manager data (trips, staff, maintenance tasks, etc.) is never populated

### Fix in `AdminDashboardView.swift`

Add a `.task {}` modifier to the `TabView`:

```swift
var body: some View {
    TabView(selection: $selectedTab) {
        // ... existing tabs ...
    }
    .tint(.orange)
    .onChange(of: selectedTab) { ... }  // existing
    .sheet(isPresented: $showQuickActions) { ... }  // existing
    // ADD THIS:
    .task {
        if store.staff.isEmpty || store.vehicles.isEmpty {
            await store.loadAll()
        }
    }
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
        Task { await store.loadAll() }
    }
}
```

The `if store.staff.isEmpty || store.vehicles.isEmpty` guard prevents re-running `loadAll()` on every tab switch while still triggering it on first load and after sign-out (where arrays are cleared).

The `willEnterForegroundNotification` listener refreshes data when the app comes back from background — this keeps the fleet map current after the phone has been idle.

---

## Gap 2 — `RouteSelectionSheet` not implemented + `TripNavigationContainerView` needs route selection flow

### Current Broken Behaviour
`TripNavigationContainerView.onAppear` immediately calls `startLocationTracking()` + `startLocationPublishing()`. `.task {}` calls `buildRoutes()`. The driver never sees any route options — the fastest route is silently selected and navigation starts immediately. The Green route is computed but never exposed to the driver.

### Fix Part A — Add `selectGreenRoute()` to `TripNavigationCoordinator.swift`

Add this method after `buildRoutes()`:

```swift
/// Swaps currentRoute and alternativeRoute so the driver's map follows
/// the green (lowest distance) route. Called from RouteSelectionSheet.
func selectGreenRoute() {
    guard let alt = alternativeRoute else { return }
    let prev = currentRoute
    currentRoute = alt
    alternativeRoute = prev
    // Re-decode the newly selected route's shape for deviation detection
    if let shape = currentRoute?.shape {
        decodedRouteCoordinates = shape.coordinates
    }
    // Update step instruction and ETA for the new route
    if let firstStep = currentRoute?.legs.first?.steps.first {
        currentStepInstruction = firstStep.instructions
    }
    if let travel = currentRoute?.expectedTravelTime {
        estimatedArrivalTime = Date().addingTimeInterval(travel)
    }
    if let dist = currentRoute?.distance {
        distanceRemainingMetres = dist
    }
    hasBuiltRoutes = true
}
```

### Fix Part B — Create `Sierra/Driver/Views/RouteSelectionSheet.swift` (new file)

This sheet is presented after `buildRoutes()` completes and before location tracking starts:

```swift
import SwiftUI

/// Shown after routes are built, before navigation starts.
/// Driver picks Fastest or Green route, then taps Start Navigation.
struct RouteSelectionSheet: View {

    let coordinator: TripNavigationCoordinator
    var onStart: () -> Void  // called when driver confirms a route

    @Environment(\.dismiss) private var dismiss

    private var fastest: MapboxDirections.Route? { coordinator.currentRoute }
    private var green: MapboxDirections.Route?   { coordinator.alternativeRoute }

    @State private var selectedIsGreen = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Choose Your Route")
                    .font(.title3.weight(.bold))
                    .padding(.top, 8)

                if let f = fastest {
                    routeCard(
                        label: "Fastest",
                        icon: "bolt.fill",
                        color: .blue,
                        distanceKm: f.distance / 1000,
                        durationMin: f.expectedTravelTime / 60,
                        eta: Date().addingTimeInterval(f.expectedTravelTime),
                        savings: nil,
                        isSelected: !selectedIsGreen
                    ) {
                        selectedIsGreen = false
                    }
                }

                if let g = green, let f = fastest {
                    let savedKm = (f.distance - g.distance) / 1000
                    routeCard(
                        label: "Green Route • Eco",
                        icon: "leaf.fill",
                        color: .green,
                        distanceKm: g.distance / 1000,
                        durationMin: g.expectedTravelTime / 60,
                        eta: Date().addingTimeInterval(g.expectedTravelTime),
                        savings: savedKm > 0.2 ? savedKm : nil,
                        isSelected: selectedIsGreen
                    ) {
                        selectedIsGreen = true
                    }
                }

                Spacer()

                Button {
                    if selectedIsGreen { coordinator.selectGreenRoute() }
                    dismiss()
                    onStart()
                } label: {
                    Text("Start Navigation")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 20)
            .interactiveDismissDisabled() // prevent accidental swipe-down before choosing
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func routeCard(
        label: String,
        icon: String,
        color: Color,
        distanceKm: Double,
        durationMin: Double,
        eta: Date,
        savings: Double?,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 12) {
                        Text(String(format: "%.1f km", distanceKm))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(durationMin < 60
                            ? String(format: "%.0f min", durationMin)
                            : String(format: "%.0fh %.0fm", floor(durationMin / 60), durationMin.truncatingRemainder(dividingBy: 60)))
                            .font(.caption).foregroundStyle(.secondary)
                        Text("ETA \(eta.formatted(.dateTime.hour().minute()))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let saved = savings {
                        Text(String(format: "−%.1f km vs fastest • Saves fuel", saved))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                }
            }
            .padding(16)
            .background(
                isSelected
                    ? color.opacity(0.08)
                    : Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
```

### Fix Part C — Update `TripNavigationContainerView.swift`

Replace the current `.task` / `.onAppear` pattern with the deferred-start flow:

```swift
struct TripNavigationContainerView: View {

    @State private var coordinator: TripNavigationCoordinator
    @State private var showProofOfDelivery = false
    @State private var showRouteSelection = false
    @State private var isBuildingRoutes = false
    @State private var lastSpokenInstruction = ""
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let speechSynthesizer = AVSpeechSynthesizer()

    init(trip: Trip) {
        _coordinator = State(initialValue: TripNavigationCoordinator(trip: trip))
    }

    private var user: AuthUser? { AuthManager.shared.currentUser }

    var body: some View {
        ZStack {
            TripNavigationView(coordinator: coordinator)
            NavigationHUDOverlay(coordinator: coordinator) {
                coordinator.stopLocationPublishing()
                coordinator.isNavigating = false
                showProofOfDelivery = true
            }

            // Route-calculating spinner shown before RouteSelectionSheet appears
            if isBuildingRoutes {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.4)
                        .tint(.white)
                    Text("Calculating routes…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
                .padding(32)
                .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .task {
            // Build routes first — do NOT start location tracking yet.
            // Location tracking + publishing begin only after the driver
            // confirms a route in RouteSelectionSheet.
            isBuildingRoutes = true
            await coordinator.buildRoutes()
            isBuildingRoutes = false
            // Only show sheet if routes were successfully built
            if coordinator.currentRoute != nil {
                showRouteSelection = true
            }
        }
        .onChange(of: coordinator.currentStepInstruction) { _, newInstruction in
            guard !newInstruction.isEmpty, newInstruction != lastSpokenInstruction else { return }
            lastSpokenInstruction = newInstruction
            let utterance = AVSpeechUtterance(string: newInstruction)
            utterance.rate = 0.52
            utterance.voice = AVSpeechSynthesisVoice(language: "en-IN")
            speechSynthesizer.speak(utterance)
        }
        .onDisappear {
            coordinator.stopLocationPublishing()
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        .sheet(isPresented: $showRouteSelection) {
            RouteSelectionSheet(coordinator: coordinator) {
                // Driver confirmed a route — now start location tracking
                guard let vehicleIdStr = coordinator.trip.vehicleId,
                      let vehicleId = UUID(uuidString: vehicleIdStr),
                      let driverId = user?.id else { return }
                coordinator.startLocationTracking()
                coordinator.startLocationPublishing(vehicleId: vehicleId, driverId: driverId)
            }
        }
        .sheet(isPresented: $showProofOfDelivery) {
            NavigationStack {
                ProofOfDeliveryView(
                    tripId: coordinator.trip.id,
                    driverId: user?.id ?? UUID()
                ) {
                    showProofOfDelivery = false
                    dismiss()
                }
            }
        }
    }
}
```

**Key differences from current implementation:**
- `.onAppear` with `startLocationTracking` + `startLocationPublishing` is REMOVED
- `.task` builds routes then shows `RouteSelectionSheet`
- Location tracking only starts in the `RouteSelectionSheet.onStart` callback
- A spinner is shown while routes are building (addresses the UX gap where the map was blank with no feedback)
- `showRouteSelection` is guarded on `coordinator.currentRoute != nil` so if the API call fails, the sheet doesn't show a broken UI

---

## Constraints
- `@Observable` only, no `@Published`
- `selectGreenRoute()` must NOT call `buildRoutes()` — it just swaps the two computed routes already in memory
- `RouteSelectionSheet` must use `.interactiveDismissDisabled()` to prevent the driver from accidentally swiping it away
- When `alternativeRoute` is nil (single route returned by Mapbox — common on rural roads), show only the Fastest card with no Green card. No crash, graceful degradation.
- `RouteSelectionSheet` takes a `TripNavigationCoordinator` reference, not a binding, so it can call `coordinator.selectGreenRoute()` directly
- Do NOT change `StartTripSheet.swift` — that sheet handles odometer entry and route pre-fetching (the Route Selector replaces the selection part, not the odometer entry part)

## Verification Checklist
- [ ] `AdminDashboardView` calls `store.loadAll()` on appear; fleet map shows vehicle annotations
- [ ] `store.subscribeToVehicleUpdates()` channel opens (check Xcode console: no "channel error" messages)
- [ ] Tapping Navigate on an active trip shows spinner while routes build
- [ ] After routes build, `RouteSelectionSheet` appears with at least one route card
- [ ] When two routes available: Fastest card (bolt/blue) + Green card (leaf/green) shown
- [ ] Green card shows distance savings badge when saving >200m
- [ ] Selecting Green card then tapping Start Navigation calls `coordinator.selectGreenRoute()` (verify via console print or breakpoint)
- [ ] Location tracking starts AFTER route confirmation, not before
- [ ] When only one route returned: single Fastest card shown, no Green card, no crash
- [ ] Navigation proceeds with the route the driver selected (verify deviationCoords are from correct route)
- [ ] `MBXAccessToken` is non-empty in local build — map renders
- [ ] Build clean, zero warnings
