import SwiftUI

struct MenuContentView: View {
    @ObservedObject var monitor: UsageMonitor
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let enabled = monitor.statuses.filter(\.isEnabled)

            if enabled.isEmpty {
                Text("Nessun provider configurato")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(enabled) { status in
                    ProviderMenuSection(status: status)
                    Divider()
                }
            }

            Button("Aggiorna ora") {
                Task { await monitor.refreshAll() }
            }

            Button("Impostazioni…") {
                openSettings()
            }
            .keyboardShortcut(",")

            Divider()

            Button("Esci") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(4)
    }
}

private struct ProviderMenuSection: View {
    let status: ProviderStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(status.source.displayName).font(.headline)
                if status.source.isExperimental {
                    Text("sperimentale")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            if let error = status.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if status.metrics.isEmpty {
                Text("In attesa del primo aggiornamento…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(status.metrics) { metric in
                    HStack {
                        Text(metric.label)
                        Spacer()
                        if let percent = metric.percent {
                            Text("\(Int(percent.rounded()))%")
                        }
                    }
                    .font(.caption)
                    if let detail = metric.detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
