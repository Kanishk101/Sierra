import SwiftUI

// MARK: - AskAIChatView

struct AskAIChatView: View {

    @State private var viewModel = AskAIViewModel()
    @FocusState private var inputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messagesArea
                Divider().overlay(SierraTheme.Colors.cloud.opacity(0.75))
                inputBar
            }
            .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
            .navigationTitle("Ask Sierra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { viewModel.clearAll() } label: {
                        Label("Clear", systemImage: "trash")
                            .font(SierraFont.subheadline)
                            .foregroundStyle(SierraTheme.Colors.granite)
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(SierraTheme.Colors.granite)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
        .onAppear {
            if viewModel.messages.isEmpty {
                viewModel.messages.append(ChatMessage(
                    role: .assistant,
                    text: "Hi! I can answer questions about your fleet — vehicles, trips, staff, and more. Try asking: *\"How many busy vehicles are there?\"*",
                    timestamp: .now
                ))
            }
        }
    }

    // MARK: - Messages Scroll Area

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                    if viewModel.isLoading {
                        TypingIndicator()
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(SierraTheme.Colors.appBackground)
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    if let last = viewModel.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isLoading) { _, loading in
                if loading {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about your fleet…", text: $viewModel.inputText, axis: .vertical)
                .font(SierraFont.bodyText)
                .foregroundStyle(SierraTheme.Colors.primaryText)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    SierraTheme.Colors.cardSurface,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(SierraTheme.Colors.cloud.opacity(0.9), lineWidth: 1)
                )
                .focused($inputFocused)
                .onSubmit {
                    Task { await viewModel.send() }
                }
                .submitLabel(.send)

            Button {
                Task { await viewModel.send() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: viewModel.isLoading ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(canSend ? SierraTheme.Colors.ember : SierraTheme.Colors.granite)
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(.symbolEffect(.replace))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(SierraTheme.Colors.appBackground)
    }

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {

    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            if !isUser {
                // Assistant avatar
                ZStack {
                    Circle()
                        .fill(SierraTheme.Colors.ember.opacity(0.14))
                        .frame(width: 30, height: 30)
                    Image(systemName: "sparkles.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SierraTheme.Colors.ember)
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(SierraFont.bodyText)
                    .foregroundStyle(isUser ? Color.white : SierraTheme.Colors.primaryText)
                    .multilineTextAlignment(isUser ? .trailing : .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser
                        ? AnyShapeStyle(SierraTheme.Colors.ember)
                        : AnyShapeStyle(SierraTheme.Colors.cardSurface),
                        in: BubbleShape(isUser: isUser)
                    )
                    .overlay(
                        BubbleShape(isUser: isUser)
                            .stroke(
                                isUser ? SierraTheme.Colors.ember.opacity(0.35) : SierraTheme.Colors.cloud.opacity(0.9),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)

                Text(message.timestamp.formatted(.dateTime.hour().minute()))
                    .font(SierraFont.caption1)
                    .foregroundStyle(SierraTheme.Colors.granite)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - BubbleShape

private struct BubbleShape: Shape {
    let isUser: Bool
    private let r: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r))
        return p
    }
}

// MARK: - TypingIndicator

private struct TypingIndicator: View {

    @State private var phase = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(SierraTheme.Colors.ember.opacity(0.14)).frame(width: 30, height: 30)
                Image(systemName: "sparkles.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SierraTheme.Colors.ember)
            }
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(SierraTheme.Colors.granite.opacity(0.65))
                        .frame(width: 8, height: 8)
                        .scaleEffect(phase == i ? 1.35 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(SierraTheme.Colors.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(SierraTheme.Colors.cloud.opacity(0.9), lineWidth: 1)
            )
            Spacer(minLength: 60)
        }
        .onAppear { phase = 1 }
    }
}

// MARK: - AskAIFAB (Floating Action Button)

struct AskAIFAB: View {

    @Binding var isPresented: Bool

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            isPresented = true
        } label: {
            ZStack {
                // Glow layer
                Circle()
                    .fill(SierraTheme.Colors.ember.opacity(0.24))
                    .frame(width: 64, height: 64)
                    .blur(radius: 8)

                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [SierraTheme.Colors.ember, SierraTheme.Colors.emberDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: SierraTheme.Colors.ember.opacity(0.42), radius: 10, y: 4)

                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AskAIChatView()
}
