# SimLab 架构证据索引

每条节点与关键边对应的可解析来源。路径相对 `F:/DevEcoProjects/SimLab`。
置信度定义:**high** = 代码/配置直接可见;**medium** = 多个部分信号一致;**low** = 由命名或目录结构推断;**unknown** = 待查。
**2026-10-11 刷新**(上一版数字见 git 历史;所有计数都由命令现算,不抄旧文档)。

## 采集方式

| 事实 | 命令 | 输出(2026-10-11) |
| --- | --- | --- |
| 规模 | `find entry/src/main/ets -name '*.ets' -exec wc -l {} +` | **93 文件 / 21041 行** |
| 目录分布 | 同上按目录汇总 | content 7988、pages 3091、bench 2328、physics 1784、chemistry 1525、view3d 1021、view 893、common 697、runner 644、scenes 600、model 294、platform 102、entryability 59 |
| 导入图 | `node tools/arch/gen-deps.mjs` | **93 文件 / 257 边 / 0 未解析** |
| 跨栈边 | 同上,过滤 `chemistry_* <-> bench_*` | **2 条且单向**:`BenchModel→GlassShapes`、`BenchModel→VesselBase`(`chemistry/BenchModel.ets:3-4`)。旧结论"0 条=两栈零耦合"已失效 |
| 反向依赖(A1) | `grep -rn "from '\.\./bench" physics runner view3d scenes` | `physics/Physics2DRunner.ets:3`、`physics/SpringForceRunner.ets:2`、`runner/IExperimentRunner.ets:2` → `FactSheet`;`view3d/{Lathe,LathePainter,TiltedPlane}.ets:1` → `Profile`;`view3d/VesselView.ets:1` → `GlassShapes`;`scenes/MechanicsScenes.ets:7` → `RubricSpring` |
| 系统能力面 | `grep -rlE "from '(@kit\|@ohos)\." entry/src/main/ets` | **8 个文件**:entryability×2、platform×2、view×3、pages/SettingsPage。Kit 集合 6 个,由 `check.mjs` 白名单断言守住(`check.mjs:3465-3492`),注入 `@kit.NetworkKit` 会让断言失败 |
| 离线断言 | `node tools/physics-check/check.mjs` | **2532 项全绿**(MODULES 清单 78 项) |
| 内容规模 | `node tools/coverage-probe.mjs` | 知识表 12 张 **770 条**;实验条目表 **331 条**;周期表 118 元素。缺判点线索 63 条(粗代理,只作线索不作定罪) |
| 可打开实验 | `node -e` 载 `ExperimentRegistry` + `LibraryFeed` | 注册场景 **7**(spring-mass、incline-block、spring-force、series-circuit、parallel-circuit、kirchhoff、max-power)+ 实操入口 **2**(measure、bench)= 首页 **9 张卡** |
| 深浅色实测 | `hdc shell uitest dumpLayout` 读节点 `backgroundColor` | 选中 chip:浅色 `#FF2C6AAE` / 深色 `#FF4E8CCB`;冷启动首帧按盘上档位解析 |
| 内联断点值 / 圆角 / 内边距 | 见 `check.mjs` 的三条源码守卫 | 0 处(2026-09-26 收敛完毕,由断言守住)。仍留:对象式 `padding` 与 `space:` 未定档,见 #38 |
| 图标资产 | `ls entry/src/main/resources/base/media` | 分层图标两件套已替换并装机验证(spec 8.19 之后的图标批次) |

## 节点证据

| 节点 | 状态 | 置信度 | sourceRefs |
| --- | --- | --- | --- |
| `student` | current | medium | 模拟器截图若干(2026-10-11 六屏深色 + 浅色回归)。`hdc shell param get const.product.model` = `emulator`,所以这条只证明"有人操作过",**不证明真机可用** |
| `teacher` | current | **low** | 仅 `module.json5` 声明 tablet/2in1。无任何教师端代码。已打 `Assumed` |
| `contentAuthor` | current | high | `content/map/*.ets` 21 个数据文件即内容本体;无 rawfile、无下发通道 |
| `harmonyos` | current | high | `EntryAbility.ets:1-3`、`platform/{SessionStore,AppearanceStore}.ets`、`view/SimCanvas.ets:1`、`view/AppChips.ets:2-3` |
| `appStore` | **target** | high(负证据) | 未上架,无下载/更新链路;这是 A2 的下游后果 |
| `entry` HAP | current | high | `build-profile.json5`(compatibleSdkVersion 26.0.0)、`module.json5` |
| `shell` | current | high | `pages/Index.ets` routeMap 七分支 + 兜底;`menuItem` 四个入口 |
| `expPages` | current | high | `pages/{Experiment,Measure,Bench,Chemistry,Report,Map,Settings}Page.ets` |
| `nativeControls` | current | high | `view/AppButton.ets`(系统 Button 三档角色)、`view/AppChips.ets`(ChipGroup SMALL) |
| `runnerContract` | current | high | `runner/IExperimentRunner.ets`、`runner/RunController.ets`(FIXED_DT 1/240,MAX_SAMPLES 2400) |
| `metaSchema` | current | high | `model/ExperimentTypes.ets`、`model/FactLabels.ets`(0/1 事实印"是/否") |
| `sceneCatalog` | current | high | `scenes/{SceneBuilders,MechanicsScenes,ElectricalScenes}.ets` |
| `physicsWorld` | current | high | `physics/{World2D,Physics2DRunner,SpringMassRunner,InclineRunner,SpringForceRunner}.ets` |
| `circuitSolver` | current | high | `physics/MnaSolver.ets`、`physics/circuit/{CircuitRunner,CircuitModel}.ets` |
| `canvasView` | current | high | `view/{SimCanvas,CanvasPainter,SeriesChart,PlotFrame}.ets` |
| `lathe3d` | current | high | `view3d/{Camera,Lathe,LathePainter,TiltedPlane,VesselView}.ets` 1021 行;ArkGraphics3D 在本模拟器零输出(缺 `.spv` 与 Vulkan,实测) |
| `chemistryStack` | current | high | `chemistry/{Formula,ChemistryModel,ChemistryLibrary,BenchModel,BenchEngine}.ets` |
| `benchStack` | current | high | `bench/{Profile,Brine,Pose,Container,Filtration,Spatula,Dropper,ChunkSolid,GlassShapes,VesselBase,BenchWorld}.ets` |
| `judgmentStack` | current | high | `bench/{Rubric,Judgment,RubricBrine,RubricMeasure,RubricSpring,BrineScenario}.ets` |
| `designTokens` | current | high | `common/Theme.ets`(25 个 Resource 令牌,零 hex)、`common/Layout.ets`、`common/Contrast.ets`、`common/Appearance.ets` |
| `inkResolver` | current | high | `view/Palette.ets`;`bind` 在 `SimCanvas`/`SeriesChart`/`EntryAbility`,reset 在 `AppearanceStore.apply` 与 `onConfigurationUpdate` |
| `curriculumMap` | current | high | `content/map/*.ets`(7988 行,零外部依赖) |
| `sessionStore` / `appearanceStore` | current | high | `platform/SessionStore.ets`、`platform/AppearanceStore.ets` |
| `checkHarness` | current | high | `tools/physics-check/check.mjs`(2532 断言,含调色板 AA、令牌接线、能力白名单、术语黑名单、覆盖度地板) |
| `archTools` | current | high | `tools/arch/gen-deps.mjs`、`tools/coverage-probe.mjs`、`tools/verify-table.mjs`。**设备侧 hdc+uitest 探针脚本未入库(A5)** |
| `labverse.*` 全部 | **target** | 见 DSL 上的 `Done`/`Partial`/`Decided`/`Rejected` 标签 | 来源为 2026-09-25 用户提示词(`human-assumption` 类)+ 2026-10-11 逐项复核 |

## 关键边证据

| 边 | 置信度 | sourceRefs |
| --- | --- | --- |
| `shell -> expPages` | high | `pages/Index.ets` routeMap 七分支 |
| `expPages -> physicsWorld` | high | `pages/ExperimentPage.ets` import `Physics2DRunner`(直接依赖,越过契约层) |
| `expPages -> lathe3d` | high | `pages/MeasurePage.ets` import `LathePainter`/`GaugeMark` |
| `judgmentStack -> benchStack` | high | `bench/BrineScenario.ets` import `Container`/`PourModel` 等 |
| `chemistryStack -> benchStack` | high | `chemistry/BenchModel.ets:3-4`(单向;旧"零耦合"结论已过期) |
| **反向** `physicsWorld -> judgmentStack` | high | `physics/Physics2DRunner.ets:3` import `FactSheet` —— A1 |
| **反向** `lathe3d -> benchStack` | high | `view3d/Lathe.ets:1` import `Profile` —— A1 |
| **反向** `sceneCatalog -> judgmentStack` | high | `scenes/MechanicsScenes.ets:7` import `RubricSpring` —— A1 |
| **跨层** `appearanceStore -> inkResolver` | high | `platform/AppearanceStore.ets:4` import `view/Palette` —— A4,刻意为之(漏调 `reset()` 就是静默 bug) |
| `designTokens -> resources` | high | `common/Theme.ets` 25 处 `$r('app.color.*')`,由断言与两套 `color.json` 双向守住 |
| `expPages -> persist` | high | 量取收手判定写入 → `aa force-stop` → 重启 → 报告页显示该记录 |
| **缺失边** `simlab -> 任何网络能力` | high(负证据) | `@kit` 命中集合内无 NetworkKit/AccountKit,白名单断言守住 |
| **缺失边** `curriculumMap -> 任何非源码载体` | high(负证据) | 无 rawfile、无 JSON、无下发通道 —— A2 |

## 已知不精确处(不得当作可信)

- `bench/Brine.ets` 的 `Calibration` 系数(R2):只有守恒与单调关系可信,绝对数值是教学演示标定。已在 `ReportPage` 底部声明里显式写出。
- 判据来源标注为「参考细则(非官方标准)」,版本 `2026.09 第1版`。不是任何教育考试院标准。
- `teacher` 是 low 置信度 actor。若教师端不在近期范围,应把它从 Context 视图移除而不是留着当装饰(目前保留,因为竞品分析显示这是采购主战场)。
- 覆盖度探针的"判点率/对照率"是**词表粗代理**,方向上只会低估真写了判点的条目;它给出的"缺判点 63 条"是人工复核线索,不是定罪。
- 真机、平板/大屏档、系统深色联动:全部未验证。

## 模型维护

- 重跑依赖图:`node tools/arch/gen-deps.mjs`(已固化在仓库里,不再是临时件)。
- DSL 是事实来源,渲染预览是派生物;不要手改导出件来修事实。
- 新增 `.ets` 纯逻辑模块时同步更新 `tools/physics-check/check.mjs` 的 `MODULES`,否则该文件既不进断言也不进类型检查(hvigor 不检查未被引用的 `.ets`)。
- 引用本文任何计数前先重跑命令 —— 这一版里已经有两处旧计数被证明过期。
