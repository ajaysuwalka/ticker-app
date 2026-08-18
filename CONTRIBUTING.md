# Contributing to Ticker

Thanks for your interest in improving Ticker! This is a native macOS app built
with SwiftUI + Swift Charts, distributed as source. Contributions of all sizes
are welcome — bug fixes, features, docs, and design.

## Ground rules

- **Privacy is the product.** Ticker keeps everything on-device. Any change that
  adds network calls, analytics, telemetry, or "phone-home" behavior will not be
  merged. This is non-negotiable and is the core promise of the project.
- Be kind and constructive — see the [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting set up

```bash
git clone https://github.com/ajaysuwalka/ticker-app.git
cd ticker-app
./tools/make-signing-cert.sh      # one-time: stable permissions across rebuilds
./build.sh && open build/Ticker.app
```

Requirements: **macOS 14+** and Apple's Command Line Tools (`xcode-select --install`).

## Before you open a PR

Run the same checks CI runs:

```bash
swift build -c release     # must compile cleanly
swift test                 # add/adjust tests for logic you touch (needs full Xcode)
swiftlint                  # brew install swiftlint (if you don't have it)
./build.sh                 # the .app bundles and signs
```

> **Note:** building/running the app works with just the Command Line Tools, but
> `swift test` needs a full **Xcode** install (XCTest ships with Xcode). CI runs
> the tests on every PR regardless.

- **Write tests** for anything with logic (analytics, streaks, idle/away
  detection, break scheduling). The pure logic lives in `Store/`, `Engine/`, and
  `Models/` and is straightforward to unit-test — see `Tests/TickerTests`.
- Keep functions small and focused; match the surrounding style.
- Update `docs/WIDGETS.md` if you change how a widget computes or decides things.

## Project layout

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full map. In short:

| Folder | What lives there |
|---|---|
| `Sources/Ticker/Engine` | Sampling loop, activity monitor, break + presence logic |
| `Sources/Ticker/Store` | Persistence + analytics (streaks, sessions, aggregates) |
| `Sources/Ticker/Models` | Data types, wellness definitions, formatting |
| `Sources/Ticker/Views` | Dashboard, menu bar, settings, overlays |
| `Sources/Ticker/Services` | Screenshots, export (PDF/CSV), notifications, permissions |

## Commit & PR style

- One logical change per PR; describe the *why*, not just the *what*.
- Reference any issue it closes (`Closes #123`).
- Screenshots/GIFs for any UI change are hugely appreciated.

## Good first issues

Look for the [`good first issue`](https://github.com/ajaysuwalka/ticker-app/labels/good%20first%20issue)
label. Docs, new app-category heuristics, and small UI polish are great entry points.
