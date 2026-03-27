import SwiftUI
import AVFoundation
import Vision

enum InventoryScanKind: String, Equatable {
    case vin
    case barcode
    case qr
    case partNumber
    case unknown
}

struct InventoryScanResult: Equatable {
    let kind: InventoryScanKind
    let rawValue: String
    let normalizedValue: String
}

/// Inventory scanner — supports VIN OCR + barcode/QR + fallback part-id OCR.
struct VINScannerView: View {
    @Binding var scanResult: InventoryScanResult?
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = true
    @State private var highlightedResult: InventoryScanResult?
    private let scannerROI = CGRect(x: 0.12, y: 0.40, width: 0.76, height: 0.20)

    var body: some View {
        ZStack {
            CameraPreviewView(onTextRecognised: handleRecognisedText, regionOfInterest: scannerROI)

            // Viewfinder overlay
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.white, lineWidth: 2)
                    .frame(width: 300, height: 78)
                    .overlay(
                        Text("Align VIN / Barcode / QR within frame")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .offset(y: 48)
                    )
                Spacer()
            }

            if let hit = highlightedResult {
                VStack {
                    Spacer()
                    Text("\(headline(for: hit.kind)): \(hit.normalizedValue)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    Button("Use This Result") {
                        scanResult = hit
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 40)
                }
            }
        }
        .ignoresSafeArea()
        .navigationTitle("Scan VIN")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.white)
            }
        }
    }

    private func handleRecognisedText(_ texts: [String]) {
        guard isScanning else { return }
        for text in texts {
            let candidates = parseCandidates(from: text)
            if let best = candidates.first {
                highlightedResult = best
                isScanning = true
                if best.kind == .vin || best.kind == .barcode || best.kind == .qr {
                    // Stable machine-readable hit; stop further camera churn.
                    isScanning = false
                }
                return
            }
        }
    }

    private func parseCandidates(from text: String) -> [InventoryScanResult] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let payload = decodeMetadataPayload(trimmed) {
            let fromRaw = payload.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if let vin = detectVIN(in: fromRaw) {
                return [InventoryScanResult(kind: .vin, rawValue: fromRaw, normalizedValue: vin)]
            }
            let kind: InventoryScanKind = payload.type.contains("qr") ? .qr : .barcode
            return [InventoryScanResult(kind: kind, rawValue: fromRaw, normalizedValue: normalizeCode(fromRaw))]
        }

        if let vin = detectVIN(in: trimmed.uppercased()) {
            return [InventoryScanResult(kind: .vin, rawValue: trimmed, normalizedValue: vin)]
        }

        // OCR fallback: detect likely part-id-like tokens.
        let rawTokens = trimmed
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" || $0 == "|" })
            .map(String.init)

        let partTokens = rawTokens
            .map { normalizeCode($0) }
            .filter { looksLikePartIdentifier($0) }

        if let first = partTokens.first {
            return [InventoryScanResult(kind: .partNumber, rawValue: trimmed, normalizedValue: first)]
        }

        return [InventoryScanResult(kind: .unknown, rawValue: trimmed, normalizedValue: normalizeCode(trimmed))]
    }

    private func decodeMetadataPayload(_ value: String) -> (type: String, value: String)? {
        guard value.hasPrefix("meta::") else { return nil }
        let comps = value.components(separatedBy: "::")
        guard comps.count >= 3 else { return nil }
        return (comps[1].lowercased(), comps.dropFirst(2).joined(separator: "::"))
    }

    private func detectVIN(in value: String) -> String? {
        let vinPattern = /[A-HJ-NPR-Z0-9]{17}/
        guard let match = value.uppercased().firstMatch(of: vinPattern) else { return nil }
        return String(match.output)
    }

    private func normalizeCode(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func looksLikePartIdentifier(_ token: String) -> Bool {
        let cleaned = token.replacingOccurrences(of: " ", with: "")
        guard cleaned.count >= 4, cleaned.count <= 40 else { return false }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_/.:")
        guard cleaned.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        return cleaned.contains(where: { $0.isNumber })
    }

    private func headline(for kind: InventoryScanKind) -> String {
        switch kind {
        case .vin: return "VIN"
        case .barcode: return "Barcode"
        case .qr: return "QR"
        case .partNumber: return "Part ID"
        case .unknown: return "Detected"
        }
    }
}
