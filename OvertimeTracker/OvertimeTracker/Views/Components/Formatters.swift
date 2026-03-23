import Foundation

/// Pure formatting utilities — nonisolated so they can be called from any context
nonisolated enum Formatters {
    /// Formats minutes as "H:MM" (e.g. 90 → "1:30", -30 → "-0:30")
    static func formatMinutes(_ minutes: Double) -> String {
        let total = Int(minutes)
        let h = total / 60
        let m = abs(total) % 60
        return String(format: "%d:%02d", h, m)
    }

    /// Extracts HH:MM from a time string ("09:15:23") or ISO timestamp ("2026-03-02T09:15:23")
    static func formatTime(_ timeString: String) -> String {
        if timeString.count >= 16 {
            // ISO timestamp: extract HH:MM after the "T"
            let startIndex = timeString.index(timeString.startIndex, offsetBy: 11)
            let endIndex = timeString.index(startIndex, offsetBy: 5)
            return String(timeString[startIndex..<endIndex])
        }
        // HH:MM:SS or HH:MM: return first 5 characters
        return String(timeString.prefix(5))
    }

    /// Formats minutes as "Xh YYm" (e.g. 90 → "1h 30m")
    static func formatHoursMinutes(_ minutes: Double) -> String {
        let total = Int(abs(minutes))
        let h = total / 60
        let m = total % 60
        let sign = minutes < 0 ? "-" : ""
        if h > 0 {
            return "\(sign)\(h)h \(m)m"
        }
        return "\(sign)\(m)m"
    }

    /// Returns ISO week range (Monday–Sunday) for a given date
    static func weekRange(for date: Date = Date()) -> (start: String, end: String) {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale(identifier: "de_DE")
        let weekday = cal.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: date)!
        let sunday = cal.date(byAdding: .day, value: 6, to: monday)!
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return (fmt.string(from: monday), fmt.string(from: sunday))
    }

    /// Returns month range (1st–last day) for a given date
    static func monthRange(for date: Date = Date()) -> (start: String, end: String) {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale(identifier: "de_DE")
        let comps = cal.dateComponents([.year, .month], from: date)
        let firstDay = cal.date(from: comps)!
        let lastDay = cal.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay)!
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return (fmt.string(from: firstDay), fmt.string(from: lastDay))
    }

    /// "dd.MM." format for short date labels
    static func shortDate(_ isoDate: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: isoDate) else { return isoDate }
        let display = DateFormatter()
        display.dateFormat = "dd.MM."
        return display.string(from: date)
    }

    /// German weekday abbreviation from ISO date string
    static func weekdayShort(_ isoDate: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: isoDate) else { return "" }
        let display = DateFormatter()
        display.locale = Locale(identifier: "de_DE")
        display.dateFormat = "EE"
        return display.string(from: date)
    }
}
