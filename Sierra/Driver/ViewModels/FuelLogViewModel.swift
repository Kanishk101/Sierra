import Foundation
import Supabase
import Vision
import UIKit

/// ViewModel for the driver fuel-logging form.
/// Uses `FuelLogService.addFuelLog(_:)` with the existing `FuelLog` model.
/// Phase 11: Added validation (recalculateTotalCost, hasTotalCostMismatch, canSubmit)
/// and Vision OCR receipt scanning.
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

    // MARK: - OCR state

    var ocrAutoFilled = false

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

    // MARK: - Validation (Phase 11)

    func recalculateTotalCost() {
        guard let q = Double(quantity), let c = Double(costPerLitre) else { return }
        let calculated = q * c
        // Auto-fill if total is empty
        if totalCost.isEmpty {
            totalCost = String(format: "%.2f", calculated)
        }
    }

    var hasTotalCostMismatch: Bool {
        // ISSUE-17 FIX: Only compare when all three fields are filled
        guard let q = Double(quantity),
              let c = Double(costPerLitre),
              let t = Double(totalCost),
              q > 0, c > 0 else { return false }
        return abs(q * c - t) > 1.0 // Allow ₹1 rounding tolerance
    }

    var canSubmit: Bool {
        guard let q = Double(quantity), q > 0,
              let t = Double(totalCost), t > 0 else { return false }
        // ISSUE-17 FIX: costPerLitre must be filled OR auto-calculable
        let hasRate = Double(costPerLitre) != nil && !costPerLitre.isEmpty
        return (hasRate || !quantity.isEmpty) && !hasTotalCostMismatch
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
                notes: notes.isEmpty ? nil : notes,  // M-01 FIX: persist notes
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
            let path = "\(driverId.uuidString)/\(UUID().uuidString).jpg"
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

    // MARK: - Vision OCR (Phase 11)
    // Runs Vision text recognition on a receipt image,
    // extracts fuel data (litres, total, rate), and uploads the image.

    @MainActor
    func processReceiptWithOCR(_ image: UIImage) async {
        submitError = nil
        ocrAutoFilled = false
        isUploadingReceipt = true
        defer { isUploadingReceipt = false }

        guard let cgImage = image.cgImage else { return }

        // Run OCR on background thread
        let lines = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["en-IN", "en-US"]
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage)
                try? handler.perform([request])

                let results = request.results ?? []
                let texts = results.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: texts)
            }
        }

        // Extract fuel data from OCR text
        extractFuelData(from: lines)

        // Upload the receipt image
        if let data = image.jpegData(compressionQuality: 0.7) {
            await uploadReceipt(data)
        }
    }

    private func extractFuelData(from lines: [String]) {
        // Pattern match for litres: "XX.X L" or "XX.X litres"
        let litresPattern = /(\d+\.?\d*)\s*[Ll](?:itres?)?/
        // Pattern match for total: "₹ XXXX" or "Rs. XXXX"
        let amountPattern = /(?:₹|Rs\.?\s*)(\d+\.?\d*)/
        // Pattern match for per-litre price: "₹XX/L" or "Rate: XX"
        let ratePattern = /(?:Rate|Per\s*[Ll]itre?)[:\s]*(\d+\.?\d*)/

        var extractedQuantity: String?
        var extractedTotalCost: String?
        var extractedRate: String?

        for line in lines {
            if extractedQuantity == nil, let match = line.firstMatch(of: litresPattern) {
                extractedQuantity = String(match.1)
            }
            if extractedTotalCost == nil, let match = line.firstMatch(of: amountPattern) {
                extractedTotalCost = String(match.1)
            }
            if extractedRate == nil, let match = line.firstMatch(of: ratePattern) {
                extractedRate = String(match.1)
            }
        }

        if let extractedQuantity {
            quantity = extractedQuantity
        }
        if let extractedTotalCost {
            totalCost = extractedTotalCost
        }
        if let extractedRate {
            costPerLitre = extractedRate
        }

        if extractedQuantity != nil || extractedTotalCost != nil || extractedRate != nil {
            ocrAutoFilled = true
        }
        recalculateTotalCost()
    }
}
