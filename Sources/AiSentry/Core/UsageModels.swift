import Foundation

/// One measured quantity from a provider (e.g. "session window", "monthly spend").
struct UsageMetric: Identifiable, Sendable, Equatable {
    let id: String
    let label: String
    /// 0-100, nil when the provider has no meaningful percentage (e.g. spend tracking disabled).
    let percent: Double?
    let detail: String?
}

struct CredentialField: Sendable {
    enum Kind: Sendable {
        case secret
        case text
    }

    let key: String
    let label: String
    let placeholder: String
    let kind: Kind
    let helpText: String
}

/// Values the user entered in Settings for one provider, keyed by CredentialField.key.
struct ProviderConfig: Sendable {
    var values: [String: String] = [:]

    subscript(key: String) -> String? {
        get { values[key]?.isEmpty == false ? values[key] : nil }
        set { values[key] = newValue }
    }
}

enum UsageSourceError: LocalizedError {
    case missingCredentials
    case http(Int)
    case decoding(String)
    case other(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Credenziali mancanti"
        case .http(let code):
            return "Errore HTTP \(code)"
        case .decoding(let detail):
            return "Risposta inattesa (\(detail))"
        case .other(let message):
            return message
        }
    }
}

protocol UsageSource: Sendable {
    /// Stable identifier used for storage keys, e.g. "claude_chat".
    var providerId: String { get }
    var displayName: String { get }
    /// Sources built on undocumented endpoints that can break without notice.
    var isExperimental: Bool { get }
    var requiredFields: [CredentialField] { get }

    func fetchMetrics(config: ProviderConfig) async throws -> [UsageMetric]
}
