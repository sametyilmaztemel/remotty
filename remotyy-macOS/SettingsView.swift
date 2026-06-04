import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var host: HostManager
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case about = "About"
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(host: host)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)
            
            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 440, height: 320)
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @ObservedObject var host: HostManager
    
    var body: some View {
        Form {
            Section {
                HStack(spacing: 0) {
                    Text("Signal URL")
                        .font(.body)
                        .frame(width: 100, alignment: .trailing)
                    TextField("ws://localhost:9000", text: $host.signalURL)
                        .font(.body.monospaced())
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                        .frame(maxWidth: .infinity)
                }
                
                HStack(spacing: 0) {
                    Text("Hostname")
                        .font(.body)
                        .frame(width: 100, alignment: .trailing)
                    TextField("", text: $host.hostName)
                        .font(.body.monospaced())
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                        .frame(maxWidth: .infinity)
                }
            } header: {
                Label("Connection", systemImage: "network")
                    .font(.headline)
            }
            
            Section {
                HStack(spacing: 0) {
                    Text("Master PW")
                        .font(.body)
                        .frame(width: 100, alignment: .trailing)
                    SecureField("Optional", text: $host.masterPassword)
                        .font(.body.monospaced())
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                }
            } header: {
                Label("Security", systemImage: "lock")
                    .font(.headline)
            }
            
            Section {
                Toggle(isOn: $host.launchAtLogin) {
                    Text("Launch at login")
                        .font(.body)
                }
                .toggleStyle(.switch)
                .padding(.leading, 100)
            } header: {
                Label("Options", systemImage: "gearshape.2")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About

private struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Image(systemName: "terminal.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Spacer().frame(height: 16)
            
            Text("remotyy")
                .font(.system(size: 22, weight: .semibold))
                .fontDesign(.monospaced)
            
            Text("Version 0.5.1")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.top, 2)
            
            Text("Remote terminal & screen access via WebRTC")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .frame(width: 240)
            
            Spacer().frame(height: 24)
            
            VStack(spacing: 8) {
                InfoRow(label: "Architecture", value: "arm64")
                InfoRow(label: "macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
                InfoRow(label: "License", value: "MIT")
            }
            .frame(width: 240)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11).monospaced())
        }
    }
}
