export interface Env {
  DB: D1Database;
  /** Burst limiter keyed by client IP (all endpoints). */
  RL_IP: RateLimit;
  /** Burst limiter keyed by App Attest keyId (pass endpoint). */
  RL_KEY: RateLimit;

  TEAM_ID: string;
  /** Bundle identifier, e.g. com.rvp97.scanner. The App Attest app ID is `${TEAM_ID}.${APP_ID}`. */
  APP_ID: string;
  PASS_TYPE_ID: string;
  APP_ATTEST_ENV: string;
  KILL_SWITCH: string;

  PASS_CERT_PEM?: string;
  PASS_KEY_PEM?: string;
  WWDR_PEM?: string;
}

export const LIMITS = {
  challengeTtlSeconds: 300,
  /** Hourly quotas enforced in D1 (Workers rate-limit bindings only support 10 s / 60 s periods). */
  passesPerKeyPerHour: 20,
  requestsPerIpPerHour: 60,
  attestsPerIpPerHour: 10,
  maxPassBodyBytes: 8 * 1024,
  maxAttestBodyBytes: 24 * 1024,
  maxAssertionHeaderChars: 1024,
  /** Devices unused for this long are forgotten (they re-attest transparently). */
  deviceRetentionSeconds: 400 * 24 * 3600,
} as const;

export function isKillSwitchOn(env: Env): boolean {
  return /^(1|true|on|yes)$/i.test((env.KILL_SWITCH ?? "").trim());
}
