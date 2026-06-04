import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var host: HostManager
    @State private var localSignalURL: String = ""
    @State private var localHostName: String = ""
    @State private var localPassword: String = ""
    @State private var launchAtLogin = false
    @State private var showInMenuBar = true
    
    var body: some View {
        TabView {
            // Connection Settings
            Form {
                Section("Signaling Server") {
                    TextField("URL", text: $localSignalURL)
                        .fontDesign(.monospaced)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Host Identity") {
                    TextField("Hostname", text: $localHostName)
                        .fontDesign(.monospaced)
                        .textFieldStyle(.roundedBorder)
                        .help("Leave empty to use system hostname")
                }
                
                Section("Security") {
                    SecureField("Master Password", text: $localPassword)
                        .fontDesign(.monospaced)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Options") {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                    Toggle("Show in menu bar", isOn: $showInMenuBar)
                }
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            .onAppear {
                localSignalURL = host.signalURL
                localHostName = host.hostName
                localPassword = host.masterPassword
            }
            .onChange(of: localSignalURL) { host.signalURL = $0 }
            .onChange(of: localHostName) { host.hostName = $0 }
            .onChange(of: localPassword) { host.masterPassword = $0 }
            
            // About
            VStack(spacing: 16) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text("remotyy")
                    .font(.title)
                    .fontDesign(.monospaced)
                Text("Version 0.3.0")
                    .foregroundColor(.secondary)
                Text("Remote terminal & screen access via WebRTC")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 450, height: 350)
    }
}
