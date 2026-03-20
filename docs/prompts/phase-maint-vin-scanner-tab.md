# Phase: Maintenance VIN Scanner Tab

## Context
Sierra FMS — iOS 17+, SwiftUI, MVVM, @Observable, no @Published.
GitHub: Kanishk101/Sierra  |  Branch: main

## Problem
In `MaintenanceDashboardView.swift` the VIN Scanner tab (tab index 2) currently shows
a `comingSoonTab` placeholder.

The schema already stores `vin_scanned: Bool` on `work_orders` and `vin: String` on
`vehicles`. `WorkOrderService.updateWorkOrder` can persist the scan result.

## Scope
Replace the VIN Scanner `comingSoonTab` in `MaintenanceDashboardView.swift` with a
functional scanner tab.

### Behaviour
1. Show a camera viewport using `AVCaptureSession` with `AVMetadataObjectTypeCode39Code`
   and `AVMetadataObjectTypeEAN13Code` barcode formats (VINs are often Code 39).
2. On scan:
   a. Match the scanned string against `store.vehicles.first { $0.vin == scannedVIN }`.
   b. If matched: show vehicle card (name, plate, status) + list of open work orders
      for that vehicle (`store.workOrders.filter { $0.vehicleId == vehicle.id && $0.status != .closed }`).
   c. Mark each matched work order's `vinScanned = true` via
      `WorkOrderService.setVinScanned(workOrderId:)` — add this static func to
      `WorkOrderService.swift` if not present:
      ```swift
      static func setVinScanned(workOrderId: UUID) async throws {
          struct P: Encodable { let vin_scanned: Bool }
          try await supabase.from("work_orders")
              .update(P(vin_scanned: true)).eq("id", value: workOrderId.uuidString).execute()
      }
      ```
   d. If not matched: show "Vehicle not found" with the raw scanned string.
3. Scan button / tap-to-rescan to reset the scanner.

## Constraints
- Only modify `MaintenanceDashboardView.swift` and `WorkOrderService.swift`.
- Do NOT change appearance outside the scanner tab.
- Add NSCameraUsageDescription to Info.plist if not already present.
- Use `@Observable` pattern, no @Published.
