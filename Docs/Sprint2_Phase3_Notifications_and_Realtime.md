# Sprint 2 — Phase 3: Notifications, Realtime Consolidation + ViewModel Extractions

> **Prerequisite:** Phase 2 complete.  
> **This phase covers:** NotificationBannerView, tab badges, RealtimeSubscriptionManager, remaining ViewModel extractions (SOSAlertViewModel, PostTripInspectionViewModel, DriverHomeViewModel)

---

## Context

Realtime infrastructure in the current repo is **fragmented but functional**:
- `AppDataStore` has channels for `emergency_alerts`, `staff_members`, `vehicles`, `trips`
- `NotificationService` has a channel for `notifications`
- There is no centralised `RealtimeSubscriptionManager` — channels are scattered
- Several features have logic embedded in views instead of ViewModels

This phase consolidates realtime into a single manager, adds the notification banner UI, and extracts the remaining view-embedded logic into proper ViewModels.

---

## Task 7 — NotificationBannerView

### Files to create

- `Sierra/Shared/Views/NotificationBannerView.swift` ← CREATE

### Files to modify

- `Sierra/Driver/Views/DriverTabView.swift` ← MODIFY: add banner overlay + unread badge
- `Sierra/Maintenance/Views/MaintenanceTabView.swift` ← MODIFY: add banner overlay + unread badge

---

### NotificationBannerView.swift

Build a slide-down banner overlay:

```swift
struct NotificationBannerView: View {
    let title: String
    let body: String
    let onTap: () -> Void

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline).fontWeight(.semibold)
                    Text(body)
                        .font(.caption)
                        .lineLimit(2)
                }
                .foregroundStyle(.primary)
                Spacer()
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .onTapGesture { onTap() }
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(duration: 0.4), value: true)
    }
}
```

### Banner coordinator

Create a helper `@Observable` class to manage banner queue:

```swift
@Observable
final class BannerCoordinator {
    struct Banner: Identifiable {
        let id = UUID()
        let title: String
        let body: String
        var onTap: () -> Void = {}
    }

    var current: Banner? = nil
    private var queue: [Banner] = []
    private var dismissTask: Task<Void, Never>? = nil

    func show(_ banner: Banner) {
        queue.append(banner)
        if current == nil { showNext() }
    }

    private func showNext() {
        guard !queue.isEmpty else { current = nil; return }
        current = queue.removeFirst()
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled {
                withAnimation { current = nil }
                showNext()
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation { current = nil }
        showNext()
    }
}
```

Store `BannerCoordinator` as a `@State` in each tab view, or add it to `AppDataStore` as a shared property.

### Wire into DriverTabView

```swift
@State private var bannerCoordinator = BannerCoordinator()

var body: some View {
    TabView { ... }
    .overlay(alignment: .top) {
        if let banner = bannerCoordinator.current {
            NotificationBannerView(title: banner.title, body: banner.body) {
                bannerCoordinator.dismiss()
                banner.onTap()
            }
        }
    }
    .onChange(of: store.notifications.count) { _, _ in
        // When a new notification arrives for this driver, show a banner
        if let latest = store.notifications.last, !latest.isRead {
            bannerCoordinator.show(.init(title: latest.title, body: latest.body))
        }
    }
}
```

Repeat the same pattern for `MaintenanceTabView`.

### Tab badge — Driver

In `DriverTabView`, add to the relevant tab item:

```swift
.badge(store.notifications.filter { !$0.isRead }.count)
```

Where `store.notifications` is the `notifications` array in `AppDataStore`, filtered to the current user (the realtime channel and RLS already scope this to the logged-in user).

### Tab badge — Maintenance

Same pattern — badge on the tasks/notifications tab with unread count.

### Verify

- Send a notification to the driver (e.g., trigger a trip assignment or SOS acknowledgement)
- Banner slides down, stays 4 seconds, auto-dismisses
- Tapping the banner dismisses it immediately
- Badge count increments on new notification, resets to 0 after all are read

### Jira stories
FMS1-46, FMS1-15, FMS1-66, FMS1-67

---

## Task 8 — RealtimeSubscriptionManager

### Context

Realtime channels are currently scattered:
- `AppDataStore` manages some channels directly
- `NotificationService` manages the notifications channel
- There is no single start/stop lifecycle

This task consolidates everything into a single manager without breaking existing behaviour.

### File to create

`Sierra/Shared/Services/RealtimeSubscriptionManager.swift` ← CREATE

---

### RealtimeSubscriptionManager.swift

```swift
import Foundation
import Supabase

@Observable
final class RealtimeSubscriptionManager {
    static let shared = RealtimeSubscriptionManager()
    private var channels: [RealtimeChannelV2] = []
    private init() {}

    func startAll(store: AppDataStore) {
        stopAll()  // clean up before restarting

        // vehicle_location_history — live map feed
        let locChannel = supabase.channel("vehicle-locations")
        locChannel
            .onPostgresChanges(
                AnyAction.self,
                schema: "public",
                table: "vehicle_location_history"
            ) { payload in
                // Decode and update store.vehicleLocations[vehicleId]
                // Use the same AppDataStore update pattern you use elsewhere
            }
        Task { await locChannel.subscribe() }
        channels.append(locChannel)

        // emergency_alerts
        let alertChannel = supabase.channel("emergency-alerts")
        alertChannel
            .onPostgresChanges(
                AnyAction.self,
                schema: "public",
                table: "emergency_alerts"
            ) { payload in
                // Append new alerts to store.emergencyAlerts
            }
        Task { await alertChannel.subscribe() }
        channels.append(alertChannel)

        // route_deviation_events
        let deviationChannel = supabase.channel("route-deviations")
        deviationChannel
            .onPostgresChanges(
                AnyAction.self,
                schema: "public",
                table: "route_deviation_events"
            ) { payload in
                // Append to store.routeDeviationEvents
            }
        Task { await deviationChannel.subscribe() }
        channels.append(deviationChannel)

        // geofence_events
        let geoChannel = supabase.channel("geofence-events")
        geoChannel
            .onPostgresChanges(
                AnyAction.self,
                schema: "public",
                table: "geofence_events"
            ) { payload in
                // Append to store.geofenceEvents
            }
        Task { await geoChannel.subscribe() }
        channels.append(geoChannel)

        // maintenance_tasks — UPDATE events (for maintenance personnel)
        let maintChannel = supabase.channel("maintenance-updates")
        maintChannel
            .onPostgresChanges(
                AnyAction.self,
                schema: "public",
                table: "maintenance_tasks"
            ) { payload in
                // Update matching task in store.maintenanceTasks
            }
        Task { await maintChannel.subscribe() }
        channels.append(maintChannel)

        // notifications
        let notifChannel = supabase.channel("notifications")
        notifChannel
            .onPostgresChanges(
                AnyAction.self,
                schema: "public",
                table: "notifications"
            ) { payload in
                // Append to store.notifications
            }
        Task { await notifChannel.subscribe() }
        channels.append(notifChannel)
    }

    func stopAll() {
        for channel in channels {
            Task { await channel.unsubscribe() }
        }
        channels.removeAll()
    }
}
```

**Important implementation notes:**
- Use `supabase` as the global client from `SupabaseManager` — do not create a new client
- Match the exact channel/subscription API your codebase already uses in `AppDataStore`. Do not guess the API — look at how existing channels are subscribed in `AppDataStore.swift` and replicate that exact pattern
- Call `RealtimeSubscriptionManager.shared.startAll(store:)` from `AppDataStore` immediately after a successful login/auth
- Call `stopAll()` from the logout path in `AuthManager`
- Migrate the `AppDataStore` inline channel setup and `NotificationService` channel to this manager **only after verifying the manager works** — do not break existing channels during migration

### AppDataStore properties to add (if missing)

Check `AppDataStore.swift`. If these properties don't exist, add them:

```swift
var vehicleLocations: [String: VehicleLocationHistory] = [:]  // vehicleId → latest location
var routeDeviationEvents: [RouteDeviationEvent] = []
var geofenceEvents: [GeofenceEvent] = []
```

### Verify

- Login → open Supabase Dashboard → Realtime → confirm 6 channels are subscribed
- Trigger a geofence event → FM sees it in AlertsInboxView without refresh
- Trigger a maintenance task update → maintenance dashboard reflects change
- Logout → channels all unsubscribed (no lingering subscriptions in dashboard)

### Jira stories
FMS1-11, FMS1-15, FMS1-14, FMS1-12, FMS1-66, FMS1-67

---

## Task 9 — SOSAlertViewModel extraction

### Context

SOS behaviour is currently implemented directly in the view. Extract it into a ViewModel.

### File to create

`Sierra/Driver/ViewModels/SOSAlertViewModel.swift` ← CREATE

### File to modify

`Sierra/Driver/Views/SOSAlertSheet.swift` ← MODIFY: inject ViewModel

---

### SOSAlertViewModel.swift

```swift
@Observable
final class SOSAlertViewModel {
    var isSending = false
    var sentSuccessfully = false
    var error: String? = nil
    var currentLocation: CLLocation? = nil  // set from TripNavigationCoordinator

    private let service = EmergencyAlertService()

    func triggerSOS(driverId: String, vehicleId: String, tripId: String?) async {
        isSending = true
        error = nil
        defer { isSending = false }
        do {
            try await service.createSOSAlert(
                driverId: driverId,
                vehicleId: vehicleId,
                tripId: tripId,
                latitude: currentLocation?.coordinate.latitude,
                longitude: currentLocation?.coordinate.longitude
            )
            // Inserts into emergency_alerts
            // Realtime channel delivers to FM's AppDataStore.emergencyAlerts
            // AlertsViewModel (Task 6) surfaces it in the FM alerts inbox
            sentSuccessfully = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

### SOSAlertSheet — refactor

Replace inline SOS logic:
```swift
@State private var vm = SOSAlertViewModel()

// Wire vm.currentLocation from TripNavigationCoordinator
// Replace inline service call with: Task { await vm.triggerSOS(driverId:vehicleId:tripId:) }
// Show loading state with vm.isSending
// On vm.sentSuccessfully = true, dismiss sheet
```

### Jira stories
FMS1-45, FMS1-15

---

## Task 10 — DriverHomeViewModel extraction

### Context

`DriverHomeView` manages availability toggle and trip display logic inline. Extract to ViewModel.

### File to create

`Sierra/Driver/ViewModels/DriverHomeViewModel.swift` ← CREATE

---

### DriverHomeViewModel.swift

```swift
@Observable
final class DriverHomeViewModel {
    var driver: StaffMember? = nil
    var assignedTrip: Trip? = nil
    var isTogglingAvailability = false
    var error: String? = nil

    private let staffService = StaffMemberService()

    func load(from store: AppDataStore) {
        driver = store.currentDriver   // whatever the AppDataStore property is
        assignedTrip = store.assignedTrip
    }

    func toggleAvailability() async {
        guard let driver else { return }
        isTogglingAvailability = true
        defer { isTogglingAvailability = false }
        let newAvailability: StaffAvailability = driver.availability == .available ? .unavailable : .available
        do {
            try await staffService.updateAvailability(driverId: driver.id, availability: newAvailability)
            // AppDataStore realtime channel will propagate the change back to the view
        } catch {
            self.error = error.localizedDescription
        }
    }

    // CRITICAL: Never manually set vehicle status here.
    // Trip start/end triggers handle vehicle status automatically.
}
```

### Jira stories
FMS1-37, FMS1-38

---

## Phase 3 Completion Checklist

- [ ] Notification banners slide in for Driver and Maintenance Personnel
- [ ] Banners auto-dismiss after 4 seconds
- [ ] Tab badge shows unread notification count
- [ ] `RealtimeSubscriptionManager` exists and consolidates all channels
- [ ] `startAll()` is called after login, `stopAll()` called on logout
- [ ] No channel leak after logout (verify in Supabase Dashboard → Realtime)
- [ ] `SOSAlertViewModel` extracts SOS logic out of the view
- [ ] `DriverHomeViewModel` extracts availability toggle logic
- [ ] AppDataStore has `vehicleLocations`, `routeDeviationEvents`, `geofenceEvents` properties
