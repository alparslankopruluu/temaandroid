#!/usr/bin/env python3
"""Cut an App Store app preview (886x1920, 30 fps, 15-30 s) from a simulator screen recording.

    python3 scripts/store/preview-video.py <recording.mov> <locale> <out.mp4> start-end:key [start-end:key ...]

Each segment is real app footage; a caption band names what the segment shows. Apple requires an
audio track, so a silent stereo track is added rather than unlicensed music.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

CAPTIONS = {
    "en-US": {"move": "Wallpapers that really move", "touch": "Touch it. Warm it.", "video": "Your video, a Live Photo",
              "nightstand": "A living nightstand"},
    "tr": {"move": "Gerçekten hareket eden duvar kâğıtları", "touch": "Dokun. Isıt.", "video": "Videon, Live Photo olsun",
           "nightstand": "Canlı bir komodin"},
}
WIDTH, HEIGHT, FADE = 886, 1920, 0.35


def caption_png(text: str, path: Path) -> None:
    """A top band over the status bar: dark gradient plus a bold centered line."""
    band = Image.new("RGBA", (WIDTH, 300), (0, 0, 0, 0))
    gradient = Image.linear_gradient("L").rotate(180).resize((WIDTH, 300))
    shade = Image.new("RGBA", (WIDTH, 300), (5, 7, 10, 255))
    shade.putalpha(gradient.point(lambda value: int(value * 0.92)))
    band.alpha_composite(shade)
    font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 56)
    font.set_variation_by_name("Heavy")
    draw = ImageDraw.Draw(band)
    size = 56
    while draw.textlength(text, font=font) > WIDTH - 80 and size > 34:
        size -= 2
        font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
        font.set_variation_by_name("Heavy")
    width = draw.textlength(text, font=font)
    draw.text(((WIDTH - width) / 2, 92), text, font=font, fill=(255, 255, 255, 255))
    band.save(path)


def main() -> None:
    source, locale, target = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    segments = []
    for spec in sys.argv[4:]:
        span, key = spec.split(":")
        start, end = (float(value) for value in span.split("-"))
        segments.append((start, end, key))
    total = sum(end - start for start, end, _ in segments) - FADE * (len(segments) - 1)
    if not 15 <= total <= 30:
        raise SystemExit(f"preview must be 15-30 s, got {total:.1f} s")
    with tempfile.TemporaryDirectory() as directory:
        tmp = Path(directory)
        clips = []
        for index, (start, end, key) in enumerate(segments):
            band = tmp / f"band-{index}.png"
            caption_png(CAPTIONS[locale][key], band)
            clip = tmp / f"clip-{index}.mp4"
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", str(start), "-to", str(end), "-i", str(source),
                "-i", str(band), "-filter_complex",
                f"[0:v]fps=30,scale={WIDTH}:-2:flags=lanczos,crop={WIDTH}:{HEIGHT}[v];[v][1:v]overlay=0:0,format=yuv420p",
                "-an", "-c:v", "libx264", "-preset", "slow", "-crf", "16", str(clip),
            ], check=True)
            clips.append((clip, end - start))
        # Cross-fade the segments, then add the silent stereo track Apple requires.
        inputs, graph, offset, previous = [], [], 0.0, "0:v"
        for index, (clip, _) in enumerate(clips):
            inputs += ["-i", str(clip)]
        for index in range(1, len(clips)):
            offset += clips[index - 1][1] - FADE
            label = f"x{index}"
            graph.append(f"[{previous}][{index}:v]xfade=transition=fade:duration={FADE}:offset={offset:.3f}[{label}]")
            previous = label
        audio_index = len(clips)
        subprocess.run([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *inputs,
            "-f", "lavfi", "-t", f"{total:.3f}", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
            "-filter_complex", ";".join(graph) or "[0:v]null[x0]", "-map", f"[{previous}]" if graph else "[x0]",
            "-map", f"{audio_index}:a", "-r", "30", "-c:v", "libx264", "-profile:v", "high", "-level", "4.0",
            "-pix_fmt", "yuv420p", "-crf", "17", "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart",
            str(target),
        ], check=True)
    print(f"{target.name}: {WIDTH}x{HEIGHT}, {total:.1f} s")


if __name__ == "__main__":
    main()
