import AppKit
import YourDotMiniCore

@MainActor
public final class MenuBarAppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private let diagnostics = DotDiagnostics()
    private let settings = SettingsStore()
    private let hotKey = GlobalHotKeyService()
    private let login = LaunchAtLoginService()
    private lazy var fallback = BrowserFallbackCoordinator(settings: settings)
    private var statusBar: StatusBarController!
    private var dotWindow: DotWindowController?
    private var settingsWindow: SettingsWindowController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        diagnostics.record(.processStart)
        statusBar = StatusBarController()
        statusBar.onToggle = { [weak self] in self?.toggleDot() }
        statusBar.onShow = { [weak self] in self?.showDot() }
        statusBar.onExpand = { [weak self] in self?.ensureWindow().toggleExpanded() }
        statusBar.onReload = { [weak self] in self?.ensureWindow().reload() }
        statusBar.onReturn = { [weak self] in self?.ensureWindow().returnToDot() }
        statusBar.onBrowser = { [weak self] in self?.ensureWindow().openInBrowser() }
        statusBar.isExpanded = { [weak self] in self?.dotWindow?.isExpanded ?? false }
        statusBar.onSettings = { [weak self] in self?.showSettings() }
        statusBar.onPin = { [weak self] in self?.settings.update { $0.keepOpen.toggle() } }
        statusBar.isPinned = { [weak self] in self?.settings.value.keepOpen ?? false }
        statusBar.supportsEmbedded = { [weak self] in self?.settings.value.browsingMode == .embedded }
        hotKey.onPressed = { [weak self] in
            self?.diagnostics.record(.shortcutPressed)
            self?.toggleDot()
        }
        _ = hotKey.apply(settings.value.shortcut)
        buildApplicationMenu()
        if !settings.value.hasCompletedOnboarding { showSettings() }
        else if settings.value.preloadAtLaunch && settings.value.browsingMode == .embedded {
            ensureWindow().browser.loadIfNeeded()
        }
    }

    private func ensureWindow() -> DotWindowController {
        if let dotWindow { return dotWindow }
        let browser = DotBrowserController(diagnostics: diagnostics)
        browser.entryURL = DotEntryURL.validate(settings.value.entryURL) ?? DotIdentity.entryURL
        let controller = DotWindowController(browser: browser, settings: settings)
        controller.anchor = { [weak self] in self?.statusBar.anchor() ?? (nil, nil) }
        controller.isStatusBarInteraction = { [weak self] in self?.statusBar.isHandlingInteraction ?? false }
        dotWindow = controller
        return controller
    }

    private func toggleDot() {
        if settings.value.browsingMode == .browserApp {
            if !fallback.open() { showSettings() }
        } else { ensureWindow().toggle() }
    }
    @objc private func showDot() {
        if settings.value.browsingMode == .browserApp {
            if !fallback.open() { showSettings() }
        } else { ensureWindow().showDot() }
    }
    @objc private func hideDot() {
        if let keyWindow = NSApp.keyWindow, keyWindow !== dotWindow?.window { keyWindow.performClose(nil) }
        else { dotWindow?.hideDot() }
    }
    @objc private func reload() { ensureWindow().reload() }
    @objc private func standardViewport() { ensureWindow().standardViewport() }
    @objc private func compactViewport() { ensureWindow().compactViewport() }
    @objc private func showSettings() {
        login.refresh()
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(settings: settings, hotKey: hotKey, login: login, fallback: fallback,
                openDot: { [weak self] in self?.showDot() },
                applyEntry: { [weak self] in
                    guard let self else { return }
                    self.ensureWindow().browser.entryURL = DotEntryURL.validate(self.settings.value.entryURL) ?? DotIdentity.entryURL
                    if self.settings.value.browsingMode == .embedded { self.ensureWindow().returnToDot() }
                    self.showDot()
                },
                clearData: { [weak self] in
                    guard let self else { return }
                    self.settingsWindow?.window?.orderOut(nil)
                    self.ensureWindow().showDot()
                    self.ensureWindow().browser.clearWebsiteData()
                })
        }
        settingsWindow?.present()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showDot(); return true }
    public func applicationDidBecomeActive(_ notification: Notification) { login.refresh() }
    public func applicationWillTerminate(_ notification: Notification) { hotKey.stop(); diagnostics.record(.processExit) }

    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if [#selector(reload), #selector(standardViewport), #selector(compactViewport)].contains(menuItem.action) {
            return settings.value.browsingMode == .embedded
        }
        return true
    }

    private func buildApplicationMenu() {
        let main = NSMenu()
        func submenu(_ title: String) -> NSMenu {
            let item = NSMenuItem()
            let menu = NSMenu(title: title)
            item.submenu = menu
            main.addItem(item)
            return menu
        }
        func add(_ menu: NSMenu, _ title: String, _ selector: Selector, _ key: String, target: AnyObject? = nil) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.target = target
            menu.addItem(item)
        }
        let app = submenu("YourDotMini")
        add(app, "Settings…", #selector(showSettings), ",", target: self)
        app.addItem(.separator())
        add(app, "Hide YourDotMini", #selector(NSApplication.hide(_:)), "h", target: NSApp)
        app.addItem(.separator())
        add(app, "Quit YourDotMini", #selector(NSApplication.terminate(_:)), "q", target: NSApp)
        let edit = submenu("Edit")
        add(edit, "Undo", Selector(("undo:")), "z")
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        add(edit, "Cut", #selector(NSText.cut(_:)), "x")
        add(edit, "Copy", #selector(NSText.copy(_:)), "c")
        add(edit, "Paste", #selector(NSText.paste(_:)), "v")
        add(edit, "Select All", #selector(NSText.selectAll(_:)), "a")
        let window = submenu("Window")
        add(window, "Open Dot", #selector(showDot), "0", target: self)
        add(window, "Hide Window", #selector(hideDot), "w", target: self)
        add(window, "Reload Dot", #selector(reload), "r", target: self)
        window.addItem(.separator())
        add(window, "480 × 720 Web Viewport", #selector(standardViewport), "1", target: self)
        add(window, "420 × 520 Web Viewport", #selector(compactViewport), "2", target: self)
        NSApp.windowsMenu = window
        NSApp.mainMenu = main
    }
}
