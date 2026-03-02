import SwiftUI

struct PopoverView: View {
    var viewModel: PopoverViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            todaySection
            Divider().padding(.vertical, 10)
            weekSection
            Divider().padding(.vertical, 10)
            actionButtons
        }
        .padding(16)
        .frame(width: 320, height: 460)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
    }

    // MARK: - Today Section

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.todayHeaderText)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.otGray)
                .tracking(0.5)

            HStack(spacing: 8) {
                StatCard(title: "Aktiv", value: viewModel.activeText, accentColor: .otBlue)
                StatCard(title: "Overtime", value: viewModel.overtimeText, accentColor: .otRed)
                StatCard(title: "Idle", value: viewModel.idleText, accentColor: .otGray)
            }

            activityRow
        }
    }

    private var activityRow: some View {
        HStack {
            Text("Erste / letzte Akt.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(viewModel.firstActivityText) – \(viewModel.lastActivityText)")
                .font(.caption.monospaced())
                .foregroundStyle(Color.otGreen)
        }
    }

    // MARK: - Week Section

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.calendarWeekText)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.otGray)
                .tracking(0.5)

            WeekBarChart(summaries: viewModel.weekSummaries)

            HStack(spacing: 8) {
                StatCard(title: "Aktiv", value: viewModel.weekActiveText, accentColor: .otBlue)
                StatCard(title: "Overtime", value: viewModel.weekOvertimeText, accentColor: .otRed)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button {
                print("[Stub] Dashboard öffnen")
            } label: {
                Text("Dashboard öffnen")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.otBlue)

            HStack(spacing: 8) {
                Button {
                    print("[Stub] Tracking pausieren")
                } label: {
                    Text("Tracking pausieren")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)

                Button {
                    print("[Stub] Einstellungen")
                } label: {
                    Text("Einstellungen")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }

            if !viewModel.isConnected {
                Label("DB nicht gefunden", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}
