import Foundation
import Testing
@testable import PilotCore

struct DiagnosticFieldsTests {
    @Test func hostDropsAllSensitiveURLComponents() {
        let url = URL(string: "https://username:password@auth.openai.com/private-conversation?code=secret&state=private#token")!
        #expect(DiagnosticFields.host(url) == "auth.openai.com")
    }

    @Test func missingOrNonWebHostIsNotAURL() {
        #expect(DiagnosticFields.host(nil) == "none")
        #expect(DiagnosticFields.host(URL(string: "about:blank")) == "none")
    }

    @Test func errorsDiscardDescriptionsAndUserInfo() {
        let error = NSError(domain: NSURLErrorDomain, code: -1009, userInfo: [
            NSLocalizedDescriptionKey: "Failed https://example.com/?token=secret",
            NSURLErrorFailingURLStringErrorKey: "https://example.com/private-conversation",
        ])
        #expect(DiagnosticFields.error(error) == "NSURLErrorDomain:-1009")
    }

    @Test func unknownErrorDomainsCannotLeakContent() {
        #expect(DiagnosticFields.error(NSError(domain: "private token", code: 3)) == "OtherErrorDomain:3")
        #expect(DiagnosticFields.error(NSError(domain: "WKErrorDomain", code: 2)) == "WKErrorDomain:2")
    }
}
