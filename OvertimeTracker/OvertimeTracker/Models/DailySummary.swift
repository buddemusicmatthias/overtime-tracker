import Foundation
import GRDB

struct DailySummary: Decodable, FetchableRecord, TableRecord, Sendable {
    static let databaseTableName = "daily_summary"

    let date: String
    let dayOfWeek: Int
    let totalActiveMinutes: Double
    let totalIdleMinutes: Double
    let overtimeMinutes: Double
    let firstActivity: String?
    let lastActivity: String?
    let workCategory: String

    enum CodingKeys: String, CodingKey {
        case date
        case dayOfWeek = "day_of_week"
        case totalActiveMinutes = "total_active_minutes"
        case totalIdleMinutes = "total_idle_minutes"
        case overtimeMinutes = "overtime_minutes"
        case firstActivity = "first_activity"
        case lastActivity = "last_activity"
        case workCategory = "work_category"
    }
}
