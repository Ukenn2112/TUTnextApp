// Shared specs for the creative-asset overlays (built by build-creative-overlays.mjs,
// placed by creative-layout.mjs).

// Open iPhone Duo framed in Apple's bezel (inner display, landscape).
export const DUOS = {
  "duo-open": { src: "duo-inner/landscape/{locale}/01.png", bezel: "duo-inner-landscape.png", w: 3093, h: 2247 },
};
export const DUO_PAD = 260;        // shadow margin around a framed Duo PNG, in bezel pixels
// UI panels (rounded crops of captures). None in the current direction.
export const PANELS = {};
export const PANEL_PAD = 200;
export const IPHONE_ASPECT = 1470 / 3000; // public/frames/iphone-portrait.png (Apple's iPhone bezel)
