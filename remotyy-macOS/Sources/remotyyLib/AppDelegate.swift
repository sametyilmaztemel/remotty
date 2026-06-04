import Cocoa
import Combine
import SwiftUI

// MARK: - AppDelegate

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    public var statusItem: NSStatusItem!
    public let hostManager = HostManager()
    private var cancellables = Set<AnyCancellable>()

    // MARK: Application Lifecycle

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        // Observe host state for dynamic icon
        hostManager.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)
    }

    // MARK: Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "remotyy")
        button.action = #selector(handleClick)
        // Both left-click and right-click trigger the same handler
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        updateIcon()
    }

    public func updateIcon() {
        guard let button = statusItem.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "remotyy")?
            .withSymbolConfiguration(config)
        button.image = image
        // Green tint when running, labelColor (adaptive) when stopped
        button.contentTintColor = hostManager.isRunning ? .systemGreen : .labelColor
    }

    // MARK: Click Handling

    @objc private func handleClick() {
        guard let button = statusItem.button else { return }
        let menu = buildMenu()
        menu.delegate = self
        // Show menu positioned below the status item button
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }

    public func menuDidClose(_ menu: NSMenu) {
        // No cleanup needed — we rebuild the menu fresh each time
    }

    // MARK: Menu Building

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // ── Status header ──
        let statusTitle = hostManager.isRunning ? "\u{25CF}  Running" : "\u{25CB}  Stopped"
        let statusAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: hostManager.isRunning ? NSColor.systemGreen : NSColor.secondaryLabelColor,
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
        ]
        let statusItem = NSMenuItem()
        statusItem.attributedTitle = NSAttributedString(string: statusTitle, attributes: statusAttr)
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        // ── Start / Stop Host ──
        if hostManager.isRunning {
            let stopItem = NSMenuItem(
                title: "Stop Host",
                action: #selector(toggleHost),
                keyEquivalent: ""
            )
            stopItem.target = self
            stopItem.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: nil)
            menu.addItem(stopItem)
        } else {
            let startItem = NSMenuItem(
                title: "Start Host",
                action: #selector(toggleHost),
                keyEquivalent: ""
            )
            startItem.target = self
            startItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
            menu.addItem(startItem)
        }

        menu.addItem(NSMenuItem.separator())

        // ── Open Web UI ──
        let webItem = NSMenuItem(
            title: "Open Web UI",
            action: #selector(openWebUI),
            keyEquivalent: "w"
        )
        webItem.target = self
        webItem.keyEquivalentModifierMask = [.command, .control]
        webItem.image = NSImage(systemSymbolName: "safari", accessibilityDescription: nil)
        webItem.isEnabled = hostManager.isRunning
        menu.addItem(webItem)

        // ── Screen Sharing ──
        if hostManager.screenSharing {
            let stopScreenItem = NSMenuItem(
                title: "Stop Screen Sharing",
                action: #selector(toggleScreenShare),
                keyEquivalent: ""
            )
            stopScreenItem.target = self
            stopScreenItem.image = NSImage(systemSymbolName: "stop.circle", accessibilityDescription: nil)
            stopScreenItem.isEnabled = hostManager.isRunning
            menu.addItem(stopScreenItem)
        } else {
            let startScreenItem = NSMenuItem(
                title: "Start Screen Sharing",
                action: #selector(toggleScreenShare),
                keyEquivalent: ""
            )
            startScreenItem.target = self
            startScreenItem.image = NSImage(
                systemSymbolName: "rectangle.connected.to.line.below",
                accessibilityDescription: nil
            )
            startScreenItem.isEnabled = hostManager.isRunning
            menu.addItem(startScreenItem)
        }

        menu.addItem(NSMenuItem.separator())

        // ── Settings ──
        let settingsItem = NSMenuItem(
            title: "Settings\u{2026}",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        // ── Quit ──
        let quitItem = NSMenuItem(
            title: "Quit remotyy",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)
        menu.addItem(quitItem)

        return menu
    }

    // MARK: Actions

    @objc func toggleHost() {
        if hostManager.isRunning {
            hostManager.stopHost()
        } else {
            hostManager.startHost()
        }
        // Icon update handled by Combine observer
    }

    @objc func openWebUI() {
        guard let url = URL(string: "http://localhost:9000") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func toggleScreenShare() {
        hostManager.toggleScreenShare()
    }

    @objc func openSettings() {
        // Opens SwiftUI Settings scene registered in remotyyApp
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
