import Foundation
import GRDB
import Observation

@Observable
final class PopoverViewModel {
    var todaySummary: DailySummary?
    var weekSummaries: [DailySummary] = []
    var topApps: [AppDailySummary] = []
    var isConnected: Bool = false
    var isDaemonRunning: Bool = true
    var onOpenDashboard: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private var pollingTask: Task<Void, Never>?

    var statusBarText: String {
        guard let summary = todaySummary else { return "—:— OT" }
        return Formatters.formatMinutes(summary.overtimeMinutes) + " OT"
    }

    var overtimeText: String {
        guard let summary = todaySummary else { return "—:—" }
        return Formatters.formatMinutes(summary.overtimeMinutes)
    }

    var activeText: String {
        guard let summary = todaySummary else { return "—:—" }
        return Formatters.formatMinutes(summary.totalActiveMinutes)
    }

    var idleText: String {
        guard let summary = todaySummary else { return "—:—" }
        return Formatters.formatMinutes(summary.totalIdleMinutes)
    }

    var firstActivityText: String {
        guard let time = todaySummary?.firstActivity else { return "—:—" }
        return Formatters.formatTime(time)
    }

    var lastActivityText: String {
        guard let time = todaySummary?.lastActivity else { return "—:—" }
        return Formatters.formatTime(time)
    }

    var weekActiveMinutes: Double {
        weekSummaries.reduce(0) { $0 + $1.totalActiveMinutes }
    }

    var weekOvertimeMinutes: Double {
        weekSummaries.reduce(0) { $0 + $1.overtimeMinutes }
    }

    var weekActiveText: String {
        Formatters.formatMinutes(weekActiveMinutes)
    }

    var weekOvertimeText: String {
        Formatters.formatMinutes(weekOvertimeMinutes)
    }

    var calendarWeekText: String {
        let cal = Calendar(identifier: .iso8601)
        let week = cal.component(.weekOfYear, from: Date())
        return "KW \(week)"
    }

    var todayHeaderText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE, dd.MM."
        let dayString = formatter.string(from: Date())
        return "HEUTE — \(dayString.prefix(1).uppercased() + dayString.dropFirst())"
    }

    func startObserving() {
        guard let pool = DatabaseManager.shared.dbPool else {
            isConnected = false
            print("[Popover] No database connection")
            return
        }

        isConnected = true
        isDaemonRunning = LaunchAgentManager.isDaemonRunning()

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let today = DatabaseManager.todayString()
                let (weekStart, weekEnd) = Self.currentWeekRange()

                do {
                    let (summary, week, apps) = try await pool.read { db in
                        let summary = try DailySummary
                            .filter(Column("date") == today)
                            .fetchOne(db)
                        let week = try DailySummary
                            .filter(Column("date") >= weekStart && Column("date") <= weekEnd)
                            .order(Column("date"))
                            .fetchAll(db)
                        let apps = try AppDailySummary
                            .filter(Column("date") == today)
                            .order(Column("active_minutes").desc)
                            .limit(5)
                            .fetchAll(db)
                        return (summary, week, apps)
                    }
                    self.todaySummary = summary
                    self.weekSummaries = week
                    self.topApps = apps
                } catch {
                    print("[Popover] Poll error: \(error)")
                }

                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stopObserving() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refreshDaemonStatus() {
        isDaemonRunning = LaunchAgentManager.isDaemonRunning()
    }

    // MARK: - Week Range

    static func currentWeekRange() -> (start: String, end: String) {
        Formatters.weekRange()
    }
}
