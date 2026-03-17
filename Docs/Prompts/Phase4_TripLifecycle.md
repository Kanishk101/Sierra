# Phase 4 — Trip Lifecycle (Driver Side)

## Context
Sierra iOS app. SwiftUI + MVVM + Swift Concurrency.
Repo: Kanishk101/Sierra, main branch.
Driver views live in Sierra/Driver/Views/ and Sierra/Driver/ViewModels/.
The existing DriverHomeView.swift shows the driver's main dashboard.
AppDataStore is available via @Environment(AppDataStore.self).

## What to build
The complete driver-side trip execution flow. This is the sequence a driver follows after being assigned a trip:

  View Assigned Trip → Pre-Trip Inspection → Start Trip → [Navigation — handled in Phase 5] → Complete Delivery + Upload Proof → Post-Trip Inspection → Trip Ends

## Task 1 — TripDetailDriverView (Sierra/Driver/Views/TripDetailDriverView.swift)
A view shown when the driver taps their assigned trip in DriverHomeView.

Shows:
- Trip task_id, origin, destination, scheduled_date, priority, delivery_instructions
- Assigned vehicle (plate number, name)
- Current trip status with color-coded badge
- If status is Scheduled: "Begin Pre-Trip Inspection" button
- If status is Active: "Navigate" button (launches Phase 5 navigation) and "Complete Delivery" button
- If status is Completed: read-only completion summary

## Task 2 — PreTripInspectionView (Sierra/Driver/Views/PreTripInspectionView.swift)
A multi-step inspection form with:

Step 1 — Checklist (scroll view of toggle items):
  Brakes, Tyres, Lights (Front), Lights (Rear), Horn, Wipers, Mirrors, Fuel Level, Engine Oil, Coolant, Steering, Seatbelt, Dashboard Warning Lights
Each item has: Pass / Fail / Warning segmented picker + optional notes text field.

Step 2 — Photo Upload:
  - PhotosPicker allowing up to 5 photos
  - Uploads each selected photo to Supabase Storage bucket "inspection-photos" under path "pre-trip/{tripId}/{UUID}.jpg"
  - Stores returned URLs in an array

Step 3 — Summary + Submit:
  - Shows overall result (Passed / Failed / Passed with Warnings based on checklist)
  - If any Fail: shows warning "Issues found — Fleet Manager will be notified"
  - Submit button calls VehicleInspectionService.submitInspectionWithPhotos(...)
  - On success, if result is Failed: creates maintenance task via MaintenanceTaskService
  - Updates trips.pre_inspection_id
  - If result is Passed or Passed with Warnings: enables "Start Trip" button

ViewModel: PreTripInspectionViewModel in Sierra/Driver/ViewModels/PreTripInspectionViewModel.swift

## Task 3 — StartTripSheet (Sierra/Driver/Views/StartTripSheet.swift)
A bottom sheet shown before navigation begins:
  - Odometer input field (numeric, labeled "Current Odometer Reading (km)")
  - Route options: shows two route cards — "Fastest Route" and "Green Route (Fuel Efficient)"
    Each card shows estimated distance and duration (fetched from Mapbox Directions API — see routing note below)
  - Avoidance toggles: "Avoid Tolls" toggle, "Avoid Highways" toggle
  - Depart By: DatePicker for scheduled departure
  - Add Stop button: allows adding intermediate waypoints (text field + coordinate)
  - "Start Navigation" button: calls AppDataStore.startTrip(tripId:startMileage:) then presents TripNavigationView (Phase 5)

Routing note: To fetch route options from Mapbox, make a URLSession call to:
  https://api.mapbox.com/directions/v5/mapbox/driving/{originLng},{originLat};{destLng},{destLat}
  ?alternatives=true&geometries=polyline6&access_token={MBXAccessToken from Bundle}
Parse the response to get two RouteOption structs: { label: String, distanceKm: Double, durationMinutes: Double, geometry: String }
Store the selected route's geometry string to be passed to TripNavigationView.

## Task 4 — ProofOfDeliveryView (Sierra/Driver/Views/ProofOfDeliveryView.swift)
Shown when driver taps "Complete Delivery":
  - Method picker: Photo / Signature / OTP Verification
  - Photo method: PhotosPicker, uploads to "delivery-proofs/{tripId}.jpg"
  - Signature method: a Canvas drawing view for capturing signature, exports as image
  - OTP method: text field for entering OTP recipient says (validates against delivery_otp_hash)
  - Recipient name text field
  - Delivery notes text field
  - Submit button: calls ProofOfDeliveryService, then transitions to PostTripInspectionView

## Task 5 — PostTripInspectionView (Sierra/Driver/Views/PostTripInspectionView.swift)
Identical structure to PreTripInspectionView but:
  - type is "Post-Trip"
  - Submit updates trips.post_inspection_id
  - On completion calls AppDataStore.completeTrip(tripId:endMileage:)
  - Shows "Trip Completed" confirmation screen

## Design requirements
- Use Sierra's existing color theme (read Sierra/Shared/Theme/)
- All views use NavigationStack or sheet presentation consistent with existing Driver views
- Loading states shown with ProgressView
- Error states shown with alert dialogs
- All async calls wrapped in Task { } with do/catch

## Output
Create all view files and view model files listed above. Commit to main branch.
