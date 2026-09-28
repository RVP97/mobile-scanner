// Small byte / encoding helpers. Everything here is pure and runtime-agnostic
// (Workers, Node 20+), relying only on WebCrypto and TextEncoder.

export const te = new TextEncoder();

export function concat(...parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let o = 0;
  for (const p of parts) {
    out.set(p, o);
    o += p.length;
  }
  return out;
}

/** Constant-time comparison for equal-length secrets/hashes. */
export function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i]! ^ b[i]!;
  return diff === 0;
}

export async function sha256(data: Uint8Array): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", data));
}

export async function sha1Hex(data: Uint8Array): Promise<string> {
  return toHex(new Uint8Array(await crypto.subtle.digest("SHA-1", data)));
}

export function toHex(b: Uint8Array): string {
  let s = "";
  for (const x of b) s += x.toString(16).padStart(2, "0");
  return s;
}

const B64_RE = /^[A-Za-z0-9+/]*={0,2}$/;
const B64URL_RE = /^[A-Za-z0-9_-]*$/;

/** Strict standard base64 decode. Returns null on malformed input. */
export function fromBase64(s: string): Uint8Array | null {
  if (s.length % 4 !== 0 || !B64_RE.test(s)) return null;
  try {
    const bin = atob(s);
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  } catch {
    return null;
  }
}

export function toBase64(b: Uint8Array): string {
  let bin = "";
  for (let i = 0; i < b.length; i += 0x8000) {
    bin += String.fromCharCode(...b.subarray(i, i + 0x8000));
  }
  return btoa(bin);
}

export function toBase64Url(b: Uint8Array): string {
  return toBase64(b).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function fromBase64Url(s: string): Uint8Array | null {
  if (!B64URL_RE.test(s)) return null;
  const std = s.replace(/-/g, "+").replace(/_/g, "/");
  return fromBase64(std + "=".repeat((4 - (std.length % 4)) % 4));
}

export function pemToDer(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/, "")
    .replace(/-----END [^-]+-----[\s\S]*$/, "")
    .replace(/\s+/g, "");
  const der = fromBase64(body);
  if (!der || der.length === 0) throw new Error("invalid PEM");
  return der;
}

/** Split a PEM bundle into its individual blocks (label + DER). */
export function pemBlocks(pem: string): { label: string; der: Uint8Array }[] {
  const re = /-----BEGIN ([^-]+)-----([\s\S]*?)-----END \1-----/g;
  const out: { label: string; der: Uint8Array }[] = [];
  for (const m of pem.matchAll(re)) {
    const der = fromBase64(m[2]!.replace(/\s+/g, ""));
    if (!der) throw new Error(`invalid PEM block ${m[1]}`);
    out.push({ label: m[1]!, der });
  }
  return out;
}

/** Copy into a standalone ArrayBuffer (asn1js / WebCrypto want exact buffers). */
export function ab(b: Uint8Array): ArrayBuffer {
  return b.slice().buffer as ArrayBuffer;
}
