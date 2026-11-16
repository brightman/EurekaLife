# Native meeting style, transcript and local summary implementation plan

**Goal:** Apply the approved Mac prototype to the native shell and meeting detail, and produce durable meeting transcript and summary using local ASR and LLM.

**Architecture:** Keep recorded media and MeetingRecord compatible. MeetingKit owns a separate atomic analysis.json document, bounded audio reading and pipeline contracts. A Mac ASR module uses WhisperKit 0.18.0 and the iPhone's verified model catalog/installer pattern without uploading audio. Existing MLX runtime serves both local meeting inference and authorized iPhone requests; stopping LAN admission must not stop local work. Native SwiftUI reuses the prototype's visual tokens and placement, not synthetic transcript data.

**Tech Stack:** macOS 15+, SwiftUI/AppKit/AVKit/ScreenCaptureKit, WhisperKit/Core ML, existing MLX Swift, local Codable files.

## Constraints and accepted design

- Preserve all recordings, metadata, models, Keychain and the existing bundle ID. Do not reset or uninstall apps. Do not commit, push or release.
- Use the approved prototype: 220px expanded/56px icon navigation; logo plus X; no duplicate middle-header collapse icon; white content, neutral controls, consistent 14px body/24px headings/8px radius; media immediately under date/time; transcript/summary tabs below; whole-page collapsible meeting Ask AI sidebar.
- Original transcript has real timestamps and seeks playback. Do not invent speaker identification; diarization is outside this request.
- Store partial transcript, summary, model provenance and processing errors. Reopen reads persisted results. No automatic repeated summary; explicit retry/regenerate available. Heavy media/model work stays off the main actor.
- Default processing assumption: after recording completes, ASR then summary; optional user question about real-time text is pending. Missing models produce actionable waiting state, never synthetic results or silent cloud fallback.
- Model downloads are explicit UI actions; automated tests use existing weights or synthetic engines, never silently download weights or open a LAN service.
- Keep native app and browser prototype distinct. Tests, real model inference, UI acceptance and release must be reported separately.
- Work on the existing task worktree because this feature builds on the uncommitted recording implementation; isolate native build/cache in /private/tmp to avoid File Provider locks. Preserve unrelated work.

## Implementation tasks

- [x] 1. MeetingKit analysis document/store, bounded audio chunks and pure summary chunking; tests for persistence, interruption, old-media compatibility, time bounds and no result replacement on failure.
- [x] 2. Local ASR adapter/model management. Fixed Whisper catalog; explicit install/cancel; installed-only inference with download:false and local tokenizer. Sequential bounded 60-second audio input, incremental timestamps/progress and cancellation. CoreML model unloaded after processing. Keep source/model licenses.
- [x] 3. MLX local admission and meeting pipeline. Reuse verified loaded model, separate local usage from LAN availability, serialize GPU generation; chunk long transcripts for grounded summary. Persist state on success/failure/cancellation and recover stale processing state on startup. Existing recordings support manual processing.
- [x] 4. Native shell and detail. Apply visual tokens, collapsible icon rail, media placement, transcript/summary/retry controls and local Ask AI. Integrate ASR model cards in model library; no fake outputs or dead buttons.
- [x] 5. Regression and review. Run MeetingKit and relevant runtime tests, native playback smoke, full Xcode build and signature check. Validate installed local models with a known fixture if available; exercise app-owned detail snapshot and preserve user recordings. Review cancellation, bounds, no network inference and durability.
- [x] 6. Update stable docs, index and verification; update local test app after checking no recording is active. No release.

## Interfaces

`MeetingTranscriptSegment`: Codable/Sendable/Identifiable, id:String, start:Double, end:Double, text:String.
`MeetingAnalysis`: Codable/Sendable, state:MeetingAnalysisState, segments:[MeetingTranscriptSegment], summary:String?, asrModel:String?, llmModel:String?, failure:String?, updatedAt:Date, completedChunks:Int, mediaBytes:Int64.
`MeetingAnalysisStore` actor: init(root:URL), load(id:UUID,recoverInterrupted:Bool=false), save(_:for:UUID).
`MeetingASREngine` actor in CompanionASR: init(root:URL?=nil), installed(size:String) throws -> Bool, download(size:String,progress:@Sendable(Double)async->Void) async throws, transcribe(url:URL,size:String,language:String,startChunk:Int,onChunk:@Sendable(Int,[MeetingTranscriptSegment],Double)async throws->Void) async throws. No implicit downloads. `models` catalog exposes name and bytes.
`MeetingAudioReader`: inspect duration and bounded PCM samples from AVAssetReader, mixed 16kHz mono Float, max60 seconds per chunk.
`MeetingModel`: @Published analysis:[UUID:MeetingAnalysis], processingID:UUID?, analysisProgress:Double, detailTab:String, seekTime:Double?, chatDraft:String; methods processSelected(), regenerateSummary(), cancelProcessing(), ask(). Root owns wiring/contracts and final UI integration.

## Evidence ledger

Initial audit: native MLX Qwen3-1.7B weights are installed; native ASR is absent. iPhone already uses WhisperKit 0.18.0 with fixed catalog and local tokenizer. Existing runtime currently suspends all inference with the LAN switch, so local admission must be separated. Approved prototype is the design source; no further design approval required.


Completion evidence (2026-11-12): native Debug build and strict local signature passed; MeetingKit 12, runtime 7 and ASR 8 tests passed. Actual installed Whisper Tiny + Qwen3-1.7B processed a public audio fixture, persisted original/summary, and answered a local question; reopening preserved the result hash. Native original/summary and collapsed-rail snapshots inspected. Installed and opened the local test app. No publication. Screen-picker recording loop, long-recording model quality and hardware audio remain acceptance limits, detailed in [verification](../../../verification/README.md#meeting-intelligence-20261112).
