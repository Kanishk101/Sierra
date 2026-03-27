import SwiftUI
import AVFoundation
import Vision

/// Wraps a UIKit camera view controller that performs real-time text recognition
/// via the Vision framework. Detected text strings are returned via the callback.
/// Phase 14: Used by VINScannerView for VIN OCR.
struct CameraPreviewView: UIViewControllerRepresentable {
    let onTextRecognised: ([String]) -> Void
    var regionOfInterest: CGRect? = nil

    func makeUIViewController(context: Context) -> CameraPreviewViewController {
        CameraPreviewViewController(
            onTextRecognised: onTextRecognised,
            regionOfInterest: regionOfInterest
        )
    }

    func updateUIViewController(_ uiViewController: CameraPreviewViewController, context: Context) {}
}

// MARK: - CameraPreviewViewController

final class CameraPreviewViewController: UIViewController,
                                         AVCaptureVideoDataOutputSampleBufferDelegate,
                                         AVCaptureMetadataOutputObjectsDelegate {

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let processingQueue = DispatchQueue(label: "com.sierra.vin-ocr", qos: .userInitiated)
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let onTextRecognised: ([String]) -> Void
    private let regionOfInterest: CGRect?

    /// Throttle: at most one recognition per second to conserve battery.
    private var lastProcessTime = Date.distantPast
    private let throttleInterval: TimeInterval = 1.0
    private var lastEmittedToken: String = ""
    private var lastEmitTime = Date.distantPast

    init(onTextRecognised: @escaping ([String]) -> Void, regionOfInterest: CGRect? = nil) {
        self.onTextRecognised = onTextRecognised
        self.regionOfInterest = regionOfInterest
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCaptureSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !captureSession.isRunning {
            processingQueue.async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Tear down capture session to release camera
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    // MARK: - Camera Setup

    private func configureCaptureSession() {
        captureSession.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input) else {
            print("[CameraPreview] Camera unavailable")
            return
        }
        captureSession.addInput(input)

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: processingQueue)
            let supported = Set(metadataOutput.availableMetadataObjectTypes)
            let requested: [AVMetadataObject.ObjectType] = [
                .qr, .ean8, .ean13, .upce, .code39, .code39Mod43, .code93, .code128, .pdf417, .aztec, .dataMatrix
            ]
            metadataOutput.metadataObjectTypes = requested.filter { supported.contains($0) }
        }

        // Preview layer
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) >= throttleInterval else { return }
        lastProcessTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self, error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else { return }

            var recognised: [String] = []
            for obs in observations {
                if let candidate = obs.topCandidates(1).first {
                    recognised.append(candidate.string)
                }
            }

            if !recognised.isEmpty {
                DispatchQueue.main.async {
                    self.onTextRecognised(recognised)
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false // VINs are codes, not prose
        if let roi = regionOfInterest {
            request.regionOfInterest = roi
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([request])
    }

    // MARK: - Metadata (Barcodes / QR)

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        for object in metadataObjects {
            guard let readable = object as? AVMetadataMachineReadableCodeObject,
                  let raw = readable.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { continue }
            let payload = "meta::\(readable.type.rawValue)::\(raw)"
            emitToken(payload)
        }
    }

    private func emitToken(_ token: String) {
        let now = Date()
        if token == lastEmittedToken, now.timeIntervalSince(lastEmitTime) < 1.2 { return }
        lastEmittedToken = token
        lastEmitTime = now
        DispatchQueue.main.async { [onTextRecognised] in
            onTextRecognised([token])
        }
    }
}
