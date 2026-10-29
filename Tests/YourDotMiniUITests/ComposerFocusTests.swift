import AppKit
import Testing
import WebKit
@testable import YourDotMiniUI

@Suite(.serialized)
@MainActor
struct ComposerFocusTests {
    @Test(arguments: [
        "<textarea id='prompt-textarea'>Unsent fixture draft</textarea>",
        "<div id='prompt-textarea' contenteditable='true'><p>Unsent fixture draft</p></div>",
        "<textarea name='prompt-textarea' id='legacy'>Unsent fixture draft</textarea>",
    ])
    func focusesVisibleComposerWithoutChangingDraftOrActivatingApp(_ composer: String) async throws {
        let fixture = try await FocusFixture(composer)
        defer { fixture.close() }
        #expect(NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier)
        try await fixture.run("document.getElementById('other').focus()")
        #expect(try await fixture.focusOnce() == "focused")
        let expectedID = composer.contains("legacy") ? "legacy" : "prompt-textarea"
        #expect(try await fixture.string("document.activeElement.id") == expectedID)
        #expect(try await fixture.string("document.activeElement.value || document.activeElement.textContent") == "Unsent fixture draft")
        // The human may switch between other apps while these tests run.
        // The regression is this test app taking foreground focus.
        #expect(NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier)
        #expect(!fixture.window.isKeyWindow)
    }

    @Test(arguments: [
        "<textarea id='prompt-textarea' hidden></textarea>",
        "<section style='display:none'><textarea id='prompt-textarea'></textarea></section>",
        "<section style='opacity:0'><textarea id='prompt-textarea'></textarea></section>",
        "<section inert><textarea id='prompt-textarea'></textarea></section>",
        "<textarea id='prompt-textarea' disabled></textarea>",
        "<textarea id='prompt-textarea' readonly></textarea>",
        "<textarea id='prompt-textarea' style='position:absolute;top:2000px'></textarea>",
        "<div id='prompt-textarea'>Non-editable renamed element</div>",
        "<textarea id='prompt-textarea'></textarea><textarea name='prompt-textarea'></textarea>",
        "<textarea id='prompt-textarea'></textarea><div role='dialog' aria-modal='true'>Modal</div>",
        "<textarea id='prompt-textarea'></textarea><div style='position:fixed;inset:0;background:white'>Overlay</div>",
    ])
    func unavailableComposerLeavesFocusAndScrollAlone(_ markup: String) async throws {
        let fixture = try await FocusFixture(markup)
        defer { fixture.close() }
        try await fixture.run("document.getElementById('other').focus()")
        #expect(try await fixture.focusOnce() == "unavailable")
        #expect(try await fixture.string("document.activeElement.id") == "other")
        #expect(try await fixture.string("String(scrollY)") == "0")
    }

    @Test func changedLayoutIsSilentAndDoesNotFocusGenericInputs() async throws {
        let fixture = try await FocusFixture("<textarea id='new-layout' aria-label='Message'></textarea>")
        defer { fixture.close() }
        try await fixture.run("document.getElementById('other').focus()")
        #expect(try await fixture.focusOnce() == "missing")
        #expect(try await fixture.string("document.activeElement.id") == "other")
    }

    @Test func controllerFocusesOncePerAppearanceAndDoesNotActivateApp() async throws {
        let fixture = try await FocusFixture("<textarea id='prompt-textarea'>Unsent fixture draft</textarea>")
        defer { fixture.close() }
        #expect(NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier)
        let controller = ComposerFocusController(webView: fixture.webView)
        defer { controller.cancel() }
        controller.setPresented(true)
        try await fixture.waitUntil { !controller.isPending }
        #expect(try await fixture.string("document.activeElement.id") == "prompt-textarea")
        try await fixture.run("document.getElementById('other').focus()")
        controller.setPresented(true)
        try await Task.sleep(for: .milliseconds(150))
        #expect(try await fixture.string("document.activeElement.id") == "other")
        controller.setPresented(false)
        controller.setPresented(true)
        try await fixture.waitUntil { !controller.isPending }
        #expect(try await fixture.string("document.activeElement.id") == "prompt-textarea")
        #expect(NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier)
        #expect(!fixture.window.isKeyWindow)
    }

    @Test func delayedMountIsFocusedButHidingCancelsTheRequest() async throws {
        let fixture = try await FocusFixture("")
        defer { fixture.close() }
        let controller = ComposerFocusController(webView: fixture.webView)
        defer { controller.cancel() }
        controller.setPresented(true)
        try await Task.sleep(for: .milliseconds(150))
        try await fixture.run("document.body.insertAdjacentHTML('beforeend', '<textarea id=prompt-textarea></textarea>')")
        try await fixture.waitUntil { !controller.isPending }
        #expect(try await fixture.string("document.activeElement.id") == "prompt-textarea")
        controller.setPresented(false)
        try await fixture.run("document.getElementById('prompt-textarea').remove(); document.getElementById('other').focus()")
        controller.setPresented(true)
        try await Task.sleep(for: .milliseconds(150))
        controller.setPresented(false)
        try await fixture.run("document.body.insertAdjacentHTML('beforeend', '<textarea id=prompt-textarea></textarea>')")
        try await Task.sleep(for: .milliseconds(200))
        #expect(try await fixture.string("document.activeElement.id") == "other")
        #expect(!controller.isPending)
    }

    @Test func disablingOrBlockingFocusPreservesCurrentTarget() async throws {
        let fixture = try await FocusFixture("<textarea id='prompt-textarea'></textarea>")
        defer { fixture.close() }
        let controller = ComposerFocusController(webView: fixture.webView)
        defer { controller.cancel() }
        try await fixture.run("document.getElementById('other').focus()")
        controller.isEnabled = false
        controller.setPresented(true)
        #expect(!controller.isPending)
        #expect(try await fixture.string("document.activeElement.id") == "other")
        controller.setPresented(false)
        controller.isEnabled = true
        controller.canFocus = { false }
        controller.setPresented(true)
        try await fixture.waitUntil { !controller.isPending }
        #expect(try await fixture.string("document.activeElement.id") == "other")
    }

    @Test func missingComposerRetryEnds() async throws {
        let fixture = try await FocusFixture("")
        defer { fixture.close() }
        let controller = ComposerFocusController(webView: fixture.webView)
        defer { controller.cancel() }
        controller.setPresented(true)
        try await fixture.waitUntil { !controller.isPending }
        #expect(!controller.isPending)
    }

    @Test func inputDuringHydrationCancelsPendingFocus() async throws {
        let fixture = try await FocusFixture("")
        defer { fixture.close() }
        let controller = ComposerFocusController(webView: fixture.webView)
        defer { controller.cancel() }
        try await fixture.run("document.getElementById('other').focus()")
        controller.setPresented(true)
        try await Task.sleep(for: .milliseconds(150))
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: fixture.window.windowNumber, context: nil, characters: "",
            charactersIgnoringModifiers: "", isARepeat: false, keyCode: 0))
        NSApp.sendEvent(event)
        #expect(!controller.isPending)
        try await fixture.run("document.body.insertAdjacentHTML('beforeend', '<textarea id=prompt-textarea></textarea>')")
        try await Task.sleep(for: .milliseconds(200))
        #expect(try await fixture.string("document.activeElement.id") == "other")
    }

    @Test(arguments: ["https://auth.chatgpt.com/", "https://chatgpt.com.evil.test/", "http://chatgpt.com/", "https://chatgpt.com:8443/", "https://name:secret@chatgpt.com/", "about:blank"])
    func rejectsNonConversationOrigins(_ address: String) {
        #expect(!ComposerFocusScript.permits(URL(string: address)))
    }

}

/// Synthetic, nonpersistent WebKit only: no network, sign-in, or production data.
@MainActor
private final class FocusFixture: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    let window: NSWindow
    private var loaded = false

    init(_ markup: String) async throws {
        _ = NSApplication.shared
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 480, height: 320), configuration: configuration)
        window = DotPanel(contentRect: CGRect(x: 40, y: 100, width: 480, height: 320),
                          styleMask: [.titled], backing: .buffered, defer: false)
        super.init()
        window.title = "YourDotMini — synthetic focus test"
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.contentView = webView
        webView.navigationDelegate = self
        window.orderFront(nil)
        let html = """
        <!doctype html><html><head><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'none'"><style>
        body { margin: 16px; } textarea, [contenteditable] { display: block; width: 300px; height: 60px; margin-top: 12px; }
        </style></head><body><input id="other" aria-label="Fixture search"><p id="message">Synthetic conversation selection</p>\(markup)</body></html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://chatgpt.com/dots")!)
        try await waitUntil { self.loaded }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded = true }
    func close() { webView.stopLoading(); window.orderOut(nil); window.close() }

    func waitUntil(_ predicate: () -> Bool) async throws {
        for _ in 0..<200 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        throw FixtureError.timeout
    }

    func string(_ script: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result as? String ?? "") }
            }
        }
    }
    func run(_ script: String) async throws { _ = try await string(script + "; ''") }
    func focusOnce() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(ComposerFocusScript.source, in: nil,
                                      in: .world(name: "YourDotMini.ComposerFocus")) { result in
                continuation.resume(with: result.map { $0 as? String ?? "" })
            }
        }
    }
    enum FixtureError: Error { case timeout }
}
