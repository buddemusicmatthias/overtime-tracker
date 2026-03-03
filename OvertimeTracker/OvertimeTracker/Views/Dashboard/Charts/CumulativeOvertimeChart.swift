import SwiftUI
import Charts

/// Area + line chart showing cumulative overtime over time
struct CumulativeOvertimeChart: View {
    let data: [(date: String, cumulative: Double)]

    var body: some View {
        Chart(data, id: \.date) { item in
            AreaMark(
                x: .value("Tag", item.date),
                y: .value("Kumulative OT", item.cumulative)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.otRed.opacity(0.3), Color.otRed.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Tag", item.date),
                y: .value("Kumulative OT", item.cumulative)
            )
            .foregroundStyle(Color.otRed)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 8)) { value in
                AxisValueLabel {
                    if let dateStr = value.as(String.self) {
                        Text(Formatters.shortDate(dateStr))
                            .font(.caption2)
                    }
                }
            }
        }
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
}
