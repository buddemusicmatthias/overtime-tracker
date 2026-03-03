import SwiftUI

struct SettingsView: View {
    var viewModel: SettingsViewModel

    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                workHoursSection
                trackingSection
                systemSection
                dataSection
                versionFooter
            }
            .padding(20)
        }
        .frame(width: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
        .alert("Alle Daten löschen?", isPresented: $showDeleteAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                Task { await viewModel.deleteAllData() }
            }
        } message: {
            Text("Alle erfassten Aktivitäten, Tages- und App-Zusammenfassungen werden unwiderruflich gelöscht. Einstellungen bleiben erhalten.")
        }
    }

    // MARK: - Work Hours

    private var workHoursSection: some View {
        sectionCard(title: "Arbeitszeiten") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Beginn")
                        .frame(width: 60, alignment: .leading)
                    Spacer()
                    Text(viewModel.formatHourMinute(viewModel.settings.coreStartTotalMinutes))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.otBlue)
                    Stepper("", value: Binding(
                        get: { viewModel.settings.coreStartTotalMinutes },
                        set: {
                            viewModel.settings.coreStartTotalMinutes = $0
                            viewModel.save()
                        }
                    ), in: 0...viewModel.settings.coreEndTotalMinutes - 15, step: 15)
                    .labelsHidden()
                }

                HStack {
                    Text("Ende")
                        .frame(width: 60, alignment: .leading)
                    Spacer()
                    Text(viewModel.formatHourMinute(viewModel.settings.coreEndTotalMinutes))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.otBlue)
                    Stepper("", value: Binding(
                        get: { viewModel.settings.coreEndTotalMinutes },
                        set: {
                            viewModel.settings.coreEndTotalMinutes = $0
                            viewModel.save()
                        }
                    ), in: viewModel.settings.coreStartTotalMinutes + 15...1439, step: 15)
                    .labelsHidden()
                }

                Divider()

                Text("Arbeitstage")
                    .font(.subheadline.weight(.medium))

                DayPillRow(
                    selectedDays: Binding(
                        get: { viewModel.settings.workDayInts },
                        set: {
                            viewModel.settings.workDayInts = $0
                            viewModel.save()
                        }
                    ),
                    onChange: {}
                )

                Text("Aktivität außerhalb der Kernzeit wird als Overtime gezählt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Tracking

    private var trackingSection: some View {
        sectionCard(title: "Tracking") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Idle-Timeout")
                    Spacer()
                    Text("\(viewModel.settings.idleTimeoutMinutes) Min.")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.otBlue)
                    Stepper("", value: Binding(
                        get: { viewModel.settings.idleTimeoutMinutes },
                        set: {
                            viewModel.settings.idleTimeoutMinutes = $0
                            viewModel.save()
                        }
                    ), in: 1...120, step: 1)
                    .labelsHidden()
                }

                Text("Nach dieser Inaktivitätszeit wird die Sitzung als Idle gewertet. Änderungen werden vom Daemon mit max. 5 Min. Verzögerung übernommen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - System

    private var systemSection: some View {
        sectionCard(title: "System") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Beim Login starten", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { _ in viewModel.toggleLaunchAtLogin() }
                ))

                if !LaunchAgentManager.isVenvReady {
                    Text("Python-venv nicht gefunden. Erstelle es mit: python3 -m venv venv && venv/bin/pip install -r requirements.txt")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Toggle("Im Dock anzeigen", isOn: Binding(
                    get: { viewModel.showInDock },
                    set: { _ in viewModel.toggleDockVisibility() }
                ))
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        sectionCard(title: "Daten") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Datenbank")
                        .font(.subheadline)
                    Spacer()
                    Text(DatabaseManager.dbPathString)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Text("Alle Daten löschen")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Version Footer

    private var versionFooter: some View {
        HStack {
            Spacer()
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
            Text("Overtime Tracker v\(version) (\(build))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    // MARK: - Card Helper

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.otGray)
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
