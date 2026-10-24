#!/bin/bash
# setup-signing.sh - one-time: create a local self-signed code-signing identity
# ("Couch Local Signing") in the login keychain.
#
# Why: ad-hoc signatures change on every build, so macOS drops the Accessibility
# grant after each rebuild (ADR-007). Signing with a stable identity keeps it.
# The private key never leaves the login keychain. macOS will ask for your
# password once, to trust the certificate for code signing.
set -euo pipefail

NAME="Couch Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
SSL=/usr/bin/openssl   # system LibreSSL: its .p12 format imports cleanly

if security find-identity -p codesigning | grep -q "$NAME"; then
  echo "Identity '$NAME' already exists. Nothing to do."
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF

"$SSL" req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf"
"$SSL" pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/id.p12" -passout pass:couch

security import "$TMP/id.p12" -k "$KEYCHAIN" -P couch -T /usr/bin/codesign
echo "==> Trusting certificate for code signing (password prompt)..."
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"

security find-identity -p codesigning | grep "$NAME"
echo "==> Done. build-app.sh will now sign with '$NAME'."
