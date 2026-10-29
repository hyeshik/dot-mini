import Foundation
import OSLog
import PilotCore
import YourDotMiniCore

@MainActor
final class DotDiagnostics {
    enum Event: String {
        case processStart, processExit, browserCreated, windowShown, windowHidden
        case navigationStarted, navigationFinished, navigationFailed, navigationBlocked
        case authenticationHostAllowed, authenticationHostDeclined
        case popupBlocked, downloadBlocked, mediaBlocked, webProcessTerminated
        case browserOpened, browserOpenFailed, dataClearStarted, dataClearFinished
        case shortcutPressed
    }
    private let logger = Logger(subsystem: DotIdentity.bundleIdentifier, category: "app")
    private let start = ProcessInfo.processInfo.systemUptime

    func record(_ event: Event, url: URL? = nil, error: NSError? = nil) {
        let host = DiagnosticFields.host(url)
        let failure = error.map(DiagnosticFields.error) ?? "none"
        let elapsed = Int((ProcessInfo.processInfo.systemUptime - start) * 1_000)
        logger.notice("event=\(event.rawValue, privacy: .public) host=\(host, privacy: .public) error=\(failure, privacy: .public) elapsed_ms=\(elapsed, privacy: .public)")
    }
}
