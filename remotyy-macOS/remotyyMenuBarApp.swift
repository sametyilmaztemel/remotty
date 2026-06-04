import SwiftUI
import OSLog
import ServiceManagement

let log = OSLog(subsystem: "com.remotyy.macos", category: "general")

// MARK: - Application Entry Point

@main
struct remotyyApp: App {
    @StateObject private var host = HostManager()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(host)
        } label: {
            Image(systemName: host.isRunning ? "terminal.fill" : "terminal")
                .foregroundColor(host.isRunning ? .green : .gray)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
                .environmentObject(host)
        }
    }
}

// MARK: - Host Manager

@MainActor
class HostManager: ObservableObject {
    @Published var isRunning = false
    @Published var statusMessage = "Ready"
    @Published var signalURL: String {
        didSet { UserDefaults.standard.set(signalURL, forKey: "signalURL") }
    }
    @Published var hostName: String {
        didSet { UserDefaults.standard.set(hostName, forKey: "hostName") }
    }
    @Published var masterPassword: String = ""
    @Published var launchAtLogin: Bool = false {
        didSet { updateLaunchAtLogin() }
    }
    
    private var hostProcess: Process?
    private var healthTimer: Timer?
    
    init() {
        signalURL = UserDefaults.standard.string(forKey: "signalURL") ?? "ws://localhost:9000"
        hostName = UserDefaults.standard.string(forKey: "hostName") ?? ProcessInfo.processInfo.hostName
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
    
    func startHost() {
        if isRunning {
            statusMessage = "Already running"
            return
        }
        
        let name = hostName.trimmingCharacters(in: .whitespaces)
        let url = signalURL.trimmingCharacters(in: .whitespaces)
        
        guard !url.isEmpty, !name.isEmpty else {
            statusMessage = "Signal URL and hostname required"
            return
        }
        
        guard let binaryPath = findBinary() else {
            statusMessage = "remotyy binary not found. Build with: make build"
            os_log("Binary not found", log: log, type: .error)
            return
        }
        
        os_log("Starting: %{public}s --signal %{public}s --name %{public}s",
               log: log, type: .info, binaryPath, url, name)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["host", "--signal", url, "--name", name]
        if !masterPassword.isEmpty {
            process.arguments?.append("--master-password")
            process.arguments?.append(masterPassword)
        }
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
        
        // Capturing stdout
        let outPipe = Pipe()
        process.standardOutput = outPipe
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0, let output = String(data: data, encoding: .utf8) {
                os_log("%{public}s", log: log, type: .debug, output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        // Capturing stderr
        let errPipe = Pipe()
        process.standardError = errPipe
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0, let output = String(data: data, encoding: .utf8) {
                os_log("stderr: %{public}s", log: log, type: .error, output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        process.terminationHandler = { [weak self] proc in
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRunning = false
                self.hostProcess = nil
                self.healthTimer?.invalidate()
                self.healthTimer = nil
                
                let status = proc.terminationStatus
                if status == 0 {
                    self.statusMessage = "Stopped"
                } else {
                    self.statusMessage = "Crashed (exit: \(status))"
                    // Read remaining stderr
                    let err = String(data: errPipe.fileHandleForReading.availableData, encoding: .utf8) ?? ""
                    os_log("Crash stderr: %{public}s", log: log, type: .error, err)
                }
                os_log("Host exit: %d", log: log, type: .info, status)
            }
        }
        
        do {
            try process.run()
            hostProcess = process
            isRunning = true
            statusMessage = "Running — \(name)"
            os_log("Host PID %d", log: log, type: .info, process.processIdentifier)
            startHealthCheck()
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
            os_log("Start failed: %{public}s", log: log, type: .error, error.localizedDescription)
        }
    }
    
    func stopHost() {
        guard let process = hostProcess, isRunning else { return }
        os_log("Stopping PID %d", log: log, type: .info, process.processIdentifier)
        process.terminate()
        // Force kill after grace period
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self, let proc = self.hostProcess, proc.isRunning else { return }
            os_log("Force kill PID %d", log: log, type: .error, proc.processIdentifier)
            kill(proc.processIdentifier, SIGKILL)
        }
        hostProcess = nil
        isRunning = false
        healthTimer?.invalidate()
        healthTimer = nil
        statusMessage = "Stopped"
    }
    
    private func startHealthCheck() {
        healthTimer?.invalidate()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self = self, let proc = self.hostProcess else { return }
            if !proc.isRunning {
                Task { @MainActor in
                    self.isRunning = false
                    self.statusMessage = "Process ended"
                }
            }
        }
    }
    
    private func findBinary() -> String? {
        // Bundled in .app
        if let bundled = Bundle.main.path(forResource: "remotyyd", ofType: nil) {
            if FileManager.default.fileExists(atPath: bundled) { return bundled }
        }
        if let bundled = Bundle.main.path(forResource: "remotyy", ofType: nil) {
            if FileManager.default.fileExists(atPath: bundled) { return bundled }
        }
        // PATH
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["remotyy"]
        let p = Pipe()
        task.standardOutput = p
        try? task.run()
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            let data = p.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty { return path }
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
            os_log("Launch at login failed: %{public}s", log: log, type: .error, error.localizedDescription)
        }
    }
}
