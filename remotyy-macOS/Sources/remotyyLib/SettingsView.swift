import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var host: HostManager
    
    public init() {}
    
    public var body: some View {
        TabView {
            Form {
                Section {
                    LabeledContent("Signal URL") {
                        TextField("ws://localhost:9000", text: $host.signalURL)
                            .font(.body.monospaced())
                            .textFieldStyle(.roundedBorder)
                            .disableAutocorrection(true)
                    }
                    LabeledContent("Hostname") {
                        TextField("", text: $host.hostName)
                            .font(.body.monospaced())
                            .textFieldStyle(.roundedBorder)
                            .disableAutocorrection(true)
                    }
                } header: {
                    Label("Connection", systemImage: "network")
                }
                
                Section {
                    LabeledContent("Master PW") {
                        SecureField("Optional", text: $host.masterPassword)
                            .font(.body.monospaced())
                            .textFieldStyle(.roundedBorder)
                    }
                } header: {
                    Label("Security", systemImage: "lock")
                }
                
                Section {
                    Toggle(isOn: $host.launchAtLogin) {
                        Text("Launch at login")
                    }
                    .toggleStyle(.switch)
                } header: {
                    Label("Options", systemImage: "gearshape.2")
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }
            
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "terminal.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                Text("remotyy").font(.title2).fontDesign(.monospaced).fontWeight(.semibold)
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")").font(.caption).foregroundColor(.secondary)
                Text("Remote terminal & screen access via WebRTC")
                    .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                    .frame(width: 220)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding()
    }
}
