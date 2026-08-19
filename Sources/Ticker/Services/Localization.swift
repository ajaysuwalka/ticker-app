import Foundation

/// Localized lookup for strings that SwiftUI can't auto-localize — namely
/// runtime `String` values and multi-line literals joined with `+` (which resolve
/// to `Text(_ content: String)`, the *verbatim* initializer). Simple string
/// literals passed to `Text`/`Toggle`/`Button`/`Label`/`Picker` are already
/// `LocalizedStringKey` and localize automatically, so they don't need this.
///
/// The English source text doubles as the lookup key, matching how the
/// auto-localized literals are keyed, and is returned verbatim when a translation
/// is missing — so English is always a clean fallback.
func tr(_ english: String) -> String {
    NSLocalizedString(english, tableName: nil, bundle: .main, value: english, comment: "")
}
