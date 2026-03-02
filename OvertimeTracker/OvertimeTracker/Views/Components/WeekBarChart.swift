import SwiftUI

struct WeekBarChart: View {
    let summaries: [DailySummary]

    private static let dayLabels = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    private static let maxBarHeight: CGFloat = 70

    var body: some View {
        let lookup = Dictionary(uniqueKeysWithValues: summaries.map { ($0.date, $0) })
        let dates = weekDates()
        let maxMinutes = summaries.map(\.totalActiveMinutes).max() ?? 1
        let todayStr = DatabaseManager.todayString()

        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                let summary = lookup[date]
                let isToday = date == todayStr
                let isWeekend = index >= 5

                VStack(spacing: 4) {
                    bar(
                        active: summary?.totalActiveMinutes ?? 0,
                        overtime: summary?.overtimeMinutes ?? 0,
                        maxMinutes: maxMinutes,
                        isWeekend: isWeekend,
                        isEmpty: summary == nil
                    )
                    Text(Self.dayLabels[index])
                        .font(.system(size: 10))
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundStyle(isToday ? .white : Color(.systemGray))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: Self.maxBarHeight + 20)
    }

    @ViewBuilder
    private func bar(
        active: Double,
        overtime: Double,
        maxMinutes: Double,
        isWeekend: Bool,
        isEmpty: Bool
    ) -> some View {
        if isEmpty {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray).opacity(0.3))
                .frame(height: 2)
        } else {
            let regular = max(active - overtime, 0)
            let scale = active > 0 ? Self.maxBarHeight / max(maxMinutes, 1) : 0
            let regularHeight = max(regular * scale, 0)
            let overtimeHeight = max(overtime * scale, 0)

            VStack(spacing: 1) {
                if overtimeHeight > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.otRed)
                        .frame(height: overtimeHeight)
                }
                if regularHeight > 0 && !isWeekend {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.otBlue)
                        .frame(height: regularHeight)
                } else if regularHeight > 0 && isWeekend {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.otRed)
                        .frame(height: regularHeight)
                }
            }
        }
    }

    private func weekDates() -> [String] {
        let (start, _) = PopoverViewModel.currentWeekRange()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let monday = fmt.date(from: start) else { return [] }
        return (0..<7).map { offset in
            fmt.string(from: Calendar(identifier: .iso8601).date(byAdding: .day, value: offset, to: monday)!)
        }
    }
}
