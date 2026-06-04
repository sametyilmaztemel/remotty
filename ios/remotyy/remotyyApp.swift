import SwiftUI

@main
struct remotyyApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

class AppState: ObservableObject {
    @Published var status: ConnectionStatus = .disconnected
    @Published var hosts: [HostInfo] = []
    @Published var signalURL: String = "ws://localhost:9000"
    
    enum ConnectionStatus: String {
        case disconnected = "Disconnected"
        case connecting = "Connecting..."
        case connected = "Connected"
        case error = "Error"
    }
}

struct HostInfo: Identifiable, Codable {
    let id: String
    let name: String
    let platform: String
    let arch: String
    let online: Bool
    let features: [String]
}
