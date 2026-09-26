#!/usr/bin/env python3
"""Validate a ScreenMotion schema-v2 manifest and its local Hosting assets."""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path, PurePosixPath
from urllib.parse import urlparse


THEME_ID = re.compile(r"^[a-z0-9][a-z0-9-]{2,47}$")
ASSET_NAME = re.compile(r"^[a-z0-9][a-z0-9_-]{0,31}$")
COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")
IMAGE_EXTENSIONS = {"png", "jpg", "jpeg", "webp"}
AUDIO_EXTENSIONS = {"m4a", "mp3", "aac"}
PARTICLE_PRESETS = {"rain", "ember", "smoke", "firefly", "snow", "bubble", "stardust"}
ANIMATIONS = {"still", "sway", "drift", "flicker", "pulse"}
INTERACTIONS = {"none", "push", "ripple", "swirl", "emberBurst", "bubbleTrail"}
MAX_MANIFEST_BYTES = 1_000_000


class InvalidManifest(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise InvalidManifest(message)


def finite_number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def local_asset(root: Path, relative_path: str, *, audio: bool = False) -> Path:
    path = PurePosixPath(relative_path)
    extensions = AUDIO_EXTENSIONS if audio else IMAGE_EXTENSIONS
    require(not path.is_absolute() and ".." not in path.parts and bool(path.parts), f"unsafe asset path: {relative_path}")
    require(path.suffix.lower().lstrip(".") in extensions, f"unsupported asset format: {relative_path}")
    resolved = (root / Path(*path.parts)).resolve()
    require(resolved.is_relative_to(root.resolve()), f"asset path escapes hosting root: {relative_path}")
    require(resolved.is_file(), f"asset file is missing: {resolved}")
    byte_limit = 8_000_000 if audio else 15_000_000
    require(0 < resolved.stat().st_size <= byte_limit, f"asset must be 1..{byte_limit} bytes: {relative_path}")
    return resolved


def validate(manifest_path: Path, hosting_root: Path) -> tuple[int, int]:
    try:
        raw_manifest = manifest_path.read_bytes()
        require(len(raw_manifest) <= MAX_MANIFEST_BYTES, f"manifest exceeds {MAX_MANIFEST_BYTES} bytes")
        manifest = json.loads(raw_manifest.decode("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise InvalidManifest(f"cannot read JSON manifest: {error}") from error

    require(isinstance(manifest, dict), "manifest root must be an object")
    require(type(manifest.get("schemaVersion")) is int and manifest["schemaVersion"] == 2, "schemaVersion must be 2")
    content_version = manifest.get("contentVersion")
    require(isinstance(content_version, str) and bool(re.fullmatch(r"[1-9][0-9]*", content_version)), "contentVersion must be a positive integer string")
    minimum_app_version = manifest.get("minimumAppVersion")
    require(isinstance(minimum_app_version, str) and bool(re.fullmatch(r"[0-9]+\.[0-9]+(?:\.[0-9]+)?", minimum_app_version)), "minimumAppVersion must be a dotted version")
    base_url = manifest.get("assetBaseURL")
    require(isinstance(base_url, str), "assetBaseURL must be a string")
    try:
        base = urlparse(base_url)
    except ValueError as error:
        raise InvalidManifest(f"invalid assetBaseURL: {error}") from error
    require(base.scheme == "https" and bool(base.netloc) and not base.username and not base.password and not base.query and not base.fragment,
            "assetBaseURL must be an HTTPS directory URL without credentials, query, or fragment")
    require(base.path.endswith("/"), "assetBaseURL must end with a slash")

    themes = manifest.get("themes")
    require(isinstance(themes, list) and len(themes) <= 48, "themes must be an array with at most 48 entries")
    seen: set[str] = set()
    asset_count = 0
    for theme in themes:
        require(isinstance(theme, dict), "every theme must be an object")
        theme_id = theme.get("id", "")
        require(isinstance(theme_id, str) and THEME_ID.fullmatch(theme_id) is not None, f"invalid theme id: {theme_id!r}")
        require(theme_id not in seen, f"duplicate theme id: {theme_id}")
        seen.add(theme_id)

        localized = theme.get("localizedText")
        require(isinstance(localized, dict), f"{theme_id}: localizedText must be an object")
        for locale, fields in localized.items():
            require(isinstance(locale, str) and bool(locale) and isinstance(fields, dict), f"{theme_id}: invalid localized text")
            title = fields.get("title", "")
            summary = fields.get("summary", "")
            require(isinstance(title, str) and bool(title.strip()) and len(title) <= 80, f"{theme_id}/{locale}: title must be 1..80 characters")
            require(isinstance(summary, str) and len(summary) <= 240, f"{theme_id}/{locale}: summary must be at most 240 characters")
            require(set(fields) <= {"title", "summary"}, f"{theme_id}/{locale}: unknown localized field")
        english = localized.get("en")
        require(isinstance(english, dict) and isinstance(english.get("title"), str) and bool(english["title"].strip()), f"{theme_id}: English title is required")

        appearance, access_policy = theme.get("appearance"), theme.get("accessPolicy")
        require(isinstance(appearance, str) and appearance in {"realistic", "pixel"}, f"{theme_id}: appearance must be realistic or pixel")
        require(isinstance(access_policy, str) and access_policy in {"free", "pro"}, f"{theme_id}: accessPolicy must be free or pro")
        recipe = theme.get("scene")
        require(isinstance(recipe, dict), f"{theme_id}: scene recipe is required")
        audio_name = recipe.get("ambientAudioAsset")
        require(audio_name is None or isinstance(audio_name, str), f"{theme_id}: ambient audio asset name must be a string")
        assets = theme.get("assets")
        require(isinstance(assets, dict) and "artwork" in assets and len(assets) <= 12, f"{theme_id}: artwork and at most 11 other assets are required")
        for name, relative_path in assets.items():
            require(isinstance(name, str) and ASSET_NAME.fullmatch(name) is not None, f"{theme_id}: invalid asset name {name!r}")
            require(isinstance(relative_path, str), f"{theme_id}/{name}: asset path must be a string")
            parts = PurePosixPath(relative_path).parts
            require(len(parts) >= 3 and parts[0] == "assets" and parts[1] == str(manifest["contentVersion"]),
                    f"{theme_id}/{name}: put assets under assets/<contentVersion>/ so immutable caching cannot serve stale bytes")
            local_asset(hosting_root / "v2", relative_path, audio=name == audio_name)
            asset_count += 1

        layers = recipe.get("layers")
        require(isinstance(layers, list) and 1 <= len(layers) <= 8, f"{theme_id}: scene needs 1..8 layers")
        for layer in layers:
            require(isinstance(layer, dict), f"{theme_id}: every layer must be an object")
            layer_asset, animation = layer.get("asset"), layer.get("animation")
            require(isinstance(layer_asset, str) and layer_asset in assets, f"{theme_id}: layer references an unknown asset")
            require(isinstance(animation, str) and animation in ANIMATIONS, f"{theme_id}: unsupported layer animation")
            parallax, amount, period = layer.get("parallax"), layer.get("amount"), layer.get("period")
            require(finite_number(parallax) and -1 <= parallax <= 1, f"{theme_id}: parallax must be -1..1")
            require(finite_number(amount) and 0 <= amount <= 1, f"{theme_id}: amount must be 0..1")
            require(finite_number(period) and 0.5 <= period <= 90, f"{theme_id}: period must be 0.5..90 seconds")

        emitters = recipe.get("particles", [])
        require(isinstance(emitters, list) and len(emitters) <= 4, f"{theme_id}: at most 4 particle emitters are allowed")
        total_particles = 0
        for emitter in emitters:
            require(isinstance(emitter, dict), f"{theme_id}: every particle emitter must be an object")
            preset = emitter.get("preset")
            require(isinstance(preset, str) and preset in PARTICLE_PRESETS, f"{theme_id}: unsupported particle preset")
            count, speed = emitter.get("count"), emitter.get("speed")
            require(type(count) is int and 0 <= count <= 120, f"{theme_id}: particle count must be 0..120")
            require(finite_number(speed) and 0 <= speed <= 2, f"{theme_id}: particle speed must be 0..2")
            total_particles += count
        require(total_particles <= 160, f"{theme_id}: total particles must not exceed 160")

        light = recipe.get("light")
        if light is not None:
            require(isinstance(light, dict), f"{theme_id}: light must be an object")
            light_color = light.get("color")
            require(isinstance(light_color, str) and COLOR.fullmatch(light_color) is not None, f"{theme_id}: invalid light color")
            for field, minimum, maximum in (("x", 0, 1), ("y", 0, 1), ("radius", 0, 0.5), ("flicker", 0, 1), ("period", 0.5, 30)):
                value = light.get(field)
                require(finite_number(value) and minimum <= value <= maximum, f"{theme_id}: light {field} is out of range")
        interaction = recipe.get("interaction")
        require(isinstance(interaction, str) and interaction in INTERACTIONS, f"{theme_id}: unsupported touch interaction")
        require(audio_name is None or audio_name in assets, f"{theme_id}: ambient audio references an unknown asset")

    return len(themes), asset_count


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", nargs="?", type=Path, default=Path("remote-content/public/v2/manifest.json"))
    parser.add_argument("--hosting-root", type=Path, default=Path("remote-content/public"))
    args = parser.parse_args()
    try:
        themes, assets = validate(args.manifest, args.hosting_root)
    except InvalidManifest as error:
        print(f"INVALID: {error}", file=sys.stderr)
        return 1
    except (AttributeError, KeyError, OSError, OverflowError, TypeError, ValueError) as error:
        print(f"INVALID: malformed manifest: {error}", file=sys.stderr)
        return 1
    print(f"Valid schema-v2 manifest: {themes} themes, {assets} assets")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
