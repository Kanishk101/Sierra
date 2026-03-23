import SwiftUI
import Combine

struct ActiveNavigationView: View {
    let trip: Trip
    let onEndTrip: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ActiveNavigationViewModel()
    private let navTimer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Moving road background
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.10, blue: 0.11),
                        Color(red: 0.03, green: 0.03, blue: 0.04),
                        .black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.11), Color.white.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 130)
                    .blur(radius: 0.3)

                ForEach(0..<12, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.appOrange.opacity(0.7))
                        .frame(width: 8, height: 30)
                        .offset(y: CGFloat(idx) * 86 + viewModel.roadOffset - 480)
                }
            }

            VStack(spacing: 0) {
                topInstructionCard
                    .padding(.top, 12)
                    .padding(.horizontal, 20)

                if let fallback = viewModel.fallbackErrorMessage {
                    AppFallbackErrorBanner(message: fallback, onDismiss: { viewModel.clearError() })
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                Spacer()

                speedRing
                    .padding(.bottom, 42)

                bottomCards
            }

            if viewModel.showEndTripModal {
                endTripModal
            }

            if viewModel.showDeliveryProofModal {
                deliveryProofModal
            }

            if viewModel.showReportIssueModal {
                reportIssueModal
            }

            if viewModel.showIssueSentToast {
                issueSentToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(80)
            }
        }
        .onAppear {
            viewModel.load(trip: trip)
            viewModel.animateRoad()
        }
        .onReceive(navTimer) { _ in
            viewModel.tick()
        }
        .navigationBarBackButtonHidden(true)
        .statusBarHidden()
    }

    private var topInstructionCard: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(viewModel.navAlert.tint.opacity(0.2))
                    .frame(width: 52, height: 52)

                Image(systemName: viewModel.navAlert == .collisionAhead ? "exclamationmark.triangle.fill" : "arrow.turn.up.right")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(viewModel.navAlert.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("In \(String(format: "%.1f", max(0, Double(viewModel.currentDistance) / 40))) km")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
                Text(viewModel.navAlert == .collisionAhead ? "Drive Carefully" : "Turn Right")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("on National Highway 48")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
                    .padding(.top, 2)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var speedRing: some View {
        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.25), lineWidth: 4)
                .frame(width: 132, height: 132)

            Circle()
                .fill(Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.84))
                .frame(width: 116, height: 116)
                .overlay(
                    Circle()
                        .stroke(Color.green.opacity(0.4), lineWidth: 2)
                )

            VStack(spacing: 0) {
                Text("\(Int(viewModel.currentSpeed))")
                    .font(.system(size: 39, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: viewModel.currentSpeed)
                Text("km/h")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
    }

    private var bottomCards: some View {
        VStack(spacing: 12) {
            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Destination", systemImage: "flag.fill")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.appOrange)
                            .textCase(.uppercase)
                        Text(trip.destination.uppercased())
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Distribution Center - Zone A")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button(action: { withAnimation(.spring(response: 0.3)) { viewModel.showEndTripModal = true } }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.red)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.red.opacity(0.2)))
                    }
                }

                HStack(spacing: 10) {
                    statCard(icon: "chart.line.uptrend.xyaxis", title: "Distance", value: "\(viewModel.currentDistance) km", accent: .appOrange)
                    statCard(icon: "clock.fill", title: "ETA", value: "\(viewModel.timeRemaining / 60)h \(viewModel.timeRemaining % 60)m", accent: .green)
                }

                VStack(spacing: 6) {
                    HStack {
                        Text("Trip Progress")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(viewModel.progress))%")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(red: 0.17, green: 0.17, blue: 0.18))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .appOrange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * viewModel.progress / 100)
                        }
                    }
                    .frame(height: 8)
                }

                if viewModel.navAlert != .turnAhead {
                    HStack(spacing: 10) {
                        Image(systemName: viewModel.navAlert.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(viewModel.navAlert.tint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(viewModel.navAlert.title)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(viewModel.navAlert.subtitle)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(viewModel.navAlert.background)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(viewModel.navAlert.tint.opacity(0.35), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.navAlert.title)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 20)

            HStack(spacing: 10) {
                quickButton(title: "Mute", icon: "speaker.slash.fill", background: Color(red: 0.11, green: 0.11, blue: 0.12), text: .white)
                quickButton(title: "Report Issue", icon: "exclamationmark.triangle", background: Color(red: 0.11, green: 0.11, blue: 0.12), text: .white) {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.showReportIssueModal = true
                    }
                }
            }
            .padding(.horizontal, 20)

            quickButton(title: "End Trip", icon: "flag.fill", background: .red.opacity(0.92), text: .white) {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.showEndTripModal = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private func statCard(icon: String, title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accent)
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
            }
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.17, green: 0.17, blue: 0.18))
        )
    }

    private func quickButton(
        title: String,
        icon: String,
        background: Color,
        text: Color,
        action: (() -> Void)? = nil
    ) -> some View {
        Button(action: { action?() }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundColor(text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(background)
            )
        }
        .buttonStyle(.plain)
    }

    private var endTripModal: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.showEndTripModal = false
                    }
                }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "flag.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Color.red.opacity(0.95))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("End Trip?")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("This will complete all stops and begin post-trip inspection.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }

                HStack(spacing: 10) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.showEndTripModal = false
                        }
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.17, green: 0.17, blue: 0.18))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.showEndTripModal = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.showDeliveryProofModal = true
                            }
                        }
                    }) {
                        Text("Confirm End")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.95, green: 0.23, blue: 0.20))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.11).opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 104)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .ignoresSafeArea()
    }

    private var deliveryProofModal: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.showDeliveryProofModal = false
                    }
                }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.appOrange.opacity(0.2))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "doc.badge.checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.appOrange)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Submit Delivery Proof")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Upload proof images before ending trip.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }

                proofUploadRow(
                    title: "Delivery Proof Image",
                    subtitle: "Photo of delivered package / drop proof",
                    isAttached: $viewModel.deliveryProofImageAttached,
                    icon: "photo.fill"
                )

                proofUploadRow(
                    title: "Receiver Signed Document",
                    subtitle: "Signed POD or acknowledgement slip",
                    isAttached: $viewModel.receiverSignedDocAttached,
                    icon: "signature"
                )

                HStack(spacing: 10) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.showDeliveryProofModal = false
                        }
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.17, green: 0.17, blue: 0.18))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: submitDeliveryAndEndTrip) {
                        Text("Submit & End Trip")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.95, green: 0.23, blue: 0.20))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canSubmitDelivery)
                    .opacity(viewModel.canSubmitDelivery ? 1 : 0.5)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.11).opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 96)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .ignoresSafeArea()
    }

    private func proofUploadRow(
        title: String,
        subtitle: String,
        isAttached: Binding<Bool>,
        icon: String
    ) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isAttached.wrappedValue.toggle()
        }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 44, height: 44)
                    Image(systemName: isAttached.wrappedValue ? icon : "camera.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isAttached.wrappedValue ? .green : .appOrange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text(isAttached.wrappedValue ? "Attached" : subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: isAttached.wrappedValue ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isAttached.wrappedValue ? .green : .appOrange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.16, green: 0.16, blue: 0.17))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var reportIssueModal: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.showReportIssueModal = false
                    }
                }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.appOrange.opacity(0.2))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.appOrange)
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Report Issue")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("This will be sent to admin while route continues.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }

                Text("Describe the issue")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $viewModel.issueText)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .frame(height: 108)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 0.16, green: 0.16, blue: 0.17))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )

                    if viewModel.issueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Example: Road blocked due to accident near next turn")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.gray.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }

                HStack(spacing: 10) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.showReportIssueModal = false
                            viewModel.issueText = ""
                        }
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.17, green: 0.17, blue: 0.18))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: submitIssue) {
                        Text("Send")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.appOrange)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.issueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(viewModel.issueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 96)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .ignoresSafeArea()
    }

    private var issueSentToast: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Issue sent to admin. Continuing route.")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.appOrange)
            )
            .padding(.top, 60)
            Spacer()
        }
    }

    private func submitIssue() {
        viewModel.submitIssue()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            viewModel.hideIssueToast()
        }
    }

    private func submitDeliveryAndEndTrip() {
        guard viewModel.canSubmitDelivery else { return }
        withAnimation(.spring(response: 0.3)) {
            viewModel.showDeliveryProofModal = false
        }
        onEndTrip()
        dismiss()
    }
}

#Preview {
    ActiveNavigationView(
        trip: Trip(
            id: "preview",
            tripCode: "TRP-20260315-102",
            origin: "Bengaluru",
            destination: "Hubli",
            fleetNumber: "FL-4096",
            vehicleType: "Sleeper Coach Volvo",
            dateTime: "15 Mar at 7:00 AM"
        ),
        onEndTrip: {}
    )
}
