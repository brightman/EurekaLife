# WiseLife 初始代码导入

类型：导入与验证记录 · 状态：current · 日期：2026-11-06 · 适用：EurekaLife 的 iPhone／Watch 与 Mac App。

## 来源与范围

- iPhone：Vessel 当前 `codex/pages-api-base` 工作区，HEAD `471cc4b3122d16f9142f6afd43d38f1bcb7f3295`，包含其现有未提交 App 功能修改及新增文件；不是只导出 HEAD。
- Ring：上述合并包含 `codex/vessel` 的 `f7616e456e3df8406bf80b6178972281c3413bc2`，保留 Native BLE SDK、完整文件处理与遗留分组删除保护。
- Mac：`dev-desktop` 工作区的 `e4c46e3220432a0ffd2bc475ea96341ef96dd6db`，包含当前 README 与交互原型更新。
- 保留 `apps/wrist-notes`、`apps/wiselife-mac`、`pods/br_flutter_plugin_ble` 的目录关系，纳入源码、测试、固定依赖、资源、构建脚本及相关设计文字。

导入独立初始提交，不携带 Vessel Git 历史、服务端或 Web console。排除用户录音、运行数据库、签名凭据、模型权重、构建包、设备截图和原始验证输出。历史验证 Markdown 中的设备标识已脱敏；未导入的附件链接标为源工作区资料。原工作区代码、Git 分支与未提交状态不因本次导入改变。

新增根目录开发入口与忽略规则；修正 iPhone README 的旧外部 Ring SDK 路径和默认关闭描述。原生业务源码与导入清单逐文件核对。

## 验证

环境：Apple silicon、Xcode 27.2（27B52）、Swift 6.4.2；命令从各 App 目录执行，`CODE_SIGNING_ALLOWED=NO` 的构建不代表签名发行或真机验收。

| 检查 | 本次结果 |
| --- | --- |
| 源码导入核对 | 1,055 个来源文件逐个核对 SHA-256 与模式；原生源码未改动，差异仅为文档入口、旧 Ring 描述、脱敏及未导入附件标记；源工作区未改写 |
| 提交范围 | 1,060 个文件，包含 80 个 Ring SDK 文件；最大文件约 21.2 MiB，无超过 GitHub 100 MiB 限制的文件 |
| `pod install` | 在新仓库目录安装仓库内 Native Pod 成功 |
| `ruby Tests/BuildFeaturesSmoke.rb` | 4 tests、92 assertions，0 failures |
| `ruby Tests/ProjectSourceMembershipSmoke.rb` | iPhone／Watch／共享模块／小组件源码成员通过 |
| `python3 scripts/verify_ble_pod.py` | 79 校验、3 个 XCFramework、真机与模拟器架构通过 |
| `sh scripts/test_notebook_people.sh` | 五字段联系人保存、清空、重新打开与来源保留通过 |
| `sh scripts/test_playback_audio_session.sh` | 播放会话与文件读取离开主线程、取消与交接回归通过 |
| `sh scripts/test_health_preparation.sh` | HealthKit 初始化与回调、主线程边界回归通过 |
| `sh scripts/test_watch_retention.sh` | 保留期限边界、升级、回执与崩溃恢复回归通过 |
| iPhone Xcode 构建 | `xcodebuild -workspace WristNotes.xcworkspace -scheme WristNotes -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` 成功，包含 Watch／小组件；0 warning、0 error |
| Mac Xcode 构建 | `xcodebuild -project WiseLifeMac.xcodeproj -scheme WiseLifeCompanion -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build` 在 MLX Metal shader 阶段停止：当前 Xcode 缺少 Metal Toolchain；不记为编译通过 |
| Mac 核心测试 | `swift test --build-system native --disable-automatic-resolution --jobs 4`：23 项，22 通过、1 项可选 Hugging Face 联网下载检查跳过、0 失败；真实 loopback HTTPS 配对／生成／撤销通过。编译保留 Swift 6.4 的弱引用捕获诊断及 native 构建引擎弃用提示，未把源码导入扩展为警告修复 |
| 公共仓库检查 | 未发现真实凭据模式；命中均为测试用虚构凭据。已排除签名／数据库／构建文件，历史真机标识已脱敏；保留第三方许可 |
| 文档与变更检查 | 文档文件链接通过；原生源码、脚本及新增入口的 whitespace 检查通过。首次导入保留上游 SDK 生成头文件空白与 Markdown 硬换行，未为了全量 whitespace 扫描改动 SDK 校验内容 |

Mac 的 Metal Toolchain 可按 Xcode 提示执行 `xcodebuild -downloadComponent MetalToolchain` 后重试完整构建。本次下载尝试较慢且未完成，已停止；不影响代码提交。新 SwiftPM 默认构建引擎也会编译 Metal，核心测试单独使用 `--build-system native`，不把它作为 GPU 推理验收。

详细临时日志保留在执行机 `/private/tmp/eurekalife-import-20261106/`：`ios-build.log`、`mac-build.log`、`mac-core-tests.log`、`pod-install.log`。本页保留可复查的命令与结果摘要，日志不公开提交。

## 限制

每日记录与片段音频到 Mac 的同步仍处于设计阶段；Mac 当前提供本地模型推理服务。此次不安装真机、不操作 Ring 硬件、不下载模型权重、不做 TestFlight／Developer ID 签名和公证。

第三方许可原样保留，尤其 Ring SDK 的专有许可；未为整个导入新增统一开源许可。

## 2026-11-06 iOS 模拟器安装

来源：EurekaLife `main` / `dd2904f`。目标：已启动的 `WiseLife Notebook Review`，iPhone 17 Pro、iOS 26.3。使用现有模拟器原位更新，未卸载 App、未清空或重建模拟器。

```sh
cd apps/wrist-notes
xcodebuild -workspace WristNotes.xcworkspace -scheme WristNotes \
  -configuration Debug -destination 'platform=iOS Simulator,name=WiseLife Notebook Review' \
  -derivedDataPath /private/tmp/eurekalife-simulator-20261106/build \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES build
```

- `BUILD SUCCEEDED`，0 error；有 1 条本机缺失 Metal Toolchain 目录的 linker search-path warning，不影响本次 iOS 模拟器构建。
- `codesign --verify --deep --strict` 通过；`Tests/test_keychain_entitlements.py` 确认模拟器 application identifier 和 Keychain access group 正确。
- `simctl install` 成功，版本 **1.0.3 (13)**；`simctl launch` 与后续进程状态确认运行，截图可见 WiseLife 首页。
- 安装器重新分配了数据容器 UUID；原 SQLite 数据库仍在，安装后、启动前核查的 10 个文件修改时间均早于安装，未进行用户数据清理。未查询或导出数据库内容。
- 当前 Xcode 使用 Device Hub；本机没有独立 Simulator.app。App 已在模拟器运行，但尝试自动显示 Device Hub 时返回 `cgWindowNotFound`，未确认桌面窗口可见。屏幕截图由 `simctl io screenshot` 核验。
- 本次不代表 Ring 真机、完整业务交互或 TestFlight 发布验收；未推送代码。

临时构建／安装结果与启动截图位于 `/private/tmp/eurekalife-simulator-20261106/`，不纳入 Git；本节保留命令、结果和环境限制。
