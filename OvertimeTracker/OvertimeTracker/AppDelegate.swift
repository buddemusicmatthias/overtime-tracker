import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let viewModel = PopoverViewModel()

    private var dashboardWindow: NSWindow?
    private var dashboardViewModel: DashboardViewModel?

    private var settingsWindow: NSWindow?
    private var settingsViewModel: SettingsViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminateOtherInstances()
        applyDockVisibility()
        setupStatusItem()
        setupPopover()
        viewModel.onOpenDashboard = { [weak self] in self?.openDashboard() }
        viewModel.onOpenSettings = { [weak self] in self?.openSettings() }
        viewModel.startObserving()
        observeStatusBarText()
    }

    /// Terminates any already-running instances of this app (e.g. leftover from previous Xcode run)
    private func terminateOtherInstances() {
        let myPID = ProcessInfo.processInfo.processIdentifier
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) where app.processIdentifier != myPID {
            app.terminate()
        }
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "—:— OT"
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 460)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(viewModel: viewModel)
        )
    }

    // MARK: - Status Bar Observation

    /// Uses `withObservationTracking` to reactively update the status bar title
    /// whenever `viewModel.statusBarText` changes.
    private func observeStatusBarText() {
        withObservationTracking {
            let text = viewModel.statusBarText
            statusItem?.button?.title = text
        } onChange: {
            Task { @MainActor [weak self] in
                self?.observeStatusBarText()
            }
        }
    }

    // MARK: - Actions

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Dashboard Window

    func openDashboard() {
        // If window already exists, just bring it to front
        if let window = dashboardWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Close popover
        popover.performClose(nil)

        // Create fresh ViewModel + View
        let vm = DashboardViewModel()
        let hostingController = NSHostingController(
            rootView: DashboardView(viewModel: vm)
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Overtime Tracker — Dashboard"
        window.setFrameAutosaveName("DashboardWindow")
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 780, height: 600))
        window.minSize = NSSize(width: 680, height: 500)
        window.center()

        // Cleanup on close
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.dashboardViewModel?.stopObserving()
            self?.dashboardViewModel = nil
            self?.dashboardWindow = nil
        }

        dashboardViewModel = vm
        dashboardWindow = window

        vm.startObserving()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Settings Window

    func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        popover.performClose(nil)

        let vm = SettingsViewModel()
        let hostingController = NSHostingController(
            rootView: SettingsView(viewModel: vm)
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Overtime Tracker — Einstellungen"
        window.setFrameAutosaveName("SettingsWindow")
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 580))
        window.center()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.settingsViewModel?.stopObserving()
            self?.settingsViewModel = nil
            self?.settingsWindow = nil
        }

        settingsViewModel = vm
        settingsWindow = window

        vm.startObserving()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Dock Visibility

    private func applyDockVisibility() {
        let showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }
}
