import Foundation

/// gemini.google.com (AI Plus/Pro/Ultra) usage limits. Unlike the other chat sources
/// this doesn't have a plain REST endpoint — Google serves it through the internal
/// "batchexecute" RPC protocol (rpcid `jSf9Qc`). Marked experimental: the response is
/// an undocumented nested array whose exact field semantics (in particular, which unit
/// "limit"/"used" are counted in) were inferred from a single all-zero sample captured
/// during development, not confirmed against a real non-zero reading.
struct GeminiChatSource: UsageSource {
    let providerId = "gemini_chat"
    let displayName = "Gemini (chat)"
    let isExperimental = true

    let requiredFields: [CredentialField] = [
        CredentialField(
            key: "cookie",
            label: "Cookie di sessione",
            placeholder: "SID=...",
            kind: .secret,
            helpText: "Da gemini.google.com: Strumenti di sviluppo -> Network, ricarica la pagina, copia l'header \"Cookie\" di una richiesta verso gemini.google.com."
        ),
    ]

    private static let host = "gemini.google.com"
    private static let rpcId = "jSf9Qc"

    func fetchMetrics(config: ProviderConfig) async throws -> [UsageMetric] {
        guard let cookie = config["cookie"] else {
            throw UsageSourceError.missingCredentials
        }
        guard let pageURL = URL(string: "https://\(Self.host)/usage") else {
            throw UsageSourceError.other("URL non valido")
        }

        let html = try await AuthenticatedClient.getText(url: pageURL, cookie: cookie)
        guard let tokens = GoogleBatchExecute.extractTokens(from: html) else {
            throw UsageSourceError.decoding("token anti-CSRF non trovato nella pagina (Google potrebbe aver cambiato formato)")
        }
        guard let requestURL = GoogleBatchExecute.requestURL(host: Self.host, rpcId: Self.rpcId, sourcePath: "/usage", tokens: tokens) else {
            throw UsageSourceError.other("URL RPC non valido")
        }
        let body = GoogleBatchExecute.requestBody(rpcId: Self.rpcId, args: "[]", tokens: tokens)

        let responseText = try await AuthenticatedClient.postForm(url: requestURL, formBody: body, cookie: cookie)
        guard let payload = GoogleBatchExecute.firstPayload(forRpcId: Self.rpcId, in: responseText) as? [Any],
              payload.count > 1,
              let limitEntries = payload[1] as? [[Any]]
        else {
            throw UsageSourceError.decoding("forma della risposta batchexecute inattesa")
        }

        return limitEntries.enumerated().compactMap { index, entry in
            guard
                entry.count > 2,
                let limit = (entry[0] as? NSNumber)?.doubleValue,
                let used = (entry[1] as? NSNumber)?.doubleValue,
                limit > 0
            else { return nil }

            let typeCode = (entry[2] as? NSNumber)?.intValue ?? index
            let label = typeCode == 1 ? "Utilizzo attuale" : (typeCode == 2 ? "Limite settimanale" : "Limite #\(typeCode)")
            let percent = (used / limit) * 100

            var detail: String?
            if entry.count > 3, let resets = entry[3] as? [[Any]],
               let resetSeconds = (resets.first?.first as? NSNumber)?.doubleValue {
                let resetDate = Date(timeIntervalSince1970: resetSeconds)
                detail = ResetFormatting.resetsIn(ISO8601DateFormatter().string(from: resetDate))
            }

            return UsageMetric(id: "limit_\(typeCode)", label: label, percent: percent, detail: detail)
        }
    }
}
