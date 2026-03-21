import Foundation
import Supabase

/// ViewModel for the driver fuel-logging form.
/// Uses `FuelLogService.addFuelLog(_:)` with the existing `FuelLog` model.
@Observable
final class FuelLogViewModel {

    // MARK: - Form fields

    var quantity: String = ""
    var costPerLitre: String = ""
    var totalCost: String = ""
    var odometer: String = ""
    var fuelStation: String = ""
    var notes: String = ""

    // MARK: - Receipt upload

    var receiptURL: String? = nil
    var isUploadingReceipt = false

    // MARK: - Submission state

    var isSubmitting = false
    var submitError: String? = nil
    var submitSuccess = false

    // MARK: - Pre-filled context (set by parent)

    let vehicleId: UUID
    let driverId: UUID
    var tripId: UUID?

    init(vehicleId: UUID, driverId: UUID, tripId: UUID? = nil) {
        self.vehicleId = vehicleId
        self.driverId = driverId
        self.tripId = tripId
    }

    // MARK: - Submit

    func submit() async {
        guard let qty = Double(quantity), qty > 0 else {
            submitError = "Please enter a valid fuel quantity."
            return
        }
        guard let cost = Double(totalCost), cost > 0 else {
            submitError = "Please enter a valid total cost."
            return
        }

        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        do {
            let log = FuelLog(
                id: UUID(),
                driverId: driverId,
                vehicleId: vehicleId,
                tripId: tripId,
                fuelQuantityLitres: qty,
                fuelCost: cost,
                pricePerLitre: Double(costPerLitre) ?? (cost / qty),
                odometerAtFill: Double(odometer) ?? 0,
                fuelStation: fuelStation.isEmpty ? nil : fuelStation,
                receiptImageUrl: receiptURL,
                loggedAt: Date(),
                createdAt: Date()
            )
            try await AppDataStore.shared.addFuelLog(log)
            submitSuccess = true
        } catch {
            submitError = error.localizedDescription
        }
    }

    // MARK: - Receipt Upload

    func uploadReceipt(_ imageData: Data) async {
        isUploadingReceipt = true
        defer { isUploadingReceipt = false }
        do {
            let path = "fuel-receipts/\(driverId.uuidString)/\(UUID().uuidString).jpg"
            try await supabase.storage
                .from("fuel-receipts")
                .upload(path, data: imageData, options: .init(contentType: "image/jpeg"))
            let url = try supabase.storage
                .from("fuel-receipts")
                .getPublicURL(path: path)
            receiptURL = url.absoluteString
        } catch {
            submitError = "Receipt upload failed: \(error.localizedDescription)"
        }
    }
}
