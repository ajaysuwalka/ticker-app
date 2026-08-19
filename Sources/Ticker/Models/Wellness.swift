import Foundation

/// The two kinds of health break the app reminds about.
enum BreakKind: String, Identifiable {
    case move      // stand up and move
    case screen    // rest your eyes / step away from the screen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .move: return tr("Time to move")
        case .screen: return tr("Screen break")
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
        case .move: return tr("Move")
        case .screen: return tr("Eyes")
        }
    }

    var headline: String {
        switch self {
        case .move: return tr("Stand up and move for 1–2 minutes")
        case .screen: return tr("Take a 5–10 minute break from the screen")
        }
    }

    /// Recommended break length.
    var recommendedDuration: String {
        switch self {
        case .move: return tr("1–2 minutes")
        case .screen: return tr("5–10 minutes")
        }
    }

    /// Short reason shown to the user.
    var reason: String {
        switch self {
        case .move: return tr("You've been sitting and working for a while.")
        case .screen: return tr("Your eyes have been on the screen for a while.")
        }
    }

    var tips: [String] {
        switch self {
        case .move:
            return [
                tr("Stand up and stretch — roll your shoulders and neck gently."),
                tr("Walk around for 1–2 minutes."),
                tr("Reset your posture when you sit back down.")
            ]
        case .screen:
            return [
                tr("Look away and focus on something in the distance (20-20-20)."),
                tr("Rest your eyes for 5–10 minutes."),
                tr("Don't use other electronic devices while resting.")
            ]
        }
    }
}

/// Static ergonomic guidance shown in Settings → Wellness.
enum Wellness {
    static var ergonomics: [String] {
        [
            tr("Keep your feet flat on the ground and your back supported by the chair."),
            tr("Center the keyboard directly in front of you."),
            tr("Center the screen above the keyboard."),
            tr("Prefer a desktop computer when you can."),
            tr("Keep the screen about 40–70 cm from your eyes."),
            tr("Arrange lighting and windows so they don't cause glare."),
            tr("Every 30 minutes, stand up and move for 1–2 minutes."),
            tr("Every 60 minutes, take a 5–10 minute break from the screen."),
            tr("Don't use other electronic devices while resting."),
            tr("To avoid eye fatigue, look away and focus on something in the distance.")
        ]
    }
}
