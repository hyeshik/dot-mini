import AppKit
import Combine
import UniformTypeIdentifiers
import YourDotMiniCore

@MainActor
final class BrowserFallbackCoordinator: ObservableObject {
    @Published private(set) var message: String?
    private let settings: SettingsStore
    init(settings: SettingsStore) { self.settings = settings }

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
            guard url.pathExtension == "app", let bundle = Bundle(url: url),
                  bundle.bundleIdentifier != DotIdentity.bundleIdentifier else {
                self.message = "Choose a dedicated browser web app, not YourDotMini."
                return
            }
            do {
                let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
                self.settings.update { $0.browserAppBookmark = data; $0.browserAppName = url.deletingPathExtension().lastPathComponent }
                self.message = "Selected. Use Test Open, verify it opens your dot, then select Browser app mode."
            } catch { self.message = "Could not remember access to that app. Choose it again." }
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }

    @discardableResult
    func open() -> Bool {
        guard let bookmark = settings.value.browserAppBookmark else { message = "Choose a dedicated browser web app in Settings first."; return false }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
            let scoped = url.startAccessingSecurityScopedResource()
            var handedOff = false
            defer { if scoped && !handedOff { url.stopAccessingSecurityScopedResource() } }
            if stale {
                let renewed = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
                settings.update { $0.browserAppBookmark = renewed }
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            handedOff = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] app, error in
                if scoped { url.stopAccessingSecurityScopedResource() }
                Task { @MainActor in self?.message = app != nil && error == nil ? "Opened the selected web app. Verify it shows your dot." : "Could not open the selected app. Choose it again or use Embedded mode." }
            }
            return true
        } catch { message = "The selected web app is unavailable. Choose it again in Settings."; return false }
    }
}
