workspace "SimLab 仿真实验室" "现状 C4 模型(证据来自 entry/src/main/ets 47 个 .ets 与 tools/physics-check),外加一个明确标注为「提案/未实现」的目标范围系统,用于对照 2026-09-25 的 LabVerse 提示词。渲染预览是派生物,本文件是事实来源。" {

    !identifiers hierarchical

    model {

        # =========================================================
        # 人
        # =========================================================
        student = person "学生" "课堂或自习中完成实验操作。目前只在模拟器上被操作过(2026-09-25),真机一次都没跑过。" {
            tags "EmulatorOnly"
        }
        teacher = person "教师" "大屏演示。deviceTypes 已声明 tablet/2in1,但教师端场景从未在设备上验证过。" {
            tags "Assumed"
        }

        # =========================================================
        # 外部系统
        # =========================================================
        harmonyos = softwareSystem "HarmonyOS NEXT 运行时" "被实际调用到的系统能力有 6 个 Kit:AbilityKit(生命周期)、ArkUI(window)、ArkGraphics2D(displaySync)、ArkData(操作记录落盘)、CoreFileKit(备份扩展)、PerformanceAnalysisKit(hilog)。这个集合由 check.mjs 断言守着,加网络或账号能力会立刻失败。" {
            tags "External"
        }

        # =========================================================
        # 被建模的系统,当前边界
        # =========================================================
        simlab = softwareSystem "SimLab 仿真实验室" "离线虚拟实验应用。当前边界内不存在网络、账号、云同步、师生协同、触觉反馈与 TaskPool 并发。本地持久化已于 2026-09-25 落地(操作记录)。这是 grep @kit 与 @ohos 的结果,不是遗漏;该集合由 check.mjs 的白名单断言守着。" {

            entry = container "entry HAP" "唯一可安装模块。单模块扁平包结构,未拆 HAR/HSP。bundleName com.simlab.edu,compatibleSdkVersion 26.0.0。" "ArkTS / Stage 模型 / API 26" {

                shell = component "实验库首页与路由" "Navigation + NavPathStack + routeMap 五路由;断点分档由 onAreaChange 宽度驱动。" "pages/Index.ets" {
                    tags "Page"
                }
                expPages = component "操作页族" "实验运行页、量取训练页、化学实验台页、反应速查页、诊断报告页。" "pages/{Experiment,Measure,Bench,Chemistry,Report}Page.ets" {
                    tags "Page"
                }
                runnerContract = component "渲染器契约与运行控制" "IExperimentRunner 十方法契约;RunController 定步长 240Hz、掉帧补偿、有界采样(20Hz 上限 2400 点)。" "runner/*.ets"
                metaSchema = component "实验元数据与事实词表" "ExperimentMeta / ParamDef / ObservableDef / ChartDef / TaskDef,外加 FactLabels:事实键到显示名与单位的集中表,配「每条链路的每个事实键都必须有显示名」的断言。外壳据元数据自动渲染控件。" "model/ExperimentTypes.ets, model/SessionRecord.ets, model/FactLabels.ets"
                sceneCatalog = component "场景注册与装配" "把元数据与 runner 工厂注册进 ExperimentRegistry。" "scenes/*.ets"
                physicsWorld = component "2D 力学世界" "World2D 刚体与约束,加弹簧振子与斜面两个 runner。" "physics/{World2D,Physics2DRunner,SpringMassRunner,InclineRunner}.ets"
                circuitSolver = component "电路求解器" "MNA 改进节点电压法加列主元高斯消元;CircuitRunner 复用 2D runner 骨架。" "physics/MnaSolver.ets, physics/circuit/*.ets"
                canvasView = component "画布投影与图表" "SimCanvas 帧驱动、CanvasPainter 世界与屏幕坐标互映射、SeriesChart 通用图线。" "view/*.ets"
                chemistryStack = component "化学栈(旧实验台)" "化学式解析、反应库、限量试剂、旧 Vessel 模型与 BenchEngine。" "chemistry/*.ets" {
                    tags "LegacyBoundary"
                }
                benchStack = component "实验台世界模型(新栈)" "容积与高度互逆的 Profile、七元存量账本 Brine、位姿与空间关系 Pose、倾倒与视差 Container、旁通几何 Filtration、粉末取用 Spatula、BenchWorld。" "bench/{Profile,Brine,Pose,Container,Filtration,Spatula,BenchWorld}.ets"
                judgmentStack = component "判定层" "两原语判据 Rubric、扣分与证据填充 Judgment、粗盐提纯参考细则、场景重放 BrineScenario。" "bench/{Rubric,Judgment,RubricBrine,BrineScenario}.ets"
                designTokens = component "设计令牌" "Theme 分层色板(含 7 枚学科辅色与 textOn)、Contrast 计算 WCAG 相对亮度与对比度、Layout 的间距/圆角/动效阶梯与角色字号。被 6 个页面与 view 层引用。" "common/Theme.ets, common/Contrast.ets, common/Layout.ets"
                libraryFeed = component "实验库列表装配" "FeedItem 视图模型、由数据推导的筛选 chip、学科短标签与窄屏宽度算式。导航语义不外溢到 ExperimentMeta。" "common/LibraryFeed.ets"
                sessionLedger = component "操作记录账本" "SessionRecord 与账本:保留最近 50 条、按结束时刻降序、未评分序列化成字符串以躲开 JSON 把 NaN 变 null 的坑。纯逻辑,可离线断言。" "model/SessionRecord.ets, runner/SessionLedger.ets"
                sessionStore = component "记录落盘绑定" "全工程唯一 import @kit.ArkData 的文件,只读写一对键值。排序/上限/统计/序列化都不在这里,所以它没有可测逻辑。" "platform/SessionStore.ets, @kit.ArkData preferences"
            }

            checkHarness = container "离线验证台" "用 DevEco 自带 TypeScript 把 .ets 转译为 cjs 后由 node 跑断言。8254 行里的纯逻辑部分由它守住,当前 877 项断言。" "Node.js / ESM" {
                tags "DevTooling"
            }
        }

        # =========================================================
        # 目标范围,全部为提案,不是现状
        # =========================================================
        labverse = softwareSystem "LabVerse 目标范围(提案,未实现)" "来自 2026-09-25 提示词的愿景。本系统内所有节点均为 target 状态,不得当作已验证现状阅读。" {
            tags "Target"

            persist = container "历史报告与复盘增强" "操作记录的落盘与回看已于 2026-09-25 落地(SessionRecord + SessionLedger + Preferences,实测跨进程存活)。剩余:记录尚无评分(量取任务还没有对应细则)、事实键未配人话标签、无按日期分组与删除。" "RelationalStore 或 Preferences,需核实版本" {
                tags "Target"
            }
            tokens = container "设计令牌资源化" "ArkTS 侧令牌已落地(色板、对比度算式、间距/圆角/动效阶梯、角色字号),Index 与 ExperimentPage 已改完。剩余:另外 4 个页面的内联断点值,以及颜色迁到 resources 以启用系统深色切换。" "resources/element 加 ArkTS Token 模块,需核实 CustomTheme 写法" {
                tags "Target"
            }
            gesture = container "直接操纵层" "拖、拿、倾斜的多指手势与 Operation 映射。位姿、支撑、空间关系已在 bench/Pose 就位,只缺手势输入。" "ArkUI Pan/Pinch/Rotation 加 GestureGroup" {
                tags "Target"
            }
            haptics = container "触觉反馈" "操作到位与错误后果的分级震动。" "@kit.SensorServiceKit vibrator,需核实模块名" {
                tags "Target"
            }
            knowledge = container "知识点图谱" "KnowledgeNode、覆盖率看板、知识点到实验到微课到练习的四元映射。" "RelationalStore 加内存邻接表" {
                tags "Target"
            }
            aiExplain = container "AI 即时讲解" "2026-09-25 用户批准「先只出 AI 讲解」,「纯本地、暂不联网」因此不再是绝对约束。必须保留离线规则兜底,否则课堂断网即不可用,把已定的可交付性前提赔进去。" "云侧网关加离线规则兜底" {
                tags "Target,Decided"
            }
            gamify = container "游戏化与成就" "闯关、徽章、成长曲线、吉祥物皮肤。" "ArkUI" {
                tags "Target"
            }
            brand = container "品牌与图标体系" "自适应图标三件套、学科图标、器材图标、徽章、VI 手册。当前 media 目录只有 DevEco 默认模板图。" "SVG 加多倍 PNG" {
                tags "Target"
            }
            render3d = container "3D 渲染" "器皿与显微结构的三维呈现。当前全部画面由 CanvasRenderingContext2D 手绘。" "ArkGraphics 3D,需核实 SDK 26 是否可用" {
                tags "Target"
            }
            bioGeo = container "新增学科渲染器" "生物显微与结构、地理、数学可视化。2026-09-25 用户确认按 5 科推进,Subject 枚举已加 GEOGRAPHY 与 MATH_VISUAL;但筛选 chip 由数据推导,没有内容的学科不上屏,所以首页今天仍只有 5 枚。" "MEDIA 渲染器族别已定义未实现" {
                tags "Target,Decided"
            }
            modules = container "多模块工程结构" "features 与 commons 拆分。当前是单 entry 模块,拆分将改变构建与依赖治理。" "HSP / HAR" {
                tags "Target,Rework"
            }
            classroom = container "教师端与分布式课堂" "大屏控制台、现场考核、多端同步。2026-09-25 用户明确暂不做,不要援引 AI 讲解那次批准作为先例。" "软总线、分布式数据管理" {
                tags "Target,Rejected"
            }
            account = container "账号与会员" "登录、权益、增量内容下发。2026-09-25 用户明确暂不做,「纯本地、无账号」对这一项仍然成立。" "@kit.AccountKit 加 AGC" {
                tags "Target,Rejected"
            }
            i18n = container "国际化" "中英双轨。当前 string.json 只有默认语言一套。" "resources/zh_CN 加 en_US" {
                tags "Target"
            }
            taskpool = container "并发求解" "把重求解移出主线程。当前所有求解都在 UI 线程的定步长循环里跑。" "TaskPool / @Sendable" {
                tags "Target"
            }
        }

        # =========================================================
        # 关系(全部在 model 内)
        # =========================================================

        # --- 人到系统
        student -> simlab "选实验、动手操作、看诊断报告"
        teacher -> simlab "课堂演示(未验证)" "in-process" "Assumed"

        # --- 系统到外部
        simlab -> harmonyos "调用 AbilityKit 生命周期、ArkUI window、ArkGraphics2D displaySync 帧回调"

        # --- 页面装配
        simlab.shell -> simlab.expPages "navDestination 按路由名实例化五个页面"
        simlab.shell -> simlab.sceneCatalog "aboutToAppear 里 registerAll 两个场景族"
        simlab.shell -> simlab.runnerContract "ExperimentRegistry.all() 取列表"
        simlab.shell -> simlab.metaSchema "ExperimentRegistry.all() 转成列表项"
        simlab.shell -> simlab.designTokens "断点分档与配色"
        simlab.shell -> simlab.libraryFeed "列表装配、筛选 chip 与点击路由"
        simlab.sessionStore -> simlab.sessionLedger "toJson 与 fromJson 是唯一接口"
        simlab.sessionLedger -> simlab.metaSchema "SessionRecord 沿用 ExperimentMeta 的 id 与学科"
        simlab.expPages -> simlab.metaSchema "读 params/observables/charts 自动渲染控件"
        simlab.expPages -> simlab.designTokens "断点分档与配色"

        # --- 页面到世界
        simlab.expPages -> simlab.runnerContract "构造 RunController 并驱动 step"
        simlab.expPages -> simlab.canvasView "SimCanvas 与 SeriesChart"
        simlab.expPages -> simlab.chemistryStack "BenchPage 用 BenchEngine,ChemistryPage 用 ChemistryLibrary"
        simlab.expPages -> simlab.benchStack "MeasurePage 用 BenchWorld"
        simlab.expPages -> simlab.judgmentStack "ReportPage 用 Judgment 与 RubricBrine"
        simlab.expPages -> simlab.sessionLedger "MeasurePage 收手判定时写入一条记录"
        simlab.expPages -> simlab.sessionStore "写入与回看历史操作记录"
        simlab.expPages -> simlab.physicsWorld "ExperimentPage 直接 import Physics2DRunner"

        # --- 运行控制
        simlab.runnerContract -> simlab.metaSchema "setup 接收 ExperimentMeta"
        simlab.sceneCatalog -> simlab.runnerContract "register(meta, factory)"
        simlab.sceneCatalog -> simlab.physicsWorld "力学 runner 工厂"
        simlab.sceneCatalog -> simlab.circuitSolver "电学 runner 工厂"
        simlab.sceneCatalog -> simlab.metaSchema "装配元数据与图线定义"
        simlab.circuitSolver -> simlab.physicsWorld "CircuitRunner 继承 Physics2DRunner"
        simlab.physicsWorld -> simlab.runnerContract "实现 IExperimentRunner"
        simlab.benchStack -> simlab.runnerContract "BenchWorld 实现同一契约"
        simlab.benchStack -> simlab.metaSchema "BenchWorld 复用 ExperimentMeta"

        # --- 表现层
        simlab.canvasView -> simlab.runnerContract "按抽稀后的采样窗口绘制"

        # --- 判定层
        simlab.judgmentStack -> simlab.benchStack "BrineScenario 真跑世界产生事实,再交给 Rubric 判定"

        # --- 令牌泄漏
        simlab.designTokens -> simlab.canvasView "图线四色与画布底色"

        # --- 验证台
        simlab.checkHarness -> simlab.entry "转译 .ets 为 cjs 后跑 877 项断言(不覆盖 ArkUI 类型)" "node" "DevTooling"

        # --- 现状到目标的缺口(显式标为未实现)
        simlab.sessionLedger -> labverse.persist "剩余缺口:记录尚无评分与标签,量取任务还没有对应细则" "in-process" "Target"
        simlab.benchStack -> labverse.gesture "缺口:位姿已是唯一判据来源,但只能被程序设定,没有手指输入" "in-process" "Target"
        simlab.designTokens -> labverse.tokens "剩余缺口:4 个页面的内联断点值,以及颜色迁到 resources 以启用深色" "in-process" "Target"
        simlab.shell -> labverse.bioGeo "筛选 chip 由数据推导,新学科有内容后自动上屏" "in-process" "Target"
        simlab.metaSchema -> labverse.knowledge "缺口:ExperimentMeta 有 gradeBand 字符串,无知识点实体" "in-process" "Target"
    }

    views {
        systemContext simlab "Context" "谁在用这个系统、它只依赖哪些外部能力、以及被刻意排除在边界外的目标范围。" {
            include *
            autoLayout lr
        }

        container simlab "Containers" "当前可安装单元与开发期验证单元。回答:这个系统里有几个可独立运行的东西?" {
            include *
            autoLayout lr
        }

        component simlab.entry "RuntimeComponents" "entry HAP 内部的责任切分。回答:两条互不引用的世界栈是怎么并存到今天的?" {
            include *
            autoLayout tb
        }

        container labverse "TargetScope" "提案清单。每个节点都是 target 状态;带 Conflicting 标签的节点与既有产品决定直接冲突,需先推翻决定而不是先开发。" {
            include *
            autoLayout tb
        }

        styles {
            element "Person" {
                shape person
                background #08427B
                colour #FFFFFF
            }
            element "External" {
                background #999999
                colour #FFFFFF
            }
            element "Page" {
                background #2F6FB5
                colour #FFFFFF
            }
            element "DevTooling" {
                background #2E9E7A
                colour #FFFFFF
            }
            element "LegacyBoundary" {
                background #8E5BD9
                colour #FFFFFF
            }
            element "Target" {
                border Dashed
                background #F2F4F7
                colour #1F2A3A
            }
            element "Decided" {
                background #1F7A5C
                colour #FFFFFF
            }
            element "Rejected" {
                background #999999
                colour #FFFFFF
            }
            element "Assumed" {
                border Dashed
            }
        }
    }
}
