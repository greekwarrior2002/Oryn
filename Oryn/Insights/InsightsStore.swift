import SwiftUI
import SwiftData

@MainActor
final class InsightsStore: ObservableObject {
    private let context: ModelContext
    private let aiService: ClaudeInsightsService = ClaudeInsightsService()

    @Published var records: [ProductivityRecord] = []
    @Published var insights: [Insight] = []
    @Published var isGeneratingAI = false
    @Published var aiError: String? = nil

    init(context: ModelContext) {
        self.context = context
        fetchRecords()
        refreshInsights()
    }

    // Called immediately after a task is marked complete
    func recordCompletion(task: OrynTask, readiness: ReadinessScore) {
        let record = ProductivityRecord(
            task: task,
            sleepHours: readiness.sleepHours,
            readinessScore: readiness.value
        )
        context.insert(record)
        try? context.save()
        fetchRecords()
        refreshInsights()

        // Trigger AI refresh when we first unlock insights, then every 5 completions
        let count = records.count
        if aiService.isConfigured && (count == InsightsEngine.minimumCompletions || count % 5 == 0) {
            Task { await refreshAIInsights() }
        }
    }

    // MARK: - Computed State

    var hasEnoughData: Bool {
        InsightsEngine.canGenerateInsights(from: records)
    }

    var daysTracked: Int {
        Set(records.map { Calendar.current.startOfDay(for: $0.completedAt) }).count
    }

    var totalCompletions: Int { records.count }

    var progressToFirstInsight: Double {
        min(Double(records.count) / Double(InsightsEngine.minimumCompletions), 1.0)
    }

    var completionsNeeded: Int {
        max(0, InsightsEngine.minimumCompletions - records.count)
    }

    // MARK: - AI Insights

    func refreshAIInsights() async {
        guard aiService.isConfigured, hasEnoughData else { return }
        isGeneratingAI = true
        aiError = nil
        let summary = InsightsEngine.buildSummary(from: records)
        do {
            let aiInsights = try await aiService.generateInsights(from: summary)
            if !aiInsights.isEmpty {
                insights = aiInsights
            }
        } catch AIInsightsError.notConfigured {
            // Expected when no key is set — silently fall back
        } catch {
            aiError = error.localizedDescription
        }
        isGeneratingAI = false
    }

    // MARK: - Private

    func fetchRecords() {
        let descriptor = FetchDescriptor<ProductivityRecord>(
            sortBy: [SortDescriptor(\.completedAt, order: .forward)]
        )
        records = (try? context.fetch(descriptor)) ?? []
    }

    func refreshInsights() {
        // Snapshot on main actor first — @Model objects must not cross actor boundaries.
        let snapshots = records.map(ProductivitySnapshot.init)
        // Outer Task inherits @MainActor context so `self` assignment is safe.
        // Inner detached task runs the CPU work off the main thread.
        Task { [weak self] in
            let generated = await Task.detached(priority: .utility) {
                InsightsEngine.generateInsights(from: snapshots)
            }.value
            self?.insights = generated
        }
    }
}
