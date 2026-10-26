#!/usr/bin/env bash
# Builds app.zip with the app AND its Python dependencies included.
# Needed because the app servers have no internet access to download packages from PyPI.
# Targets Amazon Linux 2023 (Python 3.9, x86_64).
set -euo pipefail
cd "$(dirname "$0")"
 
rm -rf build app.zip
mkdir -p build/wheels
 
pip3 download \
  --requirement requirements.txt \
  --dest build/wheels \
  --only-binary=:all: \
  --platform manylinux2014_x86_64 \
  --python-version 3.9 \
  --implementation cp
 
cp app.py requirements.txt build/
 
# Reproducible zip: identical bytes on any machine (your Mac or GitHub's Linux runners).
# The macOS and Linux `zip` tools store file metadata differently, so Python writes the zip
# with fixed timestamps, fixed permissions, sorted order, and no compression. (The wheels
# are already compressed, so skipping compression barely changes the size.)
python3 - << 'PY'
import os, zipfile
files = sorted(
    os.path.relpath(os.path.join(root, name), "build")
    for root, _, names in os.walk("build") for name in names
)
with zipfile.ZipFile("app.zip", "w", zipfile.ZIP_STORED) as zf:
    for rel in files:
        info = zipfile.ZipInfo(rel.replace(os.sep, "/"), date_time=(2020, 1, 1, 0, 0, 0))
        info.external_attr = 0o644 << 16
        info.create_system = 3  # Unix
        with open(os.path.join("build", rel), "rb") as f:
            zf.writestr(info, f.read())
PY
rm -rf build
 
echo "Built app/app.zip ($(du -h app.zip | cut -f1))"
 
