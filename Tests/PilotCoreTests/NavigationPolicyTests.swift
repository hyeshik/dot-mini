import Foundation
import Testing
@testable import PilotCore

struct NavigationPolicyTests {
    @Test(arguments: [
        "https://chatgpt.com/dots", "https://chatgpt.com/c/example",
        "https://auth.openai.com/authorize?code=secret", "https://auth.chatgpt.com/",
        "https://CHATGPT.COM:443/dots",
    ])
    func firstPartyStaysEmbedded(_ address: String) {
        #expect(NavigationPolicy().route(URL(string: address), isUserLink: false) == .embedded)
    }

    @Test(arguments: [
        "http://chatgpt.com/dots", "javascript:alert(1)", "file:///tmp/example",
        "data:text/html,example", "yourdotmini://command", "about:blank",
        "https://user:secret@chatgpt.com/dots", "https://chatgpt.com:8443/dots",
    ])
    func unsafeTopLevelDestinationsAreBlocked(_ address: String) {
        #expect(NavigationPolicy().route(URL(string: address), isUserLink: true) == .blocked)
    }

    @Test(arguments: [
        "https://chatgpt.com.attacker.example/", "https://evilchatgpt.com/",
        "https://example.org/article", "https://openai.com/",
    ])
    func externalUserLinksUseBrowser(_ address: String) {
        #expect(NavigationPolicy().route(URL(string: address), isUserLink: true) == .browser)
    }

    @Test func unknownRedirectCannotSilentlyLeaveFirstParty() {
        let url = URL(string: "https://sso.example.org/callback?token=secret")!
        #expect(NavigationPolicy().route(url, isUserLink: false) == .confirmAuthenticationHost("sso.example.org"))
    }

    @Test(arguments: ["accounts.google.com", "appleid.apple.com", "login.microsoftonline.com", "login.live.com"])
    func identityProvidersRequireAnExplicitChoice(_ host: String) {
        let url = URL(string: "https://\(host)/sign-in")!
        #expect(NavigationPolicy().route(url, isUserLink: true) == .confirmAuthenticationHost(host))
    }

    @Test func approvalIsExactHostAndScopedToOnePolicyInstance() {
        var policy = NavigationPolicy()
        policy.approvedAuthenticationHosts.insert("sso.example.org")
        let url = URL(string: "https://sso.example.org/callback")!
        #expect(policy.route(url, isUserLink: false) == .embedded)
        #expect(policy.route(URL(string: "https://sso.example.org.attacker.example/"), isUserLink: false)
                == .confirmAuthenticationHost("sso.example.org.attacker.example"))
        #expect(policy.route(URL(string: "http://sso.example.org/"), isUserLink: false) == .blocked)
        #expect(NavigationPolicy().route(url, isUserLink: false) == .confirmAuthenticationHost("sso.example.org"))
    }

    @Test func missingURLIsBlocked() {
        #expect(NavigationPolicy().route(nil, isUserLink: true) == .blocked)
    }
}
