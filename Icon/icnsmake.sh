#!/usr/bin/env bash
# icnsmake.sh — Convert a PNG to an .icns file
# Usage: icnsmake.sh [input.png]
# If no argument is given, defaults to AppIcon.png → AppIcon.icns

INPUT="${1:-AppIcon.png}"

if [[ ! -f "$INPUT" ]]; then
    echo "Error: file not found: $INPUT" >&2
    exit 1
fi

BASENAME="${INPUT%.*}"
ICONSET="${BASENAME}.iconset"
OUTPUT="${BASENAME}.icns"

mkdir "$ICONSET"

sips -z 16  16   "$INPUT" --out "$ICONSET/icon_16x16.png"
sips -z 32  32   "$INPUT" --out "$ICONSET/icon_16x16@2x.png"
sips -z 32  32   "$INPUT" --out "$ICONSET/icon_32x32.png"
sips -z 64  64   "$INPUT" --out "$ICONSET/icon_32x32@2x.png"
sips -z 128 128  "$INPUT" --out "$ICONSET/icon_128x128.png"
sips -z 256 256  "$INPUT" --out "$ICONSET/icon_128x128@2x.png"
sips -z 256 256  "$INPUT" --out "$ICONSET/icon_256x256.png"
sips -z 512 512  "$INPUT" --out "$ICONSET/icon_256x256@2x.png"
sips -z 512 512  "$INPUT" --out "$ICONSET/icon_512x512.png"
cp "$INPUT"            "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" --output "$OUTPUT"
rm -rf "$ICONSET"

echo "Created: $OUTPUT"
