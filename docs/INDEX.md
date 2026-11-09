# EurekaLife 文档入口

类型：导航 · 状态：current · 更新：2026-11-09 · 适用：EurekaLife iPhone／Watch、Mac Companion。

- [仓库首页与构建](../README.md)
- [初始代码导入与验证](repository-import.md)
- [iPhone 文档索引](../apps/wrist-notes/docs/INDEX.md)
- [iPhone / Watch 使用与开发](../apps/wrist-notes/README.md)
- [Mac Companion 开发、测试与协议](../apps/wiselife-mac/README.md)
- [Ring 编译与录音兼容](../apps/wrist-notes/docs/2026-10-20-ring-build-switch.md)
- [iPhone→Mac 记录同步设计](../apps/wrist-notes/docs/iphone-mac-sync.md)
- [EurekaLife 官网与产品演示](../apps/wiselife-website/docs/INDEX.md)
- [文档维护规则](documentation-rules.md)
- [Apache-2.0 许可](../LICENSE) · [NOTICE](../NOTICE) · [第三方许可索引](../THIRD_PARTY_NOTICES.md) · [品牌规则](../TRADEMARKS.md)

## 2026-11-09

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
