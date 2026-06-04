import SwiftUI
import remotyyLib

@main
struct remotyyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.hostManager)
        }
    }
}
