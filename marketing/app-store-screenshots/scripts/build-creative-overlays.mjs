#!/usr/bin/env node
// Builds the overlay images used by the App Store creative assets (the creative
// decks can only draw an iPhone frame themselves), per locale:
//   public/screenshots/creative/duo-open/<locale>.png           open Duo, landscape, Apple bezel
//   public/screenshots/creative/panels/<name>/<locale>.png      rounded UI crops (if any are defined)
//   public/screenshots/creative/marks/accent.png                red accent swatch
// Transparent outside the art; the editor flattens on export. Specs live in
// scripts/lib/creative-assets.mjs.
//
//   node scripts/build-creative-overlays.mjs
import { existsSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import sharp from "sharp";
import { ROOT, readProject } from "./lib/headless-editor.mjs";

import { DUOS } from "./lib/creative-assets.mjs";
// Shadow, in bezel pixels.
export const PAD = 260; // > 3 x blur sigma + offset, so the shadow never meets the edge
const SHADOW_BLUR = 40;
const SHADOW_DY = 40;
const SHADOW_OPACITY = 0.22;

const project = readProject();
// Start clean so renamed or removed overlays don't linger.
rmSync(path.join(ROOT, "public/screenshots/creative"), { recursive: true, force: true });

async function buildDuo(name, spec) {
  const BEZEL = path.join(ROOT, "public/frames", spec.bezel);
  const bezel = sharp(BEZEL);
  const { width: W, height: H } = await bezel.metadata();
  const alpha = await bezel.clone().extractChannel(3).raw().toBuffer();
  const a = (x, y) => alpha[y * W + x];
  // Walk out from the centre along the middle row and column to the opaque bezel.
  const cx = Math.floor(W / 2);
  const cy = Math.floor(H / 2);
  if (a(cx, cy) !== 0) throw new Error(`${spec.bezel}: centre is not transparent`);
  let left = cx, right = cx, top = cy, bottom = cy;
  while (left > 0 && a(left - 1, cy) === 0) left--;
  while (right < W - 1 && a(right + 1, cy) === 0) right++;
  while (top > 0 && a(cx, top - 1) === 0) top--;
  while (bottom < H - 1 && a(cx, bottom + 1) === 0) bottom++;
  const cut = { left, top, width: right - left + 1, height: bottom - top + 1 };
  let built = 0;
  for (const locale of project.locales) {
    const src = path.join(ROOT, "public/screenshots/apple", spec.src.replace("{locale}", locale));
    if (!existsSync(src)) {
      console.warn(`skip ${name} ${locale}: no ${spec.src.replace("{locale}", locale)} (run import-captures first)`);
      continue;
    }
    const capture = await sharp(src).resize(cut.width, cut.height, { fit: "fill" }).png().toBuffer();
    // A soft drop shadow like the scene gives the iPhone. PAD is added on every side.
    const shadowAlpha = await sharp(alpha, { raw: { width: W, height: H, channels: 1 } })
      .extend({ top: PAD, bottom: PAD, left: PAD, right: PAD, background: "#000000" })
      .linear(SHADOW_OPACITY, 0)
      .blur(SHADOW_BLUR)
      // extend() with a colour background turns the mask into RGB; keep one channel.
      .extractChannel(0)
      .raw()
      .toBuffer();
    const shadow = await sharp({ create: { width: W + PAD * 2, height: H + PAD * 2, channels: 3, background: "#000000" } })
      .joinChannel(shadowAlpha, { raw: { width: W + PAD * 2, height: H + PAD * 2, channels: 1 } })
      .png()
      .toBuffer();
    const png = await sharp({ create: { width: W + PAD * 2, height: H + PAD * 2, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
      .composite([
        { input: shadow, left: 0, top: SHADOW_DY },
        { input: capture, left: PAD + cut.left, top: PAD + cut.top },
        { input: BEZEL, left: PAD, top: PAD },
      ])
      .png({ compressionLevel: 9 })
      .toBuffer();
    const out = path.join(ROOT, `public/screenshots/creative/${name}/${locale}.png`);
    mkdirSync(path.dirname(out), { recursive: true });
    writeFileSync(out, png);
    built += 1;
  }
  console.log(`${name} overlays: ${built} written (bezel ${W}x${H}, screen cutout ${cut.width}x${cut.height} at ${cut.left},${cut.top})`);
}

for (const [name, spec] of Object.entries(DUOS)) await buildDuo(name, spec);

// ---------- UI panels (concept 3): rounded crops of real captures ----------
// Crop rects live in scripts/lib/creative-assets.mjs.
import { PANELS, PANEL_PAD } from "./lib/creative-assets.mjs";
const PANEL_RADIUS = 56;
const PANEL_BLUR = 50;
const PANEL_DY = 36;
const PANEL_OPACITY = 0.16;

async function buildPanel(name, locale) {
  const spec = PANELS[name];
  const file = path.join(ROOT, "public/screenshots/apple", spec.src.replace("{locale}", locale));
  if (!existsSync(file)) return false;
  const { width: w, height: h } = spec.crop;
  const P = PANEL_PAD;
  const roundRect = (fill, stroke = "") =>
    Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><rect x="1" y="1" width="${w - 2}" height="${h - 2}" rx="${PANEL_RADIUS}" ry="${PANEL_RADIUS}" fill="${fill}" ${stroke}/></svg>`);
  const ui = await sharp(file).extract(spec.crop).removeAlpha().png().toBuffer();
  // Rounded UI: the crop masked by a rounded rect, plus a hairline edge.
  const rounded = await sharp(ui)
    .composite([
      { input: roundRect("#fff"), blend: "dest-in" },
      { input: roundRect("none", 'stroke="#DCD3C6" stroke-width="3"') },
    ])
    .png()
    .toBuffer();
  const maskAlpha = await sharp(roundRect("#fff")).extractChannel(3).raw().toBuffer();
  const shadowAlpha = await sharp(maskAlpha, { raw: { width: w, height: h, channels: 1 } })
    .extend({ top: P, bottom: P, left: P, right: P, background: "#000000" })
    .linear(PANEL_OPACITY, 0)
    .blur(PANEL_BLUR)
    .extractChannel(0)
    .raw()
    .toBuffer();
  const shadow = await sharp({ create: { width: w + 2 * P, height: h + 2 * P, channels: 3, background: "#2A2018" } })
    .joinChannel(shadowAlpha, { raw: { width: w + 2 * P, height: h + 2 * P, channels: 1 } })
    .png()
    .toBuffer();
  const out = await sharp({ create: { width: w + 2 * P, height: h + 2 * P, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
    .composite([{ input: shadow, left: 0, top: PANEL_DY }, { input: rounded, left: P, top: P }])
    .png({ compressionLevel: 9 })
    .toBuffer();
  const dest = path.join(ROOT, `public/screenshots/creative/panels/${name}/${locale}.png`);
  mkdirSync(path.dirname(dest), { recursive: true });
  writeFileSync(dest, out);
  return true;
}

let panels = 0;
for (const locale of project.locales) for (const name of Object.keys(PANELS)) if (await buildPanel(name, locale)) panels += 1;

// Solid accent swatch for rules (stretched by the editor with fit: cover).
const accent = "#B23A33"; // tutnext-washi accent
mkdirSync(path.join(ROOT, "public/screenshots/creative/marks"), { recursive: true });
writeFileSync(
  path.join(ROOT, "public/screenshots/creative/marks/accent.png"),
  await sharp({ create: { width: 16, height: 16, channels: 3, background: accent } }).png().toBuffer(),
);
console.log(`ui panels: ${panels} written; accent swatch ${accent}`);
