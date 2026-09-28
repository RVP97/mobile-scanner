// CPU-cost measurements of the hot paths (process.cpuUsage counts all threads, incl. WebCrypto work).
// Run: npm run bench. Numbers are printed; assertions are deliberately loose (CI noise).
import { describe, expect, it } from "vitest";
import { verifyAssertion, verifyAttestation } from "../src/appattest";
import { loadSigner } from "../src/pkcs7";
import { buildPkpass } from "../src/pkpass";
import { APP_ID, FakeDevice, makePki, passCertFixture } from "./helpers/fixtures";
import { BOARDING } from "./helpers/samples";

async function cpuMs(fn: () => Promise<unknown>, runs = 1): Promise<number> {
  const start = process.cpuUsage();
  for (let i = 0; i < runs; i++) await fn();
  const d = process.cpuUsage(start);
  return (d.user + d.system) / 1000 / runs;
}

const CFG = { passTypeIdentifier: "pass.com.rvp97.scanner", teamIdentifier: "TESTTEAM01" };

describe("cpu", () => {
  it("measures attestation, assertion and pass signing", async () => {
    const pki = await makePki();
    const dev = await FakeDevice.create();
    const challenge = crypto.getRandomValues(new Uint8Array(32));
    const att = await dev.attest(pki, challenge);
    const inp = { keyId: dev.keyId, attestation: att, challenge, appId: APP_ID, env: "development" as const, rootCertDer: pki.rootDer };

    const attestCold = await cpuMs(() => verifyAttestation(inp));
    const attestWarm = await cpuMs(() => verifyAttestation(inp), 20);

    const body = new TextEncoder().encode(JSON.stringify(BOARDING));
    const assertion = await dev.assert(body, { counter: 1 });
    const assertWarm = await cpuMs(
      () => verifyAssertion({ assertion, clientData: body, publicKey: dev.publicRaw, storedCounter: 0, appId: APP_ID }),
      50,
    );

    const f = passCertFixture();
    const signerCold = await cpuMs(() => loadSigner(f.certPem, f.keyPem, f.wwdrPem));
    const signer = await loadSigner(f.certPem, f.keyPem, f.wwdrPem);
    const pkpassFirst = await cpuMs(() => buildPkpass(BOARDING, CFG, signer));
    const pkpassWarm = await cpuMs(() => buildPkpass(BOARDING, CFG, signer), 20);

    const table = {
      "attestation verify (cold, incl. root parse)": attestCold,
      "attestation verify (warm)": attestWarm,
      "assertion verify": assertWarm,
      "signer load (PEM parse + RSA import, once per isolate)": signerCold,
      "pkpass build+sign (first)": pkpassFirst,
      "pkpass build+sign (warm)": pkpassWarm,
    };
    console.table(Object.fromEntries(Object.entries(table).map(([k, v]) => [k, `${v.toFixed(2)} ms`])));
    expect(assertWarm).toBeLessThan(10);
    expect(pkpassWarm).toBeLessThan(50);
  });
});
