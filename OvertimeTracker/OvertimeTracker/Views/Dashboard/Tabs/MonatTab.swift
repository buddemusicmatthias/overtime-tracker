import SwiftUI

struct MonatTab: View {
    var viewModel: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                monthSelector
                metricsRow
                barChartSection
                cumulativeChartSection
                appBreakdown
            }
            .padding(24)
        }
    }

    private var monthSelector: some View {
        HStack {
            Button {
                navigateMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            Text(monthLabel)
                .font(.headline)
                .frame(width: 160)

            Button {
                navigateMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(Calendar.current.isDate(viewModel.selectedMonth, equalTo: Date(), toGranularity: .month))
        }
    }

    private var monthLabel: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: viewModel.selectedMonth)
    }

    private func navigateMonth(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: viewModel.selectedMonth) {
            viewModel.selectedMonth = newDate
            viewModel.reloadMonth()
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Aktiv (Monat)",
                value: Formatters.formatMinutes(viewModel.monthTotalActive),
                accentColor: .otBlue
            )
            StatCard(
                title: "Overtime (Monat)",
                value: Formatters.formatMinutes(viewModel.monthTotalOvertime),
                accentColor: .otRed
            )
            StatCard(
                title: "Arbeitstage",
                value: "\(viewModel.monthWorkDays)",
                accentColor: .otGreen
            )
        }
    }

    private var barChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tagesübersicht")
                .font(.headline)
            DashboardBarChart(summaries: viewModel.monthSummaries)
                .frame(height: 200)
        }
    }

    private var cumulativeChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kumulative Overtime")
                .font(.headline)
            CumulativeOvertimeChart(data: viewModel.cumulativeOvertime)
                .frame(height: 180)
        }
    }

    private var appBreakdown: some View {
        AppBreakdownView(
            title: "Apps — \(monthLabel)",
            items: viewModel.monthApps.map {
                AppBreakdownItem(
                    appName: $0.appName,
                    activeMinutes: $0.totalActiveMinutes,
                    regularMinutes: $0.regularMinutes,
                    overtimeMinutes: $0.overtimeMinutes
                )
            }
        )
    }
}
