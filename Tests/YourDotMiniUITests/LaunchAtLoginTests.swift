import Foundation
import ServiceManagement
import Testing
@testable import YourDotMiniUI

@MainActor
struct LaunchAtLoginTests {
    @Test(arguments: [SMAppService.Status.enabled, .requiresApproval, .notRegistered, .notFound])
    func reflectsSystemStateWithoutRegistering(_ state: SMAppService.Status) {
        let backend = TestLoginItem(status: state)
        let service = LaunchAtLoginService(loginItem: backend)
        #expect(service.status == state)
        #expect(service.requested == (state == .enabled || state == .requiresApproval))
        #expect(!service.description.isEmpty)
        #expect(backend.registerCalls == 0 && backend.unregisterCalls == 0)
        backend.status = .notRegistered
        service.refresh()
        #expect(service.status == .notRegistered)
        #expect(!service.requested)
        #expect(backend.registerCalls == 0 && backend.unregisterCalls == 0)
    }

    @Test func explicitEnableReflectsRequiredApprovalAndDoesNotRegisterTwice() async {
        let backend = TestLoginItem(status: .notRegistered)
        backend.statusAfterRegistration = .requiresApproval
        let service = LaunchAtLoginService(loginItem: backend)
        await service.setEnabled(true)
        #expect(service.status == .requiresApproval)
        #expect(service.requested)
        #expect(service.description.contains("Approve"))
        await service.setEnabled(true)
        #expect(backend.registerCalls == 1)
        #expect(!service.isUpdating)
    }

    @Test func disableUsesCurrentSystemStateInsteadOfStaleDisplayState() async {
        let backend = TestLoginItem(status: .notRegistered)
        let service = LaunchAtLoginService(loginItem: backend)
        backend.status = .enabled
        await service.setEnabled(false)
        #expect(backend.unregisterCalls == 1)
        #expect(service.status == .notRegistered)
        #expect(!service.requested)
    }

    @Test func alreadyDisabledDoesNotUnregister() async {
        let backend = TestLoginItem(status: .notRegistered)
        let service = LaunchAtLoginService(loginItem: backend)
        await service.setEnabled(false)
        #expect(backend.registerCalls == 0 && backend.unregisterCalls == 0)
    }

    @Test func failedRegistrationKeepsSystemStateAndRedactsErrorDetails() async {
        let backend = TestLoginItem(status: .notFound)
        backend.registrationError = NSError(domain: "private-test-domain", code: 17,
                                            userInfo: [NSLocalizedDescriptionKey: "private-test-details"])
        let service = LaunchAtLoginService(loginItem: backend)
        await service.setEnabled(true)
        #expect(service.status == .notFound)
        #expect(!service.requested && !service.isUpdating)
        #expect(service.errorMessage?.contains("17") == true)
        #expect(service.errorMessage?.contains("private-test") == false)
        backend.registrationError = nil
        await service.setEnabled(true)
        #expect(service.status == .enabled)
        #expect(service.errorMessage == nil)
    }

    @Test func failedUnregistrationKeepsEnabledState() async {
        let backend = TestLoginItem(status: .enabled)
        backend.unregistrationError = NSError(domain: "test", code: 5)
        let service = LaunchAtLoginService(loginItem: backend)
        await service.setEnabled(false)
        #expect(service.status == .enabled)
        #expect(service.requested && !service.isUpdating)
        #expect(service.errorMessage != nil)
    }

    @Test func overlappingChangesAreSuppressedDuringUnregistration() async {
        let backend = TestLoginItem(status: .enabled)
        backend.suspendUnregistration = true
        let service = LaunchAtLoginService(loginItem: backend)
        let pending = Task { await service.setEnabled(false) }
        for _ in 0..<100 where backend.unregistrationContinuation == nil {
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(service.isUpdating)
        await service.setEnabled(true)
        #expect(backend.registerCalls == 0 && backend.unregisterCalls == 1)
        backend.unregistrationContinuation?.resume()
        backend.unregistrationContinuation = nil
        await pending.value
        #expect(service.status == .notRegistered && !service.isUpdating)
    }
}

/// Never modifies the real machine's login items.
@MainActor
private final class TestLoginItem: LoginItemManaging {
    var status: SMAppService.Status
    var statusAfterRegistration: SMAppService.Status = .enabled
    var registerCalls = 0
    var unregisterCalls = 0
    var registrationError: Error?
    var unregistrationError: Error?
    var suspendUnregistration = false
    var unregistrationContinuation: CheckedContinuation<Void, Never>?
    init(status: SMAppService.Status) { self.status = status }
    func register() throws {
        registerCalls += 1
        if let registrationError { throw registrationError }
        status = statusAfterRegistration
    }
    func unregister() async throws {
        unregisterCalls += 1
        if let unregistrationError { throw unregistrationError }
        if suspendUnregistration {
            await withCheckedContinuation { unregistrationContinuation = $0 }
        }
        status = .notRegistered
    }
    func openSystemSettings() {}
}
