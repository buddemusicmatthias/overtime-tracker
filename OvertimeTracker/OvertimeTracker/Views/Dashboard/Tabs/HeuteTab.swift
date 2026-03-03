import SwiftUI

struct HeuteTab: View {
    var viewModel: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                metricsSection
                appBreakdown
            }
            .padding(24)
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Übersicht")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                StatCard(
                    title: "Aktiv",
                    value: Formatters.formatMinutes(viewModel.todaySummary?.totalActiveMinutes ?? 0),
                    accentColor: .otBlue
                )
                StatCard(
                    title: "Overtime",
                    value: Formatters.formatMinutes(viewModel.todaySummary?.overtimeMinutes ?? 0),
                    accentColor: .otRed
                )
                StatCard(
                    title: "Idle",
                    value: Formatters.formatMinutes(viewModel.todaySummary?.totalIdleMinutes ?? 0),
                    accentColor: .otGray
                )
                StatCard(
                    title: "Erste Aktivität",
                    value: viewModel.todaySummary?.firstActivity.map(Formatters.formatTime) ?? "—:—",
                    accentColor: .otGreen
                )
            }
        }
    }

    private var appBreakdown: some View {
        AppBreakdownView(
            title: "Apps — Heute",
            items: viewModel.todayApps.map {
                AppBreakdownItem(
                    appName: $0.appName,
                    activeMinutes: $0.activeMinutes,
                    regularMinutes: $0.regularMinutes,
                    overtimeMinutes: $0.overtimeMinutes
                )
            }
        )
    }
}
