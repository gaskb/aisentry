import SwiftUI

struct MenuContentView: View {
    @ObservedObject var monitor: UsageMonitor
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

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
                bringWindowToFront(matching: "Settings")
            }
            .keyboardShortcut(",")

            Button("Info su AiSentry…") {
                openWindow(id: "about")
                bringWindowToFront(matching: "about")
            }

            Divider()

            Button("Esci") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(4)
    }

    /// `openSettings()`/`openWindow()` alone leave the window visible but not "key"
    /// when launched as a menu-bar-only app that was never the frontmost app (e.g. via
    /// `swift run` from Terminal) — clicks land, but the keyboard/paste never reaches
    /// the fields. Forcing activation + makeKey after SwiftUI has had a beat to create
    /// the window works around it.
    private func bringWindowToFront(matching identifierSubstring: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.activate(ignoringOtherApps: true)
            let window = NSApp.windows.first {
                $0.identifier?.rawValue.localizedCaseInsensitiveContains(identifierSubstring) == true
            } ?? NSApp.windows.first { $0.canBecomeKey }
            window?.makeKeyAndOrderFront(nil)
            window?.orderFrontRegardless()
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
