---
id: life-ledgers-native
type: plan
status: current
updated: 2026-11-13
scope: iPhone flash categories and shared notebook
---
# 闪念分类与共享记事本原生实现

依据：已确认的 [首页分类](../../../prototype/flash-assets-design.md#flash-home-categories-20261113)、[共享记事本](../../../prototype/settings-design.md#notebook-shared-20261113) 与地点·人物原型。

## Global Constraints

- Preserve the dirty worktree, existing assets/actions, financial precision, source recordings, databases, credentials, and model files. No commits, release, uninstall or reset are authorized by this task.
- Use the same DaybookDatabase SQLite store for home and notebook. Additive, idempotent migrations; no duplicated financial/idea rows. Keep source capture time distinct from occurrence date.
- At most eight enabled home categories including money and other. No ninth All chip. Secondary chips use intrinsic widths, wrap, and never exceed primary font size. Clicking again clears selection; changing date clears selection.
- New installations start with money and other only; do not seed prototype fixtures in production. Existing ideas remain in notebook and other unless an idea category is explicitly created.
- LLM proposes facts, not executable schema/SQL. New categories require confirmation. Optional historical inclusion is unselected initially and transactional. Matching future records auto-file; old records remain other until selected. Preserve exact quotes and source permissions. No new remote endpoint.
- Candidate thresholds: last 30 days, at least three distinct facts across two known occurrence dates, compatible units and mean confidence >=0.75; explicit tracking request may suggest immediately but is not an observed event. Defer for seven days plus new evidence; dismiss durable; edits/deletes recompute eligibility. Preserve source-independent decisions.
- Quantity and unit conversions are bounded fixed-point values; increments, period totals, measurements and unknown dates must not be mixed into misleading sums. Financial statistics stay integer minor units per currency.
- Settings notebook defaults to ledgers, contains ledgers and ideas only; separate Places·People defaults to places and reuses existing detail/edit views.
- Validate migration/rules/parser with synthetic local stores, build the complete simulator target, inspect simulator UI without resetting data. Report native build, simulator interaction, physical device acceptance separately.

## Task 1: Generic ledger storage and rules

Implement Sources/iPhone/LifeLedger.swift and LifeLedgerRepository.swift plus Tests/LifeLedgerSmoke.swift and scripts/test_life_ledger.sh. Own only those paths. Follow test-first workflow. Send the final public API to root early before finishing implementation.

Data definitions: categories with stable String IDs/conceptKey/name/measure/unit/aggregation/version; builtin IDs money and other; records with UUID, optional categoryID, conceptKey/conceptName, measure, text, optional ActionSource, capture timestamp, optional occurredOn yyyy-MM-dd, optional decimal-string value + unit, increment/periodTotal/measurement mode, confidence, isTrackingRequest, requiresLocalAI, revoked, revision. Candidate includes concept, name, measure/unit, evidence records and explicit-request flag. A snapshot supports categories, records and suggestions. Keep types Codable/Sendable where appropriate.

Repository API: init(database:); categories(); records(categoryID:from:through:limit:offset:includeRevoked:); save(record) optimistic revision; importRecords(records) dedup without overwriting manual edits; hasResults(sourceID); createCategory(name:conceptKey:measure:unit:aggregation:including:) capped and atomic; candidates(now:); deferCandidate/concept and dismissCandidate; stats(categoryID:from:through:) deterministic SQLite-backed aggregates with coverage/missing and date groups. Repository must share nested transactions with FlashCaptureRepository. Keep dependencies limited to Foundation, DaybookDatabase, ActionItem, FlashCapture types. Candidate evidence should include only legitimate user facts and compatible dimensions; parser validates evidence separately. No dynamic code or SQL from model output.

Test existing database reopening, defaults and cap, dedup/retry/revoke protection, optional backfill preserving IDs, conversion and incompatible units, period totals excluded from increments, missing/unknown dates, daily stats, independent candidates and repeated extraction, defer/dismiss/reopen, revisions. Unknown concept entries stay other. Unit and aggregation enum names/API can be adapted; report exact declarations for callers.

## Task 2: Extraction and shared observable model

Extend existing FlashExtraction/FlashCaptureParser for bounded general record facts and tracking requests with exact contiguous evidence. Keep explicit action protections and monetary parsing. Unknown kinds degrade to other records without failing a valid mixed flash. Do not count questions, negations, plans, other people's experiences as completed facts. Pass bounded saved category catalog to existing provider prompt. Commit general records in same transaction as legacy assets/actions/batch. Shared FlashCaptureModel exposes categories, records and candidates read from SQLite off main actor; notify all consumers after mutation. Preserve old-history behavior and external-model consent. Update existing Swift smoke compile lists for new dependencies. Add parser/integration tests.

## Task 3: Native notebook and category views

Create reusable SwiftUI ledger overview, list/history and daily statistics (today/week/month/all), detail/edit/delete/manual add, category creation and suggestion evidence confirmation with optional history. Reuse finance and ideas UI. Settings notebook has two tabs only, default ledgers. Add combined places/people container default places. Home compact wrapping chips and at most one current-day suggestion share model. Keep labels and current app styling; accessibility identifiers for verification. Need title, text, date, quantity and unit editing, lossless source navigation, no fictional audio for text records.

## Task 4: Home integration and Ask AI

Wire DaybookView settings/sheets, secondary selection/reset, per-result filtering/counts for selected day and shared record edits. Include manual and source-deleted persisted results in home without inventing audio. Finance capture timestamps remain source timestamps. Wire generic ledger into bounded read-only Ask AI notebook tools with SQLite stats and source/remote restrictions. Preserve previous action/idea/finance tools.

## Task 5: Validation and docs

Add new source membership through xcodeproj narrowly and update generator lists, pod install without repo update, run relevant SDK checks and smoke tests, full Xcode simulator build. Use synthetic isolated UI fixture if needed; preserve current app data. Review implementation against prototype/constraints, fix findings. Update existing schema, storage, prompts and indexes; record exact build/test/UI scope and remaining real-device/model-quality verification.

## Progress

- 2026-11-13: approved prototype inspected; plan written before native implementation. Existing branch codex/card-ring-integration-20261111 with unrelated dirty changes retained.


## 实现状态与验收（2026-11-13）

已完成本轮原生功能：

- 首页二级分类最多八项（记账／其他固定），紧凑文字自动换行、单日计数与筛选、再次点击清除、换日期清除；手动条目及来源已删的结果可见，不虚构音频。新候选在今日闪念及记事本共享展示。
- 设置保留记事本，默认账本总览，灵感沿用原列表、编辑、合并；地点·人物独立入口，默认地点。生活账本按范围查询历史、SQLite 精确统计、手动新增、编辑、删除；原收支按币种／月份查看。
- 通用记录与候选持久保存；新增类型须确认，历史逐条勾选默认关闭，暂缓与拒绝持久保存；后续匹配记录自动归档。外部模型不接触仅本机记录或由其产生的分类定义。
- Ask AI 通过已有权限读取通用账本目录／明细／统计，版本变化使旧引用与记忆失效；小窗口按相关性装载工具，未启用账本权限时不额外占用其提示预算。

### 自动检查

以下命令已通过（macOS 本地 Swift 合成数据库，不访问真实用户录音／模型权重）：

- `sh scripts/test_life_ledger.sh`：迁移与重开、八类上限、事务历史收录、精度／单位、周期总量分离、缺失日期、乐观锁、去重／撤销、候选冷却／拒绝及仅本机数据。
- `sh scripts/test_life_ledger_integration.sh`：混合闪念、未知类型兜底、编辑后重试、来源分组、单位／数值／日期证据和截断否定；不把数值格式合法等同于原话事实。
- `sh scripts/test_flash_capture.sh`、`sh scripts/test_notebook_ledger.sh`、`sh scripts/test_notebook_sources.sh`：旧财务精度、灵感、行动、迁移与来源回归。
- `sh scripts/test_ask_ai_notebook.sh`、`sh scripts/test_ask_ai_read_tools.sh`、`sh scripts/test_ask_ai_runtime.sh`、`sh scripts/test_ask_ai_drivers.sh`：通用账本、旧领域、精确聚合、权限、传递隐私、过期引用、真实 Runtime 的合成驱动、窗口与压缩回归。
- `pod install --no-repo-update`、BLE／Ring SDK 校验、`ProjectSourceMembershipSmoke.rb` 通过；新增源文件只增量加入现有 pbxproj 和生成器。

审查曾发现并修正：模型数值仅验证格式、分类名称隐私遗漏、未知日期覆盖计数的引用隐私，以及截断否定导致错误追踪建议。最终复审通过。Ask AI 新指令最初无条件增加导致小窗口历史回归失败，改为仅在账本权限启用时装载，原有压缩回归重新通过。

### 编译与模拟器

完整 Debug `WristNotes` 工作区 iOS Simulator 构建通过。最终命令：

```sh
xcodebuild -workspace WristNotes.xcworkspace -scheme WristNotes -configuration Debug \
  -destination 'platform=iOS Simulator,id=6C057128-02FC-430D-B0DA-DC4238A7F3EC' \
  -derivedDataPath /tmp/eurekalife-life-ledgers-build -jobs 3 ONLY_ACTIVE_ARCH=YES build
```

独立 iOS 26.3 / iPhone 17 Pro 模拟器 `EurekaLife Ledger Verification` 使用全新数据容器和明确标注的合成记录，保留现有模拟器／真机用户数据。XCTest 启动实际安装的 EurekaLife App（辅助 UIHost 只承载测试 runner，不替代产品界面）。电脑控制工具启动失败，改用 XCTest 和 simctl 截图完成检查。

实际 UI 验收通过：七类首页 → 饮水建议 → 三条历史开关默认关闭 → 勾选确认第八类 → 首页饮水两条 → 记事本全部 850 ml／今天 550 ml → 手动新增 100 ml 后当天 650 ml → 删除后 550 ml → 地点／人物切换 → 终止并重启后全部 850 ml 仍保留。共一个端到端场景，0 失败，约 69 秒。第一次 UI 检查发现父容器覆盖子标签 accessibility identifier，修复后重跑通过；初次失败记录不冒充通过。截图检查了主页标签自动换行和记事本总览／统计。

本机复查证据：`/Users/karama/Library/Logs/EurekaLife/2026-11-13-life-ledgers/`，含测试日志、七张合成界面截图、`second.xcresult` 及临时 UI harness／fixture。媒体与 xcresult 不加入 Git。

### 验证边界

- 编译、合成 SQL／解析器测试和实际模拟器交互已验证；真机 ASR→真实 LLM→新分类建议的准确率、硬件新录音链路未在本轮验收。
- 支持的数量／日期表达采用保守核对，无法确认的字段保留待补充，不保证理解任意自然语言日期、英文拼写数字或所有单位。
- 类型排序／重命名／归档、任意字段配置、恢复拒绝建议专门页面留在后续产品范围；本轮已实现已批准首页与共享记事本流程。
- 未安装到用户真机、未提交／推送、未发布 TestFlight。保留其他未提交工作及全部原有用户数据。
