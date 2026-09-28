import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { unzipSync } from "fflate";
import { beforeAll, describe, expect, it } from "vitest";
import { CborError, decodeCbor, encodeCbor } from "../src/cbor";
import { buildPassJson } from "../src/passjson";
import { certPassTypeId, loadSigner, signDetached, type PassSigner } from "../src/pkcs7";
import { buildManifest, buildPkpass, passImages } from "../src/pkpass";
import { parsePassRequest } from "../src/schema";
import { passCertFixture } from "./helpers/fixtures";
import { BOARDING } from "./helpers/samples";

const CFG = { passTypeIdentifier: "pass.com.rvp97.scanner", teamIdentifier: "TESTTEAM01" };

describe("cbor", () => {
  it("round-trips the shapes App Attest uses", () => {
    const v = new Map<string | number, any>([
      ["fmt", "apple-appattest"],
      ["n", 70000],
      ["neg", -7],
      ["b", new Uint8Array([1, 2, 3])],
      ["a", [new Uint8Array(300), "x"]],
    ]);
    const d = decodeCbor(encodeCbor(v)) as Map<string, any>;
    expect(d.get("fmt")).toBe("apple-appattest");
    expect(d.get("n")).toBe(70000);
    expect(d.get("neg")).toBe(-7);
    expect(d.get("a")[0].length).toBe(300);
  });
  it("rejects trailing bytes, truncation, indefinite lengths, tags, deep nesting, duplicate keys", () => {
    expect(() => decodeCbor(new Uint8Array([0x01, 0x02]))).toThrow(CborError);
    expect(() => decodeCbor(new Uint8Array([0x44, 0x01]))).toThrow(CborError);
    expect(() => decodeCbor(new Uint8Array([0x5f, 0xff]))).toThrow(CborError);
    expect(() => decodeCbor(new Uint8Array([0xc2, 0x40]))).toThrow(CborError);
    expect(() => decodeCbor(new Uint8Array(Array(20).fill(0x81).concat([0x01])))).toThrow(CborError);
    expect(() => decodeCbor(new Uint8Array([0xa2, 0x61, 0x61, 0x01, 0x61, 0x61, 0x02]))).toThrow(CborError);
    expect(() => decodeCbor(new Uint8Array([0x5a, 0xff, 0xff, 0xff, 0xff]))).toThrow(CborError);
  });
});

describe("schema", () => {
  it("accepts each pass type", () => {
    expect(parsePassRequest(BOARDING).ok).toBe(true);
    expect(
      parsePassRequest({
        passType: "eventTicket",
        barcode: { message: "TICKET-1", format: "QR" },
        fields: { title: "Concert", venue: "Foro Sol", date: "2026-11-02T20:00:00-06:00" },
      }).ok,
    ).toBe(true);
    expect(parsePassRequest({ passType: "storeCard", barcode: { message: "0123456789012", format: "Code128" }, fields: { title: "Gym", number: "0042" } }).ok).toBe(true);
    expect(parsePassRequest({ passType: "generic", barcode: { message: "héllo 世界", format: "Aztec" }, fields: { title: "Note" } }).ok).toBe(true);
  });

  const bad: [string, unknown][] = [
    ["unknown passType", { ...BOARDING, passType: "coupon" }],
    ["unknown top-level key", { ...BOARDING, webServiceURL: "https://evil" }],
    ["unknown field key", { ...BOARDING, fields: { ...BOARDING.fields, logo: "x" } }],
    ["lowercase IATA", { ...BOARDING, fields: { ...(BOARDING.fields as object), from: "mex" } }],
    ["4-letter IATA", { ...BOARDING, fields: { ...(BOARDING.fields as object), to: "KJFK" } }],
    ["bad date", { ...BOARDING, fields: { ...(BOARDING.fields as object), date: "2026-13-01" } }],
    ["bad time", { ...BOARDING, fields: { ...(BOARDING.fields as object), boardingTime: "7:45pm" } }],
    ["passenger too long", { ...BOARDING, fields: { ...(BOARDING.fields as object), passenger: "x".repeat(65) } }],
    ["control chars", { ...BOARDING, fields: { ...(BOARDING.fields as object), passenger: "A\u202eB" } }],
    ["missing required", { ...BOARDING, fields: { carrier: "AM" } }],
    ["message too long", { ...BOARDING, barcode: { message: "x".repeat(2049), format: "QR" } }],
    ["EAN format not accepted", { ...BOARDING, barcode: { message: "123", format: "EAN13" } }],
    ["non-ASCII Code128", { ...BOARDING, barcode: { message: "ñ", format: "Code128" } }],
    ["arbitrary color", { ...BOARDING, color: "rgb(255,0,0)" }],
    ["relevantDate without offset", { ...BOARDING, relevantDate: "2026-10-01T07:45:00" }],
    ["images are never accepted", { ...BOARDING, images: { strip: "AAAA" } }],
    ["event date garbage", { passType: "eventTicket", barcode: { message: "x", format: "QR" }, fields: { title: "t", date: "tomorrow" } }],
  ];
  it.each(bad)("rejects %s", (_n, v) => {
    const r = parsePassRequest(v);
    expect(r.ok).toBe(false);
  });
  it("does not echo values in issues", () => {
    const r = parsePassRequest({ ...BOARDING, fields: { ...(BOARDING.fields as object), from: "SECRETVALUE" } });
    expect(JSON.stringify(r)).not.toContain("SECRETVALUE");
  });
});

describe("pass.json", () => {
  it("builds a boarding pass that never claims to be the airline", () => {
    const p = buildPassJson(BOARDING, CFG, { serialNumber: "SER-1" }) as any;
    expect(p.formatVersion).toBe(1);
    expect(p.passTypeIdentifier).toBe("pass.com.rvp97.scanner");
    expect(p.teamIdentifier).toBe("TESTTEAM01");
    expect(p.serialNumber).toBe("SER-1");
    expect(p.organizationName).toBe("Ojito");
    expect(p.logoText).toBe("Ojito");
    expect(p.description).toContain("(created with Ojito)");
    expect(JSON.stringify(p)).not.toContain("Lens");
    expect(p.description).toContain("MEX–JFK");
    expect(p.boardingPass.transitType).toBe("PKTransitTypeAir");
    expect(p.boardingPass.primaryFields.map((f: any) => f.value)).toEqual(["MEX", "JFK"]);
    expect(p.barcodes).toEqual([
      { format: "PKBarcodeFormatPDF417", message: BOARDING.barcode.message, messageEncoding: "iso-8859-1" },
    ]);
    expect(p.backgroundColor).toBe("rgb(10, 61, 98)");
    expect(p.semantics).toMatchObject({
      airlineCode: "AM",
      flightCode: "AM401",
      flightNumber: 401,
      departureAirportCode: "MEX",
      destinationAirportCode: "JFK",
      departureGate: "B12",
      boardingGroup: "3",
      seats: [{ seatNumber: "12A" }],
      passengerName: { familyName: "DOE", givenName: "JANE" },
    });
    expect(p.webServiceURL).toBeUndefined();
    expect(p.authenticationToken).toBeUndefined();
    expect(JSON.stringify(p.boardingPass.backFields)).toContain("not issued by");
  });
  it("sets relevantDate only when given, and uses utf-8 for non-Latin-1 messages", () => {
    const p = buildPassJson(
      { passType: "generic", barcode: { message: "世界", format: "QR" }, fields: { title: "x" }, relevantDate: "2026-10-01T07:45:00-06:00" },
      CFG,
      { serialNumber: "s" },
    ) as any;
    expect(p.relevantDate).toBe("2026-10-01T07:45:00-06:00");
    expect(p.barcodes[0].messageEncoding).toBe("utf-8");
    expect(p.generic.primaryFields[0].value).toBe("x");
    const q = buildPassJson(BOARDING, CFG, { serialNumber: "s" }) as any;
    expect(q.relevantDate).toBeUndefined();
  });
});

describe("manifest + signature + zip", () => {
  let signer: PassSigner;
  beforeAll(async () => {
    const f = passCertFixture();
    signer = await loadSigner(f.certPem, f.keyPem, f.wwdrPem);
  });

  it("manifest has the SHA-1 of every file", async () => {
    const files = { "pass.json": new TextEncoder().encode("{}"), ...passImages() };
    const m = JSON.parse(new TextDecoder().decode(await buildManifest(files)));
    expect(Object.keys(m).sort()).toEqual(Object.keys(files).sort());
    for (const [n, data] of Object.entries(files)) {
      expect(m[n]).toBe(createHash("sha1").update(data).digest("hex"));
    }
  });

  it("reads the pass type id from the certificate", () => {
    expect(certPassTypeId(signer.cert)).toBe("pass.com.rvp97.scanner");
  });

  it("produces a detached PKCS#7 that openssl verifies (PKCS#8 and PKCS#1 keys)", async () => {
    const f = passCertFixture();
    const content = new TextEncoder().encode('{"pass.json":"abc"}');
    for (const keyPem of [f.keyPem, f.keyPkcs1Pem]) {
      const s = await loadSigner(f.certPem, keyPem, f.wwdrPem);
      const sig = await signDetached(s, content);
      writeFileSync(join(f.dir, "content.bin"), content);
      writeFileSync(join(f.dir, "signature.der"), sig);
      const out = execFileSync(
        "openssl",
        ["smime", "-verify", "-binary", "-inform", "DER", "-in", join(f.dir, "signature.der"), "-content", join(f.dir, "content.bin"), "-noverify"],
        { stdio: ["ignore", "pipe", "pipe"] },
      );
      expect(out.toString()).toBe(new TextDecoder().decode(content));
      // Full chain check against the throwaway WWDR too.
      execFileSync(
        "openssl",
        ["cms", "-verify", "-binary", "-inform", "DER", "-in", join(f.dir, "signature.der"), "-content", join(f.dir, "content.bin"), "-CAfile", join(f.dir, "test-wwdr.pem"), "-purpose", "any"],
        { stdio: ["ignore", "pipe", "pipe"] },
      );
      // Structure: SHA-256, 2 certs, signingTime present, detached.
      const dump = execFileSync("openssl", ["cms", "-cmsout", "-print", "-inform", "DER", "-in", join(f.dir, "signature.der")]).toString();
      expect(dump).toContain("sha256");
      expect(dump).toContain("signingTime");
      expect(dump).toContain("eContent: <ABSENT>");
      expect(dump.match(/d.certificate:/g)?.length ?? dump.match(/cert_info:/g)?.length).toBe(2);
    }
  });

  it("tampered content fails verification", async () => {
    const f = passCertFixture();
    const sig = await signDetached(signer, new TextEncoder().encode("original"));
    writeFileSync(join(f.dir, "content2.bin"), "tampered");
    writeFileSync(join(f.dir, "signature2.der"), sig);
    expect(() =>
      execFileSync(
        "openssl",
        ["smime", "-verify", "-binary", "-inform", "DER", "-in", join(f.dir, "signature2.der"), "-content", join(f.dir, "content2.bin"), "-noverify"],
        { stdio: "pipe" },
      ),
    ).toThrow();
  });

  it("zips pass.json, images, manifest.json and signature", async () => {
    const { pkpass, serialNumber } = await buildPkpass(BOARDING, CFG, signer);
    const entries = unzipSync(pkpass);
    expect(Object.keys(entries).sort()).toEqual(
      ["icon.png", "icon@2x.png", "icon@3x.png", "logo.png", "logo@2x.png", "logo@3x.png", "manifest.json", "pass.json", "signature"].sort(),
    );
    const pass = JSON.parse(new TextDecoder().decode(entries["pass.json"]));
    expect(pass.serialNumber).toBe(serialNumber);
    expect(serialNumber).toMatch(/^[0-9a-f-]{36}$/);
    const manifest = JSON.parse(new TextDecoder().decode(entries["manifest.json"]));
    for (const n of Object.keys(entries).filter((n) => n !== "manifest.json" && n !== "signature")) {
      expect(manifest[n]).toBe(createHash("sha1").update(entries[n]!).digest("hex"));
    }
    expect(manifest.signature).toBeUndefined();
    expect(manifest["manifest.json"]).toBeUndefined();
    // Signature covers the exact manifest bytes.
    const f = passCertFixture();
    writeFileSync(join(f.dir, "manifest.json"), entries["manifest.json"]!);
    writeFileSync(join(f.dir, "signature"), entries["signature"]!);
    writeFileSync(join(f.dir, "out.pkpass"), pkpass);
    execFileSync("openssl", ["smime", "-verify", "-binary", "-inform", "DER", "-in", join(f.dir, "signature"), "-content", join(f.dir, "manifest.json"), "-noverify"], { stdio: "pipe" });
    // System unzip agrees with fflate.
    expect(execFileSync("unzip", ["-l", join(f.dir, "out.pkpass")]).toString()).toContain("pass.json");
    // PNG sanity: real PNGs of the right pixel size.
    const png = entries["icon@2x.png"]!;
    expect(Array.from(png.slice(1, 4))).toEqual([0x50, 0x4e, 0x47]);
    expect(new DataView(png.buffer, png.byteOffset).getUint32(16)).toBe(58);
  });
});
