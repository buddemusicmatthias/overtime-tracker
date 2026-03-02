import SwiftUI

struct PopoverView: View {
    var viewModel: PopoverViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            statsGrid
            if !viewModel.topApps.isEmpty {
                topAppsSection
            }
            Spacer()
            footer
        }
        .padding(16)
        .frame(width: 320, height: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Overtime Tracker")
                .font(.headline)
            Text(viewModel.todayFormatted)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                StatCard(
                    title: "Overtime",
                    value: viewModel.overtimeText
                )
                StatCard(
                    title: "Active",
                    value: viewModel.activeText
                )
            }
            HStack(spacing: 8) {
                StatCard(
                    title: "Start",
                    value: viewModel.firstActivityText
                )
                StatCard(
                    title: "End",
                    value: viewModel.lastActivityText
                )
            }
            StatCard(
                title: "Idle Time",
                value: viewModel.idleText
            )
        }
    }

    // MARK: - Top Apps

    private var topAppsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Top Apps")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(viewModel.topApps, id: \.appName) { app in
                HStack {
                    Text(app.appName)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(Self.formatMinutes(app.activeMinutes))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if !viewModel.isConnected {
                Label("DB not found", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private static func formatMinutes(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        return String(format: "%d:%02d", h, m)
    }
}
