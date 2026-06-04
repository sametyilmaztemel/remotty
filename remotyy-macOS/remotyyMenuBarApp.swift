import SwiftUI
import OSLog

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
    @Published var sessionCount = 0
    
    private var hostProcess: Process?
    
    init() {
        signalURL = UserDefaults.standard.string(forKey: "signalURL") ?? "ws://localhost:9000"
        hostName = UserDefaults.standard.string(forKey: "hostName") ?? ProcessInfo.processInfo.hostName
    }
    
    func startHost() {
        if isRunning {
            os_log("Host already running, ignoring start", log: log, type: .info)
            return
        }
        
        let name = hostName.trimmingCharacters(in: .whitespaces)
        let url = signalURL.trimmingCharacters(in: .whitespaces)
        let binary = findBinary()
        
        if url.isEmpty || name.isEmpty {
            statusMessage = "❌ Signal URL and hostname required"
            os_log("Missing configuration: url=%{public}s name=%{public}s", log: log, type: .error, url, name)
            return
        }
        
        guard let binaryPath = binary else {
            statusMessage = "❌ remotyy binary not found"
            os_log("Binary not found", log: log, type: .error)
            return
        }
        
        os_log("Starting host: %{public}s url=%{public}s name=%{public}s",
               log: log, type: .info, binaryPath, url, name)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["host", "--signal", url, "--name", name]
        if !masterPassword.isEmpty {
            process.arguments?.append("--master-password")
            process.arguments?.append(masterPassword)
        }
        
        // Capture output for logging
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        process.terminationHandler = { proc in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isRunning = false
                self.sessionCount = 0
                let status = proc.terminationStatus
                self.statusMessage = status == 0 ? "⏹ Stopped" : "🛑 Crashed (exit: \(status))"
                os_log("Host exited: %d", log: log, type: .info, status)
            }
        }
        
        do {
            try process.run()
            hostProcess = process
            isRunning = true
            statusMessage = "✅ Running on \(name)"
            os_log("Host started with PID: %d", log: log, type: .info, process.processIdentifier)
            
            // Read output asynchronously
            Task {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    os_log("Host output: %{public}s", log: log, type: .debug, output)
                }
            }
        } catch {
            statusMessage = "❌ Failed: \(error.localizedDescription)"
            os_log("Start failed: %{public}s", log: log, type: .error, error.localizedDescription)
        }
    }
    
    func stopHost() {
        guard let process = hostProcess, isRunning else { return }
        os_log("Stopping host PID %d", log: log, type: .info, process.processIdentifier)
        process.terminate()
        hostProcess = nil
        isRunning = false
        statusMessage = "⏹ Stopped"
    }
    
    private func findBinary() -> String? {
        let candidates: [String?] = [
            Bundle.main.path(forResource: "remotyyd", ofType: nil),
            Bundle.main.path(forResource: "remotyy", ofType: nil),
            "/usr/local/bin/remotyy",
            "/opt/homebrew/bin/remotyy",
            "\(NSHomeDirectory())/.local/bin/remotyy",
            "\(NSHomeDirectory())/projects/remotyy/bin/remotyy",
            "\(NSHomeDirectory())/Projects/remotyy/bin/remotyy",
        ]
        
        for path in candidates {
            if let p = path, FileManager.default.fileExists(atPath: p) {
                os_log("Found binary: %{public}s", log: log, type: .debug, p)
                return p
            }
        }
        return nil
    }
}
