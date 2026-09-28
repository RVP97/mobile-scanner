import { beforeAll, describe, expect, it } from "vitest";
import { AttestError, derSignatureToRaw, verifyAssertion, verifyAttestation } from "../src/appattest";
import { APPLE_APP_ATTEST_ROOT_PEM } from "../src/certs";
import { pemToDer, sha256 } from "../src/util";
import { AAGUID_PROD, APP_ID, FakeDevice, makePki, rawToDer, type FakePki } from "./helpers/fixtures";

const challenge = crypto.getRandomValues(new Uint8Array(32));

async function expectReason(p: Promise<unknown>, reason: string) {
  await expect(p).rejects.toSatisfy((e: unknown) => e instanceof AttestError && e.reason === reason);
}

describe("App Attest attestation", () => {
  let pki: FakePki;
  let dev: FakeDevice;
  beforeAll(async () => {
    pki = await makePki();
    dev = await FakeDevice.create();
  });
  const base = () => ({ keyId: dev.keyId, challenge, appId: APP_ID, env: "development" as const, rootCertDer: pki.rootDer });

  it("accepts a well-formed attestation and returns the device public key", async () => {
    const att = await dev.attest(pki, challenge);
    const r = await verifyAttestation({ ...base(), attestation: att });
    expect(r.publicKey).toEqual(dev.publicRaw);
    expect(Array.from(await sha256(r.publicKey))).toEqual(Array.from(dev.keyId));
  });

  it("the embedded Apple root parses and is the pinned default", () => {
    expect(pemToDer(APPLE_APP_ATTEST_ROOT_PEM).length).toBeGreaterThan(500);
  });

  it("rejects a chain that does not end at the pinned root (e.g. Apple's real root)", async () => {
    const att = await dev.attest(pki, challenge);
    await expectReason(verifyAttestation({ ...base(), attestation: att, rootCertDer: pemToDer(APPLE_APP_ATTEST_ROOT_PEM) }), "chain_names");
  });
  it("rejects a leaf not signed by the intermediate", async () => {
    const rogue = (await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-384" }, true, ["sign"])) as CryptoKeyPair;
    const att = await dev.attest(pki, challenge, { signWith: rogue.privateKey });
    await expectReason(verifyAttestation({ ...base(), attestation: att }), "chain_signature");
  });
  it("rejects a different challenge (nonce mismatch)", async () => {
    const att = await dev.attest(pki, challenge);
    await expectReason(verifyAttestation({ ...base(), attestation: att, challenge: new Uint8Array(32) }), "nonce_mismatch");
  });
  it("rejects a forged nonce extension", async () => {
    const att = await dev.attest(pki, challenge, { nonceOverride: new Uint8Array(32) });
    await expectReason(verifyAttestation({ ...base(), attestation: att }), "nonce_mismatch");
  });
  it("rejects a keyId that is not the hash of the certified key", async () => {
    const att = await dev.attest(pki, challenge);
    await expectReason(verifyAttestation({ ...base(), attestation: att, keyId: new Uint8Array(32) }), "keyid_mismatch");
  });
  it("rejects another app's rpIdHash", async () => {
    const att = await dev.attest(pki, challenge, { appId: "ABCDE12345.com.evil.app" });
    await expectReason(verifyAttestation({ ...base(), attestation: att }), "rpid_mismatch");
  });
  it("rejects a non-zero counter", async () => {
    const att = await dev.attest(pki, challenge, { counter: 1 });
    await expectReason(verifyAttestation({ ...base(), attestation: att }), "counter_nonzero");
  });
  it("enforces the aaguid for the configured environment", async () => {
    const dev2 = await dev.attest(pki, challenge);
    await expectReason(verifyAttestation({ ...base(), attestation: dev2, env: "production" }), "aaguid_mismatch");
    const prod = await dev.attest(pki, challenge, { aaguid: AAGUID_PROD });
    await expect(verifyAttestation({ ...base(), attestation: prod, env: "production" })).resolves.toBeTruthy();
    await expectReason(verifyAttestation({ ...base(), attestation: prod, env: "development" }), "aaguid_mismatch");
  });
  it("rejects credentialId != keyId", async () => {
    const att = await dev.attest(pki, challenge, { credId: new Uint8Array(32).fill(7) });
    await expectReason(verifyAttestation({ ...base(), attestation: att }), "credid_mismatch");
  });
  it("rejects garbage", async () => {
    await expectReason(verifyAttestation({ ...base(), attestation: new Uint8Array([1, 2, 3]) }), "cbor_invalid");
  });
});

describe("App Attest assertion", () => {
  let dev: FakeDevice;
  beforeAll(async () => {
    dev = await FakeDevice.create();
  });
  const body = new TextEncoder().encode('{"passType":"generic"}');

  it("verifies and returns the new counter", async () => {
    const a = await dev.assert(body, { counter: 5 });
    expect(await verifyAssertion({ assertion: a, clientData: body, publicKey: dev.publicRaw, storedCounter: 4, appId: APP_ID })).toBe(5);
  });
  it("rejects a replayed / non-increasing counter", async () => {
    const a = await dev.assert(body, { counter: 5 });
    await expectReason(verifyAssertion({ assertion: a, clientData: body, publicKey: dev.publicRaw, storedCounter: 5, appId: APP_ID }), "counter_replay");
  });
  it("rejects a tampered body", async () => {
    const a = await dev.assert(body, { counter: 9 });
    const tampered = new TextEncoder().encode('{"passType":"generiC"}');
    await expectReason(verifyAssertion({ assertion: a, clientData: tampered, publicKey: dev.publicRaw, storedCounter: 0, appId: APP_ID }), "assertion_signature");
  });
  it("rejects another key", async () => {
    const other = await FakeDevice.create();
    const a = await other.assert(body, { counter: 9 });
    await expectReason(verifyAssertion({ assertion: a, clientData: body, publicKey: dev.publicRaw, storedCounter: 0, appId: APP_ID }), "assertion_signature");
  });
  it("rejects another app id", async () => {
    const a = await dev.assert(body, { counter: 10, appId: "ABCDE12345.com.evil.app" });
    await expectReason(verifyAssertion({ assertion: a, clientData: body, publicKey: dev.publicRaw, storedCounter: 0, appId: APP_ID }), "rpid_mismatch");
  });
  it("DER <-> raw signature conversion handles leading zeros", () => {
    const raw = new Uint8Array(64);
    raw[31] = 1;
    raw[32] = 0x80;
    expect(derSignatureToRaw(rawToDer(raw))).toEqual(raw);
  });
});
