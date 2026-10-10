# SimLab 架构理解文档

配套文件:`simlab.structurizr.dsl`(C4 语义来源)、`simlab-deps.dot`(全量导入图)、`simlab.evidence.md`(证据索引)。
生成于 2026-09-25,由 `architecture-visualization:c4model` 技能产出。

## 这份模型回答什么问题

四张视图,每张一个问题,不要合着看:

| 视图 | 回答的问题 | 给谁看 |
| --- | --- | --- |
| `Context` | 谁在用,系统只依赖哪些外部能力,哪些东西被刻意挡在边界外 | 采购方、新加入的同事、非技术干系人 |
| `Containers` | 有几个可独立运行的单元,发布物是什么 | 构建与运维 |
| `RuntimeComponents` | entry HAP 内部怎么切责任,两条世界栈为什么互不引用 | 实现者本人、代码审查 |
| `TargetScope` | LabVerse 提示词里哪些是"还没做",哪些是"和产品决定冲突" | 需要拍板范围的人 |

## 范围与边界

只建模 `entry/src/main/ets` 与 `tools/physics-check`。`docs/` 下的 spec 是设计意图,不是运行结构,只在证据索引里作为 document 类来源引用。

**当前系统边界是刻意为之的窄**。grep `@kit.` 与 `@ohos.` 的全部命中只有 5 个 Kit:AbilityKit、ArkUI、ArkGraphics2D、CoreFileKit、PerformanceAnalysisKit。这意味着网络、账号、本地存储、触觉、分布式、并发、3D 在这个工程里不是"做得浅",是**一行都没有**。这条事实对下面的差集分析是决定性的。

## 三条硬事实(高置信度)

### 事实 1:两条世界栈并存且零耦合

`chemistry/*`(14 条入边)与 `bench/*`(26 条入边)之间的边数是 **0**,由 `simlab-deps.dot` 机械统计得出,不是印象。

同一个"倾倒液体"动作存在两套模型:旧的 `chemistry/BenchModel.Vessel` 走摩尔数与反应相态,新的 `bench/Container` 走容积账本与位姿。两者各自被页面直接引用,所以都不能删。这是 M4 合并债务的图形证据,也是 `docs/superpowers/specs/2026-09-24-...-design.md` 里"已定:不并存"这条决定至今没执行的原因,它需要一次真实的改写,不是重命名。

### 事实 2:判定层与表现层之间没有回路

`bench/Rubric`、`Judgment`、`RubricBrine`、`BrineScenario` 只读 `bench/*` 的数值,不 import 任何 ArkUI 类型(不变量 I3)。全图里从 `view/*` 或 `pages/*` 指向判定层的边只有一条:`ReportPage` 消费 `ScoreCard`。也就是说"换个评分细则,世界行为不变"这个主张(不变量 I4)在依赖图上是真的成立的。

### 事实 3:设计令牌已成型,但只覆盖了两页

`common/Theme.ets` 现在是分层色板(品牌色、7 枚学科辅色、语义色),配 `common/Contrast.ets` 计算 WCAG 相对亮度与对比度,`common/Layout.ets` 提供间距/圆角/动效三条阶梯与角色字号(`pageInset`、`cardPadding`、`listGap`、`captionSize`、`cardTitleSize`、`chipHeight`、`chipRadius`、`cardRadius`)。`pages/Index.ets` 与 `pages/ExperimentPage.ets` 已完全走令牌。

**改这套令牌时算式抓出 4 个真实的无障碍缺陷**:原先的 `TEXT_SECONDARY #6B7A8D`、`ACCENT #2F6FB5`、`DANGER #E2574C`、`RUNNING #2E9E7A` 压页面底时对比度分别是 3.98 / 4.36 / 3.68 / 3.34,全部低于 AA 的 4.5。已按算式加深为 `#5A6878 / #2C6AAE / #C0392B / #1F7A5C`。

剩余债务:另外 4 个页面(BenchPage、ChemistryPage、MeasurePage、ReportPage)仍有约 58 处内联 `DeviceClass.LARGE ? x : y`;颜色仍在 ArkTS 常量里,没有迁到 `resources/element`,所以系统深色切换还没打通(迁移动作依赖 `CustomTheme` 的写法,需核实)。

## 与 LabVerse 提示词的差集

提示词描述的产品比当前工程大一个数量级。逐条比对后分成三类,分类依据是"是否已有代码或已定决策"。

### A 类:已经在做,提示词只是催进度

| 提示词条目 | 现状 | 差距 |
| --- | --- | --- |
| FR-OS-2 多指手势、FR-OS-1 器材对象化 | `bench/Pose`+`Spatial`+`Support` 已把位姿与空间关系做成唯一合法判据来源 | 只缺手指输入。这是 M6,已解除设备阻塞 |
| FR-SE-2 变量由实操动作驱动 | 同上,`PourModel.step` 由倾角驱动 | 同上 |
| FR-OS-5 操作智能评判 | `Rubric`+`Judgment`+`RubricBrine` 8 条判据 100 分 | 已能跑,但只被规范示例驱动过,真实操作数据没走过扣分路径 |
| §6.5 设计 Token | `Theme`+`Layout` 已是事实令牌 | 缺深色/高对比,缺 66 处内联值的收敛 |
| NFR 性能 2D 60FPS | `RunController` 定步长 240Hz + 掉帧补偿 + 采样有界 | 真机帧率未测 |

### B 类:提示词新增,当前工程没有的

知识点图谱、四元映射、AI 讲解、游戏化与成就、教师端仪表盘、分布式课堂、账号会员、国际化、3D 渲染、地理与数学两个新学科、生物显微渲染器、HAR/HSP 多模块拆分、吉祥物与图标体系、VI 手册。

**本地持久化原本在本类,已于 2026-09-25 移出**:`SessionRecord` + `SessionLedger` + `platform/SessionStore`(Preferences),实测跨进程杀死与重装存活,报告页新增「历史操作记录」段。仍欠的部分:记录尚无评分(量取任务没有对应细则)、事实键未配人话标签、无按日期分组与删除。

其中**生物显微**在最初范围里就有(四类实验全要),只是从未实现;**地理与数学可视化是这次提示词新加的两个学科**,已由用户确认为 5 科(见 C 类第 2 条)。

### C 类:与既有产品决定冲突,已由用户拍板(2026-09-25)

原样提出时这三条都要求推翻既有约束。用户逐条给了答复,DSL 里对应标签已从 `Conflicting` 改为 `Decided` / `Rejected`:

1. **AI 即时讲解:批准,且只批准这一条。** "纯本地、暂不联网"不再是绝对约束。但**账号会员与教师端分布式课堂同日明确暂不做**,离线约束对这两项仍然成立,不要援引本次作为先例。落地时必须保留离线规则兜底,否则课堂断网即不可用,等于把"离线是可交付性前提"这条理由赔掉。
2. **学科按 5 科推进:批准。** `Subject` 枚举已加 `GEOGRAPHY` 与 `MATH_VISUAL`。但**不意味着首页要摆 5 个入口**:筛选 chip 由数据推导,没有内容的学科不上屏,所以今天仍是 5 枚(全部/力学/电学/化学/仪器)。这条规则同时解决了"生物被截成生"的缺陷,并把"新增学科导致溢出"变成一条会先红的断言(`LibraryFeed.fitsOnPhone`)。
3. **HAR/HSP 多模块拆分:未拍板,我建议不做。** 提示词的 `features/` + `commons/` 目录树按多团队假设写,现在是单人推进 44 个文件,拆分不产生用户价值却要重做构建与签名。
4. **"知识点不得用动画冒充实验"保留为硬约束。** 它和"全知识点覆盖"的广度目标有内在张力:覆盖率的分子如果是"有动画的场景数",就会诱导铺量。上面那条 chip 规则是它在 UI 层的体现,不要绕过。

## 我建议现在就改的三件事(提示词驱动)

### 1. 设计令牌收敛,和首页布局整改合并做(2026-09-25 已做)

做法与结果:

- `common/Contrast.ets` 新增,实现 WCAG 相对亮度与对比度;`Theme` 加分层色板与 7 枚学科辅色,以及 `textOn(bg)`(只返回正文色或白,不引入第三种灰)。
- `Layout` 加三条阶梯与角色字号访问器,`onLadder`/`onRadius` 把"别写魔法数"变成可断言规则。
- `common/LibraryFeed.ets` 新增:`FeedItem` 视图模型 + 由数据推导的筛选 chip + 窄屏宽度算式。量取训练与化学实验台作为列表条目进首页,`ExperimentMeta` 与注册表不被导航语义污染。
- 断言从 695 项经两轮涨到 877 项。三处变异检查确认断言会咬。
- **一处我明确没照提示词做**:它要求"所有颜色走 resources Token"。颜色迁进 `resources/element/color.json` 以启用系统深色切换,依赖 `CustomTheme` 取到的值能喂给 `CanvasRenderingContext2D.fillStyle`,这条路我没在 SDK 26 上验证过。按提示词自己的护栏"不臆造鸿蒙 API",令牌先留在 ArkTS 常量,深色模式因此延后,不是取消。

代价与剩余:只改了 `Index` 与 `ExperimentPage` 两页(本次布局整改必须动的两页),其余 4 页约 58 处内联断点值留作后续机械替换。

### 2. 应用图标与学科图标必须换成真资产

`resources/base/media` 现在只有 DevEco 默认模板(`background.png`、`foreground.png`、`layered_image.json`、`startIcon.png`)。对一款要进校的产品,默认图标在采购演示时是减分项。这是提示词 §4 里唯一一条"低成本、立刻可见"的。

### 3. `@kit` 依赖清单作为架构护栏(2026-09-25 已做)

"零网络零账号"是资产不是缺陷,但它会被一次 `import ... from '@kit.NetworkKit'` 悄悄推翻。已把它变成断言:`check.mjs` 扫描全部 `.ets` 的 `@kit.*` 导入集合,与白名单逐项比对,并显式断言 NetworkKit / AccountKit / DistributedDataServiceKit / CryptoArchitectureKit / RemoteCommunicationKit **未出现**。变异检查:向 `Contrast.ets` 注入一行 `@kit.NetworkKit` 导入,两条断言立即失败并指名道姓。

这是提示词 §10.2 验收标准里目前唯一被自动化的那条。注意它不是永久禁令:用户已批准 AI 即时讲解联网(见 C 类第 1 条),届时应当把新 Kit 显式加进白名单,让"放宽离线"成为一次被记录的决定而不是一个顺手改动。

## 里程碑建议

不采纳提示词的 M1~M5(它假设从零开始)。在现有 M0~M6 上插两刀:

- **M4-lite 首页整改 + 令牌收敛**(合并成一件事):布局按已批准的方案改,同时把用到的所有字面量走令牌。
- **M6 直接操纵层**:手势输入,`Operation` 映射到 `bench/Pose`。设备已解锁,无阻塞。
- **M7 本地持久化**:操作时序与 `ScoreCard` 落盘,报告页被真实数据驱动。这是 A 类里唯一需要新建能力的,也是"复盘"这条差异化主张的前提。
- 品牌与图标:与上面并行,不占关键路径。
- B 类其余项(图谱、游戏化、多端、3D)全部排在"一条闭合链路端到端可用"之后。理由:当前 4 个注册实验加 2 条实操项,没有一个被学生在设备上完整做过一次。

## 假设与待核实项

标注"需核实"的条目我没有当作事实使用:

- ArkGraphics 3D 在 SDK 26 的可用性与 API 形态。提示词把它列为强制选型,但当前全部画面是 `CanvasRenderingContext2D` 手绘,引入 3D 是重写渲染层,不是加一个模块。
- `@kit.SensorServiceKit` 下 vibrator 的确切模块名与权限声明。
- **已核实并采用**:`Navigation.title()` 接受 `ResourceStr | CustomBuilder | NavigationCommonTitle | NavigationCustomTitle`(`sdk/.../component/navigation.d.ts:2324`),`menus()` 接受 `Array<NavigationMenuItem> | CustomBuilder`(`:2412`),且 `NavigationMenuItem` 只有 `value` 必填、`icon`/`action` 可选(`:281-289`)。首页因此用「字符串标题 + 纯文字菜单项」,避开 CustomBuilder 传参的 `this` 绑定不确定性。菜单项在真机上如何渲染纯文字(无图标)仍未观察。
- 深色模式经 `$r()` 资源切换与 Canvas 字符串配色的共存方式,仍未验证。这是令牌留在 ArkTS 常量的唯一原因。
- 提示词默认 "API 12+",实际工程是 `compatibleSdkVersion 26.0.0`。以 26 为准。
- 深色模式经 `$r()` 资源切换与 Canvas 字符串配色的共存方式。

## 阅读顺序

1. 先看 `Context` 视图,确认"离线"这条边界你还想不想守住。它决定 B 类一半的条目。
2. 再看 `RuntimeComponents`,注意 `chemistry` 与 `bench` 两个簇之间没有线。
3. 需要文件级真相时打开 `simlab-deps.dot`,50 个节点 132 条边,由脚本机械生成,可重跑。
4. `TargetScope` 视图给需要拍板范围的人看。节点标签是 `Decided`(已批准,如 AI 讲解)、`Rejected`(已明确不做,如账号与分布式课堂)或裸 `Target`(尚未拍板),不要替读者假设它属于哪一类。

## 如何预览

`.structurizr.dsl` 用 Qoder 的 Structurizr DSL 格式查看器打开;`.dot` 用 DOT/Graphviz 查看器打开。两者都是派生预览,改事实请改 DSL 源。
