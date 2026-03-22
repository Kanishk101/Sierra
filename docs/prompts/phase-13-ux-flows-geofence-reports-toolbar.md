# Phase 13 — UX Flows: Geofence Placement, Reports Pagination, Toolbar Cleanup

## Scope
Fix geofence creation to only happen as the final step in trip creation. Remove the floating
geofence create button from the live map. Remove the "more" / ellipsis toolbar button from
the admin dashboard. Make AnalyticsDashboardView and ReportsView paginated sheets.

---

## Fix 1 — Geofence Flow Scoped to Trip Creation Only

### Current Problems

1. `FleetLiveMapView.swift` has a floating `plus.circle.fill` button that opens `CreateGeofenceSheet`
   directly from the map at any time with no trip context
2. `QuickActionsSheet.swift` has "View Geofences" as a navigation action — acceptable, but adding
   a geofence from there lacks trip context
3. Geofence creation is conceptually tied to a trip: it defines zones the vehicle must enter/exit
   during that specific route. Creating standalone geofences divorced from a trip is confusing

### Correct Flow
```
Create Trip Wizard:
  Step 1: Route (origin + stops + destination)
  Step 2: Assign Driver
  Step 3: Assign Vehicle
  Step 4: Add Geofences (optional) ← NEW — create geofences for THIS trip's route
  → Create Trip
```

### Fix Instructions

**A. Remove geofence create button from `FleetLiveMapView.swift`**

In `FleetLiveMapView`, the floating buttons block:
```swift
VStack(spacing: 12) {
    floatingButton(icon: "magnifyingglass.circle.fill") {
        showVehicleSearch = true
    }
    floatingButton(icon: "line.3.horizontal.decrease.circle.fill") {
        viewModel.showFilterPicker = true
    }
    // REMOVE THIS BUTTON:
    floatingButton(icon: "plus.circle.fill") {
        viewModel.showCreateGeofence = true
    }
}
```
Also remove `showCreateGeofence` sheet attachment and the `viewModel.showCreateGeofence` property
usage in this file. Keep the `GeofenceListView` accessible only via QuickActions or Dashboard nav.

**B. Remove geofence create from QuickActionsSheet**

In `QuickActionsSheet.swift`, the `actions` array currently has a "Maint. Request" action.
The geofence action is reached via `onNavigate(.geofences)` which opens `GeofenceListView` as
a read-only list. This is fine — keep it. But remove any button that opens `CreateGeofenceSheet`
directly from `QuickActionsSheet`.

**C. Add Step 4 (Geofences) to `CreateTripView.swift`**

Add a 4th step to the `currentStep` state machine:
```swift
// State
@State private var currentStep = 1  // 1..4
@State private var tripGeofences: [GeofenceCandidate] = []

struct GeofenceCandidate: Identifiable {
    let id = UUID()
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double = 500
    var alertOnEntry: Bool = true
    var alertOnExit: Bool = true
}
```

Update `stepIndicator` to show 4 steps instead of 3.

Update Step 3 "Next" button label:
```swift
Text("Next: Add Geofences")
```

Add `step4View` — a simple optional geofence builder:
```swift
private var step4View: some View {
    VStack(spacing: 0) {
        VStack(spacing: 4) {
            Text("Add Geofences (Optional)")
                .font(.system(size: 18, weight: .bold))
            Text("Define zones to monitor during this trip")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.top, 8).padding(.bottom, 12)

        List {
            // Route markers as suggested starting points
            Section("Suggested Zones") {
                if let o = selectedOrigin {
                    geofenceSuggestionRow(name: "Origin: \(o.shortName)",
                                          lat: o.latitude, lng: o.longitude)
                }
                ForEach(Array(stops.enumerated()), id: \.element.id) { i, stop in
                    geofenceSuggestionRow(name: "Stop \(i+1): \(stop.shortName)",
                                          lat: stop.latitude, lng: stop.longitude)
                }
                if let d = selectedDestination {
                    geofenceSuggestionRow(name: "Destination: \(d.shortName)",
                                          lat: d.latitude, lng: d.longitude)
                }
            }
            if !tripGeofences.isEmpty {
                Section("Added Geofences (\(tripGeofences.count))") {
                    ForEach(tripGeofences) { gf in
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.teal)
                            Text(gf.name).font(.subheadline)
                            Spacer()
                            Text("\(Int(gf.radiusMeters))m radius")
                                .font(.caption).foregroundStyle(.secondary)
                            Button { tripGeofences.removeAll { $0.id == gf.id } } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red.opacity(0.6))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)

        // Create Trip button
        Button {
            Task { await createTrip() }
        } label: {
            HStack {
                if isCreating {
                    ProgressView().scaleEffect(0.9).tint(.white)
                } else {
                    Text("Create Trip")
                    Image(systemName: "checkmark")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(isCreating)
        .padding(.horizontal, 20).padding(.bottom, 12)
    }
}

private func geofenceSuggestionRow(name: String, lat: Double, lng: Double) -> some View {
    Button {
        tripGeofences.append(GeofenceCandidate(
            name: name, latitude: lat, longitude: lng
        ))
    } label: {
        HStack {
            Image(systemName: "plus.circle").foregroundStyle(.teal)
            Text(name).font(.subheadline).foregroundStyle(.primary)
            Spacer()
            Text("Add").font(.caption).foregroundStyle(.teal)
        }
    }
    .buttonStyle(.plain)
    .disabled(tripGeofences.contains { $0.latitude == lat && $0.longitude == lng })
}
```

In `createTrip()`, after `store.addTrip(trip)` succeeds, persist the geofences:
```swift
// Persist geofences for this trip
let adminId = AuthManager.shared.currentUser?.id ?? UUID()
for gf in tripGeofences {
    let geofence = Geofence(
        id: UUID(),
        name: gf.name,
        description: "Auto-created for trip \(trip.taskId)",
        latitude: gf.latitude,
        longitude: gf.longitude,
        radiusMeters: gf.radiusMeters,
        isActive: true,
        createdByAdminId: adminId,
        alertOnEntry: gf.alertOnEntry,
        alertOnExit: gf.alertOnExit,
        geofenceType: .custom,
        createdAt: Date(),
        updatedAt: Date()
    )
    try? await store.addGeofence(geofence)
}
```

---

## Fix 2 — AnalyticsDashboardView as Paginated Sheet

### Current Problem
`AnalyticsDashboardView.swift` (43KB) is a single monolithic ScrollView presented as a sheet.
The user must scroll through everything in one continuous scroll. With 7+ sections (Fleet Overview,
Maintenance Stats, Driver Activity, Fuel Analytics, Cost Breakdown, etc.) this is overwhelming.

### Fix Instructions

Wrap `AnalyticsDashboardView.body` in a tab-page structure:

```swift
struct AnalyticsDashboardView: View {
    @Environment(AppDataStore.self) private var store
    @State private var selectedPage = 0
    @Environment(\.dismiss) private var dismiss

    private let pages = [
        "Fleet", "Trips", "Maintenance", "Drivers", "Fuel & Cost"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Page indicator pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { i, label in
                            Button { withAnimation { selectedPage = i } } label: {
                                Text(label)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(selectedPage == i ? .white : .primary)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(
                                        selectedPage == i ? Color.orange : Color.primary.opacity(0.08),
                                        in: Capsule()
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                }

                Divider()

                TabView(selection: $selectedPage) {
                    fleetPage.tag(0)
                    tripsPage.tag(1)
                    maintenancePage.tag(2)
                    driverActivityPage.tag(3)
                    fuelCostPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: selectedPage)
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // Each page is a ScrollView with the relevant existing sections
    private var fleetPage: some View { /* existing fleet overview sections */ }
    private var tripsPage: some View { /* existing trip analytics sections */ }
    private var maintenancePage: some View { /* maintenance stats */ }
    private var driverActivityPage: some View { /* driver activity table */ }
    private var fuelCostPage: some View { /* fuel + cost sections */ }
}
```

Break the existing large `body` into these 5 private vars by moving existing section builders.

---

## Fix 3 — ReportsView as Paginated Sheet

### Current Problem
`ReportsView.swift` (31KB) — check if it already uses `TabView(.page)`. If not, apply the same
pagination pattern. The sheet should have pages: Overview, Fleet Report, Driver Report,
Maintenance Report, and Export.

If it's already paginated with TabView(.page), verify:
- `.presentationDetents([.large])` is set when showing from DashboardHomeView
- The page indicator dots are visible and the content fits within a `.large` detent without clipping
- Export buttons on the Export page use `UIActivityViewController` (existing implementation) correctly

---

## Fix 4 — Remove "More" / Ellipsis Button from Admin Dashboard Toolbar

### Where It Appears

`DashboardHomeView.swift` has TWO toolbar items:
- `.topBarLeading`: bell notification button  
- `.topBarTrailing`: profile button (`person.crop.circle`)

The user reports a "more button beside the profile button." This is likely:
1. A `...` ellipsis button that may appear in sub-views opened from the dashboard
2. The `AnalyticsDashboardView` toolbar may have extra buttons
3. The NavigationStack may be showing an automatic context menu button

**In `DashboardHomeView.swift`**, ensure `.toolbar` only has the bell and profile:
```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        // notification bell — keep
    }
    ToolbarItem(placement: .topBarTrailing) {
        // profile button — keep
    }
    // No other toolbar items
}
```

If `AnalyticsDashboardView` or `ReportsView` have a `ToolbarItem(placement: .topBarTrailing)` with
an ellipsis or overflow menu, remove it — only keep the `Done` dismiss button.

Scan all admin-facing views for:
```swift
Image(systemName: "ellipsis")
Image(systemName: "ellipsis.circle")
Image(systemName: "ellipsis.circle.fill")
```
and remove any that serve as "more" menus — surface those actions inline instead.

---

## Files to Modify

| File | Change |
|---|---|
| `Sierra/FleetManager/Views/FleetLiveMapView.swift` | Remove `plus.circle.fill` floating button and `showCreateGeofence` sheet |
| `Sierra/FleetManager/Views/CreateTripView.swift` | Add Step 4 (Geofences), update step indicator to 4 steps |
| `Sierra/FleetManager/Views/AnalyticsDashboardView.swift` | Wrap in paginated TabView with 5 named pages |
| `Sierra/FleetManager/Views/ReportsView.swift` | Verify/apply pagination, fix detent |
| `Sierra/FleetManager/Views/DashboardHomeView.swift` | Remove any non-bell/profile toolbar items |
| Any view with ellipsis toolbar items | Remove overflow menus |

---

## Acceptance Criteria

- [ ] FleetLiveMapView floating buttons: only search and filter (no create geofence)
- [ ] Create Trip wizard shows 4 steps with step 4 being the optional geofence step
- [ ] Geofences added in step 4 are persisted to Supabase after trip is created
- [ ] AnalyticsDashboardView opens as a sheet with 5 swipeable pages + pill selector
- [ ] ReportsView sheet is paginated with identifiable page sections
- [ ] Admin dashboard toolbar shows ONLY bell notification and profile buttons
