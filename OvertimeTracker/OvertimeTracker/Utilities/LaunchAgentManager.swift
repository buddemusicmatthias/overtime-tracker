import Foundation

/// Wraps launchctl calls for the Python daemon LaunchAgent
nonisolated enum LaunchAgentManager {
    static let plistLabel = "com.matthias.overtime-tracker"

    static var plistPath: String {
        NSHomeDirectory() + "/Library/LaunchAgents/\(plistLabel).plist"
    }

    /// Runtime convention path — all daemon files live under ~/.overtime-tracker/
    static let projectRoot: String = NSHomeDirectory() + "/.overtime-tracker"

    static var pythonPath: String {
        projectRoot + "/venv/bin/python"
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }

    static var isVenvReady: Bool {
        FileManager.default.fileExists(atPath: pythonPath)
    }

    // MARK: - Install

    /// Writes the LaunchAgent plist with correct paths to ~/Library/LaunchAgents/
    static func install() throws {
        guard isVenvReady else {
            throw LaunchAgentError.venvNotFound(pythonPath)
        }

        let plist: NSDictionary = [
            "Label": plistLabel,
            "ProgramArguments": [pythonPath, "-m", "src.main"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": "\(projectRoot)/daemon.stdout.log",
            "StandardErrorPath": "\(projectRoot)/daemon.stderr.log",
            "WorkingDirectory": projectRoot,
        ]

        let launchAgentsDir = (plistPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: launchAgentsDir, withIntermediateDirectories: true
        )

        guard plist.write(toFile: plistPath, atomically: true) else {
            throw LaunchAgentError.writeFailed(plistPath)
        }
    }

    // MARK: - Load / Unload

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

    /// Loads the LaunchAgent plist, auto-installing if not present
    static func load() throws {
        if !isInstalled {
            try install()
        }
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

    // MARK: - Errors

    enum LaunchAgentError: LocalizedError {
        case venvNotFound(String)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .venvNotFound(let path):
                return "Python-venv nicht gefunden: \(path)"
            case .writeFailed(let path):
                return "Konnte LaunchAgent nicht schreiben: \(path)"
            }
        }
    }
}
