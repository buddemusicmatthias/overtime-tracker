import Foundation
import GRDB
import os

private let logger = Logger(subsystem: "com.overtime-tracker", category: "DB")

final class DatabaseManager {
    static let shared = DatabaseManager()

    let dbPool: DatabasePool?
    let isConnected: Bool

    private static let dbPath: String = {
        NSHomeDirectory() + "/.overtime-tracker/overtime.db"
    }()

    private init() {
        let path = Self.dbPath

        guard FileManager.default.fileExists(atPath: path) else {
            logger.warning("Database not found at \(path, privacy: .public)")
            dbPool = nil
            isConnected = false
            return
        }

        do {
            var config = Configuration()
            // Not using readonly: SQLite WAL mode needs write access to create -wal/-shm files,
            // even for read-only usage. The app only reads; Python daemon writes.
            config.prepareDatabase { db in
                try db.execute(sql: "PRAGMA busy_timeout = 5000")
            }

            let pool = try DatabasePool(path: path, configuration: config)
            dbPool = pool
            isConnected = true
            logger.debug("Connected to \(path, privacy: .public)")
        } catch {
            logger.error("Error opening database: \(error)")
            dbPool = nil
            isConnected = false
        }
    }

    static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    static var dbPathString: String { dbPath }

    // MARK: - Settings Write

    func saveSettings(_ settings: TrackerSettings) async throws {
        guard let pool = dbPool else { return }
        try await pool.write { db in
            try settings.update(db)
        }
    }

    // MARK: - Data Management

    func deleteAllData() async throws {
        guard let pool = dbPool else { return }
        try await pool.write { db in
            try db.execute(sql: "DELETE FROM activity_log")
            try db.execute(sql: "DELETE FROM daily_summary")
            try db.execute(sql: "DELETE FROM app_daily_summary")
        }
    }
}
