import Foundation
import GRDB
import Observation

/// Aggregated app data across a date range
struct AppRangeSummary: Identifiable, Sendable {
    var id: String { appName }
    let appName: String
    let totalActiveMinutes: Double
    let regularMinutes: Double
    let overtimeMinutes: Double
}

@Observable
final class DashboardViewModel {
    // MARK: - Today
    var todaySummary: DailySummary?
    var todayApps: [AppDailySummary] = []

    // MARK: - Week
    var weekSummaries: [DailySummary] = []
    var weekApps: [AppRangeSummary] = []

    // MARK: - Month
    var selectedMonth: Date = Date()
    var monthSummaries: [DailySummary] = []
    var monthApps: [AppRangeSummary] = []

    // MARK: - Export
    var exportStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    var exportEnd: Date = Date()
    var exportSummaries: [DailySummary] = []

    private var todayTask: Task<Void, Never>?
    private var todayAppsTask: Task<Void, Never>?
    private var weekTask: Task<Void, Never>?
    private var weekAppsTask: Task<Void, Never>?
    private var monthTask: Task<Void, Never>?
    private var monthAppsTask: Task<Void, Never>?

    // MARK: - Computed

    var weekTotalActive: Double {
        weekSummaries.reduce(0) { $0 + $1.totalActiveMinutes }
    }

    var weekTotalOvertime: Double {
        weekSummaries.reduce(0) { $0 + $1.overtimeMinutes }
    }

    var monthTotalActive: Double {
        monthSummaries.reduce(0) { $0 + $1.totalActiveMinutes }
    }

    var monthTotalOvertime: Double {
        monthSummaries.reduce(0) { $0 + $1.overtimeMinutes }
    }

    var monthWorkDays: Int {
        monthSummaries.filter { $0.totalActiveMinutes > 0 }.count
    }

    var cumulativeOvertime: [(date: String, cumulative: Double)] {
        var cum = 0.0
        return monthSummaries.map { s in
            cum += s.overtimeMinutes
            return (date: s.date, cumulative: cum)
        }
    }

    // MARK: - Lifecycle

    func startObserving() {
        guard let pool = DatabaseManager.shared.dbPool else { return }

        observeToday(pool: pool)
        observeWeek(pool: pool)
        observeMonth(pool: pool)
    }

    func stopObserving() {
        todayTask?.cancel()
        todayAppsTask?.cancel()
        weekTask?.cancel()
        weekAppsTask?.cancel()
        monthTask?.cancel()
        monthAppsTask?.cancel()
    }

    func reloadMonth() {
        guard let pool = DatabaseManager.shared.dbPool else { return }
        monthTask?.cancel()
        monthAppsTask?.cancel()
        observeMonth(pool: pool)
    }

    func loadExportData() {
        guard let pool = DatabaseManager.shared.dbPool else { return }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let start = fmt.string(from: exportStart)
        let end = fmt.string(from: exportEnd)

        Task { @MainActor [weak self] in
            do {
                let summaries = try await pool.read { db in
                    try DailySummary
                        .filter(Column("date") >= start && Column("date") <= end)
                        .order(Column("date"))
                        .fetchAll(db)
                }
                self?.exportSummaries = summaries
            } catch {
                print("[Dashboard] Export load error: \(error)")
            }
        }
    }

    // MARK: - CSV Export

    func generateCSV() -> String {
        var lines = ["Datum;Wochentag;Aktiv (min);Idle (min);Overtime (min);Erster;Letzter;Kategorie"]
        let dayNames = ["", "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
        for s in exportSummaries {
            let day = s.dayOfWeek >= 1 && s.dayOfWeek <= 7 ? dayNames[s.dayOfWeek] : "?"
            let first = s.firstActivity ?? ""
            let last = s.lastActivity ?? ""
            lines.append("\(s.date);\(day);\(Int(s.totalActiveMinutes));\(Int(s.totalIdleMinutes));\(Int(s.overtimeMinutes));\(first);\(last);\(s.workCategory)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private Observations

    private func observeToday(pool: DatabasePool) {
        let today = DatabaseManager.todayString()

        todayTask = Task { [weak self] in
            do {
                let observation = ValueObservation.tracking { db in
                    try DailySummary.filter(Column("date") == today).fetchOne(db)
                }
                for try await summary in observation.values(in: pool) {
                    self?.todaySummary = summary
                }
            } catch {
                if !Task.isCancelled { print("[Dashboard] Today error: \(error)") }
            }
        }

        todayAppsTask = Task { [weak self] in
            do {
                let observation = ValueObservation.tracking { db in
                    try AppDailySummary
                        .filter(Column("date") == today)
                        .order(Column("active_minutes").desc)
                        .limit(8)
                        .fetchAll(db)
                }
                for try await apps in observation.values(in: pool) {
                    self?.todayApps = apps
                }
            } catch {
                if !Task.isCancelled { print("[Dashboard] Today apps error: \(error)") }
            }
        }
    }

    private func observeWeek(pool: DatabasePool) {
        let (weekStart, weekEnd) = Formatters.weekRange()

        weekTask = Task { [weak self] in
            do {
                let observation = ValueObservation.tracking { db in
                    try DailySummary
                        .filter(Column("date") >= weekStart && Column("date") <= weekEnd)
                        .order(Column("date"))
                        .fetchAll(db)
                }
                for try await summaries in observation.values(in: pool) {
                    self?.weekSummaries = summaries
                }
            } catch {
                if !Task.isCancelled { print("[Dashboard] Week error: \(error)") }
            }
        }

        weekAppsTask = Task { [weak self] in
            do {
                let observation = ValueObservation.tracking { db in
                    try self?.fetchAppRangeSummaries(db: db, start: weekStart, end: weekEnd) ?? []
                }
                for try await apps in observation.values(in: pool) {
                    self?.weekApps = apps
                }
            } catch {
                if !Task.isCancelled { print("[Dashboard] Week apps error: \(error)") }
            }
        }
    }

    private func observeMonth(pool: DatabasePool) {
        let (monthStart, monthEnd) = Formatters.monthRange(for: selectedMonth)

        monthTask = Task { [weak self] in
            do {
                let observation = ValueObservation.tracking { db in
                    try DailySummary
                        .filter(Column("date") >= monthStart && Column("date") <= monthEnd)
                        .order(Column("date"))
                        .fetchAll(db)
                }
                for try await summaries in observation.values(in: pool) {
                    self?.monthSummaries = summaries
                }
            } catch {
                if !Task.isCancelled { print("[Dashboard] Month error: \(error)") }
            }
        }

        monthAppsTask = Task { [weak self] in
            do {
                let observation = ValueObservation.tracking { db in
                    try self?.fetchAppRangeSummaries(db: db, start: monthStart, end: monthEnd) ?? []
                }
                for try await apps in observation.values(in: pool) {
                    self?.monthApps = apps
                }
            } catch {
                if !Task.isCancelled { print("[Dashboard] Month apps error: \(error)") }
            }
        }
    }

    /// Aggregates app_daily_summary rows across a date range using raw SQL
    private func fetchAppRangeSummaries(db: Database, start: String, end: String) throws -> [AppRangeSummary] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT app_name,
                   SUM(active_minutes) AS total_active,
                   SUM(regular_minutes) AS total_regular,
                   SUM(overtime_minutes) AS total_overtime
            FROM app_daily_summary
            WHERE date >= ? AND date <= ?
            GROUP BY app_name
            ORDER BY total_active DESC
            LIMIT 8
            """, arguments: [start, end])

        return rows.map { row in
            AppRangeSummary(
                appName: row["app_name"],
                totalActiveMinutes: row["total_active"],
                regularMinutes: row["total_regular"],
                overtimeMinutes: row["total_overtime"]
            )
        }
    }
}
