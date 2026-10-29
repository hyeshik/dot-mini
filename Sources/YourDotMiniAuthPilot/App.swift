import AppKit
import PilotCore

@main
@MainActor
enum PilotApp {
    static func main() {
        // Launch the signed bundle, not `swift run`, to preserve sandbox identity.
        guard Bundle.main.bundleIdentifier == PilotIdentity.bundleIdentifier else {
            fputs("Build with scripts/build-pilot.sh, then open build/YourDotMiniAuthPilot.app.\n", stderr)
            exit(1)
        }
        let app = NSApplication.shared
        let delegate = PilotAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class PilotAppDelegate: NSObject, NSApplicationDelegate {
    private let diagnostics = PilotDiagnostics()
    private var pilot: PilotWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        diagnostics.record(.processStart)
        pilot = PilotWindowController(diagnostics: diagnostics)
        buildMenu()
        pilot.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        pilot.showPilot()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) { diagnostics.record(.processExit) }

    private func buildMenu() {
        let main = NSMenu()
        func submenu(_ title: String) -> NSMenu {
            let item = NSMenuItem()
            let menu = NSMenu(title: title)
            item.submenu = menu
            main.addItem(item)
            return menu
        }
        func item(_ menu: NSMenu, _ title: String, _ selector: Selector, key: String = "", target: AnyObject? = nil) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.target = target
            menu.addItem(item)
        }

        let app = submenu("YourDotMini Auth Pilot")
        item(app, "About YourDotMini Auth Pilot", #selector(showAbout), target: self)
        app.addItem(.separator())
        item(app, "Hide YourDotMini Auth Pilot", #selector(NSApplication.hide(_:)), key: "h", target: NSApp)
        app.addItem(.separator())
        item(app, "Quit Completely", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp)

        let file = submenu("Pilot")
        item(file, "Reload", #selector(PilotWindowController.reload), key: "r", target: pilot)
        item(file, "Return to Dot", #selector(PilotWindowController.returnToDot), target: pilot)
        item(file, "Open in Browser", #selector(PilotWindowController.openInBrowser), target: pilot)
        file.addItem(.separator())
        item(file, "Clear Pilot Website Data…", #selector(PilotWindowController.clearWebsiteData), target: pilot)

        let edit = submenu("Edit")
        item(edit, "Undo", Selector(("undo:")), key: "z")
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        item(edit, "Cut", #selector(NSText.cut(_:)), key: "x")
        item(edit, "Copy", #selector(NSText.copy(_:)), key: "c")
        item(edit, "Paste", #selector(NSText.paste(_:)), key: "v")
        item(edit, "Select All", #selector(NSText.selectAll(_:)), key: "a")

        let window = submenu("Window")
        item(window, "Show Pilot", #selector(PilotWindowController.showPilot), key: "0", target: pilot)
        item(window, "Hide Window (Keep Session)", #selector(PilotWindowController.hidePilot), key: "w", target: pilot)
        window.addItem(.separator())
        item(window, "480 × 720 Web Viewport", #selector(PilotWindowController.standardViewport), key: "1", target: pilot)
        item(window, "420 × 520 Web Viewport", #selector(PilotWindowController.compactViewport), key: "2", target: pilot)
        NSApp.windowsMenu = window
        NSApp.mainMenu = main
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "YourDotMini Auth Pilot",
            .applicationVersion: "0.1.0 — Phase 0",
            .credits: NSAttributedString(string: "Independent, unofficial WebKit feasibility pilot. Not an OpenAI product. Does not connect your computer to your dot. The official ChatGPT app is still required for its local-computer connection."),
        ])
    }
}
