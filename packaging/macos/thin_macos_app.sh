#!/bin/bash
# Thin a universal macOS .app into a single-architecture .app.
# Usage: thin_macos_app.sh <input.app> <arm64|x86_64> <output.app>
# Re-signs ad-hoc afterwards (lipo invalidates signatures; these builds ship
# unsigned and are distributed as zips, so ad-hoc is enough for local launch
# via right-click > Open).
set -euo pipefail

INPUT="${1:?usage: $0 <input.app> <arm64|x86_64> <output.app>}"
ARCH="${2:?usage: $0 <input.app> <arm64|x86_64> <output.app>}"
OUTPUT="${3:?usage: $0 <input.app> <arm64|x86_64> <output.app>}"

if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
  echo "arch must be arm64 or x86_64" >&2
  exit 1
fi

rm -rf "$OUTPUT"
cp -R "$INPUT" "$OUTPUT"

thinned=0
while IFS= read -r -d '' f; do
  info="$(lipo -info "$f" 2>/dev/null || true)"
  if [[ "$info" == *"Architectures in the fat file"* ]]; then
    if [[ "$info" != *"$ARCH"* ]]; then
      echo "ERROR: $f does not contain $ARCH ($info)" >&2
      exit 1
    fi
    lipo -thin "$ARCH" "$f" -output "$f"
    thinned=$((thinned + 1))
  fi
done < <(find "$OUTPUT" -type f -print0)

echo "Thinned $thinned universal binaries to $ARCH"
codesign --force --deep --sign - "$OUTPUT"
echo "Ad-hoc re-signed $OUTPUT"
