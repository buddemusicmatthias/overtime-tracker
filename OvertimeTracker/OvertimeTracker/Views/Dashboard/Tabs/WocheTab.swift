import SwiftUI

struct WocheTab: View {
    var viewModel: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                metricsRow
                chartSection
                detailTable
                appBreakdown
            }
            .padding(24)
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Aktiv (Woche)",
                value: Formatters.formatMinutes(viewModel.weekTotalActive),
                accentColor: .otBlue
            )
            StatCard(
                title: "Overtime (Woche)",
                value: Formatters.formatMinutes(viewModel.weekTotalOvertime),
                accentColor: .otRed
            )
            StatCard(
                title: "Arbeitstage",
                value: "\(viewModel.weekSummaries.filter { $0.totalActiveMinutes > 0 }.count)",
                accentColor: .otGreen
            )
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tagesübersicht")
                .font(.headline)
            DashboardBarChart(summaries: viewModel.weekSummaries)
                .frame(height: 200)
        }
    }

    private var detailTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Tag").fontWeight(.semibold)
                    Text("Aktiv").fontWeight(.semibold)
                    Text("Overtime").fontWeight(.semibold)
                    Text("Idle").fontWeight(.semibold)
                    Text("Erster").fontWeight(.semibold)
                    Text("Letzter").fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()

                ForEach(Array(viewModel.weekSummaries.enumerated()), id: \.offset) { _, s in
                    weekDetailRow(s)
                }
            }
        }
    }

    private func weekDetailRow(_ s: DailySummary) -> some View {
        GridRow {
            Text(Formatters.weekdayShort(s.date) + " " + Formatters.shortDate(s.date))
            Text(Formatters.formatMinutes(s.totalActiveMinutes))
                .foregroundStyle(Color.otBlue)
            Text(Formatters.formatMinutes(s.overtimeMinutes))
                .foregroundStyle(Color.otRed)
            Text(Formatters.formatMinutes(s.totalIdleMinutes))
                .foregroundStyle(Color.otGray)
            Text(s.firstActivity.map(Formatters.formatTime) ?? "—")
            Text(s.lastActivity.map(Formatters.formatTime) ?? "—")
        }
        .font(.caption.monospaced())
    }

    private var appBreakdown: some View {
        AppBreakdownView(
            title: "Apps — Woche",
            items: viewModel.weekApps.map {
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
