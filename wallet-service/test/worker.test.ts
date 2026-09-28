// End-to-end through the fetch handler, with a node:sqlite-backed D1 shim and a throwaway App Attest PKI.
import { unzipSync } from "fflate";
import { beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { Env } from "../src/env";
import { createHandler, purge } from "../src/index";
import { FakeDevice, FakeRateLimit, TEAM_ID, BUNDLE_ID, makeD1, makePki, passCertFixture, type FakePki } from "./helpers/fixtures";
import { BOARDING } from "./helpers/samples";

const BASE = "https://bloom.vallepinto.com/lens/v1";
let pki: FakePki;
let handler: ReturnType<typeof createHandler>;
let env: Env;
let db: ReturnType<typeof makeD1>["db"];

beforeAll(async () => {
  pki = await makePki();
  handler = createHandler({ rootCertDer: pki.rootDer });
});

beforeEach(() => {
  const f = passCertFixture();
  const d = makeD1();
  db = d.db;
  env = {
    DB: d.d1,
    RL_IP: new FakeRateLimit() as unknown as RateLimit,
    RL_KEY: new FakeRateLimit() as unknown as RateLimit,
    TEAM_ID,
    APP_ID: BUNDLE_ID,
    PASS_TYPE_ID: "pass.com.rvp97.scanner",
    APP_ATTEST_ENV: "development",
    KILL_SWITCH: "0",
    PASS_CERT_PEM: f.certPem,
    PASS_KEY_PEM: f.keyPem,
    WWDR_PEM: f.wwdrPem,
  };
});

const ip = (n = 1) => ({ "cf-connecting-ip": `203.0.113.${n}` });

async function getChallenge(): Promise<string> {
  const r = await handler.fetch(new Request(`${BASE}/challenge`, { headers: ip() }), env);
  expect(r.status).toBe(200);
  return ((await r.json()) as { challenge: string }).challenge;
}

async function attest(dev: FakeDevice, challengeOverride?: string): Promise<Response> {
  const challenge = challengeOverride ?? (await getChallenge());
  const chBytes = Buffer.from(challenge, "base64url");
  const att = await dev.attest(pki, chBytes);
  return handler.fetch(
    new Request(`${BASE}/attest`, {
      method: "POST",
      headers: { "content-type": "application/json", ...ip() },
      body: JSON.stringify({ keyId: dev.keyIdB64, attestation: Buffer.from(att).toString("base64"), challenge }),
    }),
    env,
  );
}

async function requestPass(dev: FakeDevice, body: unknown, o: { counter?: number; ipN?: number } = {}): Promise<Response> {
  const bytes = new TextEncoder().encode(JSON.stringify(body));
  const assertion = await dev.assert(bytes, { counter: o.counter });
  return handler.fetch(
    new Request(`${BASE}/pass`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-lens-key-id": dev.keyIdB64,
        "x-lens-assertion": Buffer.from(assertion).toString("base64"),
        ...ip(o.ipN),
      },
      body: bytes,
    }),
    env,
  );
}

describe("worker", () => {
  it("challenge → attest → pass returns a signed .pkpass", async () => {
    const dev = await FakeDevice.create();
    expect((await attest(dev)).status).toBe(201);
    const r = await requestPass(dev, BOARDING);
    expect(r.status).toBe(200);
    expect(r.headers.get("content-type")).toBe("application/vnd.apple.pkpass");
    expect(r.headers.get("cache-control")).toBe("no-store");
    const files = unzipSync(new Uint8Array(await r.arrayBuffer()));
    expect(files["signature"]!.length).toBeGreaterThan(1000);
    const pass = JSON.parse(new TextDecoder().decode(files["pass.json"]));
    expect(pass.teamIdentifier).toBe(TEAM_ID);
    const row = db.prepare("SELECT counter, window_count FROM devices").get() as any;
    expect(row).toEqual({ counter: 1, window_count: 1 });
  });

  it("challenges are single-use and expire", async () => {
    const dev = await FakeDevice.create();
    const ch = await getChallenge();
    expect((await attest(dev, ch)).status).toBe(201);
    const dev2 = await FakeDevice.create();
    expect((await attest(dev2, ch)).status).toBe(400);
    const ch2 = await getChallenge();
    db.prepare("UPDATE challenges SET expires_at = 0").run();
    expect((await attest(dev2, ch2)).status).toBe(400);
    expect((await attest(dev2, "A".repeat(43))).status).toBe(400);
  });

  it("an invalid attestation still burns the challenge", async () => {
    const dev = await FakeDevice.create();
    const ch = await getChallenge();
    const r = await handler.fetch(
      new Request(`${BASE}/attest`, {
        method: "POST",
        headers: ip(),
        body: JSON.stringify({ keyId: dev.keyIdB64, attestation: "A".repeat(200), challenge: ch }),
      }),
      env,
    );
    expect(r.status).toBe(401);
    expect(db.prepare("SELECT count(*) AS n FROM challenges").get()).toEqual({ n: 0 });
  });

  it("re-attesting the same key is refused", async () => {
    const dev = await FakeDevice.create();
    expect((await attest(dev)).status).toBe(201);
    expect((await attest(dev)).status).toBe(409);
  });

  it("rejects replayed assertions, unknown keys, tampered bodies", async () => {
    const dev = await FakeDevice.create();
    await attest(dev);
    expect((await requestPass(dev, BOARDING, { counter: 3 })).status).toBe(200);
    expect((await requestPass(dev, BOARDING, { counter: 3 })).status).toBe(401);
    expect((await requestPass(dev, BOARDING, { counter: 2 })).status).toBe(401);

    const stranger = await FakeDevice.create();
    const r = await requestPass(stranger, BOARDING);
    expect(r.status).toBe(401);
    expect(await r.json()).toEqual({ error: "unknown_key" });

    const bytes = new TextEncoder().encode(JSON.stringify(BOARDING));
    const assertion = await dev.assert(bytes, { counter: 10 });
    const tampered = await handler.fetch(
      new Request(`${BASE}/pass`, {
        method: "POST",
        headers: { "x-lens-key-id": dev.keyIdB64, "x-lens-assertion": Buffer.from(assertion).toString("base64"), ...ip() },
        body: JSON.stringify({ ...BOARDING, color: "plum" }),
      }),
      env,
    );
    expect(tampered.status).toBe(401);
    expect((await handler.fetch(new Request(`${BASE}/pass`, { method: "POST", body: "{}" }), env)).status).toBe(401);
  });

  it("validates the (authenticated) body strictly", async () => {
    const dev = await FakeDevice.create();
    await attest(dev);
    const r = await requestPass(dev, { ...BOARDING, fields: { ...(BOARDING.fields as object), from: "mexico" } });
    expect(r.status).toBe(400);
    const j = (await r.json()) as { error: string; issues: string[] };
    expect(j.error).toBe("invalid_pass_request");
    expect(j.issues.join()).toContain("fields.from");
  });

  it("enforces the hourly per-key quota", async () => {
    const dev = await FakeDevice.create();
    await attest(dev);
    db.prepare("UPDATE devices SET window_start = ?, window_count = 20").run(Math.floor(Date.now() / 1000));
    const r = await requestPass(dev, BOARDING);
    expect(r.status).toBe(429);
    db.prepare("UPDATE devices SET window_start = ?").run(Math.floor(Date.now() / 1000) - 3601);
    expect((await requestPass(dev, BOARDING)).status).toBe(200);
  });

  it("enforces the hourly per-IP quota and burst bindings", async () => {
    for (let i = 0; i < 60; i++) {
      expect((await handler.fetch(new Request(`${BASE}/challenge`, { headers: ip(9) }), env)).status).toBe(200);
    }
    expect((await handler.fetch(new Request(`${BASE}/challenge`, { headers: ip(9) }), env)).status).toBe(429);
    env.RL_IP = new FakeRateLimit(0) as unknown as RateLimit;
    expect((await handler.fetch(new Request(`${BASE}/challenge`, { headers: ip(8) }), env)).status).toBe(429);
    // Stored IP identifiers are hashes, never the address.
    const buckets = db.prepare("SELECT bucket FROM ip_usage").all() as { bucket: string }[];
    expect(buckets.every((b) => !b.bucket.includes("203.0.113"))).toBe(true);
  });

  it("kill switch → 503 everywhere; unknown paths 404; wrong methods 405", async () => {
    env.KILL_SWITCH = "1";
    expect((await handler.fetch(new Request(`${BASE}/challenge`), env)).status).toBe(503);
    expect((await handler.fetch(new Request(`${BASE}/pass`, { method: "POST" }), env)).status).toBe(503);
    env.KILL_SWITCH = "0";
    expect((await handler.fetch(new Request(`https://bloom.vallepinto.com/other`), env)).status).toBe(404);
    expect((await handler.fetch(new Request(`${BASE}/nope`), env)).status).toBe(404);
    expect((await handler.fetch(new Request(`${BASE}/pass`), env)).status).toBe(405);
  });

  it("refuses to run with a placeholder team id or a mismatched pass certificate", async () => {
    const dev = await FakeDevice.create();
    await attest(dev);
    env.PASS_TYPE_ID = "pass.com.someone.else";
    expect((await requestPass(dev, BOARDING)).status).toBe(500);
    env.TEAM_ID = "XXXXXXXXXX";
    const r = await handler.fetch(new Request(`${BASE}/attest`, { method: "POST", headers: ip(), body: "{}" }), env);
    expect(r.status).toBe(500);
  });

  it("rejects oversized bodies", async () => {
    const r = await handler.fetch(
      new Request(`${BASE}/attest`, { method: "POST", headers: ip(), body: "x".repeat(30_000) }),
      env,
    );
    expect(r.status).toBe(413);
  });

  it("cron purge removes expired challenges and stale IP buckets", async () => {
    await getChallenge();
    const later = Math.floor(Date.now() / 1000) + 3 * 3600;
    await purge(env, later);
    expect(db.prepare("SELECT count(*) AS n FROM challenges").get()).toEqual({ n: 0 });
    expect(db.prepare("SELECT count(*) AS n FROM ip_usage").get()).toEqual({ n: 0 });
  });
});
