import Foundation

struct ProviderStatus: Identifiable {
    let source: UsageSource
    var metrics: [UsageMetric] = []
    var lastError: String?
    var lastUpdated: Date?
    var isEnabled: Bool

    var id: String { source.providerId }

    /// The single number shown in the menu bar for this provider: the worst (highest) percent.
    var worstPercent: Double? {
        metrics.compactMap(\.percent).max()
    }
}

@MainActor
final class UsageMonitor: ObservableObject {
    @Published private(set) var statuses: [ProviderStatus]
    var pollIntervalSeconds: Double {
        didSet { restart() }
    }

    private let sources: [UsageSource]
    private var loopTask: Task<Void, Never>?

    init(sources: [UsageSource], pollIntervalSeconds: Double = 600) {
        self.sources = sources
        self.pollIntervalSeconds = pollIntervalSeconds
        self.statuses = sources.map {
            ProviderStatus(source: $0, isEnabled: ProviderConfigStore.isEnabled(providerId: $0.providerId))
        }
    }

    /// Highest percent across every enabled provider, for the menu bar label.
    var overallWorstPercent: Double? {
        statuses.filter(\.isEnabled).compactMap(\.worstPercent).max()
    }

    func setEnabled(_ enabled: Bool, providerId: String) {
        ProviderConfigStore.setEnabled(enabled, providerId: providerId)
        guard let index = statuses.firstIndex(where: { $0.id == providerId }) else { return }
        statuses[index].isEnabled = enabled
        if enabled {
            Task { await refresh(providerId: providerId) }
        }
    }

    func start() {
        restart()
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            for status in statuses where status.isEnabled {
                group.addTask { await self.refresh(providerId: status.id) }
            }
        }
    }

    func refresh(providerId: String) async {
        guard let index = statuses.firstIndex(where: { $0.id == providerId }) else { return }
        let source = statuses[index].source
        let config = ProviderConfigStore.load(source: source)
        do {
            let metrics = try await source.fetchMetrics(config: config)
            statuses[index].metrics = metrics
            statuses[index].lastError = nil
            statuses[index].lastUpdated = Date()
        } catch {
            statuses[index].lastError = error.localizedDescription
            statuses[index].lastUpdated = Date()
        }
    }

    private func restart() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshAll()
                try? await Task.sleep(for: .seconds(self.pollIntervalSeconds))
            }
        }
    }
}
