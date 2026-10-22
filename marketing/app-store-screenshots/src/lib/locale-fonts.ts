// Per-locale CJK fallbacks for the screenshot font stack.
//
// The canvas fonts are Latin faces (Baskerville, Avenir Next, ...). Without help,
// Chrome fills CJK glyphs from whatever face it finds first, so Simplified Chinese
// text can render with Japanese glyph forms and Hangul falls back to a sans face
// even under a serif stack. This inserts the right serif or sans family for the
// locale just before the generic family, so a serif look stays serif in every
// language (macOS faces first, then common cross-platform ones).
const SERIF: Record<string, string[]> = {
  ja: ["Hiragino Mincho ProN", "Hiragino Mincho Pro", "YuMincho", "Yu Mincho", "Noto Serif JP"],
  "zh-Hans": ["Songti SC", "STSong", "Noto Serif SC", "Source Han Serif SC"],
  "zh-Hant": ["Songti TC", "Noto Serif TC"],
  ko: ["AppleMyungjo", "Nanum Myeongjo", "NanumMyeongjo", "Noto Serif KR"],
};

const SANS: Record<string, string[]> = {
  ja: ["Hiragino Sans", "Hiragino Kaku Gothic ProN", "Noto Sans JP"],
  "zh-Hans": ["PingFang SC", "Hiragino Sans GB", "Noto Sans SC"],
  "zh-Hant": ["PingFang TC", "Noto Sans TC"],
  ko: ["Apple SD Gothic Neo", "Noto Sans KR"],
};

const GENERIC = /,\s*(serif|sans-serif)\s*$/i;

function baseLocale(locale: string): string {
  if (SERIF[locale]) return locale;
  const lower = locale.toLowerCase().replace("_", "-");
  if (lower.startsWith("zh")) return lower.includes("hant") || lower.endsWith("tw") || lower.endsWith("hk") ? "zh-Hant" : "zh-Hans";
  return lower.split("-")[0];
}

export function localizedFontFamily(family: string | undefined, locale: string): string | undefined {
  if (!family || family === "inherit") return family;
  const match = GENERIC.exec(family);
  const key = baseLocale(locale);
  if (!match) {
    const extra = SANS[key];
    return extra ? `${family}, ${extra.map((f) => `"${f}"`).join(", ")}` : family;
  }
  const extra = (match[1].toLowerCase() === "serif" ? SERIF : SANS)[key];
  if (!extra) return family;
  return `${family.slice(0, match.index)}, ${extra.map((f) => `"${f}"`).join(", ")}, ${match[1]}`;
}
