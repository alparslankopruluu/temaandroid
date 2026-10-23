// Minimal headless Chrome driver over the DevTools protocol, plus a tiny static file server.
// Shared by the loop renderer and the store creative composer; no npm dependencies.
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { existsSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

const mime = {
  ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".css": "text/css",
  ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".mp4": "video/mp4", ".json": "application/json",
};

/// `resolve(urlPath)` maps a request path to a file, or returns null for 404.
export async function serve(resolve) {
  const server = createServer(async (request, response) => {
    const url = decodeURIComponent(new URL(request.url, "http://x").pathname);
    const file = resolve(url);
    if (!file || !existsSync(file)) { response.writeHead(404).end(); return; }
    response.writeHead(200, { "content-type": mime[path.extname(file).toLowerCase()] ?? "application/octet-stream" });
    response.end(await readFile(file));
  });
  await new Promise((done) => server.listen(0, "127.0.0.1", done));
  return { origin: `http://127.0.0.1:${server.address().port}`, close: () => server.close() };
}

export async function launch({ width, height, chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" }) {
  const profile = await mkdtemp(path.join(tmpdir(), "sm-chrome-"));
  const browser = spawn(chrome, [
    "--headless=new", "--remote-debugging-port=0", `--user-data-dir=${profile}`,
    "--disable-gpu-vsync", "--hide-scrollbars", "--mute-audio", "--font-render-hinting=none", "about:blank",
  ], { stdio: ["ignore", "ignore", "pipe"] });
  const endpoint = await new Promise((resolve, reject) => {
    let buffer = "";
    browser.stderr.on("data", (chunk) => {
      buffer += chunk;
      const match = buffer.match(/DevTools listening on (ws:\/\/\S+)/);
      if (match) resolve(match[1]);
    });
    browser.on("exit", () => reject(new Error("Chrome exited before DevTools was ready")));
  });
  const socket = new WebSocket(endpoint);
  await new Promise((resolve) => socket.addEventListener("open", resolve, { once: true }));
  let nextID = 0;
  const pending = new Map();
  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id);
      pending.delete(message.id);
      message.error ? reject(new Error(message.error.message)) : resolve(message.result);
    }
  });
  const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
    const id = ++nextID;
    pending.set(id, { resolve, reject });
    socket.send(JSON.stringify({ id, method, params, sessionId }));
  });
  const { targetId } = await send("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true });
  await send("Page.enable", {}, sessionId);
  const page = {
    send: (method, params) => send(method, params, sessionId),
    async resize(w, h) {
      await send("Emulation.setDeviceMetricsOverride", { width: w, height: h, deviceScaleFactor: 1, mobile: false }, sessionId);
    },
    async goto(url) {
      await send("Page.navigate", { url }, sessionId);
      // Wait for load plus fonts and images so captures never show fallbacks.
      for (let attempt = 0; attempt < 200; attempt++) {
        const ready = await page.evaluate("document.readyState === 'complete' && document.fonts.status === 'loaded' && [...document.images].every((i) => i.complete)");
        if (ready) return;
        await new Promise((resolve) => setTimeout(resolve, 50));
      }
      throw new Error(`timed out loading ${url}`);
    },
    async evaluate(expression) {
      const result = await send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true }, sessionId);
      if (result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description ?? "evaluation failed");
      return result.result.value;
    },
    async screenshot(format = "png", quality) {
      const { data } = await send("Page.captureScreenshot", { format, quality, captureBeyondViewport: false }, sessionId);
      return Buffer.from(data, "base64");
    },
  };
  await page.resize(width, height);
  return {
    page,
    async close() {
      socket.close();
      const exited = new Promise((resolve) => browser.once("exit", resolve));
      browser.kill();
      await exited;
      await rm(profile, { recursive: true, force: true, maxRetries: 5 });
    },
  };
}
