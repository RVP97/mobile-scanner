// Apple App Attest server-side verification.
// Follows "Validating apps that connect to your server" (developer.apple.com/documentation/devicecheck).

import * as asn1js from "asn1js";
import * as pkijs from "pkijs";
import { CborError, decodeCbor, type CborValue } from "./cbor";
import { ab, bytesEqual, concat, sha256, te } from "./util";

export type AttestEnv = "development" | "production";

const AAGUID_DEVELOPMENT = te.encode("appattestdevelop"); // 16 bytes
const AAGUID_PRODUCTION = concat(te.encode("appattest"), new Uint8Array(7)); // "appattest" + 7 NULs
const NONCE_EXTENSION_OID = "1.2.840.113635.100.8.2";

export class AttestError extends Error {
  constructor(readonly reason: string) {
    super(reason);
  }
}

export interface AuthData {
  rpIdHash: Uint8Array;
  flags: number;
  counter: number;
  aaguid?: Uint8Array;
  credentialId?: Uint8Array;
}

export function parseAuthData(b: Uint8Array): AuthData {
  if (b.length < 37) throw new AttestError("authdata_short");
  const rpIdHash = b.slice(0, 32);
  const flags = b[32]!;
  const counter = new DataView(b.buffer, b.byteOffset + 33, 4).getUint32(0, false);
  const out: AuthData = { rpIdHash, flags, counter };
  if (flags & 0x40) {
    if (b.length < 55) throw new AttestError("authdata_short");
    out.aaguid = b.slice(37, 53);
    const len = (b[53]! << 8) | b[54]!;
    if (len === 0 || len > 64 || b.length < 55 + len) throw new AttestError("authdata_credid");
    out.credentialId = b.slice(55, 55 + len);
  }
  return out;
}

function mapGet(m: CborValue, k: string): CborValue {
  if (!(m instanceof Map)) throw new AttestError("cbor_shape");
  return m.get(k);
}

function asBytes(v: CborValue, what: string): Uint8Array {
  if (!(v instanceof Uint8Array)) throw new AttestError(`cbor_${what}`);
  return v;
}

function decode(buf: Uint8Array): CborValue {
  try {
    return decodeCbor(buf);
  } catch (e) {
    if (e instanceof CborError) throw new AttestError("cbor_invalid");
    throw e;
  }
}

function parseCert(der: Uint8Array): pkijs.Certificate {
  try {
    return pkijs.Certificate.fromBER(ab(der));
  } catch {
    throw new AttestError("cert_parse");
  }
}

function checkValidity(c: pkijs.Certificate, now: Date) {
  if (c.notBefore.value > now || c.notAfter.value < now) throw new AttestError("cert_expired");
}

function isCA(c: pkijs.Certificate): boolean {
  const bc = c.extensions?.find((e) => e.extnID === "2.5.29.19");
  return !!bc && bc.parsedValue instanceof pkijs.BasicConstraints && !!bc.parsedValue.cA;
}

/** Raw uncompressed EC point (0x04 || X || Y) of a certificate's public key. */
function rawPublicKey(c: pkijs.Certificate): Uint8Array {
  return new Uint8Array(c.subjectPublicKeyInfo.subjectPublicKey.valueBlock.valueHexView);
}

function nonceFromCert(c: pkijs.Certificate): Uint8Array {
  const ext = c.extensions?.find((e) => e.extnID === NONCE_EXTENSION_OID);
  if (!ext) throw new AttestError("nonce_missing");
  // Value: SEQUENCE { [1] EXPLICIT OCTET STRING nonce }
  const parsed = asn1js.fromBER(ext.extnValue.valueBlock.valueHexView);
  if (parsed.offset === -1) throw new AttestError("nonce_parse");
  const seq = parsed.result;
  if (!(seq instanceof asn1js.Sequence)) throw new AttestError("nonce_parse");
  for (const el of seq.valueBlock.value) {
    if (el.idBlock.tagClass === 3 && el.idBlock.tagNumber === 1) {
      const inner = (el as asn1js.Constructed).valueBlock.value[0];
      if (inner instanceof asn1js.OctetString) return new Uint8Array(inner.valueBlock.valueHexView);
    }
  }
  throw new AttestError("nonce_parse");
}

export interface AttestationInput {
  /** keyId as returned by DCAppAttestService (base64 of SHA-256(public key)), decoded. */
  keyId: Uint8Array;
  attestation: Uint8Array;
  /** The raw challenge bytes the server issued; the client hashes them into clientDataHash. */
  challenge: Uint8Array;
  /** "<TEAMID>.<bundle id>" */
  appId: string;
  env: AttestEnv;
  rootCertDer: Uint8Array;
  now?: Date;
}

export interface AttestedKey {
  /** Uncompressed P-256 point, 65 bytes. */
  publicKey: Uint8Array;
  receipt: Uint8Array;
}

let rootCache: { der: Uint8Array; cert: pkijs.Certificate } | undefined;

export async function verifyAttestation(inp: AttestationInput): Promise<AttestedKey> {
  const now = inp.now ?? new Date();
  const obj = decode(inp.attestation);
  if (mapGet(obj, "fmt") !== "apple-appattest") throw new AttestError("fmt");
  const attStmt = mapGet(obj, "attStmt");
  const authDataBytes = asBytes(mapGet(obj, "authData"), "authdata");
  const x5c = mapGet(attStmt, "x5c");
  const receipt = asBytes(mapGet(attStmt, "receipt") ?? new Uint8Array(0), "receipt");
  if (!Array.isArray(x5c) || x5c.length !== 2) throw new AttestError("x5c");

  // 1. Certificate chain: credCert <- intermediate <- pinned Apple root.
  const credCert = parseCert(asBytes(x5c[0]!, "x5c"));
  const intermediate = parseCert(asBytes(x5c[1]!, "x5c"));
  if (!rootCache || !bytesEqual(rootCache.der, inp.rootCertDer)) {
    rootCache = { der: inp.rootCertDer, cert: parseCert(inp.rootCertDer) };
  }
  const root = rootCache.cert;
  for (const c of [credCert, intermediate, root]) checkValidity(c, now);
  if (!intermediate.issuer.isEqual(root.subject) || !credCert.issuer.isEqual(intermediate.subject)) {
    throw new AttestError("chain_names");
  }
  if (!isCA(intermediate)) throw new AttestError("chain_ca");
  const [okInter, okLeaf] = await Promise.all([intermediate.verify(root), credCert.verify(intermediate)]);
  if (!okInter || !okLeaf) throw new AttestError("chain_signature");

  // 2–3. nonce = SHA256(authData || SHA256(challenge)) must equal the credCert extension.
  const clientDataHash = await sha256(inp.challenge);
  const nonce = await sha256(concat(authDataBytes, clientDataHash));
  if (!bytesEqual(nonce, nonceFromCert(credCert))) throw new AttestError("nonce_mismatch");

  // 4. SHA256(public key) == keyId.
  const publicKey = rawPublicKey(credCert);
  if (publicKey.length !== 65 || publicKey[0] !== 0x04) throw new AttestError("pubkey_format");
  if (!bytesEqual(await sha256(publicKey), inp.keyId)) throw new AttestError("keyid_mismatch");

  // 5–8. authenticator data.
  const ad = parseAuthData(authDataBytes);
  if (!bytesEqual(ad.rpIdHash, await sha256(te.encode(inp.appId)))) throw new AttestError("rpid_mismatch");
  if (ad.counter !== 0) throw new AttestError("counter_nonzero");
  const expectedAaguid = inp.env === "production" ? AAGUID_PRODUCTION : AAGUID_DEVELOPMENT;
  if (!ad.aaguid || !bytesEqual(ad.aaguid, expectedAaguid)) throw new AttestError("aaguid_mismatch");
  if (!ad.credentialId || !bytesEqual(ad.credentialId, inp.keyId)) throw new AttestError("credid_mismatch");

  return { publicKey, receipt };
}

/** Convert a DER ECDSA-Sig-Value to the raw r||s form WebCrypto expects. */
export function derSignatureToRaw(der: Uint8Array, size = 32): Uint8Array {
  const parsed = asn1js.fromBER(ab(der));
  const seq = parsed.result;
  if (parsed.offset === -1 || !(seq instanceof asn1js.Sequence) || seq.valueBlock.value.length !== 2) {
    throw new AttestError("sig_format");
  }
  const out = new Uint8Array(size * 2);
  seq.valueBlock.value.forEach((v, i) => {
    if (!(v instanceof asn1js.Integer)) throw new AttestError("sig_format");
    let b = new Uint8Array(v.valueBlock.valueHexView);
    while (b.length > size && b[0] === 0) b = b.subarray(1);
    if (b.length > size) throw new AttestError("sig_format");
    out.set(b, i * size + (size - b.length));
  });
  return out;
}

export interface AssertionInput {
  assertion: Uint8Array;
  /** Exact request body bytes the client hashed. */
  clientData: Uint8Array;
  publicKey: Uint8Array;
  storedCounter: number;
  appId: string;
}

/** Verifies an assertion and returns its (strictly greater) counter. The caller persists it atomically. */
export async function verifyAssertion(inp: AssertionInput): Promise<number> {
  const obj = decode(inp.assertion);
  const signature = asBytes(mapGet(obj, "signature"), "signature");
  const authenticatorData = asBytes(mapGet(obj, "authenticatorData"), "authdata");

  const clientDataHash = await sha256(inp.clientData);
  const nonce = await sha256(concat(authenticatorData, clientDataHash));

  const key = await crypto.subtle.importKey("raw", ab(inp.publicKey), { name: "ECDSA", namedCurve: "P-256" }, false, [
    "verify",
  ]);
  const ok = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    ab(derSignatureToRaw(signature)),
    ab(nonce),
  );
  if (!ok) throw new AttestError("assertion_signature");

  const ad = parseAuthData(authenticatorData);
  if (!bytesEqual(ad.rpIdHash, await sha256(te.encode(inp.appId)))) throw new AttestError("rpid_mismatch");
  if (ad.counter <= inp.storedCounter) throw new AttestError("counter_replay");
  return ad.counter;
}
