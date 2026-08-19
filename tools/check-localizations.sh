#!/bin/bash
# Validates every Resources/<lang>.lproj/Localizable.strings against the English
# base: file parses, keys are a subset of en, and format specifiers match per key.
# Missing keys are allowed (they fall back to English) but reported as a count.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/Resources/en.lproj/Localizable.strings"
[ -f "$BASE" ] || { echo "❌ missing base: $BASE"; exit 1; }

status=0
for dir in "$ROOT"/Resources/*.lproj; do
  file="$dir/Localizable.strings"
  [ -f "$file" ] || continue
  lang="$(basename "$dir" .lproj)"

  # 1) Must parse as a valid strings/plist.
  if ! plutil -lint "$file" >/dev/null; then
    echo "❌ $lang: does not parse"; status=1; continue
  fi

  # 2) Key subset + 3) per-key format-specifier parity.
  BASE="$BASE" FILE="$file" LANG_NAME="$lang" python3 - <<'PY' || status=1
import os, re, plistlib, subprocess, sys

def load(path):
    # plutil converts a .strings file to a plist dict we can read reliably.
    raw = subprocess.check_output(["plutil", "-convert", "xml1", "-o", "-", path])
    return plistlib.loads(raw)

base = load(os.environ["BASE"])
tr = load(os.environ["FILE"])
lang = os.environ["LANG_NAME"]
if lang == "en":
    sys.exit(0)

spec = re.compile(r"%(?:\d+\$)?[@ldi]+|%lld|%dh")
def specs(s): return sorted(re.findall(r"%(?:lld|dh|[@ldi])", s))

orphans = [k for k in tr if k not in base]
mismatch = [k for k in tr if k in base and specs(base[k]) != specs(tr[k])]

if orphans:
    print(f"❌ {lang}: {len(orphans)} key(s) not in English base (typo?): {orphans[:5]}")
if mismatch:
    print(f"❌ {lang}: {len(mismatch)} key(s) with mismatched format specifiers: {mismatch[:5]}")
if orphans or mismatch:
    sys.exit(1)

missing = len([k for k in base if k not in tr])
print(f"✅ {lang}: {len(tr)}/{len(base)} translated"
      + (f" ({missing} fall back to English)" if missing else " (complete)"))
PY
done

exit $status
