#!/bin/bash
# Build a Wispie AppImage from a Flutter Linux bundle.
# Usage: make_appimage.sh <bundle_dir> <output_appimage> [appimagetool]
#   bundle_dir: build/linux/x64/release/bundle (contains wispie, data/, lib/)
set -euo pipefail

BUNDLE_DIR="${1:?usage: $0 <bundle_dir> <output_appimage> [appimagetool]}"
OUTPUT="${2:?usage: $0 <bundle_dir> <output_appimage> [appimagetool]}"
APPIMAGETOOL="${3:-appimagetool}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

rm -rf AppDir
mkdir -p AppDir/usr/bin AppDir/usr/share/applications AppDir/usr/share/metainfo AppDir/usr/share/icons/hicolor

cp -r "$BUNDLE_DIR"/. AppDir/usr/bin/
cp "$SCRIPT_DIR/com.sillygru.wispie.desktop" AppDir/usr/share/applications/
cp "$SCRIPT_DIR/com.sillygru.wispie.metainfo.xml" AppDir/usr/share/metainfo/
cp -r "$SCRIPT_DIR/icons/hicolor/." AppDir/usr/share/icons/hicolor/
cp "$SCRIPT_DIR/AppRun" AppDir/AppRun
# The desktop file must be at the AppDir root too for appimagetool validation.
cp "$SCRIPT_DIR/com.sillygru.wispie.desktop" AppDir/
# appimagetool requires the Icon= target at the AppDir root plus .DirIcon;
# hicolor icons alone are not enough (fails with "defined in desktop file
# but not found" on recent continuous builds).
cp "$SCRIPT_DIR/icons/hicolor/256x256/apps/com.sillygru.wispie.png" AppDir/com.sillygru.wispie.png
cp AppDir/com.sillygru.wispie.png AppDir/.DirIcon
chmod +x AppDir/AppRun

ARCH=x86_64 "$APPIMAGETOOL" AppDir "$OUTPUT"
