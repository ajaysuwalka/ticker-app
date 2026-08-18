# Installing Ticker

Ticker is a native macOS app distributed as **source**. You build it once on your
own Mac (about 10 seconds) and run it. Because it's built locally, there's **no
Gatekeeper "unidentified developer" block** and no App Store needed.

---

## 1. Requirements

- **macOS 14 (Sonoma) or newer**.
- **Apple Command Line Tools** (provides `swift`). If you're not sure you have
  them, step 3 installs them.

No Apple Developer account or paid certificate is required.

---

## 2. Get the code

- If a teammate shared **`time-tracker.zip`**, unzip it and open Terminal in that
  folder.
- Or clone the repository, then `cd` into it.

```bash
cd ~/Downloads/time-tracker      # wherever the folder is
```

You should see `Package.swift`, `build.sh`, `tools/`, and `Sources/`.

---

## 3. Install the Swift toolchain (one time)

```bash
xcode-select --install
```

Accept the prompt if it appears. Verify:

```bash
swift --version        # expect Swift 5.9 or newer
```

---

## 4. Create a stable signing identity (one time, recommended)

This makes macOS **remember the permissions you grant, even after you rebuild**.
Skip it and you'll have to re-grant Accessibility/Screen Recording after every
rebuild.

```bash
./tools/make-signing-cert.sh
```

This creates a self-signed "Ticker Code Signing" certificate in your **login
keychain** (macOS may ask you to allow it — click Allow). `build.sh` picks it up
automatically.

---

## 5. Build and run

```bash
./build.sh && open build/Ticker.app
```

`build.sh` compiles the app, assembles `Ticker.app`, signs it, and `open` launches
it. Ticker appears in your **menu bar** (the ECG-wave icon) and opens its
dashboard window.

Rebuild any time with the same command.

---

## 6. Grant permissions (first launch)

App usage and active/idle time work right away. For the rest:

**Accessibility** — needed to count keystrokes/clicks and read the active
tab/project:
1. Click **Grant Access** in the in-app banner (or **Settings → General**).
2. In **System Settings → Privacy & Security → Accessibility**, enable **Ticker**.
3. **Quit and reopen Ticker.**

**Screen Recording** — only if you want the optional Screen Timeline
(screenshots):
1. **Settings → Wellness/Screen Timeline** → turn it on and approve the prompt.
2. Enable **Ticker** under **Privacy & Security → Screen & System Audio
   Recording**.
3. **Quit and reopen Ticker.**

> The quit-and-reopen step matters — macOS only applies a permission on the next
> launch.

---

## 7. Optional: keep it around

- **Move to Applications:** `cp -R build/Ticker.app /Applications/` then launch it
  from there (re-grant permissions once for the new copy if prompted).
- **Launch at login:** **Settings → General → Launch Ticker at login**.

---

## Sharing with your team

Share the **source folder**, not a compiled app — a downloaded, non-notarized
`.app` gets quarantined and blocked by macOS, while a locally built one is
trusted. Zip the source (without build artifacts):

```bash
cd ..
zip -r time-tracker.zip time-tracker -x "time-tracker/.build/*" "time-tracker/build/*"
```

Each teammate runs steps 2–6. Everyone creates their **own** signing cert in
step 4.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `swift: command not found` / `requires Xcode` | Run `xcode-select --install`. |
| Build fails on `import Charts` / SwiftUI | You're below macOS 14, or CLT is missing — update macOS / reinstall CLT. |
| `make-signing-cert.sh` says "MAC verification failed" | Old script — pull the latest; it exports a legacy PKCS#12 that macOS accepts. |
| `codesign … ambiguous` | You created the cert twice. Delete duplicates: run the de-dup steps in the repo, or remove extra "Ticker Code Signing" entries in Keychain Access, then rebuild. |
| Keystrokes not counted (activity flat) | Grant Accessibility, then **quit & reopen**. |
| Screen Recording re-prompts / doesn't stick | Make the signing cert (step 4), rebuild, grant once, reopen. Remove any stale "Ticker" entry in that privacy pane first. |
| Break reminder doesn't appear over other apps | Enable **Settings → Wellness → Show the reminder over all apps**. |
| Want a clean slate | **Settings → Data → Clear all tracked data**, or delete `~/Library/Application Support/Ticker/`. |
| Intel Mac | `build.sh` builds natively for whatever Mac runs it — no extra steps. |

Still stuck? See **[GUIDE.md](GUIDE.md)** for a deeper walkthrough of how Ticker
is built and works.
