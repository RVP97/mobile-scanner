// Assembles a signed .pkpass: pass.json + images + manifest.json (SHA-1 per file) + detached signature, zipped.
import { zipSync, type Zippable } from "fflate";
import { PASS_IMAGES_BASE64 } from "./assets.generated";
import { buildPassJson, type PassConfig } from "./passjson";
import { signDetached, type PassSigner } from "./pkcs7";
import type { PassRequest } from "./schema";
import { fromBase64, sha1Hex, te } from "./util";

export const PKPASS_MIME = "application/vnd.apple.pkpass";

let images: Record<string, Uint8Array> | undefined;
export function passImages(): Record<string, Uint8Array> {
  if (!images) {
    images = {};
    for (const [name, b64] of Object.entries(PASS_IMAGES_BASE64)) images[name] = fromBase64(b64)!;
  }
  return images;
}

export async function buildManifest(files: Record<string, Uint8Array>): Promise<Uint8Array> {
  const manifest: Record<string, string> = {};
  for (const name of Object.keys(files).sort()) manifest[name] = await sha1Hex(files[name]!);
  return te.encode(JSON.stringify(manifest));
}

export interface BuiltPass {
  pkpass: Uint8Array;
  serialNumber: string;
}

export async function buildPkpass(
  req: PassRequest,
  cfg: PassConfig,
  signer: PassSigner,
  opts: { serialNumber?: string; now?: Date } = {},
): Promise<BuiltPass> {
  const serialNumber = opts.serialNumber ?? crypto.randomUUID();
  const passJson = te.encode(JSON.stringify(buildPassJson(req, cfg, { serialNumber })));
  const files: Record<string, Uint8Array> = { "pass.json": passJson, ...passImages() };
  const manifest = await buildManifest(files);
  const signature = await signDetached(signer, manifest, opts.now);

  const zip: Zippable = {};
  for (const [name, data] of Object.entries(files)) {
    // PNGs are already deflated; storing them saves CPU for no size cost.
    zip[name] = name.endsWith(".png") ? [data, { level: 0 }] : [data, { level: 6 }];
  }
  zip["manifest.json"] = [manifest, { level: 6 }];
  zip["signature"] = [signature, { level: 0 }];
  return { pkpass: zipSync(zip, { mtime: opts.now ?? new Date() }), serialNumber };
}
