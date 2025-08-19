#!/bin/bash
set -e

if [ -z "$URL" ]; then
  echo "ERROR: URL not provided"
  exit 1
fi

echo "Downloading ROM from $URL"
aria2c -x16 -s16 -o rom.zip "$URL"

echo "Extracting ROM"
7z x rom.zip -oextracted >/dev/null

cd extracted
if [ -f payload.bin ]; then
  echo "Dumping payload.bin"
  payload-dumper-go payload.bin
fi

mkdir -p /workspace/output

[ -f boot.img ] && zip -r /workspace/output/boot_img.zip boot.img >/dev/null
[ -f init_boot.img ] && zip -r /workspace/output/init_boot_img.zip init_boot.img >/dev/null
[ -f vendor_boot.img ] && zip -r /workspace/output/vendor_boot_img.zip vendor_boot.img >/dev/null

echo "SUCCESS: Extraction completed"