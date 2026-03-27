import SwiftUI
import PhotosUI
import CryptoKit
import Supabase
import UserNotifications

/// Proof of delivery capture — FMS_SS themed.
/// Three tabs: Photo, Signature, OTP — each with the orange-accent card design.
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

    // OTP — hash only, never plaintext stored
    @State private var generatedOTP: String?
    @State private var otpHash: String?
    @State private var otpSalt: String?
    @State private var otpEnteredByRecipient = ""
    @State private var otpVerified = false
    @State private var otpShowMismatch = false
    @State private var generatedOTPTime: Date?
    @State private var otpExpired = false
    @State private var otpSentNotification = false
    @State private var otpNotificationFailed = false

    // Camera
    @State private var showCamera = false
    @State private var cameraImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appSurface.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Title section
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(SierraFont.scaled(40))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.appAmber, Color.appOrange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text("Delivery Verification")
                                .font(SierraFont.scaled(22, weight: .bold, design: .rounded))
                                .foregroundColor(.appTextPrimary)

                            Text("Choose a method to verify delivery")
                                .font(SierraFont.scaled(14, weight: .medium, design: .rounded))
                                .foregroundColor(.appTextSecondary)
                        }
                        .padding(.top, 4)

                        // Method tabs — FMS_SS style capsule tabs
                        methodTabs

                        // Method card
                        methodCard
                            .padding(.horizontal, 4)

                        // Common fields card
                        commonFieldsCard
                            .padding(.horizontal, 4)

                        // Submit button
                        submitButton
                            .padding(.horizontal, 4)

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Proof of Delivery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(SierraFont.scaled(24))
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Something went wrong")
            }
        }
    }

    // MARK: - Method Tabs

    private var methodTabs: some View {
        HStack(spacing: 0) {
            methodTab(icon: "camera.fill", title: "Photo", method: .photo)
            methodTab(icon: "signature", title: "Signature", method: .signature)
            methodTab(icon: "number.circle.fill", title: "OTP", method: .otpVerification)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appCardBg)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appDivider.opacity(0.5), lineWidth: 1)
        )
    }

    private func methodTab(icon: String, title: String, method: ProofOfDeliveryMethod) -> some View {
        let isSelected = self.method == method
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.method = method
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(SierraFont.scaled(16, weight: .semibold))
                Text(title)
                    .font(SierraFont.scaled(12, weight: .bold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : .appTextSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.appOrange : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Method Card

    private var methodCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch method {
            case .photo:       photoSection
            case .signature:   signatureSection
            case .otpVerification: otpSection
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appCardBg)
                .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.appDivider.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                // Camera button
                Button {
                    showCamera = true
                } label: {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.appOrange.opacity(0.12))
                                .frame(width: 52, height: 52)
                            Image(systemName: "camera.fill")
                                .font(SierraFont.scaled(22, weight: .semibold))
                                .foregroundColor(.appOrange)
                        }
                        Text("Camera")
                            .font(SierraFont.scaled(13, weight: .bold, design: .rounded))
                            .foregroundColor(.appTextPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.appDivider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
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
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.appOrange.opacity(0.12))
                                .frame(width: 52, height: 52)
                            Image(systemName: "photo.on.rectangle")
                                .font(SierraFont.scaled(22, weight: .semibold))
                                .foregroundColor(.appOrange)
                        }
                        Text("Gallery")
                            .font(SierraFont.scaled(13, weight: .bold, design: .rounded))
                            .foregroundColor(.appTextPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.appDivider, lineWidth: 1)
                    )
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            photoData = data
                        }
                    }
                }
            }

            // Photo preview
            if let data = photoData, let uiImage = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button {
                        photoData = nil
                        selectedPhoto = nil
                        cameraImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(SierraFont.scaled(24))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding(8)
                }

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(SierraFont.scaled(14, weight: .bold))
                        .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
                    Text("Photo captured")
                        .font(SierraFont.scaled(14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.12))
                )
            }
        }
    }

    // MARK: - Signature Section

    private var signatureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "signature")
                    .font(SierraFont.scaled(14, weight: .bold))
                    .foregroundColor(.appOrange)
                Text("Draw Signature Below")
                    .font(SierraFont.scaled(15, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                Spacer()
                if !signatureLines.isEmpty {
                    Button {
                        signatureLines = []
                        currentLine = []
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(SierraFont.scaled(12, weight: .bold))
                            Text("Clear")
                                .font(SierraFont.scaled(12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.90, green: 0.22, blue: 0.18))
                    }
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                signatureLines.isEmpty
                                    ? Color.appDivider
                                    : Color.appOrange.opacity(0.4),
                                style: StrokeStyle(lineWidth: 1.5, dash: signatureLines.isEmpty ? [6, 4] : [])
                            )
                    )

                if signatureLines.isEmpty && currentLine.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "hand.draw.fill")
                            .font(SierraFont.scaled(28))
                            .foregroundColor(.appTextSecondary.opacity(0.3))
                        Text("Draw here")
                            .font(SierraFont.scaled(13, weight: .medium, design: .rounded))
                            .foregroundColor(.appTextSecondary.opacity(0.5))
                    }
                }

                Canvas { context, _ in
                    for line in signatureLines {
                        var path = Path()
                        guard let first = line.first else { continue }
                        path.move(to: first)
                        for point in line.dropFirst() { path.addLine(to: point) }
                        context.stroke(path, with: .color(.primary), lineWidth: 2.5)
                    }
                    if !currentLine.isEmpty {
                        var path = Path()
                        path.move(to: currentLine[0])
                        for point in currentLine.dropFirst() { path.addLine(to: point) }
                        context.stroke(path, with: .color(.primary), lineWidth: 2.5)
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

            if !signatureLines.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(SierraFont.scaled(14, weight: .bold))
                        .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
                    Text("Signature captured")
                        .font(SierraFont.scaled(14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.12))
                )
            }
        }
    }

    // MARK: - OTP Section

    private var otpSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if generatedOTP == nil {
                // Generate OTP button
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.appOrange.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: "number.circle.fill")
                            .font(SierraFont.scaled(30, weight: .bold))
                            .foregroundColor(.appOrange)
                    }

                    Text("Generate a one-time code\nand share it with the recipient")
                        .font(SierraFont.scaled(14, weight: .medium, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)

                    Button {
                        Task { await generateOTP() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "key.fill")
                                .font(SierraFont.scaled(14, weight: .bold))
                            Text("Generate OTP")
                                .font(SierraFont.scaled(15, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(Color.appOrange)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                // OTP sent confirmation (code intentionally hidden)
                VStack(spacing: 10) {
                    Text("OTP SENT TO DRIVER ALERTS")
                        .font(SierraFont.scaled(11, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                        .tracking(1.5)

                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                            .font(SierraFont.scaled(16, weight: .bold))
                            .foregroundColor(.appOrange)
                        Text("OTP sent as notification. Copy and paste here.")
                            .font(SierraFont.scaled(14, weight: .semibold, design: .rounded))
                            .foregroundColor(.appTextPrimary)
                    }
                    .multilineTextAlignment(.center)

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(SierraFont.scaled(11))
                        Text("Valid for 10 minutes")
                            .font(SierraFont.scaled(12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.appTextSecondary)

                    if otpSentNotification {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(SierraFont.scaled(12, weight: .bold))
                            Text("Notification delivered")
                                .font(SierraFont.scaled(12, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
                    } else if otpNotificationFailed {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(SierraFont.scaled(12, weight: .bold))
                            Text("Alerts sync delayed. OTP still valid here.")
                                .font(SierraFont.scaled(12, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.90, green: 0.22, blue: 0.18))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appOrange.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.appOrange.opacity(0.2), lineWidth: 1)
                        )
                )

                // Verification
                Rectangle()
                    .fill(Color.appDivider)
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 8) {
                    Text("RECIPIENT ENTERS CODE")
                        .font(SierraFont.scaled(11, weight: .bold, design: .rounded))
                        .foregroundColor(.appTextSecondary)
                        .tracking(1)

                    TextField("Enter OTP", text: $otpEnteredByRecipient)
                        .keyboardType(.numberPad)
                        .font(SierraFont.scaled(22, weight: .bold, design: .monospaced))
                        .foregroundColor(.appTextPrimary)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.appSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            otpVerified
                                                ? Color(red: 0.20, green: 0.65, blue: 0.32)
                                                : Color.appDivider,
                                            lineWidth: 1.5
                                        )
                                )
                        )

                    if !otpVerified {
                        Button {
                            verifyOTP()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(SierraFont.scaled(14, weight: .bold))
                                Text("Verify Code")
                                    .font(SierraFont.scaled(15, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule().fill(Color.appOrange)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(SierraFont.scaled(14, weight: .bold))
                            Text("OTP Verified")
                                .font(SierraFont.scaled(14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.20, green: 0.65, blue: 0.32))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(Color(red: 0.20, green: 0.65, blue: 0.32).opacity(0.12))
                        )
                    }

                    if otpShowMismatch {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(SierraFont.scaled(12))
                            Text("Code does not match. Try again.")
                                .font(SierraFont.scaled(13, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.90, green: 0.22, blue: 0.18))
                    }

                    if otpExpired {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.badge.exclamationmark.fill")
                                .font(SierraFont.scaled(12))
                            Text("OTP expired. Generate a new one.")
                                .font(SierraFont.scaled(13, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.90, green: 0.22, blue: 0.18))
                    }

                    Button {
                        Task { await generateOTP() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(SierraFont.scaled(13, weight: .bold))
                            Text("Regenerate OTP")
                                .font(SierraFont.scaled(14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.appOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(Color.appOrange.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Common Fields Card

    private var commonFieldsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(SierraFont.scaled(14, weight: .bold))
                    .foregroundColor(.appOrange)
                Text("Recipient Details")
                    .font(SierraFont.scaled(15, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextPrimary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("RECIPIENT NAME")
                    .font(SierraFont.scaled(11, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextSecondary)
                    .tracking(1)

                TextField("Enter recipient name", text: $recipientName)
                    .font(SierraFont.scaled(15, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.appSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.appDivider, lineWidth: 1)
                            )
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("DELIVERY NOTES")
                    .font(SierraFont.scaled(11, weight: .bold, design: .rounded))
                    .foregroundColor(.appTextSecondary)
                    .tracking(1)

                TextField("Optional notes", text: $notes, axis: .vertical)
                    .font(SierraFont.scaled(15, weight: .medium, design: .rounded))
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.appSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.appDivider, lineWidth: 1)
                            )
                    )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appCardBg)
                .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.appDivider.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            Task { await submitProof() }
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(SierraFont.scaled(16, weight: .bold))
                }
                Text("Submit Proof of Delivery")
                    .font(SierraFont.scaled(16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(
                        canSubmit
                            ? LinearGradient(
                                colors: [Color.appAmber, Color.appOrange, Color.appDeepOrange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
            )
            .shadow(
                color: canSubmit ? Color.appOrange.opacity(0.3) : Color.clear,
                radius: 12, x: 0, y: 6
            )
        }
        .disabled(!canSubmit || isSubmitting)
        .buttonStyle(.plain)
    }

    // MARK: - OTP Logic

    private func generateOTP() async {
        let otp = String(format: "%06d", Int.random(in: 0...999999))
        generatedOTP = otp
        generatedOTPTime = Date()
        otpExpired = false
        otpVerified = false
        otpShowMismatch = false
        otpEnteredByRecipient = ""
        otpSentNotification = false
        otpNotificationFailed = false

        let credential = CryptoService.hash(password: otp)
        otpHash = credential.hash
        otpSalt = credential.salt

        let tripCode = store.trips.first(where: { $0.id == tripId })?.taskId ?? tripId.uuidString.prefix(8).uppercased()
        await sendLocalOTPNotification(otp: otp, tripCode: tripCode)
        otpSentNotification = true

        // Non-blocking remote notification row. OTP flow must continue regardless.
        Task {
            do {
                try await NotificationService.insertNotification(
                    recipientId: driverId,
                    type: .general,
                    title: "Delivery OTP: \(tripCode)",
                    body: "Your delivery verification code is \(otp). Valid for 10 minutes.",
                    entityType: "delivery_otp",
                    entityId: tripId
                )
            } catch {
                await MainActor.run {
                    otpSentNotification = false
                    otpNotificationFailed = true
                }
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(600))
            if !otpVerified {
                otpExpired = true
                generatedOTP = nil
            }
        }
    }

    private func sendLocalOTPNotification(otp: String, tripCode: String) async {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted == true else { return }

        let content = UNMutableNotificationContent()
        content.title = "Delivery OTP • \(tripCode)"
        content.body = "Code \(otp). Tap and copy, then paste in app."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "delivery-otp-\(tripId.uuidString)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    private func verifyOTP() {
        guard let hash = otpHash, let salt = otpSalt else { return }

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

            if method == .photo, let data = photoData {
                let path = "delivery-proofs/\(tripId.uuidString)/\(UUID().uuidString).jpg"
                try await supabase.storage
                    .from("sierra-uploads")
                    .upload(path, data: data, options: .init(contentType: "image/jpeg"))
                let url = try supabase.storage
                    .from("sierra-uploads")
                    .getPublicURL(path: path)
                photoUrl = url.absoluteString
            }

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
                        .from("sierra-uploads")
                        .upload(path, data: jpegData, options: .init(contentType: "image/jpeg"))
                    let url = try supabase.storage
                        .from("sierra-uploads")
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

            try await addProofWithRetry(pod)
            onComplete()
        } catch {
            if isTimeout(error) {
                errorMessage = "Submission timed out. Please retry once — your proof may already be saved."
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
        }

        isSubmitting = false
    }

    private func addProofWithRetry(_ pod: ProofOfDelivery) async throws {
        do {
            try await store.addProofOfDelivery(pod)
        } catch {
            guard isTimeout(error) else { throw error }
            try? await Task.sleep(for: .milliseconds(450))
            try await store.addProofOfDelivery(pod)
        }
    }

    private func isTimeout(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("timed out") || message.contains("timeout")
    }
}
