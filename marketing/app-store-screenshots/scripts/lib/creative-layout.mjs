// Art direction for the App Store creative assets: "Product lineup", in two
// variants, each laid out for the product page header (3840x1646) and search
// results (3840x2560).
//
// Apple's art safe areas (from the templates):
//   header 1646x661  @ (1097, 493)
//   search 2168x1030 @ (836, 765)
// Hard rules, enforced by check() below:
//   - every device reads as an Apple device: Apple's bezels, straight on, and
//     the top and both sides of every frame stay inside the canvas; only the
//     bottom may bleed;
//   - label + headline sit inside the safe area, centred above the hero, and
//     nothing comes within MIN_GAP of them;
//   - devices only overlap where a variant layers them on purpose (B);
//   - real captures; Quiet Washi paper, serif headline with the +10px line gap.
import { DUOS, DUO_PAD, IPHONE_ASPECT } from "./creative-assets.mjs";

export const CANVAS = { header: { w: 3840, h: 1646 }, search: { w: 3840, h: 2560 } };
export const SAFE = {
  header: { x: 1097, y: 493, w: 1646, h: 661 },
  search: { x: 836, y: 765, w: 2168, h: 1030 },
};
export const DECK = { header: "creative-header", search: "creative-search" };
const LOCALES = ["ja", "en", "zh-Hans", "ko"];
const MIN_GAP = 90;

const r = Math.round;
const rect = (x, y, width, height, zIndex = 3) => ({ x: r(x), y: r(y), width: r(width), height: r(height), rotation: 0, zIndex });

const t = (ja, en, zh, ko) => ({ ja, en, "zh-Hans": zh, ko });
const LABEL = t("多摩大非公式アプリ", "Tama Univ. · Unofficial", "多摩大学非官方应用", "타마대학 비공식 앱");
const HEADLINE = {
  one: t("キャンパスの毎日を、ひとつに", "Campus life, all in one place.", "校园的每一天，尽在一处", "캠퍼스의 하루를 하나로"),
  two: t("キャンパスの毎日を、\nひとつに", "Campus life,\nall in one place.", "校园的每一天，\n尽在一处", "캠퍼스의 하루를\n하나로"),
};
// Widest line of each variant in em (weight 600, the locale's serif fallback,
// "palt" on), measured in Chrome on macOS. Used to size each locale to fit.
const EM = {
  one: { ja: 12.29, en: 13.32, "zh-Hans": 11.0, ko: 10.49 },
  two: { ja: 8.67, en: 7.2, "zh-Hans": 7.0, ko: 7.24 },
};

// ---------- typography ----------
// The editor's caption on creative decks: unit = min(safe) * 1.15;
// headline px = unit * 0.092 * 0.95 (scene) * headlineScale * localeScale;
// label px = unit * 0.028 * labelScale, plus unit * 0.018 below it; line gap +10 px.
function headlineSizing(format, variant, maxWidth, capPx) {
  const unit = Math.min(SAFE[format].w, SAFE[format].h) * 1.15;
  const perScale = unit * 0.092 * 0.95;
  const labelScale = 2;
  const labelBlock = unit * 0.028 * labelScale * 1.25 + unit * 0.018;
  const lines = { one: 1, two: 2 }[variant];
  const px = Object.fromEntries(LOCALES.map((l) => [l, Math.min(capPx, maxWidth / EM[variant][l])]));
  const base = px.ja;
  return {
    typography: {
      labelScale,
      headlineScale: Math.round((base / perScale) * 1000) / 1000,
      localeScale: Object.fromEntries(LOCALES.filter((l) => l !== "ja").map((l) => [l, Math.round((px[l] / base) * 1000) / 1000])),
      palt: true,
      captionAlign: "center",
    },
    height: Math.max(...LOCALES.map((l) => labelBlock + lines * (px[l] * 0.96 + 10))),
    width: Math.max(...LOCALES.map((l) => EM[variant][l] * px[l])),
  };
}

// ---------- elements ----------
// The Duo overlay PNG carries a shadow margin; grow the rect so the frame lands at (x, y, w, h).
function duo(x, y, w, zIndex) {
  const d = DUOS["duo-open"];
  const h = (w * d.h) / d.w;
  const p = (DUO_PAD * w) / d.w;
  return {
    el: { id: "duo-open", src: "/screenshots/creative/duo-open/{locale}.png", fit: "contain", transform: rect(x - p, y - p, w + 2 * p, h + 2 * p, zIndex) },
    box: { name: "duo", x, y, w, h },
  };
}
const iphone = (name, x, y, w) => ({ name, x, y, w, h: w / IPHONE_ASPECT });
const accent = (id, x, y, w, h) => ({ id, src: "/screenshots/creative/marks/accent.png", fit: "cover", transform: rect(x, y, w, h, 7) });

// ---------- checks ----------
function gapBetween(a, b) {
  const dx = Math.max(a.x, b.x) - Math.min(a.x + a.w, b.x + b.w);
  const dy = Math.max(a.y, b.y) - Math.min(a.y + a.h, b.y + b.h);
  if (dx < 0 && dy < 0) return -1; // overlapping
  return Math.max(dx, dy);
}
function check(id, format, text, devices, allowedOverlaps = []) {
  const s = SAFE[format];
  const { w: cW } = CANVAS[format];
  if (text.x < s.x - 1 || text.y < s.y - 1 || text.x + text.w > s.x + s.w + 1 || text.y + text.h > s.y + s.h + 1) {
    throw new Error(`${id}: text ${JSON.stringify(text)} leaves the ${format} safe area`);
  }
  for (const d of devices) {
    // Only the bottom may bleed: top, left and right of every frame stay on the canvas.
    if (d.y < 0 || d.x < 0 || d.x + d.w > cW) throw new Error(`${id}: ${d.name} frame is cropped at the top or a side`);
    const g = gapBetween(text, d);
    if (g < MIN_GAP) throw new Error(`${id}: ${d.name} is ${g}px from the headline (min ${MIN_GAP})`);
  }
  devices.forEach((a, i) => devices.slice(i + 1).forEach((b) => {
    const pair = [a.name, b.name].sort().join("+");
    const g = gapBetween(a, b);
    if (g < 0 && !allowedOverlaps.includes(pair)) throw new Error(`${id}: ${pair} overlap`);
    if (g >= 0 && g < 60) throw new Error(`${id}: ${pair} are only ${g}px apart`);
  }));
}

function slide(id, headline, extra) {
  return { id, layout: "two-devices", label: LABEL, headline, ...extra };
}

// ---------- shared ----------
// Header: one-line headline across the top of the safe area. Search: two lines.
const TEXT = {
  header: { variant: "one", width: 1600, cap: 160 },
  search: { variant: "two", width: 1400, cap: 200 },
};

function textBlock(format, rule) {
  const safe = SAFE[format];
  const sizing = headlineSizing(format, TEXT[format].variant, TEXT[format].width, TEXT[format].cap);
  const ruleH = rule ? rule.h + rule.gap : 0;
  const top = safe.y + (format === "header" ? 14 : 40);
  const total = ruleH + sizing.height;
  const cx = safe.x + safe.w / 2;
  return {
    sizing,
    top,
    bottom: top + total,
    caption: rect(safe.x, top + ruleH, safe.w, sizing.height + 40, 4),
    box: { x: cx - sizing.width / 2, y: top, w: sizing.width, h: total },
    rule: rule ? accent("rule", cx - rule.w / 2, top, rule.w, rule.h) : null,
  };
}

function devicesSlide(id, format, text, left, right, hero, duoZ, extras = []) {
  return slide(id, HEADLINE[TEXT[format].variant], {
    screenshot: "/screenshots/apple/iphone/{locale}/02.png",
    screenshotSecondary: "/screenshots/apple/iphone/{locale}/03.png",
    typography: text.sizing.typography,
    transforms: {
      caption: text.caption,
      device: rect(left.x, left.y, left.w, left.h, 3),
      deviceSecondary: rect(right.x, right.y, right.w, right.h, 3),
    },
    imageElements: [...extras, duo(hero.x, hero.y, hero.w, duoZ).el],
  });
}

// ---------- Variant A: side by side ----------
// The open Duo is the hero in the centre, under the headline, bleeding off the
// bottom. Two iPhones (next bus, assignments) flank it with even gaps; they
// start higher so the side columns fill the top of the canvas.
function sideBySide(format) {
  const { w: cW, h: cH } = CANVAS[format];
  const spec = format === "header"
    ? { margin: 180, phoneW: 800, phoneY: 120, gap: 100, textGap: 100 }
    // 3:2 is too narrow for three bottom-bleeding devices plus a big hero, so the
    // iPhones are shown whole here and only the Duo bleeds.
    : { margin: 110, phoneW: 900, phoneY: 300, gap: 110, textGap: 200 };
  const text = textBlock(format);
  const left = iphone("bus", spec.margin, spec.phoneY, spec.phoneW);
  const right = iphone("assignments", cW - spec.margin - spec.phoneW, spec.phoneY, spec.phoneW);
  const duoX = left.x + left.w + spec.gap;
  const duoW = right.x - spec.gap - duoX;
  const duoY = text.bottom + spec.textGap;
  const hero = duo(duoX, duoY, duoW, 3).box;
  if (hero.y + hero.h <= cH) throw new Error(`${format} A: the Duo should bleed off the bottom`);
  const id = `${DECK[format]}-a-side-by-side`;
  check(id, format, text.box, [left, right, hero]);
  return devicesSlide(id, format, text, left, right, hero, 3);
}

// ---------- Variant B: layered ----------
// Same three devices, layered: the Duo in front, centred and bleeding off the
// bottom; the iPhones just behind its left and right edges, their tops and
// outer sides fully visible. A short red rule above the label.
function layered(format) {
  const { w: cW, h: cH } = CANVAS[format];
  const spec = format === "header"
    ? { margin: 200, phoneW: 800, phoneY: 130, duoW: 2300, textGap: 105, rule: { w: 140, h: 7, gap: 40 } }
    : { margin: 100, phoneW: 1000, phoneY: 360, duoW: 2400, textGap: 110, rule: { w: 180, h: 9, gap: 56 } };
  const text = textBlock(format, spec.rule);
  const left = iphone("bus", spec.margin, spec.phoneY, spec.phoneW);
  const right = iphone("assignments", cW - spec.margin - spec.phoneW, spec.phoneY, spec.phoneW);
  const hero = duo((cW - spec.duoW) / 2, text.bottom + spec.textGap, spec.duoW, 6).box;
  if (hero.y + hero.h <= cH) throw new Error(`${format} B: the Duo should bleed off the bottom`);
  if (left.x + left.w <= hero.x) throw new Error(`${format} B: the iPhones should tuck behind the Duo`);
  const id = `${DECK[format]}-b-layered`;
  check(id, format, text.box, [left, right, hero], ["bus+duo", "assignments+duo"]);
  return devicesSlide(id, format, text, left, right, hero, 6, [text.rule]);
}

export const CONCEPTS = [
  { key: "a-side-by-side", name: "Product lineup · A, side by side", build: sideBySide,
    blurb: "The open iPhone Duo (timetable + Today) as the centred hero under the headline, flanked by two iPhones (next bus, assignments) with even gaps." },
  { key: "b-layered", name: "Product lineup · B, layered", build: layered,
    blurb: "The same three devices layered: the Duo in front, the iPhones tucked just behind its edges, a short red rule above the label." },
];
