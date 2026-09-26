#!/usr/bin/env python3
"""Fail when generated Android content drifts from the owned iOS source."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ANDROID = Path(__file__).resolve().parents[1]
ROOT = ANDROID.parent
IOS = ROOT / "App" / "Resources"
RES = ANDROID / "app" / "src" / "main" / "res"

source_catalog = IOS / "catalog.json"
android_catalog = RES / "raw" / "catalog.json"
if source_catalog.read_bytes() != android_catalog.read_bytes():
    raise SystemExit("Android catalog.json differs from the canonical iOS catalog")

catalog = json.loads(android_catalog.read_text())
source_ids = [item["id"] for item in json.loads(source_catalog.read_text())["themes"]]
if [item["id"] for item in catalog["themes"]] != source_ids:
    raise SystemExit("Android theme order or ids differ from the canonical iOS catalog")

source_strings = json.loads((IOS / "Localizable.xcstrings").read_text())["strings"]
value_dirs = sorted(path for path in RES.glob("values*") if (path / "strings.xml").exists())
if len(value_dirs) != 22:
    raise SystemExit(f"Expected 22 locale folders, found {len(value_dirs)}")
for directory in value_dirs:
    names = [node.attrib["name"] for node in ET.parse(directory / "strings.xml").getroot().findall("string")]
    if len(names) != len(set(names)):
        raise SystemExit(f"Duplicate string resource in {directory.name}")
    expected = len(source_strings) + 19
    if len(names) != expected:
        raise SystemExit(f"Unexpected string count in {directory.name}: {len(names)}")

source_art = sorted((IOS / "Assets.xcassets").glob("*.imageset/art.png"))
android_art = sorted((RES / "drawable-nodpi").glob("*.png"))
if len(source_art) != len(android_art):
    raise SystemExit(f"Artwork count differs: iOS {len(source_art)}, Android {len(android_art)}")
source_hashes = sorted(hashlib.sha256(path.read_bytes()).hexdigest() for path in source_art)
android_hashes = sorted(hashlib.sha256(path.read_bytes()).hexdigest() for path in android_art)
if source_hashes != android_hashes:
    raise SystemExit("Android artwork bytes differ from the owned iOS artwork")

print(f"Android content verified: {len(source_ids)} themes, 22 locales, {len(source_strings)} iOS keys, {len(source_art)} artwork files")
