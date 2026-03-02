import Foundation
import GRDB

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
            print("[DB] Database not found at \(path)")
            dbPool = nil
            isConnected = false
            return
        }

        do {
            var config = Configuration()
            config.readonly = true
            config.prepareDatabase { db in
                try db.execute(sql: "PRAGMA busy_timeout = 5000")
            }

            let pool = try DatabasePool(path: path, configuration: config)
            dbPool = pool
            isConnected = true
            print("[DB] Connected read-only to \(path)")
        } catch {
            print("[DB] Error opening database: \(error)")
            dbPool = nil
            isConnected = false
        }
    }

    static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
