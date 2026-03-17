# Phase 8 Safeguards — Alerts & SOS
## Attach these instructions at the END of your Phase 8 prompt session before Claude writes any code.

---

## SAFEGUARD 1 — SOS alert must be submitted exactly once regardless of network conditions

The SOS "SEND ALERT" button is a high-stakes single action. If the user taps it and the network is slow, they may tap again. This must not create duplicate emergency_alerts rows.

Implement:
  @State private var alertSent = false
  @State private var isSending = false

  Button("SEND ALERT") {
    guard !alertSent && !isSending else { return }
    isSending = true
    Task {
      do {
        try await EmergencyAlertService.shared.createAlert(...)
        alertSent = true
      } catch {
        isSending = false  // allow retry on genuine failure
        errorMessage = "Failed to send alert. Tap again to retry."
      }
    }
  }
  .disabled(alertSent || isSending)

Once alertSent = true, the button never re-enables for this session.

## SAFEGUARD 2 — GPS coordinates must be validated before SOS submission

If CLLocationManager has not yet acquired a fix, currentLocation may be nil or (0,0). Submitting an alert at coordinates (0,0) is useless to the FM trying to locate the driver.

Before sending the alert:
  guard let location = locationManager.location, location.coordinate.latitude != 0 else {
    // Show "Acquiring location..." and retry after 2 seconds
    return
  }

If after 10 seconds no valid location is available, allow submission anyway but log a warning. Never block SOS submission entirely due to GPS failure — just show a warning that location is approximate.

## SAFEGUARD 3 — AlertsInboxView must NOT poll on a timer

The FM's alert inbox gets new alerts via Supabase Realtime subscription, not polling. There must be no Timer, DispatchQueue.asyncAfter, or Task.sleep loop that repeatedly fetches emergency_alerts or route_deviation_events.

All live updates come through the existing Realtime channel on emergency_alerts set up in AppDataStore (or a dedicated service channel). A manual "pull to refresh" is acceptable as an explicit user-triggered fetch.

## SAFEGUARD 4 — Reverse geocoding for alert location must be cached and not called per row

AlertsInboxView may show multiple alert rows, each with a GPS coordinate that needs reverse geocoding ("near {address}"). Never reverse geocode inside the list row's view body or in a ForEach — this fires one geocoding API call per visible row on every render.

Pattern:
  - Maintain a Dictionary<UUID, String> in the view model: var reversedAddresses: [UUID: String] = [:]
  - When an alert is loaded, check if reversedAddresses[alert.id] exists
  - If not, fire ONE reverse geocoding call using CLGeocoder (Apple's geocoder, completely free — not Mapbox)
  - On result, store in reversedAddresses[alert.id]
  - Use CLGeocoder, not Mapbox Geocoding API, for reverse geocoding. CLGeocoder is free and unlimited for reverse geocoding.

This means each alert address is only geocoded once per app session.

## SAFEGUARD 5 — NotificationCentreView must query AppDataStore.notifications, not Supabase directly

NotificationCentreView reads from AppDataStore.notifications which is already populated and kept current by the Realtime subscription from Phase 3. It must NOT make its own Supabase query in .onAppear. Querying Supabase directly from NotificationCentreView bypasses the in-memory cache and creates duplicate fetches.

The only Supabase call allowed from NotificationCentreView:
  - NotificationService.markAsRead(notificationId:) on tap
  - NotificationService.markAllAsRead(for:) on "Mark all read" button

## SAFEGUARD 6 — "Call Driver" tel:// link is the only UIApplication.shared.open() permitted in this phase

AlertDetailView has a "Call Driver" button that uses tel:// to open the phone dialer. This is the one and only acceptable UIApplication.shared.open() call across the entire Sprint 2 codebase. Every other instance is prohibited (maps, external navigation, etc.).

Implement safely:
  if let url = URL(string: "tel://\(driver.phone.filter { $0.isNumber })") {
    UIApplication.shared.open(url)
  }

## SAFEGUARD 7 — checkOverdueMaintenance deduplication must match Phase 3

In Phase 3, checkOverdueMaintenance checks AppDataStore.notifications for existing overdue notifications. In Phase 8, when this method is called from .onReceive(UIApplication.didBecomeActiveNotification), it must use the SAME deduplication logic, not a separate fetch to Supabase. Reading AppDataStore.notifications in-memory is free. Querying Supabase to check for duplicates on every foreground event is wasteful.

## VERIFICATION CHECKLIST — Before committing

- [ ] SOS button has alertSent guard preventing duplicate submissions
- [ ] GPS validated before SOS submission with graceful fallback
- [ ] AlertsInboxView has zero polling timers — Realtime only
- [ ] Reverse geocoding uses CLGeocoder (free), not Mapbox
- [ ] Reverse geocoding results cached in dictionary, not called per-row per-render
- [ ] NotificationCentreView reads AppDataStore.notifications, not its own Supabase query
- [ ] Only one UIApplication.shared.open() in the phase — the tel:// call in AlertDetailView
- [ ] checkOverdueMaintenance deduplication reads in-memory, not Supabase
