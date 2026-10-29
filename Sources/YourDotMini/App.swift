import AppKit
import YourDotMiniCore
import YourDotMiniUI

@main
@MainActor
enum YourDotMiniApp {
    static func main() {
        guard Bundle.main.bundleIdentifier == DotIdentity.bundleIdentifier else {
            fputs("Build with scripts/build-app.sh, then open build/YourDotMini.app.\n", stderr)
            exit(1)
        }
        let app = NSApplication.shared
        let delegate = MenuBarAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}
