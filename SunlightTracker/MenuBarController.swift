import AppKit
import SwiftUI

/// Status bar view: left-click toggles popover, right-click shows context menu (e.g. Quit).
private final class StatusBarView: NSView {
    var onLeftClick: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?

    private let imageView: NSImageView = {
        let iv = NSImageView()
        iv.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Sunlight Tracker")
        iv.image?.isTemplate = true
        iv.contentTintColor = .labelColor
        return iv
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        imageView.frame = bounds
    }

    override func mouseDown(with event: NSEvent) {
        if event.buttonNumber == 0 {
            onLeftClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }
}

/// Manages the menu bar status item and popover with sunlight stats.
final class MenuBarController: NSObject, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let sunlightService = SunlightService()
    private var clickMonitor: Any?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let statusItem = statusItem else { return }

        let view = StatusBarView(frame: NSRect(x: 0, y: 0, width: 22, height: 22))
        view.onLeftClick = { [weak self] in self?.togglePopover() }
        view.onRightClick = { [weak self] event in self?.showContextMenu(relativeTo: event) }
        statusItem.view = view
    }

    @objc private func togglePopover() {
        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showContextMenu(relativeTo event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Sunlight Tracker", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        guard let view = statusItem?.view else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: view)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showPopover() {
        guard let view = statusItem?.view else { return }

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

        popover?.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
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
