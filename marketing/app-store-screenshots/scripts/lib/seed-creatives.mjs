// Writes the creative-header and creative-search decks into
// app-store-screenshots.json from creative-layout.mjs (one slide per concept,
// or only the chosen ones with --only c2-notebook-page,...), and empties
// creative-universal.
//   node scripts/lib/seed-creatives.mjs [--only <concept-key>[,...]]
import fs from "node:fs";
import path from "node:path";
import { CONCEPTS, DECK } from "./creative-layout.mjs";
import { ROOT } from "./headless-editor.mjs";

const args = process.argv.slice(2);
const i = args.indexOf("--only");
const only = i >= 0 ? args[i + 1].split(",") : null;
const concepts = CONCEPTS.filter((c) => !only || only.includes(c.key));
if (!concepts.length) throw new Error(`No concept matches --only ${only}`);

const F = path.join(ROOT, "app-store-screenshots.json");
const p = JSON.parse(fs.readFileSync(F, "utf8"));
for (const format of ["header", "search"]) {
  // Each build() checks its own layout (text inside the safe area, gaps, no overlaps).
  p.slidesByDevice[DECK[format]] = concepts.map((c) => c.build(format));
}
p.slidesByDevice["creative-universal"] = [];
// Creative devices bleed off their canvas edges on purpose. Isolated screens
// clip each export to its own screen, so a bleed never leaks into the next
// slide. No deck in this project uses cross-screen elements.
p.connectedCanvas = false;
fs.writeFileSync(F, JSON.stringify(p, null, 2) + "\n");
console.log(`seeded ${concepts.map((c) => c.key).join(", ")} into creative-header and creative-search`);
