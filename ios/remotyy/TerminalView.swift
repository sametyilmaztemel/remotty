import SwiftUI
import WebKit

struct TerminalView: View {
    let host: HostInfo
    @EnvironmentObject private var app: AppState
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var isConnected = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal Output
            ScrollViewReader { proxy in
                ScrollView {
                    Text(outputText.isEmpty ? "Connecting to \(host.name)..." : outputText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Color(white: 0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .id("bottom")
                }
                .background(Color(white: 0.05))
                .onChange(of: outputText) { _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }
            
            Divider()
            
            // Input Bar
            HStack {
                TextField("Enter command...", text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .onSubmit(sendCommand)
                
                Button(action: sendCommand) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(inputText.isEmpty)
            }
            .padding()
            .background(Color(.systemGray6))
        }
        .navigationTitle(host.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Circle()
                        .fill(isConnected ? Color.green : Color.yellow)
                        .frame(width: 8, height: 8)
                    Text(isConnected ? "Connected" : "Connecting...")
                        .font(.caption)
                }
            }
        }
        .onAppear {
            connectToHost()
        }
    }
    
    private func connectToHost() {
        // TODO: Establish WebRTC connection to host
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isConnected = true
            outputText = "Welcome to \(host.name)\n\n$ "
        }
    }
    
    private func sendCommand() {
        guard !inputText.isEmpty else { return }
        outputText += inputText + "\n"
        // TODO: Send via WebRTC data channel
        inputText = ""
    }
}
