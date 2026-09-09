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
                bringSettingsWindowToFront()
            }
            .keyboardShortcut(",")

            Divider()

            Button("Esci") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(4)
    }

    /// `openSettings()` alone leaves the window visible but not "key" when launched
    /// as a menu-bar-only app that was never the frontmost app (e.g. via `swift run`
    /// from Terminal) — clicks land, but the keyboard/paste never reaches the fields.
    /// Forcing activation + makeKey after SwiftUI has had a beat to create the window
    /// works around it.
    private func bringSettingsWindowToFront() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.activate(ignoringOtherApps: true)
            let settingsWindow = NSApp.windows.first {
                $0.identifier?.rawValue.contains("Settings") == true
            } ?? NSApp.windows.first { $0.canBecomeKey }
            settingsWindow?.makeKeyAndOrderFront(nil)
            settingsWindow?.orderFrontRegardless()
        }
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
