import Foundation
import Testing
import YourDotMiniCore
@testable import YourDotMiniUI

@MainActor
struct BrowserFallbackTests {
    @Test func absentOrMalformedBookmarkDoesNotLaunch() throws {
        try withFixture { settings, _ in
            settings.update { $0.browserAppBookmark = nil }
            var launches = 0
            let coordinator = BrowserFallbackCoordinator(settings: settings) { _, _ in launches += 1 }
            #expect(!coordinator.open())
            #expect(coordinator.message?.contains("Choose a dedicated browser web app") == true)
            settings.update { $0.browserAppBookmark = Data("invalid bookmark".utf8) }
            #expect(!coordinator.open())
            #expect(coordinator.message?.contains("unavailable") == true)
            #expect(launches == 0)
        }
    }

    @Test(arguments: [false, true])
    func asynchronousLaunchCompletionReportsFailureOnlyWhenNeeded(opened: Bool) throws {
        try withFixture { settings, appURL in
            var completion: (@MainActor (Bool) -> Void)?
            var launchedURL: URL?
            var failures = 0
            let coordinator = BrowserFallbackCoordinator(settings: settings) { url, callback in
                launchedURL = url
                completion = callback
            }
            let accepted = coordinator.open(onFailure: { failures += 1 })
            #expect(accepted)
            #expect(launchedURL?.standardizedFileURL == appURL.standardizedFileURL)
            #expect(failures == 0)
            let callback = try #require(completion)
            callback(opened)
            #expect(failures == (opened ? 0 : 1))
            #expect(coordinator.message?.contains(opened ? "Opened the selected web app" : "Could not open") == true)
        }
    }

    @Test func missingExecutableDoesNotLaunch() throws {
        try withFixture { settings, appURL in
            try FileManager.default.removeItem(at: appURL.appendingPathComponent("Contents/MacOS/Fixture"))
            var launched = false
            let coordinator = BrowserFallbackCoordinator(settings: settings) { _, _ in launched = true }
            #expect(!coordinator.open())
            #expect(!launched)
            #expect(coordinator.message?.contains("unavailable") == true)
        }
    }

    @Test func selectingYourDotMiniCannotCreateLaunchLoop() throws {
        try withFixture(identifier: DotIdentity.bundleIdentifier) { settings, _ in
            var launched = false
            let coordinator = BrowserFallbackCoordinator(settings: settings) { _, _ in launched = true }
            #expect(!coordinator.open())
            #expect(!launched)
        }
    }

    private func withFixture(identifier: String = "local.YourDotMini.FallbackFixture",
                             _ body: (SettingsStore, URL) throws -> Void) throws {
        let suite = "YourDotMini.fallback-tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(repository: PreferencesRepository(defaults: defaults))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let appURL = root.appendingPathComponent("Fixture.app", isDirectory: true)
        let executable = appURL.appendingPathComponent("Contents/MacOS/Fixture")
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("synthetic app; never executed".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let info = ["CFBundleIdentifier": identifier, "CFBundleExecutable": "Fixture", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: appURL.appendingPathComponent("Contents/Info.plist"))
        // These unit tests exercise resolution and launch handling; sandbox access needs a signed app check.
        _ = try #require(Bundle(url: appURL)?.executableURL)
        let bookmark = try appURL.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
        settings.update { $0.browserAppBookmark = bookmark }
        try body(settings, appURL)
    }
}
