import SwiftUI
import PhotosUI
import CryptoKit
import Supabase

/// Proof of delivery capture: Photo, Signature, or OTP verification.
struct ProofOfDeliveryView: View {

    let tripId: UUID
    let driverId: UUID
    var onComplete: () -> Void

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var method: ProofOfDeliveryMethod = .photo
    @State private var recipientName = ""
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showError = false

    // Photo
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var uploadedPhotoUrl: String?

    // Signature
    @State private var signatureLines: [[CGPoint]] = []
    @State private var currentLine: [CGPoint] = []
    @State private var signatureCanvasSize = CGSize(width: 1, height: 180)

    // OTP — Safeguard 5: hash only, never plaintext stored
    @State private var generatedOTP: String?
    @State private var otpHash: String?
    @State private var otpSalt: String?
    @State private var otpEnteredByRecipient = ""
    @State private var otpVerified = false
    @State private var otpShowMismatch = false
    @State private var generatedOTPTime: Date?   // BUG-08 FIX: track generation time
    @State private var otpExpired = false         // BUG-08 FIX: expired flag

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Method Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Delivery Verification Method")
                        .font(.subheadline.weight(.medium))
                    Picker("Method", selection: $method) {
                        Text("Photo").tag(ProofOfDeliveryMethod.photo)
                        Text("Signature").tag(ProofOfDeliveryMethod.signature)
                        Text("OTP").tag(ProofOfDeliveryMethod.otpVerification)
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                // Method-specific content
                switch method {
                case .photo:       photoSection
                case .signature:   signatureSection
                case .otpVerification: otpSection
                }

                Divider()

                // Common fields
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipient Name")
                        .font(.subheadline.weight(.medium))
                    TextField("Enter recipient name", text: $recipientName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Delivery Notes")
                        .font(.subheadline.weight(.medium))
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }

                Spacer(minLength: 20)

                // Submit — Safeguard 7: Task { } not .task { }
                Button {
                    Task { await submitProof() }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("Submit Proof of Delivery")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canSubmit ? SierraTheme.Colors.ember : Color.gray,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canSubmit || isSubmitting)
            }
            .padding(16)
        }
        .navigationTitle("Proof of Delivery")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
    }

    // ISSUE-30 FIX: Show camera trigger and photo gallery picker
    @State private var showCamera = false
    @State private var cameraImage: UIImage?

    private var photoSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Camera button
                Button {
                    showCamera = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(SierraTheme.Colors.ember.opacity(0.6))
                        Text("Camera")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(SierraTheme.Colors.ember)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .fullScreenCover(isPresented: $showCamera) {
                    CameraCapture(image: $cameraImage)
                        .ignoresSafeArea()
                }
                .onChange(of: cameraImage) { _, newImage in
                    if let img = newImage, let data = img.jpegData(compressionQuality: 0.8) {
                        photoData = data
                    }
                }

                // Gallery picker
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 28))
                            .foregroundStyle(SierraTheme.Colors.ember.opacity(0.6))
                        Text("Gallery")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(SierraTheme.Colors.ember)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            photoData = data
                        }
                    }
                }
            }

            if photoData != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SierraTheme.Colors.alpineMint)
                    Text("Photo captured ✓")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(SierraTheme.Colors.alpineMint)
                }
            }
        }
    }

    // MARK: - Signature Section

    private var signatureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Draw Signature Below")
                .font(.subheadline.weight(.medium))

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))

                Canvas { context, _ in
                    for line in signatureLines {
                        var path = Path()
                        guard let first = line.first else { continue }
                        path.move(to: first)
                        for point in line.dropFirst() { path.addLine(to: point) }
                        context.stroke(path, with: .color(.primary), lineWidth: 2)
                    }
                    if !currentLine.isEmpty {
                        var path = Path()
                        path.move(to: currentLine[0])
                        for point in currentLine.dropFirst() { path.addLine(to: point) }
                        context.stroke(path, with: .color(.primary), lineWidth: 2)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in currentLine.append(value.location) }
                        .onEnded { _ in
                            signatureLines.append(currentLine)
                            currentLine = []
                        }
                )
            }
            .frame(height: 180)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { signatureCanvasSize = proxy.size }
                        .onChange(of: proxy.size) { _, newSize in
                            signatureCanvasSize = newSize
                        }
                }
            }

            Button("Clear Signature") {
                signatureLines = []
                currentLine = []
            }
            .font(.caption)
            .foregroundStyle(SierraTheme.Colors.danger)
        }
    }

    // MARK: - OTP Section — Safeguard 5

    private var otpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if generatedOTP == nil {
                Button {
                    generateOTP()
                } label: {
                    HStack {
                        Image(systemName: "number.circle.fill")
                        Text("Generate OTP")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(SierraTheme.Colors.info, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            } else {
                VStack(spacing: 8) {
                    Text("Read this OTP to the recipient:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(generatedOTP ?? "")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(SierraTheme.Colors.ember)
                        .kerning(8)

                    Text("Valid for 10 minutes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(SierraTheme.Colors.ember.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                Divider()

                Text("Enter the OTP the recipient confirms:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Enter OTP", text: $otpEnteredByRecipient)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.title3, design: .monospaced))

                Button {
                    verifyOTP()
                } label: {
                    Text(otpVerified ? "Verified ✓" : "Verify OTP")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(otpVerified ? SierraTheme.Colors.alpineMint : SierraTheme.Colors.info)
                }
                .disabled(otpVerified)

                if otpShowMismatch {
                    Text("OTP does not match. Please try again.")
                        .font(.caption)
                        .foregroundStyle(SierraTheme.Colors.danger)
                }
            }
        }
    }

    // MARK: - OTP Logic — Safeguard 5: hash only stored

    private func generateOTP() {
        let otp = String(format: "%06d", Int.random(in: 0...999999))
        generatedOTP = otp
        generatedOTPTime = Date() // BUG-08 FIX
        otpExpired = false

        // Hash OTP via CryptoService — never store plaintext
        let credential = CryptoService.hash(password: otp)
        otpHash = credential.hash
        otpSalt = credential.salt

        // BUG-08 FIX: Auto-expire after 10 minutes
        Task {
            try? await Task.sleep(for: .seconds(600))
            if !otpVerified {
                otpExpired = true
                generatedOTP = nil
            }
        }
    }

    private func verifyOTP() {
        guard let hash = otpHash, let salt = otpSalt else { return }

        // BUG-08 FIX: Enforce 10-minute expiry
        if let genTime = generatedOTPTime, Date().timeIntervalSince(genTime) > 600 {
            otpExpired = true
            otpShowMismatch = false
            generatedOTP = nil
            return
        }

        let credential = CryptoService.HashedCredential(hash: hash, salt: salt)
        if CryptoService.verify(password: otpEnteredByRecipient, credential: credential) {
            otpVerified = true
            otpShowMismatch = false
        } else {
            otpShowMismatch = true
        }
    }

    // MARK: - Validation

    private var canSubmit: Bool {
        if recipientName.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        switch method {
        case .photo: return photoData != nil
        case .signature: return !signatureLines.isEmpty
        case .otpVerification: return otpVerified
        }
    }

    // MARK: - Submit

    private func submitProof() async {
        isSubmitting = true

        do {
            var photoUrl: String?
            var signatureUrl: String?

            // Upload photo if needed
            if method == .photo, let data = photoData {
                let path = "delivery-proofs/\(tripId.uuidString)/\(UUID().uuidString).jpg"
                try await supabase.storage
                    .from("delivery-proofs")
                    .upload(path, data: data, options: .init(contentType: "image/jpeg"))
                let url = try supabase.storage
                    .from("delivery-proofs")
                    .getPublicURL(path: path)
                photoUrl = url.absoluteString
            }

            // BUG-02 FIX: Rasterize signature canvas to UIImage, upload, store real URL
            if method == .signature {
                let canvasWidth = max(signatureCanvasSize.width, 1)
                let canvasHeight = max(signatureCanvasSize.height, 1)
                let widthScale = 600.0 / canvasWidth
                let heightScale = 300.0 / canvasHeight
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 300))
                let signatureImage = renderer.image { ctx in
                    ctx.cgContext.setFillColor(UIColor.white.cgColor)
                    ctx.cgContext.fill(CGRect(origin: .zero, size: CGSize(width: 600, height: 300)))
                    ctx.cgContext.setStrokeColor(UIColor.black.cgColor)
                    ctx.cgContext.setLineWidth(2)
                    ctx.cgContext.setLineCap(.round)
                    // Scale points from canvas size to render size
                    for line in signatureLines {
                        guard let first = line.first else { continue }
                        ctx.cgContext.move(to: CGPoint(x: first.x * widthScale, y: first.y * heightScale))
                        for point in line.dropFirst() {
                            ctx.cgContext.addLine(to: CGPoint(x: point.x * widthScale, y: point.y * heightScale))
                        }
                        ctx.cgContext.strokePath()
                    }
                }
                if let jpegData = signatureImage.jpegData(compressionQuality: 0.8) {
                    let path = "delivery-proofs/\(tripId.uuidString)/signature-\(UUID().uuidString).jpg"
                    try await supabase.storage
                        .from("delivery-proofs")
                        .upload(path, data: jpegData, options: .init(contentType: "image/jpeg"))
                    let url = try supabase.storage
                        .from("delivery-proofs")
                        .getPublicURL(path: path)
                    signatureUrl = url.absoluteString
                }
            }

            let pod = ProofOfDelivery(
                id: UUID(),
                tripId: tripId,
                driverId: driverId,
                method: method,
                photoUrl: photoUrl,
                signatureUrl: signatureUrl,
                otpVerified: method == .otpVerification ? otpVerified : false,
                recipientName: recipientName,
                deliveryLatitude: nil,
                deliveryLongitude: nil,
                deliveryOtpHash: method == .otpVerification ? otpHash : nil,
                deliveryOtpExpiresAt: method == .otpVerification
                    ? Calendar.current.date(byAdding: .minute, value: 10, to: Date())
                    : nil,
                notes: notes.isEmpty ? nil : notes,
                capturedAt: Date(),
                createdAt: Date()
            )

            try await store.addProofOfDelivery(pod)
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isSubmitting = false
    }
}
