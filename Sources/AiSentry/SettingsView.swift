import SwiftUI

struct SettingsView: View {
    @ObservedObject var monitor: UsageMonitor
    @AppStorage("pollIntervalSeconds") private var pollIntervalSeconds: Double = 600

    var body: some View {
        TabView {
            ForEach(monitor.statuses) { status in
                ProviderSettingsTab(monitor: monitor, providerId: status.id)
                    .tabItem { Text(status.source.displayName) }
            }

            Form {
                Stepper(
                    "Intervallo di aggiornamento: \(Int(pollIntervalSeconds / 60)) min",
                    value: $pollIntervalSeconds,
                    in: 60...3600,
                    step: 60
                )
                .onChange(of: pollIntervalSeconds) { _, newValue in
                    monitor.pollIntervalSeconds = newValue
                }
            }
            .formStyle(.grouped)
            .padding()
            .tabItem { Text("Generali") }
        }
        .frame(width: 480, height: 420)
    }
}

private struct ProviderSettingsTab: View {
    @ObservedObject var monitor: UsageMonitor
    let providerId: String

    @State private var fieldValues: [String: String] = [:]
    @State private var isEnabled = false
    @State private var isRefreshing = false

    private var status: ProviderStatus? {
        monitor.statuses.first { $0.id == providerId }
    }

    var body: some View {
        Form {
            if let status {
                Section {
                    Toggle("Abilitato", isOn: $isEnabled)
                        .onChange(of: isEnabled) { _, newValue in
                            monitor.setEnabled(newValue, providerId: providerId)
                        }

                    if status.source.isExperimental {
                        Text("⚠️ Fonte sperimentale: si basa su un endpoint non documentato e può smettere di funzionare senza preavviso.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Credenziali") {
                    ForEach(status.source.requiredFields, id: \.key) { field in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(field.label)
                                .font(.subheadline)
                                .bold()
                            if field.kind == .secret {
                                SecureField(field.placeholder, text: binding(for: field))
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                TextField(field.placeholder, text: binding(for: field))
                                    .textFieldStyle(.roundedBorder)
                            }
                            Text(field.helpText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Stato") {
                    if let error = status.lastError {
                        Text(error).foregroundStyle(.red)
                    }
                    ForEach(status.metrics) { metric in
                        HStack {
                            Text(metric.label)
                            Spacer()
                            if let percent = metric.percent {
                                Text("\(Int(percent.rounded()))%")
                            }
                            if let detail = metric.detail {
                                Text(detail).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let lastUpdated = status.lastUpdated {
                        Text("Ultimo aggiornamento: \(lastUpdated.formatted(date: .omitted, time: .standard))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Button(isRefreshing ? "Verifica…" : "Verifica ora") {
                        saveAllFields()
                        Task {
                            isRefreshing = true
                            await monitor.refresh(providerId: providerId)
                            isRefreshing = false
                        }
                    }
                    .disabled(isRefreshing)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear(perform: load)
        .onDisappear(perform: saveAllFields)
    }

    /// Only touches @State while typing — writing to Keychain on every keystroke
    /// triggered a macOS access-confirmation prompt per character on unsigned/ad-hoc
    /// dev builds, effectively locking out anyone pasting a long cookie. Persisted
    /// explicitly instead: on "Verifica ora" and when leaving the tab.
    private func binding(for field: CredentialField) -> Binding<String> {
        Binding(
            get: { fieldValues[field.key] ?? "" },
            set: { fieldValues[field.key] = $0 }
        )
    }

    private func saveAllFields() {
        guard let status else { return }
        for field in status.source.requiredFields {
            let value = fieldValues[field.key] ?? ""
            ProviderConfigStore.save(field: field, providerId: providerId, value: normalize(value, for: field))
        }
    }

    /// Forgiving of a common copy-paste mistake: selecting the whole "Cookie: xxx"
    /// header line (name included) instead of just the value.
    private func normalize(_ value: String, for field: CredentialField) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if field.key == "cookie" {
            for prefix in ["cookie:", "Cookie:"] where trimmed.hasPrefix(prefix) {
                trimmed = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            }
        }
        return trimmed
    }

    private func load() {
        guard let status else { return }
        isEnabled = status.isEnabled
        let config = ProviderConfigStore.load(source: status.source)
        fieldValues = config.values
    }
}
