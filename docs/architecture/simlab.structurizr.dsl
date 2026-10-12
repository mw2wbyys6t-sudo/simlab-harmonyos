workspace "SimLab 仿真实验室" "现状 C4 模型,2026-10-11 刷新(证据:entry/src/main/ets 93 个 .ets / 21041 行、tools/physics-check 2532 项断言、tools/arch/gen-deps.mjs 生成的 257 条导入边)。另附一个明确标注为「提案/未实现」的目标范围,用于对照 2026-09-25 的 LabVerse 提示词。渲染预览是派生物,本文件是事实来源。" {

    !identifiers hierarchical

    model {

        # =========================================================
        # 人
        # =========================================================
        student = person "学生" "课堂或自习中完成实验操作。目前只在模拟器上被操作过,真机一次都没跑过(2026-10-11 仍未跑)。" {
            tags "EmulatorOnly"
        }
        teacher = person "教师" "大屏演示。deviceTypes 已声明 tablet/2in1,但教师端场景从未在设备上验证过,且应用内没有任何教师侧入口。" {
            tags "Assumed"
        }
        contentAuthor = person "内容维护者(=开发者本人)" "770 条知识点 + 331 条课程实验条目写在 .ets 源码里:改一条内容 = 改代码 + 重新构建 + 重新装机。这是「更新点」最大的来源,见 A2。" {
            tags "Assumed"
        }

        # =========================================================
        # 外部系统
        # =========================================================
        harmonyos = softwareSystem "HarmonyOS NEXT 运行时" "被实际调用到的系统能力有 6 个 Kit:AbilityKit(生命周期与 setColorMode)、ArkUI(window)、ArkGraphics2D(displaySync)、ArkData(操作记录与档位落盘)、CoreFileKit(备份扩展)、PerformanceAnalysisKit(hilog);另有 @ohos.arkui.advanced.ChipGroup/Chip 两个系统控件。这个集合由 check.mjs 的白名单断言守着,加网络或账号能力会立刻失败。深浅色自 2026-10-11 起真正在用:resources/dark 会被解析(实测 chip 底色 #FF2C6AAE → #FF4E8CCB)。" {
            tags "External"
        }
        appStore = softwareSystem "华为应用市场" "分发与更新通道。状态:未上架(target)。今天所有「更新」都要走重新构建重装,没有增量下发能力。" {
            tags "External,Target"
        }
        realLab = softwareSystem "实体实验室" "同一学习需求的替代方案,也是本应用存在的理由(器材短缺、危险、长周期、微观)。" {
            tags "External"
        }

        # =========================================================
        # 被建模的系统,当前边界
        # =========================================================
        simlab = softwareSystem "SimLab 仿真实验室" "离线虚拟实验应用。当前边界内不存在网络、账号、云同步、师生协同、触觉反馈与 TaskPool 并发。这是 grep @kit 与 @ohos 的结果,不是遗漏;该集合由 check.mjs 的白名单断言守着。" {

            entry = container "entry HAP" "唯一可安装模块。单模块扁平包结构,未拆 HAR/HSP。bundleName com.simlab.edu,compatibleSdkVersion 26.0.0。" "ArkTS / Stage 模型 / API 26" {

                shell = component "实验库首页与路由" "Navigation + NavPathStack + routeMap 七路由(experiment/reactions/bench/measure/report/curriculum/settings)+ 一条兜底;断点分档由 onAreaChange 宽度驱动。顶栏四个文字入口。" "pages/Index.ets" {
                    tags "Page"
                }
                expPages = component "操作页族" "实验运行页(567 行)、量取训练页(594 行)、化学实验台页、反应速查页、诊断报告页(508 行)、课程地图页(487 行)、深浅色设置页。" "pages/*.ets 3091 行" {
                    tags "Page"
                }
                nativeControls = component "系统控件包装" "AppButton 三档角色包住系统 Button(PRIMARY 字色取 Theme.ON_BRAND),AppChips 包住系统 ChipGroup(SMALL 档),速查表用原生 Search。可点卡片与列表行加 clickEffect。" "view/AppButton.ets, view/AppChips.ets"
                runnerContract = component "渲染器契约与运行控制" "IExperimentRunner 十方法契约;RunController 定步长 240Hz、掉帧补偿、有界采样(20Hz 上限 2400 点)。" "runner/*.ets"
                metaSchema = component "实验元数据与事实词表" "ExperimentMeta / ParamDef / ObservableDef / ChartDef / TaskDef,外加 FactLabels:事实键到显示名与单位的集中表(0/1 类事实印成「是/否」),配「每条链路的每个事实键都必须有显示名」的断言。外壳据元数据自动渲染控件。" "model/ExperimentTypes.ets, model/SessionRecord.ets, model/FactLabels.ets"
                sceneCatalog = component "场景注册与装配" "把元数据与 runner 工厂注册进 ExperimentRegistry。当前 7 个注册场景 + 2 条实操入口 = 首页 9 张卡。" "scenes/*.ets"
                physicsWorld = component "2D 力学世界" "World2D 刚体与约束(标签带锚点,文字不再靠手调偏移居中),加弹簧振子、斜面、弹簧弹力三个 runner。" "physics/{World2D,Physics2DRunner,SpringMassRunner,InclineRunner,SpringForceRunner}.ets"
                circuitSolver = component "电路求解器" "MNA 改进节点电压法加列主元高斯消元;CircuitRunner 复用 2D runner 骨架。含串并联、基尔霍夫、最大功率四个场景。" "physics/MnaSolver.ets, physics/circuit/*.ets"
                canvasView = component "画布投影与图表" "SimCanvas 帧驱动、CanvasPainter 世界与屏幕坐标互映射、SeriesChart 通用图线(≤600 点抽稀)、PlotFrame 轴与刻度算式。" "view/*.ets"
                lathe3d = component "自研回转体绘制器" "剖面 Profile → 网格 → 透视投影 → 着色,量取页与化学实验台共用同一份绘制器;含倾斜液面与判读线。全部走 CanvasRenderingContext2D,不依赖 ArkGraphics3D(后者在这台模拟器镜像里无着色器,已实测)。" "view3d/*.ets 1021 行"
                chemistryStack = component "化学栈(旧实验台)" "化学式解析、反应库 22 个反应 59 种试剂、限量试剂、旧 Vessel 模型与 BenchEngine。自 2026-10 起单向依赖 bench 的 GlassShapes/VesselBase —— 跨栈不再是零耦合,但无环。" "chemistry/*.ets 1525 行" {
                    tags "LegacyBoundary"
                }
                benchStack = component "实验台世界模型(新栈)" "容积与高度互逆的 Profile、七元存量账本 Brine、位姿与空间关系 Pose、倾倒与视差 Container、旁通几何 Filtration、粉末取用 Spatula、滴加与块状固体、BenchWorld。" "bench/{Profile,Brine,Pose,Container,Filtration,Spatula,Dropper,ChunkSolid,GlassShapes,VesselBase,BenchWorld}.ets"
                judgmentStack = component "判定层" "两原语判据 Rubric、扣分与证据填充 Judgment、三张参考细则(brine/measure/spring)、场景重放 BrineScenario。ScoreCard.summaryLine() 是那句得分文案的唯一出口。" "bench/{Rubric,Judgment,RubricBrine,RubricMeasure,RubricSpring,BrineScenario}.ets"
                designTokens = component "设计令牌" "Theme 只留 25 个 Resource 色令牌(一个 hex 字面量都没有,裸 hex 由断言拦),值住在 resources/base 与 resources/dark 两套同名键;Contrast 算 WCAG 对比度(两套板逐项过 AA,含负对照);Layout 提供间距/圆角/动效阶梯与角色字号;Appearance 定义深浅色三档与脏值回落。" "common/{Theme,Contrast,Layout,Appearance}.ets"
                inkResolver = component "画布配色解析器" "把同一个 Resource 令牌解成 Canvas 能吃的 hex 并缓存;setColorMode 或配置变化后必须 reset,否则画布会停在旧档。" "view/Palette.ets"
                libraryFeed = component "实验库列表装配" "FeedItem 视图模型、由数据推导的筛选 chip、学科短标签与窄屏宽度算式(常数按系统 ChipGroup 实测重标过)。导航语义不外溢到 ExperimentMeta。" "common/LibraryFeed.ets"
                sessionLedger = component "操作记录账本" "SessionRecord 与账本:保留最近 50 条、按结束时刻降序、未评分序列化成字符串以躲开 JSON 把 NaN 变 null 的坑。纯逻辑,可离线断言。" "model/SessionRecord.ets, runner/SessionLedger.ets"
                curriculumMap = component "课程内容地图(静态数据)" "12 张知识表 770 条 + 10 张实验条目表 331 条 + 周期表 118 元素 + CurriculumIndex 聚合与 MapValidator 校验。7988 行,占全工程 38%,零外部依赖(纯叶子)。" "content/map/*.ets"
                sessionStore = component "记录落盘绑定" "读写字典化的一对键值,脏数据一律回落空账本。" "platform/SessionStore.ets"
                appearanceStore = component "深浅色档位落盘与生效" "preferences 读写档位 + UIAbilityContext.setColorMode + 让 Palette 缓存失效。用 UIAbilityContext 而不是 ApplicationContext(优先级更高)。" "platform/AppearanceStore.ets" {
                    tags "Risk"
                }
            }

            resources = container "资源包" "base 与 dark 两套同名色键 25×2、字符串、分层图标。深浅档由系统按 Configuration 解析,组件层的 Resource 自动重解。" "HarmonyOS resources/element"

            store = container "设备本地存储" "Preferences 两个库:simlab_sessions(操作记录账本)、simlab_settings(深浅色档位)。无数据库、无云端、无导出通道。" "HarmonyOS Preferences"

            checkHarness = container "离线验证台" "用 DevEco 自带 TypeScript 把 .ets 转译为 cjs 后由 node 跑断言,当前 2532 项;含调色板 AA、令牌接线、系统能力白名单、@kit 面、术语黑名单、可见文案标点、内容覆盖度地板。" "Node.js / ESM" {
                tags "DevTooling"
            }
            archTools = container "架构与探针工具(开发期)" "tools/arch/gen-deps.mjs 机械生成全量导入图(93 文件 257 边,并直接报跨栈边数);coverage-probe/verify-table 量内容覆盖度并自带负对照。设备侧 hdc+uitest 探针脚本未纳入版本管理,见 A5。" "Node.js / hdc" {
                tags "DevTooling"
            }
        }

        # =========================================================
        # 目标范围,全部为提案,不是现状
        # =========================================================
        labverse = softwareSystem "LabVerse 目标范围(提案,未实现)" "来自 2026-09-25 提示词的愿景。本系统内所有节点均为 target 状态,不得当作已验证现状阅读。2026-10-11 逐项复核过状态。" {
            tags "Target"

            persist = container "历史报告与复盘增强" "已完成:落盘与跨进程存活、量取侧细则打分、事实键人话标签、按日期分组与删除、报告页由选中记录驱动。剩余:无导出/分享通道,记录只活在这台设备上。" "Preferences(现状)+ 导出通道(target)" {
                tags "Target,Partial"
            }
            tokens = container "设计令牌资源化" "已完成(2026-10-11):色阶全部迁入 resources/base + resources/dark,Theme 只剩 Resource,画布经 Palette 解色,深浅色在模拟器上实测生效。剩余:② 底部 Tabs 与图标体系。" "resources/element + ArkTS Token 模块" {
                tags "Target,Done"
            }
            gesture = container "直接操纵层" "拖、拿、倾斜的多指手势与 Operation 映射。位姿、支撑、空间关系已在 bench/Pose 就位,只缺手势输入。化学实验台已有拖拽(draggable + onDragStart),但量取页仍是滑杆驱动。" "ArkUI Pan/Pinch/Rotation 加 GestureGroup" {
                tags "Target"
            }
            haptics = container "触觉反馈" "操作到位与错误后果的分级震动。" "@kit.SensorServiceKit vibrator,需核实模块名" {
                tags "Target"
            }
            knowledge = container "知识点图谱" "已完成一半:12 张知识表 770 条 + 实验条目 331 条已进应用(MapPage 三排筛选 + 周期表视图),覆盖度有四把刻度量。剩余:知识点↔实验的显式建链(现在只有学科+学段的粗对齐),以及微课与练习两端。" "content/map 静态数据(现状)+ 关联表(target)" {
                tags "Target,Partial"
            }
            aiExplain = container "AI 即时讲解" "2026-09-25 用户批准「先只出 AI 讲解」,「纯本地、暂不联网」因此不再是绝对约束。必须保留离线规则兜底,否则课堂断网即不可用。竞品已把同类能力做到 2.0(见竞品报告),这是当前最明显的能力差。" "云侧网关加离线规则兜底" {
                tags "Target,Decided"
            }
            gamify = container "游戏化与成就" "闯关、徽章、成长曲线、吉祥物皮肤。" "ArkUI" {
                tags "Target"
            }
            brand = container "品牌与图标体系" "应用图标已完成分层图标两件套并装机验证。剩余:学科图标、器材图标、徽章、VI 手册;深色档 start_window_background 仍是纯黑,启动会闪一下。" "SVG 加多倍 PNG" {
                tags "Target,Partial"
            }
            render3d = container "3D 渲染" "已用自研路线落地回转体(量筒/烧杯/试剂瓶)与倾斜液面,不依赖系统 3D。ArkGraphics3D 在这台模拟器镜像上零输出(缺 .spv 着色器与 Vulkan,已实测),所以真机是这条路的唯一解锁点。生物显微结构仍未做。" "CanvasRenderingContext2D(现状)/ ArkGraphics3D(需真机)" {
                tags "Target,Partial"
            }
            bioGeo = container "新增学科渲染器" "生物显微与结构、地理、数学可视化。Subject 枚举已加 GEOGRAPHY 与 MATH_VISUAL;筛选 chip 由数据推导,没有内容的学科不上屏。课程地图侧四科齐备,可做的实验侧仍只有物理化学。" "MEDIA 渲染器族别已定义未实现" {
                tags "Target,Decided"
            }
            modules = container "多模块工程结构" "features 与 commons 拆分。当前是单 entry 模块 93 个文件,拆分将改变构建与依赖治理。" "HSP / HAR" {
                tags "Target,Rework"
            }
            classroom = container "教师端与分布式课堂" "大屏控制台、现场考核、多端同步。2026-09-25 用户明确暂不做。竞品(希沃/NOBOOK)的主战场恰在这里,不做=主动放弃课堂采购场景。" "软总线、分布式数据管理" {
                tags "Target,Rejected"
            }
            account = container "账号与会员" "登录、权益、增量内容下发。2026-09-25 用户明确暂不做,「纯本地、无账号」对这一项仍然成立。" "@kit.AccountKit 加 AGC" {
                tags "Target,Rejected"
            }
            contentChannel = container "内容更新通道" "把 content/map 与 chemistry 的表从源码里搬到 rawfile/JSON 或应用市场增量包,使「改一条知识点」不需要重新装机。A2 的直接对策,也是竞品「云端题库对接各省教材」的离线版答案。" "resources/rawfile + 校验器(现 MapValidator 可复用)" {
                tags "Target"
            }
            i18n = container "国际化" "中英双轨。当前 string.json 只有默认语言一套。" "resources/zh_CN 加 en_US" {
                tags "Target"
            }
            taskpool = container "并发求解" "把重求解移出主线程。当前所有求解都在 UI 线程的定步长循环里跑;真机帧率未测。" "TaskPool / @Sendable" {
                tags "Target"
            }
        }

        # =========================================================
        # 关系(全部在 model 内)
        # =========================================================

        # --- 人到系统
        student -> simlab "选实验、动手操作、看诊断报告、自己切深浅色"
        teacher -> simlab "课堂演示(未验证,且无入口)" "in-process" "Assumed"
        contentAuthor -> simlab.curriculumMap "改源码里的表条目,然后重新构建重装" "file"

        # --- 系统到外部
        simlab -> harmonyos "调用 AbilityKit 生命周期与 setColorMode、ArkUI window、ArkGraphics2D displaySync 帧回调、ArkData preferences"
        simlab -> appStore "分发与更新(未接入)" "unknown" "Target"
        student -> realLab "同一学习需求的替代方案" "physical"

        # --- 页面装配
        simlab.shell -> simlab.expPages "navDestination 按路由名实例化七个页面"
        simlab.shell -> simlab.sceneCatalog "aboutToAppear 里 registerAll 两个场景族"
        simlab.shell -> simlab.runnerContract "ExperimentRegistry.all() 取列表"
        simlab.shell -> simlab.metaSchema "ExperimentRegistry.all() 转成列表项"
        simlab.shell -> simlab.designTokens "断点分档与配色"
        simlab.shell -> simlab.libraryFeed "列表装配、筛选 chip 与点击路由"
        simlab.shell -> simlab.nativeControls "顶栏文字入口与筛选器"
        simlab.sessionStore -> simlab.sessionLedger "toJson 与 fromJson 是唯一接口"
        simlab.appearanceStore -> simlab.inkResolver "切档后清画布色缓存(跨层依赖,见 A4)" "in-process" "Risk"
        simlab.sessionLedger -> simlab.metaSchema "SessionRecord 沿用 ExperimentMeta 的 id 与学科"
        simlab.expPages -> simlab.metaSchema "读 params/observables/charts 自动渲染控件"
        simlab.expPages -> simlab.designTokens "断点分档与配色"
        simlab.expPages -> simlab.nativeControls "AppButton / AppChips / Search"

        # --- 页面到世界
        simlab.expPages -> simlab.runnerContract "构造 RunController 并驱动 step"
        simlab.expPages -> simlab.canvasView "SimCanvas 与 SeriesChart"
        simlab.expPages -> simlab.lathe3d "量取页与实验台共用回转体绘制器"
        simlab.expPages -> simlab.chemistryStack "BenchPage 用 BenchEngine,ChemistryPage 用 ChemistryLibrary"
        simlab.expPages -> simlab.benchStack "MeasurePage 用 BenchWorld"
        simlab.expPages -> simlab.judgmentStack "交卷时把事实表交给判分,报告页消费 ScoreCard"
        simlab.expPages -> simlab.sessionLedger "判定时写入一条记录"
        simlab.expPages -> simlab.sessionStore "写入与回看历史操作记录"
        simlab.expPages -> simlab.appearanceStore "设置页选档即落盘并生效"
        simlab.expPages -> simlab.physicsWorld "ExperimentPage 直接 import Physics2DRunner"
        simlab.expPages -> simlab.curriculumMap "MapPage 与 ChemistryPage 读表"

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
        simlab.canvasView -> simlab.inkResolver "画布只吃字符串:每帧从令牌解 hex"
        simlab.inkResolver -> simlab.designTokens "解的是同一批 Resource,组件与画布不会各画各的色"
        simlab.designTokens -> simlab.resources "25 个令牌 = $r('app.color.*'),两套同名键"
        simlab.appearanceStore -> simlab.resources "setColorMode 后系统按档位重解资源"

        # --- 判定层
        simlab.judgmentStack -> simlab.benchStack "BrineScenario 真跑世界产生事实,再交给 Rubric 判定"

        # --- 跨栈与反向依赖(架构风险 A1:箭头方向与"内核不依赖判定层"的初衷相反)
        simlab.physicsWorld -> simlab.judgmentStack "physics/runner 反向 import bench/Rubric 里的 FactSheet" "in-process" "Risk"
        simlab.lathe3d -> simlab.benchStack "view3d 反向 import bench 的 Profile/GlassShapes" "in-process" "Risk"
        simlab.sceneCatalog -> simlab.judgmentStack "MechanicsScenes 直接 import RubricSpring" "in-process" "Risk"
        simlab.chemistryStack -> simlab.benchStack "旧化学栈借用新栈的器皿几何(单向,无环)—— 这是 M4 合并的正确方向,但零耦合的旧说法已失效" "in-process"

        # --- 验证台
        simlab.checkHarness -> simlab.entry "转译 .ets 为 cjs 后跑 2532 项断言(不覆盖 ArkUI 类型)" "node" "DevTooling"
        simlab.archTools -> simlab.entry "机械生成全量导入图与覆盖度读数" "node" "DevTooling"

        # --- 现状到目标的缺口(显式标为未实现)
        simlab.sessionLedger -> labverse.persist "剩余缺口:记录不能导出,只活在这台设备上" "in-process" "Target"
        simlab.benchStack -> labverse.gesture "缺口:位姿已是唯一判据来源,但量取页只能被滑杆设定,没有手指输入" "in-process" "Target"
        simlab.curriculumMap -> labverse.contentChannel "缺口:内容在源码里,改一条要重装" "file" "Target"
        simlab.curriculumMap -> labverse.knowledge "缺口:知识点与实验之间只有学科+学段的粗对齐,无显式关联" "in-process" "Target"
        simlab.metaSchema -> labverse.aiExplain "缺口:判据已产出自然语言证据,但没有讲解出口" "in-process" "Target"
    }

    views {
        systemContext simlab "Context" "谁在用这个系统、它只依赖哪些外部能力、内容从哪来、以及被刻意排除在边界外的目标范围。" {
            include *
            autoLayout lr
        }

        container simlab "Containers" "当前可安装单元与开发期验证单元。回答:这个系统里有几个可独立运行的东西?资源和存储边界在哪?" {
            include *
            autoLayout lr
        }

        component simlab.entry "RuntimeComponents" "entry HAP 内部的责任切分。回答:两条世界栈现在还是零耦合吗?哪些箭头方向反了?" {
            include *
            autoLayout tb
        }

        container labverse "TargetScope" "提案清单。每个节点都是 target 状态;带 Rejected 标签的与既有产品决定直接冲突,需先推翻决定而不是先开发;带 Done/Partial 的是 2026-10-11 复核后的真实进度。" {
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
            element "Risk" {
                border #C0392B
                borderWidth 3
            }
            element "Target" {
                border Dashed
                background #F2F4F7
                colour #1F2A3A
            }
            element "Done" {
                background #1F7A5C
                colour #FFFFFF
                border Solid
            }
            element "Partial" {
                background #E8A24E
                colour #1F2A3A
                border Solid
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
