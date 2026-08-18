# Publishing Ticker to the Mac App Store (when needed)

> **Read this first.** The App Store requires the **App Sandbox**, which blocks
> the Accessibility APIs Ticker uses. A Store build therefore **loses keystroke/
> click counts (the Activity graph) and window-title context**. Only ship to the
> Store if that reduced version is acceptable. The default, full-featured
> distribution is Developer ID + notarization — see [DISTRIBUTION.md](DISTRIBUTION.md).

This is the App Store track, kept separate from the Developer ID release pipeline.

## What has to be true before a Store submission

1. **Sandbox entitlements** — use [`Ticker.appstore.entitlements`](../Ticker.appstore.entitlements)
   (`com.apple.security.app-sandbox = true`). Scaffolded already.
2. **Feature-gate the sandboxed build** — compile out / hide the features the
   sandbox disables so the app doesn't look broken:
   - the Activity graph + Interactions tile (global key/click monitor),
   - the window-title "context" (AXUIElement) shown in Timeline blocks.
   Keep: per-app usage, productivity by category, focus goal, wellness breaks,
   and the (consent-gated) screen timeline.
3. **An archivable target** — the Store won't accept SwiftPM's hand-assembled
   `.app`. You need an **Xcode project/target** (or `xcodebuild archive`) that
   produces an App Store-signed archive with the sandbox entitlements + an
   embedded provisioning profile.

## One-time Apple setup (Account Holder / Admin, via web or Xcode)

1. **App ID** — developer.apple.com → Identifiers → **+** → App ID for
   `com.ajaysuwalka.ticker` (macOS).
2. **Apple Distribution certificate** — Certificates → **+** → *Apple
   Distribution* (this is **not** the Developer ID cert we already made).
3. **Provisioning profile** — Profiles → **+** → *Mac App Store* → the App ID
   above + the Apple Distribution cert.
4. **App Store Connect app record** — appstoreconnect.apple.com → Apps → **+** →
   new macOS app, bundle id `com.ajaysuwalka.ticker`, set name, category
   (Productivity), price (Free), privacy details (all data on-device), and
   screenshots.

## Publish flow (each release)

1. Bump `CFBundleShortVersionString` / `CFBundleVersion` in `Info.plist`.
2. **Archive** the App Store target:
   ```bash
   xcodebuild -scheme Ticker -configuration Release archive \
     -archivePath build/Ticker.xcarchive \
     CODE_SIGN_ENTITLEMENTS=Ticker.appstore.entitlements
   ```
3. **Export + upload** with the App Store Connect API key we already configured
   (Key ID `77K585C3K6`):
   ```bash
   xcodebuild -exportArchive -archivePath build/Ticker.xcarchive \
     -exportOptionsPlist ExportOptions-appstore.plist -exportPath build/appstore
   xcrun altool --upload-app -f build/appstore/Ticker.pkg -t macos \
     --apiKey 77K585C3K6 --apiIssuer 69a6de85-74c4-47e3-e053-5b8c7c11a4d1
   ```
   (Or drag the `.pkg` into the **Transporter** app.)
4. In **App Store Connect**, attach the uploaded build to the version, finish
   metadata, and **Submit for Review**. Release manually or automatically after
   approval.

## CI automation (optional, later)

The upload step can run in GitHub Actions using the same App Store Connect API
key (already a secret) plus the Apple Distribution cert + provisioning profile as
new secrets. The **app record, metadata, and review** stay manual.

## Status / TODO before the first Store submit

- [ ] Add an Xcode project/target (or `xcodebuild`-archivable wrapper)
- [ ] Feature-gate the sandbox build (hide keystroke graph + window-title context)
- [ ] Create App ID + Apple Distribution cert + Mac App Store provisioning profile
- [ ] Create the App Store Connect app record + metadata + screenshots

Ask and I'll build the Xcode archive target + feature-gating; the Apple-portal
and App Store Connect steps need your Account-Holder login.
