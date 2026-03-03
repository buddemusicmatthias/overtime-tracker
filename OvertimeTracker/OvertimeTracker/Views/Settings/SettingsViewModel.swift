import Cocoa
import GRDB
import Observation

@Observable
final class SettingsViewModel {
    var settings = TrackerSettings()
    var launchAtLogin: Bool = false
    var showInDock: Bool = false
    var isDaemonRunning: Bool = false

    private var observationTask: Task<Void, Never>?

    private static let showInDockKey = "showInDock"

    // MARK: - Lifecycle

    func startObserving() {
        guard let pool = DatabaseManager.shared.dbPool else { return }

        launchAtLogin = LaunchAgentManager.isInstalled && LaunchAgentManager.isDaemonRunning()
        isDaemonRunning = LaunchAgentManager.isDaemonRunning()
        showInDock = UserDefaults.standard.bool(forKey: Self.showInDockKey)

        observationTask = Task { [weak self] in
            do {
                let observation = ValueObservation.tracking { db in
                    try TrackerSettings.fetchOne(db, key: 1) ?? TrackerSettings()
                }
                for try await settings in observation.values(in: pool) {
                    self?.settings = settings
                }
            } catch {
                if !Task.isCancelled { print("[Settings] Observation error: \(error)") }
            }
        }
    }

    func stopObserving() {
        observationTask?.cancel()
    }

    // MARK: - Save (auto-save on every change)

    func save() {
        Task {
            do {
                try await DatabaseManager.shared.saveSettings(settings)
            } catch {
                print("[Settings] Save error: \(error)")
            }
        }
    }

    // MARK: - Launch at Login

    func toggleLaunchAtLogin() {
        do {
            if launchAtLogin {
                try LaunchAgentManager.unload()
            } else {
                try LaunchAgentManager.load()
            }
            launchAtLogin = LaunchAgentManager.isDaemonRunning()
        } catch {
            print("[Settings] LaunchAgent toggle error: \(error)")
        }
    }

    // MARK: - Dock Visibility

    func toggleDockVisibility() {
        showInDock.toggle()
        UserDefaults.standard.set(showInDock, forKey: Self.showInDockKey)
        applyDockVisibility()
    }

    func applyDockVisibility() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    // MARK: - Data Management

    func deleteAllData() async {
        do {
            try await DatabaseManager.shared.deleteAllData()
        } catch {
            print("[Settings] Delete error: \(error)")
        }
    }

    // MARK: - Formatting Helpers

    func formatHourMinute(_ totalMinutes: Int) -> String {
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return String(format: "%02d:%02d", h, m)
    }
}
