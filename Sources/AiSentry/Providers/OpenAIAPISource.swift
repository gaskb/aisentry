import Foundation

/// OpenAI's official, documented organization Costs API (api.openai.com), authenticated
/// with an Admin API key (Settings -> Admin keys on platform.openai.com — NOT a regular
/// project API key). Unlike the other sources here this isn't scraped from the browser:
/// during the discovery spike we saw the equivalent data in the platform.openai.com
/// dashboard but couldn't capture the exact browser call, so this talks to the public
/// API directly instead. Cross-check the endpoint shape against
/// https://platform.openai.com/docs/api-reference/usage before relying on it long-term,
/// since it wasn't verified live this session the way the other sources were.
struct OpenAIAPISource: UsageSource {
    let providerId = "openai_api"
    let displayName = "OpenAI API"
    let isExperimental = false

    let requiredFields: [CredentialField] = [
        CredentialField(
            key: "adminKey",
            label: "Admin API key",
            placeholder: "sk-admin-...",
            kind: .secret,
            helpText: "platform.openai.com -> Settings -> Admin keys (organization owner). Diversa da una normale API key di progetto."
        ),
        CredentialField(
            key: "monthlyBudgetUSD",
            label: "Budget mensile (USD)",
            placeholder: "es. 50",
            kind: .text,
            helpText: "OpenAI non espone via API il limite di spesa configurato; inserisci qui il tuo budget per calcolare una percentuale."
        ),
    ]

    func fetchMetrics(config: ProviderConfig) async throws -> [UsageMetric] {
        guard let adminKey = config["adminKey"] else {
            throw UsageSourceError.missingCredentials
        }

        let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        let startTime = Int(startOfMonth.timeIntervalSince1970)

        guard var components = URLComponents(string: "https://api.openai.com/v1/organization/costs") else {
            throw UsageSourceError.other("URL non valido")
        }
        components.queryItems = [
            URLQueryItem(name: "start_time", value: String(startTime)),
            URLQueryItem(name: "bucket_width", value: "1d"),
            URLQueryItem(name: "limit", value: "31"),
        ]
        guard let url = components.url else {
            throw UsageSourceError.other("URL non valido")
        }

        let json = try await AuthenticatedClient.getJSON(url: url, bearerToken: adminKey)
        guard let root = json as? [String: Any], let buckets = root["data"] as? [[String: Any]] else {
            throw UsageSourceError.decoding("data")
        }

        var totalUSD = 0.0
        for bucket in buckets {
            guard let results = bucket["results"] as? [[String: Any]] else { continue }
            for result in results {
                if let amount = result.number(at: "amount", "value") {
                    totalUSD += amount
                }
            }
        }

        guard let budget = config["monthlyBudgetUSD"].flatMap(Double.init), budget > 0 else {
            return [UsageMetric(
                id: "spend",
                label: "Spesa mensile",
                percent: nil,
                detail: String(format: "%.2f USD spesi (imposta un budget per vedere la %%)", totalUSD)
            )]
        }

        let percent = (totalUSD / budget) * 100
        return [UsageMetric(
            id: "spend",
            label: "Spesa mensile",
            percent: percent,
            detail: String(format: "%.2f / %.2f USD", totalUSD, budget)
        )]
    }
}
