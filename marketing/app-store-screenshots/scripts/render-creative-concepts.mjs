#!/usr/bin/env node
// Presentation boards for the App Store creative-asset concepts.
//
//   node scripts/render-creative-concepts.mjs [--locales ja] [--out exports/latest/creative-concepts]
//
// Exports the creative-header and creative-search decks (one slide per concept,
// see scripts/lib/creative-layout.mjs) through the editor, then writes per locale:
//   <out>/<locale>/variant-<key>.png     header + search, each full and safe-area-only
//   <out>/<locale>/overview.png          all variants together
// plus the raw renders in <out>/<locale>/renders/.
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { readFile } from "node:fs/promises";
import path from "node:path";
import JSZip from "jszip";
import sharp from "sharp";
import { CANVAS, CONCEPTS, DECK, SAFE } from "./lib/creative-layout.mjs";
import { ROOT, ensureServer, exportBundle, launchBrowser, readProject, stateForDevice } from "./lib/headless-editor.mjs";

const args = process.argv.slice(2);
const option = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};
const locales = (option("--locales") || "ja").split(",");
const OUT = path.resolve(ROOT, option("--out") || "exports/latest/creative-concepts");
const TMP = path.join(ROOT, "exports", ".concepts-tmp");
const project = readProject();

// ---------- board styling ----------
const PAPER = "#F4F1EA";
const INK = "#1E1B18";
const MUTED = "#6B645B";
const ACCENT = "#B23A33";
const SERIF = "Baskerville, 'Hiragino Mincho ProN', Georgia, serif";
const SANS = "'Helvetica Neue', Helvetica, Arial, sans-serif";
const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function svgText(w, h, body) {
  return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}">${body}</svg>`);
}

// An image placed on the board: resized, thin border, soft shadow.
async function framed(buffer, width) {
  const meta = await sharp(buffer).metadata();
  const height = Math.round((meta.height / meta.width) * width);
  const img = await sharp(buffer).resize(width, height).png().toBuffer();
  // Soft, wide drop shadow (a tight one reads as a grey bar under the image).
  const pad = 140;
  const shadow = await sharp({ create: { width: width + pad * 2, height: height + pad * 2, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
    .composite([{ input: svgText(width + pad * 2, height + pad * 2, `<rect x="${pad + 10}" y="${pad + 24}" width="${width - 20}" height="${height - 20}" fill="rgba(40,30,20,0.10)"/>`) }])
    .blur(40)
    .png()
    .toBuffer();
  const border = svgText(width, height, `<rect x="1" y="1" width="${width - 2}" height="${height - 2}" fill="none" stroke="#D6CDBF" stroke-width="2"/>`);
  const withBorder = await sharp(img).composite([{ input: border }]).png().toBuffer();
  return { width, height, layers: (x, y) => [{ input: shadow, left: x - pad, top: y - pad }, { input: withBorder, left: x, top: y }] };
}

function caption(x, y, title, detail) {
  return `<text x="${x}" y="${y}" font-family="${SANS}" font-size="34" font-weight="600" fill="${INK}">${esc(title)}</text>
    <text x="${x}" y="${y + 46}" font-family="${SANS}" font-size="28" fill="${MUTED}">${esc(detail)}</text>`;
}

async function conceptBoard(index, concept, renders, locale) {
  const PAD = 170, GAP = 120, BIG = 2600, SMALL = 1120, CAP = 120;
  const header = await framed(renders.header.full, BIG);
  const headerSafe = await framed(renders.header.safe, SMALL);
  const search = await framed(renders.search.full, BIG);
  const searchSafe = await framed(renders.search.safe, SMALL);
  const W = PAD * 2 + BIG + GAP + SMALL;
  const titleH = 470;
  const rowA = PAD + titleH;
  const rowB = rowA + CAP + header.height + GAP + 40;
  const H = rowB + CAP + search.height + PAD;
  const sx = PAD + BIG + GAP;
  let text = `
    <rect x="${PAD}" y="${PAD}" width="140" height="8" fill="${ACCENT}"/>
    <text x="${PAD}" y="${PAD + 74}" font-family="${SANS}" font-size="30" font-weight="600" letter-spacing="4" fill="${ACCENT}">TUTNEXT · APP STORE CREATIVE · PRODUCT LINEUP · VARIANT ${String.fromCharCode(65 + index)}</text>
    <text x="${PAD}" y="${PAD + 200}" font-family="${SERIF}" font-size="118" font-weight="600" fill="${INK}">${esc(concept.name)}</text>
    <text x="${PAD}" y="${PAD + 280}" font-family="${SANS}" font-size="36" fill="${MUTED}">${esc(concept.blurb)}</text>
    <text x="${W - PAD}" y="${PAD + 74}" text-anchor="end" font-family="${SANS}" font-size="28" fill="${MUTED}">Locale: ${esc(locale)} · Quiet Washi</text>`;
  text += caption(PAD, rowA + 40, "Product page header", "3840 × 1646 · 21:9 · full asset");
  text += caption(sx, rowA + 40, "Smallest crop", `Safe area only · ${SAFE.header.w} × ${SAFE.header.h}`);
  text += caption(PAD, rowB + 40, "Search results", "3840 × 2560 · 3:2 · full asset");
  text += caption(sx, rowB + 40, "Smallest crop", `Safe area only · ${SAFE.search.w} × ${SAFE.search.h}`);
  const layers = [
    { input: svgText(W, H, text), left: 0, top: 0 },
    ...header.layers(PAD, rowA + CAP),
    ...headerSafe.layers(sx, rowA + CAP),
    ...search.layers(PAD, rowB + CAP),
    ...searchSafe.layers(sx, rowB + CAP),
  ];
  return sharp({ create: { width: W, height: H, channels: 3, background: PAPER } }).composite(layers).png().toBuffer();
}

async function overviewBoard(all, locale) {
  const PAD = 170, GAP = 100, TEXT = 860, HW = 1900, SW = 1240;
  const rows = [];
  for (const { concept, renders } of all) {
    rows.push({ concept, header: await framed(renders.header.full, HW), search: await framed(renders.search.full, SW) });
  }
  const rowH = Math.max(...rows.map((r) => Math.max(r.header.height, r.search.height)));
  const W = PAD * 2 + TEXT + GAP + HW + GAP + SW;
  const top = PAD + 360;
  const H = top + rows.length * (rowH + GAP * 1.6) + PAD;
  let text = `
    <rect x="${PAD}" y="${PAD}" width="140" height="8" fill="${ACCENT}"/>
    <text x="${PAD}" y="${PAD + 74}" font-family="${SANS}" font-size="30" font-weight="600" letter-spacing="4" fill="${ACCENT}">TUTNEXT · APP STORE CREATIVE</text>
    <text x="${PAD}" y="${PAD + 200}" font-family="${SERIF}" font-size="118" font-weight="600" fill="${INK}">Product lineup · two variants</text>
    <text x="${PAD + TEXT + GAP}" y="${top - 30}" font-family="${SANS}" font-size="30" fill="${MUTED}">Product page header · 3840 × 1646</text>
    <text x="${PAD + TEXT + GAP + HW + GAP}" y="${top - 30}" font-family="${SANS}" font-size="30" fill="${MUTED}">Search results · 3840 × 2560</text>
    <text x="${W - PAD}" y="${PAD + 74}" text-anchor="end" font-family="${SANS}" font-size="28" fill="${MUTED}">Locale: ${esc(locale)} · Quiet Washi</text>`;
  const layers = [];
  rows.forEach((row, i) => {
    const y = top + i * (rowH + GAP * 1.6);
    text += `<text x="${PAD}" y="${y + 60}" font-family="${SERIF}" font-size="140" font-weight="600" fill="${ACCENT}">${String.fromCharCode(65 + i)}</text>
      <text x="${PAD}" y="${y + 170}" font-family="${SERIF}" font-size="64" font-weight="600" fill="${INK}">${esc(row.concept.name)}</text>`;
    // Wrap the blurb to the text column.
    const words = row.concept.blurb.split(" ");
    let line = "", ly = y + 250;
    for (const word of words) {
      if ((line + " " + word).trim().length > 44) {
        text += `<text x="${PAD}" y="${ly}" font-family="${SANS}" font-size="32" fill="${MUTED}">${esc(line.trim())}</text>`;
        ly += 46; line = word;
      } else line += " " + word;
    }
    if (line.trim()) text += `<text x="${PAD}" y="${ly}" font-family="${SANS}" font-size="32" fill="${MUTED}">${esc(line.trim())}</text>`;
    layers.push(...row.header.layers(PAD + TEXT + GAP, y), ...row.search.layers(PAD + TEXT + GAP + HW + GAP, y));
  });
  layers.unshift({ input: svgText(W, H, text), left: 0, top: 0 });
  return sharp({ create: { width: W, height: Math.round(H), channels: 3, background: PAPER } }).composite(layers).png().toBuffer();
}

// ---------- export ----------
mkdirSync(TMP, { recursive: true });
const server = await ensureServer(option("--url"));
const browser = await launchBrowser({ headed: args.includes("--headed") });
const zips = {};
try {
  for (const format of ["header", "search"]) {
    const device = DECK[format];
    const zipPath = path.join(TMP, `${device}.zip`);
    console.log(`${device}: exporting (${locales.join(", ")})…`);
    await exportBundle({ browser, url: server.url, state: stateForDevice(project, device, locales), zipPath });
    zips[format] = await JSZip.loadAsync(await readFile(zipPath));
  }
} finally {
  await browser.close();
  await server.stop();
}

for (const locale of locales) {
  const dir = path.join(OUT, locale);
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(path.join(dir, "renders"), { recursive: true });
  const all = [];
  for (const [index, concept] of CONCEPTS.entries()) {
    const renders = {};
    for (const format of ["header", "search"]) {
      const { w, h } = CANVAS[format];
      const device = DECK[format];
      const slideIndex = project.slidesByDevice[device].findIndex((s) => s.id.endsWith(concept.key));
      if (slideIndex < 0) throw new Error(`${device} has no slide for ${concept.key}; run node scripts/lib/seed-creatives.mjs`);
      const prefix = `ios/${device}/${w}x${h}/${locale}/${String(slideIndex + 1).padStart(2, "0")}-`;
      const name = Object.keys(zips[format].files).find((f) => f.startsWith(prefix));
      const full = await zips[format].files[name].async("nodebuffer");
      const meta = await sharp(full).metadata();
      if (meta.width !== w || meta.height !== h || meta.hasAlpha) throw new Error(`${name}: ${meta.width}x${meta.height} alpha=${meta.hasAlpha}`);
      const s = SAFE[format];
      const safe = await sharp(full).extract({ left: s.x, top: s.y, width: s.w, height: s.h }).png().toBuffer();
      writeFileSync(path.join(dir, "renders", `${format}-${w}x${h}-${concept.key}.png`), full);
      writeFileSync(path.join(dir, "renders", `${format}-${w}x${h}-${concept.key}-safe-crop.png`), safe);
      renders[format] = { full, safe };
    }
    const board = await conceptBoard(index, concept, renders, locale);
    const file = path.join(dir, `variant-${concept.key}.png`);
    writeFileSync(file, board);
    console.log(`  -> ${path.relative(ROOT, file)}`);
    all.push({ concept, renders });
  }
  const overview = path.join(dir, "overview.png");
  writeFileSync(overview, await overviewBoard(all, locale));
  console.log(`  -> ${path.relative(ROOT, overview)}`);
}
rmSync(TMP, { recursive: true, force: true });
