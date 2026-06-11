import AppKit

@MainActor
final class StatusBarController {
    /// Lives as long as AppDelegate keeps the controller; lets windows anchor
    /// themselves beneath the menu-bar icon.
    @MainActor private(set) static weak var shared: StatusBarController?

    // var, not let: setHidden recreates the item to bring back a dragged-off icon.
    private var item: NSStatusItem

    /// Screen frame of the status-bar button.
    var buttonScreenFrame: NSRect? {
        guard let button = item.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        MainActor.assumeIsolated { Self.shared = self }
        configure(item)
        item.isVisible = !SwitchPreferences.shared.hideMenuBarIcon
    }

    private func configure(_ item: NSStatusItem) {
        if let button = item.button {
            let img = NSImage(systemSymbolName: "square.on.square", accessibilityDescription: "Switch")
            img?.isTemplate = true
            button.image = img
        }

        let menu = NSMenu()

        let header = NSMenuItem(title: "Switch", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About Switch", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Switch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        item.menu = menu
    }

    // Showing recreates the item: macOS won't reliably bring back an icon the user dragged off via isVisible alone.
    func setHidden(_ hidden: Bool) {
        if hidden {
            item.isVisible = false
        } else {
            NSStatusBar.system.removeStatusItem(item)
            item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            configure(item)
            item.isVisible = true
        }
    }

    @objc private func showOnboarding() {
        NotificationCenter.default.post(name: .switchShowOnboarding, object: nil)
    }

    @objc private func openSettings() {
        MainActor.assumeIsolated { SettingsWindow.shared.show() }
    }

    @objc private func openAbout() {
        MainActor.assumeIsolated { AboutWindow.shared.show() }
    }
}

extension Notification.Name {
    static let switchShowOnboarding = Notification.Name("com.sanyamgarg.switch.showOnboarding")
}
