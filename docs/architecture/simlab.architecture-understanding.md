# SimLab 架构理解文档

配套文件:`simlab.structurizr.dsl`(C4 语义来源)、`simlab-deps.dot`(全量导入图,由 `tools/arch/gen-deps.mjs` 机械生成)、`simlab.evidence.md`(证据索引)。
2026-09-25 首版由 `architecture-visualization:c4model` 产出;**2026-10-11 全量刷新**,刷新动机是"找架构层优化点"。

## 这份模型回答什么问题

| 视图 | 回答的问题 | 给谁看 |
| --- | --- | --- |
| `Context` | 谁在用、内容从哪来、只依赖哪些外部能力、哪些东西被刻意挡在边界外 | 采购方、新加入的同事、非技术干系人 |
| `Containers` | 有几个可独立运行的单元、资源与存储边界在哪、发布物是什么 | 构建与运维 |
| `RuntimeComponents` | entry HAP 内部怎么切责任、**哪些箭头方向反了** | 实现者本人、代码审查 |
| `TargetScope` | 愿景里哪些是"还没做"、哪些"已做完/做了一半"、哪些"和产品决定冲突" | 需要拍板范围的人 |

## 刷新时的底数(全部当场量出)

| 量 | 2026-09-25 | 2026-10-11 |
| --- | --- | --- |
| `.ets` 文件 / 行数 | 47 / 约 8254 | **93 / 21041** |
| 离线断言 | 877 | **2532** |
| 全量导入边(`gen-deps.mjs`) | 132 | **257** |
| 首页可打开实验 | 4 场景 + 2 实操 | **7 场景 + 2 实操 = 9 张卡** |
| 课程内容 | 无 | **12 张知识表 770 条 + 实验条目 331 条 + 周期表 118** |
| 碰系统能力(`@kit`/`@ohos`)的文件 | 5 个 Kit | **8 个文件 / 6 个 Kit + 2 个系统控件** |
| 颜色住在哪 | ArkTS 常量 | **`resources/base` + `resources/dark` 两套,Theme 只剩 Resource** |

## 三条硬事实(2026-10-11 复核)

### 事实 1:两条世界栈不再零耦合,但方向是对的

`gen-deps.mjs` 现在直接打印 `chemistry<->bench=2`。两条边都是 `chemistry/BenchModel.ets:3-4` → `bench/GlassShapes` + `bench/VesselBase`,**旧栈单向依赖新栈的器皿几何,没有反向边,所以无环**。

这既是好消息也是坏消息:好消息是 M4 合并有了正确的引力方向(新的东西被复用,旧的东西在瘦身);坏消息是 9 月版文档里"两条栈零耦合,所以都不能删"这句已经过期 —— 现在删掉 `bench/GlassShapes` 会让化学栈编译失败,合并债的形态从"两套并行"变成了"一套骑在另一套上"。**下次动这两个模块前必须重新量一次,不要引用本文的旧结论。**

### 事实 2:判定层与表现层之间仍然没有回路,但内核反向依赖判定层

从 `view/*`、`pages/*` 指向判定层的边只有"交卷"与"报告页消费 ScoreCard"两条 —— "换一张细则,世界行为不变"仍然成立。

但新查出来的问题是:**`physics/` 与 `runner/` 反向 import `bench/Rubric` 里的 `FactSheet`**(`physics/Physics2DRunner.ets:3`、`physics/SpringForceRunner.ets:2`、`runner/IExperimentRunner.ets:2`),`view3d/` 反向 import `bench/Profile`(`view3d/Lathe.ets:1` 等 3 处),`scenes/` 直接 import 一张细则(`scenes/MechanicsScenes.ets:7`)。`FactSheet` 与 `Profile` 是**内核概念**,现在住在"判定层"这个目录里,于是所有下游都被迫依赖判分模块才能说一句话。这是下面 A1 的由来。

### 事实 3:设计令牌已经收口,深色档实测生效

`common/Theme.ets` 里**一个 hex 字面量都没有**(有断言拦),25 个令牌全是 `$r('app.color.*')`,值在 `resources/base` 与 `resources/dark` 两套同名键里;画布侧由 `view/Palette` 把同一令牌解成 hex 并缓存。9 月版列的两条剩余债务 —— "4 个页面仍有约 58 处内联断点值"、"颜色仍在 ArkTS 常量里,所以系统深色切换还没打通" —— **都已结**。

同时推翻 9 月的一个判断:"深色模式经 `$r()` 资源切换与 Canvas 字符串配色的共存方式仍未验证"。现在验证了,而且**这台模拟器能验**:选中 chip 底色浅色 `#FF2C6AAE` / 深色 `#FF4E8CCB`,六屏深色截图。当时之所以得出相反结论,是因为探针测的时候 `resources/dark/` 里只有一个键、`onCreate` 还钉着 `COLOR_MODE_LIGHT` —— 把"没有可解析的深色资源"当成了"环境不支持"。

## 架构层优化点(A1–A10,按"改它的收益 / 代价"排)

**A1|把 `FactSheet`、`Profile` 从 `bench/` 挪进内核(高收益,低成本)**
现状:内核(`physics/`、`runner/`)与 3D 绘制(`view3d/`)为了用一个类型,反向依赖判定层;`scenes/` 甚至直接 import 一张细则。目录级的 `runner ↔ bench` 已成环。
改法:新建 `kernel/`(或直接用 `model/`)放事实表与剖面契约,`bench/` 反过来依赖它。改动是纯移动 + 改 import,离线断言能全程守住(转译清单要同步更新)。
收益:判分与仿真重新变成"单向可替换";`scenes/` 不再需要知道细则存在。

**A2|内容从源码里搬出来(高收益,高成本)**
`content/map` 7988 行 = 全工程 38%,21 张表 1101 条,改一条就要改代码 → 重新构建 → 重新装机。竞品靠云端题库按省/按教材版本下发。
改法:搬到 `resources/rawfile/*.json`,配一个加载器 + 把现有 `MapValidator` 从"编译期校验"改成"启动时校验并降级"(校验逻辑已在,可复用)。
收益:内容更新与发版解耦;这是后面所有"更新点"的放大器。

**A3|页面文件继续长大会开始咬人(中收益,低成本)**
`MeasurePage` 594 行、`ExperimentPage` 567 行、`ReportPage` 508 行、`MapPage` 487 行。单文件里同时有布局、算式、判分调用、落盘调用。
改法:把"每页的算式与状态迁移"下沉到已有的 `common/` 纯模块(这轮 `LibraryFeed` 就是这么做的,效果是那条说谎的护栏被抓出来),页面只留渲染。不要为此拆 HAR/HSP。

**A4|`platform → view` 是我今天亲手引入的跨层依赖(低收益,极低成本)**
`platform/AppearanceStore.ets:4` import `view/Palette`,目的是让切档后画布缓存一定失效。当时判断"漏调一次就是一个看不见的 bug",所以宁可跨层。
更干净的做法:把失效挂在配置变化上(ability 的 `onConfigurationUpdate` 已经在做),`apply()` 只负责 setColorMode。留在这儿也行,但它必须在依赖图上看得见 —— 所以 DSL 里给它打了 `Risk`。

**A5|设备侧探针没有版本管理(高收益,低成本)——本轮我自己造成的**
`F:\tmp` 里那批 `verify*.mjs`(按文本定位点击、dumpLayout 断言、溢出检查、深浅色底色比对)是这一轮所有 UI 结论的证据来源,刚才按你要求清理掉了。仓库里只有 `tools/arch` 与 `tools/physics-check`,**UI 层零自动化、证据不可重跑**。
改法:把探针收进 `tools/device/`,参数化页面名与断言,像 `gen-deps.mjs` 一样可重跑。这条应该最先做,因为后面每条 UI 优化都要靠它验收。

**A6|离线断言只覆盖纯逻辑,UI 与真机是盲区(已知,别自欺)**
2532 项断言全部跑在转译后的 `.cjs` 上,ArkUI 类型、渲染、手势、帧率一项都不覆盖。真机一次没跑过(#23),平板/大屏档连模拟器证据都没有。

**A7|单 HAP 单模块 + 无网络 = 可移植性是资产也是天花板**
只有 8 个文件碰系统能力,内核是纯 TypeScript 级别的逻辑 —— 同一套物理与判分内核理论上可以搬到 Web/其他端,这是竞品(引擎绑在各家客户端里)不具备的。反过来,没有网络就没有班级、任务、学情回流,而这三项恰是采购方要的。DSL 里 `classroom`/`account` 两个节点仍带 `Rejected` 标签:那是产品决定,不是技术债。

**A8|配置变化与画布缓存是一条隐式契约(中收益,低成本)**
新增一个画布组件必须记得 `Palette.bind()`,否则静默拿到透明色 —— 这轮 `MeasurePage.markColors` 在字段初值里求色就是这个坑的实锤。
改法:加一条源码扫描断言"含 `Canvas(` 的组件必须 bind",和这轮加的"组件层禁 `Color.White`""每个子页必须刷 `Theme.BG_PAGE`"同一家族。

**A9|3D 路线被环境锁死在自研上(中收益,需真机)**
`view3d/` 1021 行是手写的剖面→网格→透视→着色,因为 ArkGraphics3D 在这台模拟器镜像上零输出(缺 `.spv` 与 Vulkan,实测)。真机到位之前不要引入系统 3D,否则是零反馈盲改。

**A10|深色档还有两个尾巴(低成本)**
`start_window_background` 深色仍是纯黑,启动瞬间会闪;`resources/dark` 与 `base` 的键对齐有断言,但"新增令牌忘了配深色值"只在这一条上被拦,画布侧解色失败会回落透明 —— 值得再补一条"每个令牌在两套里都必须有非空值"的显式断言(现在靠键对齐间接保证)。

## 里程碑建议(2026-10-11 重排)

1. **A5 先把探针纳管** —— 否则后面每一条 UI 优化都无法复验。
2. **A1 内核解耦** —— 一次纯移动,趁现在只有 6 处 import。
3. **A2 内容通道** —— 决定"这个应用能不能被持续更新"的那一步。
4. M6 直接操纵层(#17)与 #60 余下 8 条物理场景:一个补"手感",一个补"广度",可以并行,但都排在上面三条之后 —— 理由和 9 月一样:**9 个入口没有一个被学生在真机上完整做过一次**。
5. 真机(#23)是所有"未验证"的共同前置。

## 阅读顺序

1. 先看 `Context`,确认"离线"这条边界还想不想守住 —— 它决定 `TargetScope` 里一半节点。
2. 再看 `RuntimeComponents`,注意三条红色 `Risk` 边(方向反了)和 `chemistry → bench` 那两条(方向对了)。
3. 需要文件级真相时打开 `simlab-deps.dot`,重跑 `node tools/arch/gen-deps.mjs` 即可刷新。
4. `TargetScope` 里节点标签是 `Done`/`Partial`(本轮复核过的进度)、`Decided`、`Rejected` 或裸 `Target`,不要替读者假设它属于哪一类。

## 如何预览

`.structurizr.dsl` 用 Qoder 的 Structurizr DSL 格式查看器打开;`.dot` 用 DOT/Graphviz 查看器打开。两者都是派生预览,改事实请改 DSL 源。
