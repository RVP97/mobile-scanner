#!/bin/sh
# Generates THROWAWAY certificates for tests only (never deploy these):
#   test-wwdr.pem            self-signed stand-in for Apple WWDR G4
#   test-pass-cert.pem       "Pass Type ID" leaf issued by it (UID=pass.com.rvp97.scanner, OU=TESTTEAM01)
#   test-pass-key.pem        its private key, PKCS#8
#   test-pass-key-pkcs1.pem  same key, PKCS#1 ("BEGIN RSA PRIVATE KEY")
# Usage: sh scripts/gen-test-certs.sh <outdir>
set -eu
OUT="${1:-test/.fixtures}"
mkdir -p "$OUT"
cd "$OUT"

openssl req -x509 -newkey rsa:2048 -nodes -days 30 -sha256 \
  -keyout test-wwdr-key.pem -out test-wwdr.pem \
  -subj "/CN=Test WWDR CA/OU=G4/O=Lens Tests/C=US" \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null

openssl req -newkey rsa:2048 -nodes -keyout test-pass-key.pem -out pass.csr \
  -subj "/UID=pass.com.rvp97.scanner/CN=Pass Type ID: pass.com.rvp97.scanner/OU=TESTTEAM01/O=Lens Tests/C=US" 2>/dev/null

printf "basicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature\n" > leaf.ext
openssl x509 -req -in pass.csr -CA test-wwdr.pem -CAkey test-wwdr-key.pem -CAcreateserial \
  -days 30 -sha256 -extfile leaf.ext -out test-pass-cert.pem 2>/dev/null

openssl pkey -in test-pass-key.pem -out key8.pem 2>/dev/null && mv key8.pem test-pass-key.pem   # normalise to PKCS#8
openssl rsa -in test-pass-key.pem -traditional -out test-pass-key-pkcs1.pem 2>/dev/null
rm -f pass.csr leaf.ext test-wwdr.srl
echo "test certificates written to $OUT"
