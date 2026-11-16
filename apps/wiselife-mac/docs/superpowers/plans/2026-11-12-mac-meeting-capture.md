# Mac meeting capture implementation plan

Goal: implement the approved settings-first recording flow in the native Mac app, with real display/window capture, local persistence and detail playback.

Architecture: a dependency-light MeetingKit Swift package owns durable records, media inspection and ScreenCaptureKit capture; the existing SwiftUI app owns navigation and presentation. macOS 15+ system content picker supplies explicit capture scope. Recordings remain in the existing app container, in a new Meetings subdirectory. No model downloads, LAN startup, transcription or generated AI content is needed for capture.

## Constraints

- Preserve the existing bundle ID, signing configuration, app data and dirty worktree.
- Settings first; audio-only skips the screen picker. Screen mode invokes the native single-display/single-window picker. Cancel returns to settings without recording.
- Store metadata before capture; mark saved only after writer finalization and media inspection. Keep partial files and recover interrupted records without deletion.
- Stop on explicit user action, system interruption or application termination. Prevent duplicate starts/stops. Never show a static demonstration as live video.
- Tests use temporary stores and synthetic media. Actual recordings and screenshots stay outside Git. No publication or commits in this task.

## Tasks

- [x] Add MeetingKit and isolated tests for durable metadata, interruption recovery, invalid media and capture dimensions.
- [x] Implement system picker, screen/window MP4 capture, microphone permission, audio-only capture, finalization and actionable errors.
- [x] Add native meeting list, settings and detail playback; retain active recording across navigation and flush on app quit.
- [x] Synchronize Xcode membership, generator and permission declarations without replacing the project.
- [x] Run seven isolated synthetic tests and full native Xcode build; verify local ad-hoc signature and permission plists.
- [ ] Exercise the real picker with nonsensitive content, inspect the actual saved asset and detail playback. Blocked on computer-control connection; test app launched and manual user step requested.
- Existing CompanionCore regression suite not rerun; core source unchanged, full compilation passed. Historical test results remain distinct.

## Validation

`swift test --disable-automatic-resolution --jobs 6 --filter MeetingKitTests`; existing `scripts/test.sh`; Xcode app build using existing resolved dependencies. Browser prototype remains a design reference. Native smoke capture requires explicit selection in the system picker and must not silently select arbitrary user windows.

## Current evidence

See [verification](../../../verification/README.md#meeting-capture-20261112) for exact environment, File Provider staging workaround, test/build outcomes and live-capture boundary. No commit, push, release or user-data reset performed.
