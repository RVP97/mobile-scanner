// Test-only fixtures: a fake App Attest PKI + device, throwaway pass certificates, and a D1 shim.
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import * as asn1js from "asn1js";
import * as pkijs from "pkijs";
import { encodeCbor } from "../../src/cbor";
import { ab, concat, sha256, te } from "../../src/util";

export const TEAM_ID = "TESTTEAM01";
export const BUNDLE_ID = "com.rvp97.scanner";
export const APP_ID = `${TEAM_ID}.${BUNDLE_ID}`;

// ---- Throwaway pass-signing certificates (openssl) ------------------------------------------------

export interface PassCertFixture {
  dir: string;
  certPem: string;
  keyPem: string;
  keyPkcs1Pem: string;
  wwdrPem: string;
}

let passCerts: PassCertFixture | undefined;
export function passCertFixture(): PassCertFixture {
  if (passCerts) return passCerts;
  const dir = mkdtempSync(join(tmpdir(), "lens-wallet-test-"));
  execFileSync("sh", [new URL("../../scripts/gen-test-certs.sh", import.meta.url).pathname, dir], { stdio: "pipe" });
  const r = (f: string) => readFileSync(join(dir, f), "utf8");
  passCerts = {
    dir,
    certPem: r("test-pass-cert.pem"),
    keyPem: r("test-pass-key.pem"),
    keyPkcs1Pem: r("test-pass-key-pkcs1.pem"),
    wwdrPem: r("test-wwdr.pem"),
  };
  return passCerts;
}

// ---- Fake App Attest PKI ------------------------------------------------------------------------

const P256 = { name: "ECDSA", namedCurve: "P-256" } as const;
const P384 = { name: "ECDSA", namedCurve: "P-384" } as const;

function name(cn: string): pkijs.RelativeDistinguishedNames {
  return new pkijs.RelativeDistinguishedNames({
    typesAndValues: [new pkijs.AttributeTypeAndValue({ type: "2.5.4.3", value: new asn1js.Utf8String({ value: cn }) })],
  });
}

async function makeCert(opts: {
  subject: string;
  issuer: string;
  publicKey: CryptoKey;
  signingKey: CryptoKey;
  hash: "SHA-256" | "SHA-384";
  ca: boolean;
  serial: number;
  nonce?: Uint8Array;
  notAfter?: Date;
}): Promise<Uint8Array> {
  const c = new pkijs.Certificate();
  c.version = 2;
  c.serialNumber = new asn1js.Integer({ value: opts.serial });
  c.subject = name(opts.subject);
  c.issuer = name(opts.issuer);
  c.notBefore.value = new Date(Date.now() - 3600_000);
  c.notAfter.value = opts.notAfter ?? new Date(Date.now() + 86400_000);
  const bc = new pkijs.BasicConstraints({ cA: opts.ca });
  c.extensions = [new pkijs.Extension({ extnID: "2.5.29.19", critical: true, extnValue: bc.toSchema().toBER(false), parsedValue: bc })];
  if (opts.nonce) {
    const v = new asn1js.Sequence({
      value: [
        new asn1js.Constructed({
          idBlock: { tagClass: 3, tagNumber: 1 },
          value: [new asn1js.OctetString({ valueHex: ab(opts.nonce) })],
        }),
      ],
    });
    c.extensions.push(new pkijs.Extension({ extnID: "1.2.840.113635.100.8.2", critical: false, extnValue: v.toBER(false) }));
  }
  await c.subjectPublicKeyInfo.importKey(opts.publicKey);
  await c.sign(opts.signingKey, opts.hash);
  return new Uint8Array(c.toSchema(true).toBER(false));
}

export interface FakePki {
  rootDer: Uint8Array;
  rootKey: CryptoKeyPair;
  interDer: Uint8Array;
  interKey: CryptoKeyPair;
}

export async function makePki(): Promise<FakePki> {
  const rootKey = (await crypto.subtle.generateKey(P384, true, ["sign", "verify"])) as CryptoKeyPair;
  const interKey = (await crypto.subtle.generateKey(P384, true, ["sign", "verify"])) as CryptoKeyPair;
  const rootDer = await makeCert({
    subject: "Test App Attestation Root CA",
    issuer: "Test App Attestation Root CA",
    publicKey: rootKey.publicKey,
    signingKey: rootKey.privateKey,
    hash: "SHA-384",
    ca: true,
    serial: 1,
  });
  const interDer = await makeCert({
    subject: "Test App Attestation CA 1",
    issuer: "Test App Attestation Root CA",
    publicKey: interKey.publicKey,
    signingKey: rootKey.privateKey,
    hash: "SHA-384",
    ca: true,
    serial: 2,
  });
  return { rootDer, rootKey, interDer, interKey };
}

export const AAGUID_DEV = te.encode("appattestdevelop");
export const AAGUID_PROD = concat(te.encode("appattest"), new Uint8Array(7));

export class FakeDevice {
  counter = 0;
  private constructor(
    readonly keyPair: CryptoKeyPair,
    readonly publicRaw: Uint8Array,
    readonly keyId: Uint8Array,
  ) {}

  static async create(): Promise<FakeDevice> {
    const kp = (await crypto.subtle.generateKey(P256, true, ["sign", "verify"])) as CryptoKeyPair;
    const raw = new Uint8Array((await crypto.subtle.exportKey("raw", kp.publicKey)) as ArrayBuffer);
    return new FakeDevice(kp, raw, await sha256(raw));
  }

  get keyIdB64(): string {
    return Buffer.from(this.keyId).toString("base64");
  }

  /** Mimics DCAppAttestService.attestKey(keyId, clientDataHash: SHA256(challenge)). */
  async attest(
    pki: FakePki,
    challenge: Uint8Array,
    o: { appId?: string; aaguid?: Uint8Array; counter?: number; credId?: Uint8Array; nonceOverride?: Uint8Array; signWith?: CryptoKey } = {},
  ): Promise<Uint8Array> {
    const credId = o.credId ?? this.keyId;
    const cose = encodeCbor(new Map<string | number, Uint8Array | number>([[1, 2], [3, -7], [-1, 1], [-2, this.publicRaw.slice(1, 33)], [-3, this.publicRaw.slice(33)]]));
    const counter = new Uint8Array(4);
    new DataView(counter.buffer).setUint32(0, o.counter ?? 0);
    const authData = concat(
      await sha256(te.encode(o.appId ?? APP_ID)),
      new Uint8Array([0x40]),
      counter,
      o.aaguid ?? AAGUID_DEV,
      new Uint8Array([credId.length >> 8, credId.length & 0xff]),
      credId,
      cose,
    );
    const nonce = o.nonceOverride ?? (await sha256(concat(authData, await sha256(challenge))));
    const leaf = await makeCert({
      subject: Buffer.from(this.keyId).toString("hex"),
      issuer: "Test App Attestation CA 1",
      publicKey: this.keyPair.publicKey,
      signingKey: o.signWith ?? pki.interKey.privateKey,
      hash: "SHA-256",
      ca: false,
      serial: 3,
      nonce,
    });
    return encodeCbor(
      new Map<string | number, any>([
        ["fmt", "apple-appattest"],
        ["attStmt", new Map<string | number, any>([["x5c", [leaf, pki.interDer]], ["receipt", new Uint8Array([1, 2, 3])]])],
        ["authData", authData],
      ]),
    );
  }

  /** Mimics DCAppAttestService.generateAssertion(keyId, clientDataHash: SHA256(body)). */
  async assert(body: Uint8Array, o: { appId?: string; counter?: number; flags?: number } = {}): Promise<Uint8Array> {
    this.counter = o.counter ?? this.counter + 1;
    const counter = new Uint8Array(4);
    new DataView(counter.buffer).setUint32(0, this.counter);
    const authenticatorData = concat(await sha256(te.encode(o.appId ?? APP_ID)), new Uint8Array([o.flags ?? 0x00]), counter);
    const nonce = await sha256(concat(authenticatorData, await sha256(body)));
    const raw = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, this.keyPair.privateKey, ab(nonce)));
    return encodeCbor(new Map<string | number, any>([["signature", rawToDer(raw)], ["authenticatorData", authenticatorData]]));
  }
}

export function rawToDer(raw: Uint8Array): Uint8Array {
  const int = (b: Uint8Array) => {
    let i = 0;
    while (i < b.length - 1 && b[i] === 0) i++;
    let v: Uint8Array = b.slice(i);
    if (v[0]! & 0x80) v = concat(new Uint8Array([0]), v);
    return concat(new Uint8Array([0x02, v.length]), v);
  };
  const body = concat(int(raw.slice(0, 32)), int(raw.slice(32)));
  return concat(new Uint8Array([0x30, body.length]), body);
}

// ---- D1 shim over node:sqlite --------------------------------------------------------------------

class Stmt {
  private args: unknown[] = [];
  constructor(
    private db: DatabaseSync,
    readonly sql: string,
  ) {}
  bind(...args: unknown[]) {
    this.args = args;
    return this;
  }
  async first<T>(): Promise<T | null> {
    return (this.db.prepare(this.sql).get(...(this.args as any[])) as T) ?? null;
  }
  async run() {
    const r = this.db.prepare(this.sql).run(...(this.args as any[]));
    return { success: true, meta: { changes: Number(r.changes) }, results: [] };
  }
  async all<T>() {
    return { success: true, results: this.db.prepare(this.sql).all(...(this.args as any[])) as T[], meta: {} };
  }
}

export function makeD1(): { d1: D1Database; db: DatabaseSync } {
  const db = new DatabaseSync(":memory:");
  db.exec(readFileSync(new URL("../../migrations/0001_init.sql", import.meta.url).pathname, "utf8"));
  const d1 = {
    prepare: (sql: string) => new Stmt(db, sql),
    batch: async (stmts: Stmt[]) => Promise.all(stmts.map((s) => s.run())),
  };
  return { d1: d1 as unknown as D1Database, db };
}

export class FakeRateLimit {
  counts = new Map<string, number>();
  constructor(readonly limitPerKey = Infinity) {}
  async limit({ key }: { key: string }) {
    const n = (this.counts.get(key) ?? 0) + 1;
    this.counts.set(key, n);
    return { success: n <= this.limitPerKey };
  }
}
