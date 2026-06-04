import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var host: HostManager
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundColor(host.isRunning ? .green : .gray)
                Text("remotyy")
                    .font(.headline)
                    .fontDesign(.monospaced)
                Spacer()
                statusBadge
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            // Status section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Status:")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(host.statusMessage)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundColor(hostColor)
                }
                
                if host.isRunning {
                    HStack {
                        Text("Host:")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(host.hostName.isEmpty ? ProcessInfo.processInfo.hostName : host.hostName)
                            .font(.caption)
                            .fontDesign(.monospaced)
                    }
                    HStack {
                        Text("Signal:")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(host.signalURL)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Action buttons
            VStack(spacing: 6) {
                if host.isRunning {
                    Button(action: host.stopHost) {
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
                
                Button(action: { showSettings = true }) {
                    Label("Settings...", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Label("Quit", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(width: 280)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(host)
                .frame(minWidth: 400, minHeight: 320)
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(host.isRunning ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            Text(host.isRunning ? "Online" : "Idle")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(host.isRunning ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var hostColor: Color {
        if host.statusMessage.contains("Failed") || host.statusMessage.contains("Crashed") {
            return .red
        } else if host.statusMessage.contains("Running") {
            return .green
        } else {
            return .secondary
        }
    }
}
