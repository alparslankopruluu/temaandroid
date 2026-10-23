#!/usr/bin/env python3
"""Build App Store header (21:9) and search-result (3:2) videos from the app's cinematic loops.

    python3 scripts/store/hero-video.py <out-dir> [--event halloween]

A row of living Lock Screen cards, each playing a bundled loop under a 9:41 clock. The length is
two loop periods, so the video repeats without a visible cut. No text beyond the clock.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent.parent.parent
loops = root / "App/Resources/Loops"
out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
SECONDS = 12  # two 6 s loop periods
EVENT_SECONDS = 18  # in-app event videos need 15-30 s: three loop periods
# Asset Library needs square pixels (setsar=1) at the exact spec size and standard BT.709 video.
COLOR = ["-pix_fmt", "yuv420p", "-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709"]

FORMATS = {
    "header-3840x1646": (3840, 1646, ["neon-rain", "jellyfish", "midnight", "aurora", "event-horizon"], 1220),
    "search-2400x1600": (2400, 1600, ["midnight", "jellyfish", "aurora"], 1320),
}
# In-app event card (16:9) as a row of cards; the details page (9:16) is one full-bleed loop.
EVENTS = {
    "halloween": {
        "event-card-1920x1080": (1920, 1080, ["halloween-moon", "halloween-pumpkins", "halloween-ghosts"], 900),
        "event-details": "halloween-moon",
    },
}


def card_overlays(directory: Path, width: int, height: int) -> tuple[Path, Path]:
    """Rounded-corner mask plus a transparent 9:41 clock layer for one card size."""
    radius = int(width * 0.11)
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, fill=255)
    mask_path = directory / f"mask-{width}.png"
    mask.save(mask_path)
    clock = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(clock)
    font = ImageFont.truetype("/System/Library/Fonts/SFNSRounded.ttf", int(width * 0.27))
    font.set_variation_by_name("Semibold")
    text = "9:41"
    box = draw.textbbox((0, 0), text, font=font)
    x = (width - (box[2] - box[0])) / 2 - box[0]
    y = height * 0.1
    draw.text((x, y + 3), text, font=font, fill=(0, 0, 0, 60))
    draw.text((x, y), text, font=font, fill=(255, 255, 255, 236))
    clock_path = directory / f"clock-{width}.png"
    clock.save(clock_path)
    return mask_path, clock_path


def build(name: str, width: int, height: int, scenes: list[str], card_height: int, tmp: Path, seconds: int = SECONDS) -> None:
    card_width = round(card_height * 9 / 16) // 2 * 2
    gap = (width - card_width * len(scenes)) // (len(scenes) + 1)
    top = (height - card_height) // 2
    mask, clock = card_overlays(tmp, card_width, card_height)
    inputs = []
    for scene in scenes:
        inputs += ["-stream_loop", "-1", "-t", str(seconds), "-i", str(loops / f"loop-{scene}.mp4")]
    inputs += ["-loop", "1", "-t", str(seconds), "-i", str(mask), "-loop", "1", "-t", str(seconds), "-i", str(clock)]
    mask_index, clock_index = len(scenes), len(scenes) + 1
    graph = [
        # Backdrop: the centre scene, blurred and darkened so the cards carry the frame.
        f"[{len(scenes) // 2}:v]scale={width}:-2,crop={width}:{height},boxblur=60:2,eq=brightness=-0.32:saturation=1.3,fps=30[bg0]",
        f"[{mask_index}:v]format=gray,split={len(scenes)}" + "".join(f"[m{i}]" for i in range(len(scenes))),
        f"[{clock_index}:v]format=rgba,split={len(scenes)}" + "".join(f"[k{i}]" for i in range(len(scenes))),
    ]
    for i in range(len(scenes)):
        graph.append(f"[{i}:v]scale={card_width}:{card_height},fps=30,format=rgba[s{i}]")
        graph.append(f"[s{i}][k{i}]overlay=0:0[c{i}]")
        graph.append(f"[c{i}][m{i}]alphamerge[a{i}]")
    previous = "bg0"
    for i in range(len(scenes)):
        x = gap + i * (card_width + gap)
        graph.append(f"[{previous}][a{i}]overlay={x}:{top}:shortest=1[bg{i + 1}]")
        previous = f"bg{i + 1}"
    graph.append(f"[{previous}]scale=out_color_matrix=bt709:out_range=tv,setsar=1,format=yuv420p[v]")
    target = out / f"{name}.mp4"
    subprocess.run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *inputs,
        "-filter_complex", ";".join(graph), "-map", "[v]", "-t", str(seconds), "-r", "30",
        "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-profile:v", "high", *COLOR, "-movflags", "+faststart", str(target),
    ], check=True)
    # Poster frame for review and for image-only placements.
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", "1.5", "-i", str(target),
                    "-frames:v", "1", str(out / f"{name}.png")], check=True)
    print(f"{target.name}: {width}x{height}, {seconds}s")


def full_bleed(name: str, scene: str, seconds: int) -> None:
    """A single loop repeated to length and re-encoded as H.264 for the event details page."""
    target = out / f"{name}.mp4"
    subprocess.run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-stream_loop", "-1", "-t", str(seconds),
        "-i", str(loops / f"loop-{scene}.mp4"), "-t", str(seconds), "-r", "30", "-vf", "scale=1080:1920:out_color_matrix=bt709:out_range=tv,setsar=1,format=yuv420p",
        "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-profile:v", "high", *COLOR, "-movflags", "+faststart", str(target),
    ], check=True)
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", "2", "-i", str(target),
                    "-frames:v", "1", str(out / f"{name}.png")], check=True)
    print(f"{target.name}: 1080x1920, {seconds}s")


event = sys.argv[sys.argv.index("--event") + 1] if "--event" in sys.argv else None
with tempfile.TemporaryDirectory() as directory:
    if event:
        for name, spec in EVENTS[event].items():
            if isinstance(spec, str):
                full_bleed(name, spec, EVENT_SECONDS)
            else:
                width, height, scenes, card_height = spec
                build(name, width, height, scenes, card_height, Path(directory), EVENT_SECONDS)
    else:
        for name, (width, height, scenes, card_height) in FORMATS.items():
            build(name, width, height, scenes, card_height, Path(directory))
