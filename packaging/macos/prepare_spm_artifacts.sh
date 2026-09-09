#!/bin/bash
# Resolve SPM dependencies and sanitize the ffmpeg_kit binary XCFrameworks
# before building.
#
# Background: the published 8.1.2-min `*.xcframework.zip` archives contain
# `._*` AppleDouble entries (61 in libswscale alone). Whatever extracts them
# leaves real `._*` files inside the .framework bundles, and Xcode's CodeSign
# phase then fails with "code object is not signed at all / In subcomponent:
# .../._libswscale". Stripping only the extracted trees loses to re-extraction
# during `flutter build`, so this script also removes the entries from the
# cached archives themselves (ordering matters: sanitize AFTER every resolve,
# so a re-download is cleaned too).
#
# Usage: run from the repo root after `flutter pub get` (+ the darwin header
# patch), immediately before `flutter build`.
# Must run with the Xcode selected for the build (xcode-select) already active.
set -euo pipefail

SPM_CACHE="$HOME/Library/Caches/org.swift.swiftpm"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
# Everywhere a downloaded XCFramework archive may sit: the shared SPM cache
# and Xcode's per-project SourcePackages trees inside DerivedData.

cd macos
if ! xcodebuild -resolvePackageDependencies -project Runner.xcodeproj -scheme Runner; then
  echo "scheme-scoped resolve failed, retrying project-wide" >&2
  xcodebuild -resolvePackageDependencies -project Runner.xcodeproj
fi
cd ..

# 1. Remove sidecar entries from cached archives so any (re-)extraction
# during the build yields clean trees. Xcode re-extracts binary artifacts
# on every build, after this script runs, so cleaning extracted trees alone
# can never win — the archives are the reservoir. Archives are discovered
# rather than assumed at a fixed path, and the search covers every zip in
# the SPM cache: AppleDouble entries are never load-bearing, so dropping
# them from any cached archive is safe. Ordering matters: sanitize AFTER
# every resolve, so a re-download is cleaned too. (Cached copies are reused
# by existence, not re-verified against the manifest checksum, which is only
# checked at download time — sanitizing them cannot trip verification.)
CLEANED_ARCHIVES=0
FOUND_ARCHIVES=0
for ROOT in "$SPM_CACHE" "$DERIVED_DATA"; do
  [ -d "$ROOT" ] || continue
  while IFS= read -r -d '' zip; do
    FOUND_ARCHIVES=$((FOUND_ARCHIVES + 1))
    echo "found cached archive: $zip"
    before=$(unzip -l "$zip" 2>/dev/null | grep -c -E '/\._|__MACOSX' || true)
    [ "$before" -gt 0 ] || continue
    chmod u+w "$zip"
    zip -dq "$zip" '*/._*' '*/__MACOSX/*' '__MACOSX/*' >/dev/null
    after=$(unzip -l "$zip" 2>/dev/null | grep -c -E '/\._|__MACOSX' || true)
    echo "cleaned $((before - after)) sidecar entries from $zip"
    CLEANED_ARCHIVES=$((CLEANED_ARCHIVES + 1))
  done < <(find "$ROOT" -name '*.zip' -print0 2>/dev/null || true)
done
echo "found $FOUND_ARCHIVES cached archives, cleaned $CLEANED_ARCHIVES"
if [ "$FOUND_ARCHIVES" -eq 0 ]; then
  echo "::warning::no cached SPM archives found under $SPM_CACHE or $DERIVED_DATA after resolve; expected the 8 ffmpeg_kit XCFramework zips. Archive sanitizing was a no-op — if the build fails at CodeSign, the cache layout differs and this script must learn the new path."
fi

# 2. Strip sidecars from every location SPM/Xcode extracts binary artifacts
# to. Missing dirs are fine (fresh caches); already-clean trees are a no-op.
STRIPPED=0
for ROOT in "$SPM_CACHE" "$DERIVED_DATA"; do
  [ -d "$ROOT" ] || continue
  while IFS= read -r -d '' f; do
    rm -rf "$f"
    STRIPPED=$((STRIPPED + 1))
  done < <(find "$ROOT" \( -name '._*' -o -name '__MACOSX' \) -print0 2>/dev/null || true)
done
echo "stripped $STRIPPED extracted sidecar files"

# 3. Clear extended attributes on the extracted ffmpeg frameworks so the
# Xcode embed step cannot materialize new `._*` files when copying them
# into the .app bundle.
for ROOT in "$SPM_CACHE" "$DERIVED_DATA"; do
  [ -d "$ROOT" ] || continue
  while IFS= read -r -d '' fw; do
    xattr -cr "$fw" 2>/dev/null || true
  done < <(find "$ROOT" -type d \( -name 'ffmpegkit.framework' -o -name 'libav*.framework' -o -name 'libsw*.framework' \) -print0 2>/dev/null || true)
done

# 4. Fail fast with diagnostics instead of a cryptic CodeSign error later.
LEFTOVER_FILES=0
for ROOT in "$SPM_CACHE" "$DERIVED_DATA"; do
  [ -d "$ROOT" ] || continue
  n=$(find "$ROOT" \( -name '._*' -o -name '__MACOSX' \) 2>/dev/null | wc -l | tr -d ' ')
  if [ "$n" -gt 0 ]; then
    echo "leftover sidecars under $ROOT:" >&2
    find "$ROOT" \( -name '._*' -o -name '__MACOSX' \) 2>/dev/null | head -n 20 >&2
  fi
  LEFTOVER_FILES=$((LEFTOVER_FILES + n))
done
LEFTOVER_ARCHIVE_ENTRIES=0
for ROOT in "$SPM_CACHE" "$DERIVED_DATA"; do
  [ -d "$ROOT" ] || continue
  while IFS= read -r -d '' zip; do
    n=$(unzip -l "$zip" 2>/dev/null | grep -c -E '/\._|__MACOSX' || true)
    [ "$n" -gt 0 ] && echo "dirty archive: $zip ($n sidecar entries)" >&2
    LEFTOVER_ARCHIVE_ENTRIES=$((LEFTOVER_ARCHIVE_ENTRIES + n))
  done < <(find "$ROOT" -name '*.zip' -print0 2>/dev/null || true)
done
if [ "$LEFTOVER_FILES" -gt 0 ] || [ "$LEFTOVER_ARCHIVE_ENTRIES" -gt 0 ]; then
  echo "error: $LEFTOVER_FILES sidecar files and $LEFTOVER_ARCHIVE_ENTRIES archived sidecar entries remain" >&2
  exit 1
fi
echo "SPM artifacts clean"
