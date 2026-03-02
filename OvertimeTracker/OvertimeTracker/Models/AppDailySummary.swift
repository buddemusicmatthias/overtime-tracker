import Foundation
import GRDB

struct AppDailySummary: Decodable, FetchableRecord, TableRecord, Sendable {
    static let databaseTableName = "app_daily_summary"

    let date: String
    let appName: String
    let activeMinutes: Double
    let regularMinutes: Double
    let overtimeMinutes: Double

    enum CodingKeys: String, CodingKey {
        case date
        case appName = "app_name"
        case activeMinutes = "active_minutes"
        case regularMinutes = "regular_minutes"
        case overtimeMinutes = "overtime_minutes"
    }
}
