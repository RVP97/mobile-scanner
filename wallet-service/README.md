# Lens wallet-service

A small, stateless Cloudflare Worker that signs Apple Wallet passes (`.pkpass`) for the Lens iOS app
(`com.rvp97.scanner`). Pass-signing keys can't ship inside an app, so the app asks this Worker to sign, and
proves each request comes from a genuine, unmodified copy of Lens with **App Attest**.

```
GET  /lens/v1/challenge   → {"challenge": "<base64url 32 bytes>", "expiresAt": <unix>}   single use, 5 min
POST /lens/v1/attest      {"keyId","attestation","challenge"}                         → 201 (once per install)
POST /lens/v1/pass        X-Lens-Key-Id, X-Lens-Assertion + JSON body                → application/vnd.apple.pkpass
```

Served only at `bloom.vallepinto.com/lens/*`; everything else on that host is untouched.

## How it works

1. **Attest (once per install).** The app fetches a challenge, calls
   `DCAppAttestService.attestKey(keyId, clientDataHash: SHA256(challengeBytes))`, and posts the attestation.
   The Worker (`src/appattest.ts`) follows Apple's validation steps exactly:
   x5c chain → pinned **Apple App Attestation Root CA** (embedded in `src/certs.ts`), nonce
   `SHA256(authData ‖ SHA256(challenge))` equals certificate extension `1.2.840.113635.100.8.2`,
   `SHA256(publicKey) == keyId`, `rpIdHash == SHA256("<TEAM_ID>.com.rvp97.scanner")`, counter `0`,
   AAGUID `appattestdevelop` / `appattest\0…` per `APP_ATTEST_ENV`, `credentialId == keyId`.
   The public key + counter are stored in D1. The challenge is deleted before verification (single use).
2. **Sign (per pass).** The app sends the JSON body with an assertion over `SHA256(body)`. The Worker checks the
   ECDSA P-256 signature over `SHA256(authenticatorData ‖ SHA256(body))`, the rpIdHash, and that the counter
   strictly increases (updated atomically together with the hourly quota), and **only then** parses the body.
3. **Build.** Strict schema (`src/schema.ts`, unknown keys rejected) → `pass.json` (`src/passjson.ts`:
   `organizationName`/`logoText` "Ojito", random UUID serial, fixed colour palette, flight `semantics`, a back-field
   disclaimer that the pass isn't issued by the carrier/venue) + bundled Ojito icon/logo PNGs → `manifest.json`
   (SHA-1 per file) → detached CMS signature (`src/pkcs7.ts`: SHA-256, RSA PKCS#1 v1.5, signed attributes
   contentType / signingTime / messageDigest, certificates = pass cert + WWDR G4) → zip.

**D1 vs KV.** Every challenge and every pass request is a write (challenge insert/delete, counter update, quota
bucket). KV's free tier allows only 1,000 writes/day and is eventually consistent — a replayed assertion could
race a stale counter. D1 gives 100k writes/day on the free plan and atomic conditional `UPDATE … WHERE counter < ?`
/ `DELETE … RETURNING`, which is exactly what replay protection needs.

**Rate limits.** Workers Rate Limiting bindings only support 10 s / 60 s windows, so they are burst limiters
(`RL_IP` 15/min per IP on all endpoints, `RL_KEY` 5/min per key on `/pass`). Hourly quotas live in D1:
20 passes/hour per device key (in the same atomic update as the counter), 60 requests/hour per IP and
10 attestations/hour per IP (IP stored only as a truncated SHA-256 inside an hour bucket, purged after ≤ 2 h).

## Setup

Prerequisites: Node 20+, a Cloudflare account with the `vallepinto.com` zone, an Apple Developer account.

### 1. Pass Type ID + certificate

If you already have `~/.lens-wallet/pass-cert.pem`, `~/.lens-wallet/pass.key` and `~/.lens-wallet/wwdr-g4.pem`,
skip to step 2. Otherwise:

1. developer.apple.com → Certificates, IDs & Profiles → Identifiers → **Pass Type IDs** → `pass.com.rvp97.scanner`.
2. Select it → **Create Certificate** → upload a CSR (Keychain Access → Certificate Assistant → *Request a
   Certificate From a Certificate Authority…*, saved to disk) → download `pass.cer`, double-click to import.
3. In Keychain Access, export the certificate **with its private key** as `pass.p12` (set an export password).
4. Convert (keep everything under `~/.lens-wallet`, **never** in the repo):

```sh
mkdir -p ~/.lens-wallet && chmod 700 ~/.lens-wallet && cd ~/.lens-wallet
# OpenSSL 3 needs -legacy for Keychain-exported .p12 files (RC2/3DES); drop it if you get "unsupported".
openssl pkcs12 -legacy -in pass.p12 -clcerts -nokeys -out pass-cert.pem
openssl pkcs12 -legacy -in pass.p12 -nocerts -nodes -out pass.key
chmod 600 pass.key
# Apple WWDR G4 intermediate (DER → PEM)
curl -fsSLO https://www.apple.com/certificateauthority/AppleWWDRCAG4.cer
openssl x509 -inform DER -in AppleWWDRCAG4.cer -out wwdr-g4.pem
```

The Worker accepts the key as PKCS#8 (`BEGIN PRIVATE KEY`) **or** PKCS#1 (`BEGIN RSA PRIVATE KEY`). If you prefer
PKCS#8: `openssl pkcs8 -topk8 -nocrypt -in pass.key -out pass.pk8.pem`. It must be unencrypted (Worker secrets
are encrypted at rest by Cloudflare).

Sanity checks (these print no secret material):

```sh
openssl x509 -in ~/.lens-wallet/pass-cert.pem -noout -subject -enddate   # UID=pass.com.rvp97.scanner, OU=<TEAM_ID>
# cert and key belong together if these two hashes match:
openssl x509 -in ~/.lens-wallet/pass-cert.pem -noout -pubkey | openssl sha256
openssl pkey -in ~/.lens-wallet/pass.key -pubout | openssl sha256
openssl verify -CAfile ~/.lens-wallet/wwdr-g4.pem ~/.lens-wallet/pass-cert.pem   # "OK" needs the Apple root in your trust store; optional
```

### 2. Configure `wrangler.toml`

- `TEAM_ID` — your 10-character Apple Team ID. **The Worker returns 500 `not_configured` while it is the
  `XXXXXXXXXX` placeholder.**
- `APP_ID` — bundle id (`com.rvp97.scanner`); the App Attest app id is `<TEAM_ID>.<APP_ID>`.
- `APP_ATTEST_ENV` — `development` for Xcode-installed builds, `production` for TestFlight/App Store. It must
  match the app's `com.apple.developer.devicecheck.appattest-environment` entitlement. Keys attested in one
  environment are rejected in the other (the app transparently re-attests).
- `KILL_SWITCH` — `"1"` makes every endpoint return 503 (flip with a redeploy, or in the dashboard).

### 3. Create the database and apply migrations

```sh
cd wallet-service
npm ci
npx wrangler login
npx wrangler d1 create lens-wallet            # copy the printed database_id into wrangler.toml
npx wrangler d1 migrations apply lens-wallet --remote
```

### 4. Secrets (piped from files — never pasted, never echoed)

```sh
npx wrangler secret put PASS_CERT_PEM < ~/.lens-wallet/pass-cert.pem
npx wrangler secret put PASS_KEY_PEM  < ~/.lens-wallet/pass.key
npx wrangler secret put WWDR_PEM      < ~/.lens-wallet/wwdr-g4.pem
```

(The first `secret put` on a brand-new Worker offers to create it — accept.)

### 5. Deploy

```sh
npm test                       # typecheck + unit/integration tests
npx wrangler deploy --dry-run  # bundle check, no upload
npx wrangler deploy
curl -s https://bloom.vallepinto.com/lens/v1/challenge   # → {"challenge":"…","expiresAt":…}
```

> **Routing caveat.** A zone route only runs if nothing more specific owns the hostname. If
> `bloom.vallepinto.com` is attached to another Worker as a **Custom Domain**, Custom Domains take precedence over
> routes and `/lens/*` will never reach this Worker — in that case, either proxy `/lens/*` from that Worker via a
> service binding, or move bloom to a route. The hostname must be proxied (orange cloud).

### 6. App side

- Entitlement: `com.apple.developer.devicecheck.appattest-environment` = `development` (or `production`), and the
  App Attest capability enabled for `com.rvp97.scanner` in the developer portal.
- Client code: `Lens/Features/Wallet/` (`WalletClient`, `WalletPassRequest`, `AddPassSheet`, `AddPassButton`).

### Regenerating the pass images

`npm run icons` (macOS) renders `assets/*.png` with CoreGraphics (`scripts/gen-icons.swift`) and inlines them into
`src/assets.generated.ts`. The generated file is committed so deploys don't need macOS.

## Tests

```sh
npm test         # tsc + vitest: CBOR, schema, pass.json, manifest, PKCS#7 (verified with `openssl smime -verify
                 # -noverify` and `openssl cms -verify` against throwaway certs from scripts/gen-test-certs.sh),
                 # zip contents, App Attest attestation/assertion against a throwaway P-384/P-256 PKI,
                 # and the full HTTP flow over a node:sqlite D1 shim.
npm run bench    # CPU cost of the hot paths
```

## CPU budget (free plan: 10 ms CPU per request)

Measured with `process.cpuUsage()` on an Apple-silicon Mac (Node 25, includes WebCrypto time); Workers run on
comparable server cores, so treat these as estimates:

| path | CPU |
|---|---|
| assertion verify (every `/pass`) | ~0.15 ms |
| pkpass build + sign, warm isolate | ~2.4 ms |
| pkpass first build in an isolate (JIT) + signer load (PEM parse, RSA import; cached per isolate) | ~6.4 + 2.9 ms |
| attestation verify, warm | ~1.7 ms |
| attestation verify, cold isolate (JIT + root parse) | ~9 ms |

A warm `/pass` is ~3 ms; a pass request on a **cold** isolate lands around 9–10 ms, and a cold `/attest` around
9 ms. Cloudflare tolerates occasional overruns on the free plan, and attestation happens once per install, so
this fits — but if you see `exceededCpu` errors in the dashboard, the Workers Paid plan (30 s CPU default) removes
the concern. No request does unbounded work: bodies are capped (8 KB pass / 24 KB attest), CBOR decoding is
bounded, and JSON is only parsed after authentication.

## Threat model

**Prevented**

- *Signing oracle abuse by arbitrary clients* — every pass requires a valid App Attest assertion from a key that was
  attested by Apple for `<TEAM_ID>.com.rvp97.scanner`; scripts, curl, modified/resigned apps and other bundle ids
  fail attestation.
- *Replay* — challenges are single-use with a 5-minute TTL; assertion counters must strictly increase (atomic
  conditional update, so concurrent replays lose); the assertion covers the exact body bytes.
- *Tampering* — any change to the body invalidates the assertion.
- *Brand impersonation via our certificate* — no user images, no arbitrary colours, `organizationName`/`logoText`
  are always "Ojito", the description says "created with Ojito", and a back field disclaims affiliation. No
  `webServiceURL`/`authenticationToken`, so passes can't be pushed updates by anyone.
- *Injection / parser attacks* — strict schema (unknown keys rejected, length limits, control and bidi-override
  characters rejected, IATA/date/time formats), JSON built with `JSON.stringify`, bounded CBOR decoder, body caps.
- *Abuse volume* — per-IP and per-key burst limiters + hourly quotas; `KILL_SWITCH` for emergencies.
- *Data exposure* — no request bodies or pass contents are logged or stored; IPs only as hour-scoped truncated
  hashes; device rows hold only the App Attest public key and counters and are purged after 400 days unused.
- *Secret leakage* — signing material only in Worker secrets, loaded per isolate; never in the repo or the app.

**Residual risks**

- *A genuine device can still request passes with any content* (within the schema and quotas). App Attest proves the
  app, not the user's intent — someone with a real iPhone and a jailbreak/instrumentation could drive the real app
  to sign misleading-but-schema-valid text (e.g. a fake flight). Mitigated by the "Ojito" branding, disclaimer and
  quotas; not eliminated. Apple's App Attest **receipt / fraud metric** (risk counts per device) isn't used yet —
  adding it would bound how many keys one device can mint.
- *Device-farm / key-minting abuse* — each reinstall yields a new key; per-IP attest limits slow this but a
  distributed attacker with many real devices isn't stopped.
- *IP hashes are brute-forceable* (IPv4 space is small); they live ≤ 2 hours.
- *Challenge endpoint* is unauthenticated and writes to D1; a distributed flood could exhaust the free D1 write
  quota (100k/day). Add a Cloudflare WAF rate-limit rule on `/lens/v1/challenge` if that happens.
- *Cloudflare account compromise* exposes the pass key (Cloudflare secrets are readable by the Worker, not by the
  dashboard) — protect the account with hardware-key 2FA; the pass certificate can be revoked in the Apple portal.
- *Scanned barcodes are copied verbatim* into the pass; a pass is only as valid as the code the user scanned.
- *CPU limit* on cold isolates on the free plan (see above).
