import Foundation

final class BabyRecognizerImpl: BabyRecognizer, Sendable {
    private let apiBaseUrl: String
    private let apiKey: String
    private let modelName: String
    private let systemPrompt: String
    private let userPrompt: String
    private let session: URLSession

    init(apiBaseUrl: String, apiKey: String, modelName: String = "gpt-4o-mini",
         systemPrompt: String = SettingsManager.defaultSystemPrompt,
         userPrompt: String = SettingsManager.defaultUserPrompt) {
        self.apiBaseUrl = apiBaseUrl
        self.apiKey = apiKey
        self.modelName = modelName
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    func recognize(base64Image: String) async throws -> BabyDetectionResult {
        let urlString = "\(apiBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/v1/chat/completions"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": modelName,
            "max_tokens": 300,
            "temperature": 0.1,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": userPrompt],
                        ["type": "image_url", "image_url": ["url": base64Image]]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "BabyRecognizer", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "API error \(httpResponse.statusCode): \(responseBody)"])
        }

        return try parseResponse(data)
    }

    private func parseResponse(_ data: Data) throws -> BabyDetectionResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "BabyRecognizer", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response structure"])
        }

        let jsonString = extractJson(content)

        guard let jsonData = jsonString.data(using: .utf8),
              let result = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw NSError(domain: "BabyRecognizer", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON from content: \(content)"])
        }

        return BabyDetectionResult(
            containsBaby: result["contains_baby"] as? Bool ?? false,
            confidence: result["confidence"] as? Int ?? 0,
            reason: result["reason"] as? String ?? ""
        )
    }

    private func extractJson(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try markdown code block: ```json ... ``` or ``` ... ```
        let codeBlockRegex = try! NSRegularExpression(pattern: "```(?:json)?\\s*\\n?([\\s\\S]*?)\\n?```")
        let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
        if let match = codeBlockRegex.firstMatch(in: trimmed, range: nsRange),
           let range = Range(match.range(at: 1), in: trimmed) {
            return String(trimmed[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try raw JSON object
        let jsonRegex = try! NSRegularExpression(pattern: "\\{[\\s\\S]*\\}")
        if let match = jsonRegex.firstMatch(in: trimmed, range: nsRange),
           let range = Range(match.range, in: trimmed) {
            return String(trimmed[range])
        }

        return trimmed
    }
}
