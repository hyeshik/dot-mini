import Foundation

public enum PilotIdentity {
    public static let bundleIdentifier = "local.YourDotMini.AuthPilot"
    public static let entryURL = URL(string: "https://chatgpt.com/dots")!
}

public enum NavigationRoute: Equatable {
    case embedded
    case browser
    case confirmAuthenticationHost(String)
    case blocked
}

/// Top-level navigation only. WebKit retains its normal subresource/security policy.
public struct NavigationPolicy {
    public var approvedAuthenticationHosts: Set<String> = []

    private let firstPartyHosts: Set<String> = [
        "chatgpt.com", "www.chatgpt.com", "auth.chatgpt.com", "auth.openai.com",
    ]
    private let identityProviderHosts: Set<String> = [
        "accounts.google.com", "appleid.apple.com", "login.microsoftonline.com", "login.live.com",
    ]

    public init() {}

    public func route(_ url: URL?, isUserLink: Bool) -> NavigationRoute {
        guard let url, url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil,
              url.port == nil || url.port == 443,
              let host = url.host?.lowercased(), !host.isEmpty else { return .blocked }

        if firstPartyHosts.contains(host) || approvedAuthenticationHosts.contains(host) {
            return .embedded
        }
        if identityProviderHosts.contains(host) || !isUserLink {
            // Enterprise SSO domains cannot be enumerated in advance. Each new
            // redirect host needs a human decision, retained only for this run.
            return .confirmAuthenticationHost(host)
        }
        return .browser
    }
}
