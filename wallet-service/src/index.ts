// Lens wallet-service: App Attest–gated, stateless Apple Wallet pass signer.
//
//   GET  /lens/v1/challenge   → { challenge }                    (single use, 5 min)
//   POST /lens/v1/attest      { keyId, attestation, challenge }   → 201
//   POST /lens/v1/pass        X-Lens-Key-Id, X-Lens-Assertion; JSON body → application/vnd.apple.pkpass
//
// Privacy: request bodies, pass contents and IPs are never logged. The only persistent data are
// App Attest public keys + counters, pending challenges, and short-lived hashed-IP quota buckets.

import { AttestError, verifyAssertion, verifyAttestation, type AttestEnv } from "./appattest";
import { APPLE_APP_ATTEST_ROOT_PEM } from "./certs";
import { isKillSwitchOn, LIMITS, type Env } from "./env";
import { certIsCurrentlyValid, certPassTypeId, loadSigner, type PassSigner } from "./pkcs7";
import { buildPkpass, PKPASS_MIME } from "./pkpass";
import { AttestRequestSchema, parsePassRequest } from "./schema";
import { fromBase64, fromBase64Url, pemToDer, sha256, te, toBase64, toBase64Url, toHex } from "./util";

const PREFIX = "/lens/v1";

const BASE_HEADERS = {
  "cache-control": "no-store",
  "x-content-type-options": "nosniff",
  "referrer-policy": "no-referrer",
};

function json(status: number, body: unknown, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...BASE_HEADERS, "content-type": "application/json; charset=utf-8", ...extra },
  });
}
const err = (status: number, error: string, extra?: Record<string, string>) => json(status, { error }, extra);

class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
  ) {
    super(code);
  }
}

const now = () => Math.floor(Date.now() / 1000);

async function readBody(req: Request, max: number): Promise<Uint8Array> {
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > max) throw new HttpError(413, "body_too_large");
  if (!req.body) return new Uint8Array(0);
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > max) {
      await reader.cancel();
      throw new HttpError(413, "body_too_large");
    }
    chunks.push(value);
  }
  const out = new Uint8Array(total);
  let o = 0;
  for (const c of chunks) {
    out.set(c, o);
    o += c.byteLength;
  }
  return out;
}

function clientIp(req: Request): string {
  return req.headers.get("cf-connecting-ip") ?? "unknown";
}

interface Config {
  appId: string;
  teamId: string;
  passTypeId: string;
  env: AttestEnv;
}

function config(env: Env): Config {
  const teamId = (env.TEAM_ID ?? "").trim();
  const bundle = (env.APP_ID ?? "").trim();
  const attestEnv = (env.APP_ATTEST_ENV ?? "").trim();
  if (!/^[A-Z0-9]{10}$/.test(teamId) || teamId === "XXXXXXXXXX") throw new HttpError(500, "not_configured");
  if (!/^[A-Za-z0-9.-]+$/.test(bundle)) throw new HttpError(500, "not_configured");
  if (attestEnv !== "development" && attestEnv !== "production") throw new HttpError(500, "not_configured");
  return { teamId, appId: `${teamId}.${bundle}`, passTypeId: (env.PASS_TYPE_ID ?? "").trim(), env: attestEnv };
}

// ---- Rate limiting -------------------------------------------------------------------------

async function burstLimit(binding: RateLimit | undefined, key: string): Promise<void> {
  if (!binding) return; // bindings are absent in unit tests only
  const { success } = await binding.limit({ key });
  if (!success) throw new HttpError(429, "rate_limited");
}

/** Hourly per-IP quota in D1. The IP is stored only as a truncated hash inside an hour-scoped bucket. */
async function ipHourlyQuota(env: Env, ip: string, scope: string, limit: number): Promise<void> {
  const hour = Math.floor(now() / 3600);
  const ipHash = toHex((await sha256(te.encode(`lens-ip-v1|${ip}`))).subarray(0, 12));
  const row = await env.DB.prepare(
    `INSERT INTO ip_usage (bucket, hour, count) VALUES (?1, ?2, 1)
     ON CONFLICT (bucket) DO UPDATE SET count = count + 1
     RETURNING count`,
  )
    .bind(`${scope}:${hour}:${ipHash}`, hour)
    .first<{ count: number }>();
  if (row && row.count > limit) throw new HttpError(429, "rate_limited");
}

// ---- Signer (cached per isolate) -------------------------------------------------------------

let signerCache: { key: string; signer: Promise<PassSigner> } | undefined;

async function getSigner(env: Env, cfg: Config): Promise<PassSigner> {
  if (!env.PASS_CERT_PEM || !env.PASS_KEY_PEM || !env.WWDR_PEM) throw new HttpError(500, "signer_not_configured");
  // Secrets only change on redeploy (new isolate), but compare the full values anyway.
  const cacheKey = `${env.PASS_CERT_PEM}\n${env.PASS_KEY_PEM}\n${env.WWDR_PEM}`;
  if (!signerCache || signerCache.key !== cacheKey) {
    const p = loadSigner(env.PASS_CERT_PEM, env.PASS_KEY_PEM, env.WWDR_PEM);
    signerCache = { key: cacheKey, signer: p };
    p.catch(() => {
      if (signerCache?.signer === p) signerCache = undefined;
    });
  }
  let signer: PassSigner;
  try {
    signer = await signerCache.signer;
  } catch {
    throw new HttpError(500, "signer_not_configured");
  }
  const uid = certPassTypeId(signer.cert);
  if ((uid && uid !== cfg.passTypeId) || !certIsCurrentlyValid(signer.cert)) {
    throw new HttpError(500, "signer_not_configured");
  }
  return signer;
}

// ---- Handlers --------------------------------------------------------------------------------

async function handleChallenge(env: Env, req: Request): Promise<Response> {
  const ip = clientIp(req);
  await burstLimit(env.RL_IP, `ip:${ip}`);
  await ipHourlyQuota(env, ip, "challenge", LIMITS.requestsPerIpPerHour);
  const challenge = toBase64Url(crypto.getRandomValues(new Uint8Array(32)));
  const expiresAt = now() + LIMITS.challengeTtlSeconds;
  await env.DB.prepare("INSERT INTO challenges (challenge, expires_at) VALUES (?1, ?2)").bind(challenge, expiresAt).run();
  return json(200, { challenge, expiresAt });
}

async function handleAttest(env: Env, req: Request, rootCertDer: Uint8Array): Promise<Response> {
  const cfg = config(env);
  const ip = clientIp(req);
  await burstLimit(env.RL_IP, `ip:${ip}`);
  await ipHourlyQuota(env, ip, "attest", LIMITS.attestsPerIpPerHour);

  const raw = await readBody(req, LIMITS.maxAttestBodyBytes);
  let parsed: unknown;
  try {
    parsed = JSON.parse(new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(raw));
  } catch {
    throw new HttpError(400, "invalid_json");
  }
  const body = AttestRequestSchema.safeParse(parsed);
  if (!body.success) throw new HttpError(400, "invalid_request");

  // Single-use: the challenge is consumed whether or not verification succeeds.
  const consumed = await env.DB.prepare(
    "DELETE FROM challenges WHERE challenge = ?1 AND expires_at >= ?2 RETURNING challenge",
  )
    .bind(body.data.challenge, now())
    .first();
  if (!consumed) throw new HttpError(400, "challenge_invalid");

  const keyId = fromBase64(body.data.keyId);
  const attestation = fromBase64(body.data.attestation);
  const challenge = fromBase64Url(body.data.challenge);
  if (!keyId || keyId.length !== 32 || !attestation || !challenge) throw new HttpError(400, "invalid_request");

  let publicKey: Uint8Array;
  try {
    ({ publicKey } = await verifyAttestation({
      keyId,
      attestation,
      challenge,
      appId: cfg.appId,
      env: cfg.env,
      rootCertDer,
    }));
  } catch (e) {
    if (e instanceof AttestError) throw new HttpError(401, "attestation_invalid");
    throw e;
  }

  const t = now();
  const res = await env.DB.prepare(
    `INSERT INTO devices (key_id, public_key, counter, env, created_at, last_used_at)
     VALUES (?1, ?2, 0, ?3, ?4, ?4) ON CONFLICT (key_id) DO NOTHING`,
  )
    .bind(body.data.keyId, toBase64(publicKey), cfg.env, t)
    .run();
  if (!res.meta.changes) throw new HttpError(409, "already_attested");
  return json(201, { ok: true });
}

interface DeviceRow {
  public_key: string;
  counter: number;
  env: string;
  window_start: number;
  window_count: number;
}

async function handlePass(env: Env, req: Request): Promise<Response> {
  const cfg = config(env);
  const ip = clientIp(req);
  await burstLimit(env.RL_IP, `ip:${ip}`);

  const keyIdStr = req.headers.get("x-lens-key-id") ?? "";
  const assertionStr = req.headers.get("x-lens-assertion") ?? "";
  if (!/^[A-Za-z0-9+/]{43}=$/.test(keyIdStr) || assertionStr.length === 0 || assertionStr.length > LIMITS.maxAssertionHeaderChars) {
    throw new HttpError(401, "missing_credentials");
  }
  const assertion = fromBase64(assertionStr);
  if (!assertion) throw new HttpError(401, "missing_credentials");

  await burstLimit(env.RL_KEY, `key:${keyIdStr}`);
  await ipHourlyQuota(env, ip, "pass", LIMITS.requestsPerIpPerHour);

  const body = await readBody(req, LIMITS.maxPassBodyBytes);

  const device = await env.DB.prepare(
    "SELECT public_key, counter, env, window_start, window_count FROM devices WHERE key_id = ?1",
  )
    .bind(keyIdStr)
    .first<DeviceRow>();
  if (!device || device.env !== cfg.env) throw new HttpError(401, "unknown_key");

  let counter: number;
  try {
    counter = await verifyAssertion({
      assertion,
      clientData: body,
      publicKey: fromBase64(device.public_key)!,
      storedCounter: device.counter,
      appId: cfg.appId,
    });
  } catch (e) {
    if (e instanceof AttestError) {
      console.warn("assertion_rejected", e.message);
      throw new HttpError(401, "assertion_invalid");
    }
    throw e;
  }

  // Atomically: counter must still be lower (no concurrent replay) and the hourly quota must allow it.
  const t = now();
  const upd = await env.DB.prepare(
    `UPDATE devices SET
       counter = ?1,
       last_used_at = ?2,
       window_start = CASE WHEN window_start <= ?2 - 3600 THEN ?2 ELSE window_start END,
       window_count = CASE WHEN window_start <= ?2 - 3600 THEN 1 ELSE window_count + 1 END
     WHERE key_id = ?3 AND counter < ?1 AND (window_start <= ?2 - 3600 OR window_count < ?4)`,
  )
    .bind(counter, t, keyIdStr, LIMITS.passesPerKeyPerHour)
    .run();
  if (!upd.meta.changes) {
    const cur = await env.DB.prepare("SELECT counter FROM devices WHERE key_id = ?1").bind(keyIdStr).first<{ counter: number }>();
    if (!cur || cur.counter >= counter) throw new HttpError(401, "assertion_invalid");
    throw new HttpError(429, "rate_limited");
  }

  // Only now — after the body is proven to come from a genuine instance of the app — parse it.
  let parsed: unknown;
  try {
    parsed = JSON.parse(new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(body));
  } catch {
    throw new HttpError(400, "invalid_json");
  }
  const result = parsePassRequest(parsed);
  if (!result.ok) {
    // Field paths and rule names only — never the submitted values.
    console.warn("invalid_pass_request", JSON.stringify(result.issues).slice(0, 500));
    return json(400, { error: "invalid_pass_request", issues: result.issues });
  }

  const signer = await getSigner(env, cfg);
  const { pkpass } = await buildPkpass(result.value, { passTypeIdentifier: cfg.passTypeId, teamIdentifier: cfg.teamId }, signer);
  return new Response(pkpass, {
    status: 200,
    headers: {
      ...BASE_HEADERS,
      "content-type": PKPASS_MIME,
      "content-disposition": 'attachment; filename="lens.pkpass"',
    },
  });
}

// ---- Entry points ----------------------------------------------------------------------------

export interface HandlerOptions {
  /** Trust anchor for App Attest. Tests inject a throwaway root; production always uses Apple's. */
  rootCertDer?: Uint8Array;
}

export function createHandler(opts: HandlerOptions = {}) {
  const rootCertDer = opts.rootCertDer ?? pemToDer(APPLE_APP_ATTEST_ROOT_PEM);

  return {
    async fetch(req: Request, env: Env): Promise<Response> {
      const { pathname } = new URL(req.url);
      if (!pathname.startsWith(`${PREFIX}/`)) return err(404, "not_found");
      if (isKillSwitchOn(env)) return err(503, "service_disabled", { "retry-after": "3600" });
      try {
        switch (pathname.slice(PREFIX.length)) {
          case "/challenge":
            if (req.method !== "GET") return err(405, "method_not_allowed", { allow: "GET" });
            return await handleChallenge(env, req);
          case "/attest":
            if (req.method !== "POST") return err(405, "method_not_allowed", { allow: "POST" });
            return await handleAttest(env, req, rootCertDer);
          case "/pass":
            if (req.method !== "POST") return err(405, "method_not_allowed", { allow: "POST" });
            return await handlePass(env, req);
          default:
            return err(404, "not_found");
        }
      } catch (e) {
        if (e instanceof HttpError) {
          console.warn("rejected", pathname, e.status, e.code);
          return err(e.status, e.code, e.status === 429 ? { "retry-after": "60" } : undefined);
        }
        // Log the error class only — never request data.
        console.error("unhandled", e instanceof Error ? e.name : typeof e);
        return err(500, "internal");
      }
    },

    async scheduled(_evt: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
      ctx.waitUntil(purge(env));
    },
  };
}

export async function purge(env: Env, at = now()): Promise<void> {
  await env.DB.batch([
    env.DB.prepare("DELETE FROM challenges WHERE expires_at < ?1").bind(at),
    env.DB.prepare("DELETE FROM ip_usage WHERE hour < ?1").bind(Math.floor(at / 3600) - 1),
    env.DB.prepare("DELETE FROM devices WHERE last_used_at < ?1").bind(at - LIMITS.deviceRetentionSeconds),
  ]);
}

export default createHandler() satisfies ExportedHandler<Env>;
