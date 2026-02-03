import AppKit
import SwiftUI

/// Manages the menu bar status item and popover with sunlight stats.
final class MenuBarController: NSObject, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let sunlightService = SunlightService()
    private var clickMonitor: Any?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Sunlight Tracker")
        button.image?.isTemplate = true
        button.action = #selector(togglePopover)
        button.target = self
    }

    @objc private func togglePopover() {
        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }

        sunlightService.refresh()

        let contentView = StatsView(service: sunlightService)
            .environment(\.colorScheme, .dark)

        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = NSRect(x: 0, y: 0, width: 280, height: 340)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor

        if popover == nil {
            let pop = NSPopover()
            pop.contentSize = NSSize(width: 280, height: 340)
            pop.behavior = .transient
            pop.animates = true
            pop.contentViewController = NSViewController()
            pop.contentViewController?.view = hosting
            pop.contentViewController?.view.wantsLayer = true
            pop.delegate = self
            popover = pop
        } else {
            popover?.contentViewController?.view = hosting
        }

        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if let window = popover?.contentViewController?.view.window {
            window.isOpaque = false
            window.backgroundColor = .clear
        }
        startClickMonitor()
    }

    private func closePopover() {
        stopClickMonitor()
        popover?.performClose(nil)
    }

    private func startClickMonitor() {
        stopClickMonitor()
        let popoverWindow = popover?.contentViewController?.view.window
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            // If the click was outside the popover's window, close the popover.
            if event.window != popoverWindow {
                self.closePopover()
            }
            return event
        }
    }

    private func stopClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
}

extension MenuBarController: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        if let window = popover?.contentViewController?.view.window {
            window.isOpaque = false
            window.backgroundColor = .clear
        }
    }
}
