# Build Your Own Activity Tracker — Ticker

A step-by-step guide to building **Ticker**, a native macOS activity/productivity
tracker, on your own Mac — and understanding how it works so you can make it
your own.

Because everyone builds it locally from source, there's **no Gatekeeper hassle,
no "unidentified developer" wall, and no notarization needed** — a locally built
app is trusted on the machine that built it.

> **Privacy first:** Ticker counts *how many* keys/clicks you make — never *which*
> keys or *what* you type. The optional **Screen Timeline** (off by default) is
> the only feature that captures screen content, and its thumbnails stay
> on-device and auto-delete. Nothing ever leaves your Mac — all data lives in
> `~/Library/Application Support/Ticker/`.

---

## Table of contents

1. [What you'll build](#1-what-youll-build)
2. [Complete feature reference](#2-complete-feature-reference)
3. [Prerequisites](#3-prerequisites)
4. [Get the code](#4-get-the-code)
5. [Build & run](#5-build--run)
6. [Grant Accessibility](#6-grant-accessibility)
7. [How it works](#7-how-it-works)
8. [Project layout](#8-project-layout)
9. [Make it your own](#9-make-it-your-own)
10. [Sharing with the team](#10-sharing-with-the-team)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. What you'll build

A menu-bar + window macOS app that continuously logs which apps you use and how
active you are, classifies your time as productive or not, and surfaces it
through charts and insights — all on-device.

---

## 2. Complete feature reference

Every feature Ticker ships with, grouped by area.

### 2.1 Tracking engine

- **Frontmost-app tracking** — samples the active app once per second via
  `NSWorkspace`, recording its name and bundle id.
- **Keyboard interaction counting** — a global monitor counts key presses
  (`keyDown`). Counts only — never key codes or typed content.
- **Mouse interaction counting** — counts clicks (left/right/other) and scroll.
- **Mouse-movement handling** — movement and drags reset the idle timer but are
  *not* counted as interactions, so passive drift doesn't inflate the graph.
- **Idle vs. active detection** — combines a global idle timer
  (`CGEventSource`, works without permission) with monitor timing; a second is
  "active" if input arrived or the last input was within the idle threshold.
- **Context-switch counting** — records how often the frontmost app changes
  (`switchCount`), a fragmentation/focus signal.
- **Configurable idle threshold** — 30–300 s slider (default 90 s) controls when
  time counts as idle.
- **Graceful degradation** — app usage and active/idle time work *immediately*;
  only keystroke counts require Accessibility.

### 2.2 Productivity classification

- **Three categories** — every app is **Productive**, **Neutral**, or
  **Distracting**.
- **Smart defaults** — `CategoryGuesser` pre-tags common apps by name/bundle id
  (editors, terminals, design tools → productive; social/video/games →
  distracting; everything else → neutral).
- **Per-app overrides** — reclassify any app in **Settings → App Categories**,
  with search and lifetime-time shown per app.
- **Productive time** — active seconds spent in productive apps.
- **Productivity %** — productive ÷ active time.

### 2.3 Dashboard — headline stats

- **Live status** — a green/grey dot + "Active · <app>" / "Idle" that updates in
  real time (the one continuously-live UI element).
- **Stat tiles** — Active Time, Productive time, Productivity %, and total
  Interactions (with a keys-vs-clicks breakdown).

### 2.4 Dashboard — focus goal

- **Daily goal** — set a productive-time target (30–600 min slider).
- **Progress ring** — circular gauge of progress toward the goal.
- **Time-to-go / reached** — shows remaining time, or "Goal reached".
- **Range scaling** — in Week/Month views the goal scales by the number of
  elapsed days.
- **Goal notifications** — optional local notification the moment you first hit
  the goal each day (opt-in; asks for notification permission).

### 2.5 Dashboard — activity graph

- **Day view** — interactions across the hours of the day, as a smooth
  area + line chart.
- **Week / Month view** — stacked bars per day, split by
  Productive / Neutral / Distracting time, with a legend.

### 2.6 Dashboard — insights

- **Productivity trend** — a filled line of productivity % over time (trailing
  14 days in Day view, or the selected week/month) with a dashed **average**
  line.
- **Focus streak** — consecutive days meeting your goal (today counts if met;
  otherwise the streak runs through yesterday so an in-progress day never breaks
  it).
- **Deep-work sessions** — count of continuous 25 min+ productive blocks (gaps
  ≤ 2 min tolerated).
- **Longest focus** — your single deepest focus session in the range.
- **Context switches** — total app switches in the range.
- **Peak hours** — active minutes per hour-of-day as a bar chart, peak hour
  highlighted, with a "Most active around <hour>" callout.
- **Weekly recap** — a digest of the trailing 7 days: productive time, a signed
  **% delta vs. the previous 7 days**, your best day, top app, and average
  productivity.

### 2.7 Dashboard — breakdowns

- **Focus split donut** — Productive/Neutral/Distracting share, with the
  productivity % in the center and a legend showing each category's duration and
  percentage.
- **Top apps** — the most-used apps in the range, each with a category-colored
  bar and time.
- **Empty states** — friendly placeholders for periods with no data yet.

### 2.8 Calendar & time filtering

- **Day / Week / Month** scope selector — every panel re-aggregates to the
  chosen scope.
- **Graphical calendar** — a month-calendar popover to jump to any date; picking
  a date snaps to the containing day/week/month.
- **Period navigation** — previous/next arrows, a **Today** shortcut, and a
  human-readable range label (Today / Yesterday / date / week range / month).
- **No future** — navigation is capped at the current period.

### 2.9 Performance & refresh model

- **On-demand snapshot** — all heavy queries run once into a value snapshot; the
  view reads from it, so scrolling and per-second logging never trigger recompute.
- **Manual refresh** — a **Refresh** button with an "Updated HH:MM · auto every
  5 min" indicator.
- **Auto refresh** — every 5 minutes, **but only while the window is active**;
  nothing recomputes in the background.
- **Catch-up on return** — when you re-focus the window, it refreshes once if the
  data is more than 5 minutes stale.
- **Refresh on interaction** — changing scope or date rebuilds immediately.

### 2.10 Menu-bar popover

- **Current app + status** with its productivity category as a colored chip.
- **Today's numbers** — Active, Productive, and Focus % at a glance.
- **Focus bar** — a mini productivity progress bar.
- **Quick actions** — Open Dashboard, Settings…, Quit Ticker.

### 2.11 Settings

- **General** — Launch at login (`SMAppService`); goal notifications toggle.
- **Permissions** — Accessibility status with a one-click grant/open button.
- **Focus Goal** — daily target slider.
- **Idle Detection** — idle threshold slider.
- **Screen Timeline** — opt-in screenshot capture + **Delete all screenshots**.
- **Privacy** — a plain statement of what is and isn't recorded.
- **Data** — **Clear all tracked data** with a confirmation dialog.
- **App Categories** — searchable per-app category assignment.

### 2.12 Data, persistence & durability

- **Per-minute records** aggregated to one `MinuteRecord` per minute.
- **On-device JSON** at `~/Library/Application Support/Ticker/data.json`.
- **Rolling saves** — flushed on a coalesced ~10 s cadence.
- **Durable exit** — also flushed on Cmd-Q, logout/restart/shutdown (`SIGTERM`
  + power-off), and sleep, so a restart never loses tracked time.
- **Atomic writes** — a crash or power-loss can't corrupt the file (at most the
  last few seconds are lost).
- **Tolerant decoding** — missing fields fall back to defaults, so app upgrades
  never invalidate an existing data file.
- **Corruption-resistant load** — duplicate/edited keys can't crash the app on
  launch.

### 2.13 Export & sharing

- **CSV export** — a Save-panel report with one row per day (active, productive,
  neutral, distracting minutes, productivity %, keystrokes, clicks) plus per-app
  lifetime totals.

### 2.14 Packaging & platform

- **App icon** — a generated indigo→cyan squircle with the ticker-wave glyph,
  packed as a multi-resolution `.icns`.
- **Universal by build** — `build.sh` compiles natively for whatever Mac runs it
  (Apple Silicon or Intel).
- **One-command build** — compile, bundle, and ad-hoc sign via `./build.sh`.

### 2.15 Minute & screen timeline

- **Minute timeline** — a dense per-minute strip for the day (1,440 cells),
  each colored by the category of the app in focus that minute, with an
  idle color for inactive minutes (Day view).
- **Screen timeline** *(optional, off by default)* — with **Capture a
  screenshot every 5 minutes** enabled in Settings, Ticker saves a small
  thumbnail of your screen every 5 active minutes and shows them as time-stamped
  **cards** (time + focused app + category) in a grid.
- **On-device & disposable** — thumbnails live only in
  `~/Library/Application Support/Ticker/shots/`, are auto-deleted after 2 days,
  and can be wiped anytime via **Settings → Delete all screenshots**.
- **Permissioned** — uses **ScreenCaptureKit** and requires Screen Recording
  permission; capture happens only while you're active.

---

## 3. Prerequisites

- **macOS 14 (Sonoma) or later.**
- **The Swift toolchain.** You do *not* need the full Xcode app — Apple's
  Command Line Tools are enough. Install them with:

  ```bash
  xcode-select --install
  ```

  Verify:

  ```bash
  swift --version    # expect Swift 5.9+ (Ticker was built with 6.x)
  ```

No Apple Developer account, no paid signing certificate.

---

## 4. Get the code

Grab the project folder (a teammate will share it as a zip — see
[§10](#10-sharing-with-the-team)). Unzip it and `cd` in:

```bash
cd ~/Downloads/time-tracker      # wherever you unzipped it
```

You should see `Package.swift`, `build.sh`, `Info.plist`, and a `Sources/`
folder.

---

## 5. Build & run

```bash
./build.sh          # compiles, assembles Ticker.app, ad-hoc signs it
open build/Ticker.app
```

`build.sh` does three things:

1. `swift build -c release` — compiles the Swift Package.
2. Assembles a proper **`.app` bundle** (SwiftPM only emits a bare executable;
   a GUI app needs `Contents/MacOS/…`, `Info.plist`, and an icon).
3. **Ad-hoc signs** it (`codesign --sign -`) — required so macOS can attach an
   Accessibility permission to the app.

Use `./build.sh debug` for a faster (unoptimized) build while hacking.
Rebuild any time after editing the source — same two commands.

---

## 6. Grant Accessibility

App usage and active/idle time work immediately. To also count **keystrokes**
for the activity graph, grant Accessibility once:

1. Click **Grant Access** in the in-app banner (or **Settings → General**).
2. In **System Settings → Privacy & Security → Accessibility**, enable **Ticker**.
3. Quit and reopen Ticker.

> Because the app is ad-hoc signed (no paid Developer ID), macOS may ask you to
> re-grant Accessibility after each rebuild — the signature changes each time.
> Once you settle on a build, keep running that same `Ticker.app`.

---

## 7. How it works

The whole tracker is ~1,000 lines of Swift built from a handful of native APIs.
Here are the building blocks — enough to recreate it from scratch.

### 7.1 Which app is in front

```swift
let front = NSWorkspace.shared.frontmostApplication
let bundleId = front?.bundleIdentifier      // e.g. "com.apple.dt.Xcode"
let name = front?.localizedName             // e.g. "Xcode"
```

### 7.2 Counting keyboard & mouse (privacy-safe)

A **global event monitor** observes input across all apps. We only *count*
events — we never read key codes or content:

```swift
NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { _ in keyCount += 1 }
NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .scrollWheel]) { _ in mouseCount += 1 }
```

Keyboard monitoring requires **Accessibility** permission (§6).

### 7.3 Idle detection (works without permission)

```swift
let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                   eventType: CGEventType(rawValue: ~0)!)
let isActive = idle < idleThreshold        // e.g. 90s
```

### 7.4 The sampling loop

A `Timer` fires once per second: read the frontmost app, drain the key/mouse
counters, decide active vs idle, detect an app switch, and record it. See
`Sources/Ticker/Tracker.swift`.

### 7.5 Storing data

Aggregated into **one record per minute**, saved as JSON:

```swift
struct MinuteRecord: Codable {
    let minute: Date
    var appSeconds: [String: Int]   // bundleId -> active seconds
    var keyCount: Int
    var mouseCount: Int
    var activeSeconds: Int
    var switchCount: Int
}
```

Two things worth copying:

- **Tolerant decoding.** Each `Codable` type has a custom `init(from:)` using
  `decodeIfPresent(...) ?? default`. Swift's synthesized decoder throws on a
  missing key, so adding a field would otherwise invalidate every existing data
  file. The tolerant decoder makes upgrades safe.
- **Durable saves.** Flushed on a ~10s cadence *and* on every exit path — Cmd-Q,
  logout/restart/shutdown (`SIGTERM` + power-off), and sleep. Writes are atomic.
  See `installLifecycleHandlers()` in `Tracker.swift`.

### 7.6 The UI

SwiftUI, three scenes in `TickerApp.swift`:

```swift
WindowGroup(id: "dashboard") { DashboardView() }   // the dashboard
MenuBarExtra { MenuBarView() }                     // the menu-bar popover
Settings { SettingsView() }                        // Cmd-, preferences
```

Charts use **Swift Charts** (`import Charts`): area, stacked bar, donut
(`SectorMark`), and line marks.

### 7.7 Keeping the UI smooth (important)

Insight queries are O(records); running them on every body pass makes scrolling
stutter. In `DashboardView`:

- `recordsByMinute` is **not** `@Published`, so per-second logging doesn't
  invalidate the UI.
- All heavy queries run **once** into a `DashboardSnapshot`.
- The snapshot refreshes only on demand, on scope/date change, and — only while
  the window is active — once it's >5 minutes old. Nothing recomputes in the
  background.

---

## 8. Project layout

```
Package.swift                 SwiftPM manifest (executable target)
Info.plist                    bundle metadata (copied into the .app)
build.sh                      build + bundle + sign (stable identity if present)
Resources/Ticker.icns          app icon
tools/                        icon + signing-cert helper scripts
Sources/Ticker/
  App/         TickerApp.swift              @main — window · menu bar · settings
  Models/      Models.swift                value types · Codable · formatting
  Store/       TickerStore.swift            state + persistence
               TickerStore+Analytics.swift  derived reads (summaries, blocks…)
               CategoryGuesser.swift       default categorization
  Engine/      Tracker.swift               1s loop · lifecycle flushes
               ActivityMonitor.swift       global key/mouse counters + idle
  Services/    Permissions · ContextReader · ScreenshotService ·
               Notifier · LoginItem · CSVExporter · PDFReporter
  Views/
    Dashboard/ DashboardView · DashboardSections · DashboardWidgets
    MenuBar/   MenuBarView
    Settings/  SettingsView
    Shared/    Components (Card · StatTile · AppIconView · …)
```

See **ARCHITECTURE.md** for the layering and how to extend each layer. Each
feature in [§2](#2-complete-feature-reference) maps to these files — insights
and charts live under `Views/Dashboard/`, all aggregations in
`Store/TickerStore+Analytics.swift`, and each side-effect (export, login,
notifications, screenshots) gets its own file in `Services/`.

---

## 9. Make it your own

- **Change the defaults.** Edit `CategoryGuesser` in `TickerStore.swift` to tag
  your own apps out of the box.
- **Change idle/goal defaults** in `Models.swift` (`PersistedData`).
- **Recolor / rename.** Category colors are in `AppCategory` (`Models.swift`);
  the app name and bundle id are in `Info.plist`.
- **Redesign the icon.** Edit `tools/make_icon.swift`, run `./tools/make_icon.sh`.
- **Add an insight.** Add a query to `TickerStore`, a field to
  `DashboardSnapshot`, populate it in `rebuild()`, and render a card. Keep heavy
  work inside `rebuild()` — never in a view body — to preserve scroll perf.

Ideas: per-app daily limits, a distraction budget with alerts, an all-time
lifetime-stats view, a weekly PDF/image report.

---

## 10. Sharing with the team

Share the **source folder**, not a compiled binary — then everyone runs
`./build.sh` and gets a clean, trusted, native build.

Zip the source (excluding build artifacts) from the parent directory:

```bash
cd ..
zip -r time-tracker.zip time-tracker \
    -x "time-tracker/.build/*" "time-tracker/build/*"
```

Send `time-tracker.zip` (Slack, Drive, AirDrop). Each teammate:

1. Unzips it.
2. Runs `xcode-select --install` if they've never used the toolchain.
3. Runs `./build.sh && open build/Ticker.app`.
4. Grants Accessibility (§6).

**Why not just share the `.app`?** A downloaded, non-notarized app gets
quarantined and macOS blocks it ("damaged" / "unidentified developer"). Building
locally avoids all of that. If you *must* pass a binary, the receiver clears the
quarantine manually: `xattr -dr com.apple.quarantine /path/to/Ticker.app`.

---

## 11. Troubleshooting

| Symptom | Fix |
|---|---|
| `xcrun: error: ... requires Xcode` or `swift: command not found` | Run `xcode-select --install`. |
| Build fails on `import Charts` / SwiftUI | You're below macOS 14, or CLT is missing. Update macOS / reinstall CLT. |
| Keystrokes not counted (activity graph flat) | Grant Accessibility (§6), then quit & reopen. App/idle time work without it. |
| Accessibility toggle keeps resetting | Expected after each rebuild (ad-hoc signature changes). Settle on one build. |
| Settings won't open | Use **⌘,**, the **Ticker** app menu, or the menu-bar **Settings…** item. |
| "Launch at login" won't stick | `SMAppService` can refuse an ad-hoc app run from a build folder. Move `Ticker.app` to `/Applications`. |
| Notifications don't appear | Enable them in **Settings → General**; approve the macOS prompt. Ad-hoc apps may need re-approval after a rebuild. |
| Want a clean slate | **Settings → Data → Clear all tracked data**, or delete `~/Library/Application Support/Ticker/`. |
| Intel Mac | `build.sh` builds natively for whatever Mac runs it. No extra steps. |

---

Happy tracking. Build it, read the source, and bend it to your own workflow.
