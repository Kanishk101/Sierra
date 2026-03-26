import Foundation
import Observation

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let text: String
    let timestamp: Date

    enum ChatRole {
        case user, assistant
    }
}

// MARK: - AskAIViewModel

@Observable
final class AskAIViewModel {

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Send

    @MainActor
    func send() async {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isLoading else { return }

        // Append user bubble
        messages.append(ChatMessage(role: .user, text: prompt, timestamp: .now))
        inputText = ""
        isLoading = true
        errorMessage = nil

        do {
            let response = try await AskAIService.ask(prompt: prompt)
            messages.append(ChatMessage(role: .assistant, text: response.answer, timestamp: .now))
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
            messages.append(ChatMessage(
                role: .assistant,
                text: "⚠️ \(message)",
                timestamp: .now
            ))
        }

        isLoading = false
    }

    func clearAll() {
        messages = []
        inputText = ""
        errorMessage = nil
        isLoading = false
    }
}
