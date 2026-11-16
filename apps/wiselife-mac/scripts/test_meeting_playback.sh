#!/bin/sh
set -eu
COMPANION_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_PATH=${1:?Usage: test_meeting_playback.sh /path/to/EurekaLife.app [local-media.mp4]}
BINARY="$APP_PATH/Contents/MacOS/EurekaLife"
if [ -f "$APP_PATH/Contents/MacOS/EurekaLife.debug.dylib" ]; then
    BINARY="$APP_PATH/Contents/MacOS/EurekaLife.debug.dylib"
fi
PLAYBACK_TEST_ROOT=$(mktemp -d /private/tmp/eurekalife-playback-tests.XXXXXX)
trap 'rm -rf "$PLAYBACK_TEST_ROOT"' EXIT HUP INT TERM
# Check the delivered binary, not merely the source's import AVKit declaration.
otool -L "$BINARY" > "$PLAYBACK_TEST_ROOT/linkage.txt"
if ! /usr/bin/grep -q '/AVKit.framework/' "$PLAYBACK_TEST_ROOT/linkage.txt"; then
    echo 'FAIL: native app is missing the AVKit runtime dependency' >&2
    exit 1
fi
xcrun swiftc -parse-as-library -swift-version 5 -framework AVKit \
    "$COMPANION_ROOT/Tests/MeetingPlaybackSmoke.swift" -o "$PLAYBACK_TEST_ROOT/playback"
"$PLAYBACK_TEST_ROOT/playback"
if [ "$#" -gt 1 ]; then "$PLAYBACK_TEST_ROOT/playback" "$2"; fi
