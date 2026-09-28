// Minimal, strict CBOR (RFC 8949) decoder — just enough for App Attest
// attestation / assertion objects. Deliberately small so it is easy to audit:
//  * definite lengths only (indefinite-length items are rejected)
//  * maps decode to Map<string | number, CborValue>
//  * tags are rejected, floats are rejected (App Attest never uses them)
//  * nesting depth, item counts and total size are bounded
//  * trailing bytes after the top-level item are an error

export type CborValue =
  | number
  | string
  | boolean
  | null
  | undefined
  | Uint8Array
  | CborValue[]
  | Map<string | number, CborValue>;

export class CborError extends Error {}

const MAX_DEPTH = 8;
const MAX_ITEMS = 256;

export function decodeCbor(input: Uint8Array): CborValue {
  let pos = 0;
  let items = 0;

  const need = (n: number) => {
    if (n < 0 || pos + n > input.length) throw new CborError("truncated");
  };

  const readArg = (info: number): number => {
    if (info < 24) return info;
    if (info === 24) {
      need(1);
      return input[pos++]!;
    }
    if (info === 25) {
      need(2);
      const v = (input[pos]! << 8) | input[pos + 1]!;
      pos += 2;
      return v;
    }
    if (info === 26) {
      need(4);
      const v =
        input[pos]! * 0x1000000 + ((input[pos + 1]! << 16) | (input[pos + 2]! << 8) | input[pos + 3]!);
      pos += 4;
      return v;
    }
    if (info === 27) {
      need(8);
      const hi = input[pos]! * 0x1000000 + ((input[pos + 1]! << 16) | (input[pos + 2]! << 8) | input[pos + 3]!);
      const lo =
        input[pos + 4]! * 0x1000000 + ((input[pos + 5]! << 16) | (input[pos + 6]! << 8) | input[pos + 7]!);
      pos += 8;
      if (hi > 0x1fffff) throw new CborError("integer too large");
      return hi * 0x100000000 + lo;
    }
    throw new CborError("indefinite or reserved length");
  };

  const item = (depth: number): CborValue => {
    if (depth > MAX_DEPTH) throw new CborError("too deep");
    if (++items > MAX_ITEMS) throw new CborError("too many items");
    need(1);
    const ib = input[pos++]!;
    const major = ib >> 5;
    const info = ib & 0x1f;
    switch (major) {
      case 0:
        return readArg(info);
      case 1:
        return -1 - readArg(info);
      case 2: {
        const len = readArg(info);
        need(len);
        const out = input.slice(pos, pos + len);
        pos += len;
        return out;
      }
      case 3: {
        const len = readArg(info);
        need(len);
        const s = new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(input.subarray(pos, pos + len));
        pos += len;
        return s;
      }
      case 4: {
        const len = readArg(info);
        if (len > MAX_ITEMS) throw new CborError("array too long");
        const arr: CborValue[] = [];
        for (let i = 0; i < len; i++) arr.push(item(depth + 1));
        return arr;
      }
      case 5: {
        const len = readArg(info);
        if (len > MAX_ITEMS) throw new CborError("map too long");
        const map = new Map<string | number, CborValue>();
        for (let i = 0; i < len; i++) {
          const k = item(depth + 1);
          if (typeof k !== "string" && typeof k !== "number") throw new CborError("unsupported map key");
          if (map.has(k)) throw new CborError("duplicate map key");
          map.set(k, item(depth + 1));
        }
        return map;
      }
      case 7:
        if (info === 20) return false;
        if (info === 21) return true;
        if (info === 22) return null;
        if (info === 23) return undefined;
        throw new CborError("unsupported simple/float value");
      default:
        throw new CborError("tags not supported");
    }
  };

  const value = item(0);
  if (pos !== input.length) throw new CborError("trailing bytes");
  return value;
}

/** Minimal encoder used by tests to build fixtures (maps with string keys, bytes, text, uints, arrays). */
export function encodeCbor(value: CborValue): Uint8Array {
  const out: number[] = [];
  const head = (major: number, n: number) => {
    if (n < 24) out.push((major << 5) | n);
    else if (n < 0x100) out.push((major << 5) | 24, n);
    else if (n < 0x10000) out.push((major << 5) | 25, n >> 8, n & 0xff);
    else out.push((major << 5) | 26, (n >>> 24) & 0xff, (n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff);
  };
  const enc = (v: CborValue) => {
    if (v instanceof Uint8Array) {
      head(2, v.length);
      for (const b of v) out.push(b);
    } else if (typeof v === "string") {
      const b = new TextEncoder().encode(v);
      head(3, b.length);
      for (const x of b) out.push(x);
    } else if (typeof v === "number") {
      if (v >= 0) head(0, v);
      else head(1, -1 - v);
    } else if (Array.isArray(v)) {
      head(4, v.length);
      v.forEach(enc);
    } else if (v instanceof Map) {
      head(5, v.size);
      for (const [k, x] of v) {
        enc(k);
        enc(x);
      }
    } else if (v === false) out.push(0xf4);
    else if (v === true) out.push(0xf5);
    else if (v === null) out.push(0xf6);
    else out.push(0xf7);
  };
  enc(value);
  return new Uint8Array(out);
}
