import AppKit
import SwiftUI

/// Settings window host. Close demotes in case Sparkle promoted to .regular.
@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()

    private var window: NSWindow?
    private var demoteWork: DispatchWorkItem?

    var isVisible: Bool { window?.isVisible == true }

    private init() {}

    func show() {
        demoteWork?.cancel()
        demoteWork = nil
        // Stays .accessory: an inactive .regular app's activate() calls are ignored, breaking switching.

        if let existing = window {
            NSApp.activate()
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            return
        }

        let host = NSHostingController(rootView: SettingsView())
        let win = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Switch Settings"
        win.contentViewController = host
        // Size to the SwiftUI content before the window becomes visible —
        // otherwise it shows up at a stale size and snaps to fit one frame
        // later (visible flicker).
        host.view.layoutSubtreeIfNeeded()
        win.setContentSize(host.view.fittingSize)
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = SettingsWindowDelegate.shared

        window = win
        NSApp.activate()
        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
    }

    func handleClose() {
        window = nil
        demoteWork?.cancel()
        let work = DispatchWorkItem {
            NSApp.setActivationPolicy(.accessory)
        }
        demoteWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
}

private final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            SettingsWindow.shared.handleClose()
        }
    }
}
