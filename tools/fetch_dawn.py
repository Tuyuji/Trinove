#!/usr/bin/env python3

"Fetches the latest release of dawn from GitHub"

import os
import tarfile
import urllib.request
import json
from dataclasses import dataclass

REPO = "google/dawn"
VERSION = "v20260403.135149"
DAWNJSON_DIR = "src/dawn/dawn.json"
OUTPUT_DIR = "dawn"

output_path = ""
headers = {}

@dataclass
class DawnAsset:
    name: str
    commit: str
    platform: str
    build_type: str
    download_url: str

    def pure_platform_name(self) -> str:
        # Remove -latest suffix if present
        return self.platform.removesuffix("-latest")
    
    def name_no_ext(self) -> str:
        return self.name.removesuffix(".tar.gz")

def parse_assets(assets: list) -> list[DawnAsset]:
    result = []
    for asset in assets:
        name = asset.get("name", "")
        if not (name.startswith("Dawn-") and name.endswith(".tar.gz")):
            continue

        # Dawn-{HASH}-{PLATFORM...}-{Debug|Release}.tar.gz
        stem = name.removeprefix("Dawn-").removesuffix(".tar.gz")
        parts = stem.split("-")
        result.append(DawnAsset(
            name=name,
            commit=parts[0],
            platform="-".join(parts[1:-1]),
            build_type=parts[-1],
            download_url=asset.get("browser_download_url")
        ))
    return result

#Utility to just fetch a file and save it to disk, only fetechs if the file doesn't already exist
def fetch_optionally(url: str, dest_path: str):
    if os.path.exists(dest_path):
        return

    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as response:
        with open(dest_path, "wb") as f:
            f.write(response.read())

def fetch_release() -> dict:
    cache_path = os.path.join(output_path, f"release-{VERSION}.json")

    if os.path.exists(cache_path):
        print(f"Using cached release data ({VERSION}).")
        with open(cache_path) as f:
            return json.load(f)

    url = f"https://api.github.com/repos/{REPO}/releases/"
    url += "latest" if VERSION == "latest" else f"tags/{VERSION}"

    print(f"Fetching release information from {url}...")
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as response:
        release_data = json.load(response)

    with open(cache_path, "w") as f:
        json.dump(release_data, f, indent=2)

    return release_data


def fetch_dawn_json():
    dawn_json_path = os.path.join(output_path, "dawn.json")

    if os.path.exists(dawn_json_path):
        with open(dawn_json_path) as f:
            existing = json.load(f)
        if existing.get("_metadata", {}).get("version") == VERSION:
            print(f"dawn.json already up to date ({VERSION}), skipping.")
            return

    raw_url = f"https://raw.githubusercontent.com/{REPO}/{VERSION}/{DAWNJSON_DIR}"
    print(f"Fetching {raw_url}...")
    req = urllib.request.Request(raw_url, headers=headers)
    with urllib.request.urlopen(req) as response:
        dawn_data = json.load(response)

    dawn_data.setdefault("_metadata", {})["version"] = VERSION
    with open(dawn_json_path, "w") as f:
        json.dump(dawn_data, f, indent=2)
    print(f"Saved dawn.json to {dawn_json_path}")

def unpack_dawn_asset(asset: DawnAsset, lib_dir: str):
    platform_dir = os.path.join(lib_dir, asset.pure_platform_name())
    os.makedirs(platform_dir, exist_ok=True)

    # Extract the tarball
    # A map of platform to the expected library path in the tarball, the root folder isn't included in this path
    expected_lib_paths = {
        "ubuntu": "lib64/libwebgpu_dawn.a",
    }

    expected_lib_path = f"{asset.name_no_ext()}/{expected_lib_paths.get(asset.pure_platform_name())}"
    with tarfile.open(os.path.join(output_path, asset.name), "r:gz") as tar:
        member = tar.getmember(expected_lib_path)
        member.name = os.path.basename(member.name)  # Strip the path, we only want the file
        tar.extract(member, platform_dir)
    print(f"Extracted {expected_lib_path} to {platform_dir}")

def main():
    global output_path, headers
    import sys

    cwd = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    output_path = os.path.join(cwd, OUTPUT_DIR)
    os.makedirs(output_path, exist_ok=True)

    headers = {"Accept": "application/vnd.github.v3+json"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    release_data = fetch_release()
    fetch_dawn_json()

    assets = parse_assets(release_data.get("assets", []))
    if not assets:
        print("No assets found in the release.")
        return
    
    # For now we only support ubuntu release
    target = next((a for a in assets if a.platform == "ubuntu-latest" and a.build_type == "Release"), None)
    if not target:
        print("No suitable asset found for ubuntu Release.")
        return
    
    print(f"Fetching {target.name}...")
    fetch_optionally(target.download_url, os.path.join(output_path, target.name))

    # Create platform lib dirs
    lib_dir = os.path.join(output_path, "lib")
    os.makedirs(lib_dir, exist_ok=True)

    unpack_dawn_asset(target, lib_dir)


if __name__ == "__main__":
    main()