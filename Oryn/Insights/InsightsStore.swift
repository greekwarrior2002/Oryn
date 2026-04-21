import SwiftUI
import SwiftData

@MainActor
final class InsightsStore: ObservableObject {
    private let context: ModelContext
    @Published var records: [ProductivityRecord] = []
    @Published var insights: [Insight] = []

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

    // MARK: - Private

    private func fetchRecords() {
        let descriptor = FetchDescriptor<ProductivityRecord>(
            sortBy: [SortDescriptor(\.completedAt, order: .forward)]
        )
        records = (try? context.fetch(descriptor)) ?? []
    }

    private func refreshInsights() {
        insights = InsightsEngine.generateInsights(from: records)
    }
}
