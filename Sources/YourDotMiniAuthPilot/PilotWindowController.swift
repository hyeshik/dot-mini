import AppKit
import WebKit
import PilotCore

@MainActor
final class PilotWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate, NSMenuItemValidation {
    // This view and its data store live until the application process exits.
    let webView: WKWebView
    let diagnostics: PilotDiagnostics
    var navigationPolicy = NavigationPolicy()
    var isClearingData = false
    private let statusLabel = NSTextField(labelWithString: "Unofficial authentication pilot — loading…")
    private static let statusHeight: CGFloat = 34

    init(diagnostics: PilotDiagnostics) {
        self.diagnostics = diagnostics
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: .zero, configuration: configuration)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 720 + Self.statusHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "YourDotMini Auth Pilot — Unofficial"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 420, height: 520 + Self.statusHeight)
        super.init(window: window)
        window.delegate = self
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        let content = NSView()
        webView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.setAccessibilityLabel("Pilot status")
        content.addSubview(webView)
        content.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: content.topAnchor),
            webView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Self.statusHeight),
            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: webView.bottomAnchor, constant: Self.statusHeight / 2),
        ])
        window.contentView = content
        let toolbar = NSToolbar(identifier: "PilotControls")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        window.setContentSize(NSSize(width: 480, height: 720 + Self.statusHeight))
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("Not supported") }

    func start() {
        showPilot()
        returnToDot()
    }

    @objc func showPilot() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(webView)
        diagnostics.record(.windowShown)
    }

    @objc func hidePilot() {
        window?.orderOut(nil)
        diagnostics.record(.windowHidden)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hidePilot()
        return false
    }

    @objc func reload() {
        guard !isClearingData else { return }
        if webView.url == nil { returnToDot() } else { webView.reload() }
    }

    @objc func returnToDot() {
        guard !isClearingData else { return }
        webView.load(URLRequest(url: PilotIdentity.entryURL))
    }

    @objc func openInBrowser() { openBrowser(PilotIdentity.entryURL) }

    func openBrowser(_ url: URL) {
        let opened = NSWorkspace.shared.open(url)
        diagnostics.record(opened ? .browserOpened : .browserOpenFailed, url: url)
        setStatus(opened ? "Opened in browser. Browser and pilot sign-ins are separate." : "Could not open the default browser.")
    }

    @objc func clearWebsiteData() {
        guard !isClearingData, let window else { return }
        let alert = NSAlert()
        alert.messageText = "Clear Pilot Website Data?"
        alert.informativeText = "This signs you out of this pilot and removes its cookies, caches, and website storage. Unsent text may be lost. Browser data and server-side ChatGPT history are unaffected."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Clear Pilot Website Data")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertSecondButtonReturn, let self else { return }
            self.isClearingData = true
            self.diagnostics.record(.dataClearStarted)
            self.setStatus("Clearing pilot website data…")
            self.webView.stopLoading()
            // Replace the active page before deletion so it cannot immediately
            // write its authentication state back into the store being cleared.
            self.webView.load(URLRequest(url: URL(string: "about:blank")!))
        }
    }

    func finishClearingData() {
        webView.configuration.websiteDataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast
        ) { [weak self] in
            guard let self else { return }
            self.navigationPolicy = NavigationPolicy()
            self.isClearingData = false
            self.diagnostics.record(.dataClearFinished)
            self.setStatus("Pilot website data cleared. Loading a fresh session…")
            self.returnToDot()
        }
    }

    @objc func standardViewport() { resizeViewport(width: 480, height: 720) }
    @objc func compactViewport() { resizeViewport(width: 420, height: 520) }

    private func resizeViewport(width: CGFloat, height: CGFloat) {
        window?.setContentSize(NSSize(width: width, height: height + Self.statusHeight))
        showPilot()
    }

    func setStatus(_ text: String) {
        statusLabel.stringValue = text
        statusLabel.toolTip = text
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if [#selector(reload), #selector(returnToDot), #selector(clearWebsiteData)].contains(menuItem.action) {
            return !isClearingData
        }
        return true
    }

    private let toolbarItems: [(String, String, String, Selector)] = [
        ("reload", "Reload", "arrow.clockwise", #selector(reload)),
        ("dot", "Return to Dot", "house", #selector(returnToDot)),
        ("browser", "Open in Browser", "safari", #selector(openInBrowser)),
    ]

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarItems.map { NSToolbarItem.Identifier($0.0) }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let definition = toolbarItems.first(where: { $0.0 == identifier.rawValue }) else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = definition.1
        item.image = NSImage(systemSymbolName: definition.2, accessibilityDescription: definition.1)
        item.target = self
        item.action = definition.3
        return item
    }
}
