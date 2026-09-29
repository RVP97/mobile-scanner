#!/usr/bin/env node
// Composes the App Store screenshots from the raw captures in raw/<device>/<lang>/.
//
//   node render.mjs [locale ...] [--device iphone|ipad] [--only hero,safety]
//
// Each scene is an HTML page rendered by headless Chrome at the exact App Store size:
// iPhone 6.9" 1320×2868 and iPad 13" 2064×2752. Copy comes from strings.json.
// Output: ../screenshots/<locale>/<NN>_<device>_<scene>.png

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "..", "screenshots");
const TMP = join(HERE, ".build");
const CHROME = process.env.CHROME || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const STRINGS = JSON.parse(readFileSync(join(HERE, "strings.json"), "utf8"));

// MARK: Brand

const INK = "#0B0C10";
const ACCENT = "#0071A4";
const ACCENT_DARK = "#64D2FF";
const KIND = { link: "#0A9BD1", wifi: "#248A3D", product: "#E8890C", contact: "#8E2BC4", travel: "#C8175D" };
const DANGER = "#FF453A";

// MARK: Devices

/** Geometry in output pixels. `screen` is the raw capture size. */
const DEVICES = {
  iphone: {
    label: "iPhone69",
    W: 1320, H: 2868,
    screen: [1320, 2868],
    text: { top: 210, title: 132, sub: 50, subGap: 30, width: 1140 },
    device: { top: 740, width: 1040, bezel: 20, radius: 0.141, kind: "phone" },
    panelWidth: 880, panelInset: 100, panelGap: 26,
  },
  ipad: {
    label: "iPadPro13",
    W: 2064, H: 2752,
    screen: [2064, 2752],
    text: { top: 190, title: 140, sub: 56, subGap: 30, width: 1700 },
    device: { top: 724, width: 1500, bezel: 46, radius: 0.026, kind: "pad" },
    panelWidth: 1250, panelInset: 230, panelGap: 32,
  },
};

/** Regions of a raw capture used as floating panels: [x, y, w, h] in capture pixels. */
const PANELS = {
  iphone: {
    wifi: [0, 222, 1320, 780],
    travel: [0, 440, 1320, 1015],
    contact: [0, 222, 1320, 1188],
  },
  ipad: {
    wifi: [360, 112, 1345, 528],
    travel: [360, 250, 1345, 700],
    contact: [360, 112, 1345, 803],
  },
};

// MARK: Scenes (in store order)

const SCENES = [
  { id: "hero", raw: "home", theme: "dark", highlight: ACCENT_DARK, brand: true,
    glows: [[ACCENT_DARK, 0.30, "50% 40%"], [KIND.travel, 0.16, "18% 70%"], [KIND.wifi, 0.14, "85% 72%"]] },
  { id: "safety", raw: "danger", theme: "dark", highlight: "#FF6961", scale: 1.1,
    glows: [[DANGER, 0.34, "50% 45%"]] },
  { id: "answers", layout: "panels", theme: "light", field: "#ECEEF3", highlight: ACCENT,
    panels: ["wifi", "travel", "contact"], tints: [KIND.wifi, KIND.travel, KIND.contact] },
  { id: "show", raw: "show", theme: "light", field: "#E4F0E7", highlight: KIND.wifi,
    glows: [[KIND.wifi, 0.16, "50% 60%"]] },
  { id: "studio", raw: "studio", theme: "light", field: "#E1ECF0", highlight: "#0B5A6F",
    glows: [["#0B5A6F", 0.16, "50% 60%"]] },
  { id: "everywhere", raw: "everywhere", theme: "light", field: "#E3EBF4", highlight: ACCENT,
    glows: [[ACCENT, 0.14, "50% 60%"]], stringsKey: { ipad: "everywhere_ipad" } },
  { id: "history", raw: "history", theme: "light", field: "#ECECF1", highlight: ACCENT,
    glows: [[ACCENT, 0.10, "50% 60%"]] },
  { id: "privacy", raw: "privacy", theme: "dark", highlight: ACCENT_DARK,
    glows: [[ACCENT_DARK, 0.24, "50% 48%"]] },
];

// MARK: HTML

const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const headline = (s) => esc(s).replace(/\*(.+?)\*/g, "<em>$1</em>").replace(/\n/g, "<br>");
const hexA = (hex, a) => {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${n >> 16}, ${(n >> 8) & 255}, ${n & 255}, ${a})`;
};

function background(scene) {
  if (scene.theme === "dark") {
    const glows = (scene.glows || [])
      .map(([c, a, at]) => `radial-gradient(ellipse 70% 42% at ${at}, ${hexA(c, a)}, transparent 70%)`)
      .join(", ");
    return `${glows}${glows ? ", " : ""}linear-gradient(#0A0C11, #05060A)`;
  }
  // A quiet tinted field: a little lighter at the top where the words sit, a breath of the
  // scene's color behind the device.
  const glows = (scene.glows || [])
    .map(([c, a, at]) => `radial-gradient(ellipse 75% 38% at ${at}, ${hexA(c, a)}, transparent 72%), `)
    .join("");
  return `radial-gradient(ellipse 90% 40% at 50% 0%, rgba(255,255,255,0.75), transparent 70%), ${glows}${scene.field}`;
}

function deviceHTML(d, dev, img, scene) {
  const g = dev.device;
  const width = Math.round(g.width * (scene.scale || 1));
  const sw = width - 2 * g.bezel;
  const sh = Math.round(sw * dev.screen[1] / dev.screen[0]);
  const rs = Math.round(sw * g.radius);
  const left = Math.round((dev.W - width) / 2);
  const dark = scene.theme === "dark";
  const rim = dark ? "#4A4B50" : "#3C3D42";
  const hairline = dark ? "rgba(255,255,255,0.28)" : "rgba(255,255,255,0.55)";
  const shadow = dark
    ? `0 0 0 5px ${rim}, 0 0 0 6.5px ${hairline}, 0 60px 140px -30px rgba(0,0,0,0.8)`
    : `0 0 0 5px ${rim}, 0 0 0 6.5px ${hairline}, 0 90px 160px -50px rgba(18,28,48,0.45), 0 30px 60px -30px rgba(18,28,48,0.35)`;
  const H = sh + 2 * g.bezel;
  const buttons = g.kind === "phone"
    ? [["l", 0.180, 0.034], ["l", 0.240, 0.060], ["l", 0.315, 0.060], ["r", 0.265, 0.095], ["r", 0.555, 0.060]]
    : [["t", 0.80, 0.07], ["r", 0.090, 0.040], ["r", 0.140, 0.040]];
  const btn = buttons.map(([side, at, len]) => {
    const t = 11;
    if (side === "t") {
      return `<i style="left:${Math.round(at * width)}px;top:${-t}px;width:${Math.round(len * width)}px;height:${t + 4}px"></i>`;
    }
    const x = side === "l" ? `left:${-t}px` : `right:${-t}px`;
    return `<i style="${x};top:${Math.round(at * H)}px;height:${Math.round(len * H)}px;width:${t + 4}px"></i>`;
  }).join("");
  return `
  <div class="device" style="left:${left}px;top:${dev.device.top}px;width:${width}px;height:${H}px;
       border-radius:${rs + g.bezel}px;padding:${g.bezel}px;box-shadow:${shadow}">
    <div class="buttons">${btn}</div>
    <div class="screen" style="width:${sw}px;height:${sh}px;border-radius:${rs}px;background-image:url('${img}')"></div>
  </div>`;
}

function panelsHTML(d, dev, rawDir, scene) {
  const regions = PANELS[d];
  let y = dev.device.top;
  return scene.panels.map((name, i) => {
    const [x0, y0, w0, h0] = regions[name];
    const k = dev.panelWidth / w0; // the region fills the panel width
    const w = dev.panelWidth, h = Math.round(h0 * k);
    const left = i % 2 === 0 ? dev.panelInset : dev.W - dev.panelInset - w;
    const top = y;
    y += h + dev.panelGap;
    const img = pathToFileURL(join(rawDir, `${name}.png`)).href;
    const sizeW = Math.round(DEVICES[d].screen[0] * k), sizeH = Math.round(DEVICES[d].screen[1] * k);
    const radius = Math.round(38 * (w / 924));
    return `<div class="panel" style="left:${left}px;top:${top}px;width:${w}px;height:${h}px;border-radius:${radius}px;
      background-image:url('${img}');background-size:${sizeW}px ${sizeH}px;
      background-position:${-Math.round(x0 * k)}px ${-Math.round(y0 * k)}px;
      box-shadow:0 0 0 1px rgba(0,0,0,0.04), 0 50px 90px -30px ${hexA(scene.tints[i], 0.45)}, 0 20px 40px -20px rgba(18,28,48,0.3)"></div>`;
  }).join("");
}

function page(d, locale, scene) {
  const dev = DEVICES[d];
  const strings = STRINGS[locale];
  const key = scene.stringsKey?.[d] || scene.id;
  const copy = strings[key];
  const rawDir = join(HERE, "raw", d, strings.app);
  const dark = scene.theme === "dark";
  const t = dev.text;
  const icon = pathToFileURL(join(HERE, "assets", "Loupe-Dark.png")).href;
  const body = scene.layout === "panels"
    ? panelsHTML(d, dev, rawDir, scene)
    : deviceHTML(d, dev, pathToFileURL(join(rawDir, `${scene.raw}.png`)).href, scene);
  const brand = scene.brand ? `
    <div class="brand"><img src="${icon}"><span>Lunet</span></div>` : "";
  return `<!doctype html><html lang="${strings.app}"><head><meta charset="utf-8"><style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: ${dev.W}px; height: ${dev.H}px; overflow: hidden; }
  body { position: relative; background: ${background(scene)};
    font-family: -apple-system, "SF Pro Display", system-ui, sans-serif;
    -webkit-font-smoothing: antialiased; color: ${dark ? "#FFFFFF" : INK}; }
  .copy { position: absolute; left: 0; right: 0; top: ${t.top}px; text-align: center; }
  h1 { font-size: ${t.title}px; line-height: 1.04; font-weight: 700; letter-spacing: -0.03em;
    display: inline-block; white-space: nowrap; }
  h1 em { font-style: normal; color: ${scene.highlight}; }
  p { font-size: ${t.sub}px; line-height: 1.28; font-weight: 500; letter-spacing: -0.012em;
    margin: ${t.subGap}px auto 0; max-width: ${Math.round(t.width * 0.84)}px; text-wrap: balance;
    color: ${dark ? "rgba(255,255,255,0.62)" : "rgba(11,12,16,0.56)"}; }
  .brand { position: absolute; left: 0; right: 0; top: ${Math.round(t.top * 0.36)}px; display: flex;
    align-items: center; justify-content: center; gap: ${Math.round(t.title * 0.14)}px; }
  .brand img { width: ${Math.round(t.title * 0.62)}px; height: ${Math.round(t.title * 0.62)}px; }
  .brand span { font-size: ${Math.round(t.title * 0.40)}px; font-weight: 600; letter-spacing: -0.02em; opacity: 0.92; }
  .device { position: absolute; background: #09090B; }
  .buttons i { position: absolute; background: ${dark ? "#3E3F44" : "#35363B"}; border-radius: 6px; z-index: -1; }
  .screen { background-size: cover; background-position: center top; overflow: hidden; }
  .panel { position: absolute; background-repeat: no-repeat; background-color: #fff; }
  </style></head><body>
  ${brand}
  <div class="copy"><h1>${headline(copy.title)}</h1>${copy.sub ? `<p>${esc(copy.sub)}</p>` : ""}</div>
  ${body}
  <script>
    // Line breaks are explicit, so a line that's too long shrinks the headline instead of wrapping.
    const h1 = document.querySelector("h1");
    let size = ${t.title};
    while (h1.offsetWidth > ${t.width} && size > ${Math.round(t.title * 0.7)}) { size -= 2; h1.style.fontSize = size + "px"; }
  </script>
  </body></html>`;
}

// MARK: Render

function render(d, locale, scene, index) {
  const dev = DEVICES[d];
  const html = page(d, locale, scene);
  mkdirSync(TMP, { recursive: true });
  const file = join(TMP, `${locale}-${d}-${scene.id}.html`);
  writeFileSync(file, html);
  const dir = join(OUT, locale);
  mkdirSync(dir, { recursive: true });
  const out = join(dir, `${String(index + 1).padStart(2, "0")}_${dev.label}_${scene.id}.png`);
  execFileSync(CHROME, [
    "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
    "--allow-file-access-from-files", "--default-background-color=00000000",
    `--window-size=${dev.W},${dev.H}`, `--screenshot=${out}`, pathToFileURL(file).href,
  ], { stdio: "ignore" });
  console.log(out);
}

const args = process.argv.slice(2);
const flag = (name) => { const i = args.indexOf(name); return i >= 0 ? args.splice(i, 2)[1] : null; };
const onlyDevice = flag("--device");
const only = flag("--only")?.split(",");
const locales = args.length ? args : Object.keys(STRINGS).filter((k) => !k.startsWith("_"));

for (const locale of locales) {
  if (!STRINGS[locale]) throw new Error(`No strings for ${locale} in strings.json`);
  for (const d of Object.keys(DEVICES)) {
    if (onlyDevice && d !== onlyDevice) continue;
    const rawDir = join(HERE, "raw", d, STRINGS[locale].app);
    if (!existsSync(rawDir)) { console.warn(`skip ${locale} ${d}: no captures in ${rawDir}`); continue; }
    SCENES.forEach((scene, i) => { if (!only || only.includes(scene.id)) render(d, locale, scene, i); });
  }
}
