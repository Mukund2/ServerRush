import Foundation

// MARK: - Mistral AI Guide Service
final class MistralService {
    static let shared = MistralService()

    private let apiURL = URL(string: "https://api.mistral.ai/v1/chat/completions")!
    private let model = "mistral-small-latest"
    private let systemPrompt = """
        You are Chip, a cheerful little engineer guide in Server Rush — a cozy data center tycoon game. \
        You wear a hard hat, have a round orange body, and love helping the player build their dream data center. \
        Your personality: warm, encouraging, a little goofy, and genuinely excited about servers and infrastructure. \
        You speak in short, punchy lines (1-2 sentences max, under 120 characters total). \
        Use casual language, light humor, and the occasional data center pun. Never be robotic or dry. \
        React specifically to what the player is doing — celebrate wins, warn about problems, give tactical tips. \
        Think Stardew Valley shopkeeper energy, not tech support.
        """

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "MISTRAL_API_KEY") ?? "MISTRAL_API_KEY"
    }

    // Track triggers so we don't spam the player
    private var hasShownFirstBuildTip = false
    private var hasShownFirstIncidentTip = false
    private var lastMilestoneLevel = 0

    private init() {}

    // MARK: - Public API

    /// Fetch a contextual guide message from Mistral, falling back to local strings on failure.
    func getGuideMessage(context: String) async -> String {
        // Try the API first
        if let response = await callAPI(context: context) {
            return response
        }
        // Fallback to local dialogue
        return pickFallback(context: context)
    }

    /// Determine whether the guide should speak based on game events.
    func shouldTriggerGuide(
        firstBuild: Bool = false,
        firstIncident: Bool = false,
        milestoneLevel: Int = 0,
        powerPercent: Double = 0,
        coolingPercent: Double = 0
    ) -> String? {
        if firstBuild && !hasShownFirstBuildTip {
            hasShownFirstBuildTip = true
            return buildContext(event: "first_build")
        }

        if firstIncident && !hasShownFirstIncidentTip {
            hasShownFirstIncidentTip = true
            return buildContext(event: "first_incident")
        }

        if milestoneLevel > lastMilestoneLevel {
            lastMilestoneLevel = milestoneLevel
            return buildContext(event: "milestone", detail: "level \(milestoneLevel)")
        }

        if powerPercent > 85 {
            return buildContext(event: "resource_warning", detail: "power at \(Int(powerPercent))%")
        }

        if coolingPercent > 85 {
            return buildContext(event: "resource_warning", detail: "cooling at \(Int(coolingPercent))%")
        }

        return nil
    }

    // MARK: - API Call

    private func callAPI(context: String) async -> String? {
        guard apiKey != "MISTRAL_API_KEY" else { return nil }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": context]
            ],
            "max_tokens": 100,
            "temperature": 0.7
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        request.timeoutInterval = 5

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            // Fall through to nil so caller uses fallback
        }

        return nil
    }

    // MARK: - Context Builder

    private func buildContext(event: String, detail: String = "") -> String {
        var parts = ["Game event: \(event)"]
        if !detail.isEmpty { parts.append("Detail: \(detail)") }
        return parts.joined(separator: ". ")
    }

    // MARK: - Fallback Dialogue

    private static let tutorialTips = [
        "Place server racks to start earning revenue!",
        "Don't forget cooling - overheating servers crash!",
        "Watch your power capacity - generators keep everything running",
        "Network switches increase your bandwidth capacity"
    ]

    private static let incidentTips = [
        "Quick! Tap that overheating rack before it crashes!",
        "A DDoS attack! Enable the firewall filters!",
        "Power's out! Switch to backup generators!",
        "Cable disconnected - tap to reconnect it!"
    ]

    private static let milestoneTips = [
        "Great work! Your data center is growing!",
        "Revenue is climbing - time to expand!",
        "You're running a tight ship, engineer!"
    ]

    private func pickFallback(context: String) -> String {
        let lowered = context.lowercased()

        if lowered.contains("incident") || lowered.contains("alert") {
            return Self.incidentTips.randomElement()!
        }
        if lowered.contains("milestone") || lowered.contains("level") {
            return Self.milestoneTips.randomElement()!
        }
        return Self.tutorialTips.randomElement()!
    }
}
