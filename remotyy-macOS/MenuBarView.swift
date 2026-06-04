import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var host: HostManager
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(isRunning: host.isRunning, hostname: host.hostName)
            
            Divider()
            
            StatusSection(host: host)
            
            Divider()
            
            ActionButtons(
                isRunning: host.isRunning,
                onStart: host.startHost,
                onStop: host.stopHost,
                onSettings: { showSettings = true }
            )
        }
        .frame(width: 300)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(host)
                .frame(minWidth: 420, minHeight: 300)
        }
    }
}

// MARK: - Components

private struct HeaderView: View {
    let isRunning: Bool
    let hostname: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal.fill")
                .font(.title3)
                .foregroundColor(isRunning ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("remotyy")
                    .font(.headline)
                    .fontDesign(.monospaced)
                Text(isRunning ? hostname : "Not connected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            StatusBadge(isRunning: isRunning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct StatusBadge: View {
    let isRunning: Bool
    
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isRunning ? Color.green : Color.gray)
                .frame(width: 7, height: 7)
            Text(isRunning ? "Online" : "Idle")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background((isRunning ? Color.green : Color.gray).opacity(0.1))
        .cornerRadius(4)
    }
}

private struct StatusSection: View {
    @ObservedObject var host: HostManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Status") {
                Text(host.statusMessage)
                    .font(.caption.monospaced())
                    .foregroundColor(statusColor)
            }
            
            if host.isRunning {
                LabeledContent("Hostname") {
                    Text(host.hostName)
                        .font(.caption.monospaced())
                }
                LabeledContent("Signal") {
                    Text(host.signalURL)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var statusColor: Color {
        if host.statusMessage.contains("Failed") || host.statusMessage.contains("Crashed") {
            return .red
        } else if host.isRunning {
            return .green
        }
        return .secondary
    }
}

private struct ActionButtons: View {
    let isRunning: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            if isRunning {
                Button(action: onStop) {
                    Label("Stop Host", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            } else {
                Button(action: onStart) {
                    Label("Start Host", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            
            HStack(spacing: 6) {
                Button(action: onSettings) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .controlSize(.regular)
    }
}
