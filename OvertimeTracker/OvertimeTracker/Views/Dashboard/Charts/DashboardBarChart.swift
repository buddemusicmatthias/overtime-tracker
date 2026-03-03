import SwiftUI
import Charts

/// Stacked bar chart: regular (blue, bottom) + overtime (red, top) per day
struct DashboardBarChart: View {
    let summaries: [DailySummary]

    var body: some View {
        Chart(chartData, id: \.id) { item in
            BarMark(
                x: .value("Tag", item.label),
                y: .value("Minuten", item.minutes)
            )
            .foregroundStyle(by: .value("Typ", item.type))
            .cornerRadius(3)
        }
        .chartForegroundStyleScale([
            "Regulär": Color.otBlue,
            "Overtime": Color.otRed
        ])
        .chartLegend(position: .top, alignment: .leading)
        .chartYAxisLabel("Stunden")
        .chartYAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text(Formatters.formatMinutes(minutes))
                    }
                }
            }
        }
    }

    private struct ChartItem {
        let id: String
        let label: String
        let type: String
        let minutes: Double
    }

    private var chartData: [ChartItem] {
        summaries.flatMap { s in
            let label = Formatters.weekdayShort(s.date) + "\n" + Formatters.shortDate(s.date)
            let regular = max(s.totalActiveMinutes - s.overtimeMinutes, 0)
            return [
                ChartItem(id: s.date + "-reg", label: label, type: "Regulär", minutes: regular),
                ChartItem(id: s.date + "-ot", label: label, type: "Overtime", minutes: s.overtimeMinutes)
            ]
        }
    }
}
