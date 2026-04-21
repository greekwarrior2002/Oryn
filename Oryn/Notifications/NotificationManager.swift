import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        Task { await refreshStatus() }
    }

    // MARK: - Permission

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            if granted { try? await UNUserNotificationCenter.current().setBadgeCount(0) }
        } catch {
            // User can enable later from Settings — no crash, no log noise
        }
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Schedule

    /// Replaces all pending Oryn notifications based on current task state.
    /// Call after any scheduling change (add, complete, redistribute, etc.).
    func rescheduleNotifications(for tasks: [OrynTask]) {
        guard authorizationStatus == .authorized else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)

        let today = Calendar.current.startOfDay(for: Date())
        let todayTasks = tasks.filter { t in
            guard !t.isCompleted, !t.isInBacklog, let d = t.scheduledDate else { return false }
            return Calendar.current.isDate(d, inSameDayAs: today)
        }
        let overdueTasks = tasks.filter { $0.isOverdue && !$0.isCompleted && !$0.isInBacklog }

        if NotificationSettings.notifyDueToday, !todayTasks.isEmpty {
            schedule(briefing: todayTasks.count)
        }
        if NotificationSettings.notifyOverdue, !overdueTasks.isEmpty {
            schedule(overdue: overdueTasks.count)
        }
        if NotificationSettings.notifyEvening {
            let remaining = todayTasks.filter { !$0.isCompleted }
            if !remaining.isEmpty { schedule(evening: remaining.count) }
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Private builders

    private var allIdentifiers: [String] {
        ["oryn.briefing", "oryn.overdue", "oryn.evening"]
    }

    private func schedule(briefing count: Int) {
        var comps = DateComponents()
        comps.hour   = NotificationSettings.reminderHour
        comps.minute = 0
        let trigger  = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let content  = UNMutableNotificationContent()
        content.title = "Good morning"
        content.body  = "You have \(count) task\(count == 1 ? "" : "s") scheduled for today."
        content.sound = .default
        let req = UNNotificationRequest(identifier: "oryn.briefing", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func schedule(overdue count: Int) {
        var comps = DateComponents()
        comps.hour   = 11
        comps.minute = 0
        let trigger  = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let content  = UNMutableNotificationContent()
        content.title = "Overdue tasks"
        content.body  = "\(count) task\(count == 1 ? " is" : "s are") overdue. Tap to review."
        content.sound = .default
        let req = UNNotificationRequest(identifier: "oryn.overdue", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func schedule(evening count: Int) {
        var comps = DateComponents()
        comps.hour   = 18
        comps.minute = 0
        let trigger  = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let content  = UNMutableNotificationContent()
        content.title = "Still on your list"
        content.body  = "\(count) task\(count == 1 ? "" : "s") remaining today."
        content.sound = .default
        let req = UNNotificationRequest(identifier: "oryn.evening", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
}

// MARK: - Settings

enum NotificationSettings {
    static var notifyDueToday: Bool {
        get { UserDefaults.standard.object(forKey: "notify.dueToday") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notify.dueToday") }
    }
    static var notifyOverdue: Bool {
        get { UserDefaults.standard.object(forKey: "notify.overdue") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notify.overdue") }
    }
    static var notifyEvening: Bool {
        get { UserDefaults.standard.object(forKey: "notify.evening") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notify.evening") }
    }
    // Default morning reminder hour is 9 AM
    static var reminderHour: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: "notify.reminderHour")
            return stored == 0 ? 9 : stored
        }
        set { UserDefaults.standard.set(newValue, forKey: "notify.reminderHour") }
    }
}
