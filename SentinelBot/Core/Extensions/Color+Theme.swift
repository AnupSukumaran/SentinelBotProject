//
//  Color+Theme.swift
//  SentinelBot
//
//  App-wide colour palette. Use these everywhere instead of literal Color values
//  so a future redesign or accessibility audit only touches one file.
//

import SwiftUI

extension Color {
    enum Theme {
        // Brand
        static let accent       = Color("AccentColor")            // defined in Assets.xcassets
        static let robotPrimary = Color(red: 0.20, green: 0.78, blue: 0.55)

        // Semantic
        static let success = Color(red: 0.20, green: 0.78, blue: 0.40)
        static let warning = Color(red: 1.00, green: 0.70, blue: 0.10)
        static let danger  = Color(red: 0.95, green: 0.25, blue: 0.25)
        static let info    = Color(red: 0.20, green: 0.55, blue: 0.95)

        // Surfaces
        static let background       = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let groupedBackground = Color(.systemGroupedBackground)
        static let cardBackground   = Color(.tertiarySystemBackground)

        // Text
        static let primaryText   = Color(.label)
        static let secondaryText = Color(.secondaryLabel)
        static let tertiaryText  = Color(.tertiaryLabel)
    }
}

// MARK: - Connection state colours

extension ConnectionState {
    var color: Color {
        switch self {
        case .connected:                   return Color.Theme.success
        case .connecting, .reconnecting:   return Color.Theme.warning
        case .disconnected:                return Color.Theme.secondaryText
        case .error:                       return Color.Theme.danger
        }
    }
}

// MARK: - Battery colours

extension BatteryStatus {
    var displayColor: Color {
        if isCritical { return Color.Theme.danger }
        if isLow      { return Color.Theme.warning }
        return Color.Theme.success
    }
}

// MARK: - Distance colours

extension DistanceReading {
    var displayColor: Color {
        if isCritical { return Color.Theme.danger }
        if isWarning  { return Color.Theme.warning }
        return Color.Theme.success
    }
}
