# EurekaLife 文档入口

> 账本文档提交范围（2026-11-16，`43d86d8`）：该提交仅包含账本相关文档；配套 iPhone 原生源码和可运行原型尚未随该提交推送。

类型：导航 · 状态：current · 更新：2026-11-16 · 适用：EurekaLife iPhone／Watch、Mac Companion。

- [仓库首页与构建](../README.md)
- [初始代码导入与验证](repository-import.md)
- [iPhone 文档索引](../apps/wrist-notes/docs/INDEX.md)
- 闪念分类与生活账本：[识别流程](../apps/wrist-notes/docs/local-storage-and-retrieval.md#life-ledgers-20261113) · [SQLite 结构](../apps/wrist-notes/docs/local-data-schema.md#life-ledger-schema-20261113) · [Prompt 契约](../apps/wrist-notes/docs/ai-prompts.md#flash-ledger-extraction-20261113)
- [iPhone / Watch 使用与开发](../apps/wrist-notes/README.md)
- [Mac Companion 开发、测试与协议](../apps/wiselife-mac/README.md)
- [Ring 编译与录音兼容](../apps/wrist-notes/docs/2026-10-20-ring-build-switch.md)
- [iPhone→Mac 记录同步设计](../apps/wrist-notes/docs/iphone-mac-sync.md)
- [EurekaLife 官网与产品演示](../apps/wiselife-website/docs/INDEX.md)
- [文档维护规则](documentation-rules.md)
- [Apache-2.0 许可](../LICENSE) · [NOTICE](../NOTICE) · [第三方许可索引](../THIRD_PARTY_NOTICES.md) · [品牌规则](../TRADEMARKS.md)

## 2026-11-16

Mac Companion 源码与产品原型同步至 GitHub：会议录制／回放、本地 Whisper 转写、MLX 总结与会议 Ask AI、当前会议说话人分析，以及 React 设置／每日记录原型；补齐依赖锁定、许可、技术设计与验证记录。每日记录备份和按日 Ask AI 仍为前端演示，未声称原生同步已实现。[Mac 入口](../apps/wiselife-mac/README.md) · [当前会议能力](../apps/wiselife-mac/docs/meeting-recording.md) · [本次验证](../apps/wiselife-mac/verification/README.md#github-sync-20261116)。

补齐闪念新分类与共享生活账本的现行技术说明：[识别及确认流程](../apps/wrist-notes/docs/local-storage-and-retrieval.md#life-ledgers-20261113)、[三张 SQLite 表及迁移](../apps/wrist-notes/docs/local-data-schema.md#life-ledger-schema-20261113)、[模型输入输出契约](../apps/wrist-notes/docs/ai-prompts.md#flash-ledger-extraction-20261113)。说明去重、候选阈值、历史收录、统计日期／精度与 Ask AI 隐私边界，两级索引增加直接阅读入口。本次仅维护文档；实现及历史验收仍见[11 月 13 日记录](../apps/wrist-notes/docs/superpowers/plans/2026-11-13-life-ledgers-native.md)，不新增模型效果或真机通过声明。


## 2026-11-13

Mac产品原型增加设置（主目录、隐私与说明）、会议列表确认删除，以及会议下方的每日记录备份入口。统一模型／会议／每日备份路径，支持按日浏览、离线历史和备份中断演示。随后移除知识库入口，每日记录增加可折叠的整页 Ask AI 右栏，按日期隔离对话并支持引用返回原文；Ask AI 仅在会议和每日记录出现。类型与构建、17组浏览器检查通过，仅前端原型，未改动原生存储或发布。见[原型入口](../apps/wiselife-mac/prototype/README.md)与[交互及验证](../apps/wiselife-mac/prototype/docs/component-migration.md#2026-11-13-设置会议删除与每日记录)。

Mac会议已接入本地SpeakerKit/WeSpeaker说话人分离：跨窗口编号、原文归属、重命名、检查点恢复和已有录制补分析；重叠／不可靠归属保持未确定。修复长媒体解码舍入并以PTS保留空隙；本地LLM/ASR/说话人推理共用串行入口。功能与隐私见[当前说明](../apps/wiselife-mac/docs/meeting-recording.md#当前会议说话人2026-11-13)，构建、合成和真实录制验收见[验证记录](../apps/wiselife-mac/verification/README.md#meeting-speakers-20261113)。未发布。

Mac 长会议转写修复：Whisper 末尾时间戳超出实际分块（60秒输入曾返回60.32秒）不再使整块失败；裁齐真实边界并过滤补零区结果，保留异常时间校验。对75分钟真实MP4检查音轨与编码，并评估HEVC压缩副本，原文件保留。测试与完整录制验证见[验证记录](../apps/wiselife-mac/verification/README.md#long-meeting-asr-20261113)，存储取舍见[当前说明](../apps/wiselife-mac/docs/meeting-recording.md#视频存储体积2026-11-13)。

## 2026-11-12

Mac 原生界面已采用统一中性样式、220/56pt 图标导航、可折叠会议 Ask AI 和时间行下方播放器；新增本地 Whisper 转写与 MLX 总结，分块原文和结果持久保存，关闭 LAN 服务仍支持本机推理。编译、模块测试、真实本地模型音频样本及应用视图检查见[验证记录](../apps/wiselife-mac/verification/README.md#meeting-intelligence-20261112)，行为与限制见[当前说明](../apps/wiselife-mac/docs/meeting-recording.md)。未发布。

Mac 产品原型的会议详情将音频／视频置于录制时间下一行、内容标签之前；左侧栏 × 改为保留 56px 图标导航，中间页头移除重复折叠图标。构建与浏览器验证见[组件迁移](../apps/wiselife-mac/prototype/docs/component-migration.md)，仅原型调整，未发布。

Mac 原生会议录制主链路已接入：设置优先，仅录音直接开始，屏幕与音频通过 macOS 单屏／单窗口选择器确定范围；结束后校验本地文件，再进入详情回放。会议元数据持久化，中断文件保留。7 项合成测试及完整 Debug 编译通过；电脑控制连接不可用，真实选屏／录制／音源回放待现场验收，未发布。见[当前说明](../apps/wiselife-mac/docs/meeting-recording.md)和[验证记录](../apps/wiselife-mac/verification/README.md#meeting-capture-20261112)。

Mac 新增会议录制产品原型：参考用户提供的 Notta 截图，覆盖即时录音／录制会议／上传文件三个入口、录制设置、整页 Ask AI 右侧栏、左右侧栏折叠、总结与行动审核，以及权限／断连／延迟／失败恢复。初版浏览器交互与 7 种宽度检查通过；随后使用指定 frontend-components 的原始源码迁移为 React / Mantine / Tailwind 三栏原型，加入拖拽／键盘调宽并统一控件；左栏品牌与关闭按钮合并到顶部，状态标签使用浅底深色字，Ask AI 仅在会议／知识库出现。「录制会议」第一步为录制设置：仅录音直接开始，屏幕与音频才进入第二步选择 Entire Screen / Application Window，确认画面后开始。当前源码与验证见 [组件迁移](../apps/wiselife-mac/prototype/docs/component-migration.md)，产品行为见 [会议设计](../apps/wiselife-mac/prototype/meeting-recording-design.md)。该条记录为本地原型阶段；后续原生采集实现与验收边界见本日上方记录。尚未发布。

## 2026-11-09

独立 iPhone 产品原型补充九组功能说明与使用入口：桌面可收起侧栏，窄屏通过问号打开；记事本四类、AI、行动与总结模板边界同步。桌面和 320／390px 浏览器检查通过，见 [原型与验证](../apps/wrist-notes/prototype/daybook-design.md#当前入口与功能说明2026-11-09)。

Apache-2.0 许可与 ChatGPT 套餐接入已实现：官方授权入口、合成连接测试、Agent 工具循环与历史压缩。专项测试和两端构建通过，已原位安装 iPhone，真实授权、模型目录、固定文本和合成工具续传通过；已修复真机缺少 SSE 媒体响应头导致的无效响应。设置补充 Plus／Pro 套餐说明，刷新与连接测试按钮并排，真机显示已核验。当前验证进度见 [实施与验收](../apps/wrist-notes/verification/chatgpt-native.md#opensource-plan-20261109)，计划见 [任务计划](work/2026-11-09-chatgpt-plan-usage/plan.md)。

明确 ChatGPT 接入仅用于授权使用用户套餐调用 LLM，不作为 EurekaLife 注册／登录方式；保留服务授权所需身份验证。此前范围确认阶段未启用真实接入；后续开启与验证见上条，商业申请未发送。见 [接入范围](../apps/wrist-notes/verification/chatgpt-native.md#plan-usage-scope-20261109)。

Ask AI 第二期实现完整问答压缩、记事本四类只读工具、SQLite 精确账目统计、模型窗口预算和跨轮权限继承。设置提供四个独立开关；原问答保留。专项回归、复审和完整模拟器构建通过，未安装或发布；既有独立脚本限制另记。见 [当前实现](../apps/wrist-notes/docs/ask-ai-session-orchestration.md#memory-notebook-agent-20261108)、[验证记录](../apps/wrist-notes/verification/ask-ai-runtime-2026-11-01.md#memory-notebook-20261109)。

## 2026-11-08

Ask AI 历史压缩与记事本 Agent 第二期设计已补充并获批准：按 LLM 窗口预算装载能力，覆盖灵感／记账／人物／地点的查询、统计、关联分析与建议。后续实现见 11 月 9 日记录；[设计](../apps/wrist-notes/docs/ask-ai-session-orchestration.md#memory-notebook-agent-20261108)持续维护。

记事本四类原型与原生代码同步：灵感合并与编辑删除、账目管理、人物资料和关联片段、地点按日查看及标记。SQLite 回归与完整模拟器构建通过，原生界面验收待 Simulator 窗口恢复。见 [产品与验证](../apps/wrist-notes/prototype/flash-assets-design.md#notebook-management-20261108)。

官网、法律页面、产品原型及演示媒体统一为 EurekaLife；官网展示进一步统一英文并重新生成截图与视频，已发布到现有官网域名；验证与回滚见 [官网部署](../apps/wiselife-website/docs/tencent-deployment.md#current-deployment)。

修复闪念全文按词碎片化展示，改为连续原文；模拟器原位更新且录音与 SQLite 完整，界面验收待窗口控制恢复。见 [说明](../apps/wrist-notes/docs/local-storage-and-retrieval.md#thought-transcript-reading-20261108)。

修复“我的声音”登记时短语音重复填充导致的一致性拒绝：使用最多 10 秒真实语音上下文，保持验证阈值。现场样本离线保存／重读和 21 项 iOS 回归通过，当前模拟器 App／待保存录音保持原样。见 [诊断与验证](../apps/wrist-notes/verification/my-voice-native.md#enrollment-context-20261108)。

闪念统一为本人发言：直接转写与分段队列跳过说话人／声纹分析，历史闪念显示“我”。专项回归及 iOS 两种目标编译通过；通用队列测试的既有超时已用修改前代码复现。尚未安装或发布，见 [实现与验证](../apps/wrist-notes/docs/local-storage-and-retrieval.md#thought-speaker-20261108)。

App 对外品牌统一为 EurekaLife，覆盖 iPhone、Watch、Mac、权限文案、快捷指令、小组件及交互原型。保留数据、配对和签名标识；构建 16 已上传并开放内部 TestFlight 测试，外部构建 15 的审核保持不变。验证与发布详情见 [改名发布记录](../apps/wrist-notes/docs/testflight-release-2026-10-19.md#eurekalife-build16-20261108)。

按用户选择在 BIZCARD LIMITED 下创建独立 WiseLife App（Apple ID `6832169777`），Bundle ID 为 `cloud.karama.wiselife`，版本 1.0.3（15）。签名归档与发布 IPA 验证通过；13:16 上传成功，Apple 处理及出口合规设置完成。新内部组显示“正在测试”，当前测试账号已获邀请；未验证真机安装，旧 App 数据保留。见 [发布记录](../apps/wrist-notes/docs/testflight-release-2026-10-19.md#new-app-bizcard-20261108)。

## 2026-11-06

TestFlight 1.0.3（14）完成签名归档与最终 IPA 权限核验，15:44 上传成功，Apple 正在处理；包含 Ring 及闪念修复、HealthKit 权限修复。测试分发状态见 [发布记录](../apps/wrist-notes/docs/testflight-release-2026-10-19.md#build14-20261106)。

核对真机“总结等待处理”：闪念实际已完成空结果整理，弹窗误读旧总结字段。改为显示真实“闪念整理”批次状态。[说明](../apps/wrist-notes/docs/2026-10-20-ring-build-switch.md#2026-11-06-闪念处理状态显示)。

修复 Ring 闪念“创建个日程”的漏识别、录音时区传递与空结果无法重试；缺少时间仍保留待补充。见 [真机证据与验证](../apps/wrist-notes/docs/2026-10-20-ring-build-switch.md#2026-11-06-闪念日程漏识别)。

检查 Ring 5 小时整文件链路，修复未完成转码缓存被误保存及按百分比放宽时长校验的问题。实际 5 小时合成 Opus、恢复回归与签名构建通过；真实 BLE 长传输另行验收。见 [处理与验证](../apps/wrist-notes/docs/2026-10-20-ring-build-switch.md#2026-11-06-五小时录音边界与恢复)。

真机排查并修复 Ring 闪念因时间戳差异重复导入、AI 整理忽略设置的问题；已有录音保留。见 [原因与验证](../apps/wrist-notes/docs/2026-10-20-ring-build-switch.md#2026-11-06-闪念重复导入与模型选择)。

从现有 iPhone 与 Mac 工作区导入当前源码、测试、依赖声明及必要的设计资料。保留原有工程路径，排除运行数据、签名文件与构建产物；验证范围见导入记录。原文中的历史事实不代表此次重新完成设备或发布验收。

同日完成 iPhone 17 Pro（iOS 26.3）模拟器签名构建、原位安装和启动核验，版本 1.0.3 (13)；窗口显示限制见 [安装记录](repository-import.md#2026-11-06-ios-模拟器安装)。

修复 Xcode 真机构建时 CocoaPods 资源复制的沙箱权限问题。连接的 iPhone 签名构建通过，签名和隐私／许可资源校验通过；未安装真机。见 [原因与验证](../apps/wrist-notes/docs/2026-10-20-ring-build-switch.md#2026-11-06-xcode-真机构建修复)。
