#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
output=$(mktemp -d /private/tmp/wiselife-hourly-check.XXXXXX)
trap 'rm -rf "$output"' EXIT
host_target="$(uname -m)-apple-macosx14.0"
xcrun clang -target "$host_target" -std=c11 -O2 -Wall -Wextra -Werror \
  -c Sources/Watch/RecordingAtomics/RecordingAtomics.c -o "$output/RecordingAtomics.o"
swiftc -target "$host_target" -module-cache-path "$output/cache" \
  -I Sources/Watch/RecordingAtomics "$output/RecordingAtomics.o" \
  Sources/Shared/CaptureMetadata.swift Sources/Shared/VoiceNote.swift \
  Sources/Shared/RecordingSession.swift Sources/Shared/RecordingSessionFiles.swift \
  Sources/Shared/RecordingFramePartition.swift Sources/Shared/RecordingAudioFile.swift \
  Sources/Shared/RecordingDiagnostics.swift Sources/Watch/SegmentedAudioCapture.swift \
  Sources/iPhone/AudioProcessing.swift Sources/iPhone/AudioWindowPlanner.swift \
  Sources/iPhone/DaybookDatabase.swift \
  Sources/iPhone/NoteRepository.swift Sources/iPhone/AudioSpeakerMapping.swift \
  Sources/iPhone/AudioProcessingRepository.swift Sources/iPhone/TranscriptionConfiguration.swift \
  Sources/iPhone/AudioProcessingCoordinator.swift Sources/iPhone/AudioSourceDiscovery.swift \
  Sources/iPhone/ContentSegmentation.swift Sources/iPhone/ContentSegmentationV2.swift \
  Sources/iPhone/ContentSegmentRepository.swift Sources/iPhone/ContentEnrichmentService.swift \
  Sources/iPhone/RecordingSessionRepository.swift Tests/HourlyRecordingVerification.swift \
  -o "$output/hourly"
"$output/hourly"
