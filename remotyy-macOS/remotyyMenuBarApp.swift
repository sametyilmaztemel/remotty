import SwiftUI
import OSLog
import ServiceManagement

let Log = OSLog(subsystem: "com.remotyy.macos", category: "general")

@main
struct remotyyApp: App {
    @StateObject private var host = HostManager()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(host)
        } label: {
            Image(systemName: host.isRunning ? "terminal.fill" : "terminal")
                .foregroundColor(host.isRunning ? .green : .secondary)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
                .environmentObject(host)
                .frame(width: 420, height: 320)
        }
    }
}

@MainActor
class HostManager: ObservableObject {
    @Published var isRunning = false
    @Published var statusMessage = "Ready"
    @Published var signalURL = UserDefaults.standard.string(forKey: "signalURL") ?? "ws://localhost:9000" {
        didSet { UserDefaults.standard.set(signalURL, forKey: "signalURL") }
    }
    @Published var hostName = UserDefaults.standard.string(forKey: "hostName") ?? ProcessInfo.processInfo.hostName {
        didSet { UserDefaults.standard.set(hostName, forKey: "hostName") }
    }
    @Published var masterPassword = ""
    @Published var launchAtLogin: Bool {
        didSet { updateLaunchAtLogin() }
    }
    
    private var hostProcess: Process?
    private var healthTimer: Timer?
    
    init() {
        launchAtLogin = (try? SMAppService.mainApp.status == .enabled) ?? false
    }
    
    func startHost() {
        guard !isRunning else { return }
        
        let name = hostName.trimmingCharacters(in: .whitespaces).nonEmpty ?? ProcessInfo.processInfo.hostName
        let url = signalURL.trimmingCharacters(in: .whitespaces)
        
        guard !url.isEmpty else {
            statusMessage = "Signal URL is required"
            return
        }
        guard let binary = findBinary() else {
            statusMessage = "remotyy binary not found"
            os_log("Binary not found", log: Log, type: .error)
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
        
        let outPipe = Pipe()
        process.standardOutput = outPipe
        outPipe.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            if d.count > 0, let s = String(data: d, encoding: .utf8) {
                os_log("%{public}s", log: Log, type: .debug, s.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        let errPipe = Pipe()
        process.standardError = errPipe
        errPipe.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            if d.count > 0, let s = String(data: d, encoding: .utf8) {
                os_log("stderr: %{public}s", log: Log, type: .error, s.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        process.terminationHandler = { [weak self] proc in
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.hostProcess = nil
                self?.healthTimer?.invalidate()
                self?.healthTimer = nil
                let status = proc.terminationStatus
                self?.statusMessage = status == 0 ? "Stopped" : "Crashed (exit \(status))"
                if status != 0 {
                    let err = String(data: errPipe.fileHandleForReading.availableData, encoding: .utf8) ?? ""
                    os_log("Crash: %{public}s", log: Log, type: .error, err)
                }
            }
        }
        
        do {
            try process.run()
            hostProcess = process
            isRunning = true
            statusMessage = "Running — \(name)"
            
            healthTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
                guard let self = self, let proc = self.hostProcess, !proc.isRunning else { return }
                Task { @MainActor in
                    self.isRunning = false
                    self.statusMessage = "Process ended"
                }
            }
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
        }
    }
    
    func stopHost() {
        guard let proc = hostProcess, isRunning else { return }
        proc.terminate()
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
    
    private func findBinary() -> String? {
        if let p = Bundle.main.path(forResource: "remotyyd", ofType: nil), FileManager.default.fileExists(atPath: p) {
            return p
        }
        if let p = Bundle.main.path(forResource: "remotyy", ofType: nil), FileManager.default.fileExists(atPath: p) {
            return p
        }
        let t = Process()
        t.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        t.arguments = ["remotyy"]
        let p = Pipe()
        t.standardOutput = p
        try? t.run()
        t.waitUntilExit()
        if t.terminationStatus == 0 {
            let s = (try? p.fileHandleForReading.readToEnd()).flatMap { String(data: $0, encoding: .utf8) }?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let s = s, !s.isEmpty { return s }
        }
        // Hardcoded fallbacks
        for path in ["/usr/local/bin/remotyy", "/opt/homebrew/bin/remotyy"] {
            if FileManager.default.fileExists(atPath: path) { return path }
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
            os_log("SMAppService: %{public}s", log: Log, type: .error, error.localizedDescription)
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
