import HealthKit
import Foundation

@MainActor
final class HealthKitManager: ObservableObject {

    // MARK: - Published State

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var readiness: ReadinessScore = .unavailable
    @Published var isLoading = false

    enum AuthorizationStatus {
        case notDetermined, authorized, denied, unavailable
    }

    // MARK: - Private

    private let store: HKHealthStore
    private var lastFetchDate: Date? = nil
    private static let fetchThrottleInterval: TimeInterval = 30 * 60  // 30 minutes

    init() {
        store = HKHealthStore()
    }

    // MARK: - Authorization

    /// Checks whether authorization has already been granted without prompting the user.
    /// If already authorized, fetches health data immediately.
    /// Call this on launch; call requestAuthorization() only from an explicit user action.
    func checkAuthorizationStatus() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .unavailable
            return
        }
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let stepType  = HKObjectType.quantityType(forIdentifier: .stepCount)!
        do {
            let status = try await store.statusForAuthorizationRequest(
                toShare: [], read: [sleepType, stepType]
            )
            if status == .unnecessary {
                // Permission already granted — fetch without prompting
                authorizationStatus = .authorized
                await fetchHealthData()
            }
            // .shouldRequest → leave as .notDetermined; user sees the CTA in the readiness card
        } catch {
            authorizationStatus = .unavailable
        }
    }

    /// Presents the system HealthKit permission sheet. Call only from an explicit user action.
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .unavailable
            return
        }

        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let stepType  = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let readTypes: Set<HKObjectType> = [sleepType, stepType]

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            authorizationStatus = .authorized
            await fetchHealthData()
        } catch {
            authorizationStatus = .denied
        }
    }

    // MARK: - Data Fetching

    func fetchHealthData(ignoreThrottle: Bool = false) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        // Avoid hammering HealthKit — skip if we fetched recently unless forced
        if !ignoreThrottle,
           let last = lastFetchDate,
           Date().timeIntervalSince(last) < Self.fetchThrottleInterval {
            return
        }

        isLoading = true
        defer { isLoading = false }

        async let sleep = fetchLastNightSleepHours()
        async let steps = fetchTodayStepCount()
        let (sleepHours, stepCount) = await (sleep, steps)
        readiness = ReadinessScore.compute(sleepHours: sleepHours, stepCount: stepCount)
        lastFetchDate = Date()
    }

    // MARK: - Sleep

    private func fetchLastNightSleepHours() async -> Double {
        let cal = Calendar.current
        let now = Date()

        guard
            let yesterday = cal.date(byAdding: .day, value: -1, to: now),
            let windowStart = cal.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday),
            let windowEnd   = cal.date(bySettingHour: 11, minute: 0, second: 0, of: now)
        else { return 0 }

        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart,
            end: windowEnd,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard error == nil,
                      let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]
                let totalSeconds = categorySamples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds / 3600.0)
            }
            store.execute(query)
        }
    }

    // MARK: - Steps

    private func fetchTodayStepCount() async -> Int {
        let stepType = HKQuantityType(.stepCount)
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                guard error == nil,
                      let sum = statistics?.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: Int(sum.doubleValue(for: .count())))
            }
            store.execute(query)
        }
    }
}
