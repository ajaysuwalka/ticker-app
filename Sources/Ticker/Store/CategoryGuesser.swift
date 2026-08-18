import Foundation

/// Guesses a default productivity category for an app from its name/bundle id.
/// User assignments in `TickerStore` always take precedence over these defaults.
enum CategoryGuesser {
    private static let productive = [
        "xcode", "vscode", "visual studio", "code", "cursor", "terminal", "iterm",
        "intellij", "pycharm", "goland", "webstorm", "rubymine", "clion", "android studio",
        "sublime", "nova", "zed", "vim", "emacs", "docker", "postman", "insomnia",
        "notion", "obsidian", "bear", "figma", "sketch", "affinity",
        "word", "excel", "powerpoint", "keynote", "pages", "numbers",
        "jupyter", "rstudio", "matlab", "tableplus", "sequel", "linear", "jira"
    ]
    private static let distracting = [
        "youtube", "netflix", "steam", "twitch", "instagram", "tiktok", "facebook",
        "reddit", "twitter", "game", "hulu", "disney", "primevideo"
    ]

    static func guess(bundleId: String, name: String) -> AppCategory {
        let hay = (bundleId + " " + name).lowercased()
        if distracting.contains(where: hay.contains) { return .distracting }
        if productive.contains(where: hay.contains) { return .productive }
        return .neutral
    }
}
