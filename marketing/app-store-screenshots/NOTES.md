# TUTnext App Store screenshots: notes

This is the editor from [ParthJadhav/app-store-screenshots](https://github.com/ParthJadhav/app-store-screenshots), set up for TUTnext.
The deck (decks, copy, look) lives in `app-store-screenshots.json`.

## After re-shooting the captures: one command

```bash
cd marketing/app-store-screenshots
npm install        # first time only
npm run release    # import captures + export every deck -> exports/latest/
```

`npm run release` runs three steps (the creative assets section below explains step 2):

1. **Imports** `marketing/captures/**` into `public/screenshots/apple/**` (`import-captures --prune --strict`):
   - It stops if a capture is missing or the wrong pixel size.
   - It deletes editor images no slide references.
2. **Builds** the creative-asset overlays: framed Duo, UI panels, accent mark (`build-creative-overlays`).
3. **Exports** all four screenshot decks and both creative assets in all four locales to `exports/latest/` (`export-bundle --out exports/latest`), then checks every PNG: pixel size matches its folder, no alpha channel, one file per slide × locale × size.
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

## App Store creative assets (product page header + search results)

**Decks.** There are two dedicated assets, both opaque RGB PNG:

- `creative-header`: 3840×1646 (21:9), safe area 1646×661 @ (1097,493)
- `creative-search`: 3840×2560 (3:2), safe area 2168×1030 @ (836,765)

The universal deck is empty.

**Direction: "Product lineup"**, in two variants. Each deck currently holds one slide per variant, defined in `scripts/lib/creative-layout.mjs`:

- **A · side by side** (`a-side-by-side`): the open iPhone Duo (inner landscape, timetable + Today) is the centred hero under the headline, bleeding off the bottom.
  - Two iPhones (next bus left, assignments right) flank it with even gaps, starting higher so the side columns fill the top.
  - In search (3:2) the iPhones are shown whole. Three bottom-bleeding devices side by side would shrink the Duo hero too much on that canvas.
- **B · layered** (`b-layered`): the same three devices, with the Duo in front and the iPhones tucked just behind its left and right edges. Their tops and outer sides stay fully visible. A short red rule sits above the label.

**Hard rules, checked in code when the decks are seeded:**

- Every device is an Apple bezel (`public/frames/iphone-portrait.png`, `duo-inner-landscape.png`), straight on.
- The top and both sides of every frame stay inside the canvas; only the bottom may bleed.
- Label + headline are inside the safe area, and every device keeps at least 90px from them.
- Devices overlap only where B layers them.

**Headline sizing**

- The header headline is one line; the search headline is two lines.
- Sizes come from Chrome-measured widths per locale (the `EM` table). Each locale fills the same width through `typography.localeScale`, and Japanese uses proportional kana (`typography.palt`).
- In the header, English is the limiting locale: about 120px. ja is about 130px, zh-Hans 145px, ko 152px.

**Isolated screens.** Devices bleed off their canvas edges on purpose, so the project exports isolated screens (`connectedCanvas: false`; no deck uses cross-screen elements). Each export is clipped to its own screen. Switching left the screenshot decks unchanged, apart from ±1-level anti-aliasing noise that also differs between two runs of the same export.

**Commands and outputs**

- `npm run creative-concepts`: builds the overlays and writes presentation boards (ja; `-- --locales ja,en,…` for more) to `exports/latest/creative-concepts/<locale>/`. Each `variant-<key>.png` board shows the header and search, both full and safe-area-only; `overview.png` shows both variants, and `renders/` holds the raw files.
- `npm run release` keeps that folder. It also writes every variant for all locales to `exports/latest/creative/<locale>/`:
  - `header-3840x1646-<variant>.png` and `search-3840x2560-<variant>.png`
  - `…-safe-outline.png` and `…-safe-crop.png` for each
  - `contact-sheet.png`, one sheet for all locales

**After the pick**

1. `node scripts/lib/seed-creatives.mjs --only <a-side-by-side|b-layered>`. Each deck then has one slide, and the outputs drop the concept suffix (`header-3840x1646.png`, `search-3840x2560.png`).
2. `npm run release`.

**Assets** (`scripts/build-creative-overlays.mjs`; runs in release, `creative-concepts` and before `npm run dev`; output is gitignored)

- `public/screenshots/creative/duo-open/<locale>.png`: the Duo inner-landscape capture framed in Apple's bezel, with a soft shadow.
- `public/screenshots/creative/marks/accent.png`: the red accent swatch.
- Rounded UI panels can still be defined in `scripts/lib/creative-assets.mjs` (`PANELS`); none are used now.

**Editor extensions** (template changes, all small)

- Image overlay `src` accepts `{locale}`.
- Slide `typography` gained `captionAlign`, `localeScale` and `palt`.
- Image overlays may overflow their screen like devices do; isolated screens clip them.
- The exporter's "screenshot never finished rendering" check ignores image areas that a clipping ancestor hides. Before, a neighbouring slide's bleeding device raised false warnings.

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
