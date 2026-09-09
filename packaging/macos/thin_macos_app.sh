#!/bin/bash
# Thin a universal macOS .app into a single-architecture .app.
# Usage: thin_macos_app.sh <input.app> <arm64|x86_64> <output.app>
# Re-signs ad-hoc afterwards (lipo invalidates signatures; these builds ship
# unsigned and are distributed as zips, so ad-hoc is enough for local launch
# via right-click > Open).
#
# IMPORTANT: file_picker hard-requires the user-selected.read* entitlement
# even with the sandbox off (SecTaskCopyValueForEntitlement check, otherwise
# getDirectoryPath throws ENTITLEMENT_NOT_FOUND). A plain
# `codesign --force --deep --sign -` does NOT preserve entitlements, so the
# entitlements are extracted from INPUT and re-applied to OUTPUT below.
set -euo pipefail

INPUT="${1:?usage: $0 <input.app> <arm64|x86_64> <output.app>}"
ARCH="${2:?usage: $0 <input.app> <arm64|x86_64> <output.app>}"
OUTPUT="${3:?usage: $0 <input.app> <arm64|x86_64> <output.app>}"

if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
  echo "arch must be arm64 or x86_64" >&2
  exit 1
fi

# Extract the entitlements embedded by the Xcode build BEFORE touching
# anything. `:-` writes the entitlements as XML plist to stdout (the `-`
# form prints a human-readable dump instead, which cannot be re-embedded).
ENT_PLIST="$(mktemp /tmp/wispie-entitlements.XXXXXX.plist)"
trap 'rm -f "$ENT_PLIST"' EXIT
codesign -d --entitlements :- "$INPUT" > "$ENT_PLIST" 2>/dev/null || true
if ! grep -q "user-selected" "$ENT_PLIST" 2>/dev/null; then
  echo "ERROR: no user-selected entitlement found in $INPUT" >&2
  echo "Refusing to thin: the output would throw ENTITLEMENT_NOT_FOUND." >&2
  exit 1
fi
echo "Preserving entitlements from $INPUT"

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
# lipo invalidated every signature, so re-sign inner code first, then the
# outer bundle WITH the preserved entitlements (no --deep on the second
# pass, so the inner signatures are kept and helpers don't inherit app
# entitlements).
codesign --force --deep --sign - "$OUTPUT"
codesign --force --sign - --entitlements "$ENT_PLIST" "$OUTPUT"
if ! codesign -d --entitlements :- "$OUTPUT" 2>/dev/null | grep -q "user-selected"; then
  echo "ERROR: user-selected entitlement missing after re-signing $OUTPUT" >&2
  exit 1
fi
echo "Ad-hoc re-signed $OUTPUT (entitlements preserved)"
