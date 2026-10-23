#!/usr/bin/env node
// Renders ScreenMotion cinematic loops deterministically: headless Chrome draws each frame of
// engine.html at an exact time, ffmpeg encodes a seamless HEVC loop. No npm dependencies.
//
//   node scripts/loops/render.mjs [--only id,id] [--preview] [--out DIR] [--stills DIR]
//
// --preview renders three stills per scene (contact sheet input) instead of full videos.
import { spawn } from "node:child_process";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launch, serve } from "../lib/chrome.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "../..");
const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const option = (name, fallback) => {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : fallback;
};
const only = option("--only", "").split(",").filter(Boolean);
const preview = flag("--preview");
const outDir = path.resolve(option("--out", path.join(repo, "App/Resources/Loops")));
// Stills stay out of the app bundle; they seed catalog artwork for code-only scenes.
const stillDir = path.resolve(option("--stills", path.join(tmpdir(), "screenmotion-loop-stills")));
const FPS = 30;
const SECONDS = 6;
const WIDTH = 1080;
const HEIGHT = 1920;

// Serves the engine and the app's artwork so canvas pixels stay same-origin and readable.
const server = await serve((url) => url.startsWith("/art/")
  ? path.join(repo, "App/Resources/Assets.xcassets", `${url.slice(5)}.imageset`, "art.png")
  : path.join(here, url === "/" ? "engine.html" : url.slice(1)));
const browser = await launch({ width: WIDTH, height: HEIGHT, chrome: option("--chrome", undefined) });
const { page } = browser;
await page.goto(`${server.origin}/`);
const evaluate = (expression) => page.evaluate(expression);
for (let attempt = 0; attempt < 100 && !(await evaluate("typeof window.SM === 'object'")); attempt++) {
  await new Promise((resolve) => setTimeout(resolve, 100));
}

if (option("--eval", "")) {
  // Debug aid: print the value of an expression evaluated inside the engine page.
  console.log(JSON.stringify(await evaluate(option("--eval", ""))));
}
const scenes = (await evaluate("window.SM.ids()")).filter((id) => only.length === 0 || only.includes(id));
await mkdir(outDir, { recursive: true });
const ffmpeg = (argv) => new Promise((resolve, reject) => {
  const child = spawn("ffmpeg", ["-hide_banner", "-loglevel", "error", "-y", ...argv], { stdio: "inherit" });
  child.on("exit", (code) => (code === 0 ? resolve() : reject(new Error(`ffmpeg exited ${code}`))));
});
const grab = async (time, quality = 0.94) => {
  const data = await evaluate(`window.SM.frame(${time}).then(() => document.querySelector('canvas').toDataURL('image/jpeg', ${quality}))`);
  return Buffer.from(data.split(",")[1], "base64");
};

for (const id of scenes) {
  const started = Date.now();
  await evaluate(`window.SM.load(${JSON.stringify(id)})`);
  if (preview) {
    for (const [index, time] of [0, 2, 4].entries()) {
      await writeFile(path.join(outDir, `${id}-${index}.jpg`), await grab(time, 0.85));
    }
    console.log(`preview ${id}`);
    continue;
  }
  const frames = await mkdtemp(path.join(tmpdir(), `sm-loop-${id}-`));
  const total = FPS * SECONDS;
  for (let frame = 0; frame < total; frame++) {
    // Times stop one frame short of SECONDS: frame 0 follows the last frame, so the loop is seamless.
    await writeFile(path.join(frames, `${String(frame).padStart(4, "0")}.jpg`), await grab(frame / FPS));
  }
  await ffmpeg([
    "-framerate", String(FPS), "-i", path.join(frames, "%04d.jpg"),
    "-c:v", "libx265", "-preset", "slow", "-crf", "23", "-pix_fmt", "yuv420p", "-tag:v", "hvc1",
    // One keyframe per loop: mid-loop I-frames visibly "breathe" on rain and grain.
    "-x265-params", "log-level=error:keyint=180:min-keyint=180:scenecut=0", "-movflags", "+faststart",
    path.join(outDir, `loop-${id}.mp4`),
  ]);
  // The first frame doubles as the catalog artwork for procedural scenes that have no painting.
  await writeFile(path.join(frames, "still.png"), await grab(1.5, 0.95));
  await mkdir(stillDir, { recursive: true });
  await ffmpeg(["-i", path.join(frames, "still.png"), "-vf", "scale=1024:-1", path.join(stillDir, `still-${id}.jpg`)]);
  await rm(frames, { recursive: true, force: true });
  console.log(`loop ${id} ${((Date.now() - started) / 1000).toFixed(1)}s`);
}

await browser.close();
server.close();
