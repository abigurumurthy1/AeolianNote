import Foundation

actor ModerationService {
    static let shared = ModerationService()

    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/moderations"

    private init() {
        self.apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "your-api-key"
    }

    struct ModerationResult {
        let flagged: Bool
        let categories: [String]
    }

    func moderate(content: String) async throws -> ModerationResult {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["input": content]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ModerationError.apiError
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let results = json?["results"] as? [[String: Any]],
              let firstResult = results.first,
              let flagged = firstResult["flagged"] as? Bool else {
            throw ModerationError.invalidResponse
        }

        var flaggedCategories: [String] = []
        if let categories = firstResult["categories"] as? [String: Bool] {
            flaggedCategories = categories.filter { $0.value }.map { $0.key }
        }

        return ModerationResult(flagged: flagged, categories: flaggedCategories)
    }
}

enum ModerationError: LocalizedError {
    case apiError
    case invalidResponse
    case contentFlagged

    var errorDescription: String? {
        switch self {
        case .apiError: return "Moderation API error"
        case .invalidResponse: return "Invalid moderation response"
        case .contentFlagged: return "Content violates community guidelines"
        }
    }
}
