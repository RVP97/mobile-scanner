// Detached CMS / PKCS#7 SignedData over manifest.json, as Wallet requires:
// SHA-256 digest, RSASSA-PKCS1-v1_5, signed attributes (contentType, signingTime,
// messageDigest), certificates = [pass certificate, Apple WWDR intermediate].
import * as asn1js from "asn1js";
import * as pkijs from "pkijs";
import { ab, pemBlocks, sha256 } from "./util";

const OID_DATA = "1.2.840.113549.1.7.1";
const OID_SIGNED_DATA = "1.2.840.113549.1.7.2";
const OID_CONTENT_TYPE = "1.2.840.113549.1.9.3";
const OID_MESSAGE_DIGEST = "1.2.840.113549.1.9.4";
const OID_SIGNING_TIME = "1.2.840.113549.1.9.5";
const OID_UID = "0.9.2342.19200300.100.1.1";

export interface PassSigner {
  cert: pkijs.Certificate;
  wwdr: pkijs.Certificate;
  key: CryptoKey;
}

function parseCertPem(pem: string, what: string): pkijs.Certificate {
  const block = pemBlocks(pem).find((b) => b.label === "CERTIFICATE");
  if (!block) throw new Error(`${what}: no CERTIFICATE block`);
  return pkijs.Certificate.fromBER(ab(block.der));
}

/** Wrap a PKCS#1 RSAPrivateKey into PKCS#8 PrivateKeyInfo so WebCrypto can import it. */
function pkcs1ToPkcs8(pkcs1: Uint8Array): Uint8Array {
  const info = new asn1js.Sequence({
    value: [
      new asn1js.Integer({ value: 0 }),
      new asn1js.Sequence({
        value: [new asn1js.ObjectIdentifier({ value: "1.2.840.113549.1.1.1" }), new asn1js.Null()],
      }),
      new asn1js.OctetString({ valueHex: ab(pkcs1) }),
    ],
  });
  return new Uint8Array(info.toBER());
}

export async function loadSigner(certPem: string, keyPem: string, wwdrPem: string): Promise<PassSigner> {
  const cert = parseCertPem(certPem, "PASS_CERT_PEM");
  const wwdr = parseCertPem(wwdrPem, "WWDR_PEM");
  const keyBlock = pemBlocks(keyPem).find((b) => b.label === "PRIVATE KEY" || b.label === "RSA PRIVATE KEY");
  if (!keyBlock) throw new Error("PASS_KEY_PEM: expected an unencrypted PRIVATE KEY or RSA PRIVATE KEY block");
  const pkcs8 = keyBlock.label === "RSA PRIVATE KEY" ? pkcs1ToPkcs8(keyBlock.der) : keyBlock.der;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    ab(pkcs8),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return { cert, wwdr, key };
}

/** The pass type identifier embedded in an Apple pass certificate's subject (UID attribute), if any. */
export function certPassTypeId(cert: pkijs.Certificate): string | undefined {
  const uid = cert.subject.typesAndValues.find((tv) => tv.type === OID_UID);
  return uid ? String(uid.value.valueBlock.value) : undefined;
}

export function certIsCurrentlyValid(cert: pkijs.Certificate, now = new Date()): boolean {
  return cert.notBefore.value <= now && now <= cert.notAfter.value;
}

export async function signDetached(signer: PassSigner, content: Uint8Array, signingTime = new Date()): Promise<Uint8Array> {
  const digest = await sha256(content);
  const signedData = new pkijs.SignedData({
    version: 1,
    encapContentInfo: new pkijs.EncapsulatedContentInfo({ eContentType: OID_DATA }), // detached: no eContent
    signerInfos: [
      new pkijs.SignerInfo({
        version: 1,
        sid: new pkijs.IssuerAndSerialNumber({
          issuer: signer.cert.issuer,
          serialNumber: signer.cert.serialNumber,
        }),
        signedAttrs: new pkijs.SignedAndUnsignedAttributes({
          type: 0,
          attributes: [
            new pkijs.Attribute({ type: OID_CONTENT_TYPE, values: [new asn1js.ObjectIdentifier({ value: OID_DATA })] }),
            new pkijs.Attribute({ type: OID_SIGNING_TIME, values: [new asn1js.UTCTime({ valueDate: signingTime })] }),
            new pkijs.Attribute({ type: OID_MESSAGE_DIGEST, values: [new asn1js.OctetString({ valueHex: ab(digest) })] }),
          ],
        }),
      }),
    ],
    certificates: [signer.cert, signer.wwdr],
  });
  await signedData.sign(signer.key, 0, "SHA-256");
  const contentInfo = new pkijs.ContentInfo({ contentType: OID_SIGNED_DATA, content: signedData.toSchema(true) });
  return new Uint8Array(contentInfo.toSchema().toBER(false));
}
