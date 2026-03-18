# Sprint 2 — Phase 1: Security Fix + Missing Driver Features

> **Deadline context:** 22 March 2026  
> **Backend status:** All DB triggers live, RLS locked down, anon grant revoked, geofencing wired.  
> **This phase covers:** ProofOfDeliveryService OTP bug, FuelLog UI, DriverMaintenanceRequestView

---

## Completed Before This Phase

- ✅ `startLocationTracking()` added to `TripNavigationContainerView` — geofencing live
- ✅ DB triggers on `trips` and `maintenance_tasks` in Supabase
- ✅ Role-scoped RLS on all 24 tables
- ✅ `anon` execute revoked from `check_resource_overlap`

---

## Task 1 — Fix ProofOfDeliveryService OTP Hash

### Problem

`ProofOfDeliveryView` correctly calls `CryptoService.sha256(rawOTP)` before submission. However, the `ProofOfDeliveryService` payload that gets written to Supabase does **not include the OTP hash fields**. This means the hash is computed client-side but never persisted — the verification round-trip is broken.

### File to modify

`Sierra/Shared/Services/ProofOfDeliveryService.swift`

### What to do

1. Open `ProofOfDeliveryService.swift` and find the method that creates a row in `proof_of_deliveries`.
2. Add the OTP hash parameter to the method signature:
   ```swift
   func submitProofOfDelivery(
       tripId: String,
       driverId: String,
       method: ProofOfDeliveryMethod,
       photoUrls: [String],
       signatureUrl: String?,
       otpHash: String?        // ← ADD THIS
   ) async throws
   ```
3. Include `otp_hash` in the Supabase insert payload:
   ```swift
   let payload: [String: AnyJSON] = [
       "trip_id": .string(tripId),
       "driver_id": .string(driverId),
       "method": .string(method.rawValue),
       "photo_urls": .array(photoUrls.map { .string($0) }),
       "signature_url": signatureUrl.map { .string($0) } ?? .null,
       "otp_hash": otpHash.map { .string($0) } ?? .null   // ← ADD THIS
   ]
   ```
4. In `ProofOfDeliveryView.swift` (or wherever the call site is), pass the hash:
   ```swift
   let hash = CryptoService.sha256(rawOTP)   // already computed
   try await ProofOfDeliveryService.submitProofOfDelivery(
       ...,
       otpHash: hash   // ← pass it through
   )
   ```
5. **Never store the raw OTP string anywhere.** The raw OTP is only used for the hash computation, then discarded.

### Verify

- Submit a POD with OTP method → check Supabase `proof_of_deliveries` table → `otp_hash` column must be non-null and contain a SHA-256 hex string (64 chars), not the raw digits.

### Jira stories
FMS1-44

---

## Task 2 — Build FuelLogViewModel + FuelLogView

### Context

`FuelLogService.swift` already exists with full CRUD. No UI exists. Drivers currently have no way to log fuel.

### Files to create

- `Sierra/Driver/ViewModels/FuelLogViewModel.swift` ← CREATE
- `Sierra/Driver/Views/FuelLogView.swift` ← CREATE

### File to modify

- `Sierra/Driver/Views/DriverTabView.swift` — add Fuel Log entry point

---

### FuelLogViewModel.swift

Create as `@Observable` class:

```swift
@Observable
final class FuelLogViewModel {
    var quantity: String = ""
    var costPerLitre: String = ""
    var totalCost: String = ""
    var fuelType: FuelType = .petrol          // use your FuelType enum
    var odometer: String = ""
    var receiptURL: String? = nil
    var notes: String = ""

    var isSubmitting = false
    var submitError: String? = nil
    var submitSuccess = false

    // Populated from AppDataStore / current trip context
    var vehicleId: String = ""
    var driverId: String = ""
    var tripId: String? = nil

    private let service = FuelLogService()

    func submit() async {
        guard !quantity.isEmpty, !totalCost.isEmpty else {
            submitError = "Quantity and total cost are required."
            return
        }
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }
        do {
            try await service.createFuelLog(
                vehicleId: vehicleId,
                driverId: driverId,
                tripId: tripId,
                fuelType: fuelType,
                quantityLitres: Double(quantity) ?? 0,
                costPerLitre: Double(costPerLitre),
                totalCost: Double(totalCost) ?? 0,
                odometerReading: Double(odometer),
                receiptUrl: receiptURL,
                notes: notes.isEmpty ? nil : notes
            )
            submitSuccess = true
        } catch {
            submitError = error.localizedDescription
        }
    }

    func uploadReceipt(_ imageData: Data) async {
        // Upload to Supabase Storage bucket "receipts"
        // Set receiptURL on success
        // Use SupabaseManager.shared.client.storage approach matching other upload patterns in the codebase
    }
}
```

### FuelLogView.swift

Build a SwiftUI form sheet:

```
NavigationStack {
    Form {
        Section("Fuel Details") {
            Picker("Fuel Type", ...) — bind to vm.fuelType
            TextField("Quantity (L)", ...) — numeric, bind to vm.quantity
            TextField("Cost per Litre", ...) — numeric, optional
            TextField("Total Cost (₹)", ...) — numeric, bind to vm.totalCost
        }
        Section("Odometer") {
            TextField("Current Reading (km)", ...) — numeric, bind to vm.odometer
        }
        Section("Receipt") {
            — PhotosPicker or camera capture, calls vm.uploadReceipt(_:) on selection
            — Show receipt thumbnail if vm.receiptURL is non-nil
        }
        Section("Notes") {
            TextField("Optional notes", ...) — bind to vm.notes
        }
    }
    .navigationTitle("Log Fuel")
    .toolbar {
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { Task { await vm.submit() } }
                .disabled(vm.isSubmitting)
        }
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
    }
    .alert("Error", isPresented: .constant(vm.submitError != nil)) { ... }
    .onChange(of: vm.submitSuccess) { if vm.submitSuccess { dismiss() } }
}
```

Inject `vehicleId`, `driverId`, `tripId` from the parent (trip context or driver profile).

### Wire into DriverTabView

Add a sheet trigger — either as a tab item or a toolbar button on the active trip screen. Pattern:

```swift
.sheet(isPresented: $showFuelLog) {
    FuelLogView(vehicleId: currentVehicleId, driverId: currentDriverId, tripId: activeTripId)
}
```

### Verify

- Open app as Driver → navigate to Fuel Log → fill form → submit → check Supabase `fuel_logs` table for new row with correct `driver_id`, `vehicle_id`, `quantity_litres`, `total_cost`.
- Test with receipt image: verify `receipt_url` is non-null and points to storage.

### Jira stories
FMS1-48 (fuel logging)

---

## Task 3 — Build DriverMaintenanceRequestView

### Context

When a driver finds an issue during pre-trip or post-trip inspection, the current inspection flow creates a maintenance task but there is no standalone view for a driver to raise an ad-hoc maintenance request. `MaintenanceTaskService.swift` already has the create method. This view is also the end state of the post-trip inspection failure path.

### Files to create

- `Sierra/Driver/Views/DriverMaintenanceRequestView.swift` ← CREATE
- `Sierra/Driver/ViewModels/DriverMaintenanceRequestViewModel.swift` ← CREATE

---

### DriverMaintenanceRequestViewModel.swift

```swift
@Observable
final class DriverMaintenanceRequestViewModel {
    // Pre-filled from context
    var vehicleId: String
    var driverId: String
    var tripId: String?
    var sourceInspectionId: String?      // set if raised from inspection

    // Form fields
    var title: String = ""
    var description: String = ""
    var priority: TaskPriority = .medium  // Low / Medium / High / Critical
    var photos: [Data] = []
    var photoURLs: [String] = []

    var isSubmitting = false
    var submitError: String? = nil
    var submitSuccess = false

    init(vehicleId: String, driverId: String, tripId: String? = nil, sourceInspectionId: String? = nil) {
        self.vehicleId = vehicleId
        self.driverId = driverId
        self.tripId = tripId
        self.sourceInspectionId = sourceInspectionId
    }

    func submit() async {
        guard !title.isEmpty, !description.isEmpty else {
            submitError = "Title and description are required."
            return
        }
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }
        do {
            // Upload photos SEQUENTIALLY — never async let / TaskGroup
            for photo in photos {
                let url = try await uploadPhoto(photo)
                photoURLs.append(url)
            }
            try await MaintenanceTaskService().createDriverRequest(
                vehicleId: vehicleId,
                driverId: driverId,
                title: title,
                description: description,
                priority: priority,
                photoURLs: photoURLs,
                sourceInspectionId: sourceInspectionId
            )
            submitSuccess = true
        } catch {
            submitError = error.localizedDescription
        }
    }

    private func uploadPhoto(_ data: Data) async throws -> String {
        // Upload to Supabase Storage bucket "maintenance-photos"
        // Return public URL
        // Follow same pattern as PreTripInspectionViewModel.uploadPhotos()
    }
}
```

**CRITICAL:** Photos must be uploaded one at a time in a `for` loop. Do **not** use `async let` or `withTaskGroup` for uploads — this causes race conditions on the storage bucket.

### DriverMaintenanceRequestView.swift

```
NavigationStack {
    Form {
        Section("Issue Details") {
            TextField("Title (e.g. Brake noise)", text: $vm.title)
            TextField("Description", text: $vm.description, axis: .vertical)
                .lineLimit(3...6)
        }
        Section("Severity") {
            Picker("Priority", selection: $vm.priority) {
                ForEach(TaskPriority.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        Section("Photos") {
            — PhotosPicker supporting multiple selection
            — Show thumbnails of selected photos
            — On selection: append raw Data to vm.photos
        }
    }
    .navigationTitle("Report Issue")
    .toolbar {
        ToolbarItem(placement: .confirmationAction) {
            Button("Submit") { Task { await vm.submit() } }
                .disabled(vm.isSubmitting || vm.title.isEmpty)
        }
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
    }
    .alert("Error", ...) — show vm.submitError
    .onChange(of: vm.submitSuccess) { if vm.submitSuccess { dismiss() } }
}
```

### Wire into post-trip inspection

In `PostTripInspectionView` (or wherever the inspection-fail path ends), present this sheet:

```swift
.sheet(isPresented: $showMaintenanceRequest) {
    DriverMaintenanceRequestView(
        vehicleId: inspectionResult.vehicleId,
        driverId: currentDriverId,
        tripId: currentTripId,
        sourceInspectionId: inspection.id
    )
}
```

### Wire into MaintenanceTaskService

If `MaintenanceTaskService` does not already have a `createDriverRequest(...)` method, add one:

```swift
func createDriverRequest(
    vehicleId: String,
    driverId: String,
    title: String,
    description: String,
    priority: TaskPriority,
    photoURLs: [String],
    sourceInspectionId: String?
) async throws {
    // Insert into maintenance_tasks with:
    // status = "Pending"
    // created_by_admin_id = nil (driver-raised request)
    // source_inspection_id = sourceInspectionId
    // Task type = "Repair" or appropriate enum value
}
```

### Verify

- Open app as Driver → navigate to Post-Trip Inspection → mark an issue → submit maintenance request → check Supabase `maintenance_tasks` for new row with `status = Pending`, `vehicle_id` correct, `source_inspection_id` populated.
- Fleet Manager dashboard should reflect the new pending maintenance task.

### Jira stories
FMS1-47, FMS1-36

---

## Phase 1 Completion Checklist

- [ ] `proof_of_deliveries.otp_hash` is non-null when OTP method is used
- [ ] Driver can log fuel from the app, row appears in `fuel_logs`
- [ ] Driver can submit a maintenance request, row appears in `maintenance_tasks` with `status = Pending`
- [ ] No `async let` / `TaskGroup` used for photo uploads anywhere in this phase
- [ ] No raw OTP string stored anywhere — only SHA-256 hash
