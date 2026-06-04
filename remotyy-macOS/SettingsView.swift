import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var host: HostManager
    
    var body: some View {
        TabView {
            Form {
                Section {
                    LabeledContent("Signal URL") {
                        TextField("ws://host:port", text: $host.signalURL)
                            .font(.caption.monospaced())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 240)
                    }
                    
                    LabeledContent("Hostname") {
                        TextField("", text: $host.hostName)
                            .font(.caption.monospaced())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 240)
                    }
                } header: {
                    Label("Connection", systemImage: "network")
                }
                
                Section {
                    LabeledContent("Master PW") {
                        SecureField("Optional master password", text: $host.masterPassword)
                            .font(.caption.monospaced())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 240)
                    }
                } header: {
                    Label("Security", systemImage: "lock")
                }
                
                Section {
                    Toggle("Launch at login", isOn: $host.launchAtLogin)
                        .toggleStyle(.switch)
                } header: {
                    Label("Options", systemImage: "gearshape.2")
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            
            // About tab
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "terminal.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 4) {
                    Text("remotyy")
                        .font(.title2)
                        .fontDesign(.monospaced)
                        .fontWeight(.semibold)
                    Text("Version 0.5.1")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Remote terminal & screen access via WebRTC")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Divider()
                    .frame(width: 200)
                
                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent("Architecture") {
                        Text("arm64")
                            .font(.caption.monospaced())
                    }
                    .frame(width: 200)
                    LabeledContent("macOS") {
                        Text(ProcessInfo.processInfo.operatingSystemVersionString)
                            .font(.caption.monospaced())
                    }
                    .frame(width: 200)
                }
                
                Spacer()
            }
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .padding()
    }
}
