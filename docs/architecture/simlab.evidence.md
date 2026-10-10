# SimLab 架构证据索引

每条节点与关键边对应的可解析来源。路径相对 `F:/DevEcoProjects/SimLab`。
置信度定义:**high** = 代码/配置直接可见;**medium** = 多个部分信号一致;**low** = 由命名或目录结构推断;**unknown** = 待查。

## 采集方式

| 事实 | 命令 | 输出 |
| --- | --- | --- |
| 导入图 | `node tools/arch/gen-deps.mjs` 遍历 `entry/src/main/ets/**/*.ets` | 58 文件 / 149 边 / 0 未解析 |
| 跨栈边 | 同上,过滤 `chemistry_* <-> bench_*` | **2 条**:`BenchModel→GlassShapes`、`BenchModel→VesselBase`。M4 合并外壳的结果;此前为 0 条,那句话是写死在生成器里的,已改成算出来的 |
| 系统能力面 | `grep -rho "@kit\.[A-Za-z0-9]+" entry/src/main/ets \| sort -u` | 6 个 Kit:AbilityKit、ArkData、ArkGraphics2D、ArkUI、CoreFileKit、PerformanceAnalysisKit。该集合由 check.mjs 的白名单断言守着,注入 `@kit.NetworkKit` 实测会让断言失败 |
| 内联断点值 | `grep -rn "===\s*DeviceClass\." entry/src/main/ets/pages entry/src/main/ets/view` | **0 处**(2026-09-26 令牌收敛完毕,现由 check.mjs 的两条源码级守卫守住:内联字号、直接比较档位各自被拦)。收敛量见 spec 8.17:64 处字号 + 13 处控件尺寸 |
| 内联圆角 / 内边距 | `grep -rn "borderRadius([0-9]\|\.padding([0-9]" pages/ view/` | **0 处**(spec 8.18,两条守卫守住)。仍留:对象式 `padding` 17 处、`space:` 51 处 —— 判断后认为前者不该合并成单一角色,后者要一次设计决定,见 #38 |
| 规模 | `find ... | xargs wc -l` | 10146 行 / 58 文件 |
| 图标资产 | `ls entry/src/main/resources/base/media` | 4 个文件,全部 DevEco 默认模板 |

## 节点证据

| 节点 | 状态 | 置信度 | sourceRefs |
| --- | --- | --- | --- |
| `student` | current | medium | 设备截图 `Screenshot_2026-09-25T120757.png`;`module.json5` deviceTypes。**设备身份已查明是模拟器**(`hdc shell param get const.product.model` = `emulator`),所以这条只证明"有人操作过",不证明真机可用 |
| `teacher` | current | **low** | 仅 `module.json5:11-15` 声明了 tablet/2in1。无任何教师端代码。已打 `Assumed` 标签 |
| `harmonyos` | current | high | `EntryAbility.ets:1-3`、`EntryBackupAbility.ets:1-2`、`SimCanvas.ets:1` |
| `entry` HAP | current | high | `build-profile.json5`(compatibleSdkVersion 26.0.0)、`module.json5` |
| `shell` | current | high | `pages/Index.ets:173-238` |
| `expPages` | current | high | `pages/{Experiment,Measure,Bench,Chemistry,Report}Page.ets` |
| `runnerContract` | current | high | `runner/IExperimentRunner.ets`、`runner/RunController.ets:1-40`(FIXED_DT 1/240, MAX_SAMPLES 2400) |
| `metaSchema` | current | high | `model/ExperimentTypes.ets:92-109` |
| `sceneCatalog` | current | high | `scenes/{SceneBuilders,MechanicsScenes,ElectricalScenes}.ets` |
| `physicsWorld` | current | high | `physics/{World2D,Physics2DRunner,SpringMassRunner,InclineRunner}.ets` |
| `circuitSolver` | current | high | `physics/MnaSolver.ets`、`physics/circuit/{CircuitRunner,CircuitModel}.ets` |
| `canvasView` | current | high | `view/{SimCanvas,CanvasPainter,SeriesChart}.ets` |
| `chemistryStack` | current | high | `chemistry/{Formula,ChemistryModel,ChemistryLibrary,BenchModel,BenchEngine}.ets` |
| `benchStack` | current | high | `bench/{Profile,Brine,Pose,Container,Filtration,BenchWorld}.ets` |
| `judgmentStack` | current | high | `bench/{Rubric,Judgment,RubricBrine,BrineScenario}.ets` |
| `designTokens` | current | high | `common/Theme.ets`(18 行 12 色)、`common/Layout.ets`(57 行) |
| `checkHarness` | current | high | `tools/physics-check/check.mjs`(MODULES 列表 28 项,695 断言) |
| `labverse.*` 全部 | **target** | 无代码证据 | 来源仅为 2026-09-25 用户提示词,属 `human-assumption` 类。全部保留 `Target` 标签 |

## 关键边证据

| 边 | 置信度 | sourceRefs |
| --- | --- | --- |
| `shell -> expPages` | high | `pages/Index.ets:88-105` routeMap 五个分支 |
| `shell -> sceneCatalog` | high | `pages/Index.ets:26-28` registerAll |
| `shell -> runnerContract` | high | `pages/Index.ets:28` `ExperimentRegistry.all()` |
| `expPages -> benchStack` | high | `pages/MeasurePage.ets` import `BenchWorld` |
| `expPages -> judgmentStack` | high | `pages/ReportPage.ets` import `Judgment`/`ScoreCard`/`RubricBrine` |
| `expPages -> chemistryStack` | high | `pages/BenchPage.ets` import `BenchEngine`;`ChemistryPage.ets` import `ChemistryLibrary` |
| `expPages -> physicsWorld` | high | `pages/ExperimentPage.ets` import `Physics2DRunner`(直接依赖,越过契约层) |
| `judgmentStack -> benchStack` | high | `bench/BrineScenario.ets` import `Container`/`PourModel`/`FilterAssembly`/`Separations` |
| `benchStack -> runnerContract` | high | `bench/BenchWorld.ets` import `IExperimentRunner` |
| `circuitSolver -> physicsWorld` | high | `physics/circuit/CircuitRunner.ets` import `Physics2DRunner`(继承) |
| `designTokens -> canvasView` | high | `view/CanvasPainter.ets`、`view/SeriesChart.ets` import `Theme` |
| **缺失边** `chemistryStack <-> benchStack` | high(负证据) | 111 条边中 0 条命中。这是 M4 未执行的直接证据 |
| **已闭合** `expPages -> persist` | high | `platform/SessionStore.ets` 用 `preferences.getPreferencesSync/putSync/flushSync`;实测:量取收手判定写入 → `aa force-stop` → 重启 → 报告页显示该记录(标题、事实、用时) |
| **缺失边** `judgmentStack -> persist` | high(负证据) | 记录里 `rubricId` 仍为空、`awarded` 为 NaN —— 量取任务还没有对应细则,所以历史条目**无分可显示** |
| **缺失边** `simlab -> 任何网络能力` | high(负证据) | `@kit` 命中集合内无 NetworkKit / 无 AccountKit,且由白名单断言守住 |

## 已知不精确处(不得当作可信)

- `bench/Brine.ets` 的 `Calibration` 全部系数(R2)。只有守恒关系与单调关系可信,绝对数值是教学演示标定。已在 spec 与 `ReportPage` 底部声明里显式写出,不得藏进注释。
- 判据来源 `RubricBrine.source = '参考细则(非官方标准)'`,版本 `2026-09-draft1`。不是任何教育考试院标准。
- `teacher` 这个 actor 是 low 置信度。若教师端不在近期范围,应把它从 Context 视图移除而不是留着当装饰。

## 模型维护

- 重跑依赖图:`node <生成脚本>`(脚本目前是临时件,若要长期维护应固化到 `tools/arch/`)。
- DSL 是事实来源。渲染预览是派生物,不要手改导出件来修事实。
- 新增 `.ets` 纯逻辑模块时,同时更新 `tools/physics-check/check.mjs` 的 `MODULES`,否则该文件不进断言也不进类型检查。
