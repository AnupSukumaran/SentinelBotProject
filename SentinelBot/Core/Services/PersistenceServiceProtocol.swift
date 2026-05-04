//
//  PersistenceServiceProtocol.swift
//  SentinelBot
//
//  Wraps UserDefaults so we can mock it in tests and so that storage keys
//  live in one place (Constants.PersistenceKeys).
//
//  Why not @AppStorage everywhere? Because @AppStorage couples views to
//  storage, which kills testability. Persistence belongs in the service layer.
//

import Foundation

protocol PersistenceServiceProtocol: AnyObject {

    func loadBrokerConfig() -> BrokerConfig?
    func saveBrokerConfig(_ config: BrokerConfig) throws

    func loadLastUsedMode() -> RobotMode?
    func saveLastUsedMode(_ mode: RobotMode) throws

    var hasCompletedOnboarding: Bool { get set }

    /// Clears all stored data — for the "reset app" settings option.
    func reset()
}
