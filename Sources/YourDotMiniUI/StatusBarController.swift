import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menu = NSMenu()
    var onToggle: (() -> Void)?
    var onShow: (() -> Void)?
    var onExpand: (() -> Void)?
    var onReload: (() -> Void)?
    var onReturn: (() -> Void)?
    var onBrowser: (() -> Void)?
    var isExpanded: (() -> Bool)?
    var onSettings: (() -> Void)?
    var onPin: (() -> Void)?
    var isPinned: (() -> Bool)?
    var supportsEmbedded: (() -> Bool)?
    private var isShowingMenu = false

    override init() {
        super.init()
        if let button = item.button {
            button.image = MenuBarIcon.make()
            button.toolTip = "YourDotMini — click to show or hide; right-click for commands"
            button.setAccessibilityLabel("YourDotMini")
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        menu.delegate = self
        menu.autoenablesItems = false
        add("Open Dot", #selector(showDot))
        add("Expand Window", #selector(expand))
        add("Reload Dot", #selector(reload))
        add("Return to Dot", #selector(returnToDot))
        add("Open Dot in Default Browser", #selector(openBrowser))
        add("Keep Open", #selector(pin))
        menu.addItem(.separator())
        add("Settings…", #selector(settings), key: ",")
        add("About YourDotMini", #selector(about))
        add("Quit YourDotMini", #selector(quit), key: "q")
    }

    func anchor() -> (CGRect?, NSScreen?) {
        guard let button = item.button, let window = button.window else { return (nil, nil) }
        return (window.convertToScreen(button.convert(button.bounds, to: nil)), window.screen)
    }

    var isHandlingInteraction: Bool {
        if isShowingMenu { return true }
        guard let rect = anchor().0, rect.contains(NSEvent.mouseLocation) else { return false }
        return NSEvent.pressedMouseButtons & 0b11 != 0 || item.button?.isHighlighted == true
    }

    private func add(_ title: String, _ action: Selector, key: String = "") {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = self
        menu.addItem(menuItem)
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            if let button = item.button {
                isShowingMenu = true
                defer { isShowingMenu = false }
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY - 4), in: button)
            }
        } else {
            onToggle?()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items.first(where: { $0.action == #selector(expand) })?.title = isExpanded?() == true ? "Restore Window" : "Expand Window"
        menu.items.first(where: { $0.action == #selector(pin) })?.state = isPinned?() == true ? .on : .off
        for item in menu.items where [#selector(expand), #selector(reload), #selector(returnToDot), #selector(pin)].contains(item.action) {
            item.isEnabled = supportsEmbedded?() ?? true
        }
    }
    @objc private func showDot() { onShow?() }
    @objc private func expand() { onExpand?() }
    @objc private func reload() { onReload?() }
    @objc private func returnToDot() { onReturn?() }
    @objc private func openBrowser() { onBrowser?() }
    @objc private func settings() { onSettings?() }
    @objc private func pin() { onPin?() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "YourDotMini",
            .applicationVersion: "0.2.0 — Menu bar MVP",
            .credits: NSAttributedString(string: "An independent, unofficial companion for your ChatGPT dot. Not an OpenAI product. This app does not provide local-computer access; that feature still requires the official ChatGPT desktop app."),
        ])
    }
}
