#!/bin/bash
# Build SPM-consumable combined XCFrameworks (iOS device + iOS simulator + macOS)
# from the ffmpeg-kit release zips of a variant, zip them for use as SPM binary
# targets, and emit their checksums.
#
# Usage: build_spm_artifacts.sh <variant> <version>
#   e.g. build_spm_artifacts.sh full-gpl 8.1.2
#
# Inputs:  GitHub release assets ffmpeg-kit-{ios,macos}-<variant>-<version>.zip
#          under tag <version>-<variant>.
# Outputs: out/<lib>.xcframework.zip (one XCFramework at the zip root, as SPM
#          requires) and out/checksums.json, ready to upload to the same release.
#
# The iOS frameworks ship as fat Mach-O bundles (x86_64 sim + arm64/arm64e
# device). The device slice keeps arm64 only (arm64e is dropped, see #164).
# A native arm64 simulator slice is produced by retagging the device
# arm64 slice's LC_BUILD_VERSION platform from iOS (2) to iOS-Simulator (7) —
# FFmpeg is plain C with no platform-conditional linkage, so the retagged slice
# runs natively on Apple Silicon simulators (required by Xcode 26+).
set -euo pipefail

VARIANT="${1:?usage: build_spm_artifacts.sh <variant> <version>}"
VERSION="${2:?usage: build_spm_artifacts.sh <variant> <version>}"
TAG="${VERSION}-${VARIANT}"
BASE="https://github.com/sk3llo/ffmpeg_kit_flutter/releases/download/${TAG}"
FRAMEWORKS="ffmpegkit libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale"

WORK="spm-artifacts-${TAG}"
mkdir -p "$WORK"
cd "$WORK"

[ -f ios.zip ]   || curl -sSL "${BASE}/ffmpeg-kit-ios-${VARIANT}-${VERSION}.zip"   -o ios.zip
[ -f macos.zip ] || curl -sSL "${BASE}/ffmpeg-kit-macos-${VARIANT}-${VERSION}.zip" -o macos.zip
rm -rf ios macos out stage
mkdir -p ios macos out stage
unzip -q -o ios.zip -d ios
unzip -q -o macos.zip -d macos
# The upstream zips contain `._*` AppleDouble sidecar files. They must go:
# `ditto --norsrc` below only suppresses *new* sidecars from xattrs, it does
# not remove sidecar files already in the tree, and those end up inside the
# XCFrameworks where Xcode's CodeSign phase rejects them
# ("code object is not signed at all / In subcomponent: .../._<name>").
find ios macos \( -name '._*' -o -name '__MACOSX' \) -delete

# Strip bitcode everywhere (no-op if absent)
for FW in $FRAMEWORKS; do
  for BIN in "ios/${FW}.framework/${FW}" "macos/${FW}.framework/${FW}"; do
    [ -f "$BIN" ] && xcrun bitcode_strip -r "$BIN" -o "$BIN" || true
  done
done

convert() {
  local FW="$1"
  local IOS_DIR="ios/${FW}.framework"
  local IOS_BIN="${IOS_DIR}/${FW}"
  local MAC_DIR="macos/${FW}.framework"
  local STAGE="stage/${FW}"
  rm -rf "$STAGE"
  mkdir -p "$STAGE/device" "$STAGE/sim"

  local ARCHS MINOS SDK
  ARCHS=$(lipo -archs "$IOS_BIN")
  MINOS=$(otool -l -arch arm64 "$IOS_BIN" 2>/dev/null | awk '/LC_BUILD_VERSION/{b=1} b&&/minos/{print $2; exit}')
  SDK=$(otool -l -arch arm64 "$IOS_BIN" 2>/dev/null | awk '/LC_BUILD_VERSION/{b=1} b&&/sdk/{print $2; exit}')
  [ -n "$MINOS" ] || MINOS="14.0"
  [ -n "$SDK" ] || SDK="$MINOS"

  cp -R "$IOS_DIR" "$STAGE/device/${FW}.framework"
  cp -R "$IOS_DIR" "$STAGE/sim/${FW}.framework"

  # Device slice: arm64 ONLY. arm64e is deliberately dropped: App Store apps
  # run as arm64 (third-party arm64e needs a special entitlement), and App
  # Store validation rejects arm64e slices built with pre-iOS-26 SDKs (#164).
  lipo "$IOS_BIN" -thin arm64 -output "$STAGE/arm64.bin"
  lipo -create "$STAGE/arm64.bin" -output "$STAGE/device/${FW}.framework/${FW}"

  # Simulator slice: x86_64 + arm64 retagged iOS(2) -> iOS-Simulator(7)
  local SIM_ARGS=()
  if echo "$ARCHS" | tr ' ' '\n' | grep -qx "x86_64"; then
    lipo "$IOS_BIN" -thin x86_64 -output "$STAGE/x86_64.bin"
    SIM_ARGS+=("$STAGE/x86_64.bin")
  fi
  if echo "$ARCHS" | tr ' ' '\n' | grep -qx "arm64"; then
    lipo "$IOS_BIN" -thin arm64 -output "$STAGE/arm64-dev.bin"
    vtool -arch arm64 -set-build-version 7 "$MINOS" "$SDK" -replace \
      -output "$STAGE/arm64-sim.bin" "$STAGE/arm64-dev.bin"
    SIM_ARGS+=("$STAGE/arm64-sim.bin")
  fi
  lipo -create "${SIM_ARGS[@]}" -output "$STAGE/sim/${FW}.framework/${FW}"

  rm -rf "out/${FW}.xcframework"
  xcodebuild -create-xcframework \
    -framework "$STAGE/device/${FW}.framework" \
    -framework "$STAGE/sim/${FW}.framework" \
    -framework "$MAC_DIR" \
    -output "out/${FW}.xcframework" >/dev/null

  # ditto preserves the macOS slice's Versions/ symlinks inside the zip;
  # --norsrc keeps resource forks/xattrs out so no `._*` AppleDouble sidecars
  # ship inside the frameworks (Xcode's CodeSign phase fails on them with
  # "code object is not signed at all / In subcomponent: .../._<name>").
  # Belt and suspenders: drop any sidecars that survived into the staged
  # frameworks (e.g. carried over from the upstream zips, which --norsrc
  # alone does not remove).
  find "$STAGE" "out/${FW}.xcframework" \( -name '._*' -o -name '__MACOSX' \) -delete 2>/dev/null || true
  (cd out && ditto -c -k --keepParent --norsrc "${FW}.xcframework" "${FW}.xcframework.zip")
  rm -rf "$STAGE"
}

for FW in $FRAMEWORKS; do
  echo "== $FW"
  convert "$FW"
done
rm -rf stage

# Gate: no AppleDouble sidecars may ship, or downstream Xcode CodeSign
# phases fail. Fail here, not in someone else's CI.
DIRTY=0
for FW in $FRAMEWORKS; do
  N=$(unzip -l "out/${FW}.xcframework.zip" | grep -c -E '/\._|__MACOSX' || true)
  if [ "$N" -gt 0 ]; then
    echo "ERROR: out/${FW}.xcframework.zip contains $N sidecar entries" >&2
    DIRTY=1
  fi
done
[ "$DIRTY" -eq 0 ] || exit 1
echo "All zips free of AppleDouble sidecars"

CK="out/checksums.json"
echo "{" > "$CK"
FIRST=1
for FW in $FRAMEWORKS; do
  SUM=$(swift package compute-checksum "out/${FW}.xcframework.zip")
  [ $FIRST -eq 1 ] || echo "," >> "$CK"
  FIRST=0
  printf '  "%s": "%s"' "$FW" "$SUM" >> "$CK"
  echo "$FW  $SUM"
done
echo "" >> "$CK"
echo "}" >> "$CK"

echo
echo "Artifacts in ${WORK}/out — upload with:"
echo "  gh release upload ${TAG} ${WORK}/out/*.xcframework.zip ${WORK}/out/checksums.json"
