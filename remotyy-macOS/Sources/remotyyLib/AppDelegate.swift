import Cocoa
import Combine
import OSLog

let Log = OSLog(subsystem: "com.remotyy.macos", category: "general")

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public let hostManager = HostManager()
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        // Set the image on the status item button
        updateIcon()

        // Observe host state for dynamic icon
        hostManager.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let img = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "remotyy")
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.image = img?.withSymbolConfiguration(config)
        button.contentTintColor = hostManager.isRunning ? .systemGreen : .controlTextColor
        // Remove any old menu reference so the click handler fires
        statusItem.menu = nil
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleClick() {
        statusItem.menu = buildMenu()
        // performClick triggers the menu display via the status item's menu
        statusItem.button?.performClick(nil)
    }

    public func menuDidClose(_: NSMenu) {
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        // Status header
        let statusItem = NSMenuItem()
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: hostManager.isRunning ? NSColor.systemGreen : NSColor.secondaryLabelColor,
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
        ]
        statusItem.attributedTitle = NSAttributedString(
            string: hostManager.isRunning ? "\u{25CF}  Running" : "\u{25CB}  Stopped",
            attributes: attrs
        )
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(.separator())

        // Start / Stop Host
        let toggleTitle = hostManager.isRunning ? "Stop Host" : "Start Host"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleHost), keyEquivalent: "h")
        toggleItem.target = self
        toggleItem.keyEquivalentModifierMask = [.command, .control]
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        // Open Web UI
        let webItem = NSMenuItem(title: "Open Web UI", action: #selector(openWebUI), keyEquivalent: "w")
        webItem.target = self
        webItem.keyEquivalentModifierMask = [.command, .control]
        webItem.isEnabled = hostManager.isRunning
        menu.addItem(webItem)

        // Screen Sharing
        let screenTitle = hostManager.screenSharing ? "Stop Screen Sharing" : "Start Screen Sharing"
        let screenItem = NSMenuItem(title: screenTitle, action: #selector(toggleScreenShare), keyEquivalent: "s")
        screenItem.target = self
        screenItem.keyEquivalentModifierMask = [.command, .control]
        screenItem.isEnabled = hostManager.isRunning
        menu.addItem(screenItem)

        menu.addItem(.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit remotyy", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Actions

    @objc func toggleHost() {
        if hostManager.isRunning { hostManager.stopHost() }
        else { hostManager.startHost() }
    }

    @objc func openWebUI() {
        guard let url = URL(string: "http://localhost:9000") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func toggleScreenShare() {
        hostManager.toggleScreenShare()
    }

    @objc func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc func quitApp() {
        hostManager.stopHost()
        NSApp.terminate(nil)
    }
}
