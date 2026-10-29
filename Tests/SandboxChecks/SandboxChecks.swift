import AppKit
#if DEBUG
import Combine
import YourDotMiniCore
@testable import YourDotMiniUI

/// A separate sandbox identity exercises the production app selector and launcher
/// without opening WebKit or accessing a user's browser or account.
@main
struct SandboxChecks {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = SandboxCheckDelegate()
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
private final class SandboxCheckDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var settings: SettingsStore?
    private var fallback: BrowserFallbackCoordinator?
    private var messageObservation: AnyCancellable?
    private let message = NSTextField(wrappingLabelWithString: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let target = Bundle.main.bundleIdentifier == "local.YourDotMini.SandboxChecks.Target"
        guard target || Bundle.main.bundleIdentifier == "local.YourDotMini.SandboxChecks" else {
            print("Run the dedicated test app bundle built by scripts/build-sandbox-checks.sh.")
            exit(1)
        }
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 520, height: 320),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = target ? "YourDotMini Fallback Fixture" : "YourDotMini Sandbox Checks"
        window.isReleasedWhenClosed = false
        let heading = NSTextField(labelWithString: target ? "Synthetic browser app launched" : "Browser-app sandbox checks")
        heading.font = .boldSystemFont(ofSize: 20)
        let description = NSTextField(wrappingLabelWithString: target
            ? "This harmless fixture has no website, network requests, or account data."
            : "Choose YourDotMiniFallbackFixture.app from this test build. Quit and reopen this identical test app to check saved access.")
        let stack = NSStackView(views: [heading, description, message])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        if target {
            message.stringValue = "PASS: fixture process is running."
        } else {
            let store = SettingsStore()
            let coordinator = BrowserFallbackCoordinator(settings: store)
            settings = store
            fallback = coordinator
            message.stringValue = store.value.browserAppBookmark == nil
                ? "No fixture selected." : "Saved fixture found after launch."
            messageObservation = coordinator.$message.compactMap { $0 }.sink { [weak self] text in
                self?.message.stringValue = text
            }
            stack.addArrangedSubview(button("Choose Fixture App…", #selector(chooseFixture)))
            stack.addArrangedSubview(button("Open Saved Fixture", #selector(openFixture)))
            stack.addArrangedSubview(button("Reset Test Data and Quit", #selector(resetAndQuit)))
        }
        stack.addArrangedSubview(button("Quit Test App", #selector(quit)))
        window.contentView?.addSubview(stack)
        if let content = window.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
                stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20),
            ])
        }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func button(_ title: String, _ selector: Selector) -> NSButton {
        NSButton(title: title, target: self, action: selector)
    }
    @objc private func chooseFixture() { fallback?.chooseApp(for: window) }
    @objc private func openFixture() { fallback?.open() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func resetAndQuit() {
        if let identifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: identifier)
        }
        quit()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
#else
@main
struct SandboxChecks {
    static func main() {
        print("SandboxChecks requires a debug build; use scripts/build-sandbox-checks.sh.")
    }
}
#endif
