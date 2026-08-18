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

### CI notarization (optional)

To notarize in GitHub Actions, add these repo secrets and extend `release.yml`:

| Secret | What |
|---|---|
| `DEVELOPER_ID_CERT_P12` | base64 of your Developer ID cert `.p12` |
| `DEVELOPER_ID_CERT_PASSWORD` | password for the `.p12` |
| `NOTARY_APPLE_ID` / `NOTARY_TEAM_ID` / `NOTARY_PASSWORD` | notarization creds |

The job imports the cert into a temporary keychain, runs `tools/dist.sh`, and
uploads the DMG. (Left as an opt-in because it needs your Apple secrets.)

## Homebrew cask (later)

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
