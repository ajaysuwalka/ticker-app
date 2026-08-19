import Foundation

/// Guesses a default productivity category for an app from its name/bundle id.
/// User assignments in `TickerStore` always take precedence over these defaults.
///
/// Matching is **token-based**: the bundle id and name are split on
/// non-alphanumeric boundaries into whole words, so a generic keyword like
/// `word` matches `com.microsoft.Word` but not `com.agilebits.1Password`.
/// Multi-word brands ("visual studio", "prime video") are matched as substrings
/// via the `*Phrases` lists.
enum CategoryGuesser {
    // MARK: Productive — dev tools, design, office, notes/PM, work comms, research.
    private static let productiveTokens: Set<String> = [
        // Editors / IDEs / terminals
        "xcode", "vscode", "code", "cursor", "windsurf", "terminal", "iterm", "iterm2",
        "warp", "alacritty", "kitty", "hyper", "tmux", "intellij", "idea", "pycharm",
        "goland", "webstorm", "phpstorm", "rubymine", "clion", "rider", "datagrip",
        "appcode", "fleet", "sublime", "sublimetext", "nova", "zed", "vim", "neovim",
        "nvim", "emacs", "textmate", "brackets", "atom", "eclipse", "netbeans",
        // Dev infra / db / api / vcs
        "docker", "orbstack", "podman", "postman", "insomnia", "paw", "bruno",
        "tableplus", "sequel", "sequelpro", "sequelace", "dbeaver", "datagrip",
        "mongodb", "compass", "redis", "pgadmin", "git", "github", "gitkraken",
        "tower", "sourcetree", "fork", "sublimemerge", "lens", "k9s", "terraform",
        "vagrant", "ngrok", "wireshark", "charles", "proxyman",
        // Notes / PM / productivity
        "notion", "obsidian", "bear", "craft", "roam", "logseq", "evernote",
        "onenote", "todoist", "things", "omnifocus", "ticktick", "fantastical",
        "linear", "jira", "confluence", "asana", "trello", "clickup", "monday",
        "height", "shortcut", "basecamp", "airtable", "coda", "miro", "mural",
        // Design / media production
        "figma", "sketch", "affinity", "photoshop", "illustrator", "indesign",
        "lightroom", "aftereffects", "premiere", "fcpx", "davinci", "blender",
        "cinema4d", "framer", "principle", "invision", "zeplin", "abstract",
        "procreate", "pixelmator", "acorn",
        // Office / docs
        "word", "excel", "powerpoint", "keynote", "pages", "numbers", "outlook",
        "libreoffice", "openoffice", "sheets", "slides", "docs", "onedrive",
        // Data / science
        "jupyter", "rstudio", "matlab", "stata", "spss", "anaconda", "spyder",
        "tableau", "powerbi", "looker", "metabase", "octave",
        // Work communication / meetings
        "slack", "teams", "zoom", "webex", "meet", "mattermost", "rocketchat",
        "skype", "gotomeeting", "loom", "whereby", "around",
        // Email
        "mail", "spark", "superhuman", "airmail", "thunderbird", "canary", "mimestream",
        // Reading / research
        "zotero", "mendeley", "papers", "devonthink", "readwise", "calibre"
    ]
    private static let productivePhrases = [
        "visual studio", "android studio", "sublime text", "sublime merge",
        "google docs", "google sheets", "google slides", "final cut", "microsoft teams",
        "google meet", "prime studio"
    ]

    // MARK: Distracting — streaming, social, games.
    private static let distractingTokens: Set<String> = [
        "youtube", "netflix", "steam", "twitch", "kick", "instagram", "tiktok",
        "facebook", "messenger", "reddit", "twitter", "snapchat", "pinterest",
        "tumblr", "hulu", "disney", "disneyplus", "primevideo", "hbomax", "peacock",
        "9gag", "imgur", "onlyfans", "hinge", "tinder", "bumble", "game", "games",
        "battlenet", "origin", "roblox", "minecraft", "valorant", "fortnite",
        "leagueoflegends", "epicgames"
    ]
    private static let distractingPhrases = [
        "prime video", "epic games", "battle.net", "call of duty", "hbo max"
    ]

    static func guess(bundleId: String, name: String) -> AppCategory {
        let hay = (bundleId + " " + name).lowercased()
        let tokens = Set(hay.split { !$0.isLetter && !$0.isNumber }.map(String.init))

        if distractingPhrases.contains(where: hay.contains) || !tokens.isDisjoint(with: distractingTokens) {
            return .distracting
        }
        if productivePhrases.contains(where: hay.contains) || !tokens.isDisjoint(with: productiveTokens) {
            return .productive
        }
        return .neutral
    }
}
