import Foundation
import Testing
@testable import YourDotMiniCore

struct PreferencesTests {
    @Test(arguments: ["http://chatgpt.com/dots", "https://chatgpt.com.evil.test/dots", "https://evilchatgpt.com/dots",
                      "https://name:secret@chatgpt.com/dots", "file:///dots", "https://chatgpt.com:8443/dots"])
    func unsafeEntryURLIsRejected(_ input: String) { #expect(DotEntryURL.validate(input) == nil) }

    @Test func directFirstPartyURLIsAllowed() {
        #expect(DotEntryURL.validate("  https://chatgpt.com/c/known-conversation  ")?.path == "/c/known-conversation")
        #expect(DotEntryURL.validate("https://CHATGPT.COM:443/dots") != nil)
    }

    @Test func olderPartialPreferencesReceiveDefaults() throws {
        let value = try JSONDecoder().decode(DotPreferences.self, from: Data("{\"keepOpen\":true}".utf8))
        #expect(value.keepOpen)
        #expect(value.hideOnFocusLoss)
        #expect(value.focusComposerOnShow)
        #expect(value.shortcut == .default)
        #expect(value.viewportWidth == 480 && value.viewportHeight == 720)
        #expect(value.browsingMode == .embedded)
    }

    @Test func disabledShortcutSurvivesRoundTrip() throws {
        var value = DotPreferences()
        value.shortcut = nil
        let decoded = try JSONDecoder().decode(DotPreferences.self, from: JSONEncoder().encode(value))
        #expect(decoded.shortcut == nil)
    }

    @Test func corruptGeometryAndMissingBrowserAppRecoverSafely() {
        var value = DotPreferences()
        value.entryURL = "https://other.example/"
        value.viewportWidth = .infinity
        value.viewportHeight = -1
        value.preferredX = .nan
        value.preferredY = 12
        value.browsingMode = .browserApp
        let repaired = value.sanitized()
        #expect(repaired.viewportWidth == 480 && repaired.viewportHeight == 520)
        #expect(repaired.preferredX == nil && repaired.preferredY == nil)
        #expect(repaired.entryURL == DotIdentity.entryURL.absoluteString)
        #expect(repaired.browsingMode == .embedded)
    }

    @Test func preferencesPersistWithoutUsingProductionDefaults() throws {
        let suite = "YourDotMini.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = PreferencesRepository(defaults: defaults)
        #expect(repository.load() == DotPreferences())
        var value = DotPreferences()
        value.keepOpen = true
        value.focusComposerOnShow = false
        value.viewportWidth = 620
        value.preferredX = -1200
        value.preferredY = 50
        value.shortcut = GlobalShortcut(keyCode: 0, modifiers: GlobalShortcut.command | GlobalShortcut.shift)
        try repository.save(value)
        #expect(repository.load() == value)
    }

    @Test func invalidShortcutsCannotCaptureOrdinaryTyping() {
        #expect(GlobalShortcut.default.isValid)
        #expect(!GlobalShortcut(keyCode: 2, modifiers: 0).isValid)
        #expect(!GlobalShortcut(keyCode: 2, modifiers: GlobalShortcut.shift).isValid)
        #expect(!GlobalShortcut(keyCode: 2, modifiers: GlobalShortcut.option).isValid)
        #expect(!GlobalShortcut(keyCode: 65535, modifiers: GlobalShortcut.control).isValid)
        #expect(!GlobalShortcut(keyCode: 2, modifiers: 65535).isValid)
    }
}
