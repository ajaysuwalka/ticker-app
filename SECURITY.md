# Security Policy

Ticker runs entirely on your Mac and never transmits your data anywhere, so its
attack surface is small — but we take any issue seriously.

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Instead, use
GitHub's **[private vulnerability reporting](https://github.com/ajaysuwalka/ticker-app/security/advisories/new)**
(Security tab → *Report a vulnerability*), or email the maintainer directly.

Include:

- what the issue is and its impact,
- steps to reproduce,
- the version / commit and your macOS version.

You'll get an acknowledgment within a few days. Once fixed, we'll credit you in
the release notes unless you prefer to remain anonymous.

## Scope notes

- Ticker stores data locally in `~/Library/Application Support/Ticker/`
  (`data.json` + a `shots/` folder). It counts *how many* keys/clicks you make —
  never *which* keys or *what* you type. Screenshots are off by default.
- Reports about data leaving the device, unexpected file access, or permission
  misuse are especially welcome.

## Supported versions

The latest released version receives fixes.
