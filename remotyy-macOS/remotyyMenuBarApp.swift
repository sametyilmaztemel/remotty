import SwiftUI

@main
struct remotyyMenuBarApp: App {
    @StateObject private var hostManager = HostManager()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(hostManager)
        } label: {
            Image(systemName: hostManager.isRunning ? "terminal.fill" : "terminal")
                .foregroundColor(hostManager.isRunning ? .green : .gray)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
                .environmentObject(hostManager)
        }
    }
}

@MainActor
class HostManager: ObservableObject {
    @Published var isRunning = false
    @Published var signalURL = "ws://localhost:9000"
    @Published var hostName = ""
    @Published var masterPassword = ""
    @Published var lastConnected: Date?
    @Published var sessionCount = 0
    @Published var statusMessage = "Ready"
    
    private var hostProcess: Process?
    
    func startHost() {
        guard !isRunning else { return }
        
        let name = hostName.isEmpty ? ProcessInfo.processInfo.hostName : hostName
        let process = Process()
        process.executableURL = findRemotyyBinary()
        process.arguments = ["host", "--signal", signalURL, "--name", name]
        if !masterPassword.isEmpty {
            process.arguments?.append("--master-password")
            process.arguments?.append(masterPassword)
        }
        
        do {
            try process.run()
            hostProcess = process
            isRunning = true
            statusMessage = "Running on \(name)"
            
            // Monitor process
            Task {
                process.waitUntilExit()
                await MainActor.run {
                    isRunning = false
                    statusMessage = "Host stopped"
                }
            }
        } catch {
            statusMessage = "Failed to start: \(error.localizedDescription)"
        }
    }
    
    func stopHost() {
        hostProcess?.terminate()
        hostProcess = nil
        isRunning = false
        statusMessage = "Stopped"
    }
    
    private func findRemotyyBinary() -> URL {
        // Check common locations
        let paths = [
            "/usr/local/bin/remotyy",
            "/opt/homebrew/bin/remotyy",
            "\(NSHomeDirectory())/.local/bin/remotyy",
            "\(NSHomeDirectory())/projects/remotyy/remotyy",
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return URL(fileURLWithPath: "/usr/local/bin/remotyy")
    }
}
