# 前端组件库使用指南与 UI 规范

本文件用于业务项目的页面开发、组件选型、样式接入和交互验收。首次接入时，由 Agent 完成下方规则落地；后续页面任务通过业务项目的 Agent 规则文件自动引用本指南。默认沿用业务项目的官方 Mantine，优先复制团队示例中的 Mantine + Tailwind 代码。

本文包含执行步骤、组件目录、取码方式和必要规范，可单独作为入口。组件实现仍需从可访问的组件库预览或源码取得，本文不携带全部组件代码。没有拿到实际示例时，不能凭组件名或几条设计数值重写后声称与团队标准一致。

## 首次接入：写入业务 Agent 规则

负责接入的 Agent 先定位业务项目根目录，读取现有协作约定并检查工作区，再执行以下操作：

1. 将本指南保存到业务项目的 `docs/ui-spec.md`；已在此位置时直接复用。
2. 找到业务项目已有的 Agent 规则文件，通常为根 `AGENTS.md`；项目约定使用 `agent.md` 时沿用该文件，没有规则文件时创建根 `AGENTS.md`。
3. 将下面的「S Works UI」规则段合并进去；已有同名或等价规则时更新原段，不重复追加、不覆盖其他业务约定。指南存放路径不同时，按规则文件位置修正链接。
4. 保存后检查引用路径和重复规则，再继续用户的页面任务。仅要求接入规范时，完成规则落地和文档检查即可。

```markdown
## S Works UI

- 新增、修改或审查页面前，先阅读并执行 [S Works UI 业务指南](docs/ui-spec.md)，按组件目录、布局、颜色、间距与交互规范实施。
- 沿用本项目的 Mantine、Tailwind、包管理器和路由，使用官方 Mantine + Tailwind 源码移植团队组件。
- 先复用本项目已有团队组件，再取得准确的团队示例，带齐当前例的辅助文件、图标和资源；保留事件、ref、状态及键盘行为。
- 视觉优先使用 Mantine 公开 props 和 Style Props，剩余差异通过公开 classNames 插槽传入静态 Tailwind；不重复管理同一视觉属性。
- 完成代码接入、项目检查、服务启动和适用的浏览器验证，给出实际URL、执行结果与未验证项；不能只提交方案或命令。
- 组件代码无法取得时，明确缺少的材料，继续不依赖它的工作；不凭名称重写团队样式，不静默降级为底座效果。
- 团队规范缺少所需组件、变体或样式定义时，不自行新增或替代实现；邮件联系 `sen.wang@brgroup.com`，或打开钉钉中“王森”的会话，说明缺失组件和业务场景，取得处理方案后再实现。
```

规则写入后，后续页面需求直接按上述约定执行，不再要求用户为每个页面复制一段额外提示词。

## 依赖与接入方式

| 项目 | 基线 |
| --- | --- |
| Mantine | 官方 `@mantine/core`、`@mantine/hooks` 8.3.18；扩展包与底座版本一致。 |
| React | 示例使用 React / React DOM 19.1.1；业务项目核对实际版本，不擅自升级或降级。 |
| Tailwind | 主线 4.3.3；源码移植兼容验证基线 3.4.17。具体组件按实际接入验证，不推断所有 3.x/4.x 均已兼容。 |
| 图标 | 优先 `lucide-react@1.61.0`；特殊设计图标使用 TSX 内联 SVG。 |

采用本规范时记录项目实际依赖版本和接入方式，沿用业务仓库已有包管理器、锁文件、检查命令与目录约定。版本不符时先核对 API、样式与交互差异，不为套用示例自动更换项目依赖。

## 给 Agent 的执行指令

先完成以下工作，再报告结果；不要只回复方案、安装命令或“可以使用”。已有业务项目按原技术栈增量接入；空目录只有在用户要求新建项目时才初始化。

1. **了解宿主**：读取业务仓库的 AGENTS、package.json、唯一锁文件、路由、入口、Provider、主题、全局CSS与现有业务组件；确认实际包管理器和可执行脚本。检查分支/工作区与远端同步，遵守业务仓库协作约定；发现远端未同步或分叉时先说明并等待同步选择，不擅自覆盖。不要为接入UI切换包管理器或覆盖已有锁文件。
2. **选组件和示例**：按下方目录将页面区域映射到团队组件；先复用业务项目已移植的同款组件，再选择官方Mantine + Tailwind的准确示例，核对所需props、状态和样式。规范缺少所需组件时，执行下方缺项联系流程，不自行补造组件。
3. **取得准确代码**：从对应示例的「Mantine + Tailwind」Tab取得主文件、辅助文件与素材，或按下文从可读源码导出。核对版本、状态与实际效果，记录来源；原始 `preview/examples/` 入口可能依赖封装或文档逻辑，不能直接复制并只替换import。
4. **接入业务**：将同一份示例的文件按相对路径带齐，保留事件/ref/状态，替换演示数据与业务文案；在业务现有组件目录封装需要复用的部分。沿用当前路由和页面壳，接通实际页面入口；不把整套组件库目录、文档站或其源码构建脚本加入业务运行时。
5. **补齐环境**：只安装实际引用的依赖，合并同源Provider、Mantine CSS层级和Tailwind扫描配置；已有配置先核对再补，不能叠加两套reset。日期、图标、组合状态和图片都按当前例实际引用处理，不能遗漏辅助文件后用默认组件静默替代。
6. **启动并检查**：执行业务项目真实存在的类型、构建和相关测试命令；按该项目dev脚本启动服务，打开实际业务路由检查默认状态、关键交互、窄屏与控制台。端口以实际输出为准，不假定是5173，不挤掉已有服务。只有命令成功但没打开页面时，不声明浏览器验收通过。
7. **交付可核对的结果**：列出采用的组件/来源/接入方式、修改路径、启动命令与可访问URL、通过的检查、未验证项及原因。无法获得标准源码时明确标出阻塞组件和需要的材料，其余独立工作可继续；不能交付未说明的替代样式。

只改用户授权范围，规范更新不授权批量改造既有页面。业务项目按自身流程检查页面和移植源码，组件库的文档维护、标准登记和构建工具不进入业务运行时。

## 组件与样式写法

- 优先用 Mantine 公开组件 props 和 Style Props 准确表达设计，如 `radius`、`size`、`loading`、`h`、`px`、`fw`。同一视觉属性由一个入口管理，不同时在 props 和 Tailwind 中重复指定。
- props 无法准确表达的视觉差异，通过公开 Styles API 的 `classNames={{ root: '...', ... }}` 传入 Tailwind。自有 Mantine 组件样式不用 `className`、手写 `style`/`styles`、CSS Modules、SCSS 或 CSS-in-JS。原生容器可用 `className` 写 Tailwind；Mantine 自带 CSS、内部定位和动画沿用底座。
- Tailwind 类名保持完整静态字符串，可用条件分支或静态映射组合，不拼接 `bg-${color}-500` 等动态候选，不依赖私有 DOM 或哈希类名。
- 保留语义元素、可访问名称、事件、ref、受控/非受控、禁用、加载、键盘和焦点行为。合并调用方 props/classNames 时保留其他插槽和回调，显式值按契约覆盖默认值。
- 默认尺寸随 Mantine 的根字号和 scale 缩放。明确要求固定 CSS 像素时使用对应字面量；不对文字自然宽度使用 `calc-size`、`round` 等取整。不为精简代码改变设计效果或状态。
- 图标按名称导入 Lucide，通过公开尺寸、描边和颜色 props 调整。装饰图标设 `aria-hidden`，仅图标按钮提供明确中文可访问名称。特殊图标用支持 SVG props、保留 viewBox 与路径的 TSX 组件，必要文件随源码一起复制；功能图标不用 SVG 图片 URL/base64，品牌 logo、头像等图片可保留。

### Mantine + Tailwind 源码接入

- 从官方 `@mantine/*` 公共入口导入，沿用该依赖体系的 Provider 和 CSS。复制示例的实际 props、classNames、状态、事件及必要图标、辅助文件和资源，不能只复制 JSX 标签。
- 移植的工具类保持示例中的原名，由业务Tailwind扫描编译；不依赖组件库文档站主题、内部解析器、`preview/`、Storybook 或本机绝对路径。
- Tailwind 4 将移植文件纳入 `@source` 扫描，Tailwind 3 将其目录加入 `content`。沿用组件库基线关闭 Preflight；Tailwind 3 仍保留 `@tailwind base` 以初始化必要变量。CSS 导入层级为 `theme, base, mantine, components, utilities`。
- 使用日期等扩展组件时按示例带入对应包、样式、语言配置和外部依赖。独立组合需要复用时可在业务项目的组件目录封装，保持公开 API 和实际行为。

## 团队标准组件选型

以下为团队标准组件。每行对应一个组件；路由追加到团队实际预览站地址后访问。示例路径均相对**组件库仓库**，用于定位代码，不能当作业务项目已有文件。实际取码遵循下一节。

| 分类 | 组件 | 何时使用 | 预览路由 | 首选参考示例入口 |
| --- | --- | --- | --- | --- |
| 基础 | Button 按钮 | 主次操作、提交、禁用和加载；按用途选择尺寸和变体。 | `#/components/button` | `preview/examples/Button/ButtonBasic.tsx` |
| 基础 | CloseButton 关闭按钮 | 关闭弹层或可移除内容，补齐可访问名称。 | `#/components/closebutton` | `preview/examples/CloseButton/CloseButtonBasic.tsx` |
| 布局 | Layout 布局 | 侧栏、页头、内容和可选辅助区、页脚。 | `#/components/layout` | `preview/examples/Layout/LayoutBasic.tsx` |
| 布局 | ThreeColumnLayout 三栏布局 | 左菜单、中间内容、右AskAgent，独立拖拽和关闭；不含AI服务。 | `#/components/threecolumnlayout` | `preview/examples/ThreeColumnLayout/ThreeColumnWorkspace.tsx` |
| 布局 | Space 间距 | 独立水平或垂直占位；成组元素先用gap。 | `#/components/space` | `preview/examples/Space/SpaceBasic.tsx` |
| 表单 | InputBase 基础输入框 | 基础输入外观、说明、图标和不同状态。 | `#/components/inputbase` | `preview/examples/InputBase/InputBaseBasic.tsx` |
| 表单 | Select 选择器 | 单项录入；按需选择搜索、清除和空结果示例。 | `#/components/select` | `preview/examples/Select/SelectBasic.tsx` |
| 表单 | TagsInput 标签输入框 | 输入、选择和删除多个标签，保留键盘行为。 | `#/components/tagsinput` | `preview/examples/TagsInput/TagsInputBasic.tsx` |
| 表单 | Radio 单选框 | 少量互斥选项；可随表单统一提交。 | `#/components/radio` | `preview/examples/Radio/RadioBasic.tsx` |
| 表单 | Checkbox 复选框 | 多选、勾选、全选和半选状态。 | `#/components/checkbox` | `preview/examples/Checkbox/CheckboxBasic.tsx` |
| 表单 | Switch 开关 | 立即生效的单项设置；业务处理保存中和失败回退。 | `#/components/switch` | `preview/examples/Switch/SwitchBasic.tsx` |
| 日期与时间 | DateInput 日期输入框 | 输入或弹出日历；区间使用对应Range示例。 | `#/components/dateinput` | `preview/examples/DateInput/DateInputBasic.tsx` |
| 日期与时间 | DatePicker 日期选择器 | 日历面板中的单日、区间、范围限制和确认。 | `#/components/datepicker` | `preview/examples/DatePicker/DatePickerBasic.tsx` |
| 导航 | Breadcrumbs 面包屑 | 页面层级与返回路径；长层级参考折叠示例。 | `#/components/breadcrumbs` | `preview/examples/Breadcrumbs/BreadcrumbsBasic.tsx` |
| 导航 | Tabs 标签页 | 同页内容切换，保留标签与面板关联、键盘切换。 | `#/components/tabs` | `preview/examples/Tabs/TabsBasic.tsx` |
| 导航 | Pagination 分页 | 列表分页；核对总页数和数据条数的不同契约。 | `#/components/pagination` | `preview/examples/Pagination/PaginationBasic.tsx` |
| 数据展示 | Table 表格 | 一级列表、会议列表或抽屉中的紧凑表格。 | `#/components/table` | `preview/examples/Table/PrimaryTableExample.tsx` |
| 数据展示 | Tag 标签 | 分类或状态；可移除标签由业务处理关闭。 | `#/components/tag` | `preview/examples/Tag/TagBasic.tsx` |
| 反馈 | Alert 警告提示 | 持续区域状态、异常或较长说明；短暂结果按Toast场景处理。 | `#/components/alert` | `preview/examples/Alert/AlertBasic.tsx` |
| 反馈 | Modal 对话框 | 必须决策、确认或短表单；长表单/多步骤考虑业务页面。 | `#/components/modal` | `preview/examples/Modal/ModalStandard.tsx` |
| 反馈 | Tooltip 文字提示 | 非关键辅助信息；悬停和聚焦可用，触发元素保留ref。 | `#/components/tooltip` | `preview/examples/Tooltip/TooltipBasic.tsx` |
| 反馈 | Loader 加载图标 | 按钮或紧凑区域正在处理；避免重复提交。 | `#/components/loader` | `preview/examples/Loader/LoaderBasic.tsx` |
| 反馈 | Skeleton 骨架屏 | 已知结构的加载占位；加载内容不可被键盘聚焦或触发。 | `#/components/skeleton` | `preview/examples/Skeleton/SkeletonLoading.tsx` |

需要其他变体时，先查看同一组件的完整文档和独立示例；这里不是全部props或状态清单。仍缺少所需组件或定义时，按下面的流程反馈，不能自行新增组件或拿底座效果替代团队标准。

### 使用组件准则：缺项联系王森

团队规范没有所需组件，或没有覆盖实际需求的变体、状态和样式定义时：

1. 确认已检查组件目录和对应示例，明确缺失组件的名称、业务页面、使用场景、必要交互，以及现有组件为什么不能满足。
2. 通过一个可用渠道联系王森：邮件发送至 `sen.wang@brgroup.com`；或打开钉钉中“王森”的会话，告知缺失组件。无法唯一确认会话对象时，不向同名联系人发送。
3. 消息说明缺项和业务需求；有用户提供的设计参考时一并说明。等待组件补齐或明确的处理方案后，再继续该部分实现，不先自行造组件或提供未确认的替代样式。
4. 继续不依赖缺项的工作，交付时说明反馈和待处理部分。无法访问邮件/钉钉时，准备缺项消息并向用户报告未发送及原因，不能把草稿说成已联系。

常见业务页面按下面的组合起步，再按用户需求取对应示例，不一次性引入全部组件：

| 页面 | 组合与边界 |
| --- | --- |
| 数据列表 | 复用现有页面壳或Layout；InputBase/Select做筛选、Table展示、Pagination分页。请求期间按已知结构使用Skeleton，持续错误用Alert，空结果给出明确说明与可执行操作。 |
| 表单与编辑 | InputBase、Select、DateInput、Radio/Checkbox按字段语义选择；Button处理提交和加载。短表单可用Modal，长表单或多步骤用页面；未保存内容保护由业务实现。 |
| Agent工作台 | ThreeColumnLayout组织菜单、内容与AskAgent；Agent内容、服务请求和草稿策略由业务提供。取得准确三栏实现前不把普通Layout辅助区冒充同款；沿用主题、留白与交互规则。 |

## 从哪里取得标准代码

- **业务本地**：先检查是否已有对应移植组件和来源记录；能复用时直接使用，不再复制第二份。
- **预览站**：由团队提供实际地址，追加目录中的路由，复制「Mantine + Tailwind」Tab的全部必要文件。不要把组件库作者本机的localhost地址当成业务Agent可访问地址。
- **源码仓库**：[S Works UI 仓库](http://git.100credit.cn/ai2c/fe/frontend-components)。已有访问权限时，在业务仓库外的独立目录读取指定提交/分支；不改变业务仓库的Git远端或依赖工作区。除表中示例外，实现位于组件库的 `src/components/<Name>/`，准确页面在 `preview/pages/<Name>Page.tsx`，对应记录表为 `preview/standards.ts`。
- **可用性**：先确认目标组件与示例在可访问的预览或源码中存在，并核对实际版本；目录中有名称不代表任意源码版本都包含该实现。
- **缺少代码**：说明缺哪个组件、示例和辅助文件，向用户索取可访问预览地址、源码或对应Tab文件。不要绕过访问控制或用同名底座静默替代。

### 在组件库副本导出可移植示例

仅当已取得准确组件库源码时使用；以下命令在**组件库副本根目录**运行，不是在业务目录运行。先按该副本自身的安装说明准备依赖；使用仓库自带Yarn 4.10.3执行 `node mantine/.yarn/releases/yarn-4.10.3.cjs install --immutable`。无需先启动文档站或复制其构建脚本到业务项目。

下例从真实文档数据导出官方Mantine + Tailwind的基础Button，不能拿原始ButtonCases辅助渲染器当业务组件。导出三栏布局时，将componentId改为threecolumnlayout、exampleId改为threecolumnlayout-workspace。其他组件先查看输出的示例id，再选择满足业务需求的那一个。

```bash
node --input-type=module <<'JS'
import { mkdir, mkdtemp, writeFile, copyFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { standardEntries, collectStandardDocs } from './scripts/lib/standard-docs.mjs';

const componentId = 'button';
const exampleId = 'button-basic';
const selected = (await standardEntries()).filter((entry) => entry.id === componentId);
if (selected.length !== 1) throw new Error('组件库没有目标组件，请核对所用源码');
const records = await collectStandardDocs(selected);
console.log('可用示例：', records.map((record) => record.demoId));
const record = records.find((item) => item.demoId === exampleId);
if (!record) throw new Error('示例id不匹配，请从上面的真实清单选择');
const files = record.bundle.files.filter((file) => /^Mantine(?:\/|\s)/.test(file.fileName)).map((file) => {
  if (file.fileName.includes('/')) return { ...file, fileName: file.fileName.slice('Mantine/'.length) };
  // Button历史代码文件只有具名Example；统一保存路径并补默认出口，不改渲染。
  if (!/export function Example\(/.test(file.code)) throw new Error('未知主文件格式，请用预览Tab取得代码');
  return { ...file, fileName: 'Example.tsx', code: file.code + '\nexport default Example;\n' };
});
if (files.filter((file) => file.fileName === 'Example.tsx').length !== 1) throw new Error('交付主文件不唯一');
if (new Set(files.map((file) => file.fileName)).size !== files.length || files.some((file) => !file.code.trim())) throw new Error('源码文件重复或内容为空');
const output = await mkdtemp(path.join(os.tmpdir(), 'sworks-example-'));
const target = (name) => {
  const result = path.resolve(output, name);
  if (!result.startsWith(output + path.sep)) throw new Error('非法输出路径');
  return result;
};
for (const file of files) {
  const destination = target(file.fileName);
  await mkdir(path.dirname(destination), { recursive: true });
  await writeFile(destination, file.code);
}
for (const asset of record.bundle.assets) {
  if (!asset.url.startsWith('/@fs/')) throw new Error('素材不是本地文件，请从预览站取得完整素材');
  const destination = target(asset.fileName);
  await mkdir(path.dirname(destination), { recursive: true });
  await copyFile(asset.url.slice(5), destination);
}
console.log(JSON.stringify({ componentId, exampleId, output }, null, 2));
JS
```

复制输出目录的**完整内容**到业务组件目录，保持相对路径；由业务路由导入其Example默认导出，再替换业务内容和适用命名。只带当前例所需文件，不带Source参考封装、虚拟模块或整个预览站。已取得源码但无法运行导出时，使用预览Tab文件，或明确选择复制封装及完整局部依赖；后者属于“封装源码移植”，不能称为JSX内直接展开props/classNames。

## 合并配置并把页面跑起来

已有项目先复用当前入口与路由；以下代码用于核对需要的配置片段，不覆盖已有完整文件。保持同一套官方 `@mantine/core` / `@mantine/hooks` 8.3.18；日期组件另需 `@mantine/dates@8.3.18`、`dayjs@1.11.18`及对应样式/语言配置。仅在复制文件引用时安装 `clsx@2.1.1`、`lucide-react@1.61.0`等依赖。

### 官方Mantine + Tailwind 4

将下面CSS放入业务 `src/app.css`（或合并到现有全局入口），只从应用入口加载一次。文件在src目录时，`@source './'`扫描src内全部移植文件；组件不在src时调整扫描路径。

```css
/* ui-spec:mantine-tailwind4 */
@layer theme, base, mantine, components, utilities;
@import 'tailwindcss/theme.css' layer(theme);
@import '@mantine/core/styles.layer.css';
@import 'tailwindcss/utilities.css' layer(utilities) source(none);
@source './';
```

```js
// postcss.config.mjs；合并已有配置，不增加第二套Tailwind处理
import tailwind from '@tailwindcss/postcss';
export default { plugins: [tailwind()] };
```

主线依赖为 `tailwindcss@4.3.3`、`@tailwindcss/postcss@4.3.3`。只导入theme和utilities，保留Mantine的reset，不再使用会引入Preflight的整包CSS导入。

### 已有Tailwind 3项目

继续使用已验证基线3.4.17；与上一套配置二选一，不同时启用。对应 `src/app.css` 为：

```css
/* ui-spec:mantine-tailwind3 */
@layer theme, base, mantine, components, utilities;
@import '@mantine/core/styles.layer.css';
@layer base.host { @tailwind base; }
@layer components.host { @tailwind components; }
@layer utilities.host { @tailwind utilities; }
```

```js
// tailwind.config.cjs
module.exports = {
  content: ['./src/**/*.{ts,tsx}'],
  corePlugins: { preflight: false },
};
```

```js
// postcss.config.mjs
import tailwind from 'tailwindcss';
export default { plugins: [tailwind()] };
```

关闭Preflight仍保留base初始化ring/shadow变量，原生CSS层使用.host子层，避免被Tailwind 3同名指令清空。复制原生容器的边框时明确宽度和样式，不依赖Preflight默认值。

### 路由与Provider

把导出的Example接到业务真实路由，例如已有React路由的目标页面组件中；由现有官方 `MantineProvider` 包住路由树，保留业务主题，不再套一层专用于文档站的Provider。全局CSS从业务入口加载。新空项目才创建React入口、TypeScript和构建配置，按业务指定技术栈初始化；本指南不要求业务应用使用Vite或Yarn。

业务dev服务启动后，打开实际目标路由核对：目标组件已出现、CSS加载、菜单/弹层/输入等关键行为可用、无新增控制台错误；运行项目已有类型/构建命令。若只有类型/构建成功，报告“构建通过，浏览器未验证”。未获得业务仓库或无法访问页面时，不能声明已把业务项目运行并验收成功。

## Layout 布局

应用壳组织侧栏、页头、主区和可选辅助区、页脚，页面内部用 `Flex`、`Stack`、`Grid` 等布局组件组合。需要团队 Layout 样式时复制对应的官方Mantine + Tailwind示例及辅助文件。

| 区域 | 团队默认值与要求 |
| --- | --- |
| 整体 | 宽度 100%，组件默认高度 900；业务页面按宿主容器显式设置高度，全屏壳可用 `h="100dvh"`。 |
| 侧栏 | 展开宽 260，折叠宽 56；可调整范围 220–400，开启拖拽时保留键盘操作。 |
| 页头 / 页脚 | 页头高 66；需要页脚时传入内容，默认高 48。 |
| 主区 | 填满剩余空间，上内边距 24、左右 32、下 32，区域 gap 16；居中模式内层最大宽 840 并可收缩。 |
| 辅助区 | 需要时与主区并排，默认宽 300。 |

- 主区、侧栏与辅助区明确滚动归属，页面提供一个主内容 `main`。窄屏按可用空间决定收起侧栏或辅助区，检查标题、表单和操作区域不互相遮挡。
- 使用 Layout 时不在内容层重复叠加它已有的外层留白。单独页面内容区参考上下 24、左右 32、模块间 16，卡片内边距 16。
- 业务内容替换示意占位。团队 Layout 通过 `sider={null}`、`header={null}` 隐藏对应区域，省略 props 可能显示占位，不能把占位直接交付业务。
- 使用可调整侧栏时保留左右方向键调整、Home/End 到边界、Enter 折叠/恢复及受控回调。局部嵌入布局需限定高度、定位及变量作用域，检查多个实例和滚动时不覆盖宿主页面。

### ThreeColumnLayout 三栏布局

三栏工作台选 ThreeColumnLayout。菜单默认260、范围220–400、折叠56；AskAgent默认300、范围280–480；主区最小320，整体默认高640。各区独立滚动，窄容器内部横向滚动；业务可通过受控显隐收起次要区域。两侧关闭后保留子树、草稿与宽度，顶部有重开入口；关闭不等同于清空草稿或取消业务任务。分隔条支持方向键每次8、Home/End到边界，左Enter折叠菜单、右Enter关闭辅助区并交回焦点；尺寸保留 Mantine 缩放语义。组件不含 AI 服务，业务自己提供菜单、主内容和Agent。复制时包含当前例的辅助文件及实际引用的 `lucide-react@1.61.0` / `clsx@2.1.1`。

## Color 颜色

先按品牌、成功、警告、错误语义选色，再选择相应状态。以下列名采用 Figma 绑定样式后缀；画板第 8 档标作 Focus，对应原始绑定样式的 Click，不能仅凭数字猜测状态。

| 语义 | Light | Focus | Disable | Hover | Normal | Click |
| --- | --- | --- | --- | --- | --- | --- |
| 品牌 Brand | `#F3F7FF` | `#D0DFFF` | `#ADC6FF` | `#3975FF` | `#165DFF` | `#0044E5` |
| 成功 Success | `#E7F9EF` | `#CFF3DE` | `#B6ECCE` | `#3DCD7C` | `#0DC15B` | `#00A742` |
| 警告 Warning | `#FFF9F3` | `#FEE8D0` | `#FDD7AD` | `#FBA345` | `#FA8C16` | `#E07300` |
| 错误 Error | `#FEF5F5` | `#FDD9D9` | `#FBBCBC` | `#F76565` | `#F53F3F` | `#DB2626` |

- 常用中性色为白色 `#FFFFFF`、填充 `#F5F5F5`、线条 `#F0F0F0`、悬停填充 `#EBEBEB`、悬停线条 `#E6E6E6`、灰色档位 `#8C8C8C` 和深色 `#262626`。具体前景/背景组合需检查可读性，不能仅凭色名判定合格。
- 组件既有 hover、active、focus、disabled、loading、error 表现按各自契约保留。固定 `bg` 或 `c` 前检查是否会覆盖这些状态，不批量替换已有配色。
- 百智颜色使用已确认 HEX 或业务主题中已实际定义的语义变量。Mantine 的 `--mantine-color-orange-5` 等变量跟随项目主题，不自动等于百智功能色；颜色规范页不会向项目注册品牌变量。
- props 可用 `c="#262626"`、`bg="orange.0"`；剩余样式可用 `classNames={{ root: 'bg-[var(--mantine-color-orange-0)]' }}` 或 `classNames={{ root: 'text-[color:var(--mantine-color-orange-9)]' }}`。文字类的 `color:` 明确指定文字颜色类型，两例各自只表达一种属性。
- 深色主题按项目已确认主题和专门设计验收，不从浅色表自动推导颜色。未提供的新状态沿用 Mantine 时明确记录，不标为设计已验收。

## Space 间距与尺寸

| 标称值 | 使用场景 |
| --- | --- |
| 4 | 徽标、标签内紧密元素 |
| 8 | 图标与文字、关联信息 |
| 12 | 紧凑控件内部、标题与辅助文字、筛选控件 |
| 16 | 并排操作、相邻模块、卡片内边距 |
| 24 | 内容顶部、较宽松卡片内边距 |
| 32 | 内容或页头左右留白 |
| 48 | 需要更大分隔时的补充档位 |

成组元素优先用容器 `gap`，留白用 `p`、`px`、`py`，独立占位用 `Space w={16}` 或 `Space h={8}`。数字为默认根字号 16px、Mantine scale 为 1 时的标称像素值，保留缩放语义。字号、字重和行高沿用标准组件或设计稿，不以自然文字宽度出现小数判定字体不合格。

## 加载占位

- 结构已知时用 Skeleton 预留正式内容的高度、列宽和间距，检查加载结束后布局不意外跳动；局部操作使用 Loader 或按钮自身 loading。
- 装饰性占位设 `aria-hidden`，内容区以 `aria-busy` 表达加载。Skeleton 的 visible 仅控制遮罩；加载期间用占位替换按钮、链接和输入框，或使保留内容容器 inert，确保隐藏控件不能被聚焦或触发。
- 团队 Skeleton 默认静态。开启动画时尊重减少动态效果偏好，按实际背景验收辨识度；深色填充需单独设计确认。

## 交互规范

### 反馈组件选型

- Tooltip 提供可通过悬停和键盘聚焦获取的辅助说明，关键错误、必填要求和任务必要信息不能只放在气泡内。
- Toast 展示真实发生的短暂结果，普通成功使用礼貌状态播报，不抢焦点；有操作时提供键盘入口和足够阅读、聚焦及操作时间。
- Alert 展示页面或区域持续问题，保留原因和处理入口；字段错误在对应字段旁关联显示，提交失败保留输入并帮助定位错误。Toast 不能替代字段提示。
- Modal 用于必须先决策的情况。组件名不直接决定 ARIA role，普通消息不全部设为紧急 alert；Toast/Alert 更新不移动焦点，表单提交失败后可按需聚焦错误字段。

### 表单关闭与危险操作

- 短确认或短表单用 Modal，需要对照列表时考虑 Drawer，长表单、多步骤或独立路由任务使用页面。模态 Drawer 背景保留视觉上下文但不可交互。
- 未保存内容通过实际存在的遮罩、Esc、关闭、取消和导航出口离开时，进入一致的草稿恢复或放弃修改确认流程。实际保存成功后才提示已保存。
- 默认保留 Esc 取消、弹层内焦点约束和关闭后的焦点返回。特殊退出限制记录原因、替代出口及键盘验证，不能困住用户。
- 高影响或不可逆操作先说明对象、后果和影响范围，按钮用“删除项目”“保留项目”等动作名称，初始焦点优先考虑安全操作。
- 低风险且真实可恢复时可执行后撤销，明确有效条件并恢复真实状态。提交中防止重复执行，失败保留输入并允许重试。

### Menu 与表单控件选型

- Menu 承载编辑、复制、删除等命令；Select 录入候选值，选项多或难找时提供搜索，并区分异步加载、失败、无数据和无匹配。
- Radio 展示少量互斥选项；Checkbox 用于多选或随表单统一提交的勾选；Switch 用于立即生效的单项设置并表达保存中及失败回退。不能仅因只有两项就用 Switch。
- 少于 5 项考虑平铺、超过 10 项考虑搜索是参考，结合文案、空间和频率判断。保留标签关联、选值及底座键盘行为，不通过边框外观判断语义。

### 中文输入与持续更新区滚动

- 自定义 Enter 发送、查询、提交或标签确认时识别输入法组合状态，选字 Enter 不触发业务操作，组合结束不自动补发提交。保留正常 Enter、换行、选项确认、受控输入和调用方回调。
- 在目标浏览器用真实中文输入法核对组合结束附近的行为，合成键盘事件不能替代真实输入法验收；不以全局吞掉 Enter 修复误提交。
- 聊天、日志等追加区域只在用户位于底部附近或主动跟随时自动滚动。用户上翻后保持位置，提供键盘可用的“回到最新”，主动返回后恢复跟随，新内容不抢焦点。底部容差按布局定义，普通静态页面不强加跟随。

### 点击热区

- 图标视觉尺寸和真实点击区域分别设计，通过公开尺寸/间距 props 扩大可交互元素，额外差异用 classNames；图标按钮有明确可访问名称、可见焦点和键盘操作。
- 通用指针操作按 WCAG 2.2 AA 基线核对，通常至少 `24×24 CSS px`。间距例外以小目标包围盒中心的直径 24 CSS px 圆核对，不与其他目标或其他小目标的检查圆相交。行内文本、等效控件、未修改的浏览器控件及必要空间布局等例外按标准记录，紧凑布局不自动豁免。
- 触屏主要操作优先以 `44×44 CSS px` 为设计目标，区分这一建议与桌面视觉尺寸，不采用 28px 通用底线或混用 px/dp。
- 相邻操作的热区不重叠、不盖住其他操作；同一动作可整行响应，不把不同动作的间隔全部填成点击区。测量窄屏、缩放与最小尺寸的真实元素，点击边缘并同时检查滚动。

## 完成前按场景验收

只检查当前任务涉及的场景，并记录不适用原因。运行项目已有检查脚本；自定义交互改变时补必要回归，CSS 作用范围与浏览器交互通过真实页面验证。

- [ ] 接入方式、实际版本、设计来源与修改范围明确，导入、Provider、CSS 和必要辅助文件齐全。
- [ ] 团队规范缺项已联系王森并取得处理方案；尚未解决的部分明确保留，没有自行新增或替代实现。
- [ ] 类型及生产构建通过，移植后的 Tailwind 真实生成所需类，组件状态和调用方覆盖保留。
- [ ] Layout 留白无重复叠加，滚动归属、窄屏和缩放正常，局部布局不覆盖宿主或影响相邻实例。
- [ ] 颜色语义、状态及可读性正确，字号/间距与确认设计一致。
- [ ] 加载时隐藏内容不可聚焦/触发，加载结束后的尺寸和焦点正确，减少动态效果可用。
- [ ] 反馈对应真实结果，字段错误可定位；未保存数据通过各退出路径受到保护，弹层可取消且焦点返回。
- [ ] 表单与菜单语义、生效时机、选值及键盘行为正确；异步场景覆盖加载、失败和空结果。
- [ ] 自定义 Enter 已用真实输入法验收；持续更新区上翻不被拉回、回到最新后跟随。
- [ ] 小操作热区、相邻目标、键盘、触屏及滚动已按目标环境核对，例外有依据。

交付说明写清已执行命令与结果、浏览器/输入法/触屏环境、未验证项及原因、待设计确认项。构建通过、用户确认或规范文件存在，都不能替代未执行的技术检查。

## 项目维护

专项设计覆盖默认布局、颜色或间距时，记录设计来源、适用页面和原因；涉及语义、焦点、数据保护等行为时同时说明影响与验证方式。项目保留例外需明确范围，不静默改变整套规范。

组件目录、依赖、接入方式或规范变化时，同步更新本文件及业务Agent规则中的引用，避免出现重复或相互矛盾的约定。
