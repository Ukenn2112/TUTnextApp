#!/usr/bin/env node
// Copies raw simulator captures into the editor's public/screenshots/apple/... layout.
//
//   node scripts/import-captures.mjs [--src ../captures] [--dry-run] [--placeholders] [--force-placeholders]
//
// Source layout (written by the capture step):
//   <src>/iphone/<locale>/NN.png
//   <src>/duo-inner/landscape/<locale>/NN.png
//   <src>/duo-outer/portrait/<locale>/NN.png
//   <src>/duo-inner/portrait/<locale>/NN.png
//
// Destination: public/screenshots/apple/<same relative path>. The set of files that
// must exist is read from app-store-screenshots.json (every slide's `screenshot`
// and `screenshotSecondary` path, for every project locale), so the script reports
// exactly which slots are still missing. Each capture's pixel size is checked
// against the App Store size for its display.
//
// --placeholders        write a labelled "capture pending" PNG into every slot that
//                       still has no file, so the editor and export never break.
// --force-placeholders  same, but also overwrite slots that already have a file.
// --prune               delete PNGs under public/screenshots/apple that no slide
//                       references (old placeholders, renumbered captures).
// --strict              exit with an error when a capture is missing or the wrong size.
// --raw                 copy captures byte for byte. By default a capture whose
//                       alpha channel is fully opaque is re-encoded losslessly as
//                       RGB PNG (same pixels, ~70% smaller, no alpha for the store).
import { existsSync, mkdirSync, readdirSync, readFileSync, copyFileSync, writeFileSync, rmSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const option = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};

const SRC = path.resolve(ROOT, option("--src", "../captures"));
const DEST = path.join(ROOT, "public", "screenshots", "apple");
const DRY = flag("--dry-run");
const FORCE_PLACEHOLDERS = flag("--force-placeholders");
const PLACEHOLDERS = FORCE_PLACEHOLDERS || flag("--placeholders");
const PRUNE = flag("--prune");
const RAW = flag("--raw");

// Lossless: only drops the alpha channel when every pixel is already opaque.
async function writeCapture(src, dest) {
  if (!RAW) {
    const image = sharp(src);
    const meta = await image.metadata();
    const opaque = !meta.hasAlpha || (await image.stats()).channels[3]?.min === 255;
    if (opaque) {
      writeFileSync(dest, await sharp(src).removeAlpha().png({ compressionLevel: 9, adaptiveFiltering: true }).toBuffer());
      return "rgb";
    }
  }
  copyFileSync(src, dest);
  return "raw";
}

// Exact App Store Connect pixel sizes per capture folder.
const SIZES = {
  iphone: [1320, 2868],
  "duo-inner/landscape": [2853, 2007],
  "duo-outer/portrait": [1398, 2034],
  "duo-inner/portrait": [2007, 2853],
};

// Folder-name aliases a capture tool might use for the project's locales.
const LOCALE_ALIASES = {
  ja: ["ja", "ja-JP", "ja_JP"],
  en: ["en", "en-US", "en_US", "en-GB"],
  "zh-Hans": ["zh-Hans", "zh_Hans", "zh-CN", "zh_CN", "zh"],
  ko: ["ko", "ko-KR", "ko_KR"],
};

const project = JSON.parse(readFileSync(path.join(ROOT, "app-store-screenshots.json"), "utf8"));
const locales = project.locales || ["en"];

// Every file the decks reference, e.g. "duo-inner/landscape/ja/02.png".
const expected = new Set();
for (const slides of Object.values(project.slidesByDevice || {})) {
  for (const slide of slides) {
    for (const raw of [slide.screenshot, slide.screenshotSecondary]) {
      if (!raw || !raw.startsWith("/screenshots/apple/")) continue;
      for (const locale of locales) expected.add(raw.replace("/screenshots/apple/", "").replaceAll("{locale}", locale));
    }
  }
}

function folderOf(rel) {
  return Object.keys(SIZES).find((folder) => rel.startsWith(`${folder}/`));
}

function sourceFor(rel) {
  const folder = folderOf(rel);
  if (!folder) return null;
  const [locale, file] = rel.slice(folder.length + 1).split("/");
  for (const alias of LOCALE_ALIASES[locale] || [locale]) {
    const candidate = path.join(SRC, folder, alias, file);
    if (existsSync(candidate)) return candidate;
  }
  return null;
}

async function placeholder(rel) {
  const folder = folderOf(rel);
  const [w, h] = SIZES[folder] || [1320, 2868];
  const label = rel.replace(/\.png$/, "");
  const fs = Math.round(Math.min(w, h) * 0.045);
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}">
  <rect width="100%" height="100%" fill="#ECE7E3"/>
  <rect x="${w * 0.08}" y="${h * 0.08}" width="${w * 0.84}" height="${h * 0.84}" rx="${fs}" fill="none" stroke="#C9BFB8" stroke-width="${fs * 0.15}" stroke-dasharray="${fs * 0.6} ${fs * 0.4}"/>
  <text x="50%" y="47%" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-size="${fs * 1.2}" font-weight="700" fill="#8A7F78">Capture pending</text>
  <text x="50%" y="53%" text-anchor="middle" font-family="Menlo, monospace" font-size="${fs * 0.7}" fill="#8A7F78">${label}</text>
</svg>`;
  return sharp(Buffer.from(svg)).flatten({ background: "#ECE7E3" }).png().toBuffer();
}

let copied = 0;
let placed = 0;
const missing = [];
const wrongSize = [];

for (const rel of [...expected].sort()) {
  const dest = path.join(DEST, rel);
  const src = sourceFor(rel);
  if (src) {
    const meta = await sharp(src).metadata();
    const want = SIZES[folderOf(rel)];
    if (want && (meta.width !== want[0] || meta.height !== want[1])) {
      wrongSize.push(`${rel}: ${meta.width}x${meta.height}, expected ${want[0]}x${want[1]}`);
    }
    let mode = "dry";
    if (!DRY) {
      mkdirSync(path.dirname(dest), { recursive: true });
      mode = await writeCapture(src, dest);
    }
    copied += 1;
    console.log(`copy  ${path.relative(ROOT, src)} -> public/screenshots/apple/${rel} (${mode})`);
    continue;
  }
  if (PLACEHOLDERS && (FORCE_PLACEHOLDERS || !existsSync(dest))) {
    if (!DRY) {
      mkdirSync(path.dirname(dest), { recursive: true });
      writeFileSync(dest, await placeholder(rel));
    }
    placed += 1;
    console.log(`stub  public/screenshots/apple/${rel}`);
    continue;
  }
  missing.push(rel + (existsSync(dest) ? " (keeps existing placeholder)" : " (no file)"));
}

// Captures that no slide references yet (e.g. extra shots or NN-book.png).
const unused = [];
for (const folder of Object.keys(SIZES)) {
  const dir = path.join(SRC, folder);
  if (!existsSync(dir)) continue;
  for (const locale of readdirSync(dir)) {
    const localeDir = path.join(dir, locale);
    let files = [];
    try { files = readdirSync(localeDir); } catch { continue; }
    for (const file of files.filter((f) => f.endsWith(".png"))) {
      const canonical = Object.keys(LOCALE_ALIASES).find((key) => LOCALE_ALIASES[key].includes(locale)) || locale;
      if (!expected.has(`${folder}/${canonical}/${file}`)) unused.push(`${folder}/${locale}/${file}`);
    }
  }
}

// Files in the editor that no slide uses any more.
const pruned = [];
if (PRUNE && existsSync(DEST)) {
  const walk = (dir) => readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]);
  for (const file of walk(DEST).filter((f) => /\.(png|jpe?g)$/i.test(f))) {
    const rel = path.relative(DEST, file).split(path.sep).join("/");
    if (expected.has(rel)) continue;
    if (!DRY) rmSync(file);
    pruned.push(rel);
  }
}

console.log(`\n${DRY ? "[dry run] " : ""}${copied} captures copied, ${placed} placeholders written, source: ${SRC}`);
if (wrongSize.length) console.warn(`\nWrong pixel size (the editor letterboxes Duo mismatches):\n  ${wrongSize.join("\n  ")}`);
if (missing.length) console.warn(`\nStill missing a real capture:\n  ${missing.join("\n  ")}`);
if (unused.length) console.log(`\nCaptures not referenced by any slide:\n  ${unused.join("\n  ")}`);
if (pruned.length) console.log(`\nRemoved from the editor (not referenced):\n  ${pruned.join("\n  ")}`);

if (flag("--strict") && (missing.length || wrongSize.length)) {
  console.error("\n--strict: fix the missing or wrong-size captures above before exporting.");
  process.exit(1);
}
