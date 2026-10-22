# TUTnext App Store screenshots: notes

This is the editor from [ParthJadhav/app-store-screenshots](https://github.com/ParthJadhav/app-store-screenshots), set up for TUTnext.
The deck (decks, copy, look) lives in `app-store-screenshots.json`.

## After re-shooting the captures: one command

```bash
cd marketing/app-store-screenshots
npm install        # first time only
npm run release    # import captures + export every deck -> exports/latest/
```

`npm run release` runs the import and then the export. It:

1. **Imports** `marketing/captures/**` into `public/screenshots/apple/**` (`import-captures --prune --strict`):
   - It stops if a capture is missing or the wrong pixel size.
   - It deletes editor images no slide references.
2. **Exports** all four decks in all four locales to `exports/latest/` (`export-bundle --out exports/latest`), then checks every PNG: pixel size matches its folder, no alpha channel, one file per slide × locale × size.
   - It writes `exports/latest/contact-sheets/<deck>.png` (rows = locales) and `exports/latest/manifest.json`.
   - It exits non-zero if any check fails.

App Store upload files: `exports/latest/ios/<deck>/<WxH>/<locale>/NN-<layout>.png`. One zip per deck sits next to them. `exports/` is gitignored.

## Run the editor

```bash
npm run dev      # http://localhost:3000
```

## Decks

| Deck (editor device) | Size | Slides: capture file -> screen |
|---|---|---|
| `iphone` | 1320x2868 (+ 6.5"/6.3"/6.1") | 01 timetable, 02 bus, 03 assignments, 04 course detail, 05 home-screen widgets |
| `duo-inner-landscape` | 2853x2007 | 01 timetable + Today, 02 both bus directions (Folded + open, closed phone = `duo-outer/portrait/02`), 03 assignments |
| `duo-outer` (portrait) | 1398x2034 | 01 timetable, 02 bus (Folded + open, open phone = `duo-inner/landscape/02`), 03 assignments |
| `duo-inner` (portrait) | 2007x2853 | 01 timetable, 02 course detail sheet, 03 bus |

Locales: `ja` (primary), `en`, `zh-Hans`, `ko`. Every slide's screenshot path contains `{locale}`.

## Look: D · Quiet Washi, with a 10px headline line gap

The look is applied to the whole project:

- theme `tutnext-washi`
- font Baskerville
- ruled-paper backdrop, flush-left 600-weight headlines
- `scene.headlineLineGap: 10`

On the iPhone, the screen layouts follow the look's rhythm. Duo decks keep their own layouts.

**Line gap.** The editor normally sets headline leading as a multiplier (`line-height: 0.96`). I added an optional `scene.headlineLineGap`, measured in canvas pixels. When it is set, the headline uses `line-height: calc(fontSize × 0.96 + gap)` in px, so the space between line 1 and line 2 grows by exactly that amount at canvas resolution.

- Canvas resolution is the largest export size of every deck. So it is +10px on the 6.9" iPhone and on all three Duo sizes.
- The smaller iPhone sizes are downscales, so the gap there is about 9.7 / 9.1 / 8.5px.
- The **Scene** popover has a "Line gap" slider. Style Lab treats it as part of **Type**.

**CJK serif fallback.** Each canvas now carries `lang=<locale>`. `src/lib/locale-fonts.ts` inserts the locale's own face before the generic family:

| Locale | Serif looks | Sans looks |
|---|---|---|
| ja | Hiragino Mincho ProN | Hiragino Sans |
| zh-Hans | Songti SC | PingFang SC |
| ko | AppleMyungjo, then Nanum Myeongjo / Noto Serif KR if installed | Apple SD Gothic Neo |

Without this, Simplified Chinese used Japanese glyph forms and Hangul fell back to a sans face.

**Hand placement.** The outer-portrait Folded + open slide (`duo-outer-p-02-bus`) has hand-set `transforms`. The open phone sits upper left and the closed phone lower right, at equal height (physical scale) and without overlapping. The template default put the closed phone over the open phone's second bus table.

Duo inner portrait slides 01 and 02 (`duo-inner-p-01-timetable`, `duo-inner-p-02-course`) also have a hand-set device rect:

- 78% of canvas width (1565×2154), centred, top at y=820
- the bottom ~120px bleeds off the canvas
- the template default was about 40% width

Applying a different look in Style Lab resets these transforms unless **Layout** is locked.

The other candidate looks (A–C, and D without the line gap) are still under **Style Lab -> Saved looks**. `npm run style-candidates` regenerates their comparison boards in `style-candidates/`.

## Individual commands

```bash
npm run import-captures                          # copy captures (lossless RGB re-encode of opaque PNGs)
npm run import-captures -- --dry-run --prune     # preview copies and deletions
npm run import-captures -- --raw                 # copy byte for byte instead
npm run export                                   # all decks -> exports/<timestamp>/
npm run export -- --devices iphone --locales ja  # subset
npm run export -- --look tutnext-night-campus    # export another saved look (the JSON is not changed)
```

- **Import:** it accepts locale folder aliases (`en-US`, `ja-JP`, `zh_Hans`, `ko-KR`), and it reports captures that no slide uses. The re-encode drops the alpha channel only when every pixel is already opaque, so the pixels are identical and the files are about 40% smaller.
- **Export:** it clicks the editor's own **Export bundle** button in headless Google Chrome (Playwright). It reuses an editor running on :3000/:3001, or starts `next dev` on a free port and stops it afterwards. The project is served to the page from memory, so `app-store-screenshots.json` is never rewritten.

Before uploading, check the Duo sets in App Store Connect's iPhone Duo preview tool.
