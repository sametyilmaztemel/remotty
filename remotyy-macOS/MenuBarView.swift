import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var host: HostManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundColor(host.isRunning ? .green : .gray)
                Text("remotyy")
                    .font(.headline)
                    .fontDesign(.monospaced)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            // Status
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Status") {
                    Text(host.statusMessage)
                        .foregroundColor(host.isRunning ? .green : .secondary)
                }
                if host.isRunning {
                    LabeledContent("Hostname") {
                        Text(host.hostName.isEmpty ? ProcessInfo.processInfo.hostName : host.hostName)
                            .fontDesign(.monospaced)
                    }
                    LabeledContent("Signal") {
                        Text(host.signalURL)
                            .fontDesign(.monospaced)
                            .foregroundColor(.secondary)
                    }
                    LabeledContent("Sessions") {
                        Text("\(host.sessionCount)")
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Actions
            VStack(spacing: 8) {
                if host.isRunning {
                    Button(action: host.stopHost) {
                        Label("Stop Host", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button(action: host.startHost) {
                        Label("Start Host", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button(action: { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }) {
                    Label("Settings...", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Label("Quit", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .frame(width: 280)
    }
}
