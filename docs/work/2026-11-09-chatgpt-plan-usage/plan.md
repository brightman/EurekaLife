# ChatGPT plan usage 与 Apache-2.0 实施计划

> 执行方式：使用 subagent-driven-development 实现独立运行时任务，并按 requesting-code-review 复核。用户于 2026-11-09 已批准 Apache-2.0、代码实现与真机验证；不再增加方案审批。

**目标：** EurekaLife 自有代码采用 Apache-2.0，原生设置可授权 ChatGPT 套餐调用 LLM，接入现有 Agent 工具循环和历史压缩，并在不删除数据的前提下安装验证。

**架构：** 保留现有 OAuth/PKCE、设备 Keychain、模型目录与 Responses 传输，新增 AskAIChatGPTDriver 适配 AskAIDriving。账号连接不建立 EurekaLife 登录会话；SQLite、权限、预算和工具执行仍由现有 Swift Runtime 管理。

**约束：** 不读真实凭证、不使用 Codex 缓存或私有 backend-api；不引入 API Key；不改 Bundle ID、签名团队、SQLite 格式或 Ring SDK。第三方许可独立保留。仅本机开发与设备安装，不推送、不发布 TestFlight。真实登录由用户在 OpenAI UI 完成。

## Task 1: Responses Agent 适配

Files: ChatGPTAPI.swift、ChatGPTProtocol.swift、ChatGPTAccountModel.swift、新增 AskAIChatGPTDriver.swift、AskAIRuntime.swift、对应 Tests 与 scripts。根代理负责 Xcode membership 与生成脚本；任务代理不得编辑工程或设置 UI。

- [x] 先运行现有 protocol/accounts 回归；在 fixture 中添加工具调用的 terminal completed、缺失终止、配额流错误、重复/未知调用与参数上限、工具结果续传、切换账号后阻止请求的失败用例。
- [x] 新增有类型的 Responses 请求/结果边界，不使基础 ChatGPTProtocol 依赖 AskAI 类型；保留 complete 文本接口和所有现有凭证安全检查。
- [x] 实现 AskAIChatGPTDriver: AskAIDriving。输入历史完整携带；使用官方 namespace function tools，工具结果由 call_id 关联；只在 response.completed 接受结果，不将半截文本作为成功。不使用 previous_response_id/background/max_output_tokens/max_tool_calls 等不支持参数；请求/响应大小、调用次数和耗时由端上限制。
- [x] 复用 ChatGPTAccountModel 的串行刷新、凭证持久化、账号代次取消、sourceIsCurrent；不要复制一套无状态 bearer 请求路径。
- [x] 在 AskAIRuntime 的 ChatGPT 分支和 compactIfNeeded 安装该驱动，复用 provenance、consent、工具白名单与预算。模型窗口未知时用已有保守预算；不声称获取了不存在的精确窗口。
- [x] scripts/test_chatgpt_protocol.sh、scripts/test_chatgpt_accounts.sh、新工具驱动回归与 Ask AI 驱动专项通过。测试使用合成凭证/数据和 URLProtocol，不调用真实服务。

## Task 2: 许可、授权入口与设备交付

Files: 根 LICENSE、NOTICE、THIRD_PARTY_NOTICES.md、TRADEMARKS.md、README.md；iPhone Info.plist、ChatGPTSettingsSection.swift、Localizable.xcstrings；工程 membership、生成脚本与现有文档索引。

- [x] LICENSE 保存官方 Apache-2.0 全文。说明仅适用于有权授权的原创代码/文档；第三方 SDK/模型/素材遵循原许可；品牌素材单列。列出已知 Proprietary Ring SDK，不能替其授权。
- [x] 开启官方公开客户端套餐授权配置。设置说明只连接模型服务、使用用户套餐；保留官方 Continue with ChatGPT 按钮名称与原有权限确认、配额/过期/取消状态。移除阻止开源客户端的商业资格误导文案。
- [x] 补充合成提示的连接测试入口（如现有模型测试不足），报告真实 Responses 完成而非仅模型目录可读；不发送生活记录。
- [x] 加入新文件的 Xcode source membership 并同步生成脚本，不重建整个工程。执行 pod install --no-repo-update、SDK 完整性检查与相关回归。
- [x] 完整模拟器构建和 UI 检查；iPhone 签名构建。设备可用后核对已装 Bundle ID/签名身份，原位安装，不卸载。
- [x] 用户完成官方授权，已验证模型目录、合成连接测试和 Ask AI 驱动的真实只读合成工具循环。真实生活资料的 Ask AI 页面问答、额度耗尽、刷新／撤销未验收，已在验证记录中注明。
- [x] 更新现有 chatgpt-native.md 和索引，区分代码/自动测试/模拟器/真机/发布状态。独立代码复核后把已验证改动安全同步回用户工作区，保留已有未跟踪文件和说明。

## 2026-11-09 当前进度

- Responses 适配、许可、设置入口和测试均已完成；独立源码复核无可操作问题。
- 专项自动测试、SDK 完整性、完整模拟器与 iPhone 签名构建通过。
- 模拟器原位安装，授权取消与 Keychain 读取恢复已验证。真机已原位安装，用户完成官方授权，模型目录、固定文本推理和合成工具循环通过。真实生活资料问答未测。
- 安装前后真机 Documents 的 8 项元数据一致；未卸载或清空应用。
- 真机发现并修复缺少 Content-Type 时提前拒绝有效 SSE 的问题，补充先失败后通过的回归及独立复核。临时诊断代码已移除。
- 已安全同步主工作目录并保留原未跟踪文件；本轮不提交或推送；详细证据见 [当前验收](../../../apps/wrist-notes/verification/chatgpt-native.md#opensource-plan-20261109)。

## 后续提交授权（2026-11-09）

用户随后明确要求将代码提交至 `https://github.com/brightman/EurekaLife`。本次提交包含上述实现、真机 SSE 兼容修复、Plus／Pro 套餐说明与并排设置按钮，以及测试、许可证和文档；目标为现有 `origin/main`。原阶段的“不推送”限制在此次用户授权后不再适用，TestFlight 发布不在本次范围内。本机截图、备份、构建产物和运行数据保持未提交。

提交前在主工作区重新运行 `test_chatgpt_protocol.sh`、`test_chatgpt_accounts.sh`、`test_ask_ai_chatgpt.sh`、`test_ask_ai_drivers.sh`、`test_ai_settings.sh`，均退出 0；`BuildFeaturesSmoke.rb` 为 4 tests／112 assertions，0 failure。相关源码与此前完成模拟器／真机构建及真机界面核验的工作树一致；此阶段未重新执行真实服务推理。待提交文件的凭据模式扫描、本地化 JSON、Shell 语法及 diff 空白检查通过。
