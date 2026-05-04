//
//  PersistenceService.swift
//  SentinelBot
//
//  Concrete UserDefaults-backed persistence. Implemented in full (no external
//  deps) so we can use it from Phase A onward.
//

import Foundation

final class PersistenceService: PersistenceServiceProtocol {

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = .iso8601
        self.decoder = .iso8601
    }

    // MARK: - Broker config

    func loadBrokerConfig() -> BrokerConfig? {
        guard let data = defaults.data(forKey: Constants.PersistenceKeys.brokerConfig) else {
            return nil
        }
        do {
            return try decoder.decode(BrokerConfig.self, from: data)
        } catch {
            Log.persistence.error("Failed to decode BrokerConfig: \(error.localizedDescription)")
            return nil
        }
    }

    func saveBrokerConfig(_ config: BrokerConfig) throws {
        let data = try encoder.encode(config)
        defaults.set(data, forKey: Constants.PersistenceKeys.brokerConfig)
        Log.persistence.info("Saved broker config for host \(config.host, privacy: .public)")
    }

    // MARK: - Last used mode

    func loadLastUsedMode() -> RobotMode? {
        guard let raw = defaults.string(forKey: Constants.PersistenceKeys.lastUsedMode) else {
            return nil
        }
        return RobotMode(rawValue: raw)
    }

    func saveLastUsedMode(_ mode: RobotMode) throws {
        defaults.set(mode.rawValue, forKey: Constants.PersistenceKeys.lastUsedMode)
    }

    // MARK: - Onboarding

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Constants.PersistenceKeys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Constants.PersistenceKeys.hasCompletedOnboarding) }
    }

    // MARK: - Reset

    func reset() {
        defaults.removeObject(forKey: Constants.PersistenceKeys.brokerConfig)
        defaults.removeObject(forKey: Constants.PersistenceKeys.lastUsedMode)
        defaults.removeObject(forKey: Constants.PersistenceKeys.hasCompletedOnboarding)
        Log.persistence.notice("Persistence reset")
    }
}
