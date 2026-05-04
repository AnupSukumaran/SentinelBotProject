//
//  Logger.swift
//  SentinelBot
//
//  Thin wrapper around os.Logger giving us pre-configured categories.
//  Use `Log.mqtt.info("…")` etc. throughout the app.
//
//  View these in Console.app on macOS while debugging on a real device:
//  filter by subsystem `com.sentinelbot.app`.
//

import Foundation
import OSLog

enum Log {
    private static let subsystem = "com.sentinelbot.app"

    static let app        = Logger(subsystem: subsystem, category: "app")
    static let mqtt       = Logger(subsystem: subsystem, category: "mqtt")
    static let command    = Logger(subsystem: subsystem, category: "command")
    static let telemetry  = Logger(subsystem: subsystem, category: "telemetry")
    static let ui         = Logger(subsystem: subsystem, category: "ui")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
}
