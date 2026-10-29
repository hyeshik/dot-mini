import AppKit
import WebKit
import PilotCore
import YourDotMiniCore

@MainActor
final class DotBrowserController: NSObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    let diagnostics: DotDiagnostics
    private(set) lazy var composerFocus: ComposerFocusController = {
        let focus = ComposerFocusController(webView: webView)
        focus.canFocus = { [weak self] in
            guard let self, let window = self.webView.window else { return false }
            return window.isVisible && !window.isMiniaturized && !NSApp.isHidden &&
                window.attachedSheet == nil &&
                !self.isClearing && !self.hasOwnedDialog
        }
        return focus
    }()
    var entryURL = DotIdentity.entryURL
    var onStatus: ((String) -> Void)?
    private var policy = NavigationPolicy()
    private(set) var isClearing = false
    private(set) var hasOwnedDialog = false {
        didSet { if hasOwnedDialog { composerFocus.cancel() } }
    }
    private var responseFailed = false
    private(set) var hasLoaded = false

    init(diagnostics: DotDiagnostics, webView suppliedWebView: WKWebView? = nil) {
        self.diagnostics = diagnostics
        if let suppliedWebView {
            webView = suppliedWebView
        } else {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .default()
            configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
            webView = WKWebView(frame: .zero, configuration: configuration)
        }
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        diagnostics.record(.browserCreated)
    }

    func loadIfNeeded() { if !hasLoaded { returnToDot() } }

    func returnToDot() {
        guard !isClearing else { return }
        hasLoaded = true
        webView.load(URLRequest(url: entryURL))
    }

    func reload() {
        guard !isClearing else { return }
        if webView.url == nil { returnToDot() } else { webView.reload() }
    }

    func openInBrowser() { openBrowser(entryURL) }

    private func openBrowser(_ url: URL) {
        let success = NSWorkspace.shared.open(url)
        diagnostics.record(success ? .browserOpened : .browserOpenFailed, url: url)
        onStatus?(success ? "Opened in your browser, using its separate sign-in." : "Could not open your default browser. Try again.")
    }

    func clearWebsiteData() {
        guard !isClearing, let window = webView.window, window.attachedSheet == nil else { return }
        let alert = NSAlert()
        alert.messageText = "Clear YourDotMini Website Data?"
        alert.informativeText = "This signs you out of YourDotMini and removes its website storage. Unsent text may be lost. Your browser data and ChatGPT history are unaffected."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Clear Website Data")
        hasOwnedDialog = true
        alert.beginSheetModal(for: window) { [weak self] result in
            guard let self else { return }
            self.hasOwnedDialog = false
            guard result == .alertSecondButtonReturn else { return }
            self.isClearing = true
            self.diagnostics.record(.dataClearStarted)
            self.onStatus?("Clearing YourDotMini website data…")
            self.webView.stopLoading()
            self.webView.load(URLRequest(url: URL(string: "about:blank")!))
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if isClearing {
            decisionHandler(action.request.url?.absoluteString == "about:blank" ? .allow : .cancel)
            return
        }
        if action.shouldPerformDownload {
            downloadFallback()
            decisionHandler(.cancel)
            return
        }
        guard action.targetFrame?.isMainFrame != false else { decisionHandler(.allow); return }
        if action.targetFrame == nil {
            // A clicked external link does not need another embedded window.
            // OAuth and first-party popups retain an explicit browser fallback.
            if action.navigationType == .linkActivated,
               policy.route(action.request.url, isUserLink: true) == .browser,
               let url = action.request.url {
                openBrowser(url)
            } else {
                diagnostics.record(.popupBlocked, url: action.request.url)
                onStatus?("This page needs another window. Use Open in Browser to continue.")
            }
            decisionHandler(.cancel)
            return
        }
        decide(action.request.url, userLink: action.navigationType == .linkActivated) {
            decisionHandler($0 ? .allow : .cancel)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
        guard response.isForMainFrame else { decisionHandler(.allow); return }
        if isClearing {
            decisionHandler(response.response.url?.absoluteString == "about:blank" ? .allow : .cancel)
            return
        }
        guard response.canShowMIMEType else {
            downloadFallback()
            decisionHandler(.cancel)
            return
        }
        if let http = response.response as? HTTPURLResponse, http.statusCode >= 400 {
            responseFailed = true
            onStatus?("Website error (HTTP \(http.statusCode)). Reload or open in your browser.")
        }
        decide(response.response.url, userLink: false) { decisionHandler($0 ? .allow : .cancel) }
    }

    private func decide(_ url: URL?, userLink: Bool, completion: @escaping @MainActor (Bool) -> Void) {
        switch policy.route(url, isUserLink: userLink) {
        case .embedded: completion(true)
        case .browser:
            if let url { openBrowser(url) }
            completion(false)
        case .blocked:
            diagnostics.record(.navigationBlocked, url: url)
            onStatus?("Unsupported destination. Return to Dot or open in your browser.")
            completion(false)
        case .confirmAuthenticationHost(let host):
            guard let window = webView.window, window.attachedSheet == nil else { completion(false); return }
            let alert = NSAlert()
            alert.messageText = "Continue to \(host)?"
            alert.informativeText = "Continue only if this host is part of the sign-in you started. It will be allowed in this window for this run. If the provider does not support embedded sign-in, use your browser."
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Continue in YourDotMini")
            alert.addButton(withTitle: "Open Dot in Browser")
            hasOwnedDialog = true
            alert.beginSheetModal(for: window) { [weak self] result in
                guard let self else { completion(false); return }
                self.hasOwnedDialog = false
                let allow = result == .alertSecondButtonReturn
                if allow { self.policy.approvedAuthenticationHosts.insert(host) }
                self.diagnostics.record(allow ? .authenticationHostAllowed : .authenticationHostDeclined, url: url)
                completion(allow)
                if result == .alertThirdButtonReturn { self.openInBrowser() }
            }
        }
    }

    private func downloadFallback() {
        diagnostics.record(.downloadBlocked)
        onStatus?("Use Open in Browser and repeat this download there.")
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        composerFocus.navigationStarted()
        responseFailed = false
        diagnostics.record(.navigationStarted, url: webView.url)
        if !isClearing { onStatus?("Loading \(DiagnosticFields.host(webView.url))…") }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        diagnostics.record(.navigationFinished, url: webView.url)
        if isClearing, webView.url?.absoluteString == "about:blank" {
            webView.configuration.websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { [weak self] in
                guard let self else { return }
                self.policy = NavigationPolicy()
                self.isClearing = false
                self.diagnostics.record(.dataClearFinished)
                self.returnToDot()
            }
        } else if !responseFailed {
            onStatus?("")
            composerFocus.resumeAfterNavigation()
        } else {
            composerFocus.cancel()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }

    private func failed(_ error: Error) {
        let error = error as NSError
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled { return }
        composerFocus.cancel()
        isClearing = false
        diagnostics.record(.navigationFailed, url: webView.url, error: error)
        let reason = error.domain == NSURLErrorDomain && error.code == NSURLErrorNotConnectedToInternet
            ? "Connection unavailable" : "Navigation failed (\(DiagnosticFields.error(error)))"
        onStatus?("\(reason). Reload or open in your browser.")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        composerFocus.cancel()
        isClearing = false
        diagnostics.record(.webProcessTerminated)
        onStatus?("Web content stopped. Drafts may be lost. Reload or open in your browser.")
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        diagnostics.record(.popupBlocked, url: action.request.url)
        onStatus?("This page needs another window. Use Open in Browser to continue.")
        return nil
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor ([URL]?) -> Void) {
        guard let window = webView.window, window.attachedSheet == nil, !isClearing else { completionHandler(nil); return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        hasOwnedDialog = true
        panel.beginSheetModal(for: window) { [weak self] result in
            self?.hasOwnedDialog = false
            completionHandler(result == .OK ? panel.urls : nil)
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor () -> Void) {
        dialog(message, frame: frame, buttons: ["OK"]) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor (Bool) -> Void) {
        dialog(message, frame: frame, buttons: ["Cancel", "OK"]) { completionHandler($0 == .alertSecondButtonReturn) }
    }

    private func dialog(_ message: String, frame: WKFrameInfo, buttons: [String],
                        completion: @escaping @MainActor (NSApplication.ModalResponse) -> Void) {
        guard let window = webView.window, window.attachedSheet == nil, !isClearing else { completion(.abort); return }
        let alert = NSAlert()
        alert.messageText = "Website message — \(DiagnosticFields.host(frame.request.url))"
        alert.informativeText = message
        buttons.forEach { alert.addButton(withTitle: $0) }
        hasOwnedDialog = true
        alert.beginSheetModal(for: window) { [weak self] result in
            self?.hasOwnedDialog = false
            completion(result)
        }
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void) {
        diagnostics.record(.mediaBlocked)
        onStatus?("Use Open in Browser for microphone and camera features.")
        decisionHandler(.deny)
    }
}
