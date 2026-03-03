import Foundation
import GRDB

struct TrackerSettings: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "settings"

    var id: Int = 1
    var coreStartHour: Int = 9
    var coreStartMinute: Int = 0
    var coreEndHour: Int = 18
    var coreEndMinute: Int = 0
    var workDays: String = "0,1,2,3"
    var idleTimeoutSeconds: Int = 600

    enum CodingKeys: String, CodingKey {
        case id
        case coreStartHour = "core_start_hour"
        case coreStartMinute = "core_start_minute"
        case coreEndHour = "core_end_hour"
        case coreEndMinute = "core_end_minute"
        case workDays = "work_days"
        case idleTimeoutSeconds = "idle_timeout_seconds"
    }

    // MARK: - Computed Helpers

    /// Work days as array of ints (0=Mon, 6=Sun)
    var workDayInts: [Int] {
        get {
            workDays.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        set {
            workDays = newValue.sorted().map(String.init).joined(separator: ",")
        }
    }

    /// Idle timeout in whole minutes (get/set)
    var idleTimeoutMinutes: Int {
        get { idleTimeoutSeconds / 60 }
        set { idleTimeoutSeconds = newValue * 60 }
    }

    /// Core start as total minutes since midnight (get/set)
    var coreStartTotalMinutes: Int {
        get { coreStartHour * 60 + coreStartMinute }
        set {
            coreStartHour = newValue / 60
            coreStartMinute = newValue % 60
        }
    }

    /// Core end as total minutes since midnight (get/set)
    var coreEndTotalMinutes: Int {
        get { coreEndHour * 60 + coreEndMinute }
        set {
            coreEndHour = newValue / 60
            coreEndMinute = newValue % 60
        }
    }
}
