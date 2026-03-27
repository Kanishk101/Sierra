import Foundation

// MARK: - Groq Configuration

private let groqAPIKey   = "."
private let groqEndpoint = URL(string: "https://api.groq.com/openai/v1/responses")!
private let groqModel    = "llama-3.3-70b-versatile"

// MARK: - GroqSummaryService

enum GroqSummaryService {

    // MARK: - Public API

    /// Summarises fleet/trip data using Groq's llama model.
    /// - Parameters:
    ///   - topic: Short label for what is being summarised (e.g. "Fleet Usage", "Trips Overview").
    ///   - data:  A JSON-serialisable dictionary of key metrics pulled from AppDataStore.
    /// - Returns: A concise AI-generated string insight.
    static func summarise(topic: String, data: [String: Any]) async throws -> String {
        let dataJSON = (try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        let inputText = """
You are a fleet analytics assistant for a logistics company. \
Be concise, professional, and actionable. Respond in 2–4 sentences max.

Summarise the following \(topic) data and highlight any key concerns or positive trends:

\(dataJSON)
"""

        let body: [String: Any] = [
            "model":       groqModel,
            "temperature": 0.3,
            "input":       inputText
        ]

        var request = URLRequest(url: groqEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(groqAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json",     forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let raw = String(data: data, encoding: .utf8) ?? "<no body>"
            throw GroqError.httpError(http.statusCode, raw)
        }
        print(response)
        return try parseResponse(data)
    }

    // MARK: - Response Parsing

    /// Parses `output[0].content[0].text` from the Groq Responses API.
    private static func parseResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GroqError.invalidResponse
        }
        print(json)

        // Responses API shape: { "output": [ { "type": "reasoning", ... }, { "role": "assistant", "content": [...] } ] }
        if let output = json["output"] as? [[String: Any]] {
            for element in output {
                if let content = element["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // Fallback — some models return choices[] (Chat Completions shape)
        if let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw GroqError.invalidResponse
    }

    // MARK: - Errors

    enum GroqError: LocalizedError {
        case httpError(Int, String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .httpError(let code, _): return "Groq API error (\(code)). Check your API key."
            case .invalidResponse:        return "Unexpected response format from Groq."
            }
        }
    }
}
