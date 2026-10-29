import Foundation
import OSLog
import PilotCore

@MainActor
final class PilotDiagnostics {
    enum Event: String {
        case processStart, processExit, windowShown, windowHidden
        case navigationRequested, navigationStarted, navigationRedirected, navigationCommitted, navigationFinished
        case navigationFailed, navigationBlocked, authenticationHostAllowed, authenticationHostDeclined
        case browserOpened, browserOpenFailed, popupBlocked, downloadBlocked, mediaBlocked
        case webProcessTerminated, dataClearStarted, dataClearFinished
    }

    private let logger = Logger(subsystem: PilotIdentity.bundleIdentifier, category: "pilot")
    private let started = ProcessInfo.processInfo.systemUptime

    func record(_ event: Event, url: URL? = nil, error: NSError? = nil) {
        let host = DiagnosticFields.host(url)
        let failure = error.map(DiagnosticFields.error) ?? "none"
        let elapsed = Int((ProcessInfo.processInfo.systemUptime - started) * 1_000)
        logger.notice("event=\(event.rawValue, privacy: .public) host=\(host, privacy: .public) error=\(failure, privacy: .public) elapsed_ms=\(elapsed, privacy: .public)")
    }
}
