#!/bin/sh
set -eu
COMPANION_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MEETING_TEST_ROOT=$(mktemp -d /private/tmp/eurekalife-meeting-tests.XXXXXX)
trap 'rm -rf "$MEETING_TEST_ROOT"' EXIT HUP INT TERM
mkdir -p "$MEETING_TEST_ROOT/Sources" "$MEETING_TEST_ROOT/Tests"
cp -R "$COMPANION_ROOT/Sources/MeetingKit" "$MEETING_TEST_ROOT/Sources/"
cp -R "$COMPANION_ROOT/Tests/MeetingKitTests" "$MEETING_TEST_ROOT/Tests/"
cat > "$MEETING_TEST_ROOT/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "MeetingCaptureTests", platforms: [.macOS(.v15)], targets: [.target(name: "MeetingKit"), .testTarget(name: "MeetingKitTests", dependencies: ["MeetingKit"])], swiftLanguageModes: [.v5])
PACKAGE
swift test --package-path "$MEETING_TEST_ROOT" --jobs 4
