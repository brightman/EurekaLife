# 内容片段持久化与回顾刷新修复

日期：2026-10-23。最终签名版本已于 20:42 原位安装到 Bright 的 iPhone 16 Pro，20:46 启动成功。

## 回顾规则

今日、昨日、历史日期统一按回顾日期登记自动生成次数。一个日期开始过生成后，不因相关或无关内容更新、ASR/分段进度、模型切换、日期切换、回顾档案替换或 App 重启而再次自动生成。后续生成只能手动触发。失败和中断同样等待手动重试，避免反复调用。

SQLite 的 `daily_recap_attempts(day PRIMARY KEY, started_at)` 与开始生成前的档案标记在同一事务内写入；先提交，再调用模型。手动生成也登记该日期。迁移会登记旧档案日期。自动次数不依赖当前正文是否存在。

## 频繁刷新的原因与修复

- 旧模型把所有日期的数据指纹和全局处理版本用于上下文变化，随后清空所有历史档案、显示加载状态、重新读取。独立复现中，AI 调用仍只有一次，但页面多次转圈。
- 回顾指纹现在按目标日期计算。普通处理进度触发静默校验，保留已展示回顾，不再清空历史卡片或取消正在进行的手动生成。
- 内容事实摘要不再包含单纯的 source/segment revision；兼容旧摘要并持久化升级，保留原引用编号与引用集合。
- 后台校验开始后若手动生成完成，归档版本校验阻止旧快照覆盖新结果。
- 删除已引用资料、撤销来源权限仍会使相关正文失效；这一过程不恢复自动生成次数，也不自动补跑。
- 空闲卡片明确提示“回顾尚未生成，点开手动生成”，不再误写成持续整理中。

## 内容时间轴

- SQLite schema v13 增加 `content_segment_presentations`，保存已加工片段的精确带时间转写，与语义内容签名绑定。
- 处理完成时按 1,000 行分页准备转写，短写事务校验来源与片段版本后提交。查询保留模型边界前后 2 秒上下文。
- 日期展示直接读取持久化结果，不扫描原始 ASR，也不在页面读取时重新推理。失效或未准备完成的片段暂不显示；AI 完整证据读取会拒绝不完整快照。
- 首页和资料列表只展示有非空转写的内容段；原始长录音保留在资料库折叠入口和片段详情的完整录音入口。
- 当前“有意义”的展示门槛是非空转写；不代表每段都已经获得 AI 主题与摘要。

## 验证结果

| 验证 | 结果 |
| --- | --- |
| 回顾证据、协调器、服务回归 | 三组通过；使用本地 fixture / stub，无真实 AI 请求 |
| 20 次全局处理进度通知 | 已有回顾保持可见，无前台加载状态，无新增 AI 调用 |
| 无关日期更新 | 不重新读取目标日期与历史档案，不调用 AI |
| 已有日期新增资料、重新创建模型/连接 | 不自动重算，手动更新仍可用 |
| 双模型竞争、档案删除后重启 | 同一日期仅一次自动调用 |
| 后台校验与手动生成竞争 | 后完成的校验不会覆盖新生成正文 |
| 资料删除、撤权、取消、旧引用摘要升级 | 隐私与引用回归通过；取消不复活失效正文 |
| 片段呈现、SQLite 竞争、分段、内容加工、音频路径变更 | 回归通过 |
| 本地真实数据库副本重开 | 33 个片段中 23 个非空，77,549 条带时间转写，读取 0.128 秒，原始 ASR 查询 0 次 |
| 最终 iPhone workspace 签名构建 | `BUILD SUCCEEDED`，退出码 0 |
| 独立代码复核 | 未发现阻塞问题 |

## 真机证据与边界

20:46:53、20:47:43、20:49:02 三次真实首页截图均显示昨日回顾处于空闲状态，提示手动生成，没有显示回顾加载动画或 database locked 弹窗。这是离散截图核验，不是连续录像或完整触摸交互测试。

20:47 与 20:49 分别复制真机数据库核对：

- schema v13，`quick_check` 均为 `ok`。
- 10 月 22 日自动次数仍只有原先一条；首次登记时间未变。两次复制间回顾 payload 逐字节一致，没有新正文或 `generatedAt`。
- 该日回顾在本轮开始前就已无生成正文，当前等待用户手动生成；没有自动恢复或补跑。
- 目标录音时长 24,129.276 秒，原始录音数据库行及 ASR/VAD 全部逐行摘要一致。
- 20:47 核对时，目标录音有 26 个已持久化的初步内容段，18 个含非空转写；持久化呈现包含 69,706 条带时间转写。非空摘要仅 2 段，不能宣称全部 AI 标题/摘要完成。
- 全库录音数从 16 变为 14。两条差异都对应 19:57:45 / 19:57:57 的删除墓碑；ASR/VAD 总数差异完全归属这两条来源。无法仅由数据库证明删除操作者；未擅自恢复，不能宣称全库记录完全未变。目标 6 小时 42 分录音不在删除范围内。

20:30 的旧版本真机截图已展示 10 月 22 日多个片段。最终版本的空白段过滤已通过代码和数据库检查，但尚无最终版本该列表的截图；iPhone Mirroring 未配置，无法直接替用户在真机切换日期。Watch 本次仍未完成新版本安装和 GPS 真机验收。

### 20:51：用户询问该录音是否仍在加工

重新复制真机数据库，确认 AI 标题/摘要仍在推进：20:47 完成 2 段，20:49 完成 4 段，20:51 完成 5 段；有转写、可整理的段数为 18。各次中间摘要检查点从 16 增至 48、78，确有增量进展。

但分段不是最终完成状态：81 个活动窗口的 ASR 全部成功，VAD 仍为 25 成功 / 56 失败，来源 `cancelled=1`，没有待重试阶段请求，26 个内容段均为 `isFinal=false`。不能把“窗口 completed”或“26 段已入库”说成全流程已完成。

这 56 个 VAD 失败与先前 [真实录音 Mac 审计](2026-10-23-real-recording-mac-audit.md) 一致：旧版严格概率校验拒绝 FP16 的 `1.0009765625`。修复已在当前 `OnDeviceSpeechActivity.swift`，此前 Mac 同文件修复后 81/81 成功；手机旧失败状态尚未重新执行。现有“处理状态 → 重试处理”入口按失败阶段补跑，保留成功 ASR。未擅自清除手机取消标记，也未用 Mac 结果覆盖手机数据库。当前需要从 App 恢复失败检测，才能核验最终定稿与主题合并结果。

证据：`content-progress-phone/Database/`、`content-progress-verification.json`。每日回顾在这段内容加工过程中没有新增自动生成次数。

## 本地证据

私有目录：`/Users/karama/Documents/WiseLife-Reports/2026-10-23-device-gps-content-h4mwrnk_/`。

- `recap-timeline-final-install.json`、`recap-timeline-final-launch.json`：最终安装与启动。
- `recap-timeline-final-verification.json`：目标数据、自动次数、删除墓碑及两次数据库稳定性核验。
- `recap-timeline-final-phone/Database/`、`recap-timeline-stability-phone/Database/`：最终版本真机数据库副本；未回写真机。
- `wiselife-recap-refresh-reviewed.log`、`wiselife-recap-timeline-final-build.log`：最终回顾回归与签名构建。
- `recap-home-20.46.53.png`、`recap-home-20.47.43.png`、`recap-home-20.49.02.png`：最终首页截图。

无卸载、重置、提交或推送操作。

<a id="recap-budget-20261102"></a>

## 2026-11-02：真机回顾长时间等待与模型窗口

类型：修复验证。状态：代码、回归、签名构建、真机原位安装及本次豆包生成成功；具体边界见下方。当前规则见[每日回顾说明](../../../docs/superpowers/specs/2026-10-22-daily-recaps-design.md)。

### 现场证据

- 环境：Bright iPhone 16 Pro，Device Hub 显示 iOS 27.2，Xcode 27.2。用户反馈发生在真机；本轮没有把模拟器当作复现环境。
- 19:06 只读复制数据库，`quick_check=ok`。11/01 档案有 90 条引用，正文为空，保留“上次生成未完成，可手动重试。”；自动日期标记已存在。
- 真机配置是 `doubao-seed-2.0-mini`、OpenAI 兼容、`contextWindowTokens=262000`。未读取 API Key。
- 19:09 看到用户手动生成中，19:14 截图已显示 19:13 完成的正文。数据库确认 90 条引用、79 条可用文字、11 条文字待就绪。旧版本本次约 4 分钟完成；不是已证明的永久死锁。先前中断的准确触发原因没有运行轨迹，不能确定。
- 代码确定缺陷：服务完全忽略已配置窗口，统一按 1,800 字符串行分批；全轮无截止时间、无批次反馈；首页忽略错误消息。旧结果还把资料处理数量写成跟进事项。

### 修复和验证

- 根据模型窗口做完整输入预算：指令、证据、输出、安全余量及引用修复；充分窗口直接生成，超出才分批和合并。没有扩大单条原文摘录范围，也没有更换模型或发送目标。
- Apple 使用原生窗口，在 iOS 26.4+ 额外用原生 tokenCount 校验，26.3 保留估算回退；自定义模型保留用户窗口和未知模型保守回退。
- 显示资料核对、整理批次、合并、保存；全轮 300 秒后停止等待并持久化可重试提示，过期响应不能覆盖新结果。首页显示已有失败／取消信息。
- UI 仍显示待转写和摘录覆盖数；模型 prompt 不再携带这些处理数量，避免被当作生活待办。此项改善仍需真实输出质量核验。
- `sh apps/wrist-notes/scripts/test_daily_recaps.sh`：三组通过。新增 90 条合成资料的大窗口单请求、全部首尾摘录保留、小窗口分批、过小窗口拒绝发送、实际输出限额、超时后重试和迟到响应隔离。保留同日期一次自动、并发领取、权限、删除和旧来源校验回归。
- 回归先失败再修复：大窗口测试在旧代码断言失败；截止时间测试在未接入定时器时断言失败。测试脚本同时补齐现有数据库迁移依赖，避免将原脚本编译缺依赖误认为业务失败。
- `sh apps/wrist-notes/scripts/test_ai_settings.sh`：通过。没有实际访问云端服务；网络传输为 stub。
- `xcodebuild -workspace apps/wrist-notes/WristNotes.xcworkspace -scheme WristNotes -configuration Debug -destination 'id=<IPHONE_DEVICE_ID>' -derivedDataPath /private/tmp/wiselife-recap-build-20261102 -disableAutomaticPackageResolution -jobs 2 IPHONEOS_DEPLOYMENT_TARGET=26.0 build`：`BUILD SUCCEEDED`。包含共享工作区既有改动；编译存在既有捕获／弃用警告，不是零 warning。
- 19:26 `devicectl device install app` 与 `device process launch` 均成功；bundle `cloud.karama.wisenote`。首页显示此前保存的昨日回顾，没有自动重算。Device Hub 对真机仅能查看，已请用户点击手动更新进行最终核验。

私有证据目录：`/Users/karama/Documents/WiseLife-Reports/2026-11-02-recap/`。包含本机数据库副本、red/green 测试日志、构建与安装结果；未写回数据库副本，未将用户原文或配置文件提交到仓库。

### 19:28 新版真机结果

- 用户操作后，数据库 `generatedAt=2026-11-02 19:28:09 +08:00`，新正文 248 字符、无错误消息；旧版为 19:13:06、246 字符。新旧 `fingerprint` 相同，都是 90 条引用、79 条可用文字，确实是同一资料快照的新结果。
- 新正文包含 5 个不同来源编号，全部属于保存的引用集合；没有再出现“待就绪／摘录／转写状态”等处理元信息。编号校验不等于全面证明建议质量或每句事实正确。
- 安装前后：录音 42、录音会话 2、会话切片 5、内容片段 486、自动尝试日期 7，数量一致；数据库 `quick_check=ok`。没有删除或替换用户原始数据。
- UI 已退出生成状态，恢复“更新每日回顾”按钮。没有捕获点击开始的精确时刻及云端请求日志，不宣称具体耗时／提速倍数或真实请求次数；90 条合成资料单请求由生产服务的 stub 测试证明。
- 脱敏核对结果保存在私有目录 `verification-safe.json`，不包含正文、位置或密钥。

边界：尚未验收本轮 Apple 本地真实推理、ChatGPT/Mac、Watch 安装或精确生成耗时；没有提交、推送或发布。本次没有统一所有 Agent Runtime，也没有改动 Ask AI 的窗口预算。

### 同轮追加：自然表达与多源推断

用户在查看 19:28 的回顾后要求更有人情味，并结合地点、步数、健康／睡眠、录音发言人，从工作、学习、生活视角回顾和建议。

- 当前主说明与 Prompt 目录已更新。输出改为 2–3 段自然叙述，按证据串联经历，不强制栏目和数字清单；允许有限的地点／活动推断及适度生活建议，未知发言人的安排不归给用户。
- 读取投影增加可选 speaker 标记；长录音复用 SQLite 当前有效绑定，短录音读取有效联系人／手动命名／本人声纹。每个摘录边界重新附上对应身份，绑定撤销改变证据摘要。没有建立新的用户画像或添加身份匹配算法，不能把长短录音两条链路的编号直接视为同一人。
- 联系人名称、已有组织名称属于这次回顾的获准文字；手机号、邮箱、头像不进入 prompt。沿用模型选择和外发授权，不扩大来源开关。
- `test_daily_recaps.sh`：三组通过；先复现身份未进入 prompt，再验证逐句归属、绑定撤销和长发言三处摘录保留身份。补测 `[1,999]` 不得绕过合法来源检查，并兼容旧版合法 `[1,2]` 归档。
- `test_content_refresh.sh`：通过真实 SQLite 绑定／过期 revision 测试，确认回顾收到有效联系人、失效绑定不再命名；普通加载路径不携带该投影，避免改变 Ask AI 上下文。
- 扩展提示词首稿触发 4K 保守窗口测试失败；压缩指令后小／大窗口及全部引用、授权、一次自动回归通过，没有简单放大未知模型窗口。
- `personalized-build.log` 为再次 `BUILD SUCCEEDED`；`personalized-install.json`、`personalized-launch.json` 确认真机原位安装启动成功。最终自然表达仍需用户手动更新回顾核对，不能以 stub 输出证明语言质量。

### 19:49 现场语言问题与后续修正

- 真机新结果已于 19:49:07 保存；原先仅 `Write in locale zh-Hans` 的弱指令未能约束模型：正文以英文为主且夹杂中文，并仍出现把未知说话人的安排写成用户计划的问题。归档 language 与当前设置均为 `zh-Hans`（未设置时默认中文），不是 App 传错语言。
- 不把这次输出算作表达质量验收通过。强化未知说话人的自然表达，明确不得使用“你提到／你计划”或生成相应用户任务；这是模型规则，不宣称能以程序彻底验证所有归因。
- 添加系统与 user prompt 的强语言约束及 `NLLanguageRecognizer` 主语言检测；错误语言沿用一次有界修复，仍错误则返回 `languageMismatch`，拒绝保存新正文。保留既有回顾，用户手动更新，不自动重算。
- 自动测试先复现英文结果被中文 UI 接受的失败，再验证中文修复、英文／日文界面输出、连续两次语言错误拒绝保存；其他预算与来源回归沿用同一套测试。
- `language-green.log` 三组回归通过，`language-build.log` 为 `BUILD SUCCEEDED`；`language-install.json`、`language-launch.json` 确认再次原位安装启动成功。源码与安装产物对应本次语言检查；最终真机语言结果待用户更新后核验。

### 19:57 语言复验与最终安装

- 只读数据库副本确认 `generatedAt=2026-11-02 19:57:33 +08:00`，`language=zh-Hans`，中文正文已保存、无错误消息；证明本轮中文界面语言生效。英文／日文只通过生产服务 stub 回归，未做真机切换语言验收。
- 正文复核仍发现将昨日经历称作“今天”、把未知发言人的出行归给用户；此结果只通过语言项，不算全部叙述质量通过。
- 最终补丁在日期上下文中明确“昨天／今天／那天”，无确认本人发言时对已观察到的少量显式归属句式做一次有界修复。空白闪念、与原文不一致的身份投影不会视为本人发言。规则范围和局限已写入当前设计及 Prompt 目录。
- `ownership-red.log` 先复现空白闪念错误放宽归属；`ownership-green.log` 三组全部通过（input/SQLite、coordinator、stub service），包含未知出行归属拒绝、合法讨论主题保留、旧标签不匹配拒绝。真实模型语义质量仍需独立检查。
- `narrative-build.log` 为 `BUILD SUCCEEDED`（退出码 0）；`narrative-install.json`、`narrative-launch.json` 确认最终版再次原位安装启动成功，没有卸载／重置。20:07 Device Hub 首页仍显示原有中文正文，没有因启动自动重写。
- 最终日期／归属补丁的真机重新生成尚待用户点击“更新每日回顾”。没有提交、推送或发布。


<a id="ui-lag-20261102"></a>

## 2026-11-02：录音处理期间列表卡顿与回顾 SQLite 核对

类型：性能修复与持久化验证。当前状态：代码、自动回归、iPhone 构建及签名通过；用户确认停止录音后已原位安装，并在 Ask AI 后续修复安装后反馈“明显改善”。下方保留安装前的诊断事实；最终安装与数据核对见[同日 Ask AI 追加记录](#ask-ui-lag-20261102)。关联：[每日回顾当前说明](../../../docs/superpowers/specs/2026-10-22-daily-recaps-design.md)。

### 真机证据

- Bright iPhone 16 Pro，iOS 27.2；对已安装的 WiseLife 使用 Xcode Time Profiler，22:28:50–22:29:16 采集约 25 秒。屏幕为 11 月 2 日的「原始录音」列表。
- Instruments 报告 3 次主线程 hang：541.02、686.39、316.97 ms。共 3,507 个主线程采样，2,036 个包含 `DaybookView.mergeListRecords → timelineRecords`，1,923 个包含 `DayRecord.recordingProjection`，1,075 个包含回顾摘要路径，其中 907 个包含 `factDigest`。这些栈可能重叠，不能相加当作独立总耗时。
- 原列表每行获取合并顺序和两个资格集合，重复投影全天长转写；回顾同步在主线程反复序列化旧／新事实，全局进度版本变化还会重读历史档案。音频处理已有后台 worker；本证据不表示全部 ASR 或模型推理在主线程执行。
- 只读导出的本机 `daybook.sqlite3`，`PRAGMA quick_check=ok`。`daily_recaps` 7 行、`daily_recap_attempts` 7 行；11/01 有 195 字符正文及 90 条引用，10/27 有 122 字符正文及 3 条引用；10/26、28、29、30、31 为无正文占位档案。检查仅输出计数与日期，未提交正文、位置或原始转写。

### 修改与验证

- 每次列表渲染共享合并顺序、资格集合，取消逐行重复扫描。
- 事实投影未变时复用指纹；使用与既有摘要字段一致的结构比较，保持 JSON 摘要格式不变。普通处理版本不触发档案重读。
- 内容片段明确编辑／删除、说话人绑定变更和会话删除保留独立证据失效通知；页面调用既有回顾校验。来源权限、存储不可用／恢复、生成前后复查及每天一次自动尝试继续生效。
- 无 SQLite 迁移或原始录音修改；不重置 `daily_recap_attempts`。自动次数原已持久化，本轮没有重写这条规则。后续只有用户手动更新才会再次生成。
- `sh apps/wrist-notes/scripts/test_daily_recaps.sh`：三组通过，退出 0（证据与 SQLite、协调器、stub 服务）。新增 20 次进度同步不额外读取历史资料、存储恢复不重复生成、文字／音频范围／说话人变化不可复用事实指纹等检查。先在旧行为上观察到进度读取断言失败，再通过修复；网络传输为 stub。
- `sh apps/wrist-notes/scripts/test_content_refresh.sh`：通过，退出 0；先复现说话人绑定未独立失效的断言失败，再验证进度通知不增加证据版本，绑定／片段删除／会话删除会增加。保留真实 SQLite、当前及过期绑定读取、事件合并回归。
- `xcodebuild -workspace apps/wrist-notes/WristNotes.xcworkspace -scheme WristNotes -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/wiselife-progress-20261101/build -jobs 3 IPHONEOS_DEPLOYMENT_TARGET=26.0 build`：退出 0，`BUILD SUCCEEDED`。工作区包含其他未提交任务，不以 HEAD 代表产物。版本 1.0.2（11），不是新的 TestFlight 发布。
- `codesign --verify --deep --strict <WiseLife.app>`：通过。没有卸载、重置、提交、推送或发布。

### 边界与证据位置

初次构建完成时用户表示 Watch 仍在录音，因此当时未安装。随后用户明确“已停止录音，可以安装”，已完成原位安装与数据核对，见后续记录。尚未完成原始录音入口相同交互条件的量化复测，不能提供加速倍数或宣称全部卡顿消失。

私有临时证据：`/private/tmp/wiselife-ui-lag-20261102/`，包括 `baseline.trace`、`profile.xml`、`hangs.xml`、`hang-summary.json`、数据库只读副本、任务前源文件快照、red/green 日志及 `build-final.log`。长期可复查的脱敏结果与命令已在本节保留；原始私有数据不纳入仓库。


### 同日 23 点追加：当前后台工作与「原始录音」入口

用户再次反馈卡顿，并明确选择「原始录音」尤其明显。通过 `devicectl device info apps --bundle-id cloud.karama.wisenote` 两次确认手机仍安装 1.0.2（10），进程路径与先前基线相同；本节性能补丁尚未安装。

- 连续两次只读导出 SQLite，`quick_check` 均为 `ok`。活动音频窗口 372 个 completed、36 个 failed、0 个 pending／running；阶段重试请求 0。内容来源 15 个 processed、2 个 pending，后两者上游各有失败窗口。索引块 24 个 ready、107 个 pending；pending 不等于当前正在计算。
- 两份快照的音频来源／窗口／重试请求、分段／持久化呈现／加工检查点、语义索引、每日回顾／尝试登记、Ask AI 运行记录逐行摘要完全相同；未观察到处理推进或回顾重写。不能仅据快照排除未完成的外部请求。
- 按名称与 PID 附加 Time Profiler 分别返回 `Cannot find process matching name: WiseLife`、`Cannot find process for provided pid: 3718`。改用 `--all-processes --time-limit 25s` 成功，导出后仅筛选 WiseLife（3718）：静置期间只有 1 个 1 ms CPU 采样，无 potential hang，热状态 Nominal。本次未捕捉点击／滚动原始录音瞬间，不据此宣布交互不卡顿。
- 「原始录音」与时间轴共用 `recordList`；当前安装版本的每行合并顺序与资格查询会重复进入 `timelineRecords → recordingProjection`。22:28 的原始录音列表采样已定位这条路径；本轮源码复核确认其与用户指出的入口一致。已构建补丁将选择元数据移至每次渲染共享，并复用未变的回顾事实指纹；需要先安装后复测，再决定是否进一步拆分原始录音列表，不叠加未经验证的改动。

本次只做读取和采样，没有重启 App、重试失败音频或修改用户数据。私有证据目录为 `/private/tmp/wiselife-live-work.5p8URY/`，脱敏汇总 `diagnostic-safe.json`；原始录音、正文、配置和其他进程信息不纳入仓库。


<a id="ask-ui-lag-20261102"></a>

## 2026-11-02：Ask AI 历史从 SQLite 直接展示与真机验收

类型：性能修复与持久化验证。状态：代码、回归、Debug 构建、签名、原位安装和启动通过；用户真机反馈“明显改善”。[当前技术规则](../docs/ask-ai-session-orchestration.md#history-display-20261102)。

### 根因与改动

- 首次列表补丁安装后，用户仍指出 AI Tab 切换与点击输入框明显延迟。Time Profiler 因设备短暂断开仅采到约 1.27 秒，765 个 WiseLife CPU 样本中 763 个在主线程；约 721 个经过 `DaybookAssistantView.body → model.isCurrent`，596 个经过证据有效性检查，463 个进入证据快照 JSON 编码，124 个经过说话人指纹查询。这些栈重叠，不能相加计算总耗时。
- 历史 UI 原先为每个已保存回答反复核验当前长转写、解析说话人和序列化证据。键盘／焦点引发视图刷新时也触发此路径。
- 复用现有 SQLite `conversation_turns` 和每次 10 轮分页；保存的问题、回答、引用与时间直接展示，`historySources` 仅做当前来源权限过滤。Tab、输入框和历史渲染不重读全文、不计算历史证据指纹。
- 从历史回答“加入行动”或创建提醒时才异步加载所需范围、后台核验当前证据；已删除／变化的来源拒绝该操作但不删除历史。进行中的回答、重试和云端发送确认保留原有权限与新鲜度检查。空闲时不重算已完成准备态的全部证据。
- 不增加数据库／schema，不重写旧对话、不重新生成每日回顾。

### 验证与安装

- 回归先在旧校验路径失败：`history rendering must use saved references without re-reading or validating current transcripts`。最终 `sh apps/wrist-notes/scripts/test_conversations.sh` 退出 0：真实 SQLite 重新打开后保留回答／引用／时间；100 次历史展示不调用范围加载；撤权隐藏引用；显式操作拒绝消失来源、接受有效来源。原有分页、取消、云端确认和过期结果检查通过。
- 同前述命令的 Debug iPhone 构建为 `BUILD SUCCEEDED`、退出 0；复制产物的 `codesign --verify --deep --strict` 通过。最终安装 `1.0.2 (11)`，`BuiltAt=2026-11-02T15:39:04Z`，安装／启动成功。用户随后明确反馈“明显改善”。该安装包尚不是 TestFlight 的 1.0.2 (11)，发布版本另见[发布记录](../docs/testflight-release-2026-10-19.md)。
- 安装前后只读数据库 `quick_check=ok`。每日回顾 7、每日尝试 7、原始语音记录 45、录音会话 2、录音分片 5，以上记录逐行不变。历史对话 21→22，已有 21 行全部保留且不变，新增 1 行发生在用户使用期间。
- 内容片段 538、音频处理任务 531，均无删除；部分派生路径／来源版本字段变化，未据此宣称整库完全相同。没有卸载、重置、清除录音或重置回顾尝试记录。
- 最后 30 秒采样完成，但 Instruments 报告 `Timeline modification failed -- dylibs overlap`，导出存在符号映射警告。未取得可信的同条件量化对照，因此以用户反馈作为本次交互验收，不报告零卡顿或加速倍数；Watch 独立安装／使用未另行验收。

私有证据：`/private/tmp/wiselife-lag-install.Lz2WKg/` 的 `ask-red.log`、`ask-final-tests.log`、`ask-final-build.log`、`ask-install.json`、`ask-launch.json`、`ask-data-check.json` 及采样。原始数据库、转写与设备截图不纳入仓库；本节保留脱敏结果供后续复查。

<a id="recap-date-cache-20261103"></a>
## 2026-11-03：回顾切换日期反复加载、历史读取错误隔离

类型：缺陷修复。状态：用户确认首轮 1.0.3 (12) 切换飞行模式无转圈／无报错；后续录音组展示替换补丁已通过回归、iPhone 签名构建和原位安装，真机完成 11/1 → 11/2 → 11/1，观察到回顾直接显示。更新前后 8 条回顾、8 条尝试记录逐行不变；首次冷读取及其他日期／来源变更不据此保证零等待。关联：[当前回顾读取规则](../../../docs/superpowers/specs/2026-10-22-daily-recaps-design.md)。

### 诊断事实

- Bright iPhone 16 Pro，iOS 27.2，检查时安装 1.0.2 (11)。用户报告「11 月 2 日 · 回顾失败」，并指出其他日期也反复加载。
- 只读复制 App 数据库及 WAL/SHM 后，`PRAGMA quick_check=ok`。11 月 2 日已保存 325 字正文、62 个来源引用，无错误 message；生成时间为 2026-11-03 13:27:13 +08，早于本次检查。11 月 1 日也有已保存正文。
- Device Hub 真机观察到切至 11 月 2 日先出现「正在整理当天的记录…」，等待后显示已保存回顾。此次未捕获明确生成失败提示，没有点击重新生成或向外部模型重放个人资料。
- 根因：日期／前后台切换触发完整 reset，清空所有内存回顾；随后串行校验所有历史日期，全部结束才统一发布。任一日期读取错误会清空所有日期。UI 日期投影消失也可能被误判为来源删除。

### 修复与验证

- 保留已校验日期缓存；切日不把上一日期的可见记录缺失解释为删除；事实变动按日期失效输入，权限撤销与明确编辑／删除仍走校验。
- 当前日期优先校验并发布，其他日期逐个处理；单日期错误不再隐藏其他日期的结果。SQLite schema、原始录音、已有正文与每日自动尝试次数不迁移／重置。
- 新增真实内存 SQLite + 生产协调器回归：其他日期读取失败、来回切日、无额外全文读取／模型请求、前后台恢复、较早日期优先显示、删除全局可见的历史来源后隐藏并清除对应旧回顾。外部服务用确定性测试替身，测试不联网。
- 修复前新测试明确失败于 `an unrelated historical read failure must not hide a valid saved recap`。修复后 `sh apps/wrist-notes/scripts/test_daily_recaps.sh` 三组 evidence/SQLite、coordinator、service 测试通过，已有授权、失效来源、超时、一次自动尝试用例继续通过。
- `xcodebuild -workspace apps/wrist-notes/WristNotes.xcworkspace -scheme WristNotes -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/wiselife-progress-20261101/build -disableAutomaticPackageResolution -jobs 3 IPHONEOS_DEPLOYMENT_TARGET=26.0 build`：退出 0，`BUILD SUCCEEDED`。共享工作区含其他任务变更，不能用 HEAD 代表构建产物；未提交／推送／发布。
- 私有原始数据库与诊断文件保留在本机 WiseLife-Reports 日期目录，不纳入仓库。自动化回归不是新模型输出质量或真机交互验收的替代。
- 最终版本沿用工作区 1.0.3 (12)，`codesign --verify --deep --strict` 通过。尚未更新真机，等待确认当前录音状态，避免安装中断录音；没有卸载 App、重写手机数据库或重置自动生成记录。

### 同日追加：飞行模式／控制中心导致首页重新加载

- 用户报告切换飞行模式后首页重新加载。21:35 在旧版 1.0.2 (11) 真机详情中捕获确切错误：`记录或 AI 设置已更新，请查看最新资料后重试。`，对应 `.changed`，不是 LLM 返回错误或 SQLite 损坏证据。此前未捕获错误的记录保留。
- 代码链路：控制中心收起导致 didBecomeActive；Runtime、NotesModel 和 DaybookView 分别触发恢复／Watch 状态刷新；旧 `refreshWatchStatus()` 每次重新初始化 NoteRepository，扫描并修复文件后 `refresh()` 无条件广播 AudioSourceDidChange。处理／会话版本因此变化，回顾完整日期读可能连续失效。生活数据把 inactive 视为后台，也额外触发补刷。
- NotesModel 复用已有连接，只在连接尚不可用时打开；仍尝试接收收件箱与未完成任务。Runtime 首次进入／实际后台返回才恢复处理与会话，重复激活不重复恢复。DaybookView 忽略生活数据的短暂 inactive；LifeSourceModel 对同日重复 active 去重，保留日期变化、存储恢复及观察查询注册失败重试。
- 回归先失败再修复：健康专项失败于 `repeated activation without entering background must not reload health records`；真实 iOS NotesModel + SQLite 专项测得 7 次打开（应为 1），失败后修复为 1。旧测试脚本缺失新增依赖、AI 测试边界落后于生产接口，先补齐测试宿主再运行；这些编译失败不计为功能回归通过。
- `sh apps/wrist-notes/scripts/test_health.sh` 通过。`ruby apps/wrist-notes/scripts/test_storage_lifecycle_ios.rb /private/tmp/wiselife-foreground-storage-20261103` 后，`xcodebuild -project /private/tmp/wiselife-foreground-storage-20261103/StorageLifecycle.xcodeproj -scheme StorageLifecycle -destination 'platform=iOS Simulator,id=332DEB86-4843-4543-8C73-4719B38DA704' -derivedDataPath /private/tmp/wiselife-foreground-storage-20261103/build test`：10 项通过，0 失败；覆盖数据库不可用、解锁、收件箱重试、处理结果恢复、照片和提醒。宿主只访问临时测试目录，不使用 WiseLife 真机数据；AI 边界禁用网络。
- 同前述 iPhone 构建命令再次执行成功。此轮未切换真机网络设置，未安装新版本；需要原位更新后再验收控制中心／飞行模式和切日体验，不能以生命周期注入测试替代真机 UI 结果。

### 同日 21:53：用户安装后的真机核对

- 用户表示已安装。`devicectl device info apps --bundle-id cloud.karama.wisenote` 核对版本为 **1.0.3 (12)**；本地最终产物 BuiltAt 为 `2026-11-03T13:42:54Z`，尚未读取手机内的 BuildMetadata，版本号不能单独证明二进制完全一致。
- Device Hub 屏幕显示飞行模式图标，11 月 2 日首页回顾已有正文、来源 54 条，无加载指示和读取错误。这证明观察时可显示已保存回顾，不等于已完成多次切换验收。
- 尝试继续操作时 UI 工具返回 `noWindowsAvailable`；重新绑定并激活窗口后，Device Hub 明确显示 `Currently Unavailable`。未成功执行本次控制中心开合／切日操作，未修改手机网络设置；已请用户 USB 重连并解锁后继续。

### 同日 21:57：连接恢复与安装后数据核对

- Device Hub 已重新将 Bright 列入 Available，可读取 WiseLife「我的记录」界面截图，手机显示蜂窝网络状态。此前不可用为当时观察，不能继续认定手机已断开。
- 只读复制安装后的 `Library/Application Support/WristNotes/Database`，连同 WAL/SHM 在本机副本检查：`PRAGMA quick_check=ok`；8 条 `daily_recaps` 的逐行 payload SHA-256 与基线全部相同，8 条 `daily_recap_attempts` 的日期／时间也全部相同。未重新生成回顾或重置自动尝试；本比较不表示其他业务表完全相同。
- 新证据保留于私有目录 `WiseLife-Reports/2026-11-03-recap-failure/installed-db` 和 `installed-safe-comparison.json`，不将原始数据库／正文提交到仓库。
- 重新绑定与激活窗口后，滚动和坐标点击仍重复返回 `Computer Use server error -10005: noWindowsAvailable`。连接和画面可读，交互操作不可用；本轮没有成功切日期或操作控制中心，已请用户协助完成两项真机交互验收。没有再安装／终止 App，也没有修改网络设置。

### 同日用户真机验收：飞行模式通过，切日仍短暂转圈

- 用户反馈：切换到 11 月 1 日、2 日，回顾仍有一个很快的转圈加载过程；切换飞行模式速度快、无转圈、无报错。飞行模式项按用户实测通过；切日不计完全通过。
- 进一步只读核对已有手机副本：11 月 1 日回顾引用 10 条原始录音，11 月 2 日引用 7 条，均属于时间轴选日后由内容片段替换并隐藏的同组原始录音。`ContentSegmentModel.replacingAudio` 隐藏整个录音组，而 `changedVisibleRecords` 仅处理“片段消失、原始录音恢复”方向，未处理反方向的原始录音及同组兄弟文件消失。
- 回顾完整日期读取仍包含这些有效来源，因而会重新恢复旧正文；这解释了短暂转圈而非重新生成。
- 后续补丁在 `changedVisibleRecords` 中识别原始来源被派生片段替换，以及这次替换一同隐藏的录音组兄弟文件。保留既有正文，仍由完整日期读取判断真实事实变化；片段已稳定显示后发生的真实兄弟文件删除仍立即失效。没有修改 SQLite 或自动生成次数规则。
- `sh apps/wrist-notes/scripts/test_daily_recaps.sh`：修正测试夹具编译／引用格式后，旧实现明确失败于 `timeline replacement of a recording group must not clear its saved recap or show a spinner`；补丁后三组通过，退出 0。覆盖连续三次来回替换不清空正文、不转圈、不调用 AI，以及真实兄弟文件删除隐藏旧文并清除持久化正文。使用真实内存 SQLite、生产协调器，模型为禁网测试替身。
- 按本节同一 iPhone 构建命令运行，退出 0，`BUILD SUCCEEDED`；`codesign --verify --deep --strict` 通过。构建仍为 1.0.3 (12)，`BuiltAt=2026-11-03T14:10:43Z`；需要以构建时间区分用户先前安装的同版本产物。本轮未安装／重启真机 App，切日补丁仍待安装后验收。
- 私有日志：`/private/tmp/wiselife-recap-group-red-20261103.log`、`wiselife-recap-group-final-20261103.log`、`wiselife-recap-group-build-20261103.log`。长期必要证据已在上述结果摘要保留；没有提交／推送／发布。

### 同日 22:12–22:14：后续补丁原位安装与切日复验

- 查看真机首页，未见录音横幅／进行中录音状态后，使用 `devicectl device install app` 原位更新签名产物，再 `device process launch` 成功启动；安装／启动命令均退出 0。仍为 1.0.3 (12)，本次安装产物 `BuiltAt=2026-11-03T14:10:43Z`。未卸载或重置数据。
- Device Hub 坐标点击恢复。使用实际日期选择器完成 11 月 1 日 → 11 月 2 日 → 11 月 1 日，每次选择后的首个观测画面（日期面板仍处于收起动画）均已有该日期回顾正文，未观察到回顾转圈／报错；后续片段时间轴补齐时正文保留。该观察不宣称逐帧零延迟，也不免除冷启动或真正来源变化时的必要校验。本次没有再次切换手机网络设置，飞行模式结果以上述用户实测为依据。
- 再次只读复制数据库与 WAL/SHM，`PRAGMA quick_check=ok`；与首轮安装后副本比较，8 条 `daily_recaps`、8 条 `daily_recap_attempts` 逐行完全相同。没有重新生成、改写正文或恢复自动生成次数，不据此声称整库其他业务表完全不变。
- 安装、启动、数据库副本与脱敏比较结果保留在本机私有日期目录，文件为 `group-fix-install.json`、`group-fix-launch.json`、`group-fix-db`、`group-fix-data-check.json`；不提交正文、设备截图或原始资料。
