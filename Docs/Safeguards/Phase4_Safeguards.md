# Phase 4 Safeguards — Trip Lifecycle
## Attach these instructions at the END of your Phase 4 prompt session before Claude writes any code.

---

## SAFEGUARD 1 — Photo uploads must be sequential with individual error handling

When uploading multiple inspection photos, upload them one at a time in a loop — not concurrently with async let or TaskGroup. Concurrent uploads to Supabase Storage from a mobile device frequently fail with rate limit errors or connection resets when more than 2-3 are in flight simultaneously.

Pattern:
  var uploadedUrls: [String] = []
  for (index, imageData) in photos.enumerated() {
    do {
      let url = try await StorageService.upload(imageData, path: "pre-trip/\(tripId)/\(index).jpg")
      uploadedUrls.append(url)
    } catch {
      // Log but continue — partial photo upload is acceptable
      print("[Inspection] Photo \(index) failed to upload: \(error)")
    }
  }

Never use withThrowingTaskGroup for photo uploads. The partial-success pattern (upload what you can) is correct for photo evidence.

## SAFEGUARD 2 — Inspection submission must be atomic — inspect then update trip

The inspection row must be fully inserted (with all photo URLs) before trips.pre_inspection_id is updated. If the order is reversed and the trip row update happens first, then the inspection insert fails, you have a trips row pointing to a non-existent inspection ID — an orphaned FK.

Correct order:
  1. Upload all photos → get URLs
  2. INSERT vehicle_inspections row with all data including photo_urls
  3. Get the returned inspection.id
  4. UPDATE trips SET pre_inspection_id = inspection.id

If step 4 fails, the inspection row exists but isn't linked — acceptable, because it can be re-linked. The reverse causes a FK violation.

## SAFEGUARD 3 — Mapbox Directions API in StartTripSheet must fire ONCE per user action

The route fetch in StartTripSheet (the URLSession call to api.mapbox.com/directions/v5) must only fire when the user taps "Preview Route" or "Start Navigation" — never reactively on any @State change.

Specifically prohibit:
- Calling the route fetch in .onChange of the avoidTolls toggle
- Calling the route fetch in .onChange of the avoidHighways toggle
- Calling the route fetch on .onAppear
- Calling the route fetch inside any computed property

The ONLY triggers for a Directions API call:
  1. User taps "Preview Route" button (optional pre-check)
  2. User taps "Start Navigation" button (required, builds final route)

If the user changes avoidTolls and taps Start Navigation, that is ONE call. Do not pre-fetch on toggle change.

## SAFEGUARD 4 — Geocoding in AddStop must be debounced at 500ms minimum

When the driver types an address in the Add Stop text field, the Mapbox Geocoding API must not fire on every keystroke. Implement a debounce:

  @State private var stopAddressQuery = ""
  @State private var geocodeTask: Task<Void, Never>? = nil

  .onChange(of: stopAddressQuery) { newValue in
    geocodeTask?.cancel()
    geocodeTask = Task {
      try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms
      guard !Task.isCancelled else { return }
      await geocodeAddress(newValue)
    }
  }

This means only the final address (500ms after the user stops typing) triggers a geocoding request. This is critical — without this, typing a 20-character address fires 20 API requests.

## SAFEGUARD 5 — OTP hash must be generated on device, never sent to Supabase in plaintext

In ProofOfDeliveryView, if the driver selects OTP Verification method:
- Generate a 6-digit OTP as a String on device
- Hash it using CryptoService (which already exists in the codebase at Sierra/Shared/Services/CryptoService.swift)
- Store the HASH in proof_of_deliveries.delivery_otp_hash
- Store now() + 10 minutes in delivery_otp_expires_at
- Display the OTP to the driver to read out to the recipient
- When the driver types back the OTP the recipient confirms, hash the entered value and compare to stored hash

Never store the raw OTP in Supabase. Never log the OTP to console. The plaintext OTP must only exist in memory on the device and be displayed once to the driver.

## SAFEGUARD 6 — CompleteTrip must only be callable after proof of delivery is submitted

The "Complete Trip" / end trip flow must enforce this order:
  1. Mark delivery complete (create ProofOfDelivery row)
  2. Complete post-trip inspection
  3. THEN call AppDataStore.completeTrip()

Block the path to completeTrip if proofOfDeliveryId is nil on the trip. Show an error: "Please submit proof of delivery before completing the trip."

This prevents the DB trigger from firing (which updates vehicle/driver stats) before the trip is actually finished.

## SAFEGUARD 7 — All async operations in views must use Task {} not .task {}

The .task {} view modifier cancels its task when the view disappears. For operations like inspection submission or trip start, the view may dismiss as part of the success flow, which would cancel the task mid-write and leave the DB in a partial state.

Use Task { } for any write operation that must complete even if the view is dismissed:
  Button("Submit Inspection") {
    Task {
      await viewModel.submitInspection()
      // navigation happens after await completes
    }
  }

Never use .task { await viewModel.submitInspection() } for write operations.

## VERIFICATION CHECKLIST — Before committing

- [ ] Photo uploads sequential in a for-loop, not concurrent
- [ ] Inspection inserted before trips.pre_inspection_id updated
- [ ] Directions API called ONLY on explicit user button tap, never reactively
- [ ] Address geocoding in Add Stop has 500ms debounce with task cancellation
- [ ] OTP stored as hash (via CryptoService), never plaintext
- [ ] completeTrip() gated behind proof_of_delivery_id check
- [ ] All write operation buttons use Task { } not .task { }
