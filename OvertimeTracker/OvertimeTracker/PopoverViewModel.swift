import Foundation
import GRDB
import Observation

@Observable
final class PopoverViewModel {
    var todaySummary: DailySummary?
    var topApps: [AppDailySummary] = []
    var isConnected: Bool = false

    private var summaryObservationTask: Task<Void, Never>?
    private var appsObservationTask: Task<Void, Never>?

    var statusBarText: String {
        guard let summary = todaySummary else { return "—:— OT" }
        return Self.formatMinutes(summary.overtimeMinutes) + " OT"
    }

    var overtimeText: String {
        guard let summary = todaySummary else { return "—:—" }
        return Self.formatMinutes(summary.overtimeMinutes)
    }

    var activeText: String {
        guard let summary = todaySummary else { return "—:—" }
        return Self.formatMinutes(summary.totalActiveMinutes)
    }

    var idleText: String {
        guard let summary = todaySummary else { return "—:—" }
        return Self.formatMinutes(summary.totalIdleMinutes)
    }

    var firstActivityText: String {
        guard let time = todaySummary?.firstActivity else { return "—:—" }
        return Self.formatTime(time)
    }

    var lastActivityText: String {
        guard let time = todaySummary?.lastActivity else { return "—:—" }
        return Self.formatTime(time)
    }

    var todayFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: Date())
    }

    func startObserving() {
        let db = DatabaseManager.shared
        guard let pool = db.dbPool else {
            isConnected = false
            print("[ViewModel] No database connection")
            return
        }

        isConnected = true
        let today = DatabaseManager.todayString()

        summaryObservationTask = Task { [weak self] in
            do {
                let observation = ValueObservation.tracking { db in
                    try DailySummary.filter(Column("date") == today).fetchOne(db)
                }
                for try await summary in observation.values(in: pool) {
                    self?.todaySummary = summary
                }
            } catch {
                print("[ViewModel] Summary observation error: \(error)")
            }
        }

        appsObservationTask = Task { [weak self] in
            do {
                let observation = ValueObservation.tracking { db in
                    try AppDailySummary
                        .filter(Column("date") == today)
                        .order(Column("active_minutes").desc)
                        .limit(5)
                        .fetchAll(db)
                }
                for try await apps in observation.values(in: pool) {
                    self?.topApps = apps
                }
            } catch {
                print("[ViewModel] Apps observation error: \(error)")
            }
        }
    }

    func stopObserving() {
        summaryObservationTask?.cancel()
        appsObservationTask?.cancel()
    }

    // MARK: - Formatting

    private static func formatMinutes(_ minutes: Double) -> String {
        let total = Int(minutes)
        let h = total / 60
        let m = abs(total) % 60
        return String(format: "%d:%02d", h, m)
    }

    /// Extracts HH:MM from an ISO timestamp like "2026-03-02T09:15:23"
    private static func formatTime(_ isoTimestamp: String) -> String {
        // Timestamp format: "YYYY-MM-DDTHH:MM:SS"
        guard isoTimestamp.count >= 16 else { return isoTimestamp }
        let startIndex = isoTimestamp.index(isoTimestamp.startIndex, offsetBy: 11)
        let endIndex = isoTimestamp.index(startIndex, offsetBy: 5)
        return String(isoTimestamp[startIndex..<endIndex])
    }
}
