#!/usr/bin/env python3
"""Update the SwiftDump formula from its latest verified stable release."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
import urllib.request
from pathlib import Path
from urllib.parse import urlparse


TAG_PATTERN = re.compile(r"^v(?P<version>\d+\.\d+\.\d+)$")
CHECKSUM_PATTERN = re.compile(r"^[0-9a-f]{64}$")
ALLOWED_DOWNLOAD_HOSTS = {"github.com", "release-assets.githubusercontent.com"}


class UpdateError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", default="YuXilong/SwiftDump")
    parser.add_argument("--formula", type=Path, default=Path("Formula/swift-dump.rb"))
    parser.add_argument("--readme", type=Path, default=Path("README.md"))
    return parser.parse_args()


def request_bytes(url: str, token: str | None = None) -> bytes:
    parsed = urlparse(url)
    if parsed.scheme != "https":
        raise UpdateError(f"refusing non-HTTPS URL: {url}")

    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "SwiftDump-Homebrew-Updater",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if token and parsed.hostname == "api.github.com":
        headers["Authorization"] = f"Bearer {token}"

    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        final_url = urlparse(response.geturl())
        if parsed.hostname == "api.github.com" and final_url.hostname != "api.github.com":
            raise UpdateError(f"unexpected API redirect host: {final_url.hostname}")
        if parsed.hostname != "api.github.com" and final_url.hostname not in ALLOWED_DOWNLOAD_HOSTS:
            raise UpdateError(f"unexpected download redirect host: {final_url.hostname}")
        return response.read()


def find_asset(release: dict[str, object], name: str) -> dict[str, object]:
    assets = release.get("assets")
    if not isinstance(assets, list):
        raise UpdateError("latest release response has no asset list")

    matches = [asset for asset in assets if isinstance(asset, dict) and asset.get("name") == name]
    if len(matches) != 1:
        raise UpdateError(f"expected exactly one release asset named {name}, found {len(matches)}")
    return matches[0]


def asset_url(asset: dict[str, object], expected_url: str) -> str:
    url = asset.get("browser_download_url")
    if url != expected_url:
        raise UpdateError(f"unexpected asset URL for {asset.get('name')}: {url}")
    return expected_url


def checksum_from_manifest(manifest: str, filename: str) -> str:
    matches: list[str] = []
    for line in manifest.splitlines():
        parts = line.strip().split()
        if len(parts) != 2:
            continue
        checksum, listed_name = parts
        if listed_name.lstrip("*") == filename and CHECKSUM_PATTERN.fullmatch(checksum):
            matches.append(checksum)

    if len(matches) != 1:
        raise UpdateError(f"expected exactly one checksum for {filename}, found {len(matches)}")
    return matches[0]


def version_tuple(version: str) -> tuple[int, int, int]:
    components = tuple(int(component) for component in version.split("."))
    if len(components) != 3:
        raise UpdateError(f"semantic version must have three components: {version}")
    return components[0], components[1], components[2]


def replace_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, flags=re.MULTILINE)
    if count != 1:
        raise UpdateError(f"expected one {label} replacement, found {count}")
    return updated


def main() -> int:
    args = parse_args()
    token = os.environ.get("GITHUB_TOKEN")
    api_url = f"https://api.github.com/repos/{args.repository}/releases/latest"
    release = json.loads(request_bytes(api_url, token))
    if not isinstance(release, dict):
        raise UpdateError("latest release response must be a JSON object")

    if release.get("draft") or release.get("prerelease"):
        raise UpdateError("latest release must be stable and published")

    tag = release.get("tag_name")
    if not isinstance(tag, str):
        raise UpdateError("latest release has no tag_name")
    tag_match = TAG_PATTERN.fullmatch(tag)
    if not tag_match:
        raise UpdateError(f"latest release tag must match vX.Y.Z: {tag}")
    version = tag_match.group("version")

    archive_name = f"SwiftDump-{tag}-macos-universal.zip"
    release_base = f"https://github.com/{args.repository}/releases/download/{tag}"
    archive_url = f"{release_base}/{archive_name}"
    sums_url = f"{release_base}/SHA256SUMS"

    archive_asset = find_asset(release, archive_name)
    sums_asset = find_asset(release, "SHA256SUMS")
    asset_url(archive_asset, archive_url)
    asset_url(sums_asset, sums_url)

    with tempfile.TemporaryDirectory(prefix="swift-dump-formula-") as temp_dir:
        archive = request_bytes(archive_url)
        manifest = request_bytes(sums_url).decode("utf-8")
        archive_path = Path(temp_dir) / archive_name
        archive_path.write_bytes(archive)

        published_checksum = checksum_from_manifest(manifest, archive_name)
        actual_checksum = hashlib.sha256(archive_path.read_bytes()).hexdigest()
        if actual_checksum != published_checksum:
            raise UpdateError(
                f"archive checksum mismatch: manifest={published_checksum} actual={actual_checksum}"
            )

        api_digest = archive_asset.get("digest")
        if api_digest and api_digest != f"sha256:{actual_checksum}":
            raise UpdateError(f"GitHub asset digest mismatch: {api_digest}")

    formula = args.formula.read_text(encoding="utf-8")
    current_url_match = re.search(r'^  url "([^"]+)"$', formula, re.MULTILINE)
    current_checksum_match = re.search(r'^  sha256 "([0-9a-f]{64})"$', formula, re.MULTILINE)
    if not current_url_match or not current_checksum_match:
        raise UpdateError("could not parse the current formula version and checksum")

    current_url = current_url_match.group(1)
    current_tag_match = re.search(r"/releases/download/(v\d+\.\d+\.\d+)/", current_url)
    if not current_tag_match:
        raise UpdateError("could not parse the current formula release tag")
    current_tag = current_tag_match.group(1)
    current_version = current_tag.removeprefix("v")
    current_checksum = current_checksum_match.group(1)
    if version_tuple(version) < version_tuple(current_version):
        raise UpdateError(f"refusing formula downgrade from {current_tag} to {tag}")
    if version == current_version and current_url != archive_url:
        raise UpdateError(f"immutable release URL changed for {tag}")
    if version == current_version and current_checksum != actual_checksum:
        raise UpdateError(f"immutable release checksum changed for {tag}")

    updated_formula = formula
    if version != current_version:
        updated_formula = replace_once(
            updated_formula,
            r'^  url "https://github\.com/YuXilong/SwiftDump/releases/download/[^\"]+"$',
            f'  url "{archive_url}"',
            "formula URL",
        )
        updated_formula = replace_once(
            updated_formula,
            r'^  sha256 "[0-9a-f]{64}"$',
            f'  sha256 "{actual_checksum}"',
            "formula checksum",
        )

    readme = args.readme.read_text(encoding="utf-8")
    updated_readme = replace_once(
        readme,
        r'^(\| `swift-dump` \| )[^|]+( \| 从 Mach-O 恢复 Swift 类型定义 \| arm64 / x86_64 \|)$',
        rf"\g<1>{version}\g<2>",
        "README swift-dump version",
    )

    changed = updated_formula != formula or updated_readme != readme
    if updated_formula != formula:
        args.formula.write_text(updated_formula, encoding="utf-8")
    if updated_readme != readme:
        args.readme.write_text(updated_readme, encoding="utf-8")

    output = {
        "changed": changed,
        "sha256": actual_checksum,
        "tag": tag,
        "version": version,
    }
    print(json.dumps(output, ensure_ascii=False, sort_keys=True))

    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with Path(github_output).open("a", encoding="utf-8") as output_file:
            for key, value in output.items():
                output_file.write(f"{key}={str(value).lower() if isinstance(value, bool) else value}\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, UpdateError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
