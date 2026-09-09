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

                Text("AiSentry è gratis. Se ti torna utile, sentiti libero di [offrirmi un caffè ☕](https://ko-fi.com/gaskb).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                        VStack(alignment: .leading, spacing: 2) {
                            if field.kind == .secret {
                                SecureField(field.label, text: binding(for: field))
                            } else {
                                TextField(field.label, text: binding(for: field))
                            }
                            Text(field.helpText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
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
    }

    private func binding(for field: CredentialField) -> Binding<String> {
        Binding(
            get: { fieldValues[field.key] ?? "" },
            set: { newValue in
                fieldValues[field.key] = newValue
                ProviderConfigStore.save(field: field, providerId: providerId, value: newValue)
            }
        )
    }

    private func load() {
        guard let status else { return }
        isEnabled = status.isEnabled
        let config = ProviderConfigStore.load(source: status.source)
        fieldValues = config.values
    }
}
