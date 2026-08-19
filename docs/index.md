---
title: Home
layout: default
nav_order: 1
---

<style>
.tk-hero{
  text-align:center; padding:3rem 1rem 2.5rem; margin:-1rem -1rem 2rem;
  border-radius:0 0 18px 18px;
  background:radial-gradient(120% 140% at 30% 0%, #5E50EB 0%, #2b2a6b 45%, #14243f 100%);
  color:#fff;
}
.tk-hero img.tk-icon{ width:104px; height:104px; border-radius:24px; box-shadow:0 10px 30px rgba(0,0,0,.35); }
.tk-hero h1{ font-size:2.8rem; margin:.6rem 0 .2rem; color:#fff; border:0; }
.tk-hero p.tag{ font-size:1.15rem; opacity:.92; max-width:640px; margin:.2rem auto 1.3rem; }
.tk-dl{ display:inline-block; }
.tk-sub{ font-size:.85rem; opacity:.8; margin-top:.8rem; }
.tk-sub code{ background:rgba(255,255,255,.14); color:#fff; padding:2px 6px; border-radius:6px; }
.tk-features{ display:grid; grid-template-columns:repeat(auto-fit,minmax(220px,1fr)); gap:14px; margin:1.5rem 0; }
.tk-card{ border:1px solid rgba(128,128,128,.25); border-radius:12px; padding:16px 18px; background:rgba(128,128,128,.05); }
.tk-card .ico{ font-size:1.5rem; } .tk-card h3{ margin:.3rem 0 .3rem; font-size:1.05rem; }
.tk-card p{ margin:0; font-size:.92rem; opacity:.85; }
.tk-shots{ display:grid; grid-template-columns:repeat(auto-fit,minmax(280px,1fr)); gap:14px; margin:1.2rem 0; }
.tk-shots img{ width:100%; border-radius:10px; border:1px solid rgba(128,128,128,.25); }
</style>

<div class="tk-hero" markdown="0">
  <img class="tk-icon" src="screenshots/icon.png" alt="Ticker">
  <h1>Ticker</h1>
  <p class="tag">The private, native macOS time tracker — focus, insights, and healthy-work breaks, <strong>100% on your Mac</strong>.</p>
  <a class="tk-dl" href="https://github.com/ajaysuwalka/ticker-app/releases/latest/download/Ticker-macOS.dmg">
    <img alt="Download Ticker for macOS" height="56"
         src="https://img.shields.io/badge/%20Download%20for%20macOS-Universal%20DMG-2ea44f?style=for-the-badge&logo=apple&logoColor=white">
  </a>
  <div class="tk-sub">Apple Silicon + Intel · signed &amp; notarized · macOS 14+ &nbsp;·&nbsp; or <code>brew install --cask ticker</code></div>
</div>

A free, open-source, on-device **alternative to RescueTime, Timing, Rize, and ActivityWatch**.

<div class="tk-features" markdown="0">
  <div class="tk-card"><div class="ico">🔒</div><h3>Private by design</h3><p>Everything stays on your Mac. No servers, no account, no telemetry.</p></div>
  <div class="tk-card"><div class="ico">🖥️</div><h3>Truly native</h3><p>SwiftUI + Swift Charts — a menu-bar companion and a full dashboard.</p></div>
  <div class="tk-card"><div class="ico">🎯</div><h3>Real focus</h3><p>Continuous-focus streaks, not scattered productive seconds.</p></div>
  <div class="tk-card"><div class="ico">🧘</div><h3>Built-in wellness</h3><p>Move &amp; screen breaks with on-screen countdowns.</p></div>
  <div class="tk-card"><div class="ico">🧠</div><h3>Idle vs. away</h3><p>Knows a Zoom call (reviewable) from a closed lid (not counted).</p></div>
  <div class="tk-card"><div class="ico">📄</div><h3>Own your data</h3><p>PDF &amp; CSV export; wipe anytime. It's all local JSON.</p></div>
</div>

## Screenshots

<div class="tk-shots" markdown="0">
  <img src="screenshots/overview.png" alt="Overview">
  <img src="screenshots/insights.png" alt="Insights">
  <img src="screenshots/apps.png" alt="Apps">
  <img src="screenshots/timeline.png" alt="Timeline">
</div>

## Learn more

- [Widget & Metric Reference](WIDGETS.md) — exactly how every number is computed.
- [Distribution & Releases](DISTRIBUTION.md) — how notarized DMGs are built and shipped.
- [Brand Guide](BRANDING.md).
- [Translating Ticker](TRANSLATING.md) — available in English, Spanish, French & German; add your language.

---

<small>Built by Ajay Suwalka · created with tools provided by
[Testlio](https://testlio.com) · MIT-licensed · not an official Testlio product.</small>
