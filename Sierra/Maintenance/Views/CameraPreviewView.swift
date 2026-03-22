import SwiftUI
import AVFoundation
import Vision

/// Wraps a UIKit camera view controller that performs real-time text recognition
/// via the Vision framework. Detected text strings are returned via the callback.
/// Phase 14: Used by VINScannerView for VIN OCR.
struct CameraPreviewView: UIViewControllerRepresentable {
    let onTextRecognised: ([String]) -> Void

    func makeUIViewController(context: Context) -> CameraPreviewViewController {
        CameraPreviewViewController(onTextRecognised: onTextRecognised)
    }

    func updateUIViewController(_ uiViewController: CameraPreviewViewController, context: Context) {}
}

// MARK: - CameraPreviewViewController

final class CameraPreviewViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.sierra.vin-ocr", qos: .userInitiated)
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let onTextRecognised: ([String]) -> Void

    /// Throttle: at most one recognition per second to conserve battery.
    private var lastProcessTime = Date.distantPast
    private let throttleInterval: TimeInterval = 1.0

    init(onTextRecognised: @escaping ([String]) -> Void) {
        self.onTextRecognised = onTextRecognised
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

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([request])
    }
}
