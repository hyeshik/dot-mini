import Combine
import Foundation
import YourDotMiniCore

@MainActor
final class SettingsStore: ObservableObject {
    @Published private(set) var value: DotPreferences
    @Published private(set) var saveError: String?
    private let repository: PreferencesRepository
    init(repository: PreferencesRepository = PreferencesRepository()) {
        self.repository = repository
        value = repository.load()
    }
    func update(_ change: (inout DotPreferences) -> Void) {
        var next = value
        change(&next)
        next = next.sanitized()
        guard next != value else { return }
        do {
            try repository.save(next)
            value = next
            saveError = nil
        } catch { saveError = "Could not save settings. Try again." }
    }
}
