import Cocoa
import GRDB
import Observation
import ServiceManagement

@MainActor
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

        let daemonLoaded = LaunchAgentManager.isInstalled && LaunchAgentManager.isDaemonRunning()
        let appRegistered = SMAppService.mainApp.status == .enabled
        launchAtLogin = daemonLoaded || appRegistered
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
        if launchAtLogin {
            // Disable both: daemon LaunchAgent + Swift app login item
            do { try LaunchAgentManager.unload() } catch {
                print("[Settings] LaunchAgent unload error: \(error)")
            }
            do { try SMAppService.mainApp.unregister() } catch {
                print("[Settings] SMAppService unregister error: \(error)")
            }
        } else {
            // Enable both: daemon LaunchAgent + Swift app login item
            do { try LaunchAgentManager.load() } catch {
                print("[Settings] LaunchAgent load error: \(error)")
            }
            do { try SMAppService.mainApp.register() } catch {
                print("[Settings] SMAppService register error: \(error)")
            }
        }

        let daemonLoaded = LaunchAgentManager.isDaemonRunning()
        let appRegistered = SMAppService.mainApp.status == .enabled
        launchAtLogin = daemonLoaded || appRegistered
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
