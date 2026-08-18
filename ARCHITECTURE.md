# Ticker — Architecture

Ticker is a native macOS (SwiftUI + AppKit) app organized in clear layers. It
follows **MVVM over an observable store, with a services layer** — an
`ObservableObject` store is the single source of truth, a per-screen view model
holds screen state/logic, views are declarative, and side-effecting work lives
in dedicated services. It's deliberately lightweight: one focused view model,
no DI framework or protocol ceremony.

```
Sources/Ticker/
├── App/          @main entry & scene graph
├── Models/       Pure value types (records, summaries, settings, enums)
├── Store/        The observable data layer (persistence + derived reads)
├── Engine/       The tracking runtime (sampling loop, input monitors)
├── Services/     Stateless, single-purpose side-effecting units
├── ViewModels/   Per-screen state + logic (DashboardViewModel)
└── Views/        Declarative SwiftUI, grouped by screen + shared components
```

## Layers & responsibilities

### App
`TickerApp.swift` — the `@main` `App`. Owns the two long-lived objects
(`TickerStore`, `Tracker`) as `@StateObject`, injects them into the environment,
and declares the three scenes: `WindowGroup` (dashboard), `MenuBarExtra`
(popover), and `Settings`.

### Models (`Models/`)
Plain `Codable`/`Identifiable` value types with no behavior:
`MinuteRecord`, `AppCategory`, `DaySummary`, `ActivityBlock`, `MinuteEntry`,
`DayBreakdown`, `ScreenShot`, `Timescale`, `PersistedData`, and the `Format`
helpers. Codable types use **tolerant decoders** (`decodeIfPresent … ?? default`)
so adding a field never invalidates an existing data file.

### Store (`Store/`) — the model layer
`TickerStore` is the single source of truth and the only `ObservableObject` most
views observe. It is split by responsibility so it doesn't become a god-object:

- **`TickerStore.swift`** — state + persistence: the records/settings, `addTick`,
  category assignment, atomic JSON load/save (coalesced debounce), and on-disk
  screenshot management.
- **`TickerStore+Analytics.swift`** — pure, read-only aggregations (summaries,
  daily breakdowns, hourly stats, focus sessions/streak, weekly recap, activity
  blocks, timelines). These never mutate state.
- **`CategoryGuesser.swift`** — default app categorization heuristics.

A deliberate performance choice: `recordsByMinute` is **not** `@Published`
(it mutates every second while tracking); views read aggregates through
snapshots instead of re-rendering on every tick.

### Engine (`Engine/`)
The tracking runtime, separated from data:

- **`Tracker`** — an `ObservableObject` that runs the 1-second sampling loop,
  publishes live status (`currentApp`, `isTracking`, …), and writes ticks to the
  store. Owns start/stop and all app-lifecycle flushes.
- **`ActivityMonitor`** — global keyboard/mouse event counters + idle timing.

### Services (`Services/`)
Stateless, single-purpose units (mostly `enum` namespaces) invoked on demand:
`Permissions`, `ContextReader` (window-title reader), `ScreenshotService`,
`Notifier`, `LoginItem`, `CSVExporter`, `PDFReporter` (+ its `ReportView`).
Each has one reason to change and no cross-dependencies beyond the store.

### Views (`Views/`)
Grouped by screen, with reusable pieces separated from screen composition:

- **`Dashboard/`** — `DashboardView` (screen composition only) plus
  `DashboardSections` and `DashboardWidgets` (the reusable charts, tiles,
  category columns, screenshot viewer, calendar, rings).
- **`MenuBar/`**, **`Settings/`** — the other two scenes.
- **`Shared/`** — cross-screen primitives (`Card`, `StatTile`, `MiniBar`,
  `AppIconView`, …).

### ViewModels (`ViewModels/`)
`DashboardViewModel` (`@MainActor ObservableObject`) owns the dashboard's screen
state (selected `scope`/`anchor`, the computed `DashboardSnapshot`, refresh
cadence, permission status) and every action (navigation, recategorize,
delete-screenshot, exports). `DashboardView` is then purely declarative: it reads
`model.snapshot` and calls `model` methods, holding only trivial UI state (which
popover/sheet is open). Other screens (menu bar, settings) are simple enough to
bind directly to the store — no view model is forced where it adds nothing.

## State

- **App/domain state** lives in `TickerStore` (persisted) and `Tracker` (live),
  injected via `@EnvironmentObject`.
- **Screen state** lives in a view model (`DashboardViewModel`), also injected
  via `@EnvironmentObject`. The dashboard builds a snapshot of all heavy queries
  once per refresh (on demand / every 5 min while active) rather than querying
  per frame — the key to smooth scrolling.
- **Trivial UI state** (open popovers/sheets) stays in the view as `@State`.

## Conventions

- **Concurrency:** UI + store + engine are `@MainActor`; only `ScreenshotService`
  hops to a background `Task` for ScreenCaptureKit and image encoding.
- **Persistence:** one atomic JSON file + a `shots/` thumbnail directory under
  `~/Library/Application Support/Ticker/`. Nothing leaves the device.
- **Extending:** add a query to `TickerStore+Analytics`, surface it via a field on
  `DashboardSnapshot`, populate it in `DashboardViewModel.rebuild()`, and render
  a view in `DashboardSections`/`DashboardWidgets`. Add new side-effects as a new
  file in `Services/`; add new user actions as methods on the view model.
