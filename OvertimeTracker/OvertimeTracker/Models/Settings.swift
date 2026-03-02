import Foundation
import GRDB

struct TrackerSettings: Decodable, FetchableRecord, TableRecord, Sendable {
    static let databaseTableName = "settings"

    let id: Int
    let coreStartHour: Int
    let coreEndHour: Int
    let workDays: String
    let idleTimeoutSeconds: Int

    enum CodingKeys: String, CodingKey {
        case id
        case coreStartHour = "core_start_hour"
        case coreEndHour = "core_end_hour"
        case workDays = "work_days"
        case idleTimeoutSeconds = "idle_timeout_seconds"
    }
}
