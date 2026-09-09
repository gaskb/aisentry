import SwiftUI

@main
struct AiSentryApp: App {
    @StateObject private var monitor: UsageMonitor

    init() {
        let interval = UserDefaults.standard.object(forKey: "pollIntervalSeconds") as? Double ?? 600
        _monitor = StateObject(wrappedValue: UsageMonitor(
            sources: [
                ClaudeChatSource(),
                ClaudeAPISource(),
                GrokChatSource(),
                OpenAIAPISource(),
                GeminiChatSource(),
            ],
            pollIntervalSeconds: interval
        ))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(monitor: monitor)
        } label: {
            MenuBarLabel(monitor: monitor)
                .task { monitor.start() }
        }
        .menuBarExtraStyle(.menu)

        Window("Info su AiSentry", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(monitor: monitor)
        }
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var monitor: UsageMonitor

    var body: some View {
        if let percent = monitor.overallWorstPercent {
            Text("\(Int(percent.rounded()))%")
                .font(.system(size: 12, design: .monospaced))
        } else {
            Image(systemName: "gauge")
        }
    }
}
