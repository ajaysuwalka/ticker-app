---
title: Widget Reference
nav_order: 2
---

# Ticker — Widget & Metric Reference

This document explains **every widget in Ticker and exactly how it decides what
it shows**. If a number ever surprises you, this is the place to understand why.

Jump to:

- [Foundations — how Ticker decides things](#foundations--how-ticker-decides-things)
  - [Active vs. Idle](#active-vs-idle)
  - [Present vs. Away](#present-vs-away)
  - [App categories](#app-categories)
  - [Focus, sessions & streaks](#focus-sessions--streaks)
- [Overview tab](#overview-tab)
- [Insights tab](#insights-tab)
- [Apps tab](#apps-tab)
- [Timeline tab](#timeline-tab)
- [Menu bar & always-visible bits](#menu-bar--always-visible-bits)
- [Interruptions — breaks & idle review](#interruptions--breaks--idle-review)

---

## Foundations — how Ticker decides things

Ticker samples the **frontmost app every second** and folds in how many
keys/clicks happened since the last sample. It stores **one record per
wall-clock minute** on your Mac. Everything below is computed from those records.

### Active vs. Idle

A second is counted as **active** if *any* of these is true:

- a key was pressed, or
- the mouse was clicked/moved, or
- there was input within the **idle threshold** (default **90 seconds**).

The idle threshold means a short pause to read or think still counts as active.
Once you've had no input for longer than the threshold, seconds stop counting as
active — that time is **idle**. Idle time is recorded but does **not** count
toward Active Time or productivity.

> Configure the threshold in **Settings → General**.

### Present vs. Away

Ticker distinguishes *"here but not typing"* from *"gone"*:

| State | Detected by | Recorded? | Counts as idle? |
|---|---|---|---|
| **Idle** (screen on, no input) | no keyboard/mouse, display awake | ✅ yes | ✅ yes (reviewable) |
| **Away** (locked / display asleep / lid closed / system asleep) | screen-lock + sleep/wake signals | ❌ no | ❌ no |

So a Zoom/Meet call where you're watching but not typing is **idle time you can
review**, while stepping away and locking your Mac is simply **not tracked**.

### App categories

Every app falls in one of four categories:

- **Productive** — counts toward productive time and focus.
- **Neutral** — tracked, but neither productive nor distracting.
- **Distracting** — tracked, flagged as distracting.
- **Excluded** — **not tracked at all** (activity, keys, clicks, window titles,
  and screenshots are dropped).

Ticker **auto-guesses** a category from the app's bundle id / name the first time
it sees it. You can **override** any app by dragging it between columns in the
**Apps** tab; your choice sticks.

### Focus, sessions & streaks

- A **focus session** is a run of consecutive productive minutes. A minute
  counts toward focus when productive apps dominated it (≈30s+ of the minute).
- Small gaps are tolerated: a break of **up to 10 minutes** stays inside the same
  session; a gap **longer than 10 minutes** ends it.
- **Focused time toward your goal is the *longest single session*, not the sum**
  of scattered productive blocks. Three separate 90-minute stretches don't add up
  to a met 4-hour goal — you need one continuous 4-hour streak (with only short
  gaps). Over a week/month, Ticker sums each day's *longest* session so it stays
  comparable to (daily goal × days).

---

## Overview tab

### Stat tiles

| Tile | Shows | How it's decided |
|---|---|---|
| **Active Time** | Total engaged time in the period | Sum of active seconds (see [Active vs. Idle](#active-vs-idle)). |
| **Productive** | Active time in **Productive** apps | Active seconds attributed to productive-category apps. |
| **Productivity** | % of active time that was productive | `Productive ÷ Active Time`. |
| **Interactions** | Total keys + clicks | Sum of key and click **counts** — never *which* keys or *what* you typed. |

### Focus Goal (ring)

- **Shows:** progress toward your daily focus goal (default **4h**), with
  Focused / Goal / Remaining.
- **Decides:** the ring fills to `longest continuous focus session ÷ goal`. It
  completes only when a single streak reaches the goal (see
  [Focus, sessions & streaks](#focus-sessions--streaks)). Set the goal in
  **Settings → General**.

### Activity Over the Day

- **Shows:** a graph of engagement across the day.
- **Decides:** interactions (keys+clicks) bucketed by time of day, so tall bars =
  busy moments. Requires **Accessibility** permission to count keystrokes.

### Productivity Trend · Last 14 Days

- **Shows:** your daily productivity % over the trailing two weeks (the period
  for Week/Month scopes).
- **Decides:** each point is that day's `Productive ÷ Active` %. The "avg" label
  averages only days that had activity.

---

## Insights tab

### Stat tiles

| Tile | Shows | How it's decided |
|---|---|---|
| **Focus Streak** | Consecutive days you met the goal | Counts back from today (or yesterday if today isn't met yet); a day counts only if its *longest* focus session ≥ goal. |
| **Deep Work** | Number of 25 min+ focus blocks | Focus sessions lasting at least 25 minutes. |
| **Longest Focus** | Your deepest single session | The single longest focus session in the period. |
| **Context Switches** | How often you jumped apps | Sum of frontmost-app changes recorded per minute. |

### Peak Hours

- **Shows:** "Most active around \<hour\>" plus an hourly breakdown.
- **Decides:** groups active time and interactions by hour-of-day (0–23); the
  peak is the hour with the most active time.

### Weekly Recap

- **Shows:** a friendly summary (e.g. average productivity, totals).
- **Decides:** aggregates the period's daily stats — averages are over days with
  activity.

---

## Apps tab

### Where your time went

- **Shows:** four columns — **Productive · Neutral · Distracting · Excluded** —
  each listing apps with the time spent in them.
- **Decides:** per-app active seconds, grouped by category.
  **Drag an app between columns to recategorize it** (drop in Excluded to stop
  tracking it entirely). Your overrides persist.

### Top Apps

- **Shows:** your most-used apps by time.
- **Decides:** ranked by active seconds across tracked (non-excluded) apps.

### Focus Split

- **Shows:** a pie of how tracked time divides across categories.
- **Decides:** share of active time in Productive vs. Neutral vs. Distracting.

---

## Timeline tab

### Minute Timeline

- **Shows:** a minute-by-minute strip of the day.
- **Decides:** each cell is one minute, colored by the **dominant app's
  category**; idle minutes are shown muted; away minutes are absent (not tracked).

### Activity Blocks

- **Shows:** 10-minute blocks summarizing what you did, with keys/clicks and —
  if enabled — a screen thumbnail.
- **Decides:** records grouped into 10-minute windows. Screenshots appear only if
  you turn on **Screen Timeline** in Settings; they're captured every N active
  minutes, stored **only on your Mac**, and auto-deleted on your retention
  schedule. The most recent 120 blocks are shown.

---

## Menu bar & always-visible bits

### Menu-bar icon

- **Shows:** the pulse-wave glyph with a status dot.
- **Decides:** 🟢 green = tracking & active · 🟠 orange = tracking but idle ·
  ⚪ hollow = paused.

### Menu-bar panel

- **Shows:** a live activity waveform, the Focus ring with today's numbers, the
  current app/context, the next-break countdown, and a Start/Pause toggle.

### Sidebar "Next Breaks" (dashboard)

- **Shows:** both wellness timers (Move + Eyes) with live countdowns, the sooner
  one highlighted — always visible on every tab.
- **Decides:** counts down only **active** time toward each configured interval;
  stepping away pauses/resets it. Configure intervals **and** durations in
  **Settings → Wellness**.

---

## Interruptions — breaks & idle review

### Break reminder overlay

- **When:** an interval elapses (defaults: **Move** every 30 min, **Screen/Eyes**
  every 60 min — both configurable) **and** the minimum gap since the last break
  has passed.
- **Minimum gap:** no break fires within a configurable **minimum interval**
  (default **30 min**) of the previous one, so breaks never bunch up — e.g. a
  long break lands at least 30 min after the last short break. This gate applies
  to every break, including the first; if a break's own interval is shorter than
  the minimum gap, the gap wins.
- **Behavior:** a card appears with an **on-screen countdown** for the break
  length (defaults: Move 2 min, Screen 5 min — configurable) that **auto-finishes
  the break at zero** — there's no "I took a break" button. Stepping away also
  completes it. If both breaks come due together, only the one with **more time
  available** (the longer interval) shows; completing a screen break also resets
  the move timer.

### Idle review prompt

- **When:** you return after **more than 10 minutes** of *screen-on* inactivity
  (not while locked/asleep — that's [Away](#present-vs-away)).
- **Behavior:** asks *"Was this a meeting?"* — **Yes** counts that stretch as
  **productive** ("Meeting"); **No** offers to **delete** the idle time or keep it.

### Paused reminder

- **When:** tracking has been paused for a while.
- **Behavior:** a gentle floating reminder to resume, snoozeable for 30/60/120
  min.

---

*Changed how a widget computes something? Please update this file in the same PR.*