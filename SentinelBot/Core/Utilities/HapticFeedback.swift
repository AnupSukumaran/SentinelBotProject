//
//  HapticFeedback.swift
//  SentinelBot
//
//  Convenience wrapper around UIKit haptic generators.
//  Use these for: emergency stop confirmation, mode toggle, connection events.
//

import UIKit

enum Haptic {
    static func light()    { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()   { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy()    { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func rigid()    { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }

    static func success()  { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning()  { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()    { UINotificationFeedbackGenerator().notificationOccurred(.error) }

    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}
