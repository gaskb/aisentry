import Foundation

/// grok.com chat rate limit. Cleanest of all the unofficial endpoints found during
/// the discovery spike: a small dedicated REST call, no org/team id needed.
struct GrokChatSource: UsageSource {
    let providerId = "grok_chat"
    let displayName = "Grok (chat)"
    let isExperimental = false

    let requiredFields: [CredentialField] = [
        CredentialField(
            key: "cookie",
            label: "Cookie di sessione",
            placeholder: "sso=...",
            kind: .secret,
            helpText: "Da grok.com: Strumenti di sviluppo -> Network, ricarica la pagina, apri la richiesta POST /rest/rate-limits e copia l'header \"Cookie\"."
        ),
    ]

    func fetchMetrics(config: ProviderConfig) async throws -> [UsageMetric] {
        guard let cookie = config["cookie"] else {
            throw UsageSourceError.missingCredentials
        }
        guard let url = URL(string: "https://grok.com/rest/rate-limits") else {
            throw UsageSourceError.other("URL non valido")
        }

        let json = try await AuthenticatedClient.postJSON(url: url, cookie: cookie)
        guard let root = json as? [String: Any] else {
            throw UsageSourceError.decoding("root")
        }

        guard
            let remaining = root.number(at: "remainingQueries"),
            let total = root.number(at: "totalQueries"),
            total > 0
        else {
            throw UsageSourceError.decoding("remainingQueries/totalQueries")
        }

        let used = total - remaining
        let percent = (used / total) * 100
        return [UsageMetric(
            id: "queries",
            label: "Messaggi",
            percent: percent,
            detail: "\(Int(used))/\(Int(total)) usati"
        )]
    }
}
