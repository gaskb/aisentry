import Foundation

/// Persists each provider's field values (secret fields to Keychain, plain text to
/// UserDefaults) and whether the provider is enabled.
enum ProviderConfigStore {
    private static func defaultsKey(providerId: String, field: String) -> String {
        "provider.\(providerId).\(field)"
    }

    private static func enabledKey(providerId: String) -> String {
        "provider.\(providerId).enabled"
    }

    static func isEnabled(providerId: String) -> Bool {
        UserDefaults.standard.bool(forKey: enabledKey(providerId: providerId))
    }

    static func setEnabled(_ enabled: Bool, providerId: String) {
        UserDefaults.standard.set(enabled, forKey: enabledKey(providerId: providerId))
    }

    static func load(source: UsageSource) -> ProviderConfig {
        var config = ProviderConfig()
        for field in source.requiredFields {
            switch field.kind {
            case .secret:
                config[field.key] = KeychainStore.load(providerId: source.providerId, field: field.key)
            case .text:
                config[field.key] = UserDefaults.standard.string(
                    forKey: defaultsKey(providerId: source.providerId, field: field.key)
                )
            }
        }
        return config
    }

    static func save(field: CredentialField, providerId: String, value: String) {
        switch field.kind {
        case .secret:
            KeychainStore.save(providerId: providerId, field: field.key, value: value)
        case .text:
            let key = defaultsKey(providerId: providerId, field: field.key)
            if value.isEmpty {
                UserDefaults.standard.removeObject(forKey: key)
            } else {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
    }
}
