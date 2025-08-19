#!/bin/bash
set -e

if [ -z "$URL" ]; then
  echo "ERROR: URL not provided"
  exit 1
fi

DOMAINS=(
  "ultimateota.d.miui.com"
  "superota.d.miui.com"
  "bigota.d.miui.com"
  "cdnorg.d.miui.com"
  "bn.d.miui.com"
  "hugeota.d.miui.com"
  "cdn-ota.azureedge.net"
  "airtel.bigota.d.miui.com"
)

for domain in "${DOMAINS[@]}"; do
  if [[ "$URL" == *"$domain"* ]]; then
    URL=${URL/$domain/bkt-sgp-miui-ota-update-alisgp.oss-ap-southeast-1.aliyuncs.com}
    break
  fi
done

if [[ "$URL" == *".zip"* ]]; then
  URL="${URL%%.zip}.zip"
else
  echo "ERROR: Only .zip URLs are supported"
  exit 1
fi

echo "Downloading ROM from $URL"
aria2c -x16 -s16 -o rom.zip "$URL"

echo "Extracting ROM"
7z x rom.zip -oextracted >/dev/null

cd extracted
if [ -f payload.bin ]; then
  /tools/payload-dumper-go payload.bin
fi

mkdir -p /workspace/output

for f in boot.img init_boot.img vendor_boot.img; do
  if [ -f "$f" ]; then
    zip -r "/workspace/output/${f%.img}.zip" "$f" >/dev/null
  fi
done

echo "SUCCESS: Extraction completed"