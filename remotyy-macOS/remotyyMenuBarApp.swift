import SwiftUI
import OSLog

let log = OSLog(subsystem: "com.remotyy.macos", category: "general")

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
    
    private var hostProcess: Process?
    private let outputQueue = DispatchQueue(label: "com.remotyy.output", qos: .background)
    
    init() {
        signalURL = UserDefaults.standard.string(forKey: "signalURL") ?? "ws://localhost:9000"
        hostName = UserDefaults.standard.string(forKey: "hostName") ?? ProcessInfo.processInfo.hostName
    }
    
    func startHost() {
        if isRunning {
            statusMessage = "⚠️ Already running"
            return
        }
        
        let name = hostName.trimmingCharacters(in: .whitespaces)
        let url = signalURL.trimmingCharacters(in: .whitespaces)
        
        guard !url.isEmpty, !name.isEmpty else {
            statusMessage = "❌ Signal URL and hostname required"
            return
        }
        
        guard let binaryPath = findBinary() else {
            statusMessage = "❌ remotyy binary not found"
            os_log("Binary not found", log: log, type: .error)
            return
        }
        
        os_log("Starting host: %{public}s --signal %{public}s --name %{public}s",
               log: log, type: .info, binaryPath, url, name)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["host", "--signal", url, "--name", name]
        if !masterPassword.isEmpty {
            process.arguments?.append("--master-password")
            process.arguments?.append(masterPassword)
        }
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
        
        // Set up pipes for stdout/stderr (read async on background queue)
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        
        // Read stdout asynchronously
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.count > 0, let output = String(data: data, encoding: .utf8) {
                os_log("host: %{public}s", log: log, type: .debug, output)
            }
        }
        
        // Read stderr asynchronously (errors from host)
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0, let output = String(data: data, encoding: .utf8) {
                os_log("host error: %{public}s", log: log, type: .error, output)
            }
        }
        
        // Handle process exit
        process.terminationHandler = { [weak self] proc in
            // Clean up readability handlers
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRunning = false
                self.hostProcess = nil
                let status = proc.terminationStatus
                if status == 0 {
                    self.statusMessage = "⏹ Stopped"
                } else {
                    self.statusMessage = "🛑 Crashed (exit: \(status))"
                    // Try to read any remaining output
                    let remainingOut = String(data: outPipe.fileHandleForReading.availableData, encoding: .utf8) ?? ""
                    let remainingErr = String(data: errPipe.fileHandleForReading.availableData, encoding: .utf8) ?? ""
                    os_log("Host crashed. stdout: %{public}s stderr: %{public}s",
                           log: log, type: .error, remainingOut, remainingErr)
                }
                os_log("Host exited with status %d", log: log, type: .info, status)
            }
        }
        
        do {
            try process.run()
            hostProcess = process
            isRunning = true
            statusMessage = "✅ Running on \(name)"
            os_log("Host PID: %d", log: log, type: .info, process.processIdentifier)
        } catch {
            statusMessage = "❌ Failed: \(error.localizedDescription)"
            os_log("Failed to start: %{public}s", log: log, type: .error, error.localizedDescription)
        }
    }
    
    func stopHost() {
        guard let process = hostProcess, isRunning else { return }
        os_log("Stopping host PID %d", log: log, type: .info, process.processIdentifier)
        process.terminate()
        // Give it 3 seconds to terminate gracefully, then kill
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self, let proc = self.hostProcess, proc.isRunning else { return }
            os_log("Force killing host PID %d", log: log, type: .error, proc.processIdentifier)
            proc.terminate()
        }
        hostProcess = nil
        isRunning = false
        statusMessage = "⏹ Stopped"
    }
    
    private func findBinary() -> String? {
        // Use Bundle first (bundled inside .app)
        if let bundled = Bundle.main.path(forResource: "remotyyd", ofType: nil) {
            if FileManager.default.fileExists(atPath: bundled) {
                return bundled
            }
        }
        if let bundled = Bundle.main.path(forResource: "remotyy", ofType: nil) {
            if FileManager.default.fileExists(atPath: bundled) {
                return bundled
            }
        }
        // Fallback to PATH
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["remotyy"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                return path
            }
        }
        return nil
    }
}
