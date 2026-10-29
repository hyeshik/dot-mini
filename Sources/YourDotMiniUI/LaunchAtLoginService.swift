import Combine
import ServiceManagement

@MainActor
protocol LoginItemManaging {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() async throws
    func openSystemSettings()
}

@MainActor
private struct SystemLoginItem: LoginItemManaging {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() async throws { try await SMAppService.mainApp.unregister() }
    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

@MainActor
final class LaunchAtLoginService: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorMessage: String?
    @Published private(set) var isUpdating = false
    private let loginItem: any LoginItemManaging

    init(loginItem: (any LoginItemManaging)? = nil) {
        let loginItem = loginItem ?? SystemLoginItem()
        self.loginItem = loginItem
        status = loginItem.status
    }
    var requested: Bool { status == .enabled || status == .requiresApproval }
    var description: String {
        switch status {
        case .enabled: "Enabled in macOS."
        case .requiresApproval: "Approve YourDotMini in System Settings → Login Items."
        case .notRegistered: "Off. YourDotMini will not launch automatically."
        case .notFound: "macOS could not find this app. Keep it in a stable location and try again."
        @unknown default: "Login item status is unavailable."
        }
    }
    func refresh() { status = loginItem.status }
    func setEnabled(_ enabled: Bool) async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { refresh(); isUpdating = false }
        // System Settings may have changed since this window was opened.
        refresh()
        do {
            if enabled && !requested { try loginItem.register() }
            else if !enabled && requested { try await loginItem.unregister() }
            errorMessage = nil
        } catch {
            let error = error as NSError
            errorMessage = "macOS could not update launch at login (code \(error.code)). Check Login Items in System Settings."
        }
    }
    func openSystemSettings() { loginItem.openSystemSettings() }
}
