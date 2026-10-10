# 仿真实验室 / SimLab

** HarmonyOS NEXT 离线仿真实验室 —— 让没有实验室的学校也能做实验 **

**An offline simulation lab for HarmonyOS NEXT — bringing labs to schools that don't have one.**

---

## 项目简介 / About

仿真实验室是一个纯离线运行的 HarmonyOS NEXT 应用，面向中学和大学物理、化学、生物、电子学四个学科，提供可交互的实验仿真和课程知识地图。

SimLab is a fully offline HarmonyOS NEXT app covering physics, chemistry, biology, and electronics for middle school through university. It offers interactive experiment simulations and a browsable curriculum knowledge map.

**核心问题 / Core problem:** 很多学校缺少实验器材和场地。本应用用 Canvas 2D 渲染 + 自研求解器还原真实实验流程，学生可以在手机上完成操作、读取数据、获得评分。

Many schools lack lab equipment and space. SimLab reproduces real experiment workflows using Canvas 2D rendering and custom solvers — students can perform operations, read data, and receive scores on their phones.

---

## 功能模块 / Features

### 课程地图 / Curriculum Map

- **471 个知识点 + 331 条实验条目**，覆盖初中/高中/大学三个学段
- 按学科 → 学段 → 册次三级导航，支持周期表视图（化学元素）
- 每条知识点标注前置依赖、认知层级（记忆/应用/迁移）、教材出处
- 实验条目按可行性分级：可运行 / 需补场景 / 需补模型 / 需补渲染 / 需真实硬件
- 471 knowledge points + 331 experiment entries across junior/senior/university stages
- Three-level navigation: subject → stage → volume, with periodic table view
- Each knowledge point tagged with prerequisites, cognitive level, and textbook source
- Experiments graded by feasibility: runnable / needs scene / needs model / needs renderer / needs real gears

### 物理仿真 / Physics Simulation

- **电路求解器 (MNA):** 7 种元件（电源/电阻/滑变/灯泡/开关/电流表/电压表），直流稳态求解
- **力学求解器:** 斜面滑块（含摩擦）、弹簧振子（简谐振动）
- **已建场景:** 串并联电路、基尔霍夫定律验证、最大功率传输、含摩擦斜面、弹簧振子
- **Circuit solver (MNA):** 7 component types, DC steady-state
- **Mechanics solver:** incline with friction, spring-mass harmonic oscillator
- **Built scenes:** series/parallel circuits, Kirchhoff verification, max power transfer, incline block, spring oscillator

### 化学实验台 / Chemistry Bench

- 试剂瓶剖面渲染（回转体 Canvas 绘制）、液面跟随倾斜
- 倾倒/滴加/块状固体操作模型
- 粗盐提纯场景：溶解→过滤→蒸发结晶全流程 + 评分细则
- Lathe-profile vessel rendering with tilt-following liquid surface
- Pouring / dropper / chunk-solid operation models
- Brine purification scenario: dissolve → filter → crystallize with rubric-based scoring

### 3D 视图 / 3D View

- 自研轻量 3D 层：相机、回转体（LathePainter）、倾斜液面
- 用于化学容器和生物结构的可视化
- Custom lightweight 3D layer: camera, lathe surfaces, tilted plane
- Used for chemical vessel and biology structure visualization

---

## 数据规模 / Scale

| 学科 / Subject | 知识点 / Knowledge | 实验 / Experiments | 可运行 / Runnable |
|---|---|---|---|
| 初中物理 / Junior Physics | 45 | 18 | 2 |
| 高中物理 / Senior Physics | 53 | 22 | 2 |
| 大学物理 / University Physics | 80 | 75 | 1 |
| 初中化学 / Junior Chemistry | 30 | 38 | 0 |
| 高中化学 / Senior Chemistry | 53 | 21 | 0 |
| 大学化学 / University Chemistry | 79 | 75 | 3 |
| 初中生物 / Junior Biology | 24 | 29 | 0 |
| 高中生物 / Senior Biology | 40 | 29 | 0 |
| 电子学 / Electronics | 67 | 24 | 2 |
| **合计 / Total** | **471** | **331** | **10** |

---

## 质量保证 / Quality

- **2403 条离线断言**，覆盖：数据完整性、求解器正确性、场景物理不变量、交叉引用合法性
- 变异测试：每条关键断言都有对应的变异验证（改数据 → 断言必须红）
- 负对照：校验器自身也接受校验（伪造坏数据必须被抓出，且不误伤好数据）
- **2403 offline assertions** covering: data integrity, solver correctness, scene physics invariants, cross-reference validity
- Mutation testing: every critical assertion has a verified mutation (change data → assertion must go red)
- Negative controls: the validator itself is validated (fake bad data must be caught without false positives)

---

## 技术栈 / Tech Stack

- **HarmonyOS NEXT** / API 26 / ArkTS + ArkUI Stage model
- **DevEco Studio** 26.0.0.851 / hvigor 6.26.8
- **纯离线**：无网络请求，所有数据内置
- **Canvas 2D** 自研渲染（SimCanvas / CanvasPainter / LathePainter）
- **离线断言 harness**：Node.js 脚本转译 .ets → .cjs 后在 node 中跑断言
- Fully offline: no network requests, all data bundled
- Custom Canvas 2D rendering pipeline
- Offline assertion harness: transpiles .ets → .cjs, runs in Node.js

---

## 项目结构 / Structure

```
entry/src/main/ets/
├── pages/          # 7 个页面（首页/实验/地图/量取/化学台/报告/ bench）
├── physics/        # 力学 + 电路求解器
├── chemistry/      # 化学实验台引擎
├── bench/          # 实验台组件（容器/滴管/固体/细则/评分）
├── content/map/    # 课程地图数据（22 张知识表 + 7 张实验表）
├── scenes/         # 实验场景定义
├── view/           # 2D 视图组件
├── view3d/         # 轻量 3D 层
├── common/         # 主题/布局/对比度
├── model/          # 数据模型
├── runner/         # 实验注册与调度
└── platform/       # 会话持久化
tools/
└── physics-check/  # 离线断言 harness (2403 assertions)
docs/
├── architecture/   # C4 架构文档
└── superpowers/specs/  # 设计规格
```

---

## 构建 / Build

```bash
# 需要 DevEco Studio 26+ 和 HarmonyOS SDK
export DEVECO_SDK_HOME="path/to/sdk"
node hvigorw.js --mode module -p product=default assembleHap --no-daemon

# 跑离线断言 / Run offline assertions
node tools/physics-check/check.mjs
```

---

## 教材版本说明 / Textbook Editions

- 初中生物/化学：按人教版 **2024 版**（2022 课标重排）
- 高中化学：按人教版 **2019 版**
- 物理/电子学：通用编排，不绑定特定版本
- 所有册次与单元名经在线电子课本目录核实（haoduoyun.cc / keben1.com / zxkeben.szxuexiao.com），未核对纸质教材与课标原文
- Junior biology/chemistry: PEP **2024 edition** (reorganized per 2022 curriculum standards)
- Senior chemistry: PEP **2019 edition**
- Physics/electronics: general arrangement, not tied to a specific edition
- All volume/chapter assignments verified against online textbook directories; print textbooks and curriculum standards not cross-checked

---

## License

MIT
