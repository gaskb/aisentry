import Foundation

/// platform.claude.com (formerly console.anthropic.com) spend vs. the monthly spend
/// limit configured under Billing. Same unofficial-but-clean-JSON pattern as chat.
struct ClaudeAPISource: UsageSource {
    let providerId = "claude_api"
    let displayName = "Claude API"
    let isExperimental = false

    let requiredFields: [CredentialField] = [
        CredentialField(
            key: "cookie",
            label: "Cookie di sessione",
            placeholder: "sessionKey=...",
            kind: .secret,
            helpText: "Da platform.claude.com: Strumenti di sviluppo -> Network, ricarica /settings/billing, copia l'header \"Cookie\" di una richiesta verso platform.claude.com."
        ),
        CredentialField(
            key: "orgId",
            label: "Organization ID",
            placeholder: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
            kind: .text,
            helpText: "Visibile nell'URL delle richieste /api/organizations/<questo id>/current_spend."
        ),
    ]

    func fetchMetrics(config: ProviderConfig) async throws -> [UsageMetric] {
        guard let cookie = config["cookie"], let orgId = config["orgId"] else {
            throw UsageSourceError.missingCredentials
        }
        guard
            let spendURL = URL(string: "https://platform.claude.com/api/organizations/\(orgId)/current_spend"),
            let limitURL = URL(string: "https://platform.claude.com/api/organizations/\(orgId)/spend_limits")
        else {
            throw UsageSourceError.other("URL non valido")
        }

        async let spendJSON = AuthenticatedClient.getJSON(url: spendURL, cookie: cookie)
        async let limitJSON = AuthenticatedClient.getJSON(url: limitURL, cookie: cookie)

        guard
            let spend = try await spendJSON as? [String: Any],
            let limit = try await limitJSON as? [String: Any]
        else {
            throw UsageSourceError.decoding("root")
        }

        guard let spentCents = spend.number(at: "amount") else {
            throw UsageSourceError.decoding("current_spend.amount")
        }
        guard let limitCents = limit.number(at: "enforced_limit_usd") else {
            // No enforced limit configured: report spend without a percentage.
            return [UsageMetric(
                id: "spend",
                label: "Spesa mensile",
                percent: nil,
                detail: String(format: "%.2f USD spesi (nessun limite impostato)", spentCents / 100)
            )]
        }

        let percent = limitCents > 0 ? (spentCents / limitCents) * 100 : nil
        return [UsageMetric(
            id: "spend",
            label: "Spesa mensile",
            percent: percent,
            detail: String(format: "%.2f / %.2f USD", spentCents / 100, limitCents / 100)
        )]
    }
}
