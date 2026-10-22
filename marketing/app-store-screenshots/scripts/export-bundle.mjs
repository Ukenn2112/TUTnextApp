#!/usr/bin/env node
// Headless "Export bundle" for every deck, using the editor's own export code.
//
//   npm run export                         # all four decks, all locales -> exports/<stamp>/
//   npm run export -- --devices iphone     # one deck
//   npm run export -- --locales ja,en      # subset of locales
//   npm run export -- --look tutnext-night-campus   # apply a saved Style Lab look first
//   npm run export -- --url http://localhost:3000   # reuse a running editor
//   npm run export -- --out exports/final  # fixed output folder (replaced)
//
// Without --url it reuses an editor already running on :3000/:3001 for this
// project, or starts `next dev` on a free port and stops it afterwards.
// app-store-screenshots.json is never modified.
//
// After exporting, every PNG is checked (pixel size matches its WxH folder, no
// alpha channel, one file per slide x locale x size), contact sheets are written
// to <out>/contact-sheets/<device>.png (rows = locales, largest size), and
// <out>/manifest.json lists every file. Exits non-zero if any check fails.
import { existsSync, mkdirSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { readFile } from "node:fs/promises";
import path from "node:path";
import JSZip from "jszip";
import sharp from "sharp";
import { ROOT, ensureServer, exportBundle, launchBrowser, readProject, stateForDevice } from "./lib/headless-editor.mjs";

const args = process.argv.slice(2);
const option = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};
const list = (value) => (value ? value.split(",").map((s) => s.trim()).filter(Boolean) : undefined);

const project = readProject();
const devices =
  list(option("--devices")) ||
  Object.entries(project.slidesByDevice).filter(([, slides]) => slides.length > 0).map(([device]) => device);
const locales = list(option("--locales")) || project.locales;
const lookId = option("--look");
const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
const outDir = path.resolve(ROOT, option("--out") || path.join("exports", stamp));

// Only ever clear a previous run inside exports/; refuse anything else that exists.
const exportsRoot = path.join(ROOT, "exports") + path.sep;
if (outDir.startsWith(exportsRoot)) {
  rmSync(outDir, { recursive: true, force: true });
} else if (existsSync(outDir) && readdirSync(outDir).length) {
  throw new Error(`--out ${outDir} is not empty and not under exports/; pick an empty folder`);
}
mkdirSync(outDir, { recursive: true });

async function contactSheet(device, files) {
  // files: { locale, size, name, buffer }[] for one device.
  const largest = [...new Set(files.map((f) => f.size))].sort((a, b) => Number(b.split("x")[0]) - Number(a.split("x")[0]))[0];
  const [w, h] = largest.split("x").map(Number);
  const thumbH = w > h ? 520 : 760;
  const thumbW = Math.round((w / h) * thumbH);
  const PAD = 48;
  const GAP = 20;
  const LABEL = 150;
  const HEAD = 90;
  const rows = locales.map((locale) => files.filter((f) => f.size === largest && f.locale === locale).sort((a, b) => a.name.localeCompare(b.name)));
  const cols = Math.max(...rows.map((r) => r.length));
  const W = PAD * 2 + LABEL + cols * thumbW + (cols - 1) * GAP;
  const H = PAD * 2 + HEAD + rows.length * thumbH + (rows.length - 1) * GAP;
  const svg = (body) => Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">${body}</svg>`);
  let labels = `<text x="${PAD}" y="${PAD + 44}" font-family="Helvetica Neue, Helvetica, Arial" font-size="44" font-weight="700" fill="#141413">TUTnext · ${device} · ${largest}</text>`;
  const layers = [];
  for (const [r, row] of rows.entries()) {
    const top = PAD + HEAD + r * (thumbH + GAP);
    labels += `<text x="${PAD}" y="${top + 40}" font-family="Helvetica Neue, Helvetica, Arial" font-size="30" font-weight="600" fill="#141413">${locales[r]}</text>`;
    for (const [c, file] of row.entries()) {
      layers.push({ input: await sharp(file.buffer).resize(thumbW, thumbH).png().toBuffer(), left: PAD + LABEL + c * (thumbW + GAP), top });
    }
  }
  layers.unshift({ input: svg(labels), left: 0, top: 0 });
  return sharp({ create: { width: W, height: H, channels: 3, background: "#F4F3EF" } }).composite(layers).png().toBuffer();
}

const server = await ensureServer(option("--url"));
const browser = await launchBrowser({ headed: args.includes("--headed") });
const manifest = {};
const problems = [];
try {
  console.log(`editor: ${server.url}\nout:    ${path.relative(process.cwd(), outDir) || "."}`);
  mkdirSync(path.join(outDir, "contact-sheets"), { recursive: true });
  for (const device of devices) {
    const zipPath = path.join(outDir, `${device}${lookId ? `-${lookId}` : ""}.zip`);
    const started = Date.now();
    console.log(`\n${device}: exporting…`);
    try {
      await exportBundle({ browser, url: server.url, state: stateForDevice(project, device, locales), lookId, zipPath });
      const zip = await JSZip.loadAsync(await readFile(zipPath));
      const names = Object.keys(zip.files).filter((f) => f.endsWith(".png")).sort();
      const files = [];
      for (const name of names) {
        const buffer = await zip.files[name].async("nodebuffer");
        const target = path.join(outDir, name);
        mkdirSync(path.dirname(target), { recursive: true });
        writeFileSync(target, buffer);
        // ios/<device>/<WxH>/<locale>/NN-<layout>.png
        const [, , size, locale, file] = name.split("/");
        const meta = await sharp(buffer).metadata();
        if (`${meta.width}x${meta.height}` !== size) problems.push(`${name}: is ${meta.width}x${meta.height}`);
        if (meta.hasAlpha || meta.channels !== 3) problems.push(`${name}: has an alpha channel`);
        files.push({ locale, size, name: file, buffer, path: path.relative(ROOT, target) });
      }
      const sizes = [...new Set(files.map((f) => f.size))];
      const slides = project.slidesByDevice[device].length;
      const expectedCount = slides * locales.length * sizes.length;
      if (files.length !== expectedCount) problems.push(`${device}: ${files.length} PNGs, expected ${expectedCount}`);
      manifest[device] = Object.fromEntries(
        sizes.map((size) => [size, Object.fromEntries(locales.map((l) => [l, files.filter((f) => f.size === size && f.locale === l).map((f) => f.path)]))]),
      );
      const sheet = path.join(outDir, "contact-sheets", `${device}.png`);
      writeFileSync(sheet, await contactSheet(device, files));
      console.log(`${device}: ${files.length} PNGs (${sizes.join(", ")}) in ${((Date.now() - started) / 1000).toFixed(0)}s; sheet ${path.relative(ROOT, sheet)}`);
    } catch (error) {
      problems.push(`${device}: export failed - ${error instanceof Error ? error.message : error}`);
      console.error(`${device}: FAILED - ${error instanceof Error ? error.message : error}`);
    }
  }
} finally {
  await browser.close();
  await server.stop();
}
writeFileSync(path.join(outDir, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
if (problems.length) {
  console.error(`\nChecks failed:\n  ${problems.join("\n  ")}`);
  process.exit(1);
}
console.log(`\nAll checks passed (sizes, no alpha, file counts). Manifest: ${path.relative(ROOT, path.join(outDir, "manifest.json"))}`);
