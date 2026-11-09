# WiseLife TestFlight 发布记录

类型：发布记录。首发日期：2026-10-19；更新：2026-11-08。

最新发布见 [EurekaLife 改名构建 16](#eurekalife-build16-20261108)：1.0.3（16）于 2026-11-08 17:41（UTC+8）上传成功，Apple 处理与出口合规完成，内部组显示“正在测试”，当前账号已获邀请；尚未验证真机安装。外部组的构建 15 仍在等待审核，Apple 暂不允许提交同版本的构建 16。新 App 身份见 [BIZCARD 独立新 App](#new-app-bizcard-20261108)，下方历史记录不代表当前线上状态。

**2026-11-05 签名勘误：** 构建 13 的发布包虽通过严格签名检查，但实际签名缺少 HealthKit 权限。此前“签名通过”不等于健康能力通过。后续发布必须采用[带签名归档与最终 IPA 校验](#healthkit-signing-20261105)；下方不签名归档命令仅保留为历史事实，不再作为发布流程。

## 当前结果

- 当前源码的 Release archive：`ARCHIVE SUCCEEDED`。
- App Store Connect 签名导出：`EXPORT SUCCEEDED`。
- iPhone 与内嵌 Watch 的签名均通过 `codesign --verify --deep --strict`，TeamIdentifier 为 `S56V68L4NP`。
- 两端显示名 WiseLife，版本 `1.0`，当前本地构建号 `3`。
- iPhone Bundle ID：`cloud.karama.wisenote`；Watch：`cloud.karama.wisenote.watchkitapp`。
- Watch 配置修复后已重新归档，`ARCHIVE SUCCEEDED`；修正版签名导出 `EXPORT SUCCEEDED`，iPhone/Watch 签名及内嵌 Watch 路径检查通过。
- **最新构建 3 上传成功**：2026-10-19 23:24:38（UTC+8），Apple 返回 `Upload succeeded` 和 `Uploaded package is processing`，Xcode 命令退出码为 0，末尾为 `EXPORT SUCCEEDED`。上传明细确认版本 `1.0 (3)`、Apple ID `6824527456`、`processingState=PROCESSING`。此前构建 1、2 分别于 22:04:53、22:18:52 上传成功；后续应使用包含新图标和隐私声明的构建 3。
- App Store Connect 显示名称现已保存为 **WiseLife: Apple Watch Recorder**。目前等待 TestFlight 构建处理完成，尚未验证可安装。
- 已创建内部组 `WiseLife Internal`（`6504f464-c2fe-43df-b210-eac3826978b0`），关闭自动分发。经用户明确指定两位受邀者后，当前账号已加入内部组；另一位不在 App Store Connect 团队用户列表，需要外部测试。尚无关联构建。
- Beta 描述、反馈邮箱和免登录使用说明已保存；尚未提交外部 Beta Review。
- **当前待办**：用户已恢复 Chrome 登录，已确认正确团队和 App；最新 TestFlight 页面仍显示 `No Builds`。上传日志确认最新构建 3 关联 Apple ID `6824527456` 并处于 `PROCESSING`，未取得失败原因。Mail 应用访问被自动审批拒绝，未绕过限制，已请用户提供 Apple 处理失败邮件（若有）。

### 构建 2 的补充声明

构建 1 上传后约十分钟尚未出现在 TestFlight。独立检查发现两端发布包缺少隐私清单，而实际使用了 required reason API；目前没有来自 Apple 的处理失败邮件或页面错误，不能认定清单缺失就是延迟原因。

已按 [Apple required reason API 要求](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) 补充两端 `PrivacyInfo.xcprivacy`，并加入 Xcode 资源及项目生成器：

- iPhone：`UserDefaults` / `CA92.1`，用于本 App 设置；`FileTimestamp` / `C617.1`，用于本 App 容器内文件元数据。
- Watch：`FileTimestamp` / `C617.1`，用于恢复本 App 容器内录音时间。
- 无广告跟踪。这里补充的是 required reason API 声明，没有将可选自定义云端 AI 描述为“绝不发送数据”。
- 两端构建号递增为 `2`。清单格式、项目资源/源码检查、Release 归档、Apple 上传校验全部通过。构建 2 签名导出成功，两端签名与清单入包检查通过。

## 首次失败原因与后续核对

Apple 返回：

```text
Error Domain=CDWebService Code=1085
No provider associated with App Store Connect user
error: exportArchive Error Downloading App Information
```

以上是上传早期的配置警告，并非最终失败原因。后续日志确认取得团队 `S56V68L4NP`，按 Bundle ID 查询 App 的请求返回 HTTP 200，但结果为 0 条；最终错误是：

```text
IDEDistribution.DistributionAppRecordProviderError.missingApp(bundleId: "cloud.karama.wisenote")
```

不能据此推断用户未登录，也不能推断 App 在所有团队中不存在。通过 CUA 控制原生 Chrome 成功访问用户已登录的 Apple Developer 与 App Store Connect，确认账号对应团队 `YONG FENG` / `S56V68L4NP`。网页中现已可访问匹配的 App 记录：

- Apple ID：`6824527456`
- Bundle ID：`cloud.karama.wisenote`
- SKU：`cloud.karama.wisenote`
- 主要语言：简体中文
- 原名称：`WiseNote`
- App Information：<https://appstoreconnect.apple.com/apps/6824527456/distribution/info>

复用该记录及已有归档重试上传，没有新建重复 App。首次日志的空结果与网页当前记录之间的变化原因尚未确认。

尝试将商店名称更改为 `WiseLife` 时，Apple 明确返回名称已被占用。随后按用户指定改为 **WiseLife recorded by watch**，页面显示 `Saved`，应用选择器同步显示该名称。设备内显示名仍为 `WiseLife`。

Xcode 界面曾被工具自动审批拒绝，未绕过该限制。浏览器专用连接不可用，但 CUA 的原生 Chrome 控制已成功；全程复用现有登录会话，没有读取或导出密码、私钥、Cookie 或会话令牌。

## Apple 包校验修复

第二次上传在 Apple 服务端校验时返回：

```text
Invalid Info.plist value. The value for the key 'WKBackgroundModes'
in bundle WiseNote.app/Watch/WristNotesWatch.app is invalid.
```

检查源码发现同时声明了 `UIBackgroundModes=audio` 与 `WKBackgroundModes=audio`。根据 [Apple 后台模式说明](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes) 与 [WKBackgroundModes 定义](https://developer.apple.com/documentation/bundleresources/information-property-list/wkbackgroundmodes)，音频后台模式使用 `UIBackgroundModes`，`WKBackgroundModes` 用于运动及特定延长运行会话，不接受 `audio`。

已仅删除 Watch Info.plist 中无效的 `WKBackgroundModes`，保留 `UIBackgroundModes=audio`。`plutil -lint`、重新归档、内嵌 Watch 包检查通过，修正版也已通过 Apple 实际上传校验。

## 当前机器上的发布产物

- 历史构建 2 Archive：`/private/tmp/wiselife-testflight-20261019/WiseLife-build2.xcarchive`。归档关闭签名，后续导出已完成 App Store Connect 签名。
- 历史构建 2 已签名 IPA：`/private/tmp/wiselife-testflight-20261019/export-build2/WiseNote.ipa`。
- 已解包验证：`/private/tmp/wiselife-testflight-20261019/signed-verification-build2/Payload/WiseNote.app`。
- 签名、构建号、隐私声明及 IPA SHA-256：`/private/tmp/wiselife-testflight-20261019/release-verification-build2.json`。
- `WiseLife-release.xcarchive` / `export-fixed/WiseNote.ipa` 是已上传的构建 1，缺少隐私清单，后续以构建 3 为准。
- 原 `WiseLife-unsigned.xcarchive` 与 `export/WiseNote.ipa` 含无效 Watch 配置，是失败诊断产物，不应继续分发。
- 导出配置：`/private/tmp/wiselife-testflight-20261019/ExportOptions.plist`。
- 上传配置：`/private/tmp/wiselife-testflight-20261019/UploadOptions.plist`。自动管理上传时的构建号；以 TestFlight 最终显示为准。
- 构建 2 日志：`/private/tmp/wiselife-testflight-archive-build2.log`、`/private/tmp/wiselife-testflight-export-build2.log`、`/private/tmp/wiselife-testflight-upload-build2.log`。
- 构建 1 修正版日志：`/private/tmp/wiselife-testflight-archive-fixed.log`、`/private/tmp/wiselife-testflight-export-fixed.log`、`/private/tmp/wiselife-testflight-upload-fixed.log`。
- 首次/第二次失败日志：`/private/tmp/wiselife-testflight-upload.log`、`/private/tmp/wiselife-testflight-upload-retry.log`。

这些是本机临时产物；后续源码有变化时需重新归档。

## 本次成功上传命令

已执行成功，记录供后续发布参考：

```sh
xcodebuild -exportArchive \
  -archivePath /private/tmp/wiselife-testflight-20261019/WiseLife-build2.xcarchive \
  -exportOptionsPlist /private/tmp/wiselife-testflight-20261019/UploadOptions.plist \
  -exportPath /private/tmp/wiselife-testflight-20261019/upload-build2 \
  -allowProvisioningUpdates
```

## 继续步骤

1. 访问 [TestFlight](https://appstoreconnect.apple.com/teams/489f53fc-82e7-4439-b492-2a62c4991028/apps/6824527456/testflight)，确认构建 3 的处理结果。若出现处理失败，按 Apple 实际错误修复；不要把上传成功当成处理成功。
2. 如有加密合规问卷，按当前源码使用的系统 HTTPS/Keychain/CryptoKit 与实际依赖填写，确认最终测试状态。
3. 将构建 3 加入 `WiseLife Internal`，确认用户已授权添加的当前账号收到安装邀请。
4. 创建外部测试组并添加用户指定的另一位测试者，补齐 Apple 实际要求的 Beta 审核资料后提交；不得将对方直接添加成具有后台权限的 App Store Connect 团队成员。
5. 记录外测审核/邀请状态；Apple 审核未完成时不可宣称外部测试者已能安装。

用户已授权邀请两位测试者，当前账号已添加到内部组，登录失效前页面状态仍为 `No Builds Available`；外部测试者尚未添加，尚未提交外部 Beta Review。网页会话现已恢复，仍待构建处理完成，**完整测试分发尚未完成**。


## 图标与名称更新（构建 3）

- 按用户指定，将 `design/brand/wiselife-icon-v1/wiselife-icon-1024.png` 原样替换 iPhone 和 Watch 的 `AppIcon.png`。
- 两端源资产 SHA-256：`62991a854c536236c1b5d7cbe6979a1eaa840ddf2693ae3230a75c622fea862c`；均为 1024 × 1024、不透明 RGB PNG，未预裁圆角。
- 两端构建号递增至 3；项目生成器同步构建号并显式配置 `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon`。
- 项目源码/资源成员检查、Info.plist 格式和两端图标哈希检查通过；构建 3 `ARCHIVE SUCCEEDED`、`EXPORT SUCCEEDED`，两端 `codesign --verify --deep --strict` 通过。已核对两端版本号、隐私清单和编译资源，目视确认归档内 iPhone 小尺寸图标，Watch 资产中包含 1024 px `AppIcon`。
- 用户原指定商店名称 `WiseLife,recorded by Apple Watch` 共 32 字符，超出页面显示的 30 字符限制。用户确认建议名称后，已改为 **WiseLife: Apple Watch Recorder**（30 字符），App Store Connect 明确显示 `Saved`。设备显示名仍为 `WiseLife`。

### 构建 3 产物

- Archive：`/private/tmp/wiselife-testflight-20261019/WiseLife-build3.xcarchive`。
- 签名 IPA：`/private/tmp/wiselife-testflight-20261019/export-build3/WiseNote.ipa`。
- IPA SHA-256：`3a013f62344ad2321913ff85da3b4baa55303bcb92187560aacbc468f6f7fbf3`。
- 校验记录：`/private/tmp/wiselife-testflight-20261019/release-verification-build3.json`。
- 日志：`/private/tmp/wiselife-testflight-{archive,export,upload}-build3.log`。
- 首次上传因网络错误失败：`RETRIEVE UPLOAD OPERATIONS (ASSET_UPLOAD)`，状态 `-19235`，`The HTTP request did not return a response`。已确认 App Store Connect 重新可达（HTTP 200），重试已成功，日志 `/private/tmp/wiselife-testflight-upload-build3-retry.log`。2026-10-19 23:24:38（UTC+8）返回 `Upload succeeded` / `EXPORT SUCCEEDED`，退出码 0；明细确认版本 `1.0 (3)` 和 `processingState=PROCESSING`。上传后刷新网页，应用选择器显示新名称，TestFlight 仍显示 `No Builds`，尚不能关联测试组或生成安装邀请。

<a id="build11-20261102"></a>

## 2026-11-02：1.0.2（11）

状态：已发布至 TestFlight。Apple 处理完成，构建 11 已关联内部与外部测试组，外部组明确显示“正在测试”。用户明确要求把当前最新版发布到 TestFlight，沿用现有 App、账号及测试组。

- App Store Connect 实时核对：Apple ID `6824527456`，团队 `YONG FENG`，最新已完成版本为 `1.0.2 (10)`。内部 `WiseLife Internal` 与外部 `WiseLife External Beta` 已存在，外部公开链接为 <https://testflight.apple.com/join/HjdCdWJu>。
- 八处构建配置统一递增至 `11`，包含 iPhone、Watch、iPhone Live Activity 和 Watch 快捷录音组件。版本号维持 `1.0.2`。
- 发布使用当前本地源码（基于 `99b203c`，含未提交改动）；没有执行 Git 提交／推送。源文件哈希清单、测试日志与归档放在私有目录 `/Users/karama/Documents/WiseLife-Reports/TestFlight/2026-11-02-build11/`，不将用户资料或凭据写入仓库。
- 包含每日回顾按界面语言生成、模型窗口预算、进度及截止时间、自然表达与发言人规则，以及此前首次引导、Ask AI、录音处理等当前代码。回顾中文真机生成已验证；最后的日期／归属修正未重新生成验收，英文／日文仅有 stub 回归。详见[回顾验证](../verification/2026-10-23-persisted-timeline-recap-refresh.md#recap-budget-20261102)。
- 发布前检查通过：项目源码成员、版本元信息、首次引导、按住语音输入、Ask AI runtime 与 driver、Watch 同步、小时录音、内容分段 v2。`test_watch_sync.sh` 与 `test_hourly_recording.sh` 先因测试脚本遗漏当前数据库依赖编译失败；补齐 `AudioProcessing`／`AudioWindowPlanner`，并移除小时测试未使用的 `NoteRepository` 后重跑通过。没有修改对应生产代码或测试断言。
- 归档环境：Xcode 27.2，`WristNotes.xcworkspace` / `WristNotes` / Release / generic iOS；依赖使用已有锁定下载，`IPHONEOS_DEPLOYMENT_TARGET=26.0` 兼容当前 Pods。归档先不签名，导出由 Xcode 自动管理 App Store 签名。
- 真机屏幕共享已关闭，避免影响后续麦克风使用。本次没有卸载或重置设备数据。
- `archive.log` 为 `ARCHIVE SUCCEEDED`、退出码 0。核验四个包均为 `1.0.2 (11)`，iPhone 最低 iOS 26.0、Watch 最低 watchOS 10.0，主包及 Watch 隐私清单存在。构建期间生产源码和配置哈希没有变化（只修正上述两个测试脚本）。
- 20:19 第一次 `-exportArchive` 退出码 70，`EXPORT FAILED`。报错 `DVTDeveloperAccountCredentialsError Code=0`、`missing Xcode-Username`、`exportArchive No Accounts`，并无法找到团队的 `iOS Distribution` 签名。Chrome 会话已由用户恢复，但 Xcode 账户独立；已打开该账户的 Sign In，等待用户重新登录后重试同一归档。没有修改／撤销证书，没有导出凭据。
- 用户重新登录 Xcode 后，同一归档签名导出成功（`export-retry.log`，退出码 0，`EXPORT SUCCEEDED`）。IPA 为 `export/WiseLife.ipa`，15,499,369 字节，SHA-256 `9a16ad142983fe4c2475091974789c31dace7713482512af4bfd6055cb79fb5f`。解包后四个组件均通过 `codesign --verify --deep --strict`，均为团队 `S56V68L4NP` 的发布签名、`1.0.2 (11)`。
- 上传复用同一归档和自动签名，`manageAppVersionAndBuildNumber=false` 保留构建号 11。上传日志为私有目录 `upload.log`；尚未将上传请求本身记作 Apple 处理或测试可用。
- 20:28:50（UTC+8）Apple 返回 `Uploaded package is processing`、`Upload succeeded`、`Uploaded WristNotes`，最终 `EXPORT SUCCEEDED`，退出码 0。此时已上传但尚不能宣称构建 11 可安装。
- 后续 App Store Connect 页面确认：构建 UUID `93cae6fa-e266-48ed-b3b3-f7f6c9648d55`，上传状态“完成”，构建状态“正在测试”，关联 `WiseLife Internal` 与 `WiseLife External Beta`，邀请数 5。现场页面操作后已完成分组／提交，没有重复提交或覆盖已填写的测试说明。
- 独立打开外部组的“构建版本”页，`1.0.2 (11)` 明确为“正在测试”，90 天后过期；公开入口 <https://testflight.apple.com/join/HjdCdWJu> 正常展示 WiseLife 与“在 TestFlight 中查看”。发布状态已核验，尚未验证测试员实际下载并运行构建 11。


<a id="build12-20261102"></a>

## 2026-11-02：1.0.3（12）

状态：1.0.3（12）已上传并完成 Apple 处理，关联内部与外部测试组；2026-11-03 App Store Connect 显示“正在等待审核”。外部测试仍待 Apple Beta App Review，不能宣称已经可安装。

- iPhone、Watch、iPhone Live Activity 与 Watch 快捷录音四个组件，Debug／Release 共八处配置统一为 `1.0.3 (12)`。Bundle ID、签名团队和已有内部／外部测试组沿用构建 11。
- 发布当前工作区源码，包含未提交修改；没有执行 Git 提交／推送。源码哈希与发布日志保存于 `/Users/karama/Documents/WiseLife-Reports/TestFlight/2026-11-02-build12/`，以实际产物和哈希识别版本。
- 包含 [Ask AI 历史 SQLite 直接展示与列表卡顿修复](../verification/2026-10-23-persisted-timeline-recap-refresh.md#ask-ui-lag-20261102)。对应开发包已原位安装，用户反馈“明显改善”；升级核对原录音、旧历史和每日回顾保留。也包含当前工作区的内容片段真实录制时间与 Face ID 关闭后启动界面修复。
- 本轮检查通过，全部退出 0：`ruby apps/wrist-notes/Tests/ProjectSourceMembershipSmoke.rb`、`test_release_info.sh`、`test_conversations.sh`、`test_daily_recaps.sh`、`test_content_refresh.sh`、`test_recording_playback_clock.sh`、`test_onboarding.sh`（shell 脚本均由 `sh apps/wrist-notes/scripts/<name>` 执行）。自定义 AI 服务回归为 stub，不宣称重新完成所有真实模型与 Watch 验收。
- 归档配置：Xcode 27.2（27B52）、`WristNotes.xcworkspace` / `WristNotes` / Release / generic iOS，`IPHONEOS_DEPLOYMENT_TARGET=26.0`、`CODE_SIGNING_ALLOWED=NO`；随后导出使用现有团队自动发布签名。`manageAppVersionAndBuildNumber=false` 保留构建号 12。
- 发布不卸载或重置手机；没有上传用户数据库／录音。TestFlight 客户端的安装及 Watch 端实际运行需另行验收。
- 回退：保留既有 `1.0.2 (11)` 测试构建；如新版本出现问题，可停止分发构建 12，测试员从 TestFlight 的已有构建选择 11。本轮未改变 SQLite schema，不要求清理数据。

- `archive.log`：`ARCHIVE SUCCEEDED`，退出 0。归档中四个组件均为 `1.0.3 (12)`；主包 `BuiltAt=2026-11-02T15:54:00Z`。iPhone 最低 iOS 26.0，Watch 最低 watchOS 10.0；主包与 Watch 的隐私清单存在；构建前后生产源码／配置哈希一致。

- 签名导出 `EXPORT SUCCEEDED`，退出 0。IPA 15,523,817 字节，SHA-256 `6884ed290ea881e5ac9fdcba23ce1636ab8e1fc696528d95111f66d6a001d852`；四组件严格 codesign 校验通过，均为团队 `S56V68L4NP` 的 Apple Distribution 签名。
- 初次把 IPA 解包到 Documents 后，目录出现 `com.apple.FinderInfo`，严格签名检查报告 `resource fork, Finder information, or similar detritus not allowed`。上传命令已先启动，随即主动中止（退出 130），日志仅到分发准备阶段，没有上传成功记录。随后将同一 IPA 解包到 `/private/tmp`，四组件验证全部通过；IPA 中无 AppleDouble 条目，没有修改原包或生产代码。复用同一归档重试上传，日志为 `upload-retry.log`。

- 2026-11-02 23:59:18（UTC+8）Apple 返回 `Uploaded package is processing`、`Upload succeeded`、`Uploaded WristNotes`，命令结束 `EXPORT SUCCEEDED`、退出 0。上传接受已核验；测试可用性继续以 App Store Connect 状态为准。

- 2026-11-03 App Store Connect 实时确认：上传状态“完成”，构建 UUID `3a3539c8-7055-49e8-91e5-1ec0fa3b74ed`；元数据页显示 `1.0.3 (12)`、Bundle ID `cloud.karama.wisenote`、二进制“已验证”。
- 初次继续时测试说明与现有组关联尚未完成：操作期间电脑界面失联，Chrome 与 Finder 均返回 `Computer Use server error -10005: cgWindowNotFound`，浏览器连接宿主也不可用；已请求用户解锁 Mac 并打开 Chrome。没有提取 Cookie／令牌或绕过系统锁。中英测试说明已保存到发布目录 `what-to-test-{zh,en}.txt`，恢复后继续同一构建；不应重复上传。


### 2026-11-03：恢复连接后的分发核验

- 用户要求继续后恢复 Chrome。构建页已有测试说明“界面卡顿优化”；保留现场填写内容，没有以预备中英文草稿覆盖。随后界面检测到用户操作，重新读取状态后继续核验，没有重复上传／提交。
- App Store Connect 的 iOS 构建列表明确显示 `1.0.3` 下的构建 `12`，状态“正在等待审核”，90 天后过期；已关联 `WiseLife Internal` 与 `WiseLife External Beta`，邀请数 7。对应构建仍为 `3a3539c8-7055-49e8-91e5-1ec0fa3b74ed`。
- 分组及提交审核已在现场操作后完成；外部测试需等待 Apple Beta App Review。尝试独立读取内部组时遇到元素失效及随后 `cgWindowNotFound`，因此没有将内部组独立可用性、测试说明刷新后的持久化结果或测试员下载安装写成已验证。
- 本轮没有改生产源码、重建／重复上传、重置设备或操作旧构建；发布状态摘要已更新到同一私有发布目录的 `release-status.json`。


<a id="build13-20261104"></a>

## 2026-11-04：1.0.3（13）

状态：1.0.3（13）已上传成功，Apple 正在处理；测试组可用性尚未确认。

- 来源为当前本地 WiseLife 工作区，含四类记事本，以及构建 12 已有的 Ask AI 性能／录制时间／Face ID 修复和后续每日回顾修复。它包含未提交改动，不等同于只包含记事本的 GitHub 提交 `3b9d0e5`。发布源码以私有目录 `/Users/karama/Documents/WiseLife-Reports/TestFlight/2026-11-04-build13/source-hashes.json` 标识；发布日志与说明保存在同一目录。
- 保持版本 `1.0.3`，iPhone、Watch、Live Activity、Watch 快捷录音的 Debug／Release 共八处构建号递增为 `13`；Bundle ID 与签名团队保持。
- 发布前项目成员检查发现生成脚本遗漏 12 个 Notebook 文件；当前 Xcode 工程已包含它们。已补齐 `generate_project.rb` 的显式列表，未重新生成工程；成员检查复验通过。
- 记事本包含增量 SQLite 表／列，原记录保留；不删除数据库进行升级或回退。本轮不卸载或重置手机。回退可保留旧 TestFlight 构建，但旧版本不能使用新分类及草稿能力，真实用户数据回退兼容仍需设备验证。
- 自动测试、Release 归档、签名导出、上传接受、Apple 处理、测试组可用性分别核验；原生交互及真实模型效果沿用记事本验证边界。

- 发布前验证已通过，全部退出 0：项目源码成员检查、`test_release_info.sh`；记事本专项 `test_notebook_ledger.sh`、`test_notebook_sources.sh`、`test_notebook_people.sh`、`test_notebook_places.sh`；既有 `test_flash_capture.sh`、`test_places.sh`、`test_speaker_contacts.sh`；回归 `test_conversations.sh`、`test_daily_recaps.sh`、`test_content_refresh.sh`、`test_recording_playback_clock.sh`、`test_onboarding.sh`、`test_health.sh`。共 13 个功能／回归脚本及 2 项发布检查。
- App Store Connect 网页登录恢复后，实时确认现有最新构建为 `1.0.3 (12)`，状态“正在测试”，已关联原内部／外部组；本次使用尚未占用的构建号 13。

- `archive.log`：`ARCHIVE SUCCEEDED`、退出 0。四个组件均为 `1.0.3 (13)`，主包 `BuiltAt=2026-11-04T00:27:35Z`；iPhone 最低 iOS 26.0、Watch 最低 watchOS 10.0，主包和 Watch 的隐私清单存在。455 项生产源码／配置哈希与归档前一致。

- `export.log`：`EXPORT SUCCEEDED`、退出 0。IPA 16,039,847 字节，SHA-256 `891773a5363ccdfa0ecef220510c1c6c22276b1e4f358aadd09826451d455d21`。在 `/private/tmp` 独立解包，四组件均通过 `codesign --verify --deep --strict`，团队 `S56V68L4NP`，Apple Distribution 签名，`get-task-allow=false`；无 AppleDouble 条目。

- 2026-11-04 08:31:51（UTC+8）上传接受确认：`Uploaded package is processing`、`Upload succeeded`、`Uploaded WristNotes`，命令末尾 `EXPORT SUCCEEDED`、退出 0。未重复上传；继续核对 App Store Connect 处理与测试组状态。

- 上传后 App Store Connect 页面已出现 `1.0.3 (13)`，创建时间 Nov 4, 2026 8:31 AM，当前显示“正在处理”；此时尚无可分发构建链接。

- 本轮最后核验：构建 13 仍显示“正在处理”，未出现可操作链接。内部组的添加构建选择器也尚无 13，已关闭选择器并保留原组；未错误关联旧构建、未修改测试员。中英文测试说明已准备在发布目录 `what-to-test-{zh,en}.txt`，待处理完成后保存到构建 13 并关联现有组。当前仅能确认上传成功，不能宣称新构建已可安装；无需重新上传。

<a id="healthkit-signing-20261105"></a>

## 2026-11-05：修复发布签名遗漏 HealthKit 权限

状态：已定位构建 13 的发布 IPA 权限缺失，修复后的签名归档及最终发布 IPA 验证通过；本轮未发布。依据：[HealthKit 当前规则与证据](2026-10-20-health-background.md#signing-20261105)。

用户提供的截图报告 `Missing com.apple.developer.healthkit entitlement.`。保留 IPA 的严格签名校验通过、profile 允许健康读取及后台投递，但 App 签名本身缺失两项权限；归档日志确认 `CODE_SIGNING_ALLOWED=NO`。这属于此前发布验收遗漏，不能归因于用户未授权健康读取。

新增 `scripts/package_release.sh`：签名归档 → 验证归档能力 → 自动发布签名导出 → 验证最终 IPA。新增 `scripts/verify_healthkit_signing.py` 检查实际签名及 profile，原错误 IPA 退出 1，保留的正确开发包通过；不改 App 的健康数据权限范围或用户数据。

本次验证保留版本／构建号 1.0.3（13），仅验证打包流程，不覆盖已发布包；后续上传修复版本需递增构建号。未上传、未安装或清除手机数据，截图设备的实际安装渠道／构建号尚待确认。

- 实际执行 `sh apps/wrist-notes/scripts/package_release.sh /private/tmp/wiselife-healthkit-20261105/package /private/tmp/wiselife-testflight-build13 /private/tmp/wiselife-notebook-build/SourcePackages`，退出 0，`ARCHIVE SUCCEEDED`、`EXPORT SUCCEEDED`。
- 归档 App：严格签名通过，两项 HealthKit entitlement 均为 true，profile 同样允许；导出 IPA：再次严格签名通过，两项权限均为 true，`get-task-allow=false`。
- 验证 IPA 16,295,402 字节，SHA-256 `56fcf214cba42179bf831918e8aa4e954c57b0922cd2e1d80f0f80779365461a`。该包是后续 Xcode warning 修复之前的工作区快照，仅用于证明签名流程修复，不作为已发布或 warning 修复后产物。

同日完成 Xcode warning 与播放／健康初始化修复后的最终签名产物：`/private/tmp/wiselife-warnings-20261105/release-accepted/export/WiseLife.ipa`，16,340,596 字节，SHA-256 `397b3757c3623269c3b09c36f4fc5b5cef6b776b5ef492271c1a778f616132cf`。归档及导出均成功，完整日志 0 warning、0 error，归档与 IPA 的两项实际健康权限和 profile 检查均通过，IPA 为 distribution 签名。仍为 1.0.3（13）的本地验证包，未上传；模拟器与真机验收限制见[完整修复记录](work/2026-11-05-xcode-warnings/README.md)。

<a id="build14-20261106"></a>

## 2026-11-06：1.0.3（14）

状态：1.0.3（14）已上传成功，App Store Connect 显示“正在处理”。Apple 处理、测试组分发与测试员安装分别核验，上传成功不代表已可安装。

- 发布当前 EurekaLife 工作区，基于 `dd2904f` 且包含未提交修改；没有执行 Git 提交或推送。iPhone、Watch、Live Activity、Watch 快捷录音组件的八处配置统一为 `1.0.3 (14)`。App、Bundle ID 与签名团队沿用，Mac Companion 不在本次 TestFlight 包内。
- 包含 Ring 录音同步、重复导入修复、AI 模型设置遵循、5 小时录音转码恢复和完整性检查、口语日程识别与已知录制时区、空结果手动重试及闪念实际处理状态显示；另包含 HealthKit 发布签名修复。范围与设备验收边界见 [Ring 记录](2026-10-20-ring-build-switch.md)。
- 发布前实时确认 App Store Connect 最高构建为 `1.0.3 (13)`，已“正在测试”；沿用 `WiseLife Internal` 和 `WiseLife External Beta`，不修改测试员成员。
- 本轮发布检查：`pod install --no-repo-update`、`BuildFeaturesSmoke.rb`（4 项／112 断言）、`ProjectSourceMembershipSmoke.rb`、`verify_ble_pod.py`（79 哈希／3 XCFrameworks）、`test_release_info.sh` 和差异格式检查通过。之前同日 Ring 集成 59 通过／2 项缺模型跳过、Action 集成 9 通过、闪念与音频处理回归通过；这些是对应修复的验证，不替代 TestFlight 实机验收。
- 首次归档失败是 `package_release.sh` 全局 `CODE_SIGNING_ALLOWED=YES` 覆盖了 CocoaPods 资源包的禁用签名设置，使隐私／许可资源 target 要求独立团队。移除全局覆盖，保留 App／扩展自动签名和资源包各自设置，未改为无签名归档。修正后 `ARCHIVE SUCCEEDED`、`EXPORT SUCCEEDED`，脚本退出 0。
- Xcode 27.2 (27B52)，Release／generic iOS，最低 iOS 26.0。归档有 Metal toolchain 搜索路径及预编译 Ring SDK 原构建缓存路径缺失警告，不声称零 warning；SDK 完整性、编译及最终签名通过。SDK 二进制未改动。
- 归档和最终 IPA 的实际 App 签名均含 `com.apple.developer.healthkit=true` 和 `com.apple.developer.healthkit.background-delivery=true`，profile 同样允许；IPA 四组件均通过严格签名验证且 `get-task-allow=false`，版本均为 `1.0.3 (14)`。iPhone／Watch／Ring 隐私清单和 Opus 许可均入包，无运行数据库、录音、密钥或 AppleDouble 文件。
- 私有产物目录：`/Users/karama/Documents/WiseLife-Reports/TestFlight/2026-11-06-build14/`。最终归档 `package-signed/WiseLife.xcarchive`，IPA `package-signed/export/WiseLife.ipa`，18,113,413 字节，SHA-256 `e52f913bd6de72589acbfe4ee25d8467e282b2c7ca72fc1aeae147b4f58a06b4`。构建时间 `2026-11-06T07:40:06Z`。522 项源码／配置／SDK 哈希在构建前后保持一致，见 `source-hashes.json`；产物检查见 `release-verification.json`。
- 上传复用同一签名归档，`UploadOptions.plist` 使用 `destination=upload`、`manageAppVersionAndBuildNumber=false`，日志 `upload.log`。首个失败打包日志与产物单独保留，未覆盖最终包。
- 15:44:31（UTC+8）Apple 返回 `Uploaded package is processing`、`Upload succeeded`、`Uploaded WristNotes`、`EXPORT SUCCEEDED`，命令退出 0；网页随后显示 `1.0.3 (14)`，创建时间 Nov 6, 2026 3:44 PM，状态“正在处理”。
- 上传后约 10 分钟复核仍为“正在处理”，无处理失败提示。内部组添加构建选择器只有 13／12，14 尚不可选；已关闭选择器，未误加旧版本或修改测试员。中英文测试说明保存在私有目录 `what-to-test-{zh,en}.txt`，尚未保存到 Apple。待处理完成后需保存测试说明、关联现有内部／外部组，并核验是否需 Beta App Review；当前不能宣称构建 14 已可安装，无需重复上传。
- 未卸载、重置或覆盖设备数据；本次未在真机安装。真实 5 小时 BLE、锁屏恢复、所选模型效果及 TestFlight 升级后的健康读取仍需设备验收。
- 如需撤回测试分发，先从构建 14 的测试组移除或在 App Store Connect 停止该构建测试；不要通过卸载 App 回退。构建 13 已知缺少 HealthKit 签名权限，不应作为健康功能回滚方案；修复版本须使用更高构建号重新发布。

<a id="build15-20261108"></a>

## 2026-11-08：切换 BIZCARD LIMITED，1.0.3（15）签名受阻

状态：这次保留原 Bundle ID 的尝试失败，未导出或上传。用户随后明确选择创建独立新 App，当前进度见[后续记录](#new-app-bizcard-20261108)。

- iPhone、Watch、Live Activity、Watch 快捷录音组件的 Debug／Release 共八处团队改为 `2W27U66VBQ`，构建号由 14 递增为 15，版本保留 `1.0.3`。全部原 Bundle ID 保留，未修改应用数据、Keychain 范围或设备安装；项目生成器会读取并保留现有团队和版本，无需重建项目文件。
- 当前生产源码／依赖与构建 14 相同，本轮仅改变项目团队和构建号；保留既有未提交代码、官网工作区和旧发布产物。`pod install --no-repo-update`、`BuildFeaturesSmoke.rb`（4 项／112 断言）、`ProjectSourceMembershipSmoke.rb`、`verify_ble_pod.py`（79 哈希／3 XCFrameworks）、`test_release_info.sh` 均通过。
- 使用 Xcode 27.2 的签名归档脚本实际请求 Apple provisioning。Apple 对 `cloud.karama.wisenote`、`.watchkitapp`、`.recording-activity`、`.watchkitapp.recording-widget` 四个标识均返回 `Failed Registering Bundle Identifier ... cannot be registered to your development team because it is not available`，随后报告匹配的 provisioning profile 不存在；`ARCHIVE FAILED`，退出码 65。这是新团队无法取得现有 App 标识的问题，不能靠更换本机签名证书解决。
- 私有诊断目录 `/Users/karama/Documents/WiseLife-Reports/TestFlight/2026-11-08-build15-bizcard/` 保存原项目配置备份、`pods.log`、`package.log`、`source-hashes.json`、`release-status.json` 及待发布测试说明。归档尝试前后源码哈希一致。本轮没有有效的构建 15 发布 IPA。
- Computer Use 原生连接返回 `Sky Computer Use native pipe startup failed`，浏览器连接返回 `The browser access host is unavailable`；无法实时核验 App Store Connect 的 App 转移状态和账号权限。未读取或导出账号密码／会话凭据，也未使用其他 UI 自动化绕过。
- 当时提出 App 转移或创建新 App 两种选择；用户随后说明原 App 仅提交 TestFlight、无真实用户，并明确选择新建 App。Apple 的[转移条件](https://developer.apple.com/help/app-store-connect/transfer-an-app/app-transfer-criteria/)要求至少一个版本已在 App Store 发布，因此按用户描述原 App 不符合转移条件。
- 配置回退仅需将本轮八处团队／构建号恢复为原值，可对照私有备份；不得覆盖此前未提交修改。原构建 14 没有被撤回、替换或重复上传，其当前 Apple 分发状态本轮未核验。

<a id="new-app-bizcard-20261108"></a>

## 2026-11-08：BIZCARD 独立新 App，1.0.3（15）

状态：新标识注册、签名归档、App Store IPA 导出及实际权限验证通过。首次上传因缺少 App 记录失败；随后已在 BIZCARD LIMITED 下创建独立 App，并于 2026-11-08 13:16:42（UTC+8）上传成功。Apple 处理及出口合规设置已完成，内部组显示“正在测试”，当前账号已获邀请；未提交外部 Beta Review，未验证实际安装。

- 团队为 BIZCARD LIMITED（`2W27U66VBQ`），指定发布账号 `mr.brightman@gmail.com`。iPhone 使用 `cloud.karama.wiselife`，Watch 使用 `.watchkitapp`，iPhone 扩展使用 `.recording-activity`，Watch 扩展使用 `.watchkitapp.recording-widget`；版本／构建号统一为 `1.0.3 (15)`。
- 同步更新 Watch companion 标识、项目生成器、预览／UI 测试标识、Keychain service 的默认命名、日志命名和最终 IPA 的身份校验。保留工程路径、数据库与音频格式、原 App 数据和历史发布文件。
- 新 Watch App 的快捷录音 URL scheme 为 `wiselife-bizcard-watch`，注册声明、共享路由及测试一致，避免与旧 App 的 `wiselife-watch` 冲突。App 图标和显示名仍为 WiseLife。
- 新身份配置的 `pod install --no-repo-update`、构建开关 4 项／112 断言、源码成员、Watch 安装配置及项目生成、Watch 组件资源／嵌入检查、SDK 79 哈希／3 XCFrameworks、版本元信息均通过。快捷录音启动 12 场景和按钮交互 8 场景通过。首次检查命令在仓库根目录引用 `Tests/` 报路径不存在，切到 App 目录后完整重跑通过。
- 私有产物仍放在 `2026-11-08-build15-bizcard/`；新归档输出单独使用 `package-new-app/`、日志 `package-new-app.log`、源码清单 `source-hashes-new-app.json`，不覆盖使用旧标识的失败证据。新 App 记录字段准备在 `new-app-record.json`。
- `package-new-app.log` 为 `ARCHIVE SUCCEEDED`、`EXPORT SUCCEEDED`，打包脚本退出 0。归档及最终 IPA 四个组件的实际签名和 profile 均属于 `2W27U66VBQ`，版本均为 `1.0.3 (15)`；最终包为 distribution 签名，`get-task-allow=false`。iPhone 的 Keychain group 为 `2W27U66VBQ.cloud.karama.wiselife`，实际 HealthKit／background-delivery 两项权限及 profile 检查通过。
- 最终 IPA：`package-new-app/export/WiseLife.ipa`，18,119,272 字节，SHA-256 `dedb66c0a608f9010b9c5264cbf44c52308e20ad24b7079aaed9ccaa6546fc52`；构建时间 `2026-11-08T04:52:17Z`。522 项源码清单在归档前后保持一致。Watch companion／独立 URL scheme、三份隐私清单、Opus 许可资源、无运行数据库／录音／密钥文件检查通过，详见私有 `archive-new-app-verification.json` 与 `release-verification-new-app.json`。
- 随后使用同一归档、明确 `teamID=2W27U66VBQ`、`destination=upload`、`manageAppVersionAndBuildNumber=false` 实际尝试上传。`upload-new-app.log` 返回 `App record with bundle identifier "cloud.karama.wiselife" not found on App Store Connect. Create an app record on App Store Connect, or distribute the app from Xcode, and then try again.`，`EXPORT FAILED`，退出码 70；未进入上传成功状态。此时剩余阻塞是商店 App 记录，而非签名或 Bundle ID。
- 电脑控制连接仍不可用，已请求用户恢复连接或在 BIZCARD LIMITED 下创建记录：iOS、建议名称 `WiseLife: Voice & Notes`、简体中文、Bundle ID／SKU 均为 `cloud.karama.wiselife`；未要求提供密码或私钥。记录创建后重试同一签名归档，无需再次编译，再分别核验 Apple 处理、新测试组及 Beta App Review。
- 新 App 的录音／SQLite／Keychain 与旧 App 隔离，模型资源和授权需要在新 App 内准备；未卸载、清理或迁移用户设备。Mac Companion 不在本次发布范围。

### 同日继续：新 App 创建与上传成功

- 重启终端 Codex 后，Computer Use 原生桌面通道恢复。浏览器扩展通道仍不可用，通过同一 CUA 的 Chrome 原生窗口完成操作；没有读取或导出密码、Cookie、会话令牌。
- 在 BIZCARD LIMITED 下创建 **WiseLife: Voice & Notes**，Apple ID **6832169777**，主要语言简体中文，Bundle ID／SKU 均为 `cloud.karama.wiselife`。采用有限访问权限，保留组织既有角色与当前账号。新 App 的 [TestFlight 页面](https://appstoreconnect.apple.com/apps/6832169777/testflight) 与旧 App 独立。
- 复用 `package-new-app/WiseLife.xcarchive` 重试上传，`upload-new-app-retry.log` 返回 `Upload succeeded`、`Uploaded package is processing` 和 `EXPORT SUCCEEDED`，命令退出 0；`IDEDistribution.critical.log` 为 0 字节。上传接受时间为 `2026-11-08T05:16:42Z`。私有目录保存完整 distribution logs 和 `upload-new-app-retry-result.json`，原失败证据保留。
- 新建内部组 `WiseLife Internal`（`13701ea9-7e03-49a2-b59a-3ffceeab9444`），关闭自动分发；仅添加当前账号 `mr.brightman@gmail.com`。新 App 的中文 Beta 描述、反馈邮箱、免登录审核备注已保存，未创建外部组或邀请其他人。
- 页面显示测试员“无可用构建版本”，内部组尚无关联构建。这是处理阶段的中间状态，后续已完成处理、测试要点与内部组关联，见下方最终核验。
- App Store Connect 有更新付费协议的提示，但未阻止本次创建与上传；没有代替账户持有人接受协议。今后如提交环节要求接受协议，应另行处理。

### 最终核验：内部 TestFlight 已开放

- Apple 处理完成后，构建 15 首先显示“缺少出口合规证明”。检查当前源码使用的系统 URLSession／Security／CryptoKit，以及三个 Ring XCFramework 的公开接口与反混淆符号，未发现独立加密算法实现；据此选择“不属于上述的任意一种算法”并保存。本次通过 App Store Connect 完成声明，没有为跳过问卷而重编译或修改已上传包。
- 构建 ID 为 `6210fdb9-c7ec-4e8c-a907-f4e6f7f3702d`；中文测试要点已保存，包含 Ring 去重、模型选择、闪念日程、5 小时长录音边界、HealthKit 与独立新 App 数据隔离说明。
- 构建 1.0.3（15）已关联 `WiseLife Internal`。页面确认 **1 名测试员、1 个构建版本**；构建状态为 **“正在测试”**，90 天后过期；当前账号 `mr.brightman@gmail.com` 为 **“已邀请”**。
- 发布范围为内部 TestFlight；未提交外部 Beta Review、未创建公开邀请链接、未提交正式 App Store 审核。用户需通过新邀请接受测试；旧 App 的公开链接不能用于新 App。
- 上传前 IPA SHA-256 与准备记录一致，上传后 522 项源码哈希未变化，`git diff --check` 通过。没有安装或卸载真机 App，实际设备安装及 Ring／Watch 验收仍需另行执行。


<a id="eurekalife-build16-20261108"></a>
## 2026-11-08：EurekaLife 品牌统一 · 1.0.3（16）

用户要求 App 整体改名为 EurekaLife。iPhone、Watch、Mac 的产品名、界面、快捷指令、录音组件、权限说明、中英文资源与当前原型同步更新；Mac 产物名为 `EurekaLife.app`。工程目录、target、Swift 模块、Bundle ID、URL scheme、Bonjour、数据库和 Keychain 标识保持原值，继续更新 BIZCARD LIMITED 下 Apple ID `6832169777` 的同一新 App。不会卸载应用或迁移／清空数据。

本次构建基于含前序功能修改的未提交工作区，版本 1.0.3（16）。私有备份、日志与产物位于仓库外 `WiseLife-Reports/TestFlight/2026-11-08-build16-eurekalife/`。

- App Store Connect 名称已保存为 `EurekaLife`；Beta 说明、审核备注以及 `EurekaLife Internal`／`EurekaLife external` 组名已同步。保留原组成员、访问范围、手动分发与构建 15 的外部审核。
- 静态与逻辑检查：本地化 JSON／plist 有效；与改名前快照比较，签名、Bundle ID、URL 与存储身份未改变。工程开关 4 项测试／112 个断言、源文件归属、Watch 安装／组件配置、Ring SDK 79 个校验值通过；Watch 同步、快捷录音、状态、ChatGPT 协议、版本元数据、首次使用持久化测试通过。
- Mac 测试：`sh scripts/test.sh` 共 23 项，1 项需显式联网的下载检查按默认设置跳过，0 失败。未下载模型权重，未启动真实用户的 LAN 服务。
- 4 张现有首次使用图片只更新品牌标题区域，并改称使用示意图；不是本次新截取的模拟器验收图。
- iPhone／Watch 最终签名归档 `package-final/EurekaLife.xcarchive` 成功，四个 bundle 均为 1.0.3（16）；HealthKit／后台投递权限保留，快捷指令类型身份与构建 15 相同。实际录音组件、Watch 平台／版本／URL／资源检查通过，最终 `Assets.car` 已包含更新后的引导示意图。
- Mac Release 编译通过，`dist/EurekaLife-macOS.zip` 为 12,646,730 字节，SHA-256 `aa2ec6b8fc750e8879cc3cdc79130eadf4699f8ffc49ec68aa1f1aa99bedab25`。ZIP 解压后的深度签名检查通过；此为本机 ad-hoc 包，未做 Developer ID 公证。首次打包失败来自 Finder／File Provider 扩展属性，脚本现用 `ditto --norsrc --noextattr` 排除附加元数据，应用内容与签名不改变。
- 14:32 命令行导出返回 `No Accounts`／找不到 iOS Distribution 证书，同时 Mac 锁屏。解锁恢复电脑控制后，CLI 仍报账号不可用；已通过 Xcode 中现有 `mr.brightman@gmail.com`／BIZCARD LIMITED 会话与 Cloud Managed Apple Distribution 证书完成最终 IPA 导出，无需更改账号、证书或归档。
- 最终 IPA：`package-final/EurekaLife-build16-export/EurekaLife.ipa`，18,117,505 字节，SHA-256 `2345926963e499fac2b13620b9328fda3ab1b6baa757a81fc91e239f036545c2`。`verify_healthkit_signing.py --require-distribution` 通过，HealthKit／后台投递权限及发布 profile 一致；版本保留 1.0.3（16）。17:41（UTC+8）经 Xcode Organizer 上传，界面显示 `EurekaLife 1.0.3 (16) uploaded`。Apple 处理完成，出口合规按与构建 15 相同的实际加密实现填写并保存。
- TestFlight 构建 ID `cff560a9-5a1d-42b1-abcf-b86b9ad02601`。测试说明已保存，加入现有 `EurekaLife Internal` 后，组内构建 16 显示“正在测试”、90 天后过期；该组为 1 位测试员／2 个构建，`mr.brightman@gmail.com` 状态为“已邀请”。构建 15 保留，可在需要时作为先前版本选择；没有使旧构建过期。
- 外部组保留构建 15 的“正在等待审核”状态。Apple 页面明确同一版本只能同时提交一个 Beta Review 构建，暂不允许将 16 添加到外部组；未撤销或替换原审核，未新建公开链接或扩大测试员范围。
- 未安装／卸载真机 App，未进行本次真机录音、Watch、Ring 交互验收；未提交或推送 Git。

### 2026-11-08：App Store 英语（美国）分发资料准备

用户要求在 Chrome 填写审核所需的英文分发信息。本次仅保存资料，未提交正式 App Review，也未发布 App。

- App Store 版本草稿从 `1.0` 更新为 `1.0.3`，关联已上传的构建 `16`；发布方式设为“手动发布此版本”。
- 英语（美国）名称 `EurekaLife`，副标题 `Voice Notes & Daily Journal`；推广文本、产品描述、关键词、版权、现有审核联系人及英文审核说明已保存。审核说明覆盖免登录、iPhone 核心测试步骤、可选 Watch／Ring、模型下载及外部 AI 的使用条件。主要语言仍为简体中文，未移除其他本地化。
- 类别为“效率／生活”。年龄问卷根据 App 的实际功能填写，健康或保健主题为“是”；系统显示主要地区 `9+`，越南 `12+`，其他区域以 Apple 分级为准。
- 用户指定官网 `https://wiselife.karama.cloud/`。技术支持与营销 URL 使用此地址；英语（美国）的隐私政策 URL 为 `https://wiselife.karama.cloud/privacy/`。HTTP 200 与 Chrome 页面访问均已验证，重新打开分发页面确认英文内容、网址、构建和手动发布模式持久保存。
- 尚未完成：iPhone／iPad／Watch 商店截图（当前均为空）、初始定价与销售地区、内容版权声明及 App 隐私数据收集申报。可选外部 AI 会传输授权文本，其数据保留与披露口径需核实，未直接申报为“不收集数据”。原主要语言的产品描述等仍为空。
- 官网仍使用 WiseLife 品牌，隐私政策仍为中文且包含旧权限说明；正式提交前需与 EurekaLife 的实际行为一致。App 中原 `wiselife.cloud` 链接未在本次网页资料任务中修改，当前域名解析失败。
- 未修改 TestFlight 测试组、测试员或构建 15 的外部审核；未上传截图、修改协议或重编译 App。
