# Watch 已同步录音保留期限

类型：实施与验证记录。更新：2026-11-04。状态：代码及自动测试完成，配对模拟器配置回执通过；真机待验证。
主要说明：[本地数据生命周期](../../local-data-schema.md)。范围：Watch 本地副本，不删除 iPhone 数据，不接入 iCloud。

## 已批准方案与实施边界

- iPhone 设置 → 硬件 → Apple Watch：已同步录音保留时间，7／14 天，初次选择默认 7 天；用户查看预估后启用，升级不静默清理已有数据。
- 从 Watch 首次持久保存 iPhone 保存回执起算；未确认、缺失可靠日期、正在录制／恢复／系统传输占用的文件不自动删除。缺失日期的旧记录发送元数据查询，由 iPhone 确认现存音频后补回执，再开始计时；不重新导入手机已删除的录音。
- 设置请求与手表已应用状态分开显示；请求持久化、后台应用并确认，离线不显示已生效。
- 当前代码使用小时文件＋录音组（`RecordingSessionFiles`），不能复活已移除的 V2 分片传输。清理以文件为单位，长录音／闪念一致，文件时长不影响保留规则。
- 删除先持久化清理意图，再把音频移为隔离文件，原子保存列表后移除隔离文件；重启可继续已授权清理，保留独立的最近同步时间。
- watchOS 执行机会不保证准点；启动、前台、录音结束、保存回执／传输完成、运行中的周期检查执行。
- 旧协议忽略可选字段；未升级 Watch 不回报支持，不允许误报已生效。历史 SessionsV2 文件不纳入本次清理，避免删除无法重新确认的旧格式。

## 实施计划

采用 writing-plans / test-driven-development，当前已授权工作区中窄范围修改并保存任务前快照，不移动或覆盖其他任务。

- [x] 1. 共享策略／回报与 Watch 文件清理器：先写行为测试，验证 7／14 天边界、未确认保护、占用保护、重启恢复、保存失败回滚与无重复清理。
- [x] 2. 传输集成：iPhone 按配对保存请求；applicationContext 保留已有字段；Watch 原子保存策略后回报；清理触发与旧回执补确认。
- [x] 3. 设置与原型：显示日期选择、最近统计、清理估算、首次／缩短期限确认、待同步／已生效状态；中英文文案。
- [x] 4. 回归、iPhone／Watch 编译、可用模拟器界面验证；更新主要说明和索引，分别记录未验证的真机／发布时间边界。

## 验证记录

- 环境：macOS，Xcode 27.2（27B52）；iOS 26.3 模拟器 `WristNotes Transfer Test iPhone` 与 watchOS 26.2 配对模拟器。未卸载／清空原 App。
- 红灯：清理器空实现时 `test_watch_retention.sh` 报 `failed index persistence must surface`，证明异常恢复用例实际覆盖清理路径。
- `sh apps/wrist-notes/scripts/test_watch_retention.sh`：通过。覆盖 7 天准确边界、14 天保留、未确认／旧日期缺失／占用／未来时间保护、首次未启用不删除、真实文件清理、索引失败重启继续、意图持久化失败保留原音、组文件路径、策略乱序／非法值／跨设备／跨配对、设置持久化、元数据损坏关闭清理。
- `sh apps/wrist-notes/scripts/test_watch_sync.sh`：通过。既有配对、保存回执、失败状态和重试策略保持。
- `ruby apps/wrist-notes/Tests/ProjectSourceMembershipSmoke.rb`：通过。新文件两端 target membership 正确。
- `node --check apps/wrist-notes/prototype/daybook-hardware.js`：通过。
- 完整模拟器构建使用 **workspace** 和具体 destination：`xcodebuild -workspace apps/wrist-notes/WristNotes.xcworkspace -scheme WristNotes -configuration Debug -destination 'platform=iOS Simulator,id=332DEB86-4843-4543-8C73-4719B38DA704' -derivedDataPath /private/tmp/wiselife-retention-build CODE_SIGNING_ALLOWED=NO build`。通过；包含 iPhone、Watch 和 widget。前两次诊断构建分别因全局 `-sdk iphonesimulator` 误作用于 Watch widget、直接构建 project 缺 CocoaPods 链接而失败，改用实际 workspace 与 destination 后通过，未为此修改现有 widget 或 Pod 配置。
- CUA 实际界面：无 Watch 支持快照时提示更新并禁用启用按钮；Watch 启动后返回 0 文件／0 KB 统计。确认 7 天后通过真实模拟器 WatchConnectivity 显示“已生效”；点击 14 天显示“未保存”，确认前未改变已应用策略。
- 模拟器关机测试：系统临时把 Watch App 报告为未安装，因此不将此当作真实离线待同步验收。
- 真机安装、真机传输与跨 7／14 自然日后台执行尚未验证；未修改真机设置／数据，未提交或发布本功能。

- 最终版本在两端模拟器原位安装。Watch 关机再启动、iPhone 重新安装并启动后，读取两端沙盒元数据均为 7 天、修订 1，配置持久化一致；未包含任何录音文件删除（测试手表统计为 0）。
