import AppKit
import Combine
import YourDotMiniCore

@MainActor
final class DotPanel: NSPanel {
    var onUnhandledCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { onUnhandledCancel?() }
}

@MainActor
final class DotWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
    let browser: DotBrowserController
    private let settings: SettingsStore
    var anchor: (() -> (CGRect?, NSScreen?))?
    var isStatusBarInteraction: (() -> Bool)?
    private(set) var visibility: WindowVisibility = .hidden
    private var restoreSize: CGSize?
    var isExpanded: Bool { restoreSize != nil }
    private let status = NSTextField(labelWithString: "")
    private var webViewBottomConstraint: NSLayoutConstraint?
    static let statusHeight: CGFloat = 30
    private var screenObserver: NSObjectProtocol?
    private var visibilityObservers: [NSObjectProtocol] = []
    private var settingsObserver: AnyCancellable?
    private var applyingFrame = false
    private var presentationRevision: UInt = 0
    private var occlusionCheck: Task<Void, Never>?

    init(browser: DotBrowserController, settings: SettingsStore) {
        self.browser = browser
        self.settings = settings
        let panel = DotPanel(contentRect: CGRect(origin: .zero, size: DotGeometry.defaultViewport),
                             styleMask: [.titled, .closable, .resizable, .miniaturizable],
                             backing: .buffered, defer: false)
        panel.title = "YourDotMini"
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        super.init(window: panel)
        panel.delegate = self
        let content = NSView()
        let webView = browser.webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        status.translatesAutoresizingMaskIntoConstraints = false
        status.font = .systemFont(ofSize: 11)
        status.lineBreakMode = .byTruncatingTail
        status.setAccessibilityLabel("Connection status")
        status.isHidden = true
        content.addSubview(webView)
        content.addSubview(status)
        let webViewBottom = webView.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        webViewBottomConstraint = webViewBottom
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: content.topAnchor),
            webView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            webViewBottom,
            status.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            status.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            status.centerYAnchor.constraint(equalTo: webView.bottomAnchor, constant: Self.statusHeight / 2),
        ])
        panel.contentView = content
        let toolbar = NSToolbar(identifier: "DotControls")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        panel.toolbar = toolbar
        panel.setContentSize(CGSize(width: settings.value.viewportWidth, height: settings.value.viewportHeight))
        panel.onUnhandledCancel = { [weak self] in self?.hideDot() }
        settingsObserver = settings.$value.sink { [weak self] value in
            guard let self else { return }
            self.browser.composerFocus.isEnabled = value.focusComposerOnShow
            guard let item = self.window?.toolbar?.items.first(where: { $0.itemIdentifier.rawValue == "pin" }) else { return }
            item.image = NSImage(systemSymbolName: value.keepOpen ? "pin.fill" : "pin", accessibilityDescription: "Keep Open")
        }
        browser.onStatus = { [weak self] text in
            self?.status.stringValue = text
            self?.status.toolTip = text.isEmpty ? nil : text
            self?.status.isHidden = text.isEmpty
            self?.webViewBottomConstraint?.constant = text.isEmpty ? 0 : -Self.statusHeight
        }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                 object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.clampToScreen() }
        }
        visibilityObservers = [NSApplication.didHideNotification, NSApplication.didUnhideNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateComposerVisibility() }
            }
        }
        visibilityObservers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleFocusLossDismissal() }
        })
    }

    required init?(coder: NSCoder) { fatalError("Not supported") }

    func toggle() {
        if NSApp.isHidden { showDot(); return }
        switch visibility.toggled {
        case .visible: showDot()
        case .hidden: hideDot()
        }
    }

    @objc func showDot() {
        showDot(activating: true)
    }

    // Explicit menu/hotkey actions activate; passive presentation only orders
    // this window and establishes its internal focus without changing apps.
    func showDot(activating: Bool) {
        guard let window else { return }
        presentationRevision &+= 1
        let (rect, anchoredScreen) = anchor?() ?? (nil, nil)
        let screen = anchoredScreen ?? window.screen ?? NSScreen.main ?? NSScreen.screens.first
        if let screen {
            updateSizeLimits(screen)
            let frame: CGRect
            if let x = settings.value.preferredX, let y = settings.value.preferredY {
                frame = DotGeometry.clamped(CGRect(origin: CGPoint(x: x, y: y), size: window.frame.size), to: screen.visibleFrame)
            } else {
                frame = DotGeometry.anchored(size: window.frame.size, below: rect, in: screen.visibleFrame)
            }
            applyFrame { window.setFrame(frame, display: false) }
        }
        if window.isMiniaturized { window.deminiaturize(nil) }
        if activating {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFront(nil)
        }
        visibility = .visible
        browser.loadIfNeeded()
        updateComposerVisibility()
        browser.diagnostics.record(.windowShown)
    }

    @objc func hideDot() {
        guard visibility != .hidden, window?.attachedSheet == nil, !browser.hasOwnedDialog else { return }
        presentationRevision &+= 1
        visibility = .hidden
        updateComposerVisibility()
        window?.orderOut(nil)
        browser.diagnostics.record(.windowHidden)
    }

    @objc func toggleExpanded() {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        updateSizeLimits(screen)
        if let restoreSize {
            self.restoreSize = nil
            let (rect, _) = anchor?() ?? (nil, nil)
            applyFrame { window.setFrame(DotGeometry.anchored(size: restoreSize, below: rect, in: screen.visibleFrame), display: true, animate: false) }
        } else {
            restoreSize = window.frame.size
            applyFrame { window.setFrame(screen.visibleFrame, display: true, animate: false) }
        }
        if visibility == .hidden { showDot() }
    }

    @objc func standardViewport() { resizeViewport(DotGeometry.defaultViewport) }
    @objc func compactViewport() { resizeViewport(DotGeometry.minimumViewport) }

    private func resizeViewport(_ size: CGSize) {
        restoreSize = nil
        settings.update { $0.viewportWidth = size.width; $0.viewportHeight = size.height; $0.preferredX = nil; $0.preferredY = nil }
        applyFrame { window?.setContentSize(size) }
        showDot()
    }

    private func updateSizeLimits(_ screen: NSScreen) {
        guard let window else { return }
        let minimum = window.frameRect(forContentRect: CGRect(origin: .zero, size: DotGeometry.minimumViewport)).size
        window.minSize = CGSize(width: min(minimum.width, screen.visibleFrame.width),
                                height: min(minimum.height, screen.visibleFrame.height))
        window.maxSize = screen.visibleFrame.size
    }

    private func clampToScreen() {
        guard let window, let screen = window.screen ?? anchor?().1 ?? NSScreen.main else { return }
        updateSizeLimits(screen)
        let frame = DotGeometry.clamped(window.frame, to: screen.visibleFrame)
        if frame != window.frame { applyFrame { window.setFrame(frame, display: visibility == .visible) } }
    }

    private func applyFrame(_ change: () -> Void) { applyingFrame = true; change(); applyingFrame = false }

    func windowDidMove(_ notification: Notification) {
        guard !applyingFrame, visibility == .visible, !isExpanded, let window else { return }
        settings.update { $0.preferredX = window.frame.minX; $0.preferredY = window.frame.minY }
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard !applyingFrame, !isExpanded else { return }
        // Remember the idle viewport even while a temporary status is visible.
        let size = window?.contentView?.bounds.size ?? browser.webView.bounds.size
        settings.update { $0.viewportWidth = size.width; $0.viewportHeight = size.height }
    }

    func windowDidResignKey(_ notification: Notification) {
        scheduleFocusLossDismissal()
    }

    private func scheduleFocusLossDismissal() {
        // A status-item mouse-down can resign key before its mouse-up action.
        // Let that action toggle the existing state instead of hiding here and
        // immediately reopening on mouse-up. Capture this before deferring.
        guard isStatusBarInteraction?() != true else { return }
        let revision = presentationRevision
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window, !window.isKeyWindow,
                  self.presentationRevision == revision, self.visibility == .visible,
                  self.isStatusBarInteraction?() != true,
                  self.settings.value.hideOnFocusLoss, !self.settings.value.keepOpen,
                  !self.browser.hasOwnedDialog, window.attachedSheet == nil,
                  !(NSApp.isActive && NSApp.windows.contains(where: { $0 !== window && $0.isKeyWindow })) else { return }
            self.hideDot()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { hideDot(); return false }
    func windowDidChangeScreen(_ notification: Notification) { clampToScreen() }
    func windowDidMiniaturize(_ notification: Notification) {
        visibility = .hidden
        updateComposerVisibility()
    }
    func windowDidDeminiaturize(_ notification: Notification) {
        visibility = .visible
        updateComposerVisibility()
    }
    func windowDidChangeOcclusionState(_ notification: Notification) { updateComposerVisibility() }

    private func updateComposerVisibility() {
        guard let window else { return }
        occlusionCheck?.cancel()
        occlusionCheck = nil
        guard visibility == .visible, window.isVisible, !window.isMiniaturized, !NSApp.isHidden else {
            browser.composerFocus.setPresented(false)
            return
        }
        if window.occlusionState.contains(.visible) {
            browser.composerFocus.setPresented(true)
        } else if browser.composerFocus.isPresented {
            // Reordering/resizing can briefly clear the WindowServer visibility
            // bit even though the user still sees the same window. Only a stable
            // occlusion begins a new appearance; explicit hide/minimize is immediate.
            occlusionCheck = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                guard !Task.isCancelled, let self, let window = self.window,
                      !window.occlusionState.contains(.visible) else { return }
                self.browser.composerFocus.setPresented(false)
                self.occlusionCheck = nil
            }
        }
    }

    @objc func reload() { browser.reload() }
    @objc func returnToDot() { browser.returnToDot() }
    @objc func openInBrowser() { browser.openInBrowser() }
    @objc func togglePinned() { settings.update { $0.keepOpen.toggle() } }

    private let toolbarItems: [(String, String, String, Selector)] = [
        ("dot", "Return to Dot", "house", #selector(returnToDot)),
        ("reload", "Reload Dot", "arrow.clockwise", #selector(reload)),
        ("browser", "Open Dot in Default Browser", "safari", #selector(openInBrowser)),
        ("expand", "Expand / Restore Window", "arrow.up.left.and.arrow.down.right", #selector(toggleExpanded)),
        ("pin", "Keep Open", "pin", #selector(togglePinned)),
    ]

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarItems.map { NSToolbarItem.Identifier($0.0) }
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarAllowedItemIdentifiers(toolbar) }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let definition = toolbarItems.first(where: { $0.0 == identifier.rawValue }) else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = definition.1
        item.toolTip = definition.1
        item.image = NSImage(systemSymbolName: definition.2, accessibilityDescription: definition.1)
        if identifier.rawValue == "pin", settings.value.keepOpen {
            item.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Keep Open")
        }
        item.target = self
        item.action = definition.3
        return item
    }
}
