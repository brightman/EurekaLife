#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
output=$(mktemp -d /private/tmp/wiselife-watch-retention.XXXXXX)
trap 'rm -rf "$output"' EXIT
swiftc -module-cache-path "$output/cache" Sources/Shared/CaptureMetadata.swift Sources/Shared/VoiceNote.swift Sources/Shared/RecordingSession.swift Sources/Shared/RecordingSessionFiles.swift Sources/Shared/RecordingAudioFile.swift Sources/Shared/RecordingDiagnostics.swift Sources/Shared/WatchSyncSnapshot.swift Sources/Watch/WatchConnectivityStatus.swift Sources/Watch/WatchRecordingRetentionStore.swift Tests/WatchRetentionSmoke.swift -o "$output/retention"
"$output/retention"
