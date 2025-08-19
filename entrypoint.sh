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

if [[ "$URL" != *.zip* ]]; then
  echo "Only .zip URLs are supported."
  exit 1
fi

cd /workspace

echo "Downloading ROM from $URL"
aria2c -x16 -s16 -o rom.zip "$URL"

echo "Extracting ROM"
mkdir -p extracted
7z x rom.zip -oextracted >/dev/null
cd extracted

if [ -f "payload.bin" ]; then
  echo "payload.bin found, extracting images..."
  for img in boot init_boot vendor_boot; do
    echo "Attempting to extract $img..."
    python3 /tools/payload_dumper.py --out . --images $img payload.bin || echo "$img not found, skipping..."
  done
else
  echo "payload.bin not found, using existing images..."
fi

mkdir -p ../output
[ -f boot.img ] && cp boot.img ../output/
[ -f init_boot.img ] && cp init_boot.img ../output/
[ -f vendor_boot.img ] && cp vendor_boot.img ../output/

echo "SUCCESS: Extraction completed"