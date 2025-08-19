#!/bin/bash
set -e

if [ -z "$URL" ]; then
  echo "ERROR: URL not provided"
  exit 1
fi

ROM_PATH=/workspace/rom.zip
EXTRACT_PATH=/workspace/extracted
OUTPUT_PATH=/workspace/output

mkdir -p "$EXTRACT_PATH" "$OUTPUT_PATH"

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

if [[ "$URL" != *.zip ]]; then
  echo "Only .zip URLs are supported."
  exit 1
fi

echo "Downloading ROM from $URL"
aria2c -x16 -s16 -o "$ROM_PATH" "$URL"

echo "Extracting ROM"
7z x "$ROM_PATH" -o"$EXTRACT_PATH" >/dev/null

cd "$EXTRACT_PATH"

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

[ -f boot.img ] && zip -r "$OUTPUT_PATH/boot_img.zip" boot.img
[ -f init_boot.img ] && zip -r "$OUTPUT_PATH/init_boot_img.zip" init_boot.img
[ -f vendor_boot.img ] && zip -r "$OUTPUT_PATH/vendor_boot_img.zip" vendor_boot.img

echo "SUCCESS: Extraction completed"