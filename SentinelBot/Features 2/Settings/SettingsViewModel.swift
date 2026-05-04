//
//  SettingsViewModel.swift
//  SentinelBot
//
//  Owns the editable copy of BrokerConfig and persists it on save.
//  The view binds directly to `config` properties; the ViewModel
//  validates and saves when the user taps Save.
//

import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: Published state

    @Published var config: BrokerConfig
    @Published private(set) var saveError: String?
    @Published private(set) var saveSuccess = false

    // MARK: Computed

    /// Non-nil when the current config fails validation.
    var validationError: String? { config.validationError() }

    var canSave: Bool { validationError == nil }

    // MARK: Dependencies

    private let persistenceService: PersistenceServiceProtocol

    // MARK: Init

    init(persistenceService: PersistenceServiceProtocol) {
        self.persistenceService = persistenceService
        self.config = persistenceService.loadBrokerConfig() ?? .default
    }

    // MARK: Actions

    func save() {
        guard canSave else { return }
        do {
            try persistenceService.saveBrokerConfig(config)
            saveError = nil
            saveSuccess = true
            // Clear the success flag after a short delay
            Task {
                try? await Task.sleep(for: .seconds(2))
                saveSuccess = false
            }
            Haptic.success()
            Log.app.info("Broker config saved: \(self.config.host):\(self.config.port)")
        } catch {
            saveError = error.localizedDescription
            Haptic.error()
        }
    }

    func resetToDefaults() {
        config = .default
        saveError = nil
        Haptic.medium()
    }

    func resetAllData() {
        persistenceService.reset()
        config = .default
        saveError = nil
        Haptic.warning()
        Log.app.notice("All persisted data cleared")
    }

    /// Regenerates the client ID (useful if two devices share the same ID).
    func regenerateClientID() {
        config.clientID = "sentinelbot-ios-\(UUID().uuidString.prefix(8))"
        Haptic.light()
    }
}
