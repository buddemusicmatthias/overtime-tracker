import SwiftUI

@main
struct OvertimeTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menubar-only app — no window, no dock icon.
        // LSUIElement = true hides the dock icon.
        // The NSStatusItem + NSPopover are managed by AppDelegate.
        Settings {
            EmptyView()
        }
    }
}
