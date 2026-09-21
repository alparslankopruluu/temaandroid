#!/usr/bin/env python3
"""Fail when XcodeGen's app device families drift from the generated project."""

from __future__ import annotations

import re
import sys
from pathlib import Path


TARGET_NAME = "ScreenMotion"
SETTING_NAME = "TARGETED_DEVICE_FAMILY"


class VerificationError(Exception):
    """Raised when the configuration cannot be compared safely."""


def normalize_families(raw_value: str) -> tuple[str, ...]:
    value = raw_value.strip().strip("'\"")
    families = tuple(sorted(part.strip() for part in value.split(",") if part.strip()))
    if not families or any(not part.isdigit() for part in families):
        raise VerificationError(f"Invalid {SETTING_NAME} value: {raw_value!r}")
    return families


def yaml_device_families(text: str) -> tuple[str, ...]:
    paths: dict[tuple[str, ...], str] = {}
    stack: list[tuple[int, str]] = []

    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        match = re.match(r"^(?P<indent>\s*)(?P<key>[^:#][^:]*):(?:\s*(?P<value>.*))?$", line)
        if match is None:
            continue
        indent = len(match.group("indent"))
        key = match.group("key").strip()
        value = (match.group("value") or "").split(" #", 1)[0].strip()
        while stack and stack[-1][0] >= indent:
            stack.pop()
        path = tuple(item[1] for item in stack) + (key,)
        if value:
            paths[path] = value
        else:
            stack.append((indent, key))

    target_path = ("targets", TARGET_NAME, "settings", "base", SETTING_NAME)
    project_path = ("settings", "base", SETTING_NAME)
    raw_value = paths.get(target_path, paths.get(project_path))
    if raw_value is None:
        raise VerificationError(
            f"{SETTING_NAME} is missing from both the project and {TARGET_NAME} settings in project.yml"
        )
    return normalize_families(raw_value)


def block_for_identifier(text: str, identifier: str, comment: str, isa: str) -> str:
    pattern = re.compile(
        rf"^\s*{re.escape(identifier)} /\* {re.escape(comment)} \*/ = \{{\n"
        rf"(?P<body>.*?)^\s*\}};\n",
        re.MULTILINE | re.DOTALL,
    )
    for match in pattern.finditer(text):
        body = match.group("body")
        if re.search(rf"^\s*isa = {re.escape(isa)};\s*$", body, re.MULTILINE):
            return body
    raise VerificationError(f"Could not find {isa} block for {comment} ({identifier})")


def pbxproj_device_families(text: str) -> dict[str, tuple[str, ...]]:
    target_match = re.search(
        rf"^\s*(?P<id>[A-F0-9]+) /\* {re.escape(TARGET_NAME)} \*/ = \{{\n"
        rf"(?P<body>.*?)^\s*\}};\n",
        text,
        re.MULTILINE | re.DOTALL,
    )
    if target_match is None or "isa = PBXNativeTarget;" not in target_match.group("body"):
        raise VerificationError(f"Could not find PBXNativeTarget {TARGET_NAME}")

    list_match = re.search(
        r"buildConfigurationList = (?P<id>[A-F0-9]+) /\* Build configuration list for "
        r"PBXNativeTarget \"ScreenMotion\" \*/;",
        target_match.group("body"),
    )
    if list_match is None:
        raise VerificationError(f"Could not find build configuration list for {TARGET_NAME}")

    list_id = list_match.group("id")
    list_body = block_for_identifier(
        text,
        list_id,
        f'Build configuration list for PBXNativeTarget "{TARGET_NAME}"',
        "XCConfigurationList",
    )
    configurations_match = re.search(
        r"buildConfigurations = \((?P<items>.*?)\);",
        list_body,
        re.DOTALL,
    )
    if configurations_match is None:
        raise VerificationError(f"Could not read build configurations for {TARGET_NAME}")

    identifiers = re.findall(
        r"([A-F0-9]+) /\* ([^*]+) \*/",
        configurations_match.group("items"),
    )
    if not identifiers:
        raise VerificationError(f"No build configurations found for {TARGET_NAME}")

    result: dict[str, tuple[str, ...]] = {}
    for identifier, configuration_name in identifiers:
        body = block_for_identifier(text, identifier, configuration_name, "XCBuildConfiguration")
        setting_match = re.search(
            rf"^\s*{SETTING_NAME} = (?P<value>[^;]+);\s*$",
            body,
            re.MULTILINE,
        )
        if setting_match is None:
            raise VerificationError(
                f"Generated {TARGET_NAME} {configuration_name} configuration has no explicit {SETTING_NAME}"
            )
        result[configuration_name] = normalize_families(setting_match.group("value"))
    return result


def main() -> int:
    repository = Path(__file__).resolve().parent.parent
    yaml_path = repository / "project.yml"
    pbxproj_path = repository / "ScreenMotion.xcodeproj" / "project.pbxproj"

    try:
        expected = yaml_device_families(yaml_path.read_text(encoding="utf-8"))
        generated = pbxproj_device_families(pbxproj_path.read_text(encoding="utf-8"))
    except (OSError, VerificationError) as error:
        print(f"Project configuration verification failed: {error}", file=sys.stderr)
        return 2

    drifted = {name: value for name, value in generated.items() if value != expected}
    if drifted:
        expected_text = ",".join(expected)
        actual_text = "; ".join(
            f"{name}={','.join(value)}" for name, value in sorted(drifted.items())
        )
        print(
            f"Project configuration drift: project.yml expects {TARGET_NAME} "
            f"{SETTING_NAME}={expected_text}, generated project has {actual_text}",
            file=sys.stderr,
        )
        return 1

    families = ",".join(expected)
    configurations = ", ".join(sorted(generated))
    print(
        f"Project configuration verified: {TARGET_NAME} {SETTING_NAME}={families} "
        f"for {configurations}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
