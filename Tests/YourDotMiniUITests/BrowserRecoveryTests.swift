import Foundation
import Testing
import WebKit
@testable import YourDotMiniUI

@MainActor
struct BrowserRecoveryTests {
    @Test func offlineErrorOffersRecoveryWithoutAutomaticReload() {
        let webView = RecordingWebView()
        let browser = DotBrowserController(diagnostics: DotDiagnostics(), webView: webView)
        var status = ""
        browser.onStatus = { status = $0 }
        browser.webView(webView, didFailProvisionalNavigation: nil,
                        withError: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))
        #expect(status.contains("Connection unavailable"))
        #expect(status.contains("Reload or open in your browser"))
        #expect(webView.requests.isEmpty && webView.reloads == 0)
        #expect(browser.webView === webView)
        browser.reload()
        #expect(webView.requests.map(\.url) == [browser.entryURL])
    }

    @Test func cancelledNavigationDoesNotReplaceExistingStatus() {
        let webView = RecordingWebView()
        let browser = DotBrowserController(diagnostics: DotDiagnostics(), webView: webView)
        var status = "Existing status"
        browser.onStatus = { status = $0 }
        browser.webView(webView, didFailProvisionalNavigation: nil,
                        withError: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))
        #expect(status == "Existing status")
        #expect(webView.requests.isEmpty && webView.reloads == 0)
    }

    @Test func navigationErrorsDoNotExposeDescriptionsOrURLs() {
        let webView = RecordingWebView()
        let browser = DotBrowserController(diagnostics: DotDiagnostics(), webView: webView)
        var status = ""
        browser.onStatus = { status = $0 }
        let error = NSError(domain: "private-fixture-domain", code: 123, userInfo: [
            NSLocalizedDescriptionKey: "private-fixture-description",
            NSURLErrorFailingURLStringErrorKey: "https://chatgpt.com/c/private-fixture?token=private-fixture-token",
        ])
        browser.webView(webView, didFail: nil, withError: error)
        #expect(status.contains("Navigation failed"))
        #expect(!status.contains("private-fixture"))
        #expect(webView.requests.isEmpty && webView.reloads == 0)
    }

    @Test func webProcessFailureRequiresExplicitRecoveryAndKeepsWrapperView() {
        let webView = RecordingWebView()
        let browser = DotBrowserController(diagnostics: DotDiagnostics(), webView: webView)
        var status = ""
        browser.onStatus = { status = $0 }
        browser.webViewWebContentProcessDidTerminate(webView)
        #expect(status.contains("Drafts may be lost"))
        #expect(status.contains("Reload or open in your browser"))
        #expect(browser.webView === webView)
        #expect(webView.requests.isEmpty && webView.reloads == 0)
        #expect(!browser.isClearing)
        browser.reload()
        #expect(webView.requests.map(\.url) == [browser.entryURL])
    }
}

/// Records only fixture requests; no network or persistent website store.
@MainActor
private final class RecordingWebView: WKWebView {
    private(set) var requests: [URLRequest] = []
    private(set) var reloads = 0
    init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        super.init(frame: .zero, configuration: configuration)
    }
    required init?(coder: NSCoder) { fatalError("Not supported") }
    override func load(_ request: URLRequest) -> WKNavigation? { requests.append(request); return nil }
    override func reload() -> WKNavigation? { reloads += 1; return nil }
}
