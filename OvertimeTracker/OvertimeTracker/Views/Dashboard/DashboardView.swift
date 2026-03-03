import SwiftUI

struct DashboardView: View {
    var viewModel: DashboardViewModel

    var body: some View {
        TabView {
            HeuteTab(viewModel: viewModel)
                .tabItem {
                    Label("Heute", systemImage: "calendar.day.timeline.left")
                }

            WocheTab(viewModel: viewModel)
                .tabItem {
                    Label("Woche", systemImage: "calendar")
                }

            MonatTab(viewModel: viewModel)
                .tabItem {
                    Label("Monat", systemImage: "chart.bar.xaxis")
                }

            ExportTab(viewModel: viewModel)
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
        }
        .frame(minWidth: 780, minHeight: 600)
        .preferredColorScheme(.dark)
    }
}
