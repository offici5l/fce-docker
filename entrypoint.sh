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

for DOMAIN in "${DOMAINS[@]}"; do
  if [[ "$URL" == *"$DOMAIN"* ]]; then
    URL="${URL/$DOMAIN/bkt-sgp-miui-ota-update-alisgp.oss-ap-southeast-1.aliyuncs.com}"
    break
  fi
done

if [[ "$URL" == *.zip* ]]; then
  URL="${URL%%.zip*}.zip"
fi

aria2c -x16 -s16 -d /workspace -o rom.zip "$URL"
7z x /workspace/rom.zip -oextracted >/dev/null

cd extracted
if [ -f payload.bin ]; then
  payload-dumper-go payload.bin
fi

mkdir -p /workspace/output

[ -f boot.img ] && zip -r /workspace/output/boot_img.zip boot.img >/dev/null
[ -f init_boot.img ] && zip -r /workspace/output/init_boot_img.zip init_boot.img >/dev/null
[ -f vendor_boot.img ] && zip -r /workspace/output/vendor_boot_img.zip vendor_boot.img >/dev/null

echo "SUCCESS: Extraction completed"