import SwiftUI
import AppKit

@main
struct TickerApp: App {
    @StateObject private var store: TickerStore
    @StateObject private var tracker: Tracker
    @StateObject private var dashboard: DashboardViewModel
    @StateObject private var breaks: BreakManager
    @StateObject private var breakPresenter: BreakPresenter
    @StateObject private var pausedPresenter: PausedReminderPresenter
    @StateObject private var idlePresenter: IdleReviewPresenter

    init() {
        let store = TickerStore()
        let breaks = BreakManager(store: store)
        let tracker = Tracker(store: store)
        _store = StateObject(wrappedValue: store)
        _tracker = StateObject(wrappedValue: tracker)
        _dashboard = StateObject(wrappedValue: DashboardViewModel(store: store))
        _breaks = StateObject(wrappedValue: breaks)
        _breakPresenter = StateObject(wrappedValue: BreakPresenter(breaks: breaks, store: store))
        _pausedPresenter = StateObject(wrappedValue: PausedReminderPresenter(tracker: tracker))
        _idlePresenter = StateObject(wrappedValue: IdleReviewPresenter(tracker: tracker))
    }

    var body: some Scene {
        WindowGroup(id: "dashboard") {
            DashboardView()
                .environmentObject(store)
                .environmentObject(tracker)
                .environmentObject(dashboard)
                .environmentObject(breaks)
                .frame(minWidth: 900, minHeight: 640)
                .onAppear(perform: bootstrap)
        }
        .defaultSize(width: 1040, height: 740)
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .environmentObject(tracker)
                .environmentObject(breaks)
        } label: {
            // The menu-bar item is always instantiated at launch, so starting
            // the engine from its label guarantees tracking begins even when the
            // dashboard window doesn't open (e.g. relaunch with no restored
            // window). `bootstrap()` is idempotent, so the window firing it too
            // is harmless.
            MenuBarLabelView(tracker: tracker)
                .onAppear(perform: bootstrap)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(tracker)
        }
    }

    /// One-time engine start-up. Wired to both the dashboard window and the
    /// menu-bar label so tracking begins at launch regardless of which UI
    /// surface appears first; every call below is idempotent.
    private func bootstrap() {
        tracker.breaks = breaks
        tracker.start()
        breakPresenter.start()
        pausedPresenter.start()
        idlePresenter.start()
    }
}
