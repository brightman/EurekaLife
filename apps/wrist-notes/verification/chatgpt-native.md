# WiseLife 原生 Sign in with ChatGPT

初始日期：2026-10-20；最近更新：2026-11-09。范围：`apps/wrist-notes` 的 iPhone 原生客户端。当前实现与验收见 [Apache-2.0 开源客户端接入](#opensource-plan-20261109)，下方历史阶段保留当时状态。

<a id="plan-usage-scope-20261109"></a>
## 当前产品范围：仅授权使用套餐调用 LLM（2026-11-09）

用户已明确：EurekaLife 需要 **ChatGPT plan usage**，用于 Ask AI、摘要等已接入的 LLM 任务；不需要把 ChatGPT 作为 EurekaLife 的注册或登录方式。

- 入口属于「设置 → AI 模型」，连接代表选择一个模型服务。App 的启动、本地记录、SQLite 历史和其他模型的使用，不依赖 ChatGPT 授权；不增加 EurekaLife 账号、登录页或产品登录会话。
- 用户仍需在 OpenAI 授权页面验证自己的 ChatGPT 身份，并同意使用套餐额度。这是服务授权，不是登录 EurekaLife。保留官方要求的 PKCE、state、nonce、ID-token 验证和授权范围检查，不因产品不需要登录而删除这些校验。
- 现有公开客户端流程按官方规范请求 `openid profile email offline_access resource.invoke chatgpt.tokens.use.direct`。身份信息仅用于区分模型服务连接和验证凭证归属；仅有身份授权不能进入推理就绪状态，必须检查套餐调用权限。
- 凭证按现有规则保存在本机 Keychain。连接不会导入 ChatGPT 对话、记忆或用户的 API Key；仅将当前任务获准的上下文发送给 OpenAI。
- 如走商业伙伴申请，需求须明确为「允许原生 iPhone／Mac App 使用用户的 ChatGPT 套餐调用 LLM」，不能用仅身份登录的批准替代。优先申请公共客户端与设备直连；回调、Token 交换和是否需要后端，按获批协议确定。

申请需求表述（草稿，未发送）：

> EurekaLife is a local-first native iPhone and Mac app. We seek approval for ChatGPT plan usage so users can authorize eligible LLM requests using their own ChatGPT plans. We do not need ChatGPT as an authentication provider for EurekaLife accounts. Our preferred integration is a native public client using PKCE, device-local credential storage, and direct Responses API calls without an app-embedded client secret or our own inference proxy. Please confirm the supported native callback, client registration, inference scopes, model/tool capabilities, and usage limits.

本次核对 `ChatGPTAPI`、`ChatGPTCredential.canUsePlan` 和 `ChatGPTAccountModel`：现有连接已独立于 EurekaLife 产品登录，并检查套餐调用权限，因此此范围澄清不需要新增产品登录代码。本次仅更新说明和索引；`WiseLifeChatGPTPublicClientEnabled` 仍为 `false`，没有完成真实账号授权／推理或取得商业接入批准。下文 2026-10-20 的验证结果为历史记录，不代表本次重新执行。

依据：[官方概览](https://developers.openai.com/siwc/quickstart)、[公开客户端授权与套餐权限验证](https://developers.openai.com/siwc/token-sharing-open-source/sign-in)。

<a id="opensource-plan-20261109"></a>
## Apache-2.0 开源客户端接入（2026-11-09）

用户已批准使用 Apache-2.0、实现官方套餐调用并进行真机验证。本节为当前实施记录；上方范围确认与下方 2026-10-20 验证属于历史阶段。

- 仓库增加标准 Apache-2.0、NOTICE、第三方许可索引和品牌规则。许可只覆盖有权授权的原创代码／文档；Ring SDK、模型和第三方素材保持原许可，没有代替厂商授予 SDK 再分发权限。
- 公开客户端开关已开启。入口仍位于 AI 模型设置，不建立 EurekaLife 登录会话。保留官方 Continue with ChatGPT 按钮、PKCE／state／nonce／ID-token 校验、本机 Keychain 和套餐授权检查。
- 新增「测试套餐连接」，只发送固定测试提示，不发送记录；仅在完整成功响应后显示成功。切换账号／模型或关闭设置会取消测试并丢弃旧结果。连接测试会消耗少量用户套餐额度。
- 真实接入资格与可用模型以官方授权及请求结果为准；不使用私有接口或其他 App 的凭证。开源许可不替代付费发行所需的商业接入条件。

### 当前验证记录

- 构建来源：基于 `102f115edabd0734d1822b31031c1e8c212c3dd1` 的本轮未提交改动；Xcode 27.2（27B52）；本地开发版本 1.0.3（16），未递增发行号。
- `pod install --no-repo-update`：成功；`verify_ble_pod.py`：79 项校验、3 个 XCFramework 完整。
- `test_chatgpt_loopback.sh`：解析器／真实本机 HTTP 监听及 iOS 浏览器适配器类型检查通过。
- `BuildFeaturesSmoke.rb`：4 tests、112 assertions，0 failure。
- `test_chatgpt_protocol.sh`、`test_chatgpt_accounts.sh`、`test_ask_ai_chatgpt.sh`、`test_ask_ai_drivers.sh`、`test_ai_settings.sh`：全部退出 0。使用合成凭证、网络 fixtures 和隔离 SQLite，覆盖 terminal SSE、工具结果配对、增量许可、引用、账号切换、历史压缩、实际模型标识与完整序列化预算。
- 完整模拟器构建、带签名的模拟器构建和 iPhone 签名构建均为 `BUILD SUCCEEDED`；真机包 `codesign --verify --deep --strict` 通过，原 Bundle ID／签名团队／Keychain 访问组保留。
- iOS 26.3.1 模拟器原位安装与界面验证：ChatGPT 入口开启，系统授权框取消后恢复可重试状态，关闭草稿后仍使用原自定义模型。首次安装无签名产物曾出现 Keychain `-34018`；换回含模拟器权限的签名构建后，原声音登记和已验证模型配置恢复可读，未清除或重新写入凭证。
- iPhone 16 Pro（iOS 27.2）原位安装成功，已启动并进入 AI 模型设置；观察到官方 `auth.openai.com` 登录页。安装前后 Documents 的 8 个文件元数据完全一致；这是该目录的元数据核对，不是全数据库逐字节审计。未卸载 App，原自定义模型配置仍显示。
- 用户已在真机完成官方登录与套餐授权；账号可用模型目录加载成功，测试模型为 GPT-6-Sol。原位更新与重启后连接仍可用，无需重新授权。
- 真机固定文本推理通过；随后通过真实 `AskAIChatGPTDriver` 完成一个仅返回固定字符串的 namespace 工具调用、`call_id` 结果回传与下一轮回答。端上阶段记录为 `catalog.available → text.completed → tool.received → tool.continuation.completed`。所有模型调用均使用合成内容，没有读取或外发录音、健康、账目等生活记录。
- 真机暴露并修复缺少 `Content-Type` 的 HTTP 200 SSE：原实现提前抛出 invalidResponse，修复后仍须通过完整 SSE、完成事件及结果结构校验。没有改为接收普通 JSON，也没有放宽显式非 SSE 媒体类型。
- Ask AI 页面使用真实生活资料的问答、真实配额耗尽、轮换刷新和撤销未测；完整 Runtime 的增量许可、引用和历史压缩由合成自动测试覆盖。未提交、推送或发布 TestFlight。
- 两次独立源码复核均无可操作的问题；后一次专门检查缺少媒体响应头的兼容修复与回归。复核不能替代真实服务验收。

### Agent 接入与验证命令

当前架构见 [Ask AI 会话编排](../docs/ask-ai-session-orchestration.md)。`AskAIChatGPTDriver` 使用官方 Responses namespace functions，保留完整显式历史和不透明 reasoning 输出；仅完成事件可发布结果。原文本调用仍保留，但遇到意外工具调用会拒绝，避免把半截文本作为成功。ChatGPT 历史压缩记录实际选择的 `chatGPTModel`，不会误用自定义模型字段。

```sh
sh apps/wrist-notes/scripts/test_chatgpt_protocol.sh
sh apps/wrist-notes/scripts/test_chatgpt_accounts.sh
sh apps/wrist-notes/scripts/test_ask_ai_chatgpt.sh
sh apps/wrist-notes/scripts/test_ask_ai_drivers.sh
sh apps/wrist-notes/scripts/test_ai_settings.sh
xcodebuild build -workspace apps/wrist-notes/WristNotes.xcworkspace \
  -scheme WristNotes -destination 'generic/platform=iOS Simulator'
# 真机：将 destination 换为本机已连接设备 id，使用自己的签名团队；原位安装。
```

新增回归曾捕获并修复：文本 API 静默忽略工具调用、ChatGPT 压缩元数据错用模型字段、中文输入未超过字节上限但已超保守 token 预算，以及有效 SSE 缺少 Content-Type 时被拒绝。传输或模型拒绝会保留明确失败，不借用 Codex 凭证、不自动转到其他模型。


### 真机 invalidResponse 排查（2026-11-09）

- 用户报告 `ChatGPT returned an invalid response. Try again.`，此时官方登录、套餐授权及可用模型列表已成功。
- 临时诊断只保存结构标签与数值，不保存请求／响应正文、账号、URL、code 或 token。设备记录显示 HTTP 200、`Content-Type` 缺失、7,643 字节；原代码在读取 SSE 前即拒绝。
- 新增无媒体头的完整流回归，先观察到 `ChatGPTError.invalidResponse`（退出 133），修复后协议测试退出 0。另验证无媒体头的半截流和非法数据仍拒绝，显式 `text/html` 即使包裹类似 SSE 内容也拒绝。
- 修复后的真机响应包含 `response.completed`、`status=completed`、assistant/output_text，完整读完并完成固定文本请求；工具续传同样完成。来源是官方 `api.openai.com/v1/responses`，不能据此判断响应头是在服务端还是网络链路中缺失。
- 临时自动探针与结构日志代码在最终交付源码中移除；随后重新通过协议／ChatGPT Agent 专项测试及模拟器／真机签名构建，最终真机包已原位安装并正常启动。正式连接测试仍只由用户点击触发。源码、许可证和文档已同步到主工作目录，原有 147 个未跟踪路径保留。


### 套餐说明与紧凑操作行（2026-11-09）

- 「ChatGPT 账号」下方说明改为「支持符合条件的 ChatGPT Plus / Pro 套餐，使用套餐额度在云端处理，无需 API Key。」中／英／日文同步维护。套餐范围来自当日核对的 [OpenAI 官方 Quickstart](https://developers.openai.com/siwc/quickstart)，实际账号仍通过现有授权及推理资格检查。
- 「刷新可用模型」与「测试套餐连接」改为同一行等宽按钮，保留加载指示、额度恢复重试、禁用条件和测试取消逻辑。
- 验证：`test_ai_settings.sh` 退出 0；三语字符串目录 JSON 校验通过；Xcode 27.2 模拟器／iPhone 签名构建通过。iPhone 16 Pro（iOS 27.2）原位安装后已查看套餐说明及并排按钮，账号连接与所选模型保持可见。本次仅调整文案和布局，没有重复发起推理测试；未卸载、推送或发布。

## 已实现的客户端功能（2026-10-20）

- AI 模型设置顺序：**Apple 本地模型 → Sign in with ChatGPT → 自定义模型**。Apple 本地仍为默认，失败后不会自动切换到云端。
- 系统浏览器授权、PKCE、state/nonce 和 RSA ID-token 验签；本机临时 HTTP 回调监听；取消、超时、断开和旧回调隔离。
- 账号注册映射、多账号选择、账号可用模型列表、套餐提示、额度错误与管理用量入口。ChatGPT 连接与当前 AI 配置分别保存，配置通过校验后才生效。
- 凭证保存在 `WhenUnlockedThisDeviceOnly` Keychain 中，禁止同步。刷新合并为同一任务，轮换后的凭证必须写入成功后才可使用；不会导入其他 App 的凭证。
- 安全存储失败时暂停账号使用并显示恢复入口。保留尚未写入成功的轮换凭证；读取失败时重试读取，不用空数据覆盖。断开失败标记确保重启或重试不会重新启用已要求删除的凭证。
- Ask AI 在发送前展示实际指令、问题与检索文本；手动摘要展示完整转写和目标服务。原始录音、图片文件和声音档案不会通过此接入上传。Ask AI 历史回答保留其生成时的 provider/model 标签。
- 摘要长文本分段处理；输入、账号或配置变化会使旧确认失效。失败不会自动转用其他服务。
- 中、英、日文设置文案。

## 历史：开启真实登录的前提（2026-10-20）

> 本节是当时尚未选择开源许可的状态；2026-11-09 已批准 Apache-2.0 并开启公开客户端，见上方当前实施记录。

当前 `Sources/iPhone/Info.plist` 中 `WiseLifeChatGPTPublicClientEnabled` 为 **false**。设置中展示接入未开通状态，不会发起真实授权。

OpenAI 的官方文档将此公开客户端流程用于符合要求的开源客户端及获准的私有客户端。WiseLife 的发布资格尚未确认。开发中已询问用户该产品属于哪种情况；尚未得到答复。此项是外部接入条件，客户端代码完成不能代替它。

确认发布方式满足官方资格，且 OpenAI 明确允许本应用使用本实现对应的公开客户端和 HTTP loopback 合约后，才能将上述构建配置设为 true。商业应用若收到独立 client ID、回调或其他集成合约，应按获批合约适配，不能仅打开这个开关。

用户拥有 ChatGPT 账号、订阅或安装了 ChatGPT App，本身不代表 WiseLife 获得了接入资格。该流程不需要填写 API Key 或 client secret；自定义模型的 API Key 配置仍独立保留。

## 历史验证记录（2026-10-20）

以下命令均由主任务在最终相关代码就绪后执行，退出码为 0。环境：Xcode 26.3（17C529），iPhone Simulator SDK 26.2；模拟器构建不代表物理设备测试。

| 验证 | 命令（仓库根目录） | 结果 |
| --- | --- | --- |
| OAuth / ID token / SSE | `sh apps/wrist-notes/scripts/test_chatgpt_protocol.sh` | 通过 |
| Loopback 真实 HTTP 与浏览器适配器编译 | `sh apps/wrist-notes/scripts/test_chatgpt_loopback.sh` | 通过 |
| 账号、安全存储与摘要确认 | `sh apps/wrist-notes/scripts/test_chatgpt_accounts.sh` | 通过 |
| 既有本地回归 | `sh apps/wrist-notes/scripts/test_local.sh` | 通过 |
| iPhone 模拟器构建 | 下方 `xcodebuild` 命令 | `BUILD SUCCEEDED` |
| 配置与静态检查 | `git diff --check -- apps/wrist-notes`；新文件空白、plist 开关、Ring 配置、恢复文案检查 | 通过 |

```sh
xcodebuild build -workspace apps/wrist-notes/WristNotes.xcworkspace \
  -scheme WristNotes -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

账号测试使用隔离 defaults、内存存储和假的网络服务，覆盖并发刷新/模型目录合并、轮换凭证落盘、断开取消、暂时失败与授权过期区别、首次套餐确认、读写失败恢复、同会话清理重试及重启清理。专项断言确认：刷新/模型目录等待期间确认失效时，推理调用次数为零；长摘要第一段后确认失效时，后续段落不发送。

完整本地回归还覆盖既有 AI 配置、转写资源、记录存储、Ask AI 精确预览和配置失效、对话持久化、权限变更、提醒、每日洞察及 SQLite / 语义检索。独立复核确认两个新增边界问题已修复。登录保存失败后释放授权状态的 iOS 路径已编译和源码复核，尚未以真实浏览器交互触发。

最后一次构建仅记录 AppIntents 元数据跳过提示（未链接 AppIntents.framework），没有编译错误。专项测试不使用真实授权或推理。

本机原始完整日志：`/tmp/wiselife-chatgpt-local-final.log`、`/tmp/wiselife-chatgpt-build-final.log`。这些临时日志可能在系统清理后消失；可用上述命令重新验证。

- [OAuth、身份验证与 Responses 核心](chatgpt-protocol.md)：本地 HTTP fixtures 与生成的 RSA 测试身份。
- [浏览器与回调监听](chatgpt-loopback.md)：真实 macOS loopback HTTP 测试与 iOS SDK 编译检查。

## 历史验证边界与后续真机检查（2026-10-20）

未进行真实 ChatGPT 登录、模型目录请求、推理、额度、刷新或撤销测试；未操作原生模拟器 UI。需要在具备接入资格的构建上，用物理 iPhone 验证系统授权页面期间的 HTTP 回调可达性，之后验证取消、后台切换、账号切换、首次套餐确认、模型获取、额度错误和断开。

真实 Ask AI/摘要测试应先使用用户同意的无敏感内容，核对确认文本与请求一致，检查切换配置、修改原文或断开后停止后续请求。测试记录不得保存密码、授权 URL、code、token 或 Keychain 内容。

既有笔记摘要仍只保存摘要文本，没有独立的历史 provider/model 字段；这与保留 provider 标签的 Ask AI 历史对话不同。本次不迁移共享笔记数据结构。

Ring SDK 由其他开发任务处理；本次沿用已有 `Config/BuildFeatures.json` 中的 `eurekaRing: false`，编译结果不代表 Ring 硬件验证。

## 官方合约

- [接入概览与资格](https://developers.openai.com/siwc/quickstart)
- [申请商业接入](https://developers.openai.com/siwc/request-client-id)
- [授权与回调](https://developers.openai.com/siwc/token-sharing-open-source/sign-in)
- [账号和会话](https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions)
- [Token 合约](https://developers.openai.com/siwc/token-sharing-open-source/token-reference)
- [模型和推理](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference)
- [错误与恢复](https://developers.openai.com/siwc/token-sharing-open-source/errors-and-recovery)

实现仅使用公开 `auth.openai.com` OAuth/discovery/JWKS 和 `api.openai.com/v1/models`、`/v1/responses`。Responses 设置 `store:false`、`stream:true`，仅完整成功的终止事件可成为结果；没有使用 ChatGPT 私有接口。
