#!/usr/bin/env python3
"""Fetch the Dawn WebGPU prebuilt library from GitHub releases if not present."""

import json
import os
import shutil
import sys
import tarfile
import tempfile
import urllib.request

REPO = "Tuyuji/dawn"
LIB_NAME = "libwebgpu_dawn.a"


def main():
    dest = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..")
    )
    lib_path = os.path.join(dest, LIB_NAME)

    if os.path.exists(lib_path):
        print(f"[dawn] {LIB_NAME} already present, skipping fetch.")
        return

    print(f"[dawn] {LIB_NAME} not found, fetching from {REPO} releases...")

    api_url = f"https://api.github.com/repos/{REPO}/releases/latest"
    req = urllib.request.Request(api_url, headers={"User-Agent": "trinove-build"})
    with urllib.request.urlopen(req) as resp:
        release = json.load(resp)

    tag = release.get("tag_name", "unknown")
    asset = next(
        (a for a in release["assets"] if a["name"].endswith("-linux.tar.gz")),
        None,
    )
    if asset is None:
        print(f"[dawn] error: no *-linux.tar.gz asset in release {tag}", file=sys.stderr)
        sys.exit(1)

    print(f"[dawn] downloading {asset['name']} ({asset['size'] // 1024 // 1024} MB) from release {tag}...")
    with tempfile.TemporaryDirectory() as tmpdir:
        archive_path = os.path.join(tmpdir, "dawn.tar.gz")
        urllib.request.urlretrieve(asset["browser_download_url"], archive_path)

        with tarfile.open(archive_path, "r:gz") as tar:
            tar.extractall(tmpdir)

        lib_src = next(
            (
                os.path.join(root, f)
                for root, _, files in os.walk(tmpdir)
                for f in files
                if f == LIB_NAME
            ),
            None,
        )
        if lib_src is None:
            print(f"[dawn] error: {LIB_NAME} not found inside archive", file=sys.stderr)
            sys.exit(1)

        shutil.copy2(lib_src, lib_path)

    print(f"[dawn] installed to {lib_path}")


if __name__ == "__main__":
    main()
