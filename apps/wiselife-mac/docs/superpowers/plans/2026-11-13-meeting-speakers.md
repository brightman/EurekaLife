# Meeting speaker separation implementation plan

> **For agentic workers:** Use subagent-driven-development for isolated model and pure-policy tasks; root owns native integration and final verification. User confirmed the design on2026-11-13. Continue without another approval gate.

**Goal:** Local within-meeting speaker labels and rename, resumable bounded long-file analysis, preserving existing ASR and media.

**Architecture:** MeetingKit owns durable speaker documents and deterministic reconciliation. A new CompanionSpeakers target owns pinned model install and bounded SpeakerKit/WeSpeaker inference. A native coordinator serializes with existing meeting processing and supplies independent speaker UI/state. Speaker output lives in speakers.json with a resumable checkpoint and separate published snapshot.

**Tech Stack:** macOS15+, SwiftUI, CoreML, SpeakerKit0.18.0, existing AVFoundation reader and MLX.

## Global constraints

Preserve recordings, original transcript IDs/text/times, current dirty worktree and credentials. Work on existing codex/card-ring-integration-20261111 because all native meeting changes are uncommitted dependencies; build/cache remain under/private/tmp. Do not commit/push/release. Models download only on explicit action; actual inference validation may use an explicitly announced preparation download, never hidden automated-test downloads or LAN publishing. User-approved scope is docs/superpowers/specs/2026-11-13-meeting-speakers-design.md. No cross-meeting identities.

## Task1: Pure data, reconciliation, publication

Files: create Sources/MeetingKit/MeetingSpeakers.swift (split policy/store if useful), Tests/MeetingKitTests/MeetingSpeakerTests.swift. No other ownership.

Interfaces (public Codable/Sendable unless noted):
- MeetingSpeakerTurn(start:Double,end:Double,speakerID:String).
- MeetingSpeakerCheckpoint(fingerprint:String): completedWindows:Int=0, turns:[MeetingSpeakerTurn], features:[String:[Float]], nextSpeaker:Int=1. `append(window:Int,turns:[MeetingSpeakerTurn],features:[String:[Float]]) throws` maps local IDs to stable global IDs and updates checkpoint once, with same-window injective matching; minimum cosine0.90, margin0.10, version supplied by fingerprint.
- MeetingSpeakerSnapshot(checkpoint:MeetingSpeakerCheckpoint,segments:[MeetingTranscriptSegment],previousNames:[String]=[]): revision:UUID, fingerprint:String, assignments:[String:String], names:[String:String], previousNames:[String], turns:[MeetingSpeakerTurn], completedAt:Date. Unknown segments absent from assignments; ≥60% coverage, dominant share≥80%, reject actual cross-speaker overlap and near ties. Whole original rows retained. `displayName(_ id:String)->String`.
- MeetingSpeakerState: idle,running,ready,interrupted,failed,waitingForModel.
- MeetingSpeakerDocument(): state, failure:String?, result:MeetingSpeakerSnapshot?, checkpoint:MeetingSpeakerCheckpoint?. Prior result survives checkpoint/cancel/failure.
- MeetingSpeakerStore actor init(root:URL), load(id:UUID,recoverInterrupted:Bool=false)throws->MeetingSpeakerDocument?, save(_:for:UUID)throws, fingerprint(url:URL,segments:[MeetingTranscriptSegment],modelVersion:String) throws->String. Full file hash streamed/cancellable, transcript encoded canonically; corrupt documents protected against overwrite. All save paths inside meeting UUID directory.

- [x] Write failing tests for window-local ID permutation, no same-window global-ID collision, ties/overlap/uncovered rows unknown, first-appearance order, checkpoint exactly-once/resume, old result preservation, corrupt-file overwrite prevention, fingerprint mutation and stale annotation rejection.
- [x] Implement minimal pure policy/store; run `sh scripts/test_meetings.sh` green. No model downloads.
- [x] Review specification and tests; report exact signatures and limitations.

## Task2: Installed-only model engine

Files: create Sources/CompanionSpeakers/* and Tests/CompanionSpeakersTests/*. Root owns Package.swift/Xcode integration.

Interfaces:
```swift
public struct SpeakerLocalTurn: Sendable { public let start:Double; public let end:Double; public let speakerID:String }
public struct SpeakerWindowOutput: Sendable { public let index:Int; public let coreStart:Double; public let coreEnd:Double; public let turns:[SpeakerLocalTurn]; public let features:[String:[Float]] }
public actor MeetingSpeakerEngine {
 public static let modelBytes:Int64 //19,197,050
 public static let modelVersion:String
 public init(root:URL?=nil)
 public func installed() throws -> Bool
 public func download(progress:@escaping @Sendable(Double)async->Void) async throws
 public func analyze(url:URL,startWindow:Int,onWindow:@escaping @Sendable(SpeakerWindowOutput,Double)async throws->Void) async throws
}
```

- [x] Reuse pinned iPhone SpeakerModels/VoiceIdentityModels catalogs and license texts; adapt verified installer semantics with isolated staging, hashes, cancellation, previous installation preservation. Keep tests synthetic/local.
- [x] Engine uses local SpeakerKit with `download:false` and WeSpeaker extraction (fixed3×160000 input, 256-d output), clean nonoverlapping solo speech only. Core300s plus2s context each side, decoded by ≤60s reader calls, ≤304s materialized. Clip turns to core, absolute timeline; extract features from input-context solo ranges. Do not label insufficient features; no full-hour array.
- [x] Reuse one loaded model per analysis with strict serialized install/inference permit, unload on success/failure/cancel. Window callback persists progress, then discard samples.
- [x] Test windows, clipping/overlap, feature quality/normalization, cancellation/permit, installer paths/hashes/no silent network. Compile against local dependency cache. Report actual model validation separately.

## Task3: Native integration

Files: MeetingSpeakerModel.swift, MeetingSpeakerViews.swift, MeetingIntelligenceModel.swift, MeetingIntelligenceViews.swift, MeetingModel.swift, CompanionView.swift, WiseLifeCompanionApp.swift, Package.swift/project/generator.

- [x] Coordinator fingerprints off MainActor before analysis; loads published results only when source matches. Independently display speaker status/progress; per-window save checkpoint; publish atomically. Retry resumes checkpoint unless explicitly recomputing; rename only current published revision, old names review-only after recompute.
- [x] Existing meetings: explicit speaker action, no ASR or summary call. New recording pipeline: after ASR, await speaker engine if resources installed, then summarize even if speaker stage failed. Serialize local downloads/analysis/chat with busy guards and awaited shutdown; pending recordings drain when speaker-only task completes.
- [x] Show stable label + timestamp + original text, grouping only display rows. Add rename sheet and review indication, unknown label, start/stop/retry and model-library card (19.2MB) with explicit download/cancel. Existing summary remains saved; explicit new summarization/Ask uses labeled transcript only when fingerprint current.
- [x] Add DEBUG-only isolated speaker processing route for actual-data tests; no implicit model download or LAN. Add source membership incrementally, not replace project wholesale.

## Task4: Review, actual inference, delivery

- [x] Review pure-policy and engine tasks before integration closure; final read-only review of cancellation, concurrency, compatibility, model/network boundaries and source membership. Address material findings.
- [x] Run relevant unit suites, full arm64 Xcode build and strict signature. Keep no-weight tests independent from manual model preparation.
- [x] Announce19.2MB model preparation, use fixed catalog. Actual known two-speaker fixture and single speaker, overlap uncertainty; no invented accuracy if no human truth. Full75min isolated clone: no ASR rerun, preserved original hash; reopen and rename persistence.
- [x] Update current meeting doc, README, index and verification with exact outcomes and unverified surfaces. Install/open local app only after checking no capture; preserve previous app and original data. No commit/push/release.


## Execution notes

Tasks1–3 implemented and reviewed on the existing dirty branch. No commit/release. Final review fixes cover current-source validation, long Ask evidence, rename shutdown, and shared model admission. Actual model validation corrected10-second feature sampling without lowering thresholds. A75-minute regression exposed fractional AAC decoding shortfall; the reader now aligns fixed windows byPTS, and policy version ismeeting-v3. Current results and remaining acceptance boundaries are maintained in[verification](../../../verification/README.md#meeting-speakers-20261113).

Delivery: installed locally, complete75-minute execution and6-window stop/resume verified; only211/2631 transcript rows pass current labeling policy. This is a documented quality limit, not calibrated speaker accuracy. Preserve thresholds pending labeled evidence. No commit/push/release.
