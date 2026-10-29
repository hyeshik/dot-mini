import AppKit
import WebKit
import PilotCore

extension PilotWindowController: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if isClearingData {
            decisionHandler(action.request.url?.absoluteString == "about:blank" ? .allow : .cancel)
            return
        }
        if action.shouldPerformDownload {
            blockDownload()
            decisionHandler(.cancel)
            return
        }
        // Subframes keep WebKit's native security behavior. This is not a
        // subresource filter and must not interfere with provider challenges.
        guard action.targetFrame?.isMainFrame != false else {
            decisionHandler(.allow)
            return
        }
        if action.targetFrame == nil {
            diagnostics.record(.popupBlocked, url: action.request.url)
            setStatus("Popup needs another window. Use Open in Browser; record this limitation in P0-02/P0-10.")
            decisionHandler(.cancel)
            return
        }
        diagnostics.record(.navigationRequested, url: action.request.url)
        decideTopLevel(action.request.url, isUserLink: action.navigationType == .linkActivated) { allow in
            decisionHandler(allow ? .allow : .cancel)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
        guard response.isForMainFrame else { decisionHandler(.allow); return }
        if isClearingData {
            decisionHandler(response.response.url?.absoluteString == "about:blank" ? .allow : .cancel)
            return
        }
        guard response.canShowMIMEType else {
            blockDownload()
            decisionHandler(.cancel)
            return
        }
        // Check the final destination as well as the initiating request, including
        // server-side redirects. No unknown host silently becomes trusted.
        decideTopLevel(response.response.url, isUserLink: false) { allow in
            decisionHandler(allow ? .allow : .cancel)
        }
    }

    private func decideTopLevel(_ url: URL?, isUserLink: Bool, completion: @escaping @MainActor (Bool) -> Void) {
        switch navigationPolicy.route(url, isUserLink: isUserLink) {
        case .embedded: completion(true)
        case .browser:
            if let url { openBrowser(url) }
            completion(false)
        case .blocked:
            diagnostics.record(.navigationBlocked, url: url)
            setStatus("Unsupported destination blocked. Return to Dot or Open in Browser.")
            completion(false)
        case .confirmAuthenticationHost(let host):
            guard let window, window.attachedSheet == nil else { completion(false); return }
            let alert = NSAlert()
            alert.messageText = "Continue to \(host)?"
            alert.informativeText = "Allow this HTTPS host inside the pilot for this run only if it is part of the sign-in you started. Embedded sign-in may be unsupported. This does not bypass the provider’s policies."
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Continue in Pilot")
            alert.addButton(withTitle: "Open Dot in Browser")
            alert.beginSheetModal(for: window) { [weak self] result in
                guard let self else { completion(false); return }
                let allowed = result == .alertSecondButtonReturn
                if allowed { self.navigationPolicy.approvedAuthenticationHosts.insert(host) }
                self.diagnostics.record(allowed ? .authenticationHostAllowed : .authenticationHostDeclined, url: url)
                completion(allowed)
                if result == .alertThirdButtonReturn { self.openInBrowser() }
            }
        }
    }

    private func blockDownload() {
        diagnostics.record(.downloadBlocked)
        setStatus("Downloads are not implemented in this pilot. Open in Browser and repeat the download there.")
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        diagnostics.record(.navigationStarted, url: webView.url)
        if !isClearingData { setStatus("Loading \(DiagnosticFields.host(webView.url))…") }
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        diagnostics.record(.navigationRedirected, url: webView.url)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        diagnostics.record(.navigationCommitted, url: webView.url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        diagnostics.record(.navigationFinished, url: webView.url)
        if isClearingData {
            if webView.url?.absoluteString == "about:blank" { finishClearingData() }
        } else {
            setStatus("Loaded \(DiagnosticFields.host(webView.url)). Verify sign-in and dot access visually.")
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showNavigationError(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showNavigationError(error)
    }

    private func showNavigationError(_ error: Error) {
        let error = error as NSError
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled { return }
        diagnostics.record(.navigationFailed, url: webView.url, error: error)
        isClearingData = false
        let reason = error.domain == NSURLErrorDomain && error.code == NSURLErrorNotConnectedToInternet
            ? "Connection unavailable" : "Navigation failed (\(DiagnosticFields.error(error)))"
        setStatus("\(reason). Use Reload or Open in Browser.")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        diagnostics.record(.webProcessTerminated)
        isClearingData = false
        setStatus("Web content process exited. Drafts may be lost. Use Reload or Open in Browser.")
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Preserve Phase 0's one-window/one-view architecture, never silently
        // convert an OAuth popup into an unrelated browser session.
        diagnostics.record(.popupBlocked, url: action.request.url)
        setStatus("Popup unsupported in the one-window pilot. Use Open in Browser.")
        return nil
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor ([URL]?) -> Void) {
        guard let window, window.attachedSheet == nil, !isClearingData else {
            completionHandler(nil)
            return
        }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        panel.beginSheetModal(for: window) { result in
            completionHandler(result == .OK ? panel.urls : nil)
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor () -> Void) {
        siteDialog(message, frame: frame, buttons: ["OK"]) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor (Bool) -> Void) {
        siteDialog(message, frame: frame, buttons: ["Cancel", "OK"]) {
            completionHandler($0 == .alertSecondButtonReturn)
        }
    }

    private func siteDialog(_ message: String, frame: WKFrameInfo, buttons: [String],
                            completion: @escaping @MainActor (NSApplication.ModalResponse) -> Void) {
        guard let window, window.attachedSheet == nil, !isClearingData else {
            completion(.abort)
            return
        }
        let alert = NSAlert()
        alert.messageText = "Website message — \(DiagnosticFields.host(frame.request.url))"
        alert.informativeText = message // Display only. Never pass website text to diagnostics.
        for button in buttons { alert.addButton(withTitle: button) }
        alert.beginSheetModal(for: window, completionHandler: completion)
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void) {
        diagnostics.record(.mediaBlocked)
        setStatus("Microphone/camera are outside this pilot. Use Open in Browser for media features.")
        decisionHandler(.deny)
    }
}
