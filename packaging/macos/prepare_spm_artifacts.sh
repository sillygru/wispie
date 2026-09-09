#!/bin/bash
# Resolve SPM dependencies and strip AppleDouble sidecars from the extracted
# binary XCFrameworks before building.
#
# Background: the ffmpeg_kit SPM zips were archived with plain `ditto -c -k`,
# which stores resource forks/xattrs as `._*` AppleDouble files. SwiftPM's
# extractor leaves them as real files inside the .framework bundles, and
# Xcode's CodeSign phase then fails with "code object is not signed at all /
# In subcomponent: .../._libswscale".
#
# Usage: run from the repo root after `flutter pub get`, immediately before
# `flutter build` — with no cache deletion in between (purging DerivedData
# re-extracts the zips and brings the sidecars back).
# Must run with the Xcode selected for the build (xcode-select) already active.
set -euo pipefail

cd macos
if ! xcodebuild -resolvePackageDependencies -project Runner.xcodeproj -scheme Runner; then
  echo "scheme-scoped resolve failed, retrying project-wide" >&2
  xcodebuild -resolvePackageDependencies -project Runner.xcodeproj
fi
cd ..

# Strip sidecars from every location SPM/Xcode extracts binary artifacts to.
# Missing dirs are fine (fresh caches); already-clean trees are a no-op.
STRIPPED=0
for ROOT in "$HOME/Library/Caches/org.swift.swiftpm" "$HOME/Library/Developer/Xcode/DerivedData"; do
  [ -d "$ROOT" ] || continue
  while IFS= read -r -d '' f; do
    rm -rf "$f"
    STRIPPED=$((STRIPPED + 1))
  done < <(find "$ROOT" \( -name '._*' -o -name '__MACOSX' \) -print0 2>/dev/null || true)
done
echo "Stripped $STRIPPED AppleDouble sidecars"
