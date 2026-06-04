import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var host: HostManager
    @State private var showSettings = false
    @State private var showQR = false
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(host: host)
            Divider()
            StatusSection(host: host)
            Divider()
            ActionButtons(host: host, showSettings: $showSettings, showQR: $showQR)
        }
        .frame(width: 280)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(host)
        }
        .sheet(isPresented: $showQR) {
            QRHostView(host: host)
                .frame(width: 320, height: 400)
        }
    }
}

// MARK: - Header

private struct HeaderView: View {
    @ObservedObject var host: HostManager
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(host.isRunning ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: "terminal.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(host.isRunning ? .green : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text("remotyy")
                    .font(.system(size: 13, weight: .semibold))
                    .fontDesign(.monospaced)
                
                Text(host.isRunning ? host.hostName : "Not connected")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            StatusBadge(isRunning: host.isRunning)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct StatusBadge: View {
    let isRunning: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isRunning ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            Text(isRunning ? "Online" : "Idle")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background((isRunning ? Color.green : Color.gray).opacity(0.1))
        .cornerRadius(3)
    }
}

// MARK: - Status

private struct StatusSection: View {
    @ObservedObject var host: HostManager
    
    var body: some View {
        VStack(spacing: 0) {
            StatusRow(label: "Status", value: host.statusMessage,
                      color: host.isRunning ? .green : host.statusMessage.contains("Failed") ? .red : .secondary)
            
            if host.isRunning {
                Divider().padding(.leading, 80)
                StatusRow(label: "Hostname", value: host.hostName.isEmpty ? ProcessInfo.processInfo.hostName : host.hostName)
                Divider().padding(.leading, 80)
                StatusRow(label: "Signal", value: host.signalURL)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct StatusRow: View {
    let label: String
    let value: String
    var color: Color = .secondary
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
            
            Text(value)
                .font(.system(size: 11).monospaced())
                .foregroundColor(color)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }
}

// MARK: - Actions

private struct ActionButtons: View {
    @ObservedObject var host: HostManager
    @Binding var showSettings: Bool
    @Binding var showQR: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            if host.isRunning {
                Button(role: .destructive, action: host.stopHost) {
                    Label("Stop Host", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            } else {
                Button(action: host.startHost) {
                    Label("Start Host", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            
            HStack(spacing: 6) {
                if host.isRunning {
                    Button(action: { showQR = true }) {
                        Label("QR Code", systemImage: "qrcode")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        if let url = URL(string: "http://localhost:9000") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Label("Web UI", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                Button(action: { showSettings = true }) {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: { NSApp.terminate(nil) }) {
                    Label("Quit", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
