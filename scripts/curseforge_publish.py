#!/usr/bin/env python3
"""
curseforge_publish.py — Upload packaged addon zips to CurseForge.

Usage:
    # Upload all addons (suite release, tag v1.5.1):
    python3 scripts/curseforge_publish.py <dist_dir> <version>

    # Upload a single addon (per-addon release, tag SlyRotate-v1.2.0):
    python3 scripts/curseforge_publish.py <dist_dir> <version> --addon <AddonName>

Reads config.json for `curseProjectId` per addon.
Skips addons where curseProjectId is empty or missing.
Requires CURSEFORGE_TOKEN environment variable (set as a GitHub Actions secret).

To publish an addon:
  1. Create the project on https://www.curseforge.com/wow/addons
  2. Copy the numeric Project ID from the project page
  3. Set "curseProjectId": "<id>" for that addon in config.json
  4. Add CURSEFORGE_TOKEN secret to your GitHub repository settings

TBC Classic Anniversary = gameVersionTypeID 67 on CurseForge.
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request


CF_API = "https://wow.curseforge.com/api"
GAME_VERSION_TYPE_ID = 73246  # Burning Crusade Classic / TBC Anniversary
GAME_VERSION_FALLBACK = [73246]  # used if API lookup returns empty
BOUNDARY = "CF_BOUNDARY_SLYSUITE_UPLOAD"


def cf_request(path: str, token: str, data: bytes = None,
               content_type: str = None) -> dict:
    url = f"{CF_API}{path}"
    headers = {"X-Api-Token": token}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=data, headers=headers,
                                  method="POST" if data else "GET")
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        raise RuntimeError(f"HTTP {e.code}: {body}") from e


def build_multipart(metadata: dict, zip_path: str) -> bytes:
    meta_bytes = json.dumps(metadata).encode()
    with open(zip_path, "rb") as f:
        file_bytes = f.read()
    filename = os.path.basename(zip_path)

    def part_header(name, filename=None, content_type=None):
        disp = f'form-data; name="{name}"'
        if filename:
            disp += f'; filename="{filename}"'
        hdr = f"--{BOUNDARY}\r\nContent-Disposition: {disp}\r\n"
        if content_type:
            hdr += f"Content-Type: {content_type}\r\n"
        hdr += "\r\n"
        return hdr.encode()

    return (
        part_header("metadata")
        + meta_bytes + b"\r\n"
        + part_header("file", filename=filename, content_type="application/zip")
        + file_bytes + b"\r\n"
        + f"--{BOUNDARY}--\r\n".encode()
    )


def main():
    parser = argparse.ArgumentParser(
        description="Upload addon zips to CurseForge.")
    parser.add_argument("dist_dir", help="Directory containing packaged .zip files")
    parser.add_argument("version",  help="Version string (e.g. 1.2.0)")
    parser.add_argument("--addon",  default=None,
                        help="If set, upload only this addon (e.g. SlyRotate). "
                             "Used by per-addon release tags (<AddonName>-v*).")
    args = parser.parse_args()

    dist_dir    = args.dist_dir
    version     = args.version
    addon_filter = args.addon  # None = all addons; str = single addon name
    token = (os.environ.get("CURSEFORGE_TOKEN") or os.environ.get("CF_API_KEY") or "").strip()

    if not token:
        print("CF_API_KEY / CURSEFORGE_TOKEN not set — skipping CurseForge upload.")
        sys.exit(0)

    with open("config.json") as f:
        config = json.load(f)

    # Resolve TBC Classic game version IDs from CurseForge
    print(f"Fetching CurseForge game versions (typeID={GAME_VERSION_TYPE_ID})...")
    tbc_ids = []
    try:
        all_versions = cf_request("/game/versions", token)
        tbc_ids = [v["id"] for v in all_versions
                   if v.get("gameVersionTypeID") == GAME_VERSION_TYPE_ID]
        print(f"Found {len(tbc_ids)} TBC Classic version ID(s): {tbc_ids[:5]}")
    except RuntimeError as e:
        print(f"WARNING: Could not fetch game versions ({e}) — using fallback.")
    if not tbc_ids:
        tbc_ids = GAME_VERSION_FALLBACK
        print(f"WARNING: Using hardcoded fallback version IDs: {tbc_ids}")

    errors = 0
    skipped = 0
    uploaded = 0

    for addon in config.get("addons", []):
        name     = addon["name"]
        curse_id = str(addon.get("curseProjectId", "")).strip()

        # Per-addon mode: only process the target addon
        if addon_filter and name != addon_filter:
            continue

        # Suite mode: skip addons with their own standalone per-addon release workflow
        if not addon_filter and addon.get("standaloneRelease"):
            print(f"SKIP  {name:<22} — standaloneRelease=true (has its own addon-release tag)")
            skipped += 1
            continue

        if not curse_id:
            print(f"SKIP  {name:<22} — curseProjectId not set in config.json")
            skipped += 1
            continue

        zip_path = os.path.join(dist_dir, f"{name}-{version}.zip")
        if not os.path.exists(zip_path):
            print(f"SKIP  {name:<22} — zip not found: {zip_path}")
            skipped += 1
            continue

        # Use the tag from which this run was triggered for the changelog link.
        # For per-addon releases the tag is <AddonName>-v<version>.
        if addon_filter:
            tag_ref = f"{addon_filter}-v{version}"
        else:
            tag_ref = f"v{version}"

        metadata = {
            "changelog": (
                f"https://github.com/kyleian/wow-addons/releases/tag/{tag_ref}"
            ),
            "changelogType": "markdown",
            "displayName": f"{name} v{version}",
            "gameVersions": tbc_ids[:1] if tbc_ids else [],
            "releaseType": "release",
        }

        body = build_multipart(metadata, zip_path)
        content_type = f"multipart/form-data; boundary={BOUNDARY}"

        try:
            result = cf_request(f"/projects/{curse_id}/upload-file",
                                 token, data=body, content_type=content_type)
            print(f"OK    {name:<22} → CurseForge file ID {result.get('id')}")
            uploaded += 1
        except RuntimeError as e:
            print(f"FAIL  {name:<22} : {e}")
            errors += 1

    if addon_filter and uploaded == 0 and errors == 0 and skipped == 0:
        print(f"ERROR: addon '{addon_filter}' not found in config.json")
        sys.exit(1)

    print(f"\nDone — {uploaded} uploaded, {skipped} skipped, {errors} failed.")

    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
