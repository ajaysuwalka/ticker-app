#!/bin/bash
# Creates a self-signed "Ticker Code Signing" certificate in your login keychain.
# Signing Ticker with a STABLE identity (instead of ad-hoc) means macOS keeps its
# Accessibility and Screen Recording permission across rebuilds — and stops
# re-prompting on every screenshot. Run this ONCE, then run ./build.sh again.
set -euo pipefail

NAME="Ticker Code Signing"

# No -v here: a self-signed cert reads as "untrusted" and -v would hide it, so the
# guard would miss it and create duplicates (which makes codesign ambiguous).
if security find-identity -p codesigning 2>/dev/null | grep -q "${NAME}"; then
    echo "'${NAME}' already exists — nothing to do. Just run ./build.sh."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

cat > "${TMP}/cs.cnf" <<'CNF'
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = Ticker Code Signing
[v3]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

echo ">> Generating self-signed code-signing certificate..."
openssl req -x509 -newkey rsa:2048 -keyout "${TMP}/key.pem" -out "${TMP}/cert.pem" \
    -days 3650 -nodes -config "${TMP}/cs.cnf" >/dev/null 2>&1
# macOS's importer only reads legacy PKCS#12 (SHA-1 MAC / 3DES). OpenSSL 3 defaults
# to a newer MAC that fails with "MAC verification failed", so try -legacy first
# and fall back to the default (LibreSSL, which is already legacy-compatible).
PW="ticker"
openssl pkcs12 -export -inkey "${TMP}/key.pem" -in "${TMP}/cert.pem" \
    -name "${NAME}" -out "${TMP}/cs.p12" -passout "pass:${PW}" -legacy >/dev/null 2>&1 \
  || openssl pkcs12 -export -inkey "${TMP}/key.pem" -in "${TMP}/cert.pem" \
    -name "${NAME}" -out "${TMP}/cs.p12" -passout "pass:${PW}" >/dev/null 2>&1

echo ">> Importing into your login keychain..."
security import "${TMP}/cs.p12" \
    -k "${HOME}/Library/Keychains/login.keychain-db" \
    -P "${PW}" -T /usr/bin/codesign -A

echo "OK - created '${NAME}'."
echo "   Now run ./build.sh again; it will sign Ticker with this stable identity."
echo "   Grant Accessibility / Screen Recording once more, and it will stick from now on."
