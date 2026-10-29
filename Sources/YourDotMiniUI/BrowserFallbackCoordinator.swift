import AppKit
import Combine
import UniformTypeIdentifiers
import YourDotMiniCore

@MainActor
final class BrowserFallbackCoordinator: ObservableObject {
    typealias ApplicationOpener = @MainActor (URL, @escaping @MainActor (Bool) -> Void) -> Void
    @Published private(set) var message: String?
    private let settings: SettingsStore
    private let openApplication: ApplicationOpener
    init(settings: SettingsStore, openApplication: @escaping ApplicationOpener = { url, completion in
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
            let opened = app != nil && error == nil
            Task { @MainActor in completion(opened) }
        }
    }) {
        self.settings = settings
        self.openApplication = openApplication
    }

    private static func isUsableApp(_ url: URL) -> Bool {
        guard url.isFileURL, url.pathExtension.lowercased() == "app", let bundle = Bundle(url: url),
              let identifier = bundle.bundleIdentifier, identifier != DotIdentity.bundleIdentifier,
              let executable = bundle.executableURL else { return false }
        return FileManager.default.fileExists(atPath: executable.path)
    }

    func chooseApp(for window: NSWindow?) {
        let panel = NSOpenPanel()
        panel.title = "Choose your dedicated dot web app"
        panel.message = "First create a dedicated web app for your dot in Safari or another supported browser, then choose its .app here."
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] result in
            guard let self, result == .OK, let url = panel.url else { return }
            guard Self.isUsableApp(url) else {
                self.message = "Choose a dedicated browser web app, not YourDotMini."
                return
            }
            do {
                let data = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                               includingResourceValuesForKeys: nil, relativeTo: nil)
                self.settings.update { $0.browserAppBookmark = data; $0.browserAppName = url.deletingPathExtension().lastPathComponent }
                self.message = "Selected. Use Test Open, verify it opens your dot, then select Browser app mode."
            } catch { self.message = "Could not remember access to that app. Choose it again." }
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }

    @discardableResult
    func open(onFailure: (@MainActor () -> Void)? = nil) -> Bool {
        guard let bookmark = settings.value.browserAppBookmark else { message = "Choose a dedicated browser web app in Settings first."; return false }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting],
                              relativeTo: nil, bookmarkDataIsStale: &stale)
            let scoped = url.startAccessingSecurityScopedResource()
            var handedOff = false
            defer { if scoped && !handedOff { url.stopAccessingSecurityScopedResource() } }
            guard Self.isUsableApp(url) else {
                message = "The selected web app is unavailable. Choose it again in Settings."
                return false
            }
            if stale {
                let renewed = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                                  includingResourceValuesForKeys: nil, relativeTo: nil)
                settings.update { $0.browserAppBookmark = renewed }
            }
            handedOff = true
            openApplication(url) { [weak self] opened in
                if scoped { url.stopAccessingSecurityScopedResource() }
                self?.message = opened ? "Opened the selected web app. Verify it shows your dot." : "Could not open the selected app. Choose it again or use Embedded mode."
                if !opened { onFailure?() }
            }
            return true
        } catch { message = "The selected web app is unavailable. Choose it again in Settings."; return false }
    }
}
