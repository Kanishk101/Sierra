# Phase 5 Safeguards — Mapbox Navigation
## THE MOST CRITICAL PHASE FOR BILLING. Attach these at the END of your Phase 5 prompt before Claude writes any code.

---

## SAFEGUARD 1 — THE MOST IMPORTANT: Location publishing Timer must be the ONLY trigger

The location publishing loop must use a single Timer with a minimum 5-second interval. There must be NO other path that calls AppDataStore.publishDriverLocation().

In TripNavigationCoordinator.startLocationPublishing():

  private var locationPublishTimer: Timer?
  private let locationPublishInterval: TimeInterval = 5.0

  func startLocationPublishing(vehicleId: UUID, driverId: UUID) {
    guard locationPublishTimer == nil else { return }  // CRITICAL: prevent double-start
    locationPublishTimer = Timer.scheduledTimer(
      withTimeInterval: locationPublishInterval,
      repeats: true
    ) { [weak self] _ in
      guard let self, let location = self.currentLocation else { return }
      Task {
        await AppDataStore.shared.publishDriverLocation(
          vehicleId: vehicleId,
          tripId: self.trip.id,
          latitude: location.coordinate.latitude,
          longitude: location.coordinate.longitude,
          speedKmh: location.speed > 0 ? location.speed * 3.6 : nil
        )
      }
    }
  }

  func stopLocationPublishing() {
    locationPublishTimer?.invalidate()
    locationPublishTimer = nil
  }

VERIFY: publishDriverLocation is NOT called from NavigationViewController delegate methods, NOT called from CLLocationManagerDelegate, NOT called from any .onChange or view lifecycle method.

## SAFEGUARD 2 — buildRoutes() must be called exactly once per navigation session

In TripNavigationCoordinator:

  private var hasBuiltRoutes = false

  func buildRoutes() async {
    guard !hasBuiltRoutes else { return }
    hasBuiltRoutes = true
    // ... route building logic
  }

This prevents multiple Directions API calls if TripNavigationContainerView's .onAppear fires more than once (which can happen with sheet/fullScreenCover presentation on some iOS versions).

## SAFEGUARD 3 — Deviation check must use LOCAL polyline math, zero network calls

checkDeviation(from location: CLLocation) must compute distance entirely on-device. The algorithm:

  1. Decode trips.route_polyline from encoded polyline format to [CLLocationCoordinate2D]
     Use a local polyline decoder (write a pure Swift function — no library needed, the algorithm is simple)
  2. For each consecutive pair of coordinates in the route, compute the perpendicular distance from location to that line segment using the Haversine formula
  3. Take the minimum distance across all segments
  4. If minimum distance > 200 metres AND more than 60 seconds have elapsed since the last deviation was recorded, call RouteDeviationService.recordDeviation(...)

This function must contain ZERO URLSession calls, ZERO Mapbox API calls, ZERO async operations. It is pure synchronous math. Only the downstream RouteDeviationService.recordDeviation call is async.

Enforce a cooldown:
  private var lastDeviationRecordedAt: Date = .distantPast
  private let deviationCooldownSeconds: TimeInterval = 60.0

  func checkDeviation(from location: CLLocation) {
    let deviationMetres = computeLocalDeviationDistance(location: location)
    guard deviationMetres > 200 else { return }
    guard Date().timeIntervalSince(lastDeviationRecordedAt) > deviationCooldownSeconds else { return }
    lastDeviationRecordedAt = Date()
    Task {
      try? await RouteDeviationService.shared.recordDeviation(...)
    }
  }

## SAFEGUARD 4 — NavigationViewController must NEVER be recreated during an active session

The UIViewControllerRepresentable.makeUIViewController is called once. updateUIViewController handles updates. If Claude puts NavigationViewController creation inside updateUIViewController, a new navigation session is created every time any SwiftUI state changes, generating a new map load and a new Directions API call every render.

Verify the implementation:
  - makeUIViewController: creates NavigationViewController ONCE, stores it
  - updateUIViewController: only updates UI elements (if anything), never recreates the controller

If Claude puts NavigationViewController() inside updateUIViewController, reject it entirely.

## SAFEGUARD 5 — Add Stop geocoding must be debounced at 500ms

The Add Stop address text field in NavigationHUDOverlay uses Mapbox Geocoding API. Apply the exact same debounce pattern from Phase 4 Safeguard 4. Typing 20 characters = 1 API call (fired 500ms after typing stops), not 20 API calls.

## SAFEGUARD 6 — Voice guidance must use Mapbox's built-in, not a custom AVSpeechSynthesizer

NavigationViewController provides voice guidance automatically. Do not add any custom AVSpeechSynthesizer or Text-to-Speech implementation. Two voice guidance systems firing simultaneously is a terrible user experience and causes audio session conflicts with other apps. The prompt says not to add custom voice — verify this is not present.

## SAFEGUARD 7 — Never call UIApplication.shared.open() with a maps URL from anywhere in this phase

Search the generated code for:
  - UIApplication.shared.open
  - "maps.apple.com"
  - "maps.google.com"
  - "waze.com"
  - "comgooglemaps"
  - "http://maps"

If any of these appear, reject the code. All navigation is in-app.

## SAFEGUARD 8 — Background location must request Always authorization before trip starts

Before startLocationPublishing is called, verify location authorization status:

  let status = CLLocationManager().authorizationStatus
  guard status == .authorizedAlways else {
    // Request Always authorization
    locationManager.requestAlwaysAuthorization()
    return
  }

Without Always authorization, location updates stop the moment the app backgrounds, which breaks continuous trip tracking. The user must be prompted once — this is why the Info.plist NSLocationAlways keys are required in the manual setup step.

## SAFEGUARD 9 — TripNavigationContainerView must use .ignoresSafeArea() and suppress all SwiftUI chrome

The navigation view must be truly fullscreen. Verify:
  - .ignoresSafeArea() on the ZStack
  - .navigationBarHidden(true) or NavigationStack is not wrapping it
  - No TabBar visible during navigation (use .toolbar(.hidden, for: .tabBar))
  - Status bar should remain visible for time/battery info

## VERIFICATION CHECKLIST — Before committing

- [ ] locationPublishTimer has nil guard preventing double-start
- [ ] stopLocationPublishing() always called in navigationViewControllerDidDismiss AND didArriveAt
- [ ] buildRoutes() has hasBuiltRoutes guard
- [ ] checkDeviation uses zero network calls, pure local math
- [ ] deviationCooldown of 60 seconds enforced
- [ ] makeUIViewController creates NavigationViewController once only
- [ ] Add Stop geocoding has 500ms debounce
- [ ] No AVSpeechSynthesizer anywhere in the file
- [ ] No UIApplication.shared.open() with maps URL anywhere
- [ ] Background location authorization checked before trip starts
- [ ] Full screen with .ignoresSafeArea() and tab bar hidden
