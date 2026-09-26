#!/usr/bin/env python3
"""Validate and deploy only the static ScreenMotion Hosting catalog."""

from __future__ import annotations

import argparse
import json
import runpy
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECTS = {
    "dev": "screenmotion-dev",
    "prod": "screenmotion-prod",
}
validate = runpy.run_path(str(Path(__file__).with_name("validate-remote-themes.py")))["validate"]


def listed_projects() -> set[str]:
    try:
        result = subprocess.run(["firebase", "projects:list", "--json"], check=False,
                                capture_output=True, text=True)
    except OSError as error:
        raise RuntimeError(f"could not run Firebase CLI: {error}") from error
    if result.returncode != 0:
        detail = result.stderr.strip() or f"exit code {result.returncode}"
        raise RuntimeError(f"Firebase project list failed: {detail}")
    try:
        decoded = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"Firebase CLI returned invalid project-list JSON: {error}") from error

    payload = decoded.get("result", decoded) if isinstance(decoded, dict) else decoded
    if isinstance(payload, list):
        projects = payload
    elif isinstance(payload, dict) and isinstance(payload.get("projects"), list):
        projects = payload["projects"]
    else:
        raise RuntimeError("Firebase CLI project-list JSON has an unexpected shape")
    return {item["projectId"] for item in projects
            if isinstance(item, dict) and isinstance(item.get("projectId"), str)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--environment", required=True, choices=PROJECTS)
    parser.add_argument("--deploy", action="store_true", help="perform the Firebase Hosting write; default is a dry run")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    project_id = PROJECTS[args.environment]
    manifest_path = root / "remote-content/public/v2/manifest.json"
    public_root = root / "remote-content/public"
    validate(manifest_path, public_root)

    try:
        available = listed_projects()
    except RuntimeError as error:
        print(f"{error}; no deployment was attempted.", file=sys.stderr)
        return 2
    if project_id not in available:
        print(f"Firebase project {project_id!r} is not accessible; no deployment was attempted.", file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory(prefix="screenmotion-hosting-") as temporary:
        staged_public = Path(temporary) / "public"
        shutil.copytree(public_root, staged_public)
        staged_manifest = staged_public / "v2/manifest.json"
        manifest = json.loads(staged_manifest.read_text(encoding="utf-8"))
        manifest["assetBaseURL"] = f"https://{project_id}.web.app/v2/"
        staged_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

        command = ["firebase", "deploy", "--only", "hosting", "--project", project_id,
                   "--public", str(staged_public), "--message",
                   f"ScreenMotion schema-v2 themes ({args.environment}, {manifest['contentVersion']})"]
        if not args.deploy:
            command.append("--dry-run")
        print(f"Target: {args.environment} ({project_id})")
        print("Action: Hosting deploy" if args.deploy else "Action: Hosting dry run (no content published)")
        print(f"Catalog: {len(manifest.get('themes', []))} themes, contentVersion {manifest['contentVersion']}")
        completed = subprocess.run(command, cwd=root, check=False)
        return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
