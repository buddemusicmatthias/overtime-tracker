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
@MainActor
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
    var exportAppData: [AppDailySummary] = []

    private var pollingTask: Task<Void, Never>?

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

    // MARK: - Export Computed

    var exportTotalRegular: Double {
        exportAppData.reduce(0) { $0 + $1.regularMinutes }
    }

    var exportTotalOvertime: Double {
        exportAppData.reduce(0) { $0 + $1.overtimeMinutes }
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

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                await self.pollAll(pool: pool)
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stopObserving() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func reloadMonth() {
        guard let pool = DatabaseManager.shared.dbPool else { return }
        Task { [weak self] in
            await self?.pollMonth(pool: pool)
        }
    }

    func loadExportData() {
        guard let pool = DatabaseManager.shared.dbPool else { return }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let start = fmt.string(from: exportStart)
        let end = fmt.string(from: exportEnd)

        Task { @MainActor [weak self] in
            do {
                let appData = try await pool.read { db in
                    try AppDailySummary
                        .filter(Column("date") >= start && Column("date") <= end)
                        .order(Column("date"), Column("app_name"))
                        .fetchAll(db)
                }
                self?.exportAppData = appData
            } catch {
                print("[Dashboard] Export load error: \(error)")
            }
        }
    }

    // MARK: - CSV Export

    func generateCSV() -> String {
        var lines = ["date;app;time;category"]
        for row in exportAppData {
            if row.regularMinutes > 0 {
                lines.append("\(row.date);\(row.appName);\(Int(row.regularMinutes));regular")
            }
            if row.overtimeMinutes > 0 {
                lines.append("\(row.date);\(row.appName);\(Int(row.overtimeMinutes));overtime")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Polling

    private func pollAll(pool: DatabasePool) async {
        let today = DatabaseManager.todayString()
        let (weekStart, weekEnd) = Formatters.weekRange()
        let (monthStart, monthEnd) = Formatters.monthRange(for: selectedMonth)

        do {
            let result = try await pool.read { [self] db in
                let todaySummary = try DailySummary
                    .filter(Column("date") == today)
                    .fetchOne(db)
                let todayApps = try AppDailySummary
                    .filter(Column("date") == today)
                    .order(Column("active_minutes").desc)
                    .limit(8)
                    .fetchAll(db)
                let weekSummaries = try DailySummary
                    .filter(Column("date") >= weekStart && Column("date") <= weekEnd)
                    .order(Column("date"))
                    .fetchAll(db)
                let weekApps = try self.fetchAppRangeSummaries(db: db, start: weekStart, end: weekEnd)
                let monthSummaries = try DailySummary
                    .filter(Column("date") >= monthStart && Column("date") <= monthEnd)
                    .order(Column("date"))
                    .fetchAll(db)
                let monthApps = try self.fetchAppRangeSummaries(db: db, start: monthStart, end: monthEnd)

                return (todaySummary, todayApps, weekSummaries, weekApps, monthSummaries, monthApps)
            }

            self.todaySummary = result.0
            self.todayApps = result.1
            self.weekSummaries = result.2
            self.weekApps = result.3
            self.monthSummaries = result.4
            self.monthApps = result.5
        } catch {
            if !Task.isCancelled { print("[Dashboard] Poll error: \(error)") }
        }
    }

    private func pollMonth(pool: DatabasePool) async {
        let (monthStart, monthEnd) = Formatters.monthRange(for: selectedMonth)

        do {
            let (summaries, apps) = try await pool.read { [self] db in
                let summaries = try DailySummary
                    .filter(Column("date") >= monthStart && Column("date") <= monthEnd)
                    .order(Column("date"))
                    .fetchAll(db)
                let apps = try self.fetchAppRangeSummaries(db: db, start: monthStart, end: monthEnd)
                return (summaries, apps)
            }
            self.monthSummaries = summaries
            self.monthApps = apps
        } catch {
            if !Task.isCancelled { print("[Dashboard] Month poll error: \(error)") }
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
