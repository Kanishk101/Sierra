import SwiftUI
import AVFoundation
import Vision

/// VIN Scanner — uses live camera with Vision OCR to detect 17-character VINs.
/// Phase 14: SRS §4.3.3 compliance.
struct VINScannerView: View {
    @Binding var scannedVIN: String
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = true
    @State private var highlightedText: String?

    var body: some View {
        ZStack {
            CameraPreviewView(onTextRecognised: handleRecognisedText)

            // Viewfinder overlay
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.white, lineWidth: 2)
                    .frame(width: 300, height: 60)
                    .overlay(
                        Text("Align VIN barcode within frame")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .offset(y: 40)
                    )
                Spacer()
            }

            if let vin = highlightedText {
                VStack {
                    Spacer()
                    Text("VIN: \(vin)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    Button("Use This VIN") {
                        scannedVIN = vin
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
        // VIN: 17 alphanumeric chars, no I, O, Q per ISO 3779
        let vinPattern = /[A-HJ-NPR-Z0-9]{17}/
        for text in texts {
            if let match = text.uppercased().firstMatch(of: vinPattern) {
                highlightedText = String(match.output)
                isScanning = false
                break
            }
        }
    }
}
