import Foundation

/// Wraps launchctl calls for the Python daemon LaunchAgent
nonisolated enum LaunchAgentManager {
    static let plistLabel = "com.matthias.overtime-tracker"

    static var plistPath: String {
        NSHomeDirectory() + "/Library/LaunchAgents/\(plistLabel).plist"
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }

    /// Checks if the daemon is currently loaded via `launchctl list`
    static func isDaemonRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list", plistLabel]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Loads the LaunchAgent plist
    static func load() throws {
        guard isInstalled else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", plistPath]
        try process.run()
        process.waitUntilExit()
    }

    /// Unloads the LaunchAgent plist
    static func unload() throws {
        guard isInstalled else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistPath]
        try process.run()
        process.waitUntilExit()
    }
}
