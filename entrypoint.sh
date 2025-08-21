#!/bin/bash
set -euo pipefail

mkdir -p /workspace/output

# Check for required tools
for tool in aria2c 7z python3; do
  if ! command -v "$tool" &> /dev/null; then
    echo "ERROR: Required tool '$tool' is not installed." >&2
    exit 1
  fi
done

# --- Input Validation ---
if [ -z "${1-}" ]; then
  echo "ERROR: ROM URL not provided." >&2
  echo "Usage: $0 <URL> <FILE_TO_EXTRACT>" >&2
  exit 1
fi

if [ -z "${2-}" ]; then
  echo "ERROR: File to extract not provided." >&2
  echo "Usage: $0 <URL> <FILE_TO_EXTRACT>" >&2
  exit 1
fi

URL="$1"
FILE_TO_EXTRACT="$2"

# --- URL Transformation ---
echo "--> Transforming URL..."
MIUI_DOMAINS=(
  "ultimateota.d.miui.com"
  "superota.d.miui.com"
  "bigota.d.miui.com"
  "cdnorg.d.miui.com"
  "bn.d.miui.com"
  "hugeota.d.miui.com"
  "cdn-ota.azureedge.net"
  "airtel.bigota.d.miui.com"
)
REPLACEMENT_DOMAIN="bkt-sgp-miui-ota-update-alisgp.oss-ap-southeast-1.aliyuncs.com"

for domain in "${MIUI_DOMAINS[@]}"; do
  if [[ "$URL" == *"$domain"* ]]; then
    URL="${URL/$domain/$REPLACEMENT_DOMAIN}"
    break
  fi
done

if [[ ! "$URL" =~ \.zip ]]; then
  echo "ERROR: Only .zip URLs are supported." >&2
  exit 1
fi

echo "--> Final download URL: $URL"


# --- Main Logic ---
cd /workspace
echo "--> Downloading ROM from $URL"
if ! aria2c -x16 -s16 -o rom.zip "$URL"; then
  echo "ERROR: Failed to download ROM." >&2
  exit 1
fi

echo "--> Extracting ROM..."
mkdir -p extracted
if ! 7z x rom.zip -oextracted >/dev/null; then
    echo "ERROR: Failed to extract ROM archive." >&2
    exit 1
fi
cd extracted

# --- Output Handling ---
mkdir -p ../output

# Check if the file already exists
if [ -f "$FILE_TO_EXTRACT.img" ]; then
    echo "--> Found '$FILE_TO_EXTRACT.img' directly in the archive."
    mv "$FILE_TO_EXTRACT.img" ../output/
    echo "SUCCESS: '$FILE_TO_EXTRACT.img' is available in the output directory."
# If not, check for payload.bin and extract from it
elif [ -f "payload.bin" ]; then
    echo "--> payload.bin found, attempting to extract '$FILE_TO_EXTRACT'..."
    python3 /tools/payload_dumper.py --out . --images "$FILE_TO_EXTRACT" payload.bin

    if [ -f "$FILE_TO_EXTRACT.img" ]; then
        echo "--> Successfully extracted '$FILE_TO_EXTRACT.img'."
        mv "$FILE_TO_EXTRACT.img" ../output/
        echo "SUCCESS: '$FILE_TO_EXTRACT.img' is available in the output directory."
    else
        echo "ERROR: Could not find or extract '$FILE_TO_EXTRACT' from payload.bin." >&2
        exit 1
    fi
else
    echo "ERROR: Neither '$FILE_TO_EXTRACT.img' nor 'payload.bin' were found in the ROM archive." >&2
    exit 1
fi

echo "--> Done."
exit 0