# Ticker — Brand Guide

A tiny, opinionated brand system so every screenshot, badge, and page reads as
one product.

## Name & tagline

- **Name:** Ticker
- **Tagline:** *Your workday, measured privately.*
- **One-liner:** The private, native macOS time tracker — focus, insights, and
  healthy-work breaks, 100% on your Mac.

Say "Ticker" alone (no "app"/"the"). Keep the privacy + native + focus/wellness
angle front and center everywhere.

## Logo / icon

Keep the **heartbeat / ECG pulse-wave** mark — it's already the app's identity
and reads at any size. Guidelines:

- Single-glyph waveform on a **dark squircle** with the brand gradient.
- Must be legible at **16px** (menu bar) and crisp at **1024px** (icon).
- Provide `logo.png` (wordmark + glyph) and `icon.png` (glyph only) in
  `docs/screenshots/`.
- Regenerate the app icon via `tools/make_icon.sh` if you change the mark.

## Color

The brand gradient (already used in-app):

| Token | Hex | Use |
|---|---|---|
| Brand indigo | `#5E50EB` | gradient start, primary accent |
| Brand cyan | `#1AB5D1` | gradient end |
| Productive | `#33C772` | category + focus green |
| Neutral | `#617DF2` | category blue |
| Distracting | `#FA8C33` | category orange / warnings |
| Ink (dark bg) | `#1F2229` | cards on dark |

Prefer the indigo→cyan gradient (top-leading → bottom-trailing) for hero
elements; use category colors only for their meaning.

## Typography

- UI: **SF Pro Rounded** for titles (matches the in-app `.rounded` design),
  SF Pro Text for body.
- Docs/site: system UI stack.

## Social preview (GitHub OG image — 1280×640)

Dark background, the wordmark, one clean dashboard screenshot, and three chips:
**Local-only · Native SwiftUI · Focus + Wellness**. Set it under
**repo → Settings → Social preview** so shared links look sharp.

## Screenshots

Put clean captures in `docs/screenshots/` (dashboard, overview, apps, timeline,
menu bar, a break overlay). Use a neutral wallpaper and hide unrelated windows.
An animated GIF of the dashboard + menu bar on the README makes the biggest
first impression.
