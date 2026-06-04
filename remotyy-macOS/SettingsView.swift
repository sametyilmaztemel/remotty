import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var host: HostManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .padding()
        .frame(width: 420, height: 320)
    }
    
    private var generalTab: some View {
        Form {
            Section("Connection") {
                HStack {
                    Text("Signal URL")
                        .frame(width: 100, alignment: .leading)
                    TextField("ws://host:port", text: $host.signalURL)
                        .fontDesign(.monospaced)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("Hostname")
                        .frame(width: 100, alignment: .leading)
                    TextField("", text: $host.hostName)
                        .fontDesign(.monospaced)
                        .textFieldStyle(.roundedBorder)
                        .help("Leave empty to use system hostname")
                }
            }
            
            Section("Security") {
                HStack {
                    Text("Master PW")
                        .frame(width: 100, alignment: .leading)
                    SecureField("Optional master password", text: $host.masterPassword)
                        .fontDesign(.monospaced)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Section("Options") {
                Toggle("Launch at login", isOn: $host.launchAtLogin)
            }
            
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
    }
    
    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            
            Text("remotyy")
                .font(.title2)
                .fontDesign(.monospaced)
                .fontWeight(.semibold)
            
            Text("Version 0.5.1")
                .foregroundColor(.secondary)
                .font(.caption)
            
            Text("Remote terminal & screen access via WebRTC")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Build Information")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Text("Binary:")
                        .foregroundColor(.secondary)
                    Text(Bundle.main.executableURL?.lastPathComponent ?? "unknown")
                        .fontDesign(.monospaced)
                }
                HStack {
                    Text("Daemon:")
                        .foregroundColor(.secondary)
                    Text("remotyy \(host.hostName)")
                        .fontDesign(.monospaced)
                }
            }
            .font(.caption)
            
            Spacer()
        }
        .padding()
    }
}
