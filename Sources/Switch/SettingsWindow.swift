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
        position(win)
        win.isReleasedWhenClosed = false
        win.delegate = SettingsWindowDelegate.shared

        window = win
        NSApp.activate()
        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
        // Don't let AppKit hand initial key focus to the first tab button —
        // the focus ring on "General" reads as a glitch.
        win.makeFirstResponder(nil)
    }

    /// Anchor below the menu-bar icon (menu-extra style); fall back to the
    /// top-right corner of the screen, then to plain centering.
    private func position(_ win: NSWindow) {
        let anchor = StatusBarController.shared?.buttonScreenFrame
        let screen = anchor.flatMap { a in NSScreen.screens.first { $0.frame.intersects(a) } }
            ?? NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else {
            win.center()
            return
        }
        var origin: NSPoint
        if let anchor {
            origin = NSPoint(
                x: anchor.midX - win.frame.width / 2,
                y: anchor.minY - win.frame.height - 8
            )
        } else {
            origin = NSPoint(
                x: visible.maxX - win.frame.width - 16,
                y: visible.maxY - win.frame.height - 16
            )
        }
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - win.frame.width - 8)
        win.setFrameOrigin(origin)
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
