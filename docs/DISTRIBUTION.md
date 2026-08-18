---
title: Distribution & Releases
nav_order: 3
---

# Distributing Ticker

Ticker is distributed **outside the Mac App Store**, signed with a **Developer
ID** and **notarized** by Apple. Users get a normal double-click install with no
"unidentified developer" wall, and Ticker keeps all its features.

## Why not the Mac App Store?

Every App Store app must run in the **App Sandbox**, which forbids the APIs
Ticker depends on:

| Feature | API | Sandbox |
|---|---|---|
| Window title / tab / project context | Accessibility (`AXUIElement…`) | ❌ Not allowed |
| Keystroke / click counts | Global event monitor + Accessibility | ❌ Not obtainable |
| Frontmost app | `NSWorkspace.frontmostApplication` | ✅ |
| Idle detection | `CGEventSource` | ✅ |
| Screen thumbnails | ScreenCaptureKit | ✅ |

Losing the activity graph and window-title context would gut the product — which
is why every comparable tool (RescueTime, Timing, Rize, ActivityWatch) ships this
same way.

## One-time setup

1. **Join the [Apple Developer Program](https://developer.apple.com/programs/)** ($99/yr).
2. In Xcode (or the Developer portal), create a **Developer ID Application**
   certificate and install it in your login keychain. Confirm it's there:
   ```bash
   security find-identity -v -p codesigning
   # → "Developer ID Application: Ajay Suwalka (TEAMID)"
   ```
3. Store notarization credentials once (uses an app-specific password from
   appleid.apple.com, or an App Store Connect API key):
   ```bash
   xcrun notarytool store-credentials TickerNotary \
     --apple-id "you@example.com" --team-id "TEAMID" --password "xxxx-xxxx-xxxx-xxxx"
   ```

## Build a notarized DMG

```bash
DEVELOPER_ID="Developer ID Application: Ajay Suwalka (TEAMID)" ./tools/dist.sh 1.0
```

`tools/dist.sh` builds a release, signs with hardened runtime, notarizes and
staples the app **and** the DMG, then verifies with `spctl`. The result is
`build/Ticker-<version>.dmg`, ready to attach to a GitHub Release.

> No entitlements are required: Ticker's Accessibility, event-monitoring, and
> ScreenCaptureKit usage are gated by macOS privacy (TCC) at runtime, not by
> sandbox/entitlements.

## Release it

- Attach the DMG to a GitHub Release (tag `vX.Y.Z` — see
  [`.github/workflows/release.yml`](../.github/workflows/release.yml)).
- Bump `CFBundleShortVersionString` / `CFBundleVersion` in `Info.plist` per release.

### CI notarization (automated releases)

`release.yml` already does the full signed + notarized DMG pipeline on every
`v*` tag — it just needs these repo secrets (**Settings → Secrets and variables →
Actions → New repository secret**). Until they're set, releases fall back to an
unsigned zip, so forks still work.

| Secret | What / how to get it |
|---|---|
| `DEVELOPER_ID` | Your identity string, e.g. `Developer ID Application: Ajay Suwalka (TEAMID)` (`security find-identity -v -p codesigning`). |
| `MACOS_CERT_P12` | base64 of your exported Developer ID cert: `base64 -i DeveloperID.p12 \| pbcopy`. |
| `MACOS_CERT_PASSWORD` | The password you set when exporting the `.p12`. |
| `KEYCHAIN_PASSWORD` | Any throwaway string (CI uses it for a temporary keychain). |
| `AC_API_KEY_ID` | App Store Connect API **Key ID** (Users and Access → Integrations → App Store Connect API). |
| `AC_API_ISSUER_ID` | The **Issuer ID** shown on that same page. |
| `AC_API_KEY_P8` | base64 of the downloaded `AuthKey_XXXX.p8`: `base64 -i AuthKey_XXXX.p8 \| pbcopy`. |

**Export the cert as `.p12`:** open **Keychain Access**, find *Developer ID
Application: …*, right-click → **Export**, choose *Personal Information Exchange
(.p12)*, set a password (→ `MACOS_CERT_PASSWORD`).

Then tag a release and it's built, signed, notarized, stapled, and published:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

## Auto-bumping the Homebrew cask

`release.yml` updates `Casks/ticker.rb` (`version` + `sha256`) and pushes it to
`main` on every release. Because `main` is a protected branch, the built-in
`GITHUB_TOKEN` can't push to it, so this step needs one extra secret:

| Secret | What |
|---|---|
| `CASK_PUSH_TOKEN` | A **fine-grained PAT** (github.com → Settings → Developer settings → Fine-grained tokens) scoped to `ajaysuwalka/ticker-app` with **Contents: Read and write**. As a repo admin, its pushes bypass branch protection. |

Without it, the cask step is skipped and you bump `Casks/ticker.rb` by hand.

## Homebrew cask (details)

Once releases are published, a cask lets users `brew install --cask ticker`:

```ruby
cask "ticker" do
  version "1.0"
  sha256 "…"                       # shasum -a 256 of the DMG
  url "https://github.com/ajaysuwalka/ticker-app/releases/download/v#{version}/Ticker-#{version}.dmg"
  name "Ticker"
  desc "Private, native macOS time tracker"
  homepage "https://github.com/ajaysuwalka/ticker-app"
  app "Ticker.app"
end
```