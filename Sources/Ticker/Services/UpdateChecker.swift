import Foundation
import AppKit

struct UpdateInfo: Equatable {
    let version: String
    let url: URL
}

/// Checks GitHub Releases for a newer version and publishes it so the UI can
/// show an "update available" banner. This is the ONLY network request Ticker
/// makes — a read-only version check that sends none of your tracked data. It
/// fails silently when offline.
@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var available: UpdateInfo?

    private let currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    private let endpoint = URL(string: "https://api.github.com/repos/ajaysuwalka/ticker-app/releases/latest")!
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        check()
        // Re-check once a day while the app runs.
        let timer = Timer(timeInterval: 24 * 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    func check() {
        Task { await fetchLatest() }
    }

    /// Open the release page for the available update.
    func openDownloadPage() {
        if let url = available?.url { NSWorkspace.shared.open(url) }
    }

    private func fetchLatest() async {
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.setValue("Ticker-macOS", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let page = (json["html_url"] as? String).flatMap(URL.init(string:))
        else { return }

        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        available = Self.isNewer(latest, than: currentVersion)
            ? UpdateInfo(version: latest, url: page)
            : nil
    }

    /// Semantic-ish comparison: 1.0.2 > 1.0.1 > 1.0.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ s: String) -> [Int] { s.split(separator: ".").map { Int($0) ?? 0 } }
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let ai = i < a.count ? a[i] : 0
            let bi = i < b.count ? b[i] : 0
            if ai != bi { return ai > bi }
        }
        return false
    }
}
