import AppKit
import UniformTypeIdentifiers

/// Exports tracked data to a CSV file via a Save panel.
enum CSVExporter {
    /// One row per day (all history) plus a block of per-app lifetime totals.
    @MainActor
    static func exportSummaries(store: TickerStore) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        var csv = "Date,Active (min),Productive (min),Neutral (min),Distracting (min),Productivity (%),Keystrokes,Clicks\n"
        for day in store.daysWithData().sorted() {
            let s = store.summary(on: day)
            let cols = [
                df.string(from: day),
                String(s.activeSeconds / 60),
                String(s.productiveSeconds / 60),
                String(s.neutralSeconds / 60),
                String(s.distractingSeconds / 60),
                String(Int((s.productivity * 100).rounded())),
                String(s.keyCount),
                String(s.mouseCount)
            ]
            csv += cols.joined(separator: ",") + "\n"
        }

        csv += "\nApp,Category,Total (min)\n"
        for app in store.knownApps() where app.seconds > 0 {
            csv += "\(escape(app.name)),\(app.category.title),\(app.seconds / 60)\n"
        }

        save(csv, suggested: "ticker-report.csv")
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    @MainActor
    private static func save(_ text: String, suggested: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggested
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? text.data(using: .utf8)?.write(to: url)
        }
    }
}
