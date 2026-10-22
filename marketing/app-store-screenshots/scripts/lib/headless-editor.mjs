// Drives the real editor UI in headless Google Chrome (Playwright) so exports use
// the editor's own render + PNG pipeline. The project is served to the page from
// memory (route mock on /api/project, like the template's e2e tests), so a
// headless run never rewrites app-store-screenshots.json and never conflicts with
// an editor tab you have open.
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import { createServer } from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");

export function readProject() {
  return JSON.parse(readFileSync(path.join(ROOT, "app-store-screenshots.json"), "utf8"));
}

const freePort = () =>
  new Promise((resolve, reject) => {
    const server = createServer();
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
  });

async function probe(url) {
  try {
    const res = await fetch(new URL("/api/project", url), { signal: AbortSignal.timeout(3000) });
    if (!res.ok) return false;
    const json = await res.json();
    return json && json.ok === true;
  } catch {
    return false;
  }
}

/**
 * Use the editor at `url` if one answers there; otherwise start `next dev` on a
 * free port. Returns { url, stop }.
 */
export async function ensureServer(url) {
  if (url) {
    if (!(await probe(url))) throw new Error(`No editor answering at ${url}`);
    return { url, stop: async () => {} };
  }
  for (const candidate of ["http://localhost:3000", "http://localhost:3001"]) {
    if (await probe(candidate)) {
      const res = await fetch(new URL("/api/project", candidate));
      const { state } = await res.json();
      if (state?.appName === readProject().appName) return { url: candidate, stop: async () => {} };
    }
  }
  const port = await freePort();
  const child = spawn(process.execPath, [path.join(ROOT, "node_modules/next/dist/bin/next"), "dev", "-p", String(port)], {
    cwd: ROOT,
    stdio: ["ignore", "pipe", "pipe"],
    detached: true,
    env: { ...process.env, NEXT_TELEMETRY_DISABLED: "1" },
  });
  let log = "";
  child.stdout.on("data", (d) => (log += d));
  child.stderr.on("data", (d) => (log += d));
  const started = `http://localhost:${port}`;
  const deadline = Date.now() + 120_000;
  while (!(await probe(started))) {
    if (child.exitCode !== null) throw new Error(`next dev exited early:\n${log}`);
    if (Date.now() > deadline) throw new Error(`next dev did not start in time:\n${log}`);
    await new Promise((r) => setTimeout(r, 500));
  }
  return {
    url: started,
    stop: async () => {
      try { process.kill(-child.pid, "SIGTERM"); } catch {}
    },
  };
}

export async function launchBrowser({ headed = false } = {}) {
  // Installed Google Chrome, as the template's e2e suite uses.
  return chromium.launch({ channel: "chrome", headless: !headed });
}

/** Deck-level state for one device: orientation follows the deck. */
export function stateForDevice(project, device, locales) {
  const useLocales = locales?.length ? locales : project.locales;
  return {
    ...project,
    device,
    orientation: device.endsWith("-landscape") ? "landscape" : "portrait",
    locales: useLocales,
    locale: useLocales[0],
  };
}

/**
 * Open the editor with `state`, optionally apply a saved Style Lab look, click
 * "Export bundle" and save the zip to `zipPath`. Returns the final state the
 * page autosaved (e.g. with the look applied).
 */
export async function exportBundle({ browser, url, state, lookId, zipPath, log = console.log }) {
  const context = await browser.newContext({ acceptDownloads: true, viewport: { width: 1600, height: 1000 } });
  const store = { state };
  await context.route("**/api/project", async (route) => {
    if (route.request().method() === "POST") store.state = JSON.parse(route.request().postData());
    await route.fulfill({ json: { ok: true, state: store.state }, headers: { etag: '"headless"' } });
  });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  try {
    await page.goto(url, { waitUntil: "domcontentloaded" });
    const exportButton = page.getByRole("button", { name: "Export bundle", exact: true });
    await exportButton.waitFor({ state: "visible", timeout: 120_000 });

    if (lookId) {
      const look = (state.savedLooks || []).find((l) => l.id === lookId || l.name === lookId);
      if (!look) throw new Error(`No saved look "${lookId}" in app-store-screenshots.json`);
      await page.getByRole("button", { name: "Style Lab", exact: true }).click();
      await page.getByRole("button", { name: `Apply saved look ${look.name}`, exact: true }).click();
      await page.getByRole("dialog").waitFor({ state: "hidden", timeout: 10_000 });
      log(`  applied look ${look.name}`);
    }

    await page.waitForTimeout(800);
    const download = page.waitForEvent("download", { timeout: 30 * 60_000 });
    const failure = page
      .getByText(/Export failed|renders failed|Couldn't bundle export|No screens to export/)
      .first()
      .waitFor({ state: "visible", timeout: 30 * 60_000 })
      .then(async () => {
        const text = await page.locator("[data-sonner-toast]").allInnerTexts().catch(() => []);
        throw new Error(`Editor reported an export error: ${text.join(" | ")}`);
      });
    // The loser of the race rejects when the context closes; keep that quiet.
    download.catch(() => {});
    failure.catch(() => {});
    await exportButton.click();
    const file = await Promise.race([download, failure]);
    await file.saveAs(zipPath);
    const warnings = await page.locator("[data-sonner-toast]").allInnerTexts().catch(() => []);
    for (const w of warnings) if (!/^Exported/.test(w.trim())) log(`  editor notice: ${w.replace(/\s+/g, " ").trim()}`);
    if (errors.length) log(`  page errors: ${errors.join(" | ")}`);
    return store.state;
  } finally {
    await context.close();
  }
}
