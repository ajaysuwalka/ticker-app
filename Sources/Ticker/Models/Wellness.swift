import Foundation

/// The two kinds of health break the app reminds about.
enum BreakKind: String, Identifiable {
    case move      // stand up and move
    case screen    // rest your eyes / step away from the screen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .move: return "Time to move"
        case .screen: return "Screen break"
        }
    }

    var symbol: String {
        switch self {
        case .move: return "figure.walk"
        case .screen: return "eye"
        }
    }

    /// Short label for compact readouts (menu bar, dashboard next-break pill).
    var shortLabel: String {
        switch self {
        case .move: return "Move"
        case .screen: return "Eyes"
        }
    }

    var headline: String {
        switch self {
        case .move: return "Stand up and move for 1–2 minutes"
        case .screen: return "Take a 5–10 minute break from the screen"
        }
    }

    /// Recommended break length.
    var recommendedDuration: String {
        switch self {
        case .move: return "1–2 minutes"
        case .screen: return "5–10 minutes"
        }
    }

    /// Short reason shown to the user.
    var reason: String {
        switch self {
        case .move: return "You've been sitting and working for a while."
        case .screen: return "Your eyes have been on the screen for a while."
        }
    }

    var tips: [String] {
        switch self {
        case .move:
            return [
                "Stand up and stretch — roll your shoulders and neck gently.",
                "Walk around for 1–2 minutes.",
                "Reset your posture when you sit back down."
            ]
        case .screen:
            return [
                "Look away and focus on something in the distance (20-20-20).",
                "Rest your eyes for 5–10 minutes.",
                "Don't use other electronic devices while resting."
            ]
        }
    }
}

/// Static ergonomic guidance shown in Settings → Wellness.
enum Wellness {
    static let ergonomics: [String] = [
        "Keep your feet flat on the ground and your back supported by the chair.",
        "Center the keyboard directly in front of you.",
        "Center the screen above the keyboard.",
        "Prefer a desktop computer when you can.",
        "Keep the screen about 40–70 cm from your eyes.",
        "Arrange lighting and windows so they don't cause glare.",
        "Every 30 minutes, stand up and move for 1–2 minutes.",
        "Every 60 minutes, take a 5–10 minute break from the screen.",
        "Don't use other electronic devices while resting.",
        "To avoid eye fatigue, look away and focus on something in the distance."
    ]
}
