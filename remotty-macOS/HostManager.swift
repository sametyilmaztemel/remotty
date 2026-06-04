import Foundation
import OSLog
import ServiceManagement

let Log = OSLog(subsystem: "com.remotty.macos", category: "general")

// MARK: - HostManager

public class HostManager: ObservableObject {
    @Published public internal(set) var isRunning = false
    @Published public internal(set) var statusMessage = "Ready"
    @Published public var signalURL: String { didSet { save() } }
    @Published public var hostName: String { didSet { save() } }
    @Published public var masterPassword: String = ""
    @Published public var launchAtLogin: Bool { didSet { updateLaunchAtLogin() } }
    @Published public private(set) var screenSharing = false

    private var hostProcess: Process?
    private var healthTimer: Timer?
    private var screenProcess: Process?

    /// Singleton access for AppKit / target-action callbacks
    public static let shared = HostManager()

    public init() {
        signalURL = UserDefaults.standard.string(forKey: "signalURL")
            ?? "ws://localhost:9000"
        hostName = UserDefaults.standard.string(forKey: "hostName")
            ?? ProcessInfo.processInfo.hostName
        launchAtLogin = (try? SMAppService.mainApp.status == .enabled) ?? false
    }

    // MARK: - Host Lifecycle

    public func startHost() {
        guard !isRunning else { return }

        let name = hostName.trimmed.isEmpty
            ? ProcessInfo.processInfo.hostName
            : hostName.trimmed
        let url = signalURL.trimmed

        guard !url.isEmpty else {
            statusMessage = "Signal URL is required"
            return
        }

        guard let binary = findBinary() else {
            statusMessage = "Binary not found"
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["host", "--signal", url, "--name", name]
        if !masterPassword.isEmpty {
            process.arguments?.append("--master-password")
            process.arguments?.append(masterPassword)
        }
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())

        let stdOut = Pipe()
        process.standardOutput = stdOut
        stdOut.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            if d.count > 0, let s = String(data: d, encoding: .utf8) {
                os_log("%{public}s", log: Log, type: .debug,
                       s.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        let stdErr = Pipe()
        process.standardError = stdErr
        stdErr.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            if d.count > 0, let s = String(data: d, encoding: .utf8) {
                os_log("stderr: %{public}s", log: Log, type: .error,
                       s.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        process.terminationHandler = { [weak self] proc in
            stdOut.fileHandleForReading.readabilityHandler = nil
            stdErr.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.hostProcess = nil
                self?.healthTimer?.invalidate()
                self?.healthTimer = nil
                let st = proc.terminationStatus
                self?.statusMessage = st == 0 ? "Stopped" : "Crashed (exit \(st))"
            }
        }

        do {
            try process.run()
            hostProcess = process
            isRunning = true
            statusMessage = "Running \u{2014} \(name)"
            healthTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
                guard let self = self, let p = self.hostProcess, !p.isRunning else { return }
                Task {
                    self.isRunning = false
                    self.statusMessage = "Process ended"
                }
            }
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
        }
    }

    public func stopHost() {
        guard let p = hostProcess, isRunning else { return }
        p.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self, let p = self.hostProcess, p.isRunning else { return }
            kill(p.processIdentifier, SIGKILL)
        }
        hostProcess = nil
        isRunning = false
        healthTimer?.invalidate()
        healthTimer = nil
        statusMessage = "Stopped"
    }

    // MARK: - Screen Sharing

    public func toggleScreenShare() {
        if screenSharing {
            stopScreenShare()
        } else {
            startScreenShare()
        }
    }

    private func startScreenShare() {
        guard !screenSharing else { return }
        guard let binary = findBinary() else {
            statusMessage = "Binary not found for screen sharing"
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["screen", "--signal", signalURL.trimmed]
        if !masterPassword.isEmpty {
            process.arguments?.append("--master-password")
            process.arguments?.append(masterPassword)
        }

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                self?.screenSharing = false
                self?.screenProcess = nil
            }
        }

        do {
            try process.run()
            screenProcess = process
            screenSharing = true
        } catch {
            statusMessage = "Screen sharing failed: \(error.localizedDescription)"
        }
    }

    private func stopScreenShare() {
        guard let p = screenProcess else { return }
        p.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self, let p = self.screenProcess, p.isRunning else { return }
            kill(p.processIdentifier, SIGKILL)
        }
        screenProcess = nil
        screenSharing = false
    }

    // MARK: - Helpers

    func findBinary() -> String? {
        // 1. Bundled binary
        if let p = Bundle.main.path(forResource: "remottyd", ofType: nil) {
            return p
        }
        // 2. which(1)
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["remotty"]
        let pipe = Pipe()
        which.standardOutput = pipe
        try? which.run()
        which.waitUntilExit()
        if which.terminationStatus == 0 {
            let data = try? pipe.fileHandleForReading.readToEnd()
            if let s = data.flatMap({ String(data: $0, encoding: .utf8) })?
                .trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                return s
            }
        }
        // 3. Common locations
        for candidate in ["/usr/local/bin/remotty", "/opt/homebrew/bin/remotty"] {
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            os_log("SMAppService: %{public}s", log: Log, type: .error,
                   error.localizedDescription)
        }
    }

    private func save() {
        UserDefaults.standard.set(signalURL, forKey: "signalURL")
        UserDefaults.standard.set(hostName, forKey: "hostName")
    }
}

// MARK: - String Helpers

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
}
