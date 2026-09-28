-- Lens wallet-service schema. Apply with:
--   npx wrangler d1 migrations apply lens-wallet --remote

-- Single-use App Attest challenges (5-minute TTL; purged by the cron trigger).
CREATE TABLE IF NOT EXISTS challenges (
  challenge  TEXT PRIMARY KEY,           -- base64url(32 random bytes)
  expires_at INTEGER NOT NULL            -- unix seconds
);
CREATE INDEX IF NOT EXISTS idx_challenges_expires ON challenges (expires_at);

-- Attested App Attest keys. No user data: just the device key and its counters.
CREATE TABLE IF NOT EXISTS devices (
  key_id       TEXT PRIMARY KEY,         -- base64 SHA-256(public key), as DCAppAttestService returns it
  public_key   TEXT NOT NULL,            -- base64 uncompressed P-256 point (65 bytes)
  counter      INTEGER NOT NULL,         -- last accepted assertion counter (strictly increasing)
  env          TEXT NOT NULL,            -- development | production
  created_at   INTEGER NOT NULL,
  last_used_at INTEGER NOT NULL,
  window_start INTEGER NOT NULL DEFAULT 0, -- hourly pass quota window
  window_count INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_devices_last_used ON devices (last_used_at);

-- Hourly per-IP quotas. `bucket` = scope:hour:truncated SHA-256 of the IP; rows live ≤ 2 hours.
CREATE TABLE IF NOT EXISTS ip_usage (
  bucket     TEXT PRIMARY KEY,
  hour       INTEGER NOT NULL,
  count      INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ip_usage_hour ON ip_usage (hour);
