# Eureka Ring 编译与录音文件兼容

类型：技术说明 · 状态：current · 更新：2026-11-06 · 适用：WiseLife iPhone／Watch，Ring 功能及当前本地合并工作区。

## 当前构建

`Config/BuildFeatures.json` 的 `eurekaRing` 已设为 `true`。Podfile 使用仓库内 `../../pods/br_flutter_plugin_ble` 的 Native 子模块，包含 BLE、适配层、Opus 及隐私／许可资源；不引用相邻 SDK 源码，不引入 Flutter 或 `br_app_services`。

集成测试从宿主展开的 SDK 额外链接 Opus 框架；不再创建第二个 Opus Pod 子目标，避免同一 XCFramework 的重复拷贝。生成 Pod 的最低 iOS 版本设为 15.0，兼容 Xcode 27；App 仍要求 iOS 26。

修改开关后执行 `pod install`，共享读取器同步更新依赖、`WISELIFE_EUREKA_RING` 和源码排除。关闭功能不删除已有录音；仅改 JSON 后直接 Build 不会更新现有工程。

开启 Xcode 用户脚本沙箱时，`post_integrate` 将 CocoaPods 资源复制脚本的临时文件清单及 `rsync` 暂存文件放到 `TEMP_DIR`。`DERIVED_FILE_DIR` 虽在该目录下，却被 Xcode 另行限制，不能用于未声明的临时输出。脚本输出权限只覆盖声明的精确路径；资源包目录本身不授权其内容。因此从 Pods 工程中读取 Ring 资源 target 的文件列表，加上生成的 `Info.plist`，逐个补入 `[CP] Copy Pods Resources` 的输出。重复运行保持幂等，保留 `ENABLE_USER_SCRIPT_SANDBOXING=YES`。

## 两种原音的处理契约

| 来源 | 原音文件 | 处理层接入 | 来源标记 |
| --- | --- | --- | --- |
| Apple Watch | 每小时一个独立 M4A，最后一份可不足一小时 | 按录音组、序号及真实偏移形成连续音源，保留缺失文件产生的缺口 | `captureDevice: watch` |
| EurekaRing | 一条设备录音对应一个完整文件，超过一小时也不拆原音 | BLE 校验后流式转为 16 kHz 单声道 AAC/M4A，进入现有本机录音库与统一处理队列；不套用 Watch 小时分片描述符 | `captureDevice: ring` |

AI 窗口最多 300 秒核心区间及两侧各 2 秒上下文，仅引用原音帧范围。全文、说话人和主题片段的时间戳相对整条录音，不在小时边界归零；内容主题分段沿用现有规则，与物理音频是否分片无关。Ring 单文件不会被遗留的小时组元数据合并成 Watch 分片。`VoiceNote.effectiveRecordingGroupID` 对显式或旧名称识别出的 Ring 返回空，列表、详情、播放分组、删除、恢复、转写与音源发现统一使用它；原始组字段继续保留供 Codable 往返，不需要改写已有数据库。删除 Watch 组不会连带删除 Ring。

Ring 任务按设备 ID、格式化代次与文件名确定身份，保留稳定笔记 UUID 和同步回执。实时结束事件和列表中的时间戳、大小、时长仅作为可补充元数据，不另建任务；重传不重复导入。保存成功后清理 SDK／转换暂存副本，不删除硬件原音。

Ring 闪念在本地转写；结构化整理和总结使用设置中选择的 AI 模型，不因 Ring 来源强制选择 Apple Intelligence。外部模型仍受当前发送确认／免提示设置约束，配置或原文改变会使旧确认失效；模型失败不自动切换供应商。

## 来源兼容与展示

新增可选 Codable 字段 `RecordingOrigin.captureDevice`，取值 `watch`／`ring`／`iPhone`／`unknown`，保留原设备名称、ID、文件名和时区字段。使用现有 JSON payload／SQLite 表，无新增 SQL 列或 schema 迁移。旧数据缺字段时从 `Watch`／`Apple Watch`、`Ring`／`EurekaRing` 名称识别，未知来源保持未知，不重写旧音频。

Watch 采集及手机 Watch 接收入口写入 watch，Ring 导入入口写入 ring，AI 音源快照保留字段。首页、完整录音和内容片段详情统一展示 Apple Watch／EurekaRing，原设备型号仍保存在元数据中。

## 2026-11-03 分支验证

环境：2026-11-03，`codex/vessel` 分支，基线 `7ed237f` 加本次工作区修改；Xcode 27.1（27A9275），iOS 26.3 的 WiseNote Ring Tests 模拟器。代码尚未提交。

| 检查 | 实际结果 |
| --- | --- |
| `pod install` | 成功，仅使用仓库内 Native Pod；Bluetooth／Native／Opus 3.0.0 |
| `ruby Tests/BuildFeaturesSmoke.rb` | 3 项、91 断言通过；开关可逆、测试 Opus 链接及 Watch 配置验证 |
| `python3 scripts/verify_ble_pod.py` | 79 项完整性检查、3 个 XCFramework 和真机／模拟器架构通过 |
| `sh scripts/test_audio_processing.sh` | 来源向后兼容、明确来源跨 AI 快照保留；7323.5 秒 Ring 单文件与 Watch 三个小时文件的窗口边界一致、跨小时语句只归属一次；队列回滚／重试／恢复通过 |
| `sh scripts/test_hourly_recording.sh` | 实际写入 3601 秒 AAC：Watch 两份文件、Ring 一份完整文件；持久化、重开、来源、有界处理及独立删除通过；遗留小时组元数据不改变 Ring 单文件归属 |
| `xcodebuild ... -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` | iPhone arm64、嵌入 Watch 与小组件编译通过；源码成员及 Watch 嵌入结构检查通过 |
| `xcodebuild ... -destination 'id=8AF9489C-FAD1-4AA2-A88A-E9591649A948' -only-testing:RingIntegrationTests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test` | 整个包 53 项、2 项资源 smoke 跳过、0 失败；其中 Ring 集成类 31 项全部通过，覆盖真实 Opus 转码、同步、断连、解绑、格式化、闪念、手机来源保存及处理队列路由 |

同时修复共用旧测试夹具与当前代码的接口差异：声音登记测试使用独立模拟 URL；持久化故障通过现有 SQLite 触发器注入；队列测试使用已有的三次自动重试预算。未修改对应生产策略。测试使用模拟硬件及合成音频，不向真实 Ring 发送命令。

**未验证：**真实 Ring 蓝牙配对、多小时 Opus 传输耗时、锁屏传输及硬件格式化；本地模型在真机的质量／内存／能耗；本次未做手机／手表签名安装或发布。

## 2026-11-06 合并到当前本地代码

来源：GitHub `origin/codex/vessel` 的 `f7616e456e3df8406bf80b6178972281c3413bc2`；目标：本地 `codex/pages-api-base`，合并前 HEAD `99b203cc1b84a3acb2b46873e2b1708488fd1493`。11 月 5 日开始隔离整合，11 月 6 日完成追加回归。

合并以本地安全快照保护原有工作区，先在隔离 worktree 结合 Ring 改动与当前联系人、播放、HealthKit、Watch 保留策略等代码验证。提交历史保留两条分支的祖先；原有未提交修改仍作为本地修改保留，不将整个工作区打包进合并提交。仓库级 README 保留 Notes／`NOTES_*`，补充远端 WiseLife 网站入口。

整合中修复：

- CocoaPods 资源脚本最初因 `resources-to-copy-WristNotes.txt` 写入沙箱外目录导致构建失败，改用派生构建目录后通过。
- Ring 转换任务弱引用捕获及 SDK 可扩展事件枚举的 Swift 警告；Whisper 测试在模拟器条件编译下跳过真机路径，消除不可达代码警告。
- 遗留 Ring 组字段原来只在处理层忽略，整组删除仍可能误删。新增测试先实际复现失败，再统一有效分组规则；显式 `.ring` 与旧 `EurekaRing` 名称均覆盖。

环境：Xcode 27.2（27B52）；独立 iOS 26.3 模拟器 `WiseLife Ring Merge Tests`，合成音频和模拟硬件。以下结果对应“合并后的当前工作区”，包含原有未提交改动，不是独立干净 checkout 的全量发布验收。

| 检查 | 实际结果 |
| --- | --- |
| `pod install` | 仓库内 Native Pod 安装成功，生成资源脚本兼容脚本沙箱 |
| `ruby Tests/BuildFeaturesSmoke.rb` | 4 项、92 断言通过，包含临时清单路径与幂等验证 |
| `python3 scripts/verify_ble_pod.py` | 79 校验、3 个 XCFramework、真机 arm64 与模拟器 arm64/x86_64 通过 |
| `ruby Tests/ProjectSourceMembershipSmoke.rb` | iPhone、Watch、共享源码和小组件成员检查通过 |
| `sh scripts/test_audio_processing.sh` | 来源兼容、窗口、队列、事务、重试与删除检查通过 |
| `sh scripts/test_hourly_recording.sh` | 实际 3601 秒 AAC 的 Watch 两文件、Ring 单文件持久化与处理通过；保留遗留组字段后删除 Watch session，Ring 原音仍存在 |
| `sh scripts/test_notebook_people.sh`、`test_playback_audio_session.sh`、`test_health_preparation.sh`、`test_watch_retention.sh` | 当前本地已有功能的专项回归通过 |
| `xcodebuild ... -destination 'platform=iOS Simulator,id=EE8B84E4-EB21-4F33-9280-AE058E50BA4C' -only-testing:RingIntegrationTests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test` | 54 项：52 通过、2 项 Whisper 真机推理跳过、0 失败；Ring 类 32 项通过，含整组删除后重开 SQLite 并核查 Ring 原音 |
| `xcodebuild ... -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` | iPhone arm64、内嵌 Watch 与小组件编译通过；0 warning、0 error（无签名编译，非真机安装） |

测试命令均从 `apps/wrist-notes` 执行，workspace 为 `WristNotes.xcworkspace`、scheme 为 `WristNotes`、configuration 为 `Debug`。临时详细记录：`/private/tmp/vessel-ring-merge-20261105/` 下的 `ring-group-red-retry.log`、`RingIntegrationVerified.xcresult`、`ring-tests-verified.log`、`device-build-verified.log`。本节同时保留结果摘要，临时日志清理不会使验证结论丢失。

限制：测试日志仍出现测试临时数据库 teardown 时的 SQLite 文件已移除诊断，不将模拟器测试通过等同于运行时诊断全部消除；旧全量 `test_local.sh` 的独立编译依赖和历史断言未纳入本次修复。真实 Ring 配对、长录音传输、锁屏行为与真机模型推理仍待硬件验收。本次未安装真机、上传 TestFlight 或推送 GitHub。

## 2026-11-06 Xcode 真机构建修复

环境：EurekaLife `main`，基线 `dd2904f` 加本次未提交修改；Xcode 27.2（27B52），`WristNotes.xcworkspace` / `WristNotes` / Debug，连接的 iPhone 16 Pro「Bright」。

用户在 Xcode 中的实际失败为 `Sandbox: bash ... deny(1) file-write-create .../DerivedSources/resources-to-copy-WristNotes.txt`。此前改用 `DERIVED_FILE_DIR` 的方案没有覆盖此次真机构建配置。修正临时清单后，构建继续暴露 `rsync ... mkstempat ... Operation not permitted`：资源包中的文件与随机暂存文件未获授权。给目录输出追加 `/` 不改变 Xcode 生成的精确路径权限；最终采用上文的逐文件输出声明和 `TEMP_DIR` 暂存方案。`Unexpected failure` 是 CocoaPods 错误处理脚本的后续报错，不是 Swift 编译失败。

| 检查 | 实际结果 |
| --- | --- |
| `pod install --no-repo-update` | 成功；资源清单、`rsync` 参数与工程输出声明均由集成流程生成，Podfile.lock 同步 |
| `ruby Tests/BuildFeaturesSmoke.rb` | 4 项、112 断言、0 失败；真实 `sandbox-exec` + `rsync` 验证文件复制、暂存清理、三种既有脚本路径迁移及幂等性 |
| 反向回归 | 去掉测试中的 `rsync --temp-dir` 修复后，实际复现 `mkstempat ... Operation not permitted`；恢复后通过 |
| `ruby Tests/ProjectSourceMembershipSmoke.rb` | iPhone、Watch、共享源码及小组件成员检查通过 |
| `python3 scripts/verify_ble_pod.py` | 79 校验、3 个 XCFramework、真机及模拟器架构通过 |
| Xcode 对 Bright 执行 Product → Build（⌘B） | 13:14 显示 `WristNotes Build Succeeded`；实际日志保留脚本沙箱与签名开启，产物为 1.0.3 (13) |
| `codesign --verify --deep --strict .../Debug-iphoneos/WiseLife.app` | 退出码 0，签名校验通过 |
| App 内隐私及许可资源 | 两个 bundle 共五个文件齐全；隐私 plist 内容与两个 Opus 许可文本均与 SDK 源文件一致 |

构建证据：Xcode DerivedData `WristNotes-azapspqqeeykmvbwogxwktehnpww` 中 `Logs/Build/C44AA5CD-3372-49C8-A049-72853ED66898.xcactivitylog`。本次只完成带签名的真机构建与产物检查，未安装／运行真机、未做 Ring 硬件验收、未发布；未清理设备数据。

## 2026-11-06 闪念重复导入与模型选择

### 真机取证与原因

从连接的 iPhone 16 Pro「Bright」只读取得 Ring 同步日志及 AI 配置，未读取 Keychain。同步日志中同一个闪念文件有两个不同任务 UUID，均为 `saved`；实时结束事件与设备列表的 `recordedAt` 相差 1 秒。原来的去重条件要求非空时间戳完全相等，因此重复建任务、补下载并导入两条笔记。配置确认当前选择 `custom / doubao-seed-2.0-mini / openai`，远程发送确认已关闭；但 `NotesModel.summaryConfiguration` 对 Ring 闪念返回默认本地配置，覆盖用户设置。

### 修复

- 以设备、格式化代次和文件名去重；列表只补全元数据。实时暂存、离线补同步及重启回执使用一致的身份。
- 闪念模型路由遵循设置。保留远程发送授权检查，未选择本地模型时不调用 Apple 总结。将 `usesLocalThoughtAI` 改名为只表达来源的 `isRingThought`，修正文案及中英日字符串。
- 不删除既有两条笔记、不重写历史结果、不改动真机配置或录音文件。修复防止之后再次产生此类重复；已存在的重复记录仍保留。

### 验证

基线 EurekaLife `main` / `dd2904f` 加当前未提交修复，包含此前构建脚本修复；Xcode 27.2。

- 新增回归先失败：1 秒差异实际产生两条笔记及一次额外 BLE 下载；重启后的完成回执无法去重；自定义模型被本地配置覆盖。修复后上述回归通过。
- `xcodebuild -workspace WristNotes.xcworkspace -scheme WristNotes -configuration Debug -destination 'platform=iOS Simulator,name=WiseLife Ring Merge Tests' -derivedDataPath /private/tmp/eurekalife-ring-bug-build-20261106 -only-testing:RingIntegrationTests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test`：57 项，55 通过、2 项 Whisper 真机模型测试跳过、0 失败。包含格式化代次隔离、独立文件、暂存重启恢复、同名闪念去重、远程确认以及显式本地选择。
- `sh scripts/test_flash_capture.sh`：原文依据、持久化去重、编辑冲突、撤销、记账和历史检查通过。
- `ruby Tests/ProjectSourceMembershipSmoke.rb`、`python3 scripts/verify_ble_pod.py`：成员检查及 SDK 79 项校验通过。
- `xcodebuild -workspace WristNotes.xcworkspace -scheme WristNotes -configuration Debug -destination 'platform=iOS,name=Bright' -derivedDataPath ~/Library/Developer/Xcode/DerivedData/WristNotes-azapspqqeeykmvbwogxwktehnpww build`：带签名真机构建通过；最终 `codesign --verify --deep --strict` 退出码 0。日志有 Metal 工具链 Swift 搜索路径缺失警告，未阻止链接／签名；未通过关闭沙箱或签名绕过。构建日志：`/private/tmp/eurekalife-ring-bug-device-build.log`。

测试结果包：`/private/tmp/eurekalife-ring-bug-build-20261106/Logs/Test/Test-WristNotes-2026.11.06_13-44-04-+0800.xcresult`。测试使用模拟硬件及合成音频，没有将用户录音送给第三方模型。本次未安装／启动修复版真机 App；真实 Ring 重新录制与第三方返回质量仍需修复版的真机回归。

## 2026-11-06 五小时录音边界与恢复

### 处理与修复

按硬件单文件最长 5 小时检查当前链路：每个文件仍是一条独立原始录音，不拆成 Watch 小时文件，也不凭相邻时间戳合并不同 Ring 文件。5 小时、16 kHz 对应 288,000,000 帧；元数据与读取偏移使用 Int64。AI 核心窗口最多 300 秒、两侧各最多 2 秒上下文，通常为 60 个核心窗口（AAC 尾部填充可能增加一个极短尾窗）。有界读取以最多 4096 帧缓冲顺序处理，全文及片段时间保持整条录音的绝对偏移；队列已有 SQLite 窗口检查点与恢复机制。

新增测试先复现两处错误：一份 3 秒原音配上只有开头 1 秒的可读旧转码缓存、且设备没有时长元数据时，会被错误保存为 1 秒；61 秒文件搭配 64 秒设备时长也能通过原来 5% 的宽松校验。5% 在 5 小时下会容忍 15 分钟缺尾。

- 转码改为每次尝试独立的 `conversion-UUID.m4a`；SDK 完成后重新读取实际音频格式／时长，通过校验并确认操作未中断，才原子重命名为 `recording.complete.m4a`。取消和失败清理该次临时输出，不污染后续连接的输出。
- 旧 `recording.m4a` 不再单独作为完成证明：有原始 `recording.opus` 则重新转码；无原音则重新传输。新完成缓存损坏时也优先复用原音重新转码。旧缓存不会在成功保存前主动删除；无法恢复时保留任务和错误，不假装成功。
- 设备提供有效时长时，误差固定最多 2 秒，用于设备时间取整与 AAC 填充，不再随录音长度扩大。新转换与缓存恢复都执行同一检查。正常完成的转换在入库失败后保留，重启重试无需再次下载或转码；保存回执继续防止重复导入。

### 验证与边界

环境：EurekaLife `main` / `dd2904f` 加当前工作区，Xcode 27.2，`WiseLife Ring Merge Tests` iOS 模拟器；真实 SDK 转码，BLE 采用模拟设备。全部音频为合成数据。

| 检查 | 结果 |
| --- | --- |
| 实际 5 小时 Opus | 用 1 秒 SDK 测试夹具流式重复生成 72,000,000 字节 Opus，经真实 SDK 转码、单条入库、SQLite 重开、音源发现与窗口规划；读取最末窗口并校验有声音及绝对结束时间 18,000 秒；再次同步无重复导入 |
| 恢复回归 | 未完成旧缓存（有／无原音）、转码取消后保留可读半成品、完成转换后入库失败重启、缺尾时长不符均通过；未完成旧缓存与缺尾时长校验两项新增回归已在修复前实际失败 |
| `xcodebuild ... -only-testing:RingIntegrationTests ... test` | 60 项：58 通过、2 项 Whisper 真机模型测试跳过、0 失败；5 小时用例约 34.5 秒完成，非蓝牙传输／真机转写速度 |
| `sh scripts/test_audio_processing.sh` | 有界窗口、缺口、跨窗口归属、SQLite 原子提交／重启、取消及删除回归通过 |
| `ruby Tests/ProjectSourceMembershipSmoke.rb`、`python3 scripts/verify_ble_pod.py` | 源码成员检查、SDK 79 项完整性与架构检查通过；未更换二进制 SDK 或增删 Pod |
| 对连接 iPhone 的签名构建及 `codesign --verify --deep --strict` | 构建成功、签名验证退出码 0；保留 Metal 工具链 Swift 搜索目录缺失的非阻断链接警告，未关闭沙箱／签名 |

结果包：`/private/tmp/eurekalife-ring-bug-build-20261106/Logs/Test/Test-WristNotes-2026.11.06_14-01-53-+0800.xcresult`。日志：`/private/tmp/eurekalife-ring-long-red.log`、`eurekalife-ring-long-green.log`、`eurekalife-ring-long-device-build.log`。

实际 Ring 的 5 小时 BLE 传输耗时、设备时长元数据精度、真机内存峰值／能耗、模型推理质量和锁屏行为尚未验收。二进制 SDK 的公开接口没有传输偏移／续传参数；App 只复用**已经完整下载**的原音，不能承诺蓝牙传到一半从原字节位置继续。iOS 后台执行受系统时限约束；长文件同步建议保持 App 前台。没有安装真机、修改用户录音、推送或发布。

## 2026-11-06 闪念日程漏识别

### 真机证据与修复

只读复制连接 iPhone 的 SQLite 数据库及 WAL 到仓库外，`quick_check` 为 `ok`。目标闪念已经转写完成，实际文字包含“给我创建个日程吧”和“明天上午 10:00”；人名另有识别错误。对应 `flash_batches` 为 `complete`，但没有关联的 `flash_assets` 或 `daybook_actions`，且录音来源未保存时区。这表示尚未进入系统日历执行阶段，不能归因为 EventKit 权限失败。数据库没有保留模型原始响应，不能据此断言该次模型输出了什么；下列代码缺陷已独立复现：

- 命令校验只匹配“创建日程”，不匹配“创建个日程／创建一个日程”。现在兼容这类口语量词及 ASR 空格，仍先检查否定、转述和条件句；同一句较短引用不能绕过原话上下文。
- Ring 原先未向 `RecordingOrigin` 写入时区。现在在 SDK 校时确认后记录设备时钟上下文，新录音任务携带可确定的时区，下载、保存失败与重启后仍保留。早于该次校时的离线录音、未知时间及手机时区已变化的未标记文件继续保留未知，不按接收时区回填；不修改既有笔记。
- 空提取也会标成完成，原界面无法再整理。现在空结果明确显示“未提取到想法、账目或行动”，提供手动“重新整理”；数据库允许真正空结果重新提交。已有结果（包括撤销和删除的行动）继续阻止重复执行，自动恢复不批量重跑完成批次。

本次没有变更缺少结束时间的规则：识别到创建指令但缺开始／结束时间，保留可见的“待补充”日程，不默默丢弃，也不自行设为一小时。用户选择默认时长前保留此行为。该条旧录音还需核对人名、时区和结束时间；没有直接替用户创建系统日程或改写真机数据。

### 验证

- 修复前分别复现口语指令被丢弃、空完成批次无法恢复、Ring 时区在保存／重启后为 nil；修复后通过。
- `sh scripts/test_flash_capture.sh`：口语与空格、否定／转述、缺结束时间保留草稿、空结果重试、非空结果去重、原文依据和历史策略通过。
- Ring 模拟器集成 61 项：59 通过、2 项 Whisper 真机模型测试跳过、0 失败；包括校时之后的录音时区跨保存失败与重启传递、旧离线录音不猜时区，以及此前 5 小时音频回归。
- 独立 Actions 模拟器集成 9 项通过，新增“口语 Ring 日程 → JSON 解析 → SQLite → 执行队列 → 一次系统保存”及重复重试检查。系统日历使用测试替身，不写入用户日历；没有向外部模型发送录音或转写。
- 源码成员与 SDK 79 项完整性检查通过。测试包：`/private/tmp/eurekalife-ring-bug-build-20261106/Logs/Test/Test-WristNotes-2026.11.06_14-40-08-+0800.xcresult`；独立 Actions 项目与结果在 `/private/tmp/eurekalife-calendar-actions-20261106/`。
- 对连接的 iPhone 签名构建通过，`codesign --verify --deep --strict` 退出码 0；日志仍有此前 Metal 工具链 Swift 搜索路径缺失的非阻断警告。日志 `/private/tmp/eurekalife-ring-calendar-device.log`。本次未安装修复版；真实 Ring 新录音、所选模型返回和 EventKit 权限／创建仍待真机验收。

## 2026-11-06 闪念处理状态显示

用户继续反馈同条闪念的“总结”显示“等待处理”。再次只读取得真机 SQLite／WAL，检查结果为：`transcriptionState=ready`、`summaryState=pending`、总结为空、无处理错误；对应 `flash_batches.state=complete`，没有关联的想法／账目／行动。这是空结果整理已完成，不是 AI 总结仍在后台排队。

原因：运行时开启 `handlesFlashOrganization` 后，闪念由 `FlashCaptureModel` 的独立批次整理，刻意不启动旧总结路径；但 `DaybookVoiceDetailView` 的处理状态弹窗仍统一读取 `VoiceNote.summaryState`，因而长期显示旧字段的 pending。

修正处理状态弹窗：闪念显示“闪念整理”，观察实际批次和当前处理集合；空完成批次明确显示未提取到内容，可回整理页重试。失败显示批次真实原因，等待发送确认与历史待处理各自说明；有结果时说明整理完成，行动执行状态仍在整理结果中展示。普通长录音继续显示原总结状态。本次只改显示，不伪造总结、不更新真机数据库、不重跑历史指令。

验证：源码成员检查、对连接 iPhone 的签名构建、`codesign --verify --deep --strict` 与 diff 检查通过。仍有此前 Metal 工具链搜索路径的非阻断警告；构建日志 `/private/tmp/eurekalife-flash-status-device.log`。尚未安装修复版，修复后的弹窗未做真机交互验收。

## 历史

2026-10-20 曾按用户要求关闭 Ring，当时缺少相邻源码适配层，开启状态未完成构建。2026-11-03 用户要求在当前分支恢复本仓库 Pod、开启编译及兼容两类录音。本节以前的默认关闭／外部源码恢复步骤不再适用于当前配置。历史设备记录见 [原生接入验证](../verification/eureka-ring-native.md)。
