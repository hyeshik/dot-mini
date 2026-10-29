import AppKit
import WebKit

/// A request belongs to one hidden-to-visible transition. It ends on success,
/// user interaction, hide, error, or a short hydration timeout. No idle polling.
@MainActor
final class ComposerFocusController {
    private weak var webView: WKWebView?
    var canFocus: () -> Bool = { true }
    var isEnabled = true { didSet { if !isEnabled { cancel() } } }
    private(set) var isPresented = false
    private(set) var isPending = false
    private var revision: UInt = 0
    private var task: Task<Void, Never>?
    private var interactionMonitor: Any?
    private let world = WKContentWorld.world(name: "YourDotMini.ComposerFocus")

    init(webView: WKWebView) { self.webView = webView }

    func setPresented(_ presented: Bool) {
        guard presented != isPresented else { return }
        isPresented = presented
        cancel()
        guard presented, isEnabled else { return }
        isPending = true
        // Inspect event type only, inside this app. Never consume an event or
        // examine typed characters. Delayed autofocus must yield to user intent.
        interactionMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] event in
            self?.cancel()
            return event
        }
        resumeAfterNavigation()
    }

    func navigationStarted() {
        revision &+= 1
        task?.cancel()
        task = nil
    }

    func resumeAfterNavigation() {
        guard isPending, task == nil, webView?.isLoading == false else { return }
        let request = revision
        task = Task { [weak self] in
            for attempt in 0..<20 {
                guard !Task.isCancelled, let self, self.revision == request,
                      self.isPending, self.isPresented, self.isEnabled else { return }
                guard self.canFocus(), let webView = self.webView,
                      ComposerFocusScript.permits(webView.url) else { self.cancel(); return }
                let result: String = await withCheckedContinuation { continuation in
                    webView.evaluateJavaScript(ComposerFocusScript.source, in: nil, in: self.world) { result in
                        continuation.resume(returning: (try? result.get()) as? String ?? "unavailable")
                    }
                }
                guard !Task.isCancelled, self.revision == request, self.isPending else { return }
                if result == "focused", self.canFocus() {
                    // This sets the responder *within* the window. It never
                    // activates the app, makes a window key, or orders it forward.
                    webView.window?.makeFirstResponder(webView)
                }
                guard result == "missing", attempt < 19 else { self.cancel(); return }
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
        }
    }

    func cancel() {
        revision &+= 1
        isPending = false
        task?.cancel()
        task = nil
        if let interactionMonitor { NSEvent.removeMonitor(interactionMonitor) }
        interactionMonitor = nil
    }
}
