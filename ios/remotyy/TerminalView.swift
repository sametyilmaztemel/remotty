import SwiftUI
import UIKit

struct TerminalView: View {
    let host: HostInfo
    @EnvironmentObject private var app: AppState

    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var connectionState: WebRTCState = .disconnected

    // Scroll handling
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            // Terminal Output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Text(outputText.isEmpty ? placeholderText : outputText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(outputColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(8)
                            .id("bottom")
                    }
                }
                .background(Color(white: 0.05))
                .onChange(of: outputText) { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("bottom")
                    }
                }
                .onAppear {
                    scrollProxy = proxy
                }
                // Tap anywhere to focus input
                .onTapGesture {
                    // focus the text field programmatically
                }
            }

            Divider()

            // Input Bar
            HStack(spacing: 8) {
                TextField("Enter command...", text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit(sendCommand)
                    .disabled(connectionState != .connected)

                Button(action: sendCommand) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(inputText.isEmpty || connectionState != .connected)
            }
            .padding()
            .background(Color(.systemGray6))
        }
        .navigationTitle(host.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(connectionIndicatorColor)
                        .frame(width: 8, height: 8)
                    Text(connectionIndicatorText)
                        .font(.caption2)
                }
            }
        }
        .onAppear {
            connectToHost()
        }
        .onDisappear {
            disconnectFromHost()
        }
    }

    // MARK: - Helpers

    private var placeholderText: String {
        switch connectionState {
        case .connecting:
            return "Connecting to \(host.name)...\n"
        case .disconnected:
            return "Disconnected from \(host.name)\n"
        case .error(let msg):
            return "Error: \(msg)\n"
        case .connected:
            return "Connected to \(host.name)\n$ "
        }
    }

    private var outputColor: Color {
        connectionState == .connected ? Color(white: 0.85) : Color(white: 0.45)
    }

    private var connectionIndicatorColor: Color {
        switch connectionState {
        case .disconnected: return .gray
        case .connecting:   return .yellow
        case .connected:    return .green
        case .error:        return .red
        }
    }

    private var connectionIndicatorText: String {
        switch connectionState {
        case .disconnected: return "Disconnected"
        case .connecting:   return "Connecting..."
        case .connected:    return "Connected"
        case .error(let msg): return msg
        }
    }

    // MARK: - Connection

    private func connectToHost() {
        connectionState = .connecting

        // Set up WebRTC service callbacks
        app.webRTCService.delegate = nil // Will use closure-based observation
        app.webRTCService.connect(
            signalURL: app.signalURL,
            hostID: host.id,
            password: nil
        )

        // Observe connection state via Combine
        // We use a simple polling approach for the @Published property
        DispatchQueue.main.async { [weak self] in
            self?.pollConnectionState()
        }

        // Observe terminal output
        DispatchQueue.main.async { [weak self] in
            self?.pollTerminalOutput()
        }
    }

    private func disconnectFromHost() {
        app.webRTCService.disconnect()
    }

    /// Poll the WebRTC service's published connection state.
    private func pollConnectionState() {
        guard connectionState.connectedOrConnecting else { return }

        let newState = app.webRTCService.state
        if newState != connectionState {
            connectionState = newState
            if newState == .connected {
                // Send terminal resize on connect
                sendTerminalResize()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.pollConnectionState()
        }
    }

    /// Poll for new terminal output.
    private func pollTerminalOutput() {
        guard connectionState.connectedOrConnecting else { return }

        let output = app.webRTCService.terminalOutput
        if !output.isEmpty && !outputText.hasSuffix(output) {
            outputText = output
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.pollTerminalOutput()
        }
    }

    // MARK: - Commands

    private func sendCommand() {
        guard !inputText.isEmpty, connectionState == .connected else { return }

        let cmd = inputText + "\n"
        outputText += "$ " + inputText + "\n"
        app.webRTCService.sendTerminalInput(cmd)
        inputText = ""
    }

    private func sendTerminalResize() {
        // Approximate terminal size: 80 cols × 24 rows
        app.webRTCService.sendTerminalResize(rows: 24, cols: 80)
    }
}

// MARK: - WebRTCState convenience

private extension WebRTCState {
    var connectedOrConnecting: Bool {
        switch self {
        case .connected, .connecting: return true
        case .disconnected, .error:   return false
        }
    }
}
