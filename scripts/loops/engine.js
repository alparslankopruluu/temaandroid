// ScreenMotion cinematic loop engine.
// Every motion is a periodic function of p = t / LOOP, and every particle wraps an integer
// number of times per loop, so the last frame flows into the first without a seam.
"use strict";

const W = 1080, H = 1920, LOOP = 6, TAU = Math.PI * 2;
const canvas = document.querySelector("canvas");
const mainCtx = canvas.getContext("2d");
// Effects draw through `ctx`; additive() points it at an offscreen layer while a glow pass is built.
let ctx = mainCtx;
const layer = Object.assign(document.createElement("canvas"), { width: W, height: H });
const layerCtx = layer.getContext("2d");
const buffer = Object.assign(document.createElement("canvas"), { width: W, height: H });
const bctx = buffer.getContext("2d");
const auroraCanvas = Object.assign(document.createElement("canvas"), { width: W / 4, height: H / 4 });

// ---------- helpers ----------
const frac = (x) => x - Math.floor(x);
const wave = (p, cycles = 1, phase = 0) => Math.sin(TAU * (p * cycles + phase));
function rng(seed) {
  return () => {
    seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const images = {};
const loadImage = (name) => images[name] ?? (images[name] = new Promise((resolve, reject) => {
  const image = new Image();
  image.onload = () => resolve(image);
  image.onerror = reject;
  image.src = `/art/${name}`;
}));

/// Draws artwork covering the 9:16 frame; returns a mapper from artwork (u, v) to canvas pixels.
function cover(image, cam = { s: 1, x: 0, y: 0 }) {
  const scale = Math.max(W / image.width, H / image.height) * cam.s;
  const w = image.width * scale, h = image.height * scale;
  const left = (W - w) / 2 + cam.x, top = (H - h) / 2 + cam.y;
  ctx.drawImage(image, left, top, w, h);
  return (u, v) => [left + u * w, top + v * h];
}
/// A slow breathing camera: scale and drift return exactly to their start each loop.
const camera = (p, amount = 1, phase = 0) => ({
  s: 1.06 + 0.014 * amount * wave(p, 1, phase),
  x: 12 * amount * wave(p, 1, phase + 0.25),
  y: 7 * amount * wave(p, 1, phase),
});

/// Light adds onto the frame. Blurred passes are drawn sharp on a layer and blurred once:
/// blurring hundreds of individual strokes exhausts the GPU context and silently blanks the canvas.
function additive(draw, blur = 0) {
  if (!blur || ctx !== mainCtx) {
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    draw();
    ctx.restore();
    return;
  }
  layerCtx.save();
  layerCtx.clearRect(0, 0, W, H);
  layerCtx.globalCompositeOperation = "lighter";
  ctx = layerCtx;
  try { draw(); } finally { ctx = mainCtx; layerCtx.restore(); }
  mainCtx.save();
  mainCtx.globalCompositeOperation = "lighter";
  mainCtx.filter = `blur(${blur}px)`;
  mainCtx.drawImage(layer, 0, 0);
  mainCtx.restore();
}
function glow(x, y, r, color, alpha = 1) {
  const g = ctx.createRadialGradient(x, y, 0, x, y, r);
  g.addColorStop(0, color.replace("A", alpha));
  g.addColorStop(0.35, color.replace("A", alpha * 0.45));
  g.addColorStop(1, color.replace("A", 0));
  ctx.fillStyle = g;
  ctx.fillRect(x - r, y - r, r * 2, r * 2);
}
function rays(x, y, p, { count = 9, length = 1900, spread = 0.9, angle = Math.PI / 2, color = "rgba(255,214,150,A)", alpha = 0.16, width = 0.08 } = {}) {
  additive(() => {
    for (let i = 0; i < count; i++) {
      const a = angle - spread / 2 + (spread * (i + 0.5)) / count + 0.03 * wave(p, 1, i * 0.21);
      const strength = alpha * (0.55 + 0.45 * wave(p, 1, i * 0.37));
      const half = width * (0.6 + 0.4 * wave(p, 1, i * 0.53 + 0.1));
      const g = ctx.createLinearGradient(x, y, x + Math.cos(a) * length, y + Math.sin(a) * length);
      g.addColorStop(0, color.replace("A", strength));
      g.addColorStop(1, color.replace("A", 0));
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + Math.cos(a - half) * length, y + Math.sin(a - half) * length);
      ctx.lineTo(x + Math.cos(a + half) * length, y + Math.sin(a + half) * length);
      ctx.closePath();
      ctx.fill();
    }
  }, 22);
}
/// Particles that drift or rise; `cycles` is an integer so each one wraps cleanly.
function particles(p, { seed = 1, count = 60, cycles = 1, dir = -1, sway = 30, size = [2, 6], area = [0, 0, W, H], color = "rgba(255,240,200,A)", alpha = [0.3, 0.9], twinkle = 0, glowSize = 3, ring = false } = {}) {
  const random = rng(seed);
  additive(() => {
    for (let i = 0; i < count; i++) {
      const x0 = random(), y0 = random(), r = size[0] + random() * (size[1] - size[0]);
      // Speed is a whole number of passes per loop (signed by direction), or particles would not return home.
      const c = Math.sign(dir || 1) * Math.max(1, Math.round(Math.abs(dir) * cycles * (0.6 + random() * 0.8)));
      const ph = random();
      const y = area[1] + frac(y0 + p * c) * area[3];
      const x = area[0] + x0 * area[2] + sway * wave(p, 1 + (i % 2), ph);
      const a = alpha[0] + (alpha[1] - alpha[0]) * (twinkle ? 0.5 + 0.5 * wave(p, twinkle, ph) : random());
      // Fade at the wrap edges so particles never pop in or out.
      const edge = Math.min(1, frac(y0 + p * c) * 8, (1 - frac(y0 + p * c)) * 8);
      if (ring) {
        ctx.strokeStyle = color.replace("A", a * edge);
        ctx.lineWidth = 1.6;
        ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.stroke();
        glow(x - r * 0.3, y - r * 0.3, r * 0.6, "rgba(255,255,255,A)", a * edge * 0.6);
      } else {
        glow(x, y, r * glowSize, color, a * edge);
      }
    }
  });
}
function rain(p, { seed = 7, count = 380, angle = 0.12, length = [40, 110], cycles = 5, alpha = 0.22, color = "rgba(200,220,255,A)" } = {}) {
  const random = rng(seed);
  ctx.save();
  ctx.lineCap = "round";
  for (let i = 0; i < count; i++) {
    const x0 = random(), y0 = random(), len = length[0] + random() * (length[1] - length[0]);
    const c = cycles + Math.floor(random() * 3);
    const y = frac(y0 + p * c) * (H + 300) - 150;
    const x = x0 * (W + 300) - 150 + y * angle;
    const depth = 0.4 + random() * 0.6;
    ctx.strokeStyle = color.replace("A", alpha * depth);
    ctx.lineWidth = 1 + depth * 1.6;
    ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x - angle * len, y - len); ctx.stroke();
  }
  ctx.restore();
}
/// Light streaks rushing outward from a vanishing point, as if the camera travels along the road.
function speedStreaks(vx, vy, p, { seed = 3, count = 70, cycles = 3, color = "rgba(255,230,190,A)", alpha = 0.32, minAngle = 0.15, maxAngle = Math.PI - 0.15 } = {}) {
  const random = rng(seed);
  additive(() => {
    ctx.lineCap = "round";
    for (let i = 0; i < count; i++) {
      const a = minAngle + random() * (maxAngle - minAngle);
      const d = frac(random() + p * (cycles + Math.floor(random() * 2)));
      const near = d * d;
      const r0 = 80 + near * 1500, r1 = r0 + 40 + near * 260;
      ctx.strokeStyle = color.replace("A", alpha * Math.min(1, d * 3) * (1 - d));
      ctx.lineWidth = 1 + near * 5;
      ctx.beginPath();
      ctx.moveTo(vx + Math.cos(a) * r0, vy + Math.sin(a) * r0);
      ctx.lineTo(vx + Math.cos(a) * r1, vy + Math.sin(a) * r1);
      ctx.stroke();
    }
  }, 1.5);
}
/// Horizontal slice displacement: water ripple, reflections and heat haze.
function shimmer(y0, y1, p, { amp = 6, freq = 0.035, cycles = 2, slice = 4, growth = 1 } = {}) {
  bctx.drawImage(canvas, 0, 0);
  for (let y = Math.max(0, y0); y < Math.min(H, y1); y += slice) {
    const depth = (y - y0) / Math.max(1, y1 - y0);
    const dx = amp * (1 + depth * growth) * Math.sin(TAU * p * cycles + y * freq);
    ctx.drawImage(buffer, 0, y, W, slice, dx, y, W, slice);
  }
}
function stars(p, { seed = 11, count = 160, area = [0, 0, W, H * 0.6], size = [0.6, 2.2], twinkle = 2, color = "rgba(255,255,255,A)" } = {}) {
  const random = rng(seed);
  additive(() => {
    for (let i = 0; i < count; i++) {
      const x = area[0] + random() * area[2], y = area[1] + random() * area[3];
      const r = size[0] + random() * (size[1] - size[0]);
      const a = 0.25 + 0.75 * (0.5 + 0.5 * wave(p, twinkle, random()));
      glow(x, y, r * 3.5, color, a);
    }
  });
}
/// One streak crossing during a window of the loop; outside the window nothing is drawn.
function shootingStar(p, { start = 0.2, span = 0.12, from = [200, 300], to = [800, 620], color = "rgba(255,255,255,A)" } = {}) {
  const k = (p - start) / span;
  if (k < 0 || k > 1) return;
  const x = from[0] + (to[0] - from[0]) * k, y = from[1] + (to[1] - from[1]) * k;
  const tail = 0.18;
  const tx = x - (to[0] - from[0]) * tail, ty = y - (to[1] - from[1]) * tail;
  additive(() => {
    const g = ctx.createLinearGradient(tx, ty, x, y);
    g.addColorStop(0, color.replace("A", 0));
    g.addColorStop(1, color.replace("A", Math.sin(Math.PI * k)));
    ctx.strokeStyle = g; ctx.lineWidth = 3; ctx.lineCap = "round";
    ctx.beginPath(); ctx.moveTo(tx, ty); ctx.lineTo(x, y); ctx.stroke();
    glow(x, y, 18, color, Math.sin(Math.PI * k));
  }, 0.5);
}
function caustics(p, { y0 = 0, y1 = H * 0.45, count = 14, color = "rgba(160,255,240,A)", alpha = 0.08 } = {}) {
  additive(() => {
    ctx.lineWidth = 3;
    for (let i = 0; i < count; i++) {
      ctx.strokeStyle = color.replace("A", alpha * (0.6 + 0.4 * wave(p, 1, i * 0.17)));
      ctx.beginPath();
      for (let x = -20; x <= W + 20; x += 20) {
        const y = y0 + ((i + 0.5) / count) * (y1 - y0) + 18 * Math.sin(x * 0.012 + TAU * (p * 2 + i * 0.13)) + 10 * Math.sin(x * 0.031 - TAU * p + i);
        x === -20 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
      }
      ctx.stroke();
    }
  }, 6);
}
function tint(color, alpha) {
  ctx.save();
  ctx.globalCompositeOperation = "soft-light";
  ctx.fillStyle = color.replace("A", alpha);
  ctx.fillRect(0, 0, W, H);
  ctx.restore();
}
function finish(frameIndex, { vignette = 0.5, grain = 0.05 } = {}) {
  const g = ctx.createRadialGradient(W / 2, H * 0.5, H * 0.25, W / 2, H * 0.5, H * 0.75);
  g.addColorStop(0, "rgba(0,0,0,0)");
  g.addColorStop(1, `rgba(0,0,0,${vignette})`);
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, W, H);
  // Fine film grain keeps gradients from banding after HEVC compression.
  const random = rng(1000 + frameIndex);
  ctx.save();
  ctx.globalAlpha = grain;
  for (let i = 0; i < 2600; i++) {
    const v = random() > 0.5 ? 255 : 0;
    ctx.fillStyle = `rgb(${v},${v},${v})`;
    ctx.fillRect(random() * W, random() * H, 2, 2);
  }
  ctx.restore();
}

// ---------- scenes painted from the app's artwork ----------
const sunset = "rgba(255,196,120,A)";
const scenes = {
  async midnight(p, f) {
    const [bg, fg] = await Promise.all([loadImage("midnight-background"), loadImage("midnight-foreground")]);
    cover(bg, camera(p, 1.6));
    shimmer(H * 0.62, H, p, { amp: 3, freq: 0.05, cycles: 3 });
    const map = cover(fg, camera(p, 0.5));
    additive(() => {
      for (const [u, v] of [[0.45, 0.64], [0.87, 0.64]]) {
        const [x, y] = map(u, v);
        glow(x, y, 120 + 16 * wave(p, 2), "rgba(255,40,40,A)", 0.55 + 0.15 * wave(p, 2));
        glow(x, y + 260, 70, "rgba(255,30,30,A)", 0.18 + 0.06 * wave(p, 2, 0.3));
      }
    }, 2);
    rain(p, { count: 420, alpha: 0.2 });
    finish(f, { vignette: 0.55 });
  },
  async motorcycle(p, f) {
    const map = cover(await loadImage("motorcycle"), camera(p, 1));
    const [sx, sy] = map(0.75, 0.33);
    rays(sx, sy, p, { angle: Math.PI * 0.62, spread: 1.4, alpha: 0.13 });
    additive(() => glow(sx, sy, 300 + 30 * wave(p), sunset, 0.35), 4);
    const [vx, vy] = map(0.55, 0.62);
    speedStreaks(vx, vy, p, { alpha: 0.28, minAngle: 0.25, maxAngle: Math.PI - 0.25 });
    particles(p, { seed: 4, count: 40, cycles: 1, dir: 1, area: [0, H * 0.3, W, H * 0.7], color: sunset, size: [1, 3], glowSize: 4 });
    finish(f);
  },
  async bicycle(p, f) {
    const map = cover(await loadImage("bicycle"), camera(p, 0.8));
    const [sx, sy] = map(0.14, 0.32);
    rays(sx, sy, p, { angle: Math.PI * 0.32, spread: 1.2, alpha: 0.16, count: 11 });
    additive(() => glow(sx, sy, 260 + 30 * wave(p), sunset, 0.4), 4);
    particles(p, { seed: 5, count: 70, cycles: 1, dir: -1, sway: 50, color: "rgba(255,226,160,A)", size: [1.2, 3.2], glowSize: 4, twinkle: 2 });
    finish(f);
  },
  async tractor(p, f) {
    const map = cover(await loadImage("tractor"), camera(p, 0.8));
    const [sx, sy] = map(0.15, 0.36);
    rays(sx, sy, p, { angle: Math.PI * 0.18, spread: 1.0, alpha: 0.15 });
    additive(() => glow(sx, sy, 280, sunset, 0.38 + 0.05 * wave(p)), 4);
    shimmer(H * 0.36, H * 0.48, p, { amp: 2.5, freq: 0.09, cycles: 3 });
    particles(p, { seed: 6, count: 110, cycles: 1, dir: -1, sway: 80, area: [0, H * 0.35, W, H * 0.65], color: "rgba(255,210,140,A)", size: [1, 3.5], glowSize: 3.5, alpha: [0.15, 0.6] });
    finish(f);
  },
  async tank(p, f) {
    const map = cover(await loadImage("tank"), camera(p, 0.7));
    const [sx, sy] = map(0.09, 0.42);
    additive(() => glow(sx, sy, 340, sunset, 0.4 + 0.05 * wave(p)), 6);
    shimmer(H * 0.42, H * 0.62, p, { amp: 3, freq: 0.11, cycles: 4, slice: 3 });
    particles(p, { seed: 8, count: 150, cycles: 2, dir: 0.4, sway: 140, area: [0, H * 0.45, W, H * 0.55], color: "rgba(230,190,130,A)", size: [1, 4], glowSize: 2.5, alpha: [0.1, 0.45] });
    finish(f, { vignette: 0.55 });
  },
  async bus(p, f) {
    const map = cover(await loadImage("bus"), camera(p, 0.9));
    const [sx, sy] = map(0.16, 0.35);
    rays(sx, sy, p, { angle: Math.PI * 0.3, spread: 1.1, alpha: 0.13 });
    additive(() => glow(sx, sy, 300, sunset, 0.38 + 0.05 * wave(p)), 4);
    shimmer(H * 0.25, H * 0.5, p, { amp: 2.2, freq: 0.04, cycles: 2, growth: 0.5 });
    const [vx, vy] = map(0.62, 0.62);
    speedStreaks(vx, vy, p, { alpha: 0.2, minAngle: 0.4, maxAngle: Math.PI - 0.6 });
    finish(f);
  },
  async truck(p, f) {
    const map = cover(await loadImage("truck"), camera(p, 0.8));
    additive(() => {
      for (const u of [0.29, 0.52]) {
        const [x, y] = map(u, 0.69);
        glow(x, y, 190 + 20 * wave(p, 2, u), "rgba(255,236,190,A)", 0.62);
        glow(x, y + 300, 90, "rgba(255,220,160,A)", 0.22 + 0.06 * wave(p, 2, u));
      }
    }, 3);
    const [lx, ly] = map(0.4, 0.69);
    rays(lx, ly, p, { angle: Math.PI / 2, spread: 1.3, alpha: 0.1, count: 7, color: "rgba(255,240,200,A)", length: 900 });
    stars(p, { seed: 2, count: 90, area: [0, 0, W, H * 0.28], size: [0.5, 1.5] });
    speedStreaks(lx, ly, p, { alpha: 0.22, minAngle: 0.3, maxAngle: Math.PI - 0.3, color: "rgba(200,220,255,A)" });
    finish(f, { vignette: 0.6 });
  },
  async helicopter(p, f) {
    const map = cover(await loadImage("helicopter"), camera(p, 1.1));
    const [sx, sy] = map(0.8, 0.31);
    rays(sx, sy, p, { angle: Math.PI * 0.72, spread: 1.2, alpha: 0.12 });
    additive(() => glow(sx, sy, 260, sunset, 0.35 + 0.05 * wave(p)), 4);
    shimmer(H * 0.5, H, p, { amp: 3, freq: 0.045, cycles: 2 });
    particles(p, { seed: 9, count: 26, cycles: 1, dir: 0.2, sway: 220, area: [0, H * 0.55, W, H * 0.4], color: "rgba(255,240,230,A)", size: [40, 90], glowSize: 1.6, alpha: [0.05, 0.12] });
    finish(f);
  },
  async airplane(p, f) {
    const map = cover(await loadImage("airplane"), camera(p, 0.6));
    const [sx, sy] = map(0.25, 0.45);
    additive(() => glow(sx, sy, 380 + 40 * wave(p), sunset, 0.42), 6);
    rays(sx, sy, p, { angle: 0, spread: TAU, count: 16, alpha: 0.08, length: 1300 });
    particles(p, { seed: 12, count: 34, cycles: 1, dir: 1, sway: 0, area: [0, H * 0.58, W, H * 0.42], color: "rgba(255,225,215,A)", size: [50, 120], glowSize: 1.4, alpha: [0.04, 0.1] });
    additive(() => {
      const [x, y] = map(0.62, 0.53);
      glow(x, y, 26, "rgba(255,60,60,A)", 0.5 + 0.5 * Math.max(0, wave(p, 3)));
    });
    finish(f);
  },
  async spaceship(p, f) {
    const map = cover(await loadImage("spaceship"), camera(p, 0.9));
    additive(() => {
      for (const u of [0.23, 0.31, 0.4]) {
        const [x, y] = map(u, 0.62);
        glow(x, y, 120 + 30 * wave(p, 4, u), "rgba(255,170,90,A)", 0.55);
        glow(x, y, 46, "rgba(255,240,220,A)", 0.8);
      }
    }, 2);
    stars(p, { seed: 21, count: 120, area: [0, 0, W, H * 0.45] });
    const [vx, vy] = map(0.62, 0.55);
    speedStreaks(vx, vy, p, { alpha: 0.16, color: "rgba(180,220,255,A)", minAngle: -Math.PI, maxAngle: Math.PI });
    finish(f, { vignette: 0.6 });
  },
  async reef(p, f) {
    const map = cover(await loadImage("reef"), camera(p, 1));
    const [sx, sy] = map(0.52, -0.05);
    rays(sx, sy, p, { angle: Math.PI / 2, spread: 0.9, alpha: 0.12, count: 12, color: "rgba(170,255,240,A)" });
    caustics(p);
    shimmer(0, H * 0.4, p, { amp: 2, freq: 0.03, cycles: 2 });
    particles(p, { seed: 13, count: 46, cycles: 1, dir: -1, sway: 20, size: [4, 11], ring: true, color: "rgba(220,255,255,A)", alpha: [0.25, 0.6] });
    particles(p, { seed: 14, count: 120, cycles: 1, dir: 0.5, sway: 40, size: [0.8, 2], color: "rgba(200,255,245,A)", alpha: [0.15, 0.5], glowSize: 2.5 });
    finish(f);
  },
  async jellyfish(p, f) {
    const cam = camera(p, 0.6);
    cam.y += 22 * wave(p, 1, 0.1);
    const map = cover(await loadImage("jellyfish"), cam);
    additive(() => {
      for (const [u, v, r, ph] of [[0.62, 0.46, 360, 0], [0.35, 0.27, 220, 0.4]]) {
        const [x, y] = map(u, v);
        glow(x, y, r * (1 + 0.08 * wave(p, 2, ph)), "rgba(170,150,255,A)", 0.3 + 0.12 * wave(p, 2, ph));
      }
    }, 6);
    const [sx, sy] = map(0.5, -0.05);
    rays(sx, sy, p, { angle: Math.PI / 2, spread: 0.7, alpha: 0.07, color: "rgba(150,200,255,A)" });
    particles(p, { seed: 15, count: 150, cycles: 1, dir: 0.5, sway: 30, size: [0.8, 2.4], color: "rgba(190,210,255,A)", alpha: [0.15, 0.6], glowSize: 3, twinkle: 2 });
    finish(f, { vignette: 0.6 });
  },
  async orbit(p, f) {
    const cam = camera(p, 0.5);
    const map = cover(await loadImage("orbit"), cam);
    additive(() => {
      const [x, y] = map(0.5, 0.66);
      glow(x, y + 14 * wave(p, 1, 0.2), 90, "rgba(255,255,255,A)", 0.2 + 0.08 * wave(p, 2));
    }, 3);
    stars(p, { seed: 31, count: 180, area: [0, 0, W, H * 0.42] });
    shootingStar(p, { start: 0.3, span: 0.1, from: [140, 260], to: [760, 560] });
    finish(f, { vignette: 0.55 });
  },
  async nebula(p, f) {
    const map = cover(await loadImage("nebula"), camera(p, 0.9));
    additive(() => {
      const [x, y] = map(0.53, 0.59);
      glow(x, y, 520 * (1 + 0.06 * wave(p)), "rgba(255,140,220,A)", 0.18 + 0.06 * wave(p, 1, 0.3));
      const [px, py] = map(0.77, 0.62);
      glow(px, py, 160, "rgba(255,210,170,A)", 0.16 + 0.05 * wave(p, 2));
    }, 10);
    stars(p, { seed: 41, count: 220, area: [0, 0, W, H], twinkle: 3 });
    shootingStar(p, { start: 0.62, span: 0.09, from: [900, 300], to: [380, 640] });
    finish(f, { vignette: 0.5 });
  },
  async alpine(p, f) {
    const map = cover(await loadImage("alpine"), camera(p, 0.7));
    const [sx, sy] = map(0.93, 0.33);
    rays(sx, sy, p, { angle: Math.PI * 0.82, spread: 1.0, alpha: 0.12 });
    additive(() => glow(sx, sy, 240, sunset, 0.36 + 0.05 * wave(p)), 4);
    shimmer(H * 0.5, H * 0.8, p, { amp: 4, freq: 0.06, cycles: 2, growth: 1.5 });
    particles(p, { seed: 16, count: 20, cycles: 1, dir: 0.15, sway: 260, area: [0, H * 0.4, W, H * 0.16], color: "rgba(255,250,245,A)", size: [50, 110], glowSize: 1.5, alpha: [0.05, 0.12] });
    finish(f);
  },
  async forest(p, f) {
    const map = cover(await loadImage("forest"), camera(p, 0.8));
    const [sx, sy] = map(0.42, -0.04);
    rays(sx, sy, p, { angle: Math.PI * 0.55, spread: 0.8, alpha: 0.16, count: 10, color: "rgba(255,250,210,A)", width: 0.05 });
    const [wx] = map(0.82, 0.62);
    shimmer(H * 0.55, H * 0.8, p, { amp: 2, freq: 0.2, cycles: 6, slice: 2, growth: 0 });
    particles(p, { seed: 17, count: 90, cycles: 1, dir: 0.3, sway: 60, color: "rgba(240,255,190,A)", size: [1, 3], glowSize: 4, alpha: [0.2, 0.8], twinkle: 3 });
    additive(() => glow(wx, H * 0.7, 160, "rgba(220,255,255,A)", 0.08 + 0.04 * wave(p, 3)), 8);
    finish(f);
  },

  // ---------- fully procedural scenes ----------
  async aurora(p, f) {
    const sky = ctx.createLinearGradient(0, 0, 0, H);
    sky.addColorStop(0, "#010309"); sky.addColorStop(0.4, "#04142a"); sky.addColorStop(0.64, "#0b2b3a"); sky.addColorStop(1, "#01060a");
    ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H);
    stars(p, { seed: 51, count: 300, area: [0, 0, W, H * 0.62] });
    // Curtains are drawn at quarter resolution and scaled up, which gives the soft, smoky edge of real aurora.
    const low = auroraCanvas;
    const l = low.getContext("2d");
    l.clearRect(0, 0, low.width, low.height);
    l.globalCompositeOperation = "lighter";
    const ribbon = (offset, hue, alpha, top, amp) => {
      for (let x = 0; x < low.width; x++) {
        const u = x / low.width;
        const base = low.height * top + amp * Math.sin(TAU * (u * 1.3 + p + offset)) + amp * 0.4 * Math.sin(TAU * (u * 3.1 - 2 * p + offset));
        const intensity = alpha * Math.pow(0.5 + 0.5 * Math.sin(TAU * (u * 5 + p * 2 + offset)) * Math.sin(TAU * (u * 2.2 - p + offset * 2)), 1.6);
        const height = low.height * (0.1 + 0.08 * (0.5 + 0.5 * Math.sin(TAU * (u * 2 + p + offset))));
        const g = l.createLinearGradient(0, base - height, 0, base + 12);
        g.addColorStop(0, `hsla(${hue + 60},90%,70%,0)`);
        g.addColorStop(0.55, `hsla(${hue + 25},95%,62%,${intensity * 0.45})`);
        g.addColorStop(0.92, `hsla(${hue},100%,60%,${intensity})`);
        g.addColorStop(1, `hsla(${hue},100%,60%,0)`);
        l.fillStyle = g;
        l.fillRect(x, base - height, 1.2, height + 12);
      }
    };
    ribbon(0, 138, 0.9, 0.34, 26);
    ribbon(0.37, 152, 0.55, 0.27, 20);
    ribbon(0.71, 290, 0.35, 0.22, 16);
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    ctx.filter = "blur(10px)";
    ctx.imageSmoothingQuality = "high";
    ctx.drawImage(low, 0, 0, W, H);
    ctx.filter = "none";
    ctx.drawImage(low, 0, 0, W, H);
    ctx.restore();
    const ridge = (seed, y, amp, rough, color, rim) => {
      ctx.fillStyle = color;
      ctx.beginPath(); ctx.moveTo(0, H);
      for (let x = 0; x <= W; x += 8) {
        const h = y - amp * Math.pow(Math.abs(Math.sin(x * 0.0021 + seed)), 1.4) - rough * Math.abs(Math.sin(x * 0.019 + seed * 3)) * Math.abs(Math.sin(x * 0.007 + seed));
        ctx.lineTo(x, h);
      }
      ctx.lineTo(W, H); ctx.closePath(); ctx.fill();
      if (rim) { ctx.save(); ctx.globalCompositeOperation = "lighter"; ctx.strokeStyle = rim; ctx.lineWidth = 2; ctx.stroke(); ctx.restore(); }
    };
    ridge(1.3, H * 0.66, 380, 60, "#071823", "rgba(90,255,190,0.12)");
    ridge(4.1, H * 0.68, 180, 40, "#030c12");
    // Pine line along the shore.
    ctx.fillStyle = "#01060a";
    const random = rng(52);
    for (let x = -10; x < W + 10; x += 14 + random() * 16) {
      const h = 40 + random() * 70;
      ctx.beginPath(); ctx.moveTo(x - h * 0.22, H * 0.68); ctx.lineTo(x, H * 0.68 - h); ctx.lineTo(x + h * 0.22, H * 0.68); ctx.fill();
    }
    ctx.save();
    ctx.globalAlpha = 0.5;
    ctx.translate(0, H * 1.36); ctx.scale(1, -1);
    ctx.drawImage(canvas, 0, 0, W, H * 0.68, 0, 0, W, H * 0.68);
    ctx.restore();
    const lake = ctx.createLinearGradient(0, H * 0.68, 0, H);
    lake.addColorStop(0, "rgba(1,8,12,0.2)"); lake.addColorStop(1, "rgba(1,4,8,0.75)");
    ctx.fillStyle = lake; ctx.fillRect(0, H * 0.68, W, H * 0.32);
    shimmer(H * 0.68, H, p, { amp: 3, freq: 0.09, cycles: 2, growth: 2.5 });
    finish(f, { vignette: 0.45, grain: 0.06 });
  },
  async "neon-rain"(p, f) {
    const horizon = H * 0.5, vx = W / 2;
    const sky = ctx.createLinearGradient(0, 0, 0, horizon);
    sky.addColorStop(0, "#07040e"); sky.addColorStop(1, "#2a1238");
    ctx.fillStyle = sky; ctx.fillRect(0, 0, W, horizon);
    // Distant skyline glowing through haze.
    const random = rng(61);
    for (let x = 160; x < W - 160; x += 30 + random() * 40) {
      const h = 160 + random() * 420;
      const g = ctx.createLinearGradient(0, horizon - h, 0, horizon);
      g.addColorStop(0, "#1a1028"); g.addColorStop(1, "#2c1840");
      ctx.fillStyle = g; ctx.fillRect(x, horizon - h, 26 + random() * 40, h);
      for (let wy = horizon - h + 14; wy < horizon - 10; wy += 18) {
        if (random() > 0.55) { ctx.fillStyle = `rgba(255,200,150,${0.25 + 0.2 * wave(p, 1, random())})`; ctx.fillRect(x + 6, wy, 5, 7); }
      }
    }
    additive(() => glow(vx, horizon, 520, "rgba(255,80,170,A)", 0.25), 20);
    // Street in perspective with wet asphalt.
    const road = ctx.createLinearGradient(0, horizon, 0, H);
    road.addColorStop(0, "#1a0f24"); road.addColorStop(1, "#05030a");
    ctx.fillStyle = road; ctx.fillRect(0, horizon, W, H - horizon);
    ctx.strokeStyle = "rgba(255,255,255,0.18)"; ctx.lineWidth = 3;
    for (let i = 0; i < 10; i++) {
      const d0 = frac(i / 10 + p * 2), d1 = d0 + 0.03;
      const y0 = horizon + d0 * d0 * (H - horizon), y1 = horizon + d1 * d1 * (H - horizon);
      ctx.strokeStyle = `rgba(255,255,255,${0.18 * Math.min(1, (1 - d0) * 8)})`;
      ctx.lineWidth = 2 + d0 * 10;
      ctx.beginPath(); ctx.moveTo(vx, y0); ctx.lineTo(vx, y1); ctx.stroke();
    }
    // Side buildings converging to the vanishing point, each with vertical neon signs.
    const signColors = ["rgba(255,50,160,A)", "rgba(50,225,255,A)", "rgba(255,170,50,A)", "rgba(170,90,255,A)"];
    for (const side of [-1, 1]) {
      ctx.fillStyle = "#0b0712";
      ctx.beginPath();
      ctx.moveTo(vx + side * 120, horizon - 60);
      ctx.lineTo(vx + side * 120, horizon + 10);
      ctx.lineTo(vx + side * 620, H);
      ctx.lineTo(vx + side * 620, 0);
      ctx.lineTo(vx + side * 120, horizon - 420);
      ctx.closePath(); ctx.fill();
      for (let i = 0; i < 4; i++) {
        const t = 0.25 + i * 0.2;
        const x = vx + side * (120 + t * 500);
        const top = horizon - 420 * (1 - t) - t * 300, height = 120 + t * 420;
        const color = signColors[(i + (side > 0 ? 2 : 0)) % 4];
        const flicker = i === 2 && side > 0 && frac(p * 3 + 0.5) > 0.9 ? 0.25 : 1;
        additive(() => {
          ctx.fillStyle = color.replace("A", 0.85 * flicker);
          const width = 18 + t * 40;
          ctx.fillRect(x - width / 2, top, width, height);
          ctx.fillStyle = "rgba(0,0,0,0.55)";
          for (let k = 0; k < 4; k++) ctx.fillRect(x - width * 0.3, top + 12 + k * height / 4, width * 0.6, height / 10);
          glow(x, top + height / 2, height * 0.9, color, 0.35 * flicker);
          // Reflection stretched down the wet street.
          const g = ctx.createLinearGradient(0, horizon, 0, H);
          g.addColorStop(0, color.replace("A", 0)); g.addColorStop(0.5, color.replace("A", 0.22 * flicker)); g.addColorStop(1, color.replace("A", 0));
          ctx.fillStyle = g; ctx.fillRect(x - width, horizon + (H - horizon) * t * 0.6, width * 2, (H - horizon) * 0.9);
        }, 2);
      }
    }
    shimmer(horizon + 20, H, p, { amp: 1.4, freq: 0.05, cycles: 3, growth: 1.5 });
    // Head and tail light trails.
    additive(() => {
      for (let i = 0; i < 8; i++) {
        const toward = i % 2 === 0;
        const d = frac(i / 8 + p * (toward ? 2 : 1));
        const y = horizon + d * d * (H - horizon) * 0.95;
        const x = vx + (toward ? 1 : -1) * (30 + d * d * 300);
        const color = toward ? "rgba(255,240,215,A)" : "rgba(255,40,60,A)";
        // Fade in at the horizon and out at the bottom so the wrap is invisible.
        const fade = Math.min(1, d * 5, (1 - d) * 6);
        ctx.strokeStyle = color.replace("A", 0.5 * fade);
        ctx.lineWidth = 3 + d * 14; ctx.lineCap = "round";
        ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(vx + (toward ? 1 : -1) * (30 + Math.pow(Math.max(0, d - 0.12), 2) * 300), horizon + Math.pow(Math.max(0, d - 0.12), 2) * (H - horizon) * 0.95); ctx.stroke();
        glow(x, y, 20 + d * 70, color, 0.6 * fade);
      }
    }, 2);
    additive(() => glow(vx, horizon + 40, 700, "rgba(150,90,255,A)", 0.12), 30);
    rain(p, { count: 560, alpha: 0.24, color: "rgba(220,210,255,A)" });
    finish(f, { vignette: 0.55, grain: 0.06 });
  },
  async abyss(p, f) {
    const sea = ctx.createLinearGradient(0, 0, 0, H);
    sea.addColorStop(0, "#06304f"); sea.addColorStop(0.45, "#03132a"); sea.addColorStop(1, "#000207");
    ctx.fillStyle = sea; ctx.fillRect(0, 0, W, H);
    rays(W / 2, -160, p, { angle: Math.PI / 2, spread: 0.7, alpha: 0.11, color: "rgba(120,210,255,A)", count: 11 });
    particles(p, { seed: 72, count: 140, cycles: 1, dir: 0.3, sway: 20, size: [0.6, 1.6], color: "rgba(160,220,255,A)", alpha: [0.08, 0.35], glowSize: 2.5 });
    const jelly = (cx, cy, size, hue, phase) => {
      const pulse = 0.5 + 0.5 * wave(p, 2, phase);
      const y = cy - 46 * wave(p, 1, phase);
      additive(() => {
        glow(cx, y + size * 0.3, size * 3, `hsla(${hue},100%,60%,A)`, 0.16 + 0.08 * pulse);
        // Tentacles first, so the bell sits on top of them.
        for (let t = 0; t < 11; t++) {
          const sx = cx - size * 0.75 + (t / 10) * size * 1.5;
          ctx.strokeStyle = `hsla(${hue + 15},100%,78%,${0.18 + 0.12 * pulse})`;
          ctx.lineWidth = t % 3 === 0 ? 3 : 1.4;
          ctx.beginPath(); ctx.moveTo(sx, y);
          const length = size * (2.4 + (t % 4) * 0.5);
          for (let k = 1; k <= 40; k++) {
            const s = k / 40;
            ctx.lineTo(sx + size * 0.18 * s * Math.sin(s * 6 + TAU * (p * 2 + phase) + t * 0.7), y + s * length);
          }
          ctx.stroke();
        }
        const rx = size * (1 + 0.1 * pulse), ry = size * (0.75 - 0.1 * pulse);
        const bell = ctx.createRadialGradient(cx, y - ry * 0.4, size * 0.05, cx, y, rx);
        bell.addColorStop(0, `hsla(${hue + 30},100%,92%,0.8)`);
        bell.addColorStop(0.5, `hsla(${hue},100%,70%,0.45)`);
        bell.addColorStop(1, `hsla(${hue},100%,60%,0.1)`);
        ctx.fillStyle = bell;
        ctx.beginPath(); ctx.ellipse(cx, y, rx, ry, 0, Math.PI, 0);
        ctx.quadraticCurveTo(cx, y + ry * 0.35, cx - rx, y); ctx.fill();
        ctx.strokeStyle = `hsla(${hue + 20},100%,85%,0.6)`; ctx.lineWidth = 2.5; ctx.stroke();
      }, 1.2);
    };
    jelly(330, 560, 95, 195, 0.35);
    jelly(820, 1360, 75, 320, 0.7);
    jelly(610, 820, 190, 275, 0);
    particles(p, { seed: 71, count: 240, cycles: 1, dir: 0.4, sway: 30, size: [0.8, 2.6], color: "rgba(120,255,230,A)", alpha: [0.15, 0.9], glowSize: 3.2, twinkle: 3 });
    finish(f, { vignette: 0.6, grain: 0.06 });
  },
  async "event-horizon"(p, f) {
    ctx.fillStyle = "#010103"; ctx.fillRect(0, 0, W, H);
    const cx = W / 2, cy = H * 0.5, hole = 170;
    ctx.save(); ctx.translate(cx, cy); ctx.rotate(0.02 * wave(p)); ctx.translate(-cx, -cy);
    stars(p, { seed: 81, count: 480, area: [-400, -400, W + 800, H + 800], twinkle: 2 });
    ctx.restore();
    // Hot disk texture: every ring turns exactly once per loop, so each streak returns to its own place.
    const diskBand = (start, end) => additive(() => {
      for (let ring = 0; ring < 40; ring++) {
        const r = hole * 1.35 + ring * 13;
        const heat = 1 - ring / 40;
        for (let s = 0; s < 36; s++) {
          const a0 = (TAU / 36) * s + TAU * p;
          if (!(a0 % TAU > start && a0 % TAU < end) && !((a0 % TAU) + TAU > start && (a0 % TAU) + TAU < end)) continue;
          const bright = 0.5 + 0.5 * Math.sin(s * 2.3 + ring * 1.7);
          ctx.strokeStyle = `hsla(${22 + heat * 20},100%,${50 + heat * 35}%,${(0.1 + 0.25 * bright) * heat})`;
          ctx.lineWidth = 9;
          ctx.beginPath(); ctx.ellipse(cx, cy, r * 1.85, r * 0.3, -0.08, a0, a0 + 0.14); ctx.stroke();
        }
      }
    }, 2.5);
    // Light from the far side of the disk, bent over and under the hole.
    additive(() => {
      for (let i = 0; i < 18; i++) {
        const r = hole * 1.12 + i * 7;
        ctx.strokeStyle = `rgba(255,${190 - i * 4},${120 - i * 4},${0.22 * (1 - i / 18) * (0.85 + 0.15 * wave(p, 1, i * 0.05))})`;
        ctx.lineWidth = 7;
        ctx.beginPath(); ctx.arc(cx, cy, r, 0, TAU); ctx.stroke();
      }
    }, 5);
    diskBand(Math.PI, TAU);
    additive(() => glow(cx, cy, 640, "rgba(255,150,70,A)", 0.2 + 0.04 * wave(p)), 16);
    ctx.fillStyle = "#000"; ctx.beginPath(); ctx.arc(cx, cy, hole, 0, TAU); ctx.fill();
    additive(() => {
      ctx.strokeStyle = `rgba(255,236,200,${0.85 + 0.1 * wave(p, 2)})`;
      ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(cx, cy, hole + 4, 0, TAU); ctx.stroke();
    }, 3);
    diskBand(0, Math.PI);
    finish(f, { vignette: 0.35, grain: 0.05 });
  },
  // ---------- Halloween scenes (fully procedural) ----------
  async "halloween-moon"(p, f) {
    const mx = W * 0.5, my = H * 0.5, mr = 360;
    const sky = ctx.createLinearGradient(0, 0, 0, H);
    sky.addColorStop(0, "#030208"); sky.addColorStop(0.28, "#0b0716"); sky.addColorStop(0.48, "#251022");
    sky.addColorStop(0.62, "#4a1d1c"); sky.addColorStop(0.75, "#1c0b10"); sky.addColorStop(1, "#030105");
    ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H);
    stars(p, { seed: 91, count: 130, area: [0, 0, W, H * 0.46], size: [0.4, 1.4], twinkle: 2, color: "rgba(255,236,220,A)" });
    additive(() => {
      glow(mx, my, 1150, "rgba(255,105,40,A)", 0.3);
      glow(mx, my, 600, "rgba(255,150,70,A)", 0.42 + 0.03 * wave(p));
    }, 14);
    // The harvest moon: warm disk, darker maria, reddened toward the horizon.
    ctx.save();
    ctx.beginPath(); ctx.arc(mx, my, mr, 0, TAU); ctx.clip();
    const disk = ctx.createRadialGradient(mx - mr * 0.28, my - mr * 0.32, mr * 0.08, mx, my, mr);
    disk.addColorStop(0, "#ffdc96"); disk.addColorStop(0.5, "#ffa652"); disk.addColorStop(0.88, "#e8682a"); disk.addColorStop(1, "#b5401a");
    ctx.fillStyle = disk; ctx.fillRect(mx - mr, my - mr, mr * 2, mr * 2);
    ctx.globalCompositeOperation = "multiply";
    const random = rng(92);
    for (let i = 0; i < 16; i++) {
      const a = random() * TAU, d = Math.sqrt(random()) * mr * 0.8, r = mr * (0.07 + random() * 0.22);
      glow(mx + Math.cos(a) * d, my + Math.sin(a) * d, r, "rgba(190,90,45,A)", 0.5 + random() * 0.4);
    }
    for (let i = 0; i < 70; i++) {
      const a = random() * TAU, d = Math.sqrt(random()) * mr * 0.92, r = 3 + random() * 13;
      glow(mx + Math.cos(a) * d, my + Math.sin(a) * d, r * 1.6, "rgba(215,130,80,A)", 0.35 + random() * 0.3);
    }
    const low = ctx.createLinearGradient(0, my - mr * 0.2, 0, my + mr);
    low.addColorStop(0, "rgba(160,40,20,0)"); low.addColorStop(1, "rgba(160,40,20,0.75)");
    ctx.fillStyle = low; ctx.fillRect(mx - mr, my - mr, mr * 2, mr * 2);
    ctx.restore();
    additive(() => {
      ctx.strokeStyle = "rgba(255,200,140,0.35)"; ctx.lineWidth = 4;
      ctx.beginPath(); ctx.arc(mx, my, mr - 2, 0, TAU); ctx.stroke();
    }, 4);
    // Thin dark cloud wisps sliding across the face of the moon.
    fogBank(p, { seed: 93, count: 10, y: my + 30, spread: 230, size: [260, 520], drift: 240, color: "rgba(30,10,24,A)", alpha: 0.6, squash: 0.08, blur: 3 });
    // Distant ridge in moonlit haze.
    ctx.fillStyle = "#1e0d16";
    ctx.beginPath(); ctx.moveTo(0, H);
    for (let x = 0; x <= W; x += 8) ctx.lineTo(x, H * 0.705 - 46 * Math.sin(x * 0.0055 + 1) - 22 * Math.sin(x * 0.019 + 2));
    ctx.lineTo(W, H); ctx.closePath(); ctx.fill();
    fogBank(p, { seed: 94, count: 18, y: H * 0.7, spread: 50, size: [200, 380], drift: 220, color: "rgba(235,135,95,A)", alpha: 0.22, squash: 0.22, mode: "screen" });
    // The crooked hill, its haunted house and dead trees.
    const hx = W * 0.6, silhouette = "#0a0509";
    const hill = (x) => H * 0.79 - 340 * Math.exp(-(((x - hx) / 320) ** 4)) - 70 * Math.exp(-(((x - hx - 330) / 110) ** 2)) - 18 * Math.sin(x * 0.013 + 1.1);
    const base = hill(hx) + 6;
    hauntedHouse(p, hx, base, 0.82, silhouette);
    gnarledTree(rng(95), hx + 300, hill(hx + 300) + 10, 300, p, { color: silhouette, lean: 0.25, depth: 6, sway: 0.004 });
    gnarledTree(rng(96), hx - 330, hill(hx - 330) + 10, 230, p, { color: silhouette, lean: -0.3, depth: 6, sway: 0.004 });
    ctx.fillStyle = silhouette;
    ctx.beginPath(); ctx.moveTo(0, H);
    for (let x = 0; x <= W; x += 6) ctx.lineTo(x, hill(x));
    ctx.lineTo(W, H); ctx.closePath(); ctx.fill();
    // Moonlight catching the crest.
    additive(() => {
      ctx.strokeStyle = "rgba(255,140,70,0.16)"; ctx.lineWidth = 3;
      ctx.beginPath();
      for (let x = 160; x <= 980; x += 6) x === 160 ? ctx.moveTo(x, hill(x) + 1) : ctx.lineTo(x, hill(x) + 1);
      ctx.stroke();
    }, 2);
    houseWindows(p, hx, base, 0.82, silhouette);
    // A colony of bats streaming across the moon; the near ones pass twice per loop.
    batColony(p, { seed: 97, count: 16, y0: H * 0.37, y1: H * 0.6, cycles: 1, size: [0.55, 1.15], color: "#0a0408" });
    batColony(p, { seed: 98, count: 2, y0: H * 0.44, y1: H * 0.56, cycles: 2, size: [2.2, 2.8], color: "#050205" });
    fogBank(p, { seed: 100, count: 24, y: H * 0.8, spread: 70, size: [220, 420], drift: 260, color: "rgba(170,140,190,A)", alpha: 0.22, squash: 0.22, mode: "screen" });
    // Foreground: graveyard rise and a twisted tree framing the left edge.
    const front = (x) => H * 0.9 - 40 * Math.sin(x * 0.004 + 0.4) - 16 * Math.sin(x * 0.017);
    const stones = [[W * 0.42, 110, 0.08, 0], [W * 0.6, 150, -0.07, 1], [W * 0.78, 175, 0.05, 0], [W * 0.94, 120, 0.16, 0]];
    for (const [sx, sh, tilt, cross] of stones) {
      const sy = front(sx) + 26, sw = sh * 0.62;
      ctx.save(); ctx.translate(sx, sy); ctx.rotate(tilt);
      ctx.fillStyle = "#060308";
      ctx.beginPath();
      if (cross) { ctx.rect(-sw * 0.13, -sh * 1.25, sw * 0.26, sh * 1.25); ctx.rect(-sw * 0.5, -sh * 0.98, sw, sw * 0.26); }
      else { ctx.moveTo(-sw / 2, 0); ctx.lineTo(-sw / 2, -sh + sw / 2); ctx.arc(0, -sh + sw / 2, sw / 2, Math.PI, 0); ctx.lineTo(sw / 2, 0); ctx.closePath(); }
      ctx.fill();
      ctx.globalCompositeOperation = "lighter";
      ctx.strokeStyle = "rgba(255,130,60,0.28)"; ctx.lineWidth = 2.5;
      ctx.beginPath();
      if (cross) { ctx.moveTo(-sw * 0.13, -sh * 0.98); ctx.lineTo(-sw * 0.13, -sh * 1.25); ctx.lineTo(sw * 0.13, -sh * 1.25); }
      else ctx.arc(0, -sh + sw / 2, sw / 2 - 1, Math.PI * 1.02, Math.PI * 1.8);
      ctx.stroke();
      ctx.restore();
    }
    ctx.fillStyle = "#050206";
    ctx.beginPath(); ctx.moveTo(0, H);
    for (let x = 0; x <= W; x += 8) ctx.lineTo(x, front(x));
    ctx.lineTo(W, H); ctx.closePath(); ctx.fill();
    gnarledTree(rng(99), W * 0.03, H * 1.01, 860, p, { color: "#040205", lean: 0.07, depth: 7, spread: 0.5, sway: 0.0035, width: 60 });
    // Slow ground fog rolling over the graves.
    fogBank(p, { seed: 101, count: 26, y: H * 0.93, spread: 80, size: [200, 420], drift: -240, color: "rgba(150,125,180,A)", alpha: 0.15, squash: 0.24, mode: "screen" });
    finish(f, { vignette: 0.55, grain: 0.055 });
  },
  async "halloween-pumpkins"(p, f) {
    const horizon = H * 0.66;
    const sky = ctx.createLinearGradient(0, 0, 0, horizon);
    sky.addColorStop(0, "#02020a"); sky.addColorStop(0.45, "#090a22"); sky.addColorStop(0.85, "#1f1640"); sky.addColorStop(1, "#33194a");
    ctx.fillStyle = sky; ctx.fillRect(0, 0, W, horizon + 4);
    stars(p, { seed: 111, count: 240, area: [0, 0, W, H * 0.62], size: [0.4, 1.8], twinkle: 3, color: "rgba(225,230,255,A)" });
    // Thin crescent moon with faint earthshine.
    crescentMoon(W * 0.76, H * 0.355, 62, p);
    fogBank(p, { seed: 112, count: 10, y: H * 0.5, spread: 90, size: [260, 480], drift: 200, color: "rgba(60,40,110,A)", alpha: 0.35, squash: 0.1, blur: 4, mode: "screen" });
    // Distant tree line on the horizon.
    const random = rng(113);
    ctx.fillStyle = "#0a0716";
    ctx.beginPath(); ctx.moveTo(0, horizon + 10);
    for (let x = 0; x <= W; x += 6) ctx.lineTo(x, horizon - 30 - 26 * Math.sin(x * 0.009 + 2) - 16 * Math.abs(Math.sin(x * 0.04 + 1)));
    ctx.lineTo(W, horizon + 10); ctx.closePath(); ctx.fill();
    for (let i = 0; i < 4; i++) {
      const tx = W * (0.08 + i * 0.27 + random() * 0.08);
      gnarledTree(rng(114 + i), tx, horizon - 40, 170 + random() * 90, p, { color: "#0a0716", depth: 6, sway: 0.004 });
    }
    // Warm lantern haze bleeding up from the patch.
    additive(() => glow(W * 0.55, H * 0.86, 900, "rgba(255,110,30,A)", 0.16 + 0.02 * wave(p, 3)), 20);
    fogBank(p, { seed: 115, count: 22, y: horizon - 10, spread: 40, size: [220, 400], drift: 220, color: "rgba(110,95,190,A)", alpha: 0.3, squash: 0.2, mode: "screen" });
    // Crooked fence along the horizon.
    crookedFence(rng(116), W * 0.36, W + 40, horizon + 18, p);
    // The field.
    const field = ctx.createLinearGradient(0, horizon, 0, H);
    field.addColorStop(0, "#0d0918"); field.addColorStop(0.4, "#08050d"); field.addColorStop(1, "#030205");
    ctx.fillStyle = field;
    ctx.beginPath(); ctx.moveTo(0, H);
    for (let x = 0; x <= W; x += 8) ctx.lineTo(x, horizon + 24 + 10 * Math.sin(x * 0.01));
    ctx.lineTo(W, H); ctx.closePath(); ctx.fill();
    scarecrow(W * 0.2, horizon + 50, 0.86, p);
    fogBank(p, { seed: 117, count: 20, y: H * 0.74, spread: 60, size: [240, 440], drift: -220, color: "rgba(100,90,200,A)", alpha: 0.24, squash: 0.22, mode: "screen" });
    // Pumpkin patch, back to front.
    const lanterns = [
      [W * 0.6, H * 0.752, 58, 2, 0.04, 0.11],
      [W * 0.88, H * 0.772, 74, 1, -0.06, 0.37],
      [W * 0.17, H * 0.815, 98, 3, 0.05, 0.63],
      [W * 0.67, H * 0.875, 168, 0, -0.03, 0.21],
      [W * 0.3, H * 0.935, 128, 1, 0.07, 0.83],
    ];
    vines(rng(118), lanterns, p);
    for (const [x, y, r, face, tilt, ph] of lanterns) jackOLantern(x, y, r, face, tilt, candle(p, ph));
    // Embers rising from the lanterns and fireflies drifting over the patch.
    particles(p, { seed: 119, count: 46, cycles: 1, dir: -1, sway: 26, size: [0.7, 1.8], area: [W * 0.1, H * 0.56, W * 0.8, H * 0.36], color: "rgba(255,150,60,A)", alpha: [0.2, 0.85], glowSize: 4, twinkle: 4 });
    fireflies(p, { seed: 120, count: 26, area: [40, H * 0.5, W - 80, H * 0.38] });
    fogBank(p, { seed: 121, count: 24, y: H * 0.95, spread: 70, size: [260, 480], drift: 260, color: "rgba(80,70,170,A)", alpha: 0.3, squash: 0.26, mode: "screen" });
    finish(f, { vignette: 0.55, grain: 0.055 });
  },
  async "halloween-ghosts"(p, f) {
    const ground = H * 0.8;
    const sky = ctx.createLinearGradient(0, 0, 0, H);
    sky.addColorStop(0, "#010605"); sky.addColorStop(0.3, "#031412"); sky.addColorStop(0.55, "#08322c");
    sky.addColorStop(0.78, "#0a3a31"); sky.addColorStop(1, "#020a08");
    ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H);
    // A hidden moon somewhere behind the canopy; its light falls through the mist.
    additive(() => glow(W * 0.6, H * 0.4, 760, "rgba(120,255,210,A)", 0.16), 16);
    rays(W * 0.7, -260, p, { angle: Math.PI * 0.58, spread: 0.7, alpha: 0.07, count: 9, color: "rgba(150,255,220,A)", width: 0.05, length: 2300 });
    // Far trunks dissolve into the mist.
    const random = rng(131);
    for (let i = 0; i < 13; i++) {
      const x = -40 + (i + random() * 0.8) * (W + 80) / 13;
      deadTrunk(rng(132 + i), x, ground - 30, 16 + random() * 22, p, { fill: "#0b2c27", fillTop: "#020d0b", rim: "rgba(120,240,200,A)", rimAlpha: 0.08, branches: 2 });
    }
    const haze = ctx.createLinearGradient(0, 0, 0, H);
    haze.addColorStop(0, "rgba(4,24,20,0.5)"); haze.addColorStop(0.6, "rgba(30,100,85,0.32)"); haze.addColorStop(1, "rgba(10,40,34,0.2)");
    ctx.fillStyle = haze; ctx.fillRect(0, 0, W, H);
    fogBank(p, { seed: 133, count: 20, y: H * 0.64, spread: 160, size: [240, 460], drift: 240, swirl: 40, color: "rgba(90,210,170,A)", alpha: 0.22, squash: 0.35, mode: "screen" });
    wanderingGhost(p, { x: W * 0.55, y: H * 0.47, s: 38, drift: 260, offset: 0.15, alpha: 0.5 });
    // Mid trunks, rim-lit from the mist; one ghost weaves between the two rows.
    const midBack = [[W * 0.16, 54], [W * 0.47, 46], [W * 0.84, 60]];
    const midFront = [[W * 0.31, 70], [W * 0.66, 64]];
    midBack.forEach(([x, w], i) => deadTrunk(rng(140 + i), x, ground, w, p, { fill: "#061815", rim: "rgba(120,255,210,A)", rimAlpha: 0.18, branches: 3 }));
    floatingGhost(p, { x: W * 0.47, y: H * 0.5, s: 66, ax: 120, ay: 30, phase: 0.1 });
    fogBank(p, { seed: 143, count: 18, y: H * 0.72, spread: 120, size: [220, 420], drift: -240, swirl: 50, color: "rgba(80,220,170,A)", alpha: 0.2, squash: 0.3, mode: "screen" });
    midFront.forEach(([x, w], i) => deadTrunk(rng(150 + i), x, ground + 10, w, p, { fill: "#030d0b", rim: "rgba(120,255,210,A)", rimAlpha: 0.22, branches: 3 }));
    // Forest floor with roots.
    const floor = ctx.createLinearGradient(0, ground - 20, 0, H);
    floor.addColorStop(0, "#04130f"); floor.addColorStop(0.3, "#020907"); floor.addColorStop(1, "#000302");
    ctx.fillStyle = floor;
    ctx.beginPath(); ctx.moveTo(0, H);
    for (let x = 0; x <= W; x += 8) ctx.lineTo(x, ground + 14 * Math.sin(x * 0.012 + 1) + 8 * Math.sin(x * 0.04));
    ctx.lineTo(W, H); ctx.closePath(); ctx.fill();
    // Watching eyes in the dark between the roots.
    blinkingEyes(p, W * 0.12, H * 0.71, 7, 30, "rgba(200,255,90,A)", [0.18, 0.62]);
    blinkingEyes(p, W * 0.56, H * 0.765, 5, 22, "rgba(255,190,70,A)", [0.4, 0.9]);
    blinkingEyes(p, W * 0.9, H * 0.68, 6, 26, "rgba(170,255,120,A)", [0.05, 0.52]);
    blinkingEyes(p, W * 0.4, H * 0.86, 8, 36, "rgba(255,120,60,A)", [0.33, 0.78]);
    fogBank(p, { seed: 160, count: 22, y: H * 0.81, spread: 70, size: [240, 440], drift: 260, swirl: 40, color: "rgba(100,235,185,A)", alpha: 0.24, squash: 0.25, mode: "screen" });
    floatingGhost(p, { x: W * 0.74, y: H * 0.58, s: 92, ax: 70, ay: 34, phase: 0.55 });
    wanderingGhost(p, { x: W * 0.24, y: H * 0.62, s: 58, drift: -300, offset: 0.62, alpha: 0.85 });
    // Near trunks frame the view.
    deadTrunk(rng(170), W * 0.02, H + 40, 150, p, { fill: "#010504", rim: "rgba(120,255,210,A)", rimAlpha: 0.2, rimSide: 1, branches: 3, top: -60 });
    deadTrunk(rng(171), W * 0.985, H + 40, 128, p, { fill: "#010504", rim: "rgba(120,255,210,A)", rimAlpha: 0.16, rimSide: -1, branches: 3, top: -60 });
    fogBank(p, { seed: 172, count: 22, y: H * 0.94, spread: 70, size: [260, 500], drift: -260, swirl: 30, color: "rgba(70,190,150,A)", alpha: 0.26, squash: 0.28, mode: "screen" });
    fallingLeaves(p, { seed: 173, count: 18 });
    finish(f, { vignette: 0.6, grain: 0.055 });
  },
};

// ---------- Halloween helpers ----------
const fogCanvas = Object.assign(document.createElement("canvas"), { width: W / 4, height: H / 4 });
const smoothstep = (x) => { const t = Math.min(1, Math.max(0, x)); return t * t * (3 - 2 * t); };
/// Fog banks built from soft puffs. Each puff fades in, creeps `drift` px and fades out once per
/// loop at its own phase, so the bank seems to roll on forever while the loop repeats exactly.
function fogBank(p, { seed = 1, count = 18, y = H * 0.8, spread = 120, size = [220, 420], drift = 220, swirl = 0, color = "rgba(150,160,200,A)", alpha = 0.3, squash = 0.3, blur = 6, mode = "source-over" } = {}) {
  const random = rng(seed);
  const l = fogCanvas.getContext("2d");
  l.setTransform(1, 0, 0, 1, 0, 0);
  l.clearRect(0, 0, fogCanvas.width, fogCanvas.height);
  l.setTransform(0.25, 0, 0, 0.25, 0, 0);
  for (let i = 0; i < count; i++) {
    const x0 = random() * (W + 300) - 150, y0 = y + (random() * 2 - 1) * spread;
    const r = size[0] + random() * (size[1] - size[0]), offset = random(), ph = random();
    const life = frac(offset + p);
    const a = alpha * Math.pow(Math.sin(Math.PI * life), 1.3);
    const x = x0 + drift * (life - 0.5) + swirl * Math.cos(TAU * (p + ph));
    const yy = y0 + swirl * 0.45 * Math.sin(TAU * (p + ph));
    l.save();
    l.translate(x, yy); l.scale(1, squash);
    const g = l.createRadialGradient(0, 0, 0, 0, 0, r);
    g.addColorStop(0, color.replace("A", a));
    g.addColorStop(0.5, color.replace("A", a * 0.55));
    g.addColorStop(1, color.replace("A", 0));
    l.fillStyle = g; l.fillRect(-r, -r, r * 2, r * 2);
    l.restore();
  }
  ctx.save();
  ctx.globalCompositeOperation = mode;
  ctx.filter = `blur(${blur}px)`;
  ctx.imageSmoothingQuality = "high";
  ctx.drawImage(fogCanvas, 0, 0, W, H);
  ctx.restore();
}
/// Candle light: a few incommensurate-looking but whole-cycle flickers, so it never visibly repeats inside a loop.
const candle = (p, ph) => 0.86 + 0.07 * wave(p, 7, ph) + 0.05 * wave(p, 13, ph * 1.7) + 0.035 * wave(p, 29, ph * 2.3) - 0.08 * Math.pow(Math.max(0, wave(p, 3, ph * 3.1)), 12);
/// A gnarled, leafless tree. Every random draw happens in the same order every frame; sway grows toward the twigs.
function gnarledTree(random, x, y, height, p, { color = "#05030a", lean = 0, sway = 0.004, depth = 7, spread = 0.58, width } = {}) {
  ctx.save();
  ctx.strokeStyle = color; ctx.fillStyle = color;
  ctx.lineCap = "round"; ctx.lineJoin = "round";
  const limb = (bx, by, angle, len, w, level) => {
    let a = angle + sway * level * wave(p, 1, level * 0.13 + bx * 0.001);
    let cx = bx, cy = by;
    for (let s = 0; s < 4; s++) {
      a += (random() - 0.5) * 0.55;
      a += (-Math.PI / 2 - a) * 0.06;
      const nx = cx + (Math.cos(a) * len) / 4, ny = cy + (Math.sin(a) * len) / 4;
      ctx.lineWidth = Math.max(0.8, w * (1 - s * 0.09));
      ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(nx, ny); ctx.stroke();
      cx = nx; cy = ny;
    }
    if (level >= depth || w < 1.1) return;
    const kids = 2 + (random() < 0.35 ? 1 : 0);
    for (let k = 0; k < kids; k++) {
      const off = (k - (kids - 1) / 2) * spread * (0.7 + random() * 0.6) + (random() - 0.5) * 0.3;
      limb(cx, cy, a + off, len * (0.64 + random() * 0.18), w * 0.64, level + 1);
    }
  };
  const w0 = width ?? height * 0.05;
  // Root flare.
  ctx.beginPath(); ctx.moveTo(x - w0 * 1.6, y); ctx.quadraticCurveTo(x - w0 * 0.4, y - w0 * 0.6, x - w0 * 0.4, y - w0 * 2.4);
  ctx.lineTo(x + w0 * 0.4, y - w0 * 2.4); ctx.quadraticCurveTo(x + w0 * 0.4, y - w0 * 0.6, x + w0 * 1.6, y); ctx.closePath(); ctx.fill();
  limb(x, y, -Math.PI / 2 + lean, height * 0.32, w0, 0);
  ctx.restore();
}
/// Silhouette of a crooked Victorian house; its origin sits on the ground at the middle of the main block.
function hauntedHouse(p, x, y, k, color) {
  ctx.save();
  ctx.translate(x, y); ctx.scale(k, k); ctx.transform(1, 0, -0.04, 1, 0, 0);
  ctx.fillStyle = color; ctx.strokeStyle = color;
  const poly = (pts) => { ctx.beginPath(); pts.forEach(([px, py], i) => (i ? ctx.lineTo(px, py) : ctx.moveTo(px, py))); ctx.closePath(); ctx.fill(); };
  poly([[88, 200], [90, -118], [152, -168], [218, -116], [214, 200]]);
  poly([[182, -140], [186, -206], [208, -203], [203, -126]]);
  poly([[178, -212], [214, -208], [214, -200], [178, -203]]);
  poly([[-122, 200], [-118, -176], [112, -171], [114, 200]]);
  ctx.beginPath(); ctx.moveTo(-148, -166); ctx.quadraticCurveTo(-72, -204, -8, -296); ctx.quadraticCurveTo(62, -214, 138, -168); ctx.closePath(); ctx.fill();
  poly([[18, -196], [20, -242], [46, -266], [74, -240], [72, -192]]);
  poly([[58, -228], [66, -306], [92, -301], [84, -212]]);
  poly([[52, -312], [98, -306], [97, -296], [52, -300]]);
  poly([[-168, 200], [-164, -332], [-94, -336], [-90, 200]]);
  ctx.beginPath(); ctx.moveTo(-182, -326); ctx.quadraticCurveTo(-142, -372, -106, -478); ctx.quadraticCurveTo(-118, -384, -78, -330); ctx.closePath(); ctx.fill();
  ctx.lineWidth = 4;
  ctx.beginPath(); ctx.moveTo(-106, -476); ctx.lineTo(-104, -512); ctx.stroke();
  ctx.lineWidth = 3;
  ctx.beginPath(); ctx.moveTo(-122, -500); ctx.lineTo(-86, -498); ctx.stroke();
  poly([[-92, -496], [-80, -505], [-80, -491]]);
  // Porch roof, posts and a broken balustrade.
  poly([[-86, -82], [72, -88], [82, -70], [-94, -64]]);
  for (const px of [-82, -20, 44, 68]) poly([[px, -70], [px + 6, -70], [px + 7, 2], [px + 1, 2]]);
  ctx.lineWidth = 3;
  for (let px = -78; px < 66; px += 11) { ctx.beginPath(); ctx.moveTo(px, -26 + (px % 3)); ctx.lineTo(px + 1, 0); ctx.stroke(); }
  ctx.beginPath(); ctx.moveTo(-82, -28); ctx.lineTo(70, -24); ctx.stroke();
  ctx.restore();
}
/// The lit windows of hauntedHouse, flickering like candles and oil lamps.
function houseWindows(p, x, y, k, color) {
  const windows = [
    [-140, -300, 24, 42, true, 0.12, 1], [-140, -190, 22, 36, true, 0.5, 0],
    [-88, -150, 32, 46, false, 0.37, 1], [42, -150, 32, 46, false, 0.71, 0.35],
    [34, -238, 22, 30, true, 0.58, 1], [-62, -60, 40, 42, false, 0.23, 0.85], [138, -96, 28, 40, false, 0.91, 1],
  ];
  const at = (wx, wy) => [x + k * (wx - 0.04 * wy), y + k * wy];
  const paint = (bloom) => {
    for (const [wx, wy, ww, wh, arch, ph, lit] of windows) {
      if (!lit) continue;
      const fl = candle(p, ph) * lit;
      const [cx, cy] = at(wx, wy);
      const w = ww * k, h = wh * k;
      if (bloom) { glow(cx, cy, w * 3.2, "rgba(255,150,50,A)", 0.5 * fl); continue; }
      const g = ctx.createRadialGradient(cx, cy + h * 0.15, 1, cx, cy, h * 0.8);
      g.addColorStop(0, `rgba(255,236,160,${0.95 * fl})`); g.addColorStop(1, `rgba(255,140,40,${0.85 * fl})`);
      ctx.fillStyle = g;
      ctx.beginPath();
      if (arch) { ctx.moveTo(cx - w / 2, cy + h / 2); ctx.lineTo(cx - w / 2, cy - h / 2 + w / 2); ctx.arc(cx, cy - h / 2 + w / 2, w / 2, Math.PI, 0); ctx.lineTo(cx + w / 2, cy + h / 2); }
      else ctx.rect(cx - w / 2, cy - h / 2, w, h);
      ctx.fill();
      ctx.fillStyle = color;
      ctx.fillRect(cx - 1.2, cy - h / 2, 2.4, h);
      ctx.fillRect(cx - w / 2, cy - 1.2 + h * 0.08, w, 2.4);
    }
  };
  paint(false);
  ctx.save();
  ctx.fillStyle = `rgba(255,190,90,${0.6 * candle(p, 0.44)})`;
  const [rx, ry] = at(-10, -238);
  ctx.beginPath(); ctx.arc(rx, ry, 9 * k, 0, TAU); ctx.fill();
  ctx.restore();
  additive(() => paint(true), 6);
}
/// One bat; flap runs -1..1 and the scalloped wing membrane folds with it.
function bat(x, y, s, flap, tilt, color) {
  ctx.save();
  ctx.translate(x, y); ctx.rotate(tilt); ctx.scale(s, s);
  ctx.fillStyle = color;
  const up = flap;
  for (const side of [-1, 1]) {
    const span = 21 - Math.abs(up) * 4;
    const tipX = side * span, tipY = -2 - up * 13;
    const wristX = side * 9.5, wristY = -5 - up * 7;
    ctx.beginPath();
    ctx.moveTo(0, -3);
    ctx.quadraticCurveTo(side * 4, -6 - up * 3, wristX, wristY);
    ctx.lineTo(tipX, tipY);
    const edge = [[side * 15, 2 - up * 8], [side * 9, 3.5 - up * 4], [side * 3, 5 - up]];
    let px = tipX, py = tipY;
    for (const [qx, qy] of edge) {
      ctx.quadraticCurveTo((px + qx) / 2 - side * 0.5, (py + qy) / 2 - 2.6, qx, qy);
      px = qx; py = qy;
    }
    ctx.lineTo(0, 4);
    ctx.closePath(); ctx.fill();
  }
  ctx.beginPath(); ctx.ellipse(0, 1, 2.6, 5, 0, 0, TAU); ctx.fill();
  ctx.beginPath(); ctx.arc(0, -4.2, 2.3, 0, TAU); ctx.fill();
  ctx.beginPath(); ctx.moveTo(-2.2, -5); ctx.lineTo(-1.6, -8.4); ctx.lineTo(-0.6, -5.6); ctx.moveTo(2.2, -5); ctx.lineTo(1.6, -8.4); ctx.lineTo(0.6, -5.6); ctx.fill();
  ctx.restore();
}
/// A loose stream of bats crossing right to left, `cycles` passes per loop, each flapping a whole number of beats.
function batColony(p, { seed = 1, count = 12, y0 = H * 0.4, y1 = H * 0.6, cycles = 1, size = [0.6, 1.2], color = "#060306" } = {}) {
  const random = rng(seed);
  for (let i = 0; i < count; i++) {
    const x0 = random(), yy = y0 + random() * (y1 - y0), s = size[0] + random() * (size[1] - size[0]);
    const beats = 18 + Math.floor(random() * 9), ph = random(), bob = 18 + random() * 40, bobC = 1 + Math.floor(random() * 3);
    const u = frac(x0 - cycles * p);
    const x = -220 + u * (W + 440);
    const y = yy + bob * wave(p, bobC, ph) + 30 * Math.sin(TAU * (u * 1.5 + ph));
    const vy = bob * bobC * Math.cos(TAU * (p * bobC + ph));
    const flap = Math.sin(TAU * (p * beats + ph)) + 0.25 * Math.sin(2 * TAU * (p * beats + ph));
    bat(x, y, s, Math.max(-1, Math.min(1, flap)), vy * 0.0016, color);
  }
}
/// A thin crescent drawn by cutting the lit disk with an offset one; the dark side keeps a faint earthshine.
const moonCanvas = Object.assign(document.createElement("canvas"), { width: 400, height: 400 });
function crescentMoon(x, y, r, p) {
  additive(() => {
    glow(x, y, r * 7, "rgba(170,180,255,A)", 0.14);
    glow(x, y, r * 2.6, "rgba(210,215,255,A)", 0.16);
  }, 8);
  ctx.save();
  ctx.fillStyle = "rgba(50,52,80,0.55)";
  ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill();
  ctx.restore();
  const m = moonCanvas.getContext("2d");
  m.setTransform(1, 0, 0, 1, 0, 0);
  m.clearRect(0, 0, 400, 400);
  m.globalCompositeOperation = "source-over";
  const g = m.createRadialGradient(170, 200, 10, 200, 200, r);
  g.addColorStop(0, "#fffbea"); g.addColorStop(1, "#e7e0c8");
  m.fillStyle = g;
  m.beginPath(); m.arc(200, 200, r, 0, TAU); m.fill();
  m.globalCompositeOperation = "destination-out";
  m.beginPath(); m.arc(200 + r * 0.42, 200 - r * 0.2, r * 0.95, 0, TAU); m.fill();
  m.globalCompositeOperation = "source-over";
  ctx.save();
  ctx.translate(x, y); ctx.rotate(-0.35);
  ctx.drawImage(moonCanvas, -200, -200);
  ctx.restore();
  ctx.save();
  ctx.globalCompositeOperation = "lighter";
  ctx.filter = "blur(6px)";
  ctx.globalAlpha = 0.6 + 0.04 * wave(p);
  ctx.translate(x, y); ctx.rotate(-0.35);
  ctx.drawImage(moonCanvas, -200, -200);
  ctx.restore();
}
/// Leaning picket fence with sagging rails.
function crookedFence(random, x0, x1, y, p) {
  ctx.save();
  ctx.fillStyle = "#07050e"; ctx.strokeStyle = "#07050e";
  const posts = [];
  for (let x = x0; x < x1; x += 70 + random() * 40) {
    const h = 80 + random() * 50, tilt = (random() - 0.5) * 0.3, gone = random() < 0.12;
    posts.push([x, h, tilt, gone]);
  }
  ctx.lineWidth = 7; ctx.lineCap = "round";
  for (const rail of [0.38, 0.72]) {
    ctx.beginPath();
    posts.forEach(([x, h, tilt], i) => {
      const px = x + Math.sin(tilt) * h * rail, py = y - Math.cos(tilt) * h * rail + (i % 2) * 6;
      i ? ctx.quadraticCurveTo((px + posts[i - 1][0]) / 2, py + 10, px, py) : ctx.moveTo(px, py);
    });
    ctx.stroke();
  }
  for (const [x, h, tilt, gone] of posts) {
    if (gone) continue;
    ctx.save(); ctx.translate(x, y); ctx.rotate(tilt);
    ctx.beginPath(); ctx.moveTo(-7, 6); ctx.lineTo(-7, -h); ctx.lineTo(0, -h - 14); ctx.lineTo(7, -h); ctx.lineTo(7, 6); ctx.closePath(); ctx.fill();
    ctx.restore();
  }
  ctx.restore();
}
/// Scarecrow on a post: witch hat, sack head, tattered coat whose rags sway in the breeze.
function scarecrow(x, y, k, p) {
  ctx.save();
  ctx.translate(x, y); ctx.scale(k, k); ctx.rotate(0.012 * wave(p, 1, 0.2));
  ctx.fillStyle = "#06040b"; ctx.strokeStyle = "#06040b"; ctx.lineCap = "round";
  ctx.fillRect(-7, -560, 14, 580);
  ctx.save(); ctx.translate(0, -440); ctx.rotate(-0.06);
  ctx.fillRect(-190, -9, 380, 16);
  ctx.restore();
  // Coat and sleeves with ragged hems.
  const rag = (x0, x1, yb, n, ph) => {
    for (let i = 0; i <= n; i++) {
      const t = i / n, xx = x0 + (x1 - x0) * t;
      const len = (i % 2 ? 26 : 8) + 10 * Math.sin(i * 2.3);
      ctx.lineTo(xx + 6 * wave(p, 2, ph + t * 0.6), yb + len + 4 * wave(p, 2, ph + t));
    }
  };
  ctx.beginPath();
  ctx.moveTo(-176, -462); ctx.lineTo(-50, -478); ctx.lineTo(0, -486); ctx.lineTo(50, -478); ctx.lineTo(176, -464);
  rag(176, 140, -420, 3, 0.1);
  ctx.lineTo(80, -404); ctx.lineTo(96, -250);
  rag(96, -96, -250, 9, 0.3);
  ctx.lineTo(-80, -404); ctx.lineTo(-140, -414);
  rag(-140, -176, -420, 3, 0.6);
  ctx.closePath(); ctx.fill();
  // Straw tufts at the cuffs.
  ctx.lineWidth = 2.5;
  for (const side of [-1, 1]) {
    for (let i = 0; i < 6; i++) {
      const a = 0.4 + i * 0.14;
      ctx.beginPath(); ctx.moveTo(side * 180, -452);
      ctx.lineTo(side * (180 + Math.cos(a) * 30) + 3 * wave(p, 3, i * 0.1), -452 + Math.sin(a) * 30); ctx.stroke();
    }
  }
  // Sack head, hat.
  ctx.beginPath(); ctx.ellipse(0, -520, 40, 46, 0, 0, TAU); ctx.fill();
  ctx.beginPath(); ctx.ellipse(-2, -556, 92, 14, -0.12, 0, TAU); ctx.fill();
  ctx.beginPath(); ctx.moveTo(-50, -560); ctx.quadraticCurveTo(-20, -640, 18, -700); ctx.quadraticCurveTo(40, -690, 56, -664); ctx.quadraticCurveTo(20, -660, 44, -566); ctx.closePath(); ctx.fill();
  // A crow perched on the arm.
  ctx.save(); ctx.translate(140, -466); ctx.rotate(-0.06);
  ctx.beginPath(); ctx.ellipse(0, -18, 20, 13, -0.3, 0, TAU); ctx.fill();
  ctx.beginPath(); ctx.arc(16, -32, 9, 0, TAU); ctx.fill();
  ctx.beginPath(); ctx.moveTo(23, -34); ctx.lineTo(36, -30); ctx.lineTo(23, -28); ctx.fill();
  ctx.beginPath(); ctx.moveTo(-14, -14); ctx.lineTo(-40, -2); ctx.lineTo(-36, -12); ctx.fill();
  ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(-2, -6); ctx.lineTo(-2, 0); ctx.moveTo(4, -6); ctx.lineTo(4, 0); ctx.stroke();
  ctx.restore();
  // Faint eyes stitched into the sack catch the lantern glow.
  additive(() => {
    glow(-14, -524, 9, "rgba(255,140,50,A)", 0.12 + 0.04 * wave(p, 2));
    glow(14, -524, 9, "rgba(255,140,50,A)", 0.12 + 0.04 * wave(p, 2, 0.3));
  });
  ctx.restore();
}
/// Curling pumpkin vines and big lobed leaves joining the lanterns.
function vines(random, lanterns, p) {
  ctx.save();
  ctx.strokeStyle = "#0a0f07"; ctx.fillStyle = "#090d06"; ctx.lineCap = "round";
  const sorted = [...lanterns].sort((a, b) => a[0] - b[0]);
  ctx.lineWidth = 6;
  for (let i = 0; i < sorted.length - 1; i++) {
    const [ax, ay] = sorted[i], [bx, by] = sorted[i + 1];
    ctx.beginPath(); ctx.moveTo(ax, ay - 6);
    ctx.bezierCurveTo(ax + (bx - ax) * 0.3, ay + 40 + random() * 40, ax + (bx - ax) * 0.7, by - 30 - random() * 30, bx, by - 6);
    ctx.stroke();
  }
  for (let i = 0; i < 14; i++) {
    const x = random() * W, y = H * 0.76 + random() * H * 0.22, s = 26 + random() * 34, a = random() * TAU;
    ctx.save(); ctx.translate(x, y); ctx.rotate(a); ctx.scale(s, s * (0.55 + random() * 0.2));
    ctx.beginPath();
    for (let l = 0; l < 5; l++) { const t = (l / 5) * TAU; ctx.moveTo(Math.cos(t) * 0.5, Math.sin(t) * 0.5); ctx.arc(Math.cos(t) * 0.5, Math.sin(t) * 0.5, 0.55, 0, TAU); }
    ctx.fill();
    ctx.restore();
    // A tendril curl.
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    for (let t = 0; t < 4 * Math.PI; t += 0.25) {
      const rr = 3 + t * 2.2, px = x + s + Math.cos(t) * rr, py = y - s * 0.4 + Math.sin(t) * rr;
      t ? ctx.lineTo(px, py) : ctx.moveTo(px, py);
    }
    ctx.stroke();
  }
  ctx.restore();
}
/// Carved faces in pumpkin-radius units, centred just above the middle of the pumpkin.
const pumpkinFaces = [
  [[[-0.56, -0.05], [-0.16, -0.05], [-0.34, -0.42]], [[0.56, -0.05], [0.16, -0.05], [0.34, -0.42]], [[-0.09, 0.13], [0.09, 0.13], [0, -0.02]],
    [[-0.66, 0.18], [-0.46, 0.3], [-0.34, 0.24], [-0.3, 0.33], [-0.1, 0.38], [-0.04, 0.3], [0.06, 0.3], [0.1, 0.39], [0.3, 0.33], [0.34, 0.24], [0.46, 0.3], [0.66, 0.18],
      [0.5, 0.48], [0.3, 0.58], [0.24, 0.5], [0.14, 0.5], [0.1, 0.6], [-0.1, 0.62], [-0.14, 0.52], [-0.24, 0.52], [-0.3, 0.6], [-0.5, 0.48]]],
  [[[-0.6, -0.26], [-0.12, -0.06], [-0.42, 0.04]], [[0.6, -0.26], [0.12, -0.06], [0.42, 0.04]], [[-0.08, 0.08], [0.08, 0.08], [0, 0.21]],
    [[-0.64, 0.2], [-0.46, 0.34], [-0.36, 0.26], [-0.24, 0.39], [-0.12, 0.29], [0, 0.41], [0.12, 0.29], [0.24, 0.39], [0.36, 0.26], [0.46, 0.34], [0.64, 0.2],
      [0.5, 0.56], [0.36, 0.5], [0.24, 0.64], [0.12, 0.54], [0, 0.68], [-0.12, 0.54], [-0.24, 0.64], [-0.36, 0.5], [-0.5, 0.56]]],
  [{ c: [-0.32, -0.16, 0.15, 0.2] }, { c: [0.32, -0.16, 0.15, 0.2] }, [[-0.07, 0.1], [0.07, 0.1], [0, 0]],
    [[-0.52, 0.2], [-0.26, 0.44], [0, 0.5], [0.26, 0.44], [0.52, 0.2], [0.3, 0.3], [0.12, 0.33], [0.08, 0.27], [-0.02, 0.27], [-0.06, 0.34], [-0.3, 0.3]]],
  [[[-0.62, -0.08], [-0.44, -0.3], [-0.2, -0.32], [-0.1, -0.12], [-0.26, -0.2], [-0.44, -0.17]],
    [[0.62, -0.08], [0.44, -0.3], [0.2, -0.32], [0.1, -0.12], [0.26, -0.2], [0.44, -0.17]], [[-0.07, 0.1], [0.07, 0.1], [0, -0.03]],
    [[-0.72, 0.05], [-0.5, 0.3], [-0.2, 0.42], [-0.16, 0.33], [-0.05, 0.33], [-0.03, 0.44], [0.2, 0.44], [0.24, 0.35], [0.34, 0.35], [0.36, 0.4], [0.5, 0.3], [0.72, 0.05],
      [0.55, 0.5], [0.2, 0.66], [-0.2, 0.66], [-0.55, 0.5]]],
];
function facePath(face, r, dx = 0, dy = 0, shrink = 1) {
  ctx.beginPath();
  for (const shape of face) {
    if (shape.c) {
      const [x, y, rx, ry] = shape.c;
      ctx.moveTo((x + rx * shrink) * r + dx, y * r + dy);
      ctx.ellipse(x * r + dx, y * r + dy, rx * r * shrink, ry * r * shrink, 0, 0, TAU);
      continue;
    }
    const cx = shape.reduce((s, q) => s + q[0], 0) / shape.length, cy = shape.reduce((s, q) => s + q[1], 0) / shape.length;
    shape.forEach(([x, y], i) => {
      const px = (cx + (x - cx) * shrink) * r + dx, py = (cy + (y - cy) * shrink) * r + dy;
      i ? ctx.lineTo(px, py) : ctx.moveTo(px, py);
    });
    ctx.closePath();
  }
}
/// A carved jack-o'-lantern standing at (x, y): ribbed skin, light through the flesh and the cut-outs, warm pool on the ground.
function jackOLantern(x, y, r, faceIndex, tilt, fl) {
  const face = pumpkinFaces[faceIndex];
  additive(() => {
    ctx.save(); ctx.translate(x, y + r * 0.05); ctx.scale(1, 0.3);
    glow(0, 0, r * 3.2, "rgba(255,110,25,A)", 0.42 * fl);
    ctx.restore();
  });
  ctx.save();
  ctx.fillStyle = "rgba(0,0,0,0.55)";
  ctx.beginPath(); ctx.ellipse(x, y, r * 1.05, r * 0.16, 0, 0, TAU); ctx.fill();
  ctx.translate(x, y - r * 0.8); ctx.rotate(tilt);
  // Ribs, outermost first so the front lobes overlap them.
  const body = () => { ctx.beginPath(); ctx.ellipse(0, 0, r * 1.02, r * 0.82, 0, 0, TAU); };
  for (const kk of [-3, 3, -2, 2, -1, 1, 0]) {
    const ox = kk * r * 0.2, rx = r * (0.44 - Math.abs(kk) * 0.015), ry = r * (0.82 - Math.abs(kk) * 0.035);
    const g = ctx.createRadialGradient(ox - rx * 0.25, -ry * 0.35, r * 0.05, ox, 0, Math.max(rx, ry) * 1.05);
    g.addColorStop(0, "#9c4210"); g.addColorStop(0.55, "#5a1f06"); g.addColorStop(1, "#1e0802");
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.ellipse(ox, 0, rx, ry, 0, 0, TAU); ctx.fill();
    ctx.strokeStyle = "rgba(25,7,0,0.85)"; ctx.lineWidth = Math.max(1.2, r * 0.02);
    ctx.stroke();
  }
  // Candle light glowing through the flesh.
  ctx.save();
  body(); ctx.clip();
  ctx.globalCompositeOperation = "lighter";
  glow(0, r * 0.1, r * 1.15, "rgba(255,105,20,A)", 0.5 * fl);
  ctx.restore();
  // Carved lid seam leaking light, then the stem.
  ctx.save();
  ctx.globalCompositeOperation = "lighter";
  ctx.strokeStyle = `rgba(255,170,60,${0.55 * fl})`; ctx.lineWidth = Math.max(1.5, r * 0.018);
  ctx.beginPath();
  for (let i = 0; i <= 18; i++) {
    const a = Math.PI + (i / 18) * Math.PI;
    const px = Math.cos(a) * r * 0.36, py = -r * 0.66 + Math.sin(a) * r * 0.1 + (i % 2 ? -r * 0.035 : r * 0.02);
    i ? ctx.lineTo(px, py) : ctx.moveTo(px, py);
  }
  ctx.stroke();
  ctx.restore();
  ctx.fillStyle = "#211a0b";
  ctx.beginPath(); ctx.moveTo(-r * 0.08, -r * 0.74); ctx.quadraticCurveTo(-r * 0.1, -r * 0.98, r * 0.06, -r * 1.08);
  ctx.lineTo(r * 0.12, -r * 1.02); ctx.quadraticCurveTo(r * 0.02, -r * 0.94, r * 0.09, -r * 0.74); ctx.closePath(); ctx.fill();
  // Cut-outs: lit wall first, then the bright interior seen through the opening.
  const fy = -r * 0.05;
  ctx.fillStyle = "#c2510c";
  facePath(face, r, 0, fy); ctx.fill();
  const inner = ctx.createRadialGradient(0, fy + r * 0.12, r * 0.02, 0, fy, r * 0.85);
  inner.addColorStop(0, `rgba(255,252,220,${fl})`); inner.addColorStop(0.35, `rgba(255,214,100,${fl})`);
  inner.addColorStop(0.75, `rgba(255,140,30,${fl})`); inner.addColorStop(1, `rgba(230,80,10,${fl})`);
  ctx.fillStyle = inner;
  facePath(face, r, -r * 0.012, fy - r * 0.028, 0.86); ctx.fill();
  ctx.restore();
  additive(() => {
    ctx.save(); ctx.translate(x, y - r * 0.8); ctx.rotate(tilt);
    ctx.fillStyle = `rgba(255,160,50,${0.55 * fl})`;
    facePath(face, r, 0, fy); ctx.fill();
    glow(0, fy + r * 0.1, r * 1.5, "rgba(255,120,30,A)", 0.28 * fl);
    ctx.restore();
  }, Math.max(4, r * 0.09));
  additive(() => glow(x, y - r * 0.8, r * 2.6, "rgba(255,110,30,A)", 0.1 * fl));
}
/// Fireflies wander on closed Lissajous paths and pulse a whole number of times per loop.
function fireflies(p, { seed = 1, count = 20, area = [0, H * 0.5, W, H * 0.4] } = {}) {
  const random = rng(seed);
  additive(() => {
    for (let i = 0; i < count; i++) {
      const bx = area[0] + random() * area[2], by = area[1] + random() * area[3];
      const ax = 30 + random() * 70, ay = 20 + random() * 50, fx = 1 + Math.floor(random() * 2), fy = 1 + Math.floor(random() * 3), ph = random();
      const pulses = 2 + Math.floor(random() * 3);
      const x = bx + ax * wave(p, fx, ph), y = by + ay * wave(p, fy, ph + 0.3);
      const b = Math.pow(0.5 + 0.5 * wave(p, pulses, ph * 1.7), 3);
      glow(x, y, 16, "rgba(210,255,110,A)", 0.55 * b);
      glow(x, y, 3.5, "rgba(250,255,220,A)", 0.9 * b);
    }
  }, 1);
}
/// A sheet ghost; `lean` trails the hem behind the motion, the hem ripples a whole number of times per loop.
function drawGhost(p, x, y, s, { alpha = 1, lean = 0, tilt = 0, ph = 0 } = {}) {
  const hem = 2.35;
  const ripple = (u) => 0.13 * Math.sin(TAU * (u * 2.5 + 2 * p + ph)) + 0.05 * Math.sin(TAU * (u * 5 - 3 * p + ph));
  const trail = (yy) => lean * Math.pow(Math.max(0, yy) / hem, 1.7);
  const outline = () => {
    ctx.beginPath();
    ctx.moveTo(-1.32 + trail(hem), hem + ripple(0));
    ctx.bezierCurveTo(-1.28 + trail(1.6), 1.6, -1.06, 0.75, -1, 0);
    ctx.arc(0, 0, 1, Math.PI, 0);
    ctx.bezierCurveTo(1.06, 0.75, 1.28 + trail(1.6), 1.6, 1.32 + trail(hem), hem + ripple(1));
    const n = 7;
    for (let k = 1; k <= n; k++) {
      const um = 1 - (k - 0.5) / n, u1 = 1 - k / n;
      ctx.quadraticCurveTo(-1.32 + 2.64 * um + trail(hem), hem + ripple(um) - 0.24, -1.32 + 2.64 * u1 + trail(hem), hem + ripple(u1));
    }
    ctx.closePath();
  };
  const place = () => { ctx.translate(x, y); ctx.rotate(tilt); ctx.scale(s, s); };
  ctx.save(); place();
  outline();
  const g = ctx.createLinearGradient(0, -1, 0, hem + 0.2);
  g.addColorStop(0, `rgba(220,255,244,${0.52 * alpha})`); g.addColorStop(0.45, `rgba(160,245,220,${0.32 * alpha})`); g.addColorStop(1, `rgba(110,225,195,${0.16 * alpha})`);
  ctx.fillStyle = g; ctx.fill();
  ctx.restore();
  additive(() => {
    ctx.save(); place();
    glow(0, 0.7, 3.4, "rgba(110,255,205,A)", 0.2 * alpha);
    glow(-0.25, -0.35, 1.1, "rgba(235,255,250,A)", 0.3 * alpha);
    outline();
    ctx.strokeStyle = `rgba(200,255,235,${0.5 * alpha})`; ctx.lineWidth = 0.06; ctx.stroke();
    ctx.strokeStyle = `rgba(220,255,240,${0.1 * alpha})`; ctx.lineWidth = 0.07;
    for (const fx of [-0.55, 0.05, 0.6]) {
      ctx.beginPath(); ctx.moveTo(fx * 0.6, 0.55);
      ctx.quadraticCurveTo(fx + trail(1.4) * 0.6, 1.5, fx * 1.15 + trail(hem), hem - 0.15 + ripple(0.5 + fx * 0.4));
      ctx.stroke();
    }
    ctx.restore();
  }, Math.max(2, s * 0.08));
  ctx.save(); place();
  ctx.fillStyle = `rgba(1,16,12,${0.82 * alpha})`;
  ctx.beginPath(); ctx.ellipse(-0.34, -0.06, 0.15, 0.25, 0.08, 0, TAU); ctx.fill();
  ctx.beginPath(); ctx.ellipse(0.34, -0.06, 0.15, 0.25, -0.08, 0, TAU); ctx.fill();
  ctx.fillStyle = `rgba(1,16,12,${0.55 * alpha})`;
  ctx.beginPath(); ctx.ellipse(0, 0.48, 0.11, 0.17, 0, 0, TAU); ctx.fill();
  ctx.restore();
}
/// A ghost hovering on a closed figure-eight: once across, twice up and down per loop.
function floatingGhost(p, { x, y, s, ax = 80, ay = 30, phase = 0, alpha = 1 }) {
  const gx = x + ax * wave(p, 1, phase), gy = y + ay * wave(p, 2, phase + 0.1);
  const v = Math.cos(TAU * (p + phase));
  drawGhost(p, gx, gy, s * (1 + 0.02 * wave(p, 2, phase)), { alpha, lean: -0.5 * v, tilt: 0.07 * v, ph: phase });
}
/// A ghost that materialises, drifts across a clearing and dissolves again, once per loop.
function wanderingGhost(p, { x, y, s, drift = 260, offset = 0, alpha = 1 }) {
  const life = frac(p + offset);
  const a = alpha * Math.pow(Math.sin(Math.PI * life), 1.4);
  if (a < 0.002) return;
  const dir = Math.sign(drift);
  drawGhost(p, x + drift * (life - 0.5), y + 22 * wave(p, 2, offset), s, { alpha: a, lean: -0.35 * dir, tilt: 0.05 * dir, ph: offset });
}
/// A dead tree trunk rising out of the frame, cylinder-shaded with a cold rim light, a few bare limbs.
function deadTrunk(random, x, bottom, w, p, { fill = "#04100e", fillTop, rim = "rgba(120,255,210,A)", rimAlpha = 0.15, rimSide = 1, branches = 2, top = -40 } = {}) {
  const steps = 28, left = [], right = [];
  const wob = random() * 10, lean = (random() - 0.5) * w * 1.2;
  for (let i = 0; i <= steps; i++) {
    const t = i / steps, y = top + (bottom - top) * t;
    const cx = x + lean * (1 - t) + 0.12 * w * Math.sin(t * 6 + wob);
    const half = (w * (0.72 + 0.28 * t) * (1 + 1.3 * Math.pow(t, 14))) / 2;
    left.push([cx - half, y]); right.push([cx + half, y]);
  }
  const g = ctx.createLinearGradient(x - w, 0, x + w, 0);
  const lit = rim.replace("A", rimAlpha), dark = fill;
  if (rimSide > 0) { g.addColorStop(0, dark); g.addColorStop(0.62, dark); g.addColorStop(0.74, lit); g.addColorStop(0.8, dark); g.addColorStop(1, dark); }
  else { g.addColorStop(0, dark); g.addColorStop(0.2, dark); g.addColorStop(0.26, lit); g.addColorStop(0.38, dark); g.addColorStop(1, dark); }
  ctx.save();
  if (fillTop) { const v = ctx.createLinearGradient(0, top, 0, bottom); v.addColorStop(0, fillTop); v.addColorStop(1, fill); ctx.fillStyle = v; }
  else ctx.fillStyle = dark;
  ctx.beginPath();
  left.forEach(([px, py], i) => (i ? ctx.lineTo(px, py) : ctx.moveTo(px, py)));
  for (let i = right.length - 1; i >= 0; i--) ctx.lineTo(right[i][0], right[i][1]);
  ctx.closePath(); ctx.fill();
  ctx.fillStyle = g; ctx.globalAlpha = fillTop ? 0.35 : 0.9; ctx.fill();
  ctx.globalAlpha = 1;
  // Bark furrows.
  ctx.strokeStyle = "rgba(0,0,0,0.35)"; ctx.lineWidth = Math.max(1, w * 0.04);
  for (let k = 0; k < 3; k++) {
    const off = (random() - 0.5) * 0.6;
    ctx.beginPath();
    left.forEach(([lx, ly], i) => { const px = (lx + right[i][0]) / 2 + off * (right[i][0] - lx) + 2 * Math.sin(i * 0.9 + k); i ? ctx.lineTo(px, ly) : ctx.moveTo(px, ly); });
    ctx.stroke();
  }
  ctx.restore();
  for (let b = 0; b < branches; b++) {
    const i = 3 + Math.floor(random() * (steps * 0.45));
    const side = random() > 0.5 ? 1 : -1;
    const [px, py] = side > 0 ? right[i] : left[i];
    gnarledTree(random, px - side * w * 0.1, py, w * (3 + random() * 3), p, { color: dark, lean: side * (0.7 + random() * 0.5), depth: 4, sway: 0.006, width: w * 0.2, spread: 0.6 });
  }
}
/// A pair of eyes glowing in the dark that blink at fixed points of the loop.
function blinkingEyes(p, x, y, size, gap, color, blinks) {
  let open = 1;
  for (const b of blinks) open = Math.min(open, smoothstep(Math.abs(frac(p - b + 0.5) - 0.5) / 0.022));
  additive(() => {
    for (const side of [-1, 1]) {
      const ex = x + (side * gap) / 2;
      glow(ex, y, size * 5, color, 0.3 * (0.3 + 0.7 * open));
      ctx.fillStyle = color.replace("A", 0.95);
      ctx.beginPath(); ctx.ellipse(ex, y, size, size * 0.6 * Math.max(0.04, open), side * 0.18, 0, TAU); ctx.fill();
      glow(ex, y, size * 0.7, "rgba(255,255,230,A)", 0.7 * open);
    }
  }, 0);
}
/// Dead leaves tumbling down through the mist, one fall per loop; they fade in below the Lock Screen clock.
function fallingLeaves(p, { seed = 1, count = 16 } = {}) {
  const random = rng(seed);
  for (let i = 0; i < count; i++) {
    const x0 = random() * W, y0 = random(), s = 8 + random() * 16, spin = random() > 0.5 ? 1 : -1;
    const flip = 2 + Math.floor(random() * 3), ph = random(), amp = 40 + random() * 90;
    const u = frac(y0 + p);
    const y = -80 + u * (H + 160);
    const x = x0 + amp * wave(p, 2, ph);
    const rot = TAU * spin * p + ph * TAU + 0.5 * wave(p, 3, ph);
    const turn = Math.cos(TAU * (flip * p + ph));
    const fade = smoothstep((y - H * 0.24) / (H * 0.16)) * (0.5 + s / 48);
    if (fade <= 0) continue;
    ctx.save();
    ctx.translate(x, y); ctx.rotate(rot); ctx.scale(s * (0.2 + 0.8 * Math.abs(turn)), s);
    ctx.globalAlpha = fade;
    ctx.fillStyle = turn > 0 ? "#1a2a1c" : "#0e1a12";
    ctx.beginPath(); ctx.moveTo(-1, 0); ctx.quadraticCurveTo(-0.2, -0.75, 1, 0); ctx.quadraticCurveTo(-0.2, 0.75, -1, 0); ctx.fill();
    ctx.strokeStyle = "rgba(120,220,180,0.25)"; ctx.lineWidth = 0.08;
    ctx.beginPath(); ctx.moveTo(-1.3, 0); ctx.lineTo(0.9, 0); ctx.stroke();
    ctx.restore();
  }
}

window.SM = {
  ids: () => Object.keys(scenes),
  current: null,
  async load(id) {
    if (!scenes[id]) throw new Error(`unknown scene ${id}`);
    this.current = id;
    await scenes[id](0, 0);
  },
  async frame(t) {
    ctx.save();
    ctx.clearRect(0, 0, W, H);
    await scenes[this.current](frac(t / LOOP), Math.round(t * 30));
    ctx.restore();
  },
};
