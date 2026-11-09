# EurekaLife

EurekaLife 的 iPhone／Apple Watch App 与 Mac Companion 源码仓库。

| 工程 | 用途 | 入口 |
| --- | --- | --- |
| iPhone / Apple Watch | 录音、时间轴、Ask AI、记事本、Watch 同步及 Eureka Ring 硬件接入 | [apps/wrist-notes](apps/wrist-notes/README.md) |
| Mac Companion | Apple silicon 上的本地 MLX 模型管理、配对与局域网文字推理服务 | [apps/wiselife-mac](apps/wiselife-mac/README.md) |
| Native Ring SDK | iPhone 工程使用的仓库内 BLE / Recorder / Opus 二进制依赖 | [pods](pods/README.md) |

## 构建

需要 macOS、完整 Xcode 和 Command Line Tools；iPhone 工程还需 Ruby 与 CocoaPods。依赖版本保存在 `Podfile.lock` 和 Swift `Package.resolved` 中。首次构建需联网获取 Swift 包。

```sh
# iPhone / Watch
cd apps/wrist-notes
pod install
open WristNotes.xcworkspace
```

`WristNotes` scheme 包含 iPhone、Watch 与小组件。Ring 已开启，直接使用本仓库的 `pods/br_flutter_plugin_ble`，无需相邻 SDK 源码。当前 iPhone deployment target 为 iOS 26；真机运行需要在 Xcode 中配置自己的签名团队。

```sh
# Mac（从仓库根目录开始）
cd apps/wiselife-mac
open WiseLifeMac.xcodeproj
# 本机 ad-hoc 签名打包
sh scripts/build.sh
```

Mac Companion 要求 Apple silicon 和 macOS 15+；MLX Metal shaders 需要 Xcode 构建。模型按用户操作下载，模型权重不随源码提交。

## 验证与文档

- [文档入口](docs/INDEX.md)
- [初次导入范围与验证](docs/repository-import.md)
- [iPhone 技术文档](apps/wrist-notes/docs/INDEX.md)
- [iPhone→Mac 每日记录同步设计](apps/wrist-notes/docs/iphone-mac-sync.md)：当前仍为设计，不能视作已实现；现有 Mac 服务主要提供模型推理。

此仓库在 2026-11-06 导入两端的当前工作区代码，包含 iPhone 的 Eureka Ring 合并和本地功能修改。导入为独立初始提交，不包含 Vessel 服务端、Web console 或原仓库历史。历史验证文字保留当时结论，未随代码导入的截图、设备报告及本地文件会明确标注。

第三方代码、模型和 SDK 保留各自声明与许可；仓库公开不改变这些许可。相关说明位于 `apps/wrist-notes/Vendor`、各 App 资源与 `pods/br_flutter_plugin_ble/Licenses`。

## 开源许可

EurekaLife 自有源码与项目文档采用 [Apache License 2.0](LICENSE)，另有明确声明的文件除外。版权归各贡献者所有；品牌素材见 [品牌使用规则](TRADEMARKS.md)。第三方 SDK、开源依赖和模型保持原许可，详见 [第三方许可索引](THIRD_PARTY_NOTICES.md) 与 [NOTICE](NOTICE)。

仓库包含独立许可的 Ring SDK，不代表这些二进制也采用 Apache-2.0。只开发 iPhone／Apple Watch 时，可以关闭 `Config/BuildFeatures.json` 中的 Ring 开关并重新运行 `pod install --no-repo-update`，使用不依赖该 SDK 的构建。

## ChatGPT 套餐模型服务

在 iPhone 的「设置 → AI 模型」中选择 ChatGPT，使用官方 Continue with ChatGPT 完成套餐授权，选择账号可用模型并测试连接。连接只用于 LLM 请求，不创建 EurekaLife 登录账号；授权凭证留在本机 Keychain。测试连接只发送固定测试消息，实际任务按现有发送范围规则使用文字。账号资格、可用模型和额度以 OpenAI 返回结果为准。

当前实现与设备验证边界见 [ChatGPT 接入记录](apps/wrist-notes/verification/chatgpt-native.md#opensource-plan-20261109)。
