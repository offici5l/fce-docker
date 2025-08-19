#!/bin/bash
set -e

if [ -z "$URL" ]; then
  echo "ERROR: URL not provided"
  exit 1
fi

domains=(
"ultimateota.d.miui.com"
"superota.d.miui.com"
"bigota.d.miui.com"
"cdnorg.d.miui.com"
"bn.d.miui.com"
"hugeota.d.miui.com"
"cdn-ota.azureedge.net"
"airtel.bigota.d.miui.com"
)

for domain in "${domains[@]}"; do
  if [[ "$URL" == *"$domain"* ]]; then
    URL="${URL/$domain/bkt-sgp-miui-ota-update-alisgp.oss-ap-southeast-1.aliyuncs.com}"
    break
  fi
done

if [[ "$URL" == *".zip"* ]]; then
  URL="${URL%%.zip*}.zip"
else
  echo "Only .zip URLs are supported."
  exit 1
fi

echo "Downloading ROM from $URL"
aria2c -x16 -s16 -o rom.zip "$URL"

echo "Extracting ROM"
7z x rom.zip -oextracted >/dev/null

cd extracted

boot_img="false"
init_boot="false"
vendor_boot="false"

if [ -f "payload.bin" ]; then
  echo "payload.bin found, extracting images..."
  for img in boot init_boot vendor_boot; do
    echo "Attempting to extract $img..."
    python3 /tools/payload_dumper.py --out . --images $img payload.bin || echo "$img not found in payload.bin, skipping..."
  done
else
  echo "payload.bin not found, using existing images..."
fi

mkdir -p /workspace/output

[ -f boot.img ] && zip -r /workspace/output/boot_img.zip boot.img >/dev/null
[ -f init_boot.img ] && zip -r /workspace/output/init_boot_img.zip init_boot.img >/dev/null
[ -f vendor_boot.img ] && zip -r /workspace/output/vendor_boot_img.zip vendor_boot.img >/dev/null

echo "SUCCESS: Extraction completed"