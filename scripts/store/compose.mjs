#!/usr/bin/env node
// Composes App Store screenshots with headless Chrome so every script (Arabic, Hindi, Thai, CJK)
// is shaped correctly with system fonts. Inputs are real simulator captures plus scene stills.
//
//   node scripts/store/compose.mjs --raw DIR --out DIR [--locales en-US,tr] [--size 1290x2796]
//
// DIR layout: <raw>/<locale>/{01-discover,02-cards,03-editor,04-video,05-nightstand,06-halloween}.png
import { mkdir, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launch, serve } from "../lib/chrome.mjs";
import { CAPTIONS } from "./captions.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "../..");
const args = process.argv.slice(2);
const option = (name, fallback) => {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : fallback;
};
const rawDir = path.resolve(option("--raw", ""));
const outDir = path.resolve(option("--out", ""));
const [width, height] = option("--size", "1290x2796").split("x").map(Number);
const locales = option("--locales", Object.keys(CAPTIONS).join(",")).split(",");

// Each shot: which capture fills the phone, which scene tints the background, and the copy key.
const SHOTS = [
  { file: "lock:midnight", scene: "midnight", key: "move" },
  { file: "04-video", scene: "abyss", key: "video" },
  { file: "06-halloween", scene: "halloween-moon", key: "halloween" },
  { file: "02-cards", scene: "aurora", key: "loops" },
  { file: "03-editor", scene: "reef", key: "touch" },
  { file: "05-nightstand", scene: "midnight", key: "nightstand" },
  { file: "01-discover", scene: "neon-rain", key: "discover" },
  { file: "lock:event-horizon", scene: "event-horizon", key: "new" },
];

// Pages are served from the same origin as their images; a data: page may not load local images.
const pagesDir = path.join(outDir, ".pages");
await mkdir(pagesDir, { recursive: true });
const server = await serve((url) => {
  if (url.startsWith("/raw/")) return path.join(rawDir, url.slice(5));
  if (url.startsWith("/art/")) return path.join(repo, "App/Resources/Assets.xcassets", `${url.slice(5)}.imageset`, "art.png");
  if (url.startsWith("/page/")) return path.join(pagesDir, url.slice(6));
  return null;
});
const browser = await launch({ width, height });
const { page } = browser;

const rtl = (locale) => locale.startsWith("ar");
// system-ui (SF) first: a CJK font earlier in the stack would also draw Latin accents, badly.
const scriptFont = (locale) => ({
  ja: '"Hiragino Sans",', "zh-Hans": '"PingFang SC",', "zh-Hant": '"PingFang TC",', ko: '"Apple SD Gothic Neo",',
  hi: '"Kohinoor Devanagari",', th: "Thonburi,", "ar-SA": '"SF Arabic",',
})[locale] ?? "";
// The locale's own Lock Screen time format: 9:41 in the US, 09:41 in Türkiye; never an AM/PM marker.
const clockText = (locale) => new Intl.DateTimeFormat(locale, { timeStyle: "short" })
  .formatToParts(new Date(2026, 9, 20, 9, 41)).filter((part) => part.type !== "dayPeriod").map((part) => part.value).join("").trim();
const lockScreen = (scene, locale) => `
  <div class="lock">
    <img src="/art/${scene}" alt="">
    <div class="clock"><div class="date">${new Date(2026, 9, 20).toLocaleDateString(locale, { weekday: "long", month: "long", day: "numeric" })}</div><div class="time">${clockText(locale)}</div></div>
    <div class="live">LIVE</div>
    <div class="dock"><span></span><span></span></div>
  </div>`;

function html(shot, locale) {
  // Compose decomposed accents (e.g. Turkish ğ) so the font draws one glyph, not a floating mark.
  const copy = CAPTIONS[locale][shot.key].map((line) => line.normalize("NFC"));
  const screen = shot.file.startsWith("lock:")
    ? lockScreen(shot.file.slice(5), locale)
    : `<img class="shot" src="/raw/${locale}/${shot.file}.png" alt="">`;
  const phoneWidth = Math.round(width * 0.79);
  return `<!doctype html><html lang="${locale}" dir="${rtl(locale) ? "rtl" : "ltr"}"><head><meta charset="utf-8"><style>
  :root { --accent: #c8f56e; }
  * { box-sizing: border-box; margin: 0; }
  html, body { width: ${width}px; height: ${height}px; overflow: hidden; background: #05070a; }
  body { font-family: system-ui, ${scriptFont(locale)} sans-serif; color: #fff; position: relative; }
  .bg { position: absolute; inset: -120px; background: url(/art/${shot.scene}) center/cover; filter: blur(70px) saturate(1.35) brightness(0.55); }
  .shade { position: absolute; inset: 0; background: linear-gradient(180deg, rgba(5,7,10,.55) 0%, rgba(5,7,10,.15) 38%, rgba(5,7,10,.55) 100%); }
  header { position: absolute; top: ${Math.round(height * 0.058)}px; left: 80px; right: 80px; text-align: center; }
  h1 { font-size: ${Math.round(width * 0.098)}px; line-height: 1.04; font-weight: 800; letter-spacing: -0.025em; text-wrap: balance; }
  p { margin-top: 28px; font-size: ${Math.round(width * 0.04)}px; font-weight: 600; color: var(--accent); text-wrap: balance; line-height: 1.2; }
  .phone { position: absolute; left: 50%; transform: translateX(-50%); top: ${Math.round(height * 0.255)}px; width: ${phoneWidth}px; aspect-ratio: 1206 / 2622;
    padding: 22px; border-radius: 160px; background: #0b0d10; box-shadow: 0 0 0 4px #2b3036, 0 60px 140px rgba(0,0,0,.6); }
  .screen { position: relative; width: 100%; height: 100%; border-radius: 138px; overflow: hidden; background: #000; }
  .island { position: absolute; top: 34px; left: 50%; width: 31%; height: 92px; transform: translateX(-50%); border-radius: 60px; background: #000; z-index: 3; }
  .shot { width: 100%; height: 100%; object-fit: cover; display: block; }
  .lock { position: absolute; inset: 0; }
  .lock img { width: 100%; height: 100%; object-fit: cover; }
  .clock { position: absolute; top: 9%; width: 100%; text-align: center; text-shadow: 0 2px 12px rgba(0,0,0,.3); }
  .date { font-size: ${Math.round(phoneWidth * 0.052)}px; font-weight: 600; opacity: .92; }
  .time { font-size: ${Math.round(phoneWidth * 0.27)}px; font-weight: 700; letter-spacing: -0.02em; line-height: 1; font-family: ui-rounded, system-ui, sans-serif; }
  .live { position: absolute; top: 4.6%; left: 7%; font-size: ${Math.round(phoneWidth * 0.028)}px; font-weight: 700; letter-spacing: .08em; padding: 8px 16px; border-radius: 40px; background: rgba(0,0,0,.35); }
  .dock { position: absolute; bottom: 6%; left: 9%; right: 9%; display: flex; justify-content: space-between; }
  .dock span { width: ${Math.round(phoneWidth * 0.13)}px; height: ${Math.round(phoneWidth * 0.13)}px; border-radius: 50%; background: rgba(40,40,40,.45); backdrop-filter: blur(20px); }
  </style></head><body>
    <div class="bg"></div><div class="shade"></div>
    <header><h1>${copy[0]}</h1><p>${copy[1]}</p></header>
    <div class="phone"><div class="screen"><div class="island"></div>${screen}</div></div>
  </body></html>`;
}

for (const locale of locales) {
  if (!CAPTIONS[locale]) throw new Error(`no captions for ${locale}`);
  await mkdir(path.join(outDir, locale), { recursive: true });
  for (const [index, shot] of SHOTS.entries()) {
    if (!shot.file.startsWith("lock:") && !existsSync(path.join(rawDir, locale, `${shot.file}.png`))) {
      throw new Error(`missing capture ${locale}/${shot.file}.png`);
    }
    const pageName = `${locale}-${index + 1}.html`;
    await writeFile(path.join(pagesDir, pageName), html(shot, locale));
    await page.goto(`${server.origin}/page/${pageName}`);
    await writeFile(path.join(outDir, locale, `${String(index + 1).padStart(2, "0")}.png`), await page.screenshot("png"));
  }
  console.log(`composed ${locale}`);
}
await browser.close();
server.close();
