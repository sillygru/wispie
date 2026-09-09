#!/bin/bash
# Patch bare `#if TARGET_OS_OSX` uses in video_player_avfoundation's darwin
# sources so the macOS build takes the macOS branch.
#
# Upstream defect (present in 2.10.0-2.12.0 and flutter/packages@main):
# several headers test TARGET_OS_OSX with no prior import of anything that
# defines it. Under SwiftPM the macro is then undefined, `#if` evaluates to
# 0, and compilation takes the iOS branch (`@import Flutter`), failing with
# "Module 'Flutter' not found" (FVPViewProvider.h:9). Sibling plugins
# (sqflite, audio_service, just_audio) all import an Apple header first and
# are unaffected.
#
# Run from the repo root after `flutter pub get`, before building.
# Idempotent; version-globbed so lock bumps can't silently disable it.
# PUB_CACHE_ROOT overrides the pub-cache location (used for testing).
set -euo pipefail

python3 - <<'PYEOF'
import glob
import os
import re
import sys

pub_cache = os.environ.get(
    "PUB_CACHE_ROOT", os.path.join(os.environ["HOME"], ".pub-cache")
)
pattern = os.path.join(
    pub_cache,
    "hosted/pub.dev/video_player_avfoundation-*/darwin"
    "/video_player_avfoundation/Sources/video_player_avfoundation_objc",
)
bases = sorted(glob.glob(pattern))

files = []
for base in bases:
    files += glob.glob(
        os.path.join(base, "include/video_player_avfoundation_objc/*.h")
    )
    files += glob.glob(os.path.join(base, "*.m"))
if not files:
    sys.exit(
        "No video_player_avfoundation darwin sources found in %s" % pub_cache
    )

apple_import = re.compile(r'^\s*(#\s*import\s*<|#\s*include\s*<|@import\s)')
patched = 0
for f in sorted(files):
    with open(f) as fh:
        lines = fh.read().splitlines(keepends=True)
    if any("TargetConditionals" in line for line in lines):
        continue
    first_use = next(
        (i for i, line in enumerate(lines) if "TARGET_OS_OSX" in line), None
    )
    if first_use is None:
        continue
    if any(apple_import.match(line) for line in lines[:first_use]):
        continue
    with open(f, "w") as fh:
        fh.write("#import <TargetConditionals.h>\n" + "".join(lines))
    patched += 1
    print("patched " + f)
print("patched %d of %d files" % (patched, len(files)))
PYEOF
