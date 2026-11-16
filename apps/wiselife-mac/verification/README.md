# Mac App verification

<a id="github-sync-20261116"></a>

## 2026-11-16 · GitHub 源码提交验证

范围：Mac Companion 会议录制／回放、本地 ASR／MLX／说话人分析、依赖锁定、许可、技术文档及 React 产品原型。基于 `43d86d8` 上的未提交工作区检查；未纳入其他 iPhone／Ring／官网改动。验证环境为 Apple silicon、macOS 27.2.1、Xcode 27.2（27B52）。

- `WISELIFE_HF_DOWNLOAD_SMOKE=0 sh scripts/test.sh`：93 项，1 项显式联网下载测试跳过、0 失败；MeetingKit 38、说话人 17、CompanionCore 28、ASR 10。测试采用临时目录和合成媒体／下载器；TLS 测试仅绑定 loopback，不发布 LAN 服务，不下载模型权重。
- 下列 Xcode Debug 构建通过；`codesign --verify --deep --strict` 通过。使用本机 ad-hoc 签名，未公证、未制作正式发布安装包。
- `sh scripts/test_meeting_playback.sh /private/tmp/eurekalife-meeting-native-build/Build/Products/Debug/EurekaLife.app`：AVKit 链接检查与合成播放器检查通过（`PLAYBACK_VIEW_OK`）；没有使用用户录音，也不代表真实录制／声音回放验收。
- React 原型 `npm run build` 通过，生产预览全部 17 组 Chromium 回归通过，无浏览器错误、失败资源、外部请求或网络写入。[本次浏览器结果](../prototype/verification/components/results-publish-2026-11-16.json)独立保存，历史报告保留。
- CLI 与 Xcode 的 16 项 Swift 依赖 pin 一致；新增 App 源文件均纳入工程；plist、提交差异空白检查通过。提交清单排除录音、SQLite、模型权重、截图、凭据和生成目录。

```sh
xcodebuild -jobs 3 -project WiseLifeMac.xcodeproj -scheme WiseLifeCompanion \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/eurekalife-meeting-native-build \
  -clonedSourcePackagesDirPath /private/tmp/eurekalife-meeting-packages \
  -onlyUsePackageVersionsFromResolvedFile \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY=- build
```

构建保留上游 Cmlx 的 `missing creator for mutated node` 警告和已有 Swift 弱引用捕获警告，未导致失败。日志位于本机 `/private/tmp/eurekalife-mac-push-*-20261116.log`，不提交到 Git。本轮未安装 App、未重新验收真实设备／模型效果、未发布二进制。每日记录备份与按日 Ask AI 仍属 React 合成原型；原生能力与原有质量限制见[当前会议说明](../docs/meeting-recording.md)。


<a id="long-meeting-asr-20261113"></a>
## Long recording timestamp failure and compression — 2026-11-13

User's native MP4: 4530.73s, 1,000,944,932 bytes, H.264 1920×1268 at approximately 28.7fps, AAC stereo48kHz. Persisted analysis had failed before saving its first chunk with `转写结果时间戳无效，请重试。`.

Root cause reproduced with the actual first60s: Whisper Tiny returned intervals ending at60.3199997s and60.0400009s; another window ended at60.22s, and the30.73s final window yielded31.22s. The upstream segment seeker derives timestamps from tokens on padded30s model windows and does not clip them to input samples. Our0.02s tolerance incorrectly rejected ordinary boundary estimates, losing the entire otherwise valid chunk. MP4 decoding/model loading succeeded; file size was not the failure cause.

Fix: retain segments overlapping real input, clamp their end to the actual input duration and drop wholly padded intervals. Nonfinite/negative/reversed timestamps and values beyond the padded model window still fail. A new test using the observed boundary values failed before the fix; **10 ASR tests passed** after it. Native arm64 Debug Xcode build and strict ad-hoc signature check passed.

Actual-data verification uses an APFS copy-on-write clone in the isolated meeting acceptance directory, no cloud or model download. The full76 chunks completed, saving2631 original segments /18453 characters, with the last recognized segment ending at4530.30s. Original recording and existing metadata are protected by before/after SHA-256 checks; no capture permissions or recording APIs are exercised by this transcription check. This validates completion and bounded timestamps, not word accuracy. The subsequent LLM summary failed its bounded-output completion check (the guard rejects output-limit termination or empty text); its failure was separate from ASR. A follow-up experiment narrowed map summaries to3 facts/150 characters and final summaries to5 facts/350 characters, but the real local model still failed its bounded-output completion check. That prompt experiment was reverted; only clearer failure wording is retained, explicitly separating saved original text from failed summary. Summary generation for this long meeting remains unresolved; no truncated summary was saved. The unchanged completed transcript was restored to the original meeting only after checking original media/metadata/analysis hashes, keeping a backup of the prior failed analysis. A new locally signed Debug app was installed after confirming no active capture/analysis and gracefully quitting the old app, then opened on this meeting. Strict signature passed. The source MP4 and meeting.json hashes stayed unchanged.

Compression assessment: three30s slices (at120/2100/4200s) encoded locally with hardware HEVC,15fps, video target800kbps, hvc1 tag and AAC96kbps. Measured total rates0.889–0.926Mbps. A same-resolution, same-frame-rate middle-slice comparison gave SSIM0.9980; this is a sample metric, not exhaustive visual acceptance. Full independent preview:510,562,661 bytes,49.0% smaller;1920×1268 retained, video802kbps, audio96kbps. Video duration4530.867s vs4530.73s source (frame-boundary difference); audio4530.729s. Full compressed-video/audio decode completed with ffmpeg exit0 and an empty error log. Original MP4 is retained, and capture defaults remain H.264/30fps. HEVC's compatibility and lower frame rate are explicit tradeoffs.

Local evidence outside Git: `/private/tmp/eurekalife-long-asr-boundaries.log`, `eurekalife-long-asr-red.log`, `eurekalife-long-asr-green.log`, `eurekalife-long-asr-build.log`, `eurekalife-long-native-pipeline.log`, `eurekalife-long-video-compression.log`, `eurekalife-video-compression-ssim.log`. Media, snapshots and transcripts are not committed. No push or release.


<a id="meeting-intelligence-20261112"></a>
## Native style and local meeting intelligence — 2026-11-12

Working-tree build on Apple silicon, macOS 27.2.1 / Xcode 27.2; macOS 15 deployment target. Native scope follows the approved prototype: 220/56pt navigation, neutral shell, no middle-header left toggle, media below the date, transcript/summary tabs and full-height meeting Ask AI.

- `sh scripts/test_meetings.sh`: **12 tests, 0 failures**. Includes existing capture/media coverage plus durable partial analysis, interrupted-state recovery, unreadable-result overwrite protection, bounded audio windows, full-text summary chunking and extreme timestamp handling.
- `swift test --filter 'RuntimeTests|LocalMeetingRuntimeTests'` in the dependency-isolated runtime package: **7 tests, 0 failures**. Local work is admitted while LAN is suspended; remote cancellation does not cancel local inference. No LAN listener is created by these tests.
- `swift test --filter CompanionASRTests` in the isolated ASR package: **8 tests, 0 failures**, including pinned local tokenizer preflight, resume/timestamp bounds and catalog validation. No weight downloads.
- Actual Whisper Tiny inference on the repository's public JFK WAV fixture passed with OS network denial (`sandbox-exec`, `deny network*`). Existing verified iPhone simulator weights were copied into Mac ASRModels without changing the source or downloading weights.
- Full sandboxed native app processed a separate AAC copy of that fixture with local Whisper Tiny and installed Qwen3-1.7B-4bit. The saved analysis reached `ready`, with real English transcript, model IDs and Chinese summary. App-owned snapshots rendered original/summary and expanded/collapsed navigation. These are actual native views, not web prototype screenshots.
- Initial small-model output invented decisions/tasks to fill mandatory summary sections. Prompt changed to evidence-backed concise bullets and optional explicit decisions; the final short-speech summary includes the actual quote and timestamp without fabricated tasks. The prompt's worked example uses unrelated synthetic text. This is a fixture check, not a broad model-quality evaluation.
- Reopening the fixture detail left the entire saved analysis SHA-256 unchanged: no automatic ASR or summary rerun. Actual local Ask AI returned “未提及” when asked for concrete tasks absent from the fixture, and persisted the exchange. This validates the inference/persistence path, not general answer accuracy.
- Updated `~/Applications/EurekaLife-Meetings-Debug.app` after confirming no meeting was recording/finalizing and gracefully quitting the old app. The previous bundle is retained outside Git. Strict signature and installed-player smoke passed; opened the new app normally on the meeting page. User recordings were not changed.
- Review fixes preserve unreadable analysis files, permit retry after empty ASR, preserve newly typed Ask AI drafts, and join the existing stop task before exit so media finalization is awaited. Shutdown race fix is source-reviewed/compiled; forced quit during capture is not runtime-accepted.
- Full Debug arm64 Xcode build passed. Native sources emit no warnings; remaining warnings are upstream MLX build-graph metadata and AppIntents metadata skipped. AVKit playback-view regression and strict ad-hoc signature verification passed. This is not Developer ID signing, notarization or a release.

Reproduce app fixture processing with Debug flags: `--meeting-local-test --meeting <fixture-UUID> --process-meeting --snapshot <path-inside-container>`. Optional `--regenerate-summary`, `--summary-tab`, `--sidebar-collapsed`, `--hide-agent` and `--ask-meeting <question>` exercise the same coordinator/views. The local-test mode uses container tmp meeting data and prohibits LAN publishing; ordinary data, pairing and recording directories are preserved. Models must already be installed.

Local evidence (outside Git): `/private/tmp/eurekalife-meeting-intelligence-final-build.log`, `/private/tmp/eurekalife-meeting-analysis-final-tests.log`, `/private/tmp/eurekalife-runtime-green.log`, `/private/tmp/eurekalife-companion-asr-tests.log`, `/private/tmp/eurekalife-asr-real-offline.log`, `/private/tmp/eurekalife-meeting-local-e2e.log`, `/private/tmp/eurekalife-meeting-summary-final.log`. Snapshots and audio remain inside the test container. Temporary isolation avoids File Provider build locks; source/project/package changes were synchronized before the final build.

Limitations: computer control remains unavailable, so a fresh screen picker → recording → stop → analysis loop and audible microphone/system mix still need user interaction. Long multilingual recordings, every model size and local-model answer accuracy are not exhaustively accepted. Recording-time live transcript is not implemented; processing starts after saving. No commit, push or release.


<a id="meeting-capture-20261112"></a>
## Recording-finished playback crash — 2026-11-12 20:17

User reported an abort immediately after finishing a real screen recording. Crash report `EurekaLife-2026-11-12-201722.ips` shows SIGABRT in Swift metadata initialization through `_AVKit_SwiftUI` while constructing the player view. The meeting had already reached saved state.

Root cause was missing direct AVKit framework linkage: the delivered app depended on `_AVKit_SwiftUI`, but not AVKit. A minimal `NSHostingView(VideoPlayer(player: nil))` reproduced exit 134 and `failed to demangle superclass of VideoPlayerView from mangled name 'So12AVPlayerViewC': unknown error`. Linking the unchanged reproduction with `-framework AVKit` returned exit 0 and `PLAYBACK_VIEW_OK`.

Fix: explicitly link AVKit in the app Xcode target, generator and Swift package executable. The Xcode framework reference uses SDKROOT without hardcoding an SDK version. Added a Debug-only `--meeting <UUID>` route for exercising a saved detail page without capturing another recording.

Verification:

- New `scripts/test_meeting_playback.sh` rejected the previous delivered binary because AVKit was absent. It passed against the repaired build and installed app. Native tests mount/unmount the real SwiftUI player, and the optional local-media case waits for readyToPlay and confirms time advances with muted playback.
- The user's existing 16.833-second recording is a 1,344,945-byte MP4 with H.264 video (1918 × 1134) and AAC audio. Entire video/audio decoding passed via ffmpeg; AVPlayer playback advanced. This does not prove audible microphone/system-audio balance or all capture modes.
- Full native Debug build and strict ad-hoc signature check passed. The installed full app rendered the existing saved meeting detail and playback controls without the abort, verified by an app-owned local snapshot; screenshot stays outside Git. Snapshot auto-termination remained waiting in the existing terminateLater path, so that idle test process was stopped after rendering; this is not a normal-quit acceptance result.
- Updated `~/Applications/EurekaLife-Meetings-Debug.app` and reopened the saved meeting with `--meeting-test --meeting ...`. Old test binaries were moved to `/private/tmp` to avoid accidentally reopening the crashing workspace copy. Recording and metadata files were neither replaced nor deleted.
- Live computer control is still unavailable. A fresh user-driven record → stop interaction and audible playback should be reconfirmed; previously recorded media and detail construction are verified independently.

Local logs: `/private/tmp/eurekalife-videoplayer-repro.log`, `/private/tmp/eurekalife-playback-regression-before.log`, `/private/tmp/eurekalife-playback-regression-after.log`, `/private/tmp/eurekalife-meeting-playback-build-final.log`. No release or Git publication.

## Native meeting capture — 2026-11-12

Environment: arm64, macOS 27.2.1, Xcode 27.2 (27B52), macOS 27.2 SDK; deployment target macOS 15. No model weights downloaded, no LAN service started, no existing data reset.

- `sh scripts/test_meetings.sh`: **7 tests, 0 failures**, final run 18:14:44 UTC+8; no compiler warnings in the final isolated test log. Tests cover durable metadata, interrupted recovery preserving bytes, corrupt-metadata isolation, bounded even aspect-ratio dimensions, invalid media, invalid capture options, playable synthetic H.264 MP4 with extracted frame, and mixed synthetic system/microphone AAC audio without video. These are seven test methods, not seven real-device scenarios.
- Full Xcode Debug arm64 build: **BUILD SUCCEEDED**, final build 18:14 UTC+8. MeetingKit and both new SwiftUI files are compiled into the native app. Incremental build emitted an MLX package build-graph warning and an AppIntents metadata-skipped warning; no meeting-source warnings. The initial dependency build also emitted upstream MLX C++17-extension warnings.
- `codesign --verify --deep --strict` passed on the build and copied local test bundle; Info.plist and entitlements lint passed. This is **local ad-hoc signing**, not Developer ID, notarization or release.
- Stable test artifact: `~/Applications/EurekaLife-Meetings-Debug.app`, outside the iCloud workspace and Git, separate from the prior release artifact. Copied from the validated build using `ditto --norsrc`; strict signature check passed. An identical workspace `dist/EurekaLife-Meetings-Debug.app` was launched with `--meeting-test --page 会议`; process startup verified, GUI rendering not inspected. File Provider repeatedly reattached FinderInfo to the workspace copy after removal, invalidating its later signature checks, so use the Applications copy for subsequent launches. Do not use the workspace copy as a distributable.
- Computer control returned `Sky Computer Use native pipe startup failed` and `The browser access host is unavailable`, including on retry. **Native picker interaction, real screen/window capture, actual system/microphone sound and detail playback remain unverified.** The user was asked to record a nonsensitive test window for about ten seconds in the running test app.
- Existing CompanionCore code is unchanged and compiles in the full app. Its prior 23-test suite was not rerun in this pass; the results below are historical.

Build reproducibility: the repository is under File Provider. In-place SwiftPM/Xcode resolution blocked on dataless dependency files and NSFileCoordinator. Build used `/private/tmp/eurekalife-meeting-source`, copied from the current source without File Provider attributes, with `/private/tmp/eurekalife-meeting-packages` for resolved dependency source. Four unchanged dataless CompanionCore Swift files and six unchanged AppIcon PNG files were populated from their Git index blobs after verifying they had no workspace changes; all modified/new files used current workspace bytes. User source and data were not overwritten. The final capture/audio/UI changes were synchronized before the successful final build.

```sh
xcodebuild -jobs 6 \
  -project /private/tmp/eurekalife-meeting-source/WiseLifeMac.xcodeproj \
  -scheme WiseLifeCompanion -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/eurekalife-meeting-native-build \
  -clonedSourcePackagesDirPath /private/tmp/eurekalife-meeting-packages \
  -onlyUsePackageVersionsFromResolvedFile \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY=- build
```

Local logs (not committed): `/private/tmp/eurekalife-meeting-build-final.log`, `/private/tmp/eurekalife-meeting-isolated-final.log`. Actual recordings remain outside Git. See [current behavior and manual acceptance](../docs/meeting-recording.md).

## Historical desktop verification — 2026-10-24

## 0.2.0: light-gray iPhone styling and model recommendations

- Reused the iPhone light NotesStyle / DaybookStyle tokens: gray `#f5f5f7`, white grouped cards, blue-gray `#335f83` primary actions, 18pt card radius.
- Read actual Apple M4 / 16 GB hardware. Conservative catalog policy selects 1.7B for 8–12 GB and 4B for 16 GB+, excludes unknown models and unsupported configurations. This is a heuristic, not measured model RAM consumption or M3 acceptance.
- Model card's download button now starts Hugging Face download directly. Source, license, download size and memory guidance are visible in the card; fixed revision is in expandable details.
- Added byte counts, rate, explicit verification stage, cancellation/retry and an installed-only completion notice. Background progress reports are throttled, and stale progress is ignored.
- `WISELIFE_HF_DOWNLOAD_SMOKE=1 sh scripts/test.sh`: **23 tests, 0 failures**, including actual HTTPS model-card + 11 MB LFS tokenizer download from Hugging Face/CDN, verified against pinned SHA-256. No language-model weights were downloaded by this test.
- Actual sandboxed 0.2.0 App: clicked the 1.7B model’s download button once; the inline progress changed from connecting to real Hugging Face bytes (72 KB observed). Cancel returned immediately to a cancellation notice and a retry button. No complete language-model weights were downloaded or loaded. The staging directory was cleaned.
- Preview QA: `overview-gray.png`, `models-gray.png`, and `model-downloading.png`. The downloading screenshot uses an isolated debug fixture; it is not evidence of a real weight download. No injected fixture state is enabled in Release.
- Packaging now stages a clean signed bundle and replaces the previous App instead of merging Debug and Release contents; this fixes leftover debug-dylib resource-seal failures.
- Pairing Keychain access is now lazy and runs off the main actor. With service paused, starting the app and downloading a model do not require pairing-credential authorization. Device status distinguishes unread credentials from an empty registry.
- Final startup was rechecked after the lazy-Keychain change: the Release window opened immediately, reported actual M4 / 16 GB hardware, and navigated to the recommended model library without requiring pairing authorization. Offline regression: 23 executed, 1 opt-in network check skipped, 0 failures; the actual Hub/CDN check had passed separately above.
- Final 0.2.0 arm64 Release build and zip completed; bundle version and strict deep ad-hoc signature verification passed. Release entitlements retain only App Sandbox plus client/server network permissions.

## Original 0.1.0 verification — 2026-10-23

Environment: MacBook Pro / Apple M4 / 16 GB, macOS 15.7.4 (24G517), Xcode 26.3 (17C529), Swift 6.2.4. This is **not** the design's named M3 Air acceptance machine.

## Automated verification

`sh scripts/test.sh` runs deterministic, weight-free XCTest cases. Inference uses a cancellable stub; transport tests use a real NIO/NIOSSL listener on loopback, URLSession certificate pinning, generated in-memory identities and an isolated credential store. No user's iPhone, Keychain, notes or model weights are used.

Result: **19 tests passed, 0 failures**. `sh scripts/build.sh` completed an arm64 Release App and zip, with model catalog and MLX `default.metallib` verified inside the bundle. `codesign --verify --deep --strict` passed with the local ad-hoc signature. This does not mean Developer ID / notarization passed.

Final Release entitlements contain only App Sandbox and network client/server permissions; automatic `get-task-allow` debug access injection is disabled. The development host's missing Metal Toolchain was installed through Xcode's official component downloader before the successful build.

`sh scripts/benchmark.sh --check-metal` compiled the Xcode command-line target and successfully evaluated **1 + 2 + 3 = 6** with MLX Metal on this M4. This verifies the GPU integration without downloading or loading language-model weights.

Coverage:

- Strict text-only request schema, system/user messages, unknown settings, stream rejection, output clamp and 1 MiB bound.
- Immutable catalog revisions, SHA-256 hashes, local file tampering, successful atomic install, failed install cleanup and revalidation before load.
- Expiring single-use QR secret, rate limit, replay, wrong bearer, credential rotation, restart persistence, verifier storage and revocation.
- Stable self-signed certificate identity and certificate DER fingerprint.
- Single active inference, bounded FIFO, queue-full, caller cancellation, timeout, revoked-client admission, idle unload and shutdown drain.
- Pause during pairing cancels generation while retaining the pairing flow.
- Real HTTPS pair → models → completion → revoke; paused/model-not-ready responses, wrong TLS pin, cleartext rejection and oversized request.
- Rejection of wildcard/public listener addresses.
- Concurrent service stops and subsequent listener restart.

Plist/entitlements were linted with `plutil`; shell scripts were checked with `sh -n`; maintainer Python scripts compile. App sources contain no request/response logger or cloud inference endpoint.

The actual sandboxed Release App was launched and inspected through accessibility: first launch reached paused service / unloaded model state without an error; model-library navigation and the download disclosure showed the pinned revision, license and size. Cancelling returned to the not-downloaded state. The App then quit normally. This launch created the app's own local Keychain identity and empty device registry; no pairing or network availability was enabled.

## Visual verification

Debug-only isolated preview renders the actual SwiftUI window, not an HTML mockup. Preview creates no identity, network listener or downloads. PNGs:

- `overview.png`: empty model / first device / paused state.
- `models.png`: pinned 4B and 1.7B model cards, storage, load/download controls and engineering qualification.
- `devices.png`: first pairing instructions, availability and connection help.
- `privacy.png`: text data flow, credential handling and release limitations.

## Required release acceptance still outstanding

1. On the exact M3 Air / 16 GB, explicitly download both pinned candidates and run the synthetic Chinese benchmark and 30-minute soak **one at a time**. Inspect generated summaries/titles/citations/JSON/content decisions; establish numerical latency/memory gates from observations. No real model quality, speed, sustained memory pressure or thermal passing result is claimed here.
2. Integrate iPhone Nearby Mac provider, discovery, QR parsing, certificate pinning, Keychain and shared authorized routing for all text tasks. Preserve source validation, citations, cancellation and stale-result guards. Existing desktop sync QR is a different protocol.
3. With real iPhone + M3 Air, verify Local Network denial, firewall, sleep/wake, Wi-Fi change, hotspots/client isolation, revocation and no cloud fallback. Loopback TLS tests do not prove LAN Bonjour behavior.
4. Audit bundled notices and model licenses at release; configure Developer ID signing and notarization. Local ad-hoc build is not a distributable notarized release.

See the app README for exact commands. Benchmark output is explicitly marked `UNREVIEWED`, includes model pins and system data, and cannot automatically qualify hardware.


<a id="meeting-speakers-20261113"></a>
## Mac会议说话人（2026-11-13）

状态：功能实现、原生编译、合成样本和真实长录音执行／恢复通过；真实样本的归属覆盖较低，不能宣称识别效果已达标。未发布。范围仅当前会议内的说话人标签，不是跨会议联系人身份或独立音轨分离。

- 38项MeetingKit、17项Speaker、10项ASR与10项runtime相关测试通过，共75项；无权重测试覆盖跨窗口ID一致性、同窗口排他、模糊／重叠归属、断点与结果保留、损坏文件和符号链接保护、全媒体／原文指纹、模型固定清单、取消／串行执行；LLM/ASR/Speaker使用同一推理入口，包含加载和卸载，不在测试中下载权重或发布服务。
- 完整arm64 Debug Xcode构建及`codesign --verify --deep --strict`通过。原有CompanionModel/LocalHTTPServer weak捕获警告和MLX/AppIntents构建提示仍存在，不宣称零警告。
- 明确准备19.2MB固定模型后，应用内本地验证合成Samantha/Daniel：0–20、25–45、300–320、325–345秒，原文行分别为1、2、1、2；单声线20秒为1个归属，重叠双声线20秒保持未确定。修改为测试名称后正常关闭、重新打开，UI仍显示该名称。合成样本不等于真实多人准确率。
- 实际推理发现两项边界：分散取短样本使同人内部余弦低于阈值，改为完整10秒和≥2秒尾段、至少2秒核心独立语音；阈值仍0.90，不靠放宽阈值通过。另一个是300–302秒解码31994而非32000个采样点，改为PTS固定窗口对齐，保留真实空隙。
- 75分钟录音在第6个窗口后通过正常应用退出取消，文件状态为interrupted、保留6个完整窗口；重新打开后从第6个索引继续，未清空检查点。Debug直接启动二进制在正常退出后可能只恢复菜单栏，需发送普通open事件打开窗口，才执行视图上的测试入口。
- 4530.73秒、1,000,944,932字节真实MP4完成16个窗口；2631段原文中211段获得自动标签，2420段未确定。输出5组候选标签不代表实际有5个人；没有人物真值。1040个发言区间中966个保持unknown。原文件、analysis.json和meeting.json与执行前SHA-256完全一致；续接前6个窗口的区间为最终结果的精确前缀。
- 首窗口诊断：两个局部分组均能提取3段有效10秒特征，但组内余弦分别为0.5633/0.4574/0.8012和0.6318/0.5502/0.6815，未过0.90一致性校验。有限样本无法判断是局部分组混人、非连续发言拼接还是模型／声学差异；不直接放宽阈值来提高数字。后续需要带人工说话人真值的短样本，分别校准特征一致性和跨窗口匹配。界面显示真实已标注／未确定段数；覆盖数量不等于准确率。
- 自动标签需听原文核对；没有人物真值，不报告识别准确率。当前小LLM的长会议总结可能因输出上限失败，此任务保留原有失败状态和原文，不伪造新总结。Ask选段检索与标签拼接有单元测试，未对真实长会议的模型回答质量作验收。
- 原生测试使用container内`tmp/EurekaLifeMeetingAcceptance`；原录音、analysis.json与meeting.json的SHA-256基线记录在本机`/private/tmp/eurekalife-speakers-source-hashes.json`，不写入Git。截图、原始音频、特征、模型和构建均留在仓库外。电脑控制连接启动失败，未完成鼠标交互验收；名称保存／重开通过同一原生方法的Debug入口验证。

执行日志（本机临时证据）：`/private/tmp/eurekalife-speakers-build.log`、`/private/tmp/eurekalife-speaker-evidence-green.log`、`/private/tmp/meeting-shared-runtime-integrated.log`、`/private/tmp/meeting-shared-asr-tests.log`、`/private/tmp/meeting-shared-speakers-tests.log`、`/private/tmp/eurekalife-speakers-two-voice-v2.log`、`/private/tmp/eurekalife-speakers-single.log`、`/private/tmp/eurekalife-speakers-overlap.log`、`/private/tmp/eurekalife-speakers-rename.log`。

最终读取修复回归：`/private/tmp/eurekalife-reader-all-green.log`（38+17+10），runtime10项沿用上述独立结果；全长完成／诊断日志：`/private/tmp/eurekalife-speakers-long-meeting-resumed.log`、`/private/tmp/eurekalife-speakers-real-first-window-diagnostic.log`。

最终meeting-v3原生回归：双声线4段仍为1/2/1/2，单声线1段、重叠0段归属，改名成功；原文控件显示数量。正常退出旧版后原位安装`~/Applications/EurekaLife-Meetings-Debug.app`，严格签名校验通过，仅把已校验的`speakers.json`写回原75分钟会议，打开新版后再次确认原媒体、原文与元数据哈希未变。旧App保留在`/private/tmp/eurekalife-before-speakers-v12ymdbs/EurekaLife-previous.app`。没有提交、推送或发布；当前质量限制如上。
