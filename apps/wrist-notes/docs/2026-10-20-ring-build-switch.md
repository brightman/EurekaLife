# Eureka Ring 编译与录音文件兼容

类型：技术说明 · 状态：current · 更新：2026-11-06 · 适用：WiseLife iPhone／Watch，Ring 功能及当前本地合并工作区。

## 当前构建

`Config/BuildFeatures.json` 的 `eurekaRing` 已设为 `true`。Podfile 使用仓库内 `../../pods/br_flutter_plugin_ble` 的 Native 子模块，包含 BLE、适配层、Opus 及隐私／许可资源；不引用相邻 SDK 源码，不引入 Flutter 或 `br_app_services`。

集成测试从宿主展开的 SDK 额外链接 Opus 框架；不再创建第二个 Opus Pod 子目标，避免同一 XCFramework 的重复拷贝。生成 Pod 的最低 iOS 版本设为 15.0，兼容 Xcode 27；App 仍要求 iOS 26。

修改开关后执行 `pod install`，共享读取器同步更新依赖、`WISELIFE_EUREKA_RING` 和源码排除。关闭功能不删除已有录音；仅改 JSON 后直接 Build 不会更新现有工程。

开启 Xcode 用户脚本沙箱时，`post_integrate` 将 CocoaPods 资源复制脚本的临时文件清单改写到 `DERIVED_FILE_DIR`，避免写入受保护的源码 `Pods` 目录；重复运行保持幂等，不关闭沙箱。

## 两种原音的处理契约

| 来源 | 原音文件 | 处理层接入 | 来源标记 |
| --- | --- | --- | --- |
| Apple Watch | 每小时一个独立 M4A，最后一份可不足一小时 | 按录音组、序号及真实偏移形成连续音源，保留缺失文件产生的缺口 | `captureDevice: watch` |
| EurekaRing | 一条设备录音对应一个完整文件，超过一小时也不拆原音 | BLE 校验后流式转为 16 kHz 单声道 AAC/M4A，进入现有本机录音库与统一处理队列；不套用 Watch 小时分片描述符 | `captureDevice: ring` |

AI 窗口最多 300 秒核心区间及两侧各 2 秒上下文，仅引用原音帧范围。全文、说话人和主题片段的时间戳相对整条录音，不在小时边界归零；内容主题分段沿用现有规则，与物理音频是否分片无关。Ring 单文件不会被遗留的小时组元数据合并成 Watch 分片。`VoiceNote.effectiveRecordingGroupID` 对显式或旧名称识别出的 Ring 返回空，列表、详情、播放分组、删除、恢复、转写与音源发现统一使用它；原始组字段继续保留供 Codable 往返，不需要改写已有数据库。删除 Watch 组不会连带删除 Ring。

Ring 任务保留稳定笔记 UUID 和同步回执，重传不重复导入。保存成功后清理 SDK／转换暂存副本，不删除硬件原音。

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

## 历史

2026-10-20 曾按用户要求关闭 Ring，当时缺少相邻源码适配层，开启状态未完成构建。2026-11-03 用户要求在当前分支恢复本仓库 Pod、开启编译及兼容两类录音。本节以前的默认关闭／外部源码恢复步骤不再适用于当前配置。历史设备记录见 [原生接入验证](../verification/eureka-ring-native.md)。
