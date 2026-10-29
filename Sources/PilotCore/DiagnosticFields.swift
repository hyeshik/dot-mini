import Foundation

public enum DiagnosticFields {
    /// Never return a path, query, fragment, user info, or page title.
    public static func host(_ url: URL?) -> String {
        guard let host = url?.host?.lowercased(), !host.isEmpty,
              host.unicodeScalars.allSatisfy({
                  CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-:[]").contains($0)
              }) else { return "none" }
        return String(host.prefix(253))
    }

    /// Error userInfo and descriptions can contain complete URLs or site content.
    public static func error(_ error: NSError) -> String {
        let domain: String
        switch error.domain {
        case NSURLErrorDomain: domain = "NSURLErrorDomain"
        case "WKErrorDomain": domain = "WKErrorDomain"
        case NSPOSIXErrorDomain: domain = "NSPOSIXErrorDomain"
        case NSCocoaErrorDomain: domain = "NSCocoaErrorDomain"
        default: domain = "OtherErrorDomain"
        }
        return "\(domain):\(error.code)"
    }
}
