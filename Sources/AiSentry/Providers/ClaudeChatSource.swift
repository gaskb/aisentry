import Foundation

/// claude.ai (Pro/Max) session + weekly quota. Reverse-engineered from the browser
/// network call the Impostazioni -> Utilizzo page makes; unofficial but returns clean JSON.
struct ClaudeChatSource: UsageSource {
    let providerId = "claude_chat"
    let displayName = "Claude (chat)"
    let isExperimental = false

    let requiredFields: [CredentialField] = [
        CredentialField(
            key: "cookie",
            label: "Cookie di sessione",
            placeholder: "sessionKey=...",
            kind: .secret,
            helpText: "Da claude.ai: apri gli Strumenti di sviluppo del browser -> Network, ricarica la pagina, apri una richiesta verso claude.ai e copia l'intero header \"Cookie\"."
        ),
        CredentialField(
            key: "orgId",
            label: "Organization ID",
            placeholder: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
            kind: .text,
            helpText: "Visibile nell'URL della richiesta di rete /api/organizations/<questo id>/usage."
        ),
    ]

    func fetchMetrics(config: ProviderConfig) async throws -> [UsageMetric] {
        guard let cookie = config["cookie"], let orgId = config["orgId"] else {
            throw UsageSourceError.missingCredentials
        }
        guard let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage") else {
            throw UsageSourceError.other("URL non valido")
        }

        let json = try await AuthenticatedClient.getJSON(url: url, cookie: cookie)
        guard let root = json as? [String: Any] else {
            throw UsageSourceError.decoding("root")
        }

        var metrics: [UsageMetric] = []

        if let fiveHour = root.dict(at: "five_hour"), let percent = fiveHour.number(at: "utilization") {
            metrics.append(UsageMetric(
                id: "session",
                label: "Sessione (5h)",
                percent: percent,
                detail: ResetFormatting.resetsIn(fiveHour.string(at: "resets_at"))
            ))
        }

        if let sevenDay = root.dict(at: "seven_day"), let percent = sevenDay.number(at: "utilization") {
            metrics.append(UsageMetric(
                id: "weekly",
                label: "Settimanale (tutti i modelli)",
                percent: percent,
                detail: ResetFormatting.resetsIn(sevenDay.string(at: "resets_at"))
            ))
        }

        if let spend = root.dict(at: "spend"), (spend["enabled"] as? Bool) == true {
            let used = spend.number(at: "used", "amount_minor").map { $0 / 100 }
            let currency = spend.string(at: "used", "currency") ?? ""
            metrics.append(UsageMetric(
                id: "credits",
                label: "Crediti extra",
                percent: spend.number(at: "percent"),
                detail: used.map { String(format: "%.2f %@ spesi", $0, currency) }
            ))
        }

        return metrics
    }
}
