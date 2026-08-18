import Foundation
@testable import Ticker

/// A fixed, minute-aligned reference day so tests are deterministic.
let fixedDay = Date(timeIntervalSinceReferenceDate: 800_000_000).startOfDay

@MainActor
enum TestSupport {
    /// A store backed by a fresh temporary directory (isolated, no real data).
    static func makeStore() -> TickerStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ticker-tests-\(UUID().uuidString)", isDirectory: true)
        return TickerStore(directory: dir)
    }

    /// Records `seconds` of active time for `bundle` in `minute`, attributing the
    /// given key/click/switch counts to the first seconds of that minute.
    static func addActive(_ store: TickerStore, minute: Date, bundle: String,
                          seconds: Int, keys: Int = 0, mouse: Int = 0, switches: Int = 0) {
        for i in 0..<seconds {
            store.addTick(minute: minute, bundleId: bundle, appName: bundle, active: true,
                          keys: i < keys ? 1 : 0, mouse: i < mouse ? 1 : 0,
                          switched: i < switches, context: nil)
        }
    }
}
