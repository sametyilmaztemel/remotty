import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var signalURL: String = ""
    @State private var password: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Signaling Server") {
                    TextField("ws://host:port", text: $signalURL)
                        .fontDesign(.monospaced)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section("Authentication") {
                    SecureField("Master Password (optional)", text: $password)
                        .fontDesign(.monospaced)
                }
                
                Section {
                    Button(action: connect) {
                        HStack {
                            Spacer()
                            Text("Connect")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(signalURL.isEmpty)
                }
            }
            .navigationTitle("Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                signalURL = app.signalURL
            }
        }
    }
    
    private func connect() {
        app.signalURL = signalURL
        app.status = .connecting
        
        // TODO: Implement WebSocket connection
        // For now, simulate with mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            app.status = .connected
            app.hosts = [
                HostInfo(id: "1", name: "mac-studio", platform: "darwin", arch: "arm64", online: true, features: ["terminal", "screen"]),
                HostInfo(id: "2", name: "arm-oracle", platform: "linux", arch: "arm64", online: true, features: ["terminal"]),
            ]
            dismiss()
        }
    }
}
