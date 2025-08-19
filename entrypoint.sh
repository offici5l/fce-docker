#!/bin/bash
set -euo pipefail

if [ -z "${URL:-}" ]; then
  echo "URL is not set"
  exit 1
fi

aria2c -x 7 -s 7 -k 1M --continue --max-tries=0 --out="exrom.zip" "$URL"
7z x exrom.zip -o./
rm -f exrom.zip

if [ -f "payload.bin" ]; then
  for img in boot init_boot vendor_boot; do
    python3 /tools/payload_dumper.py --out . --images "$img" payload.bin || echo "$img not found in payload.bin"
  done
fi

ROM_NAME=$(basename "$URL" .zip)
ROM_NAME=$(echo "$ROM_NAME" | sed 's/[^A-Za-z0-9._-]/_/g')

for img in boot init_boot vendor_boot; do
  if [ -f "${img}.img" ]; then
    7z a "${img}_img_${ROM_NAME}.zip" "${img}.img"
  fi
done

echo "done"
