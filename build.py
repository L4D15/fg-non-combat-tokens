#!/usr/bin/env python3
"""Packages ext/ into dist/NonCombatTokens.ext and installs it into Fantasy Grounds.

Usage:  python3 build.py [--no-install]
"""

import os
import shutil
import sys
import zipfile
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
EXT_SRC = os.path.join(HERE, "ext")
DIST = os.path.join(HERE, "dist")
EXT_NAME = "NonCombatTokens.ext"
FGDATA = os.path.expanduser(os.environ.get("FGDATA", "~/.smiteworks/fgdata"))


def pack(src, out):
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(src):
            for f in sorted(files):
                p = os.path.join(root, f)
                if f.endswith(".xml"):
                    try:
                        ET.parse(p)
                    except ET.ParseError as e:
                        sys.exit(f"Invalid XML in {os.path.relpath(p, HERE)}: {e}")
                z.write(p, os.path.relpath(p, src))
    return out


def main():
    os.makedirs(DIST, exist_ok=True)
    out = pack(EXT_SRC, os.path.join(DIST, EXT_NAME))
    print("Built:", os.path.relpath(out, HERE), f"({os.path.getsize(out) // 1024} KB)")

    if "--no-install" in sys.argv:
        return
    if not os.path.isdir(FGDATA):
        print(f"Fantasy Grounds not found at {FGDATA}; skipping install (set FGDATA=PATH).")
        return
    dest_dir = os.path.join(FGDATA, "extensions")
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, EXT_NAME)
    shutil.copy2(out, dest)
    print("Installed:", dest)


if __name__ == "__main__":
    main()
