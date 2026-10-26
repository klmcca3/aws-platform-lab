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

# Reproducible zip: fixed timestamps and sorted file order, so the same code always
# produces the same file. Otherwise every build looks "changed" to Terraform.
find build -exec touch -t 202001010000 {} +
(cd build && find . -type f | LC_ALL=C sort | zip -qX ../app.zip -@)
rm -rf build

echo "Built app/app.zip ($(du -h app.zip | cut -f1))"
