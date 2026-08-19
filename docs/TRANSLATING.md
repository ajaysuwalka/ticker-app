---
title: Translating Ticker
nav_order: 5
---

# Translating Ticker 🌍

Ticker ships in **English, Spanish, French, and German**, and adding a new
language is a self-contained pull request — no Swift required.

## How localization works

Ticker uses standard Apple `.lproj/Localizable.strings` bundles, loaded from the
app bundle at runtime (`Bundle.main`). The **English source string is the key**,
so any string that isn't translated automatically falls back to clean English —
partial translations are perfectly fine and never break the UI.

```
Resources/
  en.lproj/Localizable.strings   ← authoritative key list (English)
  es.lproj/Localizable.strings   ← Spanish
  fr.lproj/Localizable.strings   ← French
  de.lproj/Localizable.strings   ← German
```

Each entry looks like:

```
"Weekly Hours" = "Weekly Hours";     /* en — key = value */
"Weekly Hours" = "Semanales";        /* de — translate only the right side */
```

## Add a new language

1. **Copy the English file** to a new locale folder, e.g. for Italian:
   ```bash
   mkdir -p Resources/it.lproj
   cp Resources/en.lproj/Localizable.strings Resources/it.lproj/Localizable.strings
   ```
2. **Translate the right-hand side only.** Leave every key (the text before ` = `)
   byte-for-byte identical.
3. **Register the locale** in `Info.plist` → `CFBundleLocalizations` (add
   `<string>it</string>`).
4. Build and run — macOS shows the language matching your system's preferred
   language order.

## Rules that keep the build green

- **Never change a key.** Only the value (right of ` = `) is translated.
- **Keep every format specifier**, in a natural order for your language:
  `%@` (text), `%d` / `%lld` (numbers), `%dh` (a number followed by "h").
  Don't add, drop, or renumber them.
- **Preserve literal glyphs** where they appear: `·`, `—`, `→`, `\n`, the curly
  quotes `“ ”`, the emoji (🎯 🎉), and the en-dash in ranges like `1–2`.
- **Don't translate the brand name** "Ticker".
- One entry per line, ending in `;`. Escape inner quotes as `\"`.

## Test your translation

```bash
./build.sh && open build/Ticker.app
```

To force a language regardless of your system settings, run:

```bash
defaults write com.ajaysuwalka.ticker AppleLanguages '("it")'
open build/Ticker.app
# undo with: defaults delete com.ajaysuwalka.ticker AppleLanguages
```

Open a PR with your `<locale>.lproj/Localizable.strings` and the `Info.plist`
change — that's the whole contribution. Thank you! 🙏
