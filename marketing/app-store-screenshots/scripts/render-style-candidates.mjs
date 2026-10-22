#!/usr/bin/env node
// Renders one comparison board per saved Style Lab look (savedLooks in
// app-store-screenshots.json) into style-candidates/<look-id>.png, plus
// style-candidates/all-candidates.png with every look's Japanese deck.
//
//   npm run style-candidates                       # iPhone deck, ja + en rows
//   npm run style-candidates -- --locales ja       # one row per board
//   npm run style-candidates -- --device duo-outer # another portrait deck
//
// Each look is applied through the editor's own Style Lab ("Apply saved look"),
// then exported with "Export bundle", so the boards are exactly what an export
// of that look would produce. app-store-screenshots.json is never modified.
import { mkdirSync, rmSync } from "node:fs";
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
const project = readProject();
const device = option("--device") || "iphone";
const locales = (option("--locales") || "ja,en").split(",");
const only = option("--looks")?.split(",");
const looks = (project.savedLooks || []).filter((l) => !only || only.includes(l.id));
if (!looks.length) throw new Error("No savedLooks in app-store-screenshots.json");

const OUT = path.join(ROOT, "style-candidates");
const TMP = path.join(ROOT, "exports", "style-candidates-tmp");
mkdirSync(OUT, { recursive: true });
mkdirSync(TMP, { recursive: true });

// Short description shown on each board (one line per look).
const BLURB = {
  "tutnext-sakura-campus": "Brand cream + coral from the app icon, soft aurora flowing across screens, rounded Avenir / Hiragino Sans.",
  "tutnext-timetable-grid": "Swiss paper-and-ink grid like a timetable, flush-left heavy type, coral accent, two ink-black contrast screens.",
  "tutnext-night-campus": "Near-black night campus with a coral spotlight glow behind each phone, white system type.",
  "tutnext-quiet-washi": "Washi-paper ruled lines, calm serif (Baskerville / Hiragino Mincho), hanko-red label, one dark screen.",
};

const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const text = (w, h, svgBody) =>
  sharp(Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}">${svgBody}</svg>`)).png().toBuffer();

async function shotsFor(zipPath, locale) {
  const zip = await JSZip.loadAsync(await readFile(zipPath));
  const names = Object.keys(zip.files)
    .filter((f) => f.includes(`/${locale}/`) && f.endsWith(".png"))
    // Largest size folder only (the canvas size).
    .sort();
  const bySize = {};
  for (const n of names) {
    const size = n.split("/")[2];
    (bySize[size] ||= []).push(n);
  }
  const largest = Object.keys(bySize).sort((a, b) => Number(b.split("x")[0]) - Number(a.split("x")[0]))[0];
  return Promise.all(bySize[largest].sort().map((n) => zip.files[n].async("nodebuffer")));
}

async function row(buffers, thumbH, gap) {
  const metas = await Promise.all(buffers.map((b) => sharp(b).metadata()));
  const widths = metas.map((m) => Math.round((m.width / m.height) * thumbH));
  const width = widths.reduce((a, b) => a + b, 0) + gap * (buffers.length - 1);
  const parts = await Promise.all(buffers.map((b, i) => sharp(b).resize(widths[i], thumbH).png().toBuffer()));
  let x = 0;
  const composite = parts.map((input, i) => {
    const item = { input, left: x, top: 0 };
    x += widths[i] + gap;
    return item;
  });
  return { width, height: thumbH, composite };
}

async function board({ title, subtitle, rows, thumbH }) {
  const PAD = 72;
  const GAP = 24;
  const ROW_LABEL = 56;
  const HEAD = 170;
  const built = [];
  for (const r of rows) built.push({ label: r.label, ...(await row(r.buffers, thumbH, GAP)) });
  const contentW = Math.max(...built.map((r) => r.width));
  const W = contentW + PAD * 2;
  const H = PAD + HEAD + built.length * (ROW_LABEL + thumbH + 40) + PAD - 40;
  const layers = [
    {
      input: await text(W, HEAD, `
        <text x="${PAD}" y="62" font-family="Helvetica Neue, Helvetica, Arial" font-size="56" font-weight="700" fill="#141413">${esc(title)}</text>
        <text x="${PAD}" y="118" font-family="Helvetica Neue, Helvetica, Arial" font-size="28" fill="#55524C">${esc(subtitle)}</text>`),
      left: 0,
      top: PAD - 20,
    },
  ];
  let y = PAD + HEAD;
  for (const r of built) {
    layers.push({
      input: await text(W, ROW_LABEL, `<text x="${PAD}" y="36" font-family="Helvetica Neue, Helvetica, Arial" font-size="30" font-weight="600" fill="#141413">${esc(r.label)}</text>`),
      left: 0,
      top: y,
    });
    y += ROW_LABEL;
    for (const c of r.composite) layers.push({ ...c, left: c.left + PAD, top: c.top + y });
    y += thumbH + 40;
  }
  return sharp({ create: { width: W, height: H, channels: 3, background: "#F4F3EF" } }).composite(layers).png().toBuffer();
}

const server = await ensureServer(option("--url"));
const browser = await launchBrowser({ headed: args.includes("--headed") });
const overview = [];
try {
  for (const look of looks) {
    const zipPath = path.join(TMP, `${look.id}.zip`);
    console.log(`${look.name}: exporting ${device} (${locales.join(", ")})…`);
    await exportBundle({ browser, url: server.url, state: stateForDevice(project, device, locales), lookId: look.id, zipPath });
    const rows = [];
    for (const locale of locales) rows.push({ label: locale, buffers: await shotsFor(zipPath, locale) });
    overview.push({ label: look.name, buffers: rows[0].buffers });
    const png = await board({ title: `TUTnext — ${look.name}`, subtitle: BLURB[look.id] || look.direction, rows, thumbH: 900 });
    const file = path.join(OUT, `${look.id}.png`);
    await sharp(png).toFile(file);
    console.log(`  -> ${path.relative(ROOT, file)}`);
  }
  if (overview.length > 1) {
    const png = await board({ title: "TUTnext — style candidates", subtitle: `${device}, ${locales[0]}`, rows: overview, thumbH: 640 });
    await sharp(png).toFile(path.join(OUT, "all-candidates.png"));
    console.log(`  -> style-candidates/all-candidates.png`);
  }
} finally {
  await browser.close();
  await server.stop();
  rmSync(TMP, { recursive: true, force: true });
}
