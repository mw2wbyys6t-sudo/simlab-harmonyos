# 学生填数入口(#61)实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让学生把自己处理出来的数交进应用,应用按正确流程比对并点名典型错法,使"数据处理"这一类判据第一次能被判。

**Architecture:** `meta.submissions` 声明填空 → `ExperimentPage` 渲染任务与输入框 → `runner.setAnswer()` 收下 → 每场景一个**纯函数 procedure** 从本次数据算出正确值与各错法值 → `AnswerCheck.match` 产出三值结果码 → 细则只读这个码。判定层不新增 op、不懂物理;学生原话以 `ans.` 前缀进 FactSheet 并随记录落盘。

**Tech Stack:** HarmonyOS NEXT / API 26 / ArkTS + ArkUI Stage model;离线断言 harness `tools/physics-check/check.mjs`(把 `.ets` 转译成 `.cjs` 后跑);设备侧 `hdc` + `uitest` 探针。

**Spec:** `docs/superpowers/specs/2026-10-16-student-answer-channel-design.md` —— 本计划逐节实现它,执行时两份一起读。

## Global Constraints

- 判定层只读事实。`ans.*` 前缀的键**永远不进任何判据**(比较只发生在 runner 里)。
- 输入时不回显任何对错:填错之后屏幕上不得出现"对/错/偏差"字样,只有交卷后才有。
- 学生可见文案一律全角标点,且不得出现内部词(黑名单见 `tools/visible-copy-blocklist.mjs`)。新增的填空 `label` 与任务文本必须过这道闸门。
- 细则必须能被满足:每条新判据都要有"认真做完 = 100 分"的断言与设备侧验证。
- 判分保守宁漏不误:**"没交"扣分**(runner 显式写 Outcome=2);**"这道题出不来"不扣分也不响**(一个事实都不写)。
- 不新增滑杆来代替学生动作。
- 完成定义 = 离线断言全绿 → hvigor 构建绿 → 装机探针全通过 → 截图人眼看过。只到模拟器,不得声称真机。
- 每一笔提交必须单独可编译可验证;不可分割时一笔 + 正文分批。
- 含中文的批量改写落成脚本文件执行,不用 shell heredoc(会把模式串弄坏成"匹配不到"的假失败)。
- 命令均在仓库根目录 `F:/DevEcoProjects/SimLab` 执行。构建:
  `export DEVECO_SDK_HOME="F:/DevEco/DevEco Studio/sdk" && "F:/DevEco/DevEco Studio/tools/node/node.exe" "F:/DevEco/DevEco Studio/tools/hvigor/bin/hvigorw.js" --mode module -p product=default assembleHap --no-daemon`

## 文件结构

| 文件 | 责任 |
| --- | --- |
| Create `entry/src/main/ets/physics/AnswerCheck.ets` | 结果码常量、`Fingerprint`、`AnswerOutcome`、`match()`。纯函数,场景无关 |
| Create `entry/src/main/ets/physics/TapeChunkProcedure.ets` | sr-003 的逐差法:分子、分母倍数、错法值。纯函数 |
| Create `entry/src/main/ets/physics/ProjectileGProcedure.ets` | sr-007 的反求 g 与竖直段比、错法值。纯函数 |
| Modify `entry/src/main/ets/model/ExperimentTypes.ets` | `SubmissionDef` + `ExperimentMeta.submissions` |
| Modify `entry/src/main/ets/scenes/SceneBuilders.ets` | `submission()` 工厂 |
| Modify `entry/src/main/ets/runner/IExperimentRunner.ets` | `setAnswer(key, value)` / `answer(key)` |
| Modify `entry/src/main/ets/physics/Physics2DRunner.ets` | 答案表 + setup/reset 清空 + `checkNumber` 工具 |
| Modify `entry/src/main/ets/physics/TickerTape.ets` | `segmentsMm(start, every)` |
| Modify `entry/src/main/ets/physics/TapeCartRunner.ets` | 写 8 个填空相关事实 |
| Modify `entry/src/main/ets/physics/ProjectileRunner.ets` | 点旁标 y;写 8 个事实 |
| Modify `entry/src/main/ets/scenes/MechanicsScenes.ets` | 两条场景声明填空 |
| Modify `entry/src/main/ets/model/FactLabels.ets` | 结果码的枚举标签表 |
| Modify `entry/src/main/ets/bench/RubricTape.ets` | +2 判据、分值重排、版本 |
| Modify `entry/src/main/ets/bench/RubricProjectile.ets` | 同上 |
| Modify `entry/src/main/ets/pages/ExperimentPage.ets` | 「要交的结论」一节(全工程第一个 `TextInput`) |
| Modify `tools/physics-check/check.mjs` | MODULES、新断言节、文案闸门收录填空 |
| Create `tools/device/check-answer.mjs` | 设备侧验收 |

---

### Task 1: `AnswerCheck` —— 比对与三值结果码

**Files:** Create `entry/src/main/ets/physics/AnswerCheck.ets`;Test `tools/physics-check/check.mjs`(新节追加在末尾 `if (failures.length > 0) {` 之前)

**Interfaces:** Produces `ANSWER_OK=0`、`ANSWER_WRONG=1`、`ANSWER_MISSING=2`;`class Fingerprint { id, value }`;`class AnswerOutcome { code, relErr, wrongKind }`;`AnswerCheck.match(answer, correct, prints, tol): AnswerOutcome | null`;`AnswerCheck.MATCH_TOL = 0.5`

- [ ] **Step 1** `MODULES` 里 `'physics/TickerTape',` 之后插入 `'physics/AnswerCheck',`
- [ ] **Step 2** 写失败的断言(见下)
- [ ] **Step 3** `node tools/physics-check/check.mjs 2>&1 | tail -3` → 预期 `Cannot find module .../AnswerCheck.cjs`
- [ ] **Step 4** 写实现(见下)
- [ ] **Step 5** 再跑 → `✓ ...`
- [ ] **Step 6** 提交:`git add entry/src/main/ets/physics/AnswerCheck.ets tools/physics-check/check.mjs && git commit -m "填数通道 1:AnswerCheck —— 三值结果码、先正确值后指纹的匹配顺序、没出题时返回 null"`

断言:

```js
// ---- 学生填数通道 1:AnswerCheck 的三值码与匹配顺序 ------------------------------
// 这套码是"没交"与"这题没出"两条路径的唯一落点,所以顺序与边界都要钉住。
{
  const { AnswerCheck, ANSWER_OK, ANSWER_WRONG, ANSWER_MISSING, Fingerprint } =
    require(join(OUT, 'physics/AnswerCheck.cjs'));
  const fp = (id, value) => { const f = new Fingerprint(); f.id = id; f.value = value; return f; };
  const prints = [fp(1, 100), fp(2, 20), fp(3, 60)];
  check('差 1% → 算对', AnswerCheck.match(181.8, 180, prints, 3).code, ANSWER_OK, 0);
  check('偏差按有符号百分比报出', AnswerCheck.match(181.8, 180, prints, 3).relErr, 1, 0.01);
  check('差 4% → 算错', AnswerCheck.match(172.8, 180, prints, 3).code, ANSWER_WRONG, 0);
  check('没填(NaN)→ 没交', AnswerCheck.match(Number.NaN, 180, prints, 3).code, ANSWER_MISSING, 0);
  assertTrue('没填时 relErr 不编数',
    !Number.isFinite(AnswerCheck.match(Number.NaN, 180, prints, 3).relErr), 'x');
  check('命中指纹 2 号(差 0.3%)', AnswerCheck.match(20.06, 180, prints, 3).wrongKind, 2, 0);
  check('命中指纹也仍算错,不因为"像某种错法"就放过',
    AnswerCheck.match(20.06, 180, prints, 3).code, ANSWER_WRONG, 0);
  check('一个指纹都没命中时 wrongKind 为 0',
    AnswerCheck.match(123, 180, prints, 3).wrongKind, 0, 0);
  // 先比正确值:学生填出一个与正确值同数的指纹时,判"对"而不是判错法
  check('匹配顺序:先正确值后指纹', AnswerCheck.match(100, 100, [fp(1, 100)], 3).code, ANSWER_OK, 0);
  // 这题出不来由调用方决定:correct 非有限 → 不产出结果,而不是"算对"
  assertTrue('correct 为 NaN 时返回 null(调用方据此一个事实都不写)',
    AnswerCheck.match(90, Number.NaN, prints, 3) === null, 'x');
  check('负的正确值也算得出相对偏差(分母取绝对值)',
    AnswerCheck.match(-90, -100, prints, 3).relErr, 10, 0.01);
  check('带宽 0.5% 之外就不算命中(0.6% → wrongKind 0)',
    AnswerCheck.match(100.6, 180, [fp(1, 100)], 3).wrongKind, 0, 0);
}
```

实现(`entry/src/main/ets/physics/AnswerCheck.ets`):

```ts
/** 学生填数比对的三种结局。0/1/2 是判据读的码,印给学生前必须过枚举标签表 */
export const ANSWER_OK: number = 0;
export const ANSWER_WRONG: number = 1;
export const ANSWER_MISSING: number = 2;

/** 一种典型错法算出来的数。id 由场景的 procedure 定,0 保留给"没命中" */
export class Fingerprint {
  id: number = 0;
  value: number = 0;
}

export class AnswerOutcome {
  code: number = ANSWER_MISSING;
  /** 有符号相对偏差 %;没填时为 NaN */
  relErr: number = Number.NaN;
  /** 命中的错法编号,0 表示只是算错、说不出错在哪 */
  wrongKind: number = 0;
}

/**
 * 把"学生填的数"与"这批数据按正确流程应得的结果"比一次。
 *
 * 纯函数,而且刻意不知道任何物理:场景的 procedure 负责算出 correct 与各种错法值,
 * 这里只做带宽比对。顺序写死 —— 先比正确值,再比指纹,否则一个恰好等于错法值的
 * 正确答案会被点名成犯了那个错。
 */
export class AnswerCheck {
  /** 认"就是这个错法"的带宽。比判分的容差紧得多:点名是断言,不是给分 */
  static readonly MATCH_TOL: number = 0.5;

  /**
   * correct 非有限 = 这道题在这批数据上根本出不来(段数切不满两半、点不够算比值)。
   * 此时返回 null 而不是某个码:调用方据此**一个事实都不写**,判据不响、不扣分。
   * "没交"与"没出题"是两件事,不能共用一个码。
   */
  static match(answer: number, correct: number, prints: Fingerprint[],
    tol: number): AnswerOutcome | null {
    if (!Number.isFinite(correct) || correct === 0) {
      return null;
    }
    const out = new AnswerOutcome();
    if (!Number.isFinite(answer)) {
      out.code = ANSWER_MISSING;
      return out;
    }
    out.relErr = (answer - correct) / Math.abs(correct) * 100;
    if (Math.abs(out.relErr) <= tol) {
      out.code = ANSWER_OK;
      return out;
    }
    out.code = ANSWER_WRONG;
    for (let i = 0; i < prints.length; i++) {
      const f = prints[i];
      if (!Number.isFinite(f.value) || f.value === 0) {
        continue;
      }
      if (Math.abs((answer - f.value) / Math.abs(f.value) * 100) <= AnswerCheck.MATCH_TOL) {
        out.wrongKind = f.id;
        return out;
      }
    }
    return out;
  }
}
```

---

### Task 2: 声明填空,并让它进文案闸门

**Files:** Modify `entry/src/main/ets/model/ExperimentTypes.ets`、`entry/src/main/ets/scenes/SceneBuilders.ets`、`tools/physics-check/check.mjs`

**Interfaces:** Produces `class SubmissionDef { key, taskKey, label, unit, precision }`、`ExperimentMeta.submissions: SubmissionDef[]`、`SceneBuilders.submission(key, taskKey, label, unit, precision)`

- [ ] **Step 1** 写失败的断言:`check.mjs` 里紧接 `for (const t of meta.tasks) push(...)` 之后加

```js
    // 填空的问句是印在实验页上让学生照着算的,漏进闸门就等于新写一类文案没人管标点
    for (const s of meta.submissions) push(`${meta.id} 填空`, s.label);
```

并在 `check('注册表里的场景数', ...)` 之前加:

```js
  // 填空必须挂在真存在的任务下:挂错了,页面上那一栏找不到归属,渲染成孤儿
  const orphan = [];
  for (const m of ExperimentRegistry.all()) {
    for (const s of m.submissions) {
      if (!m.tasks.some((t) => t.key === s.taskKey)) {
        orphan.push(`${m.id}/${s.key}→${s.taskKey}`);
      }
    }
  }
  assertTrue('每个填空都挂在真声明了的任务下', orphan.length === 0, orphan.join(' | '));
```

- [ ] **Step 2** 跑 → 预期 `Cannot read properties of undefined (reading 'length')`
- [ ] **Step 3** 写实现:`ExperimentTypes.ets` 在 `TaskDef` 之后加

```ts
/**
 * 学生要交的一个数。
 *
 * 它和 ObservableDef 的方向正好相反:observable 是应用报给他看的数,submission 是他
 * 自己处理出来的数。所以 label 得把"用哪几个数、按什么流程算"说清 ——
 * 屏幕上不会给他别处找不到的提示。
 */
export class SubmissionDef {
  key: string = ''
  /** 挂在哪个 taskKey 下面渲染 */
  taskKey: string = ''
  label: string = ''
  unit: string = ''
  precision: number = 2
}
```

`ExperimentMeta` 里紧跟 `tasks` 之后加 `submissions: SubmissionDef[] = []`;`SceneBuilders.ets` 在 `observable(...)` 之后加

```ts
  /** 学生要交的一个数。taskKey 必须指向本场景已声明的任务(由断言守) */
  static submission(key: string, taskKey: string, label: string,
    unit: string, precision: number): SubmissionDef {
    const def = new SubmissionDef();
    def.key = key;
    def.taskKey = taskKey;
    def.label = label;
    def.unit = unit;
    def.precision = precision;
    return def;
  }
```

两个文件的 import 各补 `SubmissionDef`。

- [ ] **Step 4** 跑 → `✓ ...`(还没有场景声明填空,orphan 断言空跑为真,Task 5/9 会真填上)
- [ ] **Step 5** 构建 + 提交:`git commit -m "填数通道 2:meta 声明填空,并把填空问句与任务文本一起进文案闸门"`

---

### Task 3: runner 收下答案,并在重置时清掉

**Files:** Modify `entry/src/main/ets/runner/IExperimentRunner.ets`、`entry/src/main/ets/physics/Physics2DRunner.ets`、`entry/src/main/ets/bench/BenchWorld.ets`(预检 `grep -rln "implements IExperimentRunner"` 实测就这两个实现者);Test `tools/physics-check/check.mjs`

**Interfaces:** Produces `setAnswer(key: string, value: number): void`、`answer(key: string): number`(未填为 NaN)

- [ ] **Step 1** 先数清接口的实现者:`grep -rln "implements IExperimentRunner" entry/src/main/ets/`。接口加方法会让所有实现者编译失败,漏一个就是构建红 —— 把它们全写进 Files。
- [ ] **Step 2** 写失败的断言:

```js
// ---- 学生填数通道 2:答案进 runner,重置要清干净 --------------------------------
// 交卷时读的是 runner 里的答案,"换一条纸带还留着上一次填的数"会直接判错人。
{
  const { ExperimentRegistry } = require(join(OUT, 'runner/ExperimentRegistry.cjs'));
  const runner = ExperimentRegistry.createRunner('tape-cart');
  runner.setup(ExperimentRegistry.find('tape-cart').meta);
  assertTrue('没填时读到 NaN 而不是 0(0 是合法的数,不能当缺省)',
    !Number.isFinite(runner.answer('tapeNumerator')), String(runner.answer('tapeNumerator')));
  runner.setAnswer('tapeNumerator', 180);
  check('填进去就读得到', runner.answer('tapeNumerator'), 180, 1e-12);
  runner.setAnswer('tapeNumerator', Number.NaN);
  assertTrue('清空回到没填', !Number.isFinite(runner.answer('tapeNumerator')), 'x');
  runner.setAnswer('tapeNumerator', 180);
  runner.reset();
  assertTrue('重置把答案一起清掉', !Number.isFinite(runner.answer('tapeNumerator')),
    String(runner.answer('tapeNumerator')));
}
```

- [ ] **Step 3** 跑 → 预期 `runner.setAnswer is not a function`
- [ ] **Step 4** 写实现:接口里 `setParam` 之后加

```ts
  /**
   * 学生交上来的一个处理结果。与 setParam 的区别是方向:那是我们施给世界的条件,
   * 这是他算出来的结论 —— 判定层读的是"它和这批数据应得的结果差多少",不是它本身。
   * 传 NaN 表示清空这一格。
   */
  setAnswer(key: string, value: number): void;
```

`readObservable` 之后加 `/** 学生填过的值;没填一律 NaN,不得用 0 兜底 */ answer(key: string): number;`

`Physics2DRunner.ets`:`protected time` 之后加 `protected answers: Map<string, number> = new Map();`;`setup()` 与 `reset()` 各自的 `this.onSetup();` 之前加 `this.answers.clear();`;`getParam` 之后加

```ts
  setAnswer(key: string, value: number): void {
    this.answers.set(key, value);
  }

  answer(key: string): number {
    const hit = this.answers.get(key);
    return hit === undefined ? Number.NaN : hit;
  }
```

其余实现者同样补上(不需要判填空的场景,转调自己的一张 Map,不要抛异常)。

- [ ] **Step 5** 断言 + 构建都过
- [ ] **Step 6** 提交:`git commit -m "填数通道 3:runner 收下答案,重置一并清空;没填读 NaN 不用 0 兜底"`

---

### Task 4: 纸带段长出口 + sr-003 的 procedure

**Files:** Modify `entry/src/main/ets/physics/TickerTape.ets`;Create `entry/src/main/ets/physics/TapeChunkProcedure.ets`;Test `tools/physics-check/check.mjs`

**Interfaces:** Consumes `dotAt(i).s`(累计米)、`segmentCount(start, every)`;Produces `segmentsMm(start, every): number[]`、`TapeChunkProcedure.numerator(segMm)`、`.denFactor(segMm)`、`.denPrints(segMm)`、`.fingerprints(segMm): Fingerprint[]`

- [ ] **Step 1** `MODULES` 里 `'physics/AnswerCheck',` 之后加 `'physics/TapeChunkProcedure',`
- [ ] **Step 2** 写失败的断言:

```js
// ---- 学生填数通道 3:逐差法的正确值与四种错法指纹 --------------------------------
{
  const { TapeChunkProcedure } = require(join(OUT, 'physics/TapeChunkProcedure.cjs'));
  // 样例纸带:a=2 m/s²、T=0.1 s、六段 50..150 mm(spec §5 那张表)
  const s = [50, 70, 90, 110, 130, 150];
  check('分子 = 后三段之和 减 前三段之和', TapeChunkProcedure.numerator(s), 180, 1e-9);
  check('分母里 T² 的倍数 = h²', TapeChunkProcedure.denFactor(s), 9, 0);
  const print = {};
  for (const f of TapeChunkProcedure.fingerprints(s)) print[f.id] = f.value;
  check('F1 只吃首尾', print[1], 100, 1e-9);
  check('F2 相邻逐段平均', print[2], 20, 1e-9);
  check('F3 相邻配对', print[3], 60, 1e-9);
  check('F4 单位错(放大一千倍)', print[4], 180000, 1e-6);
  check('F5 单位错(缩小一千倍)', print[5], 0.18, 1e-12);
  const den = {};
  for (const f of TapeChunkProcedure.denPrints(s)) den[f.id] = f.value;
  check('D1 漏乘段数平方', den[1], 1, 0);
  check('D2 只乘 h', den[2], 3, 0);
  check('D3 拿总段数平方', den[3], 36, 0);
  // 负对照:指纹之间、指纹与正确值之间必须分得开,否则判词会指着学生说他犯了个没犯的错
  const tapes = [[50, 70, 90, 110, 130, 150], [50, 51, 52, 53, 54, 55],
    [12, 20, 28, 36, 44, 52], [5, 7, 9, 11], [30, 45, 60, 75, 90, 105, 120, 135]];
  let worst = 100;
  let where = '';
  for (const t of tapes) {
    const values = [TapeChunkProcedure.numerator(t), TapeChunkProcedure.denFactor(t)];
    for (const f of TapeChunkProcedure.fingerprints(t)) values.push(f.value);
    for (const f of TapeChunkProcedure.denPrints(t)) values.push(f.value);
    for (let i = 0; i < values.length; i++) {
      for (let j = i + 1; j < values.length; j++) {
        const gap = Math.abs(values[i] - values[j]) / Math.abs(values[i]) * 100;
        if (gap < worst) { worst = gap; where = t.join(',') + ` #${i}vs#${j}`; }
      }
    }
  }
  assertTrue('正确值与各指纹两两至少差 20%', worst >= 20, `最小 ${worst.toFixed(1)}% @ ${where}`);
  assertTrue('三段切不出两半 → 分子 NaN',
    !Number.isFinite(TapeChunkProcedure.numerator([50, 70, 90])), 'x');
  assertTrue('三段 → 倍数 NaN', !Number.isFinite(TapeChunkProcedure.denFactor([50, 70, 90])), 'x');
  check('空纸带 → 没有指纹可点名', TapeChunkProcedure.fingerprints([]).length, 0, 0);
  // 奇数段:只用前 2h 段,尾巴那段不参与(与 accelByChunking 的取窗一致)
  check('七段时按前六段算,与 accelByChunking 同窗',
    TapeChunkProcedure.numerator([50, 70, 90, 110, 130, 150, 999]), 180, 1e-9);
}
```

- [ ] **Step 3** 跑 → 预期模块不存在
- [ ] **Step 4** 写 `TickerTape.segmentsMm`,放在 `shortestSegment(...)` 之后:

```ts
  /**
   * 每一计数段的长度(毫米)。逐差法要的是"这几段各多长",不是段数也不是最短那段。
   *
   * 给毫米而不是米:学生拿毫米刻度尺量出来的就是这个数,判他的数与判他量的数同一单位,
   * 中间不再有一次换算 —— 少一次换算就少一处"到底是谁错了"的扯皮。
   */
  segmentsMm(start: number, every: number): number[] {
    const step = every < 1 ? 1 : every;
    const from = start < 0 ? 0 : start;
    const out: number[] = [];
    const n = this.segmentCount(from, step);
    for (let i = 0; i < n; i++) {
      const here = this.dotAt(from + i * step);
      const next = this.dotAt(from + (i + 1) * step);
      if (here === null || next === null) {
        break;
      }
      out.push((next.s - here.s) * 1000);
    }
    return out;
  }
```

- [ ] **Step 5** 写 `entry/src/main/ets/physics/TapeChunkProcedure.ets`:

```ts
import { Fingerprint } from './AnswerCheck';

/** 参与运算的段数:前后两半各 h 段,凑不满 2h 段就出不了这道题 */
function half(segMm: number[]): number {
  const h = Math.floor(segMm.length / 2);
  return h < 2 ? 0 : h;
}

function of(id: number, value: number): Fingerprint {
  const f = new Fingerprint();
  f.id = id;
  f.value = value;
  return f;
}

/**
 * 「测匀变速直线运动的加速度」的数据处理层。
 *
 * 纯函数:进一串段长(毫米),出正确流程的答案与几种典型错法的答案。放 runner 里
 * 就测不到这么细,放细则里就等于让判分模块懂物理 —— 两头都不合适。
 *
 * 取窗与 TickerTape.accelByChunking 一致:用前 2h 段,尾巴上凑不满一对的那段丢掉。
 */
export class TapeChunkProcedure {
  /** 分子 = 后 h 段之和 减 前 h 段之和(毫米)。逐差法里"用上全部数据"的那一步 */
  static numerator(segMm: number[]): number {
    const h = half(segMm);
    if (h === 0) {
      return Number.NaN;
    }
    let sum = 0;
    for (let i = 0; i < h; i++) {
      sum += segMm[h + i] - segMm[i];
    }
    return sum;
  }

  /** 分母里 T² 的倍数。a = 分子 /(倍数 · T²),分母单独问一遍:漏乘平方是高频错 */
  static denFactor(segMm: number[]): number {
    const h = half(segMm);
    return h === 0 ? Number.NaN : h * h;
  }

  /** 分子的错法,顺序即 spec §5 那张表 */
  static fingerprints(segMm: number[]): Fingerprint[] {
    const h = half(segMm);
    if (h === 0) {
      return [];
    }
    const first = segMm[0];
    const last = segMm[2 * h - 1];
    const correct = TapeChunkProcedure.numerator(segMm);
    let paired = 0;
    for (let i = 0; i + 1 < 2 * h; i += 2) {
      paired += segMm[i + 1] - segMm[i];
    }
    const out: Fingerprint[] = [];
    out.push(of(1, last - first));
    out.push(of(2, (last - first) / (2 * h - 1)));
    out.push(of(3, paired));
    out.push(of(4, correct * 1000));
    out.push(of(5, correct / 1000));
    return out;
  }

  /** 分母那一格的错法:漏乘平方、只乘 h、拿总段数平方 */
  static denPrints(segMm: number[]): Fingerprint[] {
    const h = half(segMm);
    if (h === 0) {
      return [];
    }
    const out: Fingerprint[] = [];
    out.push(of(1, 1));
    out.push(of(2, h));
    out.push(of(3, 2 * h * 2 * h));
    return out;
  }
}
```

- [ ] **Step 6** 跑 → `✓ ...`。**若"两两至少差 20%"红了,不要放宽阈值**:说明某条纸带上两条指纹会撞车,处理办法是删掉撞车的那条指纹(宁可点不出名,也不指认一个没犯过的错)。
- [ ] **Step 7** 提交:`git commit -m "填数通道 4:纸带段长出口 + 逐差法 procedure(正确分子、分母倍数、错法值,自带互斥负对照)"`

---

### Task 5: sr-003 接线 —— 事实、枚举标签、填空声明

**Files:** Modify `entry/src/main/ets/physics/Physics2DRunner.ets`、`entry/src/main/ets/physics/TapeCartRunner.ets`、`entry/src/main/ets/model/FactLabels.ets`、`entry/src/main/ets/bench/Judgment.ets`、`entry/src/main/ets/scenes/MechanicsScenes.ets`;Test `tools/physics-check/check.mjs`

**Interfaces:** Consumes `AnswerCheck.match`、`TapeChunkProcedure`、`this.tape.segmentsMm(start, every)`、`this.answer(key)`;Produces 事实键 `ans.tapeNumerator`、`tapeNumeratorTrue`、`tapeNumeratorOutcome`、`tapeNumeratorWrongKind`、`ans.tapeDenFactor`、`tapeDenFactorTrue`、`tapeDenFactorOutcome`、`tapeDenFactorWrongKind`

- [ ] **Step 1** `Physics2DRunner.ets` 加共用工具(import `AnswerCheck`、`Fingerprint`、`FactSheet` 已在):

```ts
  /**
   * 把一格填空的结果码写进事实。
   *
   * correct 非有限 = 这道题在这批数据上出不来 → 一个事实都不写,判据不响。
   * 这是"没交扣分、没出题不扣"那条界线的唯一实现处。
   */
  protected checkNumber(sheet: FactSheet, key: string, correct: number,
    prints: Fingerprint[], tol: number): void {
    const outcome = AnswerCheck.match(this.answer(key), correct, prints, tol);
    if (outcome === null) {
      return;
    }
    sheet.set('ans.' + key, this.answer(key));
    sheet.set(key + 'True', correct);
    sheet.set(key + 'Outcome', outcome.code);
    sheet.set(key + 'WrongKind', outcome.wrongKind);
  }
```

- [ ] **Step 2** `FactLabels.ets`:`FactLabel` 类加字段

```ts
  /** 结果码这类事实印成裸 0/1/2 学生读不懂;给一张码→人话的表 */
  codes: Map<number, string> | null = null;
```

`valueText` 里,在 `if (hit !== null && hit.boolean)` **之前**插入:

```ts
    if (hit !== null && hit.codes !== null) {
      const text = hit.codes.get(value);
      if (text !== undefined) {
        return text;
      }
    }
```

加工厂:

```ts
  /** 结果码类事实:0 算对 / 1 算错 / 2 没交。判据标题与证据模板仍在细则里,这里只管读数 */
  static coded(label: string): FactLabel {
    const entry = new FactLabel(label, '');
    const codes = new Map<number, string>();
    codes.set(0, '算对了');
    codes.set(1, '算错了');
    codes.set(2, '没交');
    entry.codes = codes;
    return entry;
  }

  /** 只有带 codes 表的事实键才走这条路;其余事实照旧由 Judgment 按数字格式化 */
  static codedText(key: string, value: number): string | null {
    const hit = FactLabels.of(key);
    if (hit === null || hit.codes === null) {
      return null;
    }
    const text = hit.codes.get(value);
    return text === undefined ? null : text;
  }
```

`bench/Judgment.ets` 的 `fill()` 里,把 `facts.numbers.forEach` 那个回调换成:

```ts
    facts.numbers.forEach((factValue: number, key: string) => {
      const coded = FactLabels.codedText(key, factValue);
      out = out.split('{' + key + '}').join(coded === null ? Judgment.text(factValue) : coded);
    });
```

(顶部 import `FactLabels`。这一步不能省:`fill()` 原本只按数字格式化,不改的话细则模板里的
`{tapeNumeratorOutcome}` 会印成裸 `2`,Task 6 那条"判词读得通"的断言也立不住。
不给所有事实统一换成 `FactLabels.valueText` —— 那个会追加单位,会把全部既有细则的数字格式一起换掉。)

`buildTable()` 里加八条:

```ts
    table.set('tapeNumeratorOutcome', FactLabels.coded('逐差法分子判定'));
    table.set('tapeDenFactorOutcome', FactLabels.coded('逐差法分母判定'));
    table.set('ans.tapeNumerator', new FactLabel('你交的逐差法分子', ' mm'));
    table.set('ans.tapeDenFactor', new FactLabel('你交的分母倍数', ''));
    table.set('tapeNumeratorTrue', new FactLabel('逐差法分子应有值', ' mm'));
    table.set('tapeDenFactorTrue', new FactLabel('分母倍数应有值', ''));
    table.set('tapeNumeratorWrongKind', new FactLabel('分子错法', ''));
    table.set('tapeDenFactorWrongKind', new FactLabel('分母错法', ''));
```

- [ ] **Step 3** 写失败的断言:

```js
// ---- 学生填数通道 4:sr-003 两条填空进事实,守住"没交/没出题"两条路径 -------------
{
  const { ExperimentRegistry } = require(join(OUT, 'runner/ExperimentRegistry.cjs'));
  const { FactSheet } = require(join(OUT, 'model/FactSheet.cjs'));
  const { FactLabels } = require(join(OUT, 'model/FactLabels.cjs'));
  const meta = ExperimentRegistry.find('tape-cart').meta;
  function factsOf(steps, answers) {
    const runner = ExperimentRegistry.createRunner('tape-cart');
    runner.setup(meta);
    for (const [k, v] of steps) {
      if (k === 'act') { runner.doAction(v); }
      else if (k === 'run') { for (let i = 0; i < v; i++) runner.step(1 / 60); }
      else if (k === 'param') { runner.setParam(v[0], v[1]); }
      else { runner.setAnswer(v[0], v[1]); }
    }
    const sheet = new FactSheet();
    runner.collectFacts(sheet);
    return sheet;
  }
  const RUN_TAPE = [['act', 'power'], ['run', 90], ['act', 'release'], ['run', 150]];

  const blank = factsOf(RUN_TAPE, []);
  check('一条没填:分子算"没交"', blank.num('tapeNumeratorOutcome'), 2, 0);
  check('一条没填:分母也算"没交"', blank.num('tapeDenFactorOutcome'), 2, 0);
  assertTrue('没交时应有值仍然量得出', Number.isFinite(blank.num('tapeNumeratorTrue')), 'x');
  checkText('结果码印成人话而不是裸 2', FactLabels.valueText('tapeNumeratorOutcome', 2), '没交');

  const right = factsOf(RUN_TAPE, [['ans', ['tapeNumerator', blank.num('tapeNumeratorTrue')]],
    ['ans', ['tapeDenFactor', blank.num('tapeDenFactorTrue')]]]);
  check('照应有值填 → 分子算对', right.num('tapeNumeratorOutcome'), 0, 0);
  check('分母也判对', right.num('tapeDenFactorOutcome'), 0, 0);
  check('说不出错法时错法码为 0', right.num('tapeNumeratorWrongKind'), 0, 0);

  const short = factsOf([['param', ['countEvery', 10]], ['act', 'power'], ['run', 40],
    ['act', 'release'], ['run', 20]], [['ans', ['tapeNumerator', 180]]]);
  assertTrue('段数切不出两半 → 分子不写事实(这题没出,不扣分)',
    !Number.isFinite(short.num('tapeNumeratorOutcome')), String(short.num('tapeNumeratorOutcome')));

  const wrong = factsOf(RUN_TAPE, [['ans', ['tapeDenFactor', 3]], ['ans', ['tapeNumerator', 100]]]);
  check('分母只乘 h → 算错', wrong.num('tapeDenFactorOutcome'), 1, 0);
  check('分母错法点名 D2', wrong.num('tapeDenFactorWrongKind'), 2, 0);
  check('分子填成 F1 的值 → 算错且点名', wrong.num('tapeNumeratorWrongKind'), 1, 0);
}
```

- [ ] **Step 4** 跑 → 预期事实键全 NaN;然后写实现。

`TapeCartRunner.ets` import `TapeChunkProcedure`,在 `onCollectFacts` 的 `sheet.mark('taped', ...)` 之前加:

```ts
    const segMm = this.tape.segmentsMm(start, every);
    this.checkNumber(sheet, 'tapeNumerator', TapeChunkProcedure.numerator(segMm),
      TapeChunkProcedure.fingerprints(segMm), 3);
    this.checkNumber(sheet, 'tapeDenFactor', TapeChunkProcedure.denFactor(segMm),
      TapeChunkProcedure.denPrints(segMm), 0);
```

`MechanicsScenes.ets` 的 `tapeCart()` 里,两条 `meta.tasks` 之后:

```ts
    meta.submissions.push(SceneBuilders.submission('tapeNumerator', 'tape-a-by-difference',
      '逐差法的分子：后三段之和 减 前三段之和', 'mm', 1));
    meta.submissions.push(SceneBuilders.submission('tapeDenFactor', 'tape-a-by-difference',
      '分母里 T² 的倍数（a = 分子 ÷（倍数 × T²））', '', 0));
```

- [ ] **Step 5** 跑 → `✓ ...`;构建 → `BUILD SUCCESSFUL`
- [ ] **Step 6** 提交:`git commit -m "填数通道 5:sr-003 两条填空进事实;结果码印成人话;没交扣分、这题没出不写事实"`

---

### Task 6: sr-003 细则 —— 加两条、重排分值、升版本

**Files:** Modify `entry/src/main/ets/bench/RubricTape.ets`;Test `tools/physics-check/check.mjs`

**Interfaces:** Consumes `tapeNumeratorOutcome`、`tapeDenFactorOutcome`;Produces 判据 `tape-numerator-value`、`tape-den-factor-value`,版本 `2026.10.1`

- [ ] **Step 1** 写失败的断言:

```js
// ---- 学生填数通道 5:sr-003 细则重排后仍必须能被满足 ----------------------------
{
  const { RubricTape } = require(join(OUT, 'bench/RubricTape.cjs'));
  const { Judgment } = require(join(OUT, 'bench/Judgment.cjs'));
  const { FactSheet } = require(join(OUT, 'model/FactSheet.cjs'));
  const rubric = RubricTape.create();
  check('细则六条', rubric.criteria.length, 6, 0);
  let sum = 0;
  for (const c of rubric.criteria) sum += c.points;
  check('总分仍是 100', sum, 100, 0);
  checkText('版本随判据变更升过', rubric.version, '2026.10.1');
  const sheet = new FactSheet();
  sheet.set('tapeDotCount', 120);
  sheet.set('tapeLostHead', 0);
  sheet.set('tapeShortestMm', 18);
  sheet.set('tapeSegments', 6);
  sheet.set('tapeNumeratorOutcome', 2);
  sheet.set('tapeDenFactorOutcome', 2);
  const missing = Judgment.score(rubric, sheet);
  check('手上功夫做足、两格都没交 → 只剩 60 分', missing.awarded, 60, 1e-9);
  check('没交扣两条', missing.deductions.length, 2, 0);
  sheet.set('tapeNumeratorOutcome', 0);
  sheet.set('tapeDenFactorOutcome', 0);
  check('都填对 → 满分', Judgment.score(rubric, sheet).awarded, 100, 1e-9);
  sheet.set('tapeNumeratorOutcome', 1);
  sheet.set('tapeNumeratorWrongKind', 1);
  const hit = Judgment.score(rubric, sheet);
  check('分子算错 → 只扣这一条', hit.deductions.length, 1, 0);
  checkText('判词读得通:没交与算错两种说法都出现过',
    missing.deductions[0].evidence.indexOf('没交') > 0 ? 'yes' : 'no', 'yes');
}
```

- [ ] **Step 2** 跑 → 预期"四条 / 版本仍是 2026.10"
- [ ] **Step 3** 改 `RubricTape.ets`:`VERSION` → `'2026.10.1'`;既有四条的 `25` 全改 `15`;`fewSegments` 之后加:

```ts
    // 数据处理这两条读的是结果码:0 算对、1 算错、2 没交 —— 判据本身不懂物理
    const numerator = CriterionBuilder.numeric('tape-numerator-value',
      '逐差法这一问没算对或没交',
      CriterionOp.GT, 'tapeNumeratorOutcome', 0, 0, 20,
      '你交的分子是 {ans.tapeNumerator} mm，这条纸带按逐差法应为 {tapeNumeratorTrue} mm，判定：{tapeNumeratorOutcome}。分子要把后三段与前一段一一对齐相减：只用首尾两段会把中间量出来的数全丢掉，相邻两两相减又退化成逐段平均');
    const denFactor = CriterionBuilder.numeric('tape-den-factor-value',
      '逐差法分母这一问没算对或没交',
      CriterionOp.GT, 'tapeDenFactorOutcome', 0, 0, 20,
      '你交的分母倍数是 {ans.tapeDenFactor}，判定：{tapeDenFactorOutcome}，这条纸带该是 {tapeDenFactorTrue}：漏乘段数平方会把加速度放大好几倍，拿总段数平方又多吃了一倍');
    rubric.criteria.push(numerator);
    rubric.criteria.push(denFactor);
```

标题写成"没算对或没交"而不是"算错了",是因为同一条判据要同时容纳 code=1 与 code=2 —— 学生看到"算错了"却知道自己没填,会以为应用吞了他的输入。

- [ ] **Step 4** 跑 → `✓ ...`
- [ ] **Step 5** 提交:`git commit -m "填数通道 6:sr-003 细则加两条数据处理判据,分值 4×25 → 4×15+2×20,版本升 2026.10.1"`

---

### Task 7: 实验页渲染「要交的结论」(全工程第一个 TextInput)

**Files:** Modify `entry/src/main/ets/pages/ExperimentPage.ets`;Test:构建 + Task 10 的设备探针

**Interfaces:** Consumes `meta.tasks`、`meta.submissions`、`runner.setAnswer`;Produces `@State answerTexts: string[]`(与 `meta.submissions` 同序)、`onAnswerChange(index, text)`

- [ ] **Step 1** `@State verdict: string = '';` 之后加:

```ts
  /** 与 meta.submissions 同序;空串表示这一格没填 */
  @State answerTexts: string[] = [];
```

- [ ] **Step 2** `onParamChange` 之后加回调(注意沿用既有的 slice + 重新赋值写法,@State 数组按下标改不触发刷新):

```ts
  /**
   * 学生改了一格填空。
   *
   * 这里刻意什么都不判:即时回显对错会把"算"变成"猜"—— 二分几次就能逼近到满分,
   * 那时判的就不再是会不会处理数据。判定只在交卷那一次发生。
   */
  private onAnswerChange(index: number, text: string): void {
    if (this.runner === null || index >= this.meta.submissions.length) {
      return;
    }
    const def = this.meta.submissions[index];
    const trimmed = text.trim();
    const value = trimmed.length > 0 ? Number(trimmed) : Number.NaN;
    this.runner.setAnswer(def.key, Number.isNaN(value) ? Number.NaN : value);
    const next = this.answerTexts.slice();
    next[index] = text;
    this.answerTexts = next;
  }
```

- [ ] **Step 3** 载入场景处(初始化 `paramValues` 的那一段旁边)同步清空:

```ts
    const answers: string[] = [];
    for (let i = 0; i < this.meta.submissions.length; i++) {
      answers.push('');
    }
    this.answerTexts = answers;
```

- [ ] **Step 4** `panelContent()` 里,读数那个 `Column({...}).width('100%')` 之后追加:

```ts
        if (this.meta.tasks.length > 0) {
          Divider().color(Theme.DIVIDER)

          Text('要交的结论')
            .fontSize(Layout.sectionSize(this.cls()))
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)

          Column({ space: 12 }) {
            ForEach(this.meta.tasks, (task: TaskDef) => {
              Column({ space: 8 }) {
                Text(task.prompt)
                  .fontSize(Layout.bodySize(this.cls()))
                  .fontColor(Theme.TEXT_PRIMARY)
                ForEach(this.meta.submissions, (def: SubmissionDef, index: number) => {
                  if (def.taskKey === task.key) {
                    Column({ space: 4 }) {
                      Text(def.label)
                        .fontSize(Layout.labelSize(this.cls()))
                        .fontColor(Theme.TEXT_SECONDARY)
                      Row({ space: 8 }) {
                        TextInput({
                          text: this.answerTexts.length > index ? this.answerTexts[index] : '',
                          placeholder: '把你算出的数填进来'
                        })
                          .type(InputType.Number)
                          .fontSize(Layout.readoutSize(this.cls()))
                          .fontColor(Theme.TEXT_PRIMARY)
                          .layoutWeight(1)
                          .onChange((value: string) => {
                            this.onAnswerChange(index, value);
                          })
                        if (def.unit.length > 0) {
                          Text(def.unit)
                            .fontSize(Layout.labelSize(this.cls()))
                            .fontColor(Theme.TEXT_SECONDARY)
                        }
                      }
                      .width('100%')
                    }
                    .width('100%')
                    .alignItems(HorizontalAlign.Start)
                  }
                }, (def: SubmissionDef) => def.key)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }, (task: TaskDef) => task.key)
          }
          .width('100%')
        }
```

import 补 `TaskDef`、`SubmissionDef`。**不给 TextInput 写死底色** —— 沿用页面既有卡片色常量;深浅色令牌非空由源码守卫那条断言管。

- [ ] **Step 5** 构建 → `BUILD SUCCESSFUL`
- [ ] **Step 6** 提交:`git commit -m "填数通道 7:实验页第一次渲染任务正文与填空(全工程第一个 TextInput);输入时不回显任何对错"`

---

### Task 8: sr-007 —— 点旁标 y + 反求 g 的 procedure

**Files:** Modify `entry/src/main/ets/physics/ProjectileRunner.ets`;Create `entry/src/main/ets/physics/ProjectileGProcedure.ets`;Test `tools/physics-check/check.mjs`

**Interfaces:** Produces `ProjectileGProcedure.gFromPoint(yMm, xMm, v0)`、`.fingerprints(yMm, xMm, v0)`、`.segmentRatio(yMmFirstTwo)`、`.ratioFingerprints(yMmFirstTwo)`

- [ ] **Step 1** `MODULES` 加 `'physics/ProjectileGProcedure',`;写失败的断言:

```js
// ---- 学生填数通道 6:sr-007 反求 g 与竖直段比,含各自指纹 ------------------------
{
  const { ProjectileGProcedure } = require(join(OUT, 'physics/ProjectileGProcedure.cjs'));
  const G = 9.8;
  const v0 = Math.sqrt(2 * G * 4 * 0.05);            // 斜槽第 4 格
  const xs = [0.15, 0.30, 0.45, 0.60];
  const ysMm = xs.map((x) => 0.5 * G * Math.pow(x / v0, 2) * 1000);
  check('由第 2 个点反求 g', ProjectileGProcedure.gFromPoint(ysMm[1], 300, v0), 9.8, 1e-6);
  const print = {};
  for (const f of ProjectileGProcedure.fingerprints(ysMm[1], 300, v0)) print[f.id] = f.value;
  check('G1 漏乘 2', print[1], 4.9, 1e-6);
  check('G2 把 x 当时间', print[2], 2 * (ysMm[1] / 1000) / Math.pow(0.3, 2), 1e-6);
  check('G4 单位错(放大一千倍)', print[4], 9800, 1e-3);
  check('竖直段比:从抛出点数起 1:3 → 3.00',
    ProjectileGProcedure.segmentRatio([ysMm[0], ysMm[1]]), 3, 1e-6);
  check('段比指纹 V1 是两点总位移之比',
    ProjectileGProcedure.ratioFingerprints([ysMm[0], ysMm[1]])[0].value, 4, 1e-6);
  let worst = 100;
  for (const y of [ysMm[0], ysMm[1], ysMm[2]]) {
    const values = [ProjectileGProcedure.gFromPoint(y, 300, v0)];
    for (const f of ProjectileGProcedure.fingerprints(y, 300, v0)) values.push(f.value);
    for (let i = 0; i < values.length; i++) {
      for (let j = i + 1; j < values.length; j++) {
        worst = Math.min(worst, Math.abs(values[i] - values[j]) / Math.abs(values[i]) * 100);
      }
    }
  }
  assertTrue('g 的正确值与各指纹两两至少差 20%', worst >= 20, `最小 ${worst.toFixed(1)}%`);
  assertTrue('一个点也算不出 g(y 为 0 时)', !Number.isFinite(ProjectileGProcedure.gFromPoint(0, 300, v0)), 'x');
  assertTrue('两个点以下算不出段比', !Number.isFinite(ProjectileGProcedure.segmentRatio([30])), 'x');
}
```

- [ ] **Step 2** 跑 → 预期模块不存在
- [ ] **Step 3** 写 `entry/src/main/ets/physics/ProjectileGProcedure.ets`:

```ts
import { Fingerprint } from './AnswerCheck';

function of(id: number, value: number): Fingerprint {
  const f = new Fingerprint();
  f.id = id;
  f.value = value;
  return f;
}

/**
 * 「探究平抛运动的特点」的数据处理层。
 *
 * y = g·x²/(2v0²) 反解出 g = 2·(y/x²)·v0²。这一步是这条实验的全部落点:它同时说明
 * 水平分运动匀速(x 与 t 成正比)与竖直分运动是自由落体(y 与 t² 成正比)。
 * 面板给的是 y/x² 的**离散度**,没给 g —— 学生必须自己把这三个量凑一次。
 */
export class ProjectileGProcedure {
  /** 由一个点反求 g。yMm、xMm 都是毫米,v0 米每秒 */
  static gFromPoint(yMm: number, xMm: number, v0: number): number {
    if (!(yMm > 0) || !(xMm > 0) || !(v0 > 0)) {
      return Number.NaN;
    }
    const y = yMm / 1000;
    const x = xMm / 1000;
    return 2 * (y / (x * x)) * v0 * v0;
  }

  /** G1 漏乘 2、G2 把 x 当时间、G4/G5 单位错。G3(板角坐标)由调用方喂错数据自然命中 */
  static fingerprints(yMm: number, xMm: number, v0: number): Fingerprint[] {
    const correct = ProjectileGProcedure.gFromPoint(yMm, xMm, v0);
    if (!Number.isFinite(correct)) {
      return [];
    }
    const y = yMm / 1000;
    const x = xMm / 1000;
    const out: Fingerprint[] = [];
    out.push(of(1, correct / 2));
    out.push(of(2, 2 * y / (x * x)));
    out.push(of(4, correct * 1000));
    out.push(of(5, correct / 1000));
    return out;
  }

  /**
   * 竖直方向第二段与第一段位移之比。等水平间隔下,从抛出点数起应当是 1:3:5:7 → 3。
   *
   * 传进来的必须是**已定原点**那套坐标下的 y:没定原点时这个比根本不是这个意思,
   * 那种情形由 g 那一格的 G3 去点名,不在这里重复判。
   */
  static segmentRatio(yMmFirstTwo: number[]): number {
    if (yMmFirstTwo.length < 2 || !(yMmFirstTwo[0] > 0)) {
      return Number.NaN;
    }
    const first = yMmFirstTwo[0];
    const second = yMmFirstTwo[1] - yMmFirstTwo[0];
    if (!(second > 0)) {
      return Number.NaN;
    }
    return second / first;
  }

  /** V1 拿两点总位移之比(y₂/y₁ = 4)、V2 以为每段翻倍 */
  static ratioFingerprints(yMmFirstTwo: number[]): Fingerprint[] {
    const correct = ProjectileGProcedure.segmentRatio(yMmFirstTwo);
    if (!Number.isFinite(correct)) {
      return [];
    }
    return [of(1, yMmFirstTwo[1] / yMmFirstTwo[0]), of(2, 2)];
  }
}
```

- [ ] **Step 4** `ProjectileRunner.snapshot()` 的描点循环里,`this.snap.circles.push(dot);` 之后加点旁标签:

```ts
      this.snap.labels.push(this.text('y=' + (p.y * 1000).toFixed(1),
        dot.cx + 0.09, dot.cy - 0.11, 'left', 10));
```

- [ ] **Step 5** 跑 → `✓ ...`;构建 → 绿
- [ ] **Step 6** 提交:`git commit -m "填数通道 8:描下的点在旁边标出 y(这条实验此前量不到自己的点)+ 反求 g 与竖直段比的 procedure"`

---

### Task 9: sr-007 接线 + 细则重排

**Files:** Modify `entry/src/main/ets/physics/ProjectileRunner.ets`、`entry/src/main/ets/scenes/MechanicsScenes.ets`、`entry/src/main/ets/bench/RubricProjectile.ets`、`entry/src/main/ets/model/FactLabels.ets`;Test `tools/physics-check/check.mjs`

**Interfaces:** Consumes `ProjectileGProcedure`、`this.points`、`this.originSet`、`this.v0()`;Produces `ans.pjG`、`pjGTrue`、`pjGOutcome`、`pjGWrongKind`、`ans.pjSegRatio`、`pjSegRatioTrue`、`pjSegRatioOutcome`、`pjSegRatioWrongKind`;判据 `pj-g-value`、`pj-seg-ratio-value`;版本 `2026.10.1`

- [ ] **Step 1** 写失败的断言:

```js
// ---- 学生填数通道 7:sr-007 两格填空 + 细则重排后仍可被满足 ----------------------
{
  const { ExperimentRegistry } = require(join(OUT, 'runner/ExperimentRegistry.cjs'));
  const { RubricProjectile } = require(join(OUT, 'bench/RubricProjectile.cjs'));
  const { Judgment } = require(join(OUT, 'bench/Judgment.cjs'));
  const { FactSheet } = require(join(OUT, 'model/FactSheet.cjs'));
  const meta = ExperimentRegistry.find('projectile-frame').meta;
  function diligent(answers) {
    const runner = ExperimentRegistry.createRunner('projectile-frame');
    runner.setup(meta);
    runner.doAction('origin');
    runner.doAction('slot+');
    runner.doAction('slot+');
    for (const card of [1, 2, 3, 4]) {
      while (runner.readObservable('pjCardDistance') < card * 0.15 - 1e-9) runner.doAction('card+');
      while (runner.readObservable('pjCardDistance') > card * 0.15 + 1e-9) runner.doAction('card-');
      runner.doAction('release');
      for (let i = 0; i < 50; i++) runner.step(1 / 60);
    }
    for (const [k, v] of answers) runner.setAnswer(k, v);
    const sheet = new FactSheet();
    runner.collectFacts(sheet);
    return { sheet: sheet, card: Judgment.score(RubricProjectile.create(), sheet) };
  }
  const blank = diligent([]);
  check('认真描完但两格都没交 → g 那格算"没交"', blank.sheet.num('pjGOutcome'), 2, 0);
  check('段比那格也算"没交"', blank.sheet.num('pjSegRatioOutcome'), 2, 0);
  check('手上四条做足、两格没交 → 60 分', blank.card.awarded, 60, 1e-9);
  const good = diligent([['pjG', blank.sheet.num('pjGTrue')],
    ['pjSegRatio', blank.sheet.num('pjSegRatioTrue')]]);
  check('照应有值填 → 满分', good.card.awarded, 100, 1e-9);
  check('扣分条数为 0', good.card.deductions.length, 0, 0);
  check('g 的应有值就是 9.8', good.sheet.num('pjGTrue'), 9.8, 1e-6);
  check('段比应有值是 3', good.sheet.num('pjSegRatioTrue'), 3, 1e-6);
  const half = diligent([['pjG', 4.9], ['pjSegRatio', 3]]);
  check('漏乘 2 → g 这格算错', half.sheet.num('pjGOutcome'), 1, 0);
  check('点名 G1', half.sheet.num('pjGWrongKind'), 1, 0);
  check('只扣这一条 = 80 分', half.card.awarded, 80, 1e-9);
  const rubric = RubricProjectile.create();
  let sum = 0;
  for (const c of rubric.criteria) sum += c.points;
  check('六条加起来还是 100', sum, 100, 0);
  checkText('版本升过', rubric.version, '2026.10.1');
}
```

- [ ] **Step 2** 跑 → 预期事实键不存在、细则四条
- [ ] **Step 3** `ProjectileRunner.ets` import `ProjectileGProcedure`;`onCollectFacts` 里 `sheet.mark('traced', ...)` 之前加:

```ts
    // 两格填空都要求"定过原点":没定原点时那套坐标算出来的 g 不是这条问的 g,
    // 那种情形由 pj-origin-late 那条去扣,不在这里抢同一个错。
    // 注意 v0 取的是**描下那个点时**的释放格(first.slot),不是当前滑槽位置 ——
    // 学生描完点再去改释放高度是常事,拿新的 v0 去比旧的点会假扣分。
    if (this.originSet && this.points.length >= 1) {
      const first = this.points[0];
      const yMm = first.y * 1000;
      const xMm = first.x * 1000;
      const v0 = ProjectileRunner.v0At(first.slot);
      this.checkNumber(sheet, 'pjG', ProjectileGProcedure.gFromPoint(yMm, xMm, v0),
        ProjectileGProcedure.fingerprints(yMm, xMm, v0), 3);
    }
    if (this.originSet && this.points.length >= 3) {
      const ys = this.sortedY().slice(0, 2).map((v: number): number => v * 1000);
      this.checkNumber(sheet, 'pjSegRatio', ProjectileGProcedure.segmentRatio(ys),
        ProjectileGProcedure.ratioFingerprints(ys), 3);
    }
```

`v0()` 改写成"按格数取"的静态口,并把原来的私有 `v0()` 转调它(答案的期望值与飞行中的画面都用它):

```ts
  /** 槽口速度只由释放格数决定:这就是"必须同一位置静止释放"的所以然 */
  static v0At(slot: number): number {
    return Math.sqrt(2 * G * slot * SLOT_STEP);
  }

  private v0(): number {
    return ProjectileRunner.v0At(this.slot);
  }
```

**并加一条断言钉住这件事**(而不是只在注释里说):描完四个点后把 `slot+` 按两下,`pjGTrue` 必须纹丝不动 ——
这是 Ruling G 的落点:期望值绑在"数据被记下的那一刻",不绑在世界的当前状态。

加取数口(紧跟 `sortedX()`):

```ts
  /** 按 x 排好的 y 序列(米)。段比要的是"从抛出点数起的前两段",不能按描点先后 */
  private sortedY(): number[] {
    const out: number[] = [];
    const xs = this.sortedX();
    for (let i = 0; i < xs.length; i++) {
      for (let j = 0; j < this.points.length; j++) {
        if (Math.abs(this.points[j].x - xs[i]) < 1e-12) {
          out.push(this.points[j].y);
          break;
        }
      }
    }
    return out;
  }
```

- [ ] **Step 4** `MechanicsScenes.ets` 的 `projectileFrame()` 两条 `meta.tasks` 之后:

```ts
    meta.submissions.push(SceneBuilders.submission('pjG', 'pj-y-over-x2',
      '由你描的点反求的重力加速度 g（g = 2·(y/x²)·v0²）', 'm/s²', 2));
    meta.submissions.push(SceneBuilders.submission('pjSegRatio', 'pj-y-over-x2',
      '竖直方向第二段位移 ÷ 第一段位移（按卡片等间隔取点时）', '', 2));
```

`FactLabels.buildTable()` 加八条:

```ts
    table.set('pjGOutcome', FactLabels.coded('反求 g 判定'));
    table.set('pjSegRatioOutcome', FactLabels.coded('竖直段比判定'));
    table.set('ans.pjG', new FactLabel('你交的 g', ' m/s²'));
    table.set('ans.pjSegRatio', new FactLabel('你交的段比', ''));
    table.set('pjGTrue', new FactLabel('g 应有值', ' m/s²'));
    table.set('pjSegRatioTrue', new FactLabel('竖直段比应有值', ''));
    table.set('pjGWrongKind', new FactLabel('g 错法', ''));
    table.set('pjSegRatioWrongKind', new FactLabel('段比错法', ''));
```

- [ ] **Step 5** `RubricProjectile.ets`:版本 → `'2026.10.1'`,既有四条 25 → 15,加两条 20 分:

```ts
    const gValue = CriterionBuilder.numeric('pj-g-value', '反求的 g 没算对或没交',
      CriterionOp.GT, 'pjGOutcome', 0, 0, 20,
      '你交的 g 是 {ans.pjG} m/s²，按你描的第 1 个点应为 {pjGTrue} m/s²，判定：{pjGOutcome}。由 y = ½gt² 与 x = v0t 消去 t 得 g = 2·(y/x²)·v0²：漏掉那个 2、把横坐标当成时间，都会得到另一个数');
    const ratioValue = CriterionBuilder.numeric('pj-seg-ratio-value',
      '竖直方向相邻两段的比没算对或没交',
      CriterionOp.GT, 'pjSegRatioOutcome', 0, 0, 20,
      '你交的第二段与第一段之比是 {ans.pjSegRatio}，应为 {pjSegRatioTrue}，判定：{pjSegRatioOutcome}。y 与 x² 成正比说的是总位移；等时间间隔下相邻两段之比是 1:3:5，把两点的总位移之比当成段比会得到 4');
    rubric.criteria.push(gValue);
    rubric.criteria.push(ratioValue);
```

- [ ] **Step 6** 跑 → `✓ ...`;构建 → 绿
- [ ] **Step 7** 提交:`git commit -m "填数通道 9:sr-007 两格填空进事实,细则 4×25 → 4×15+2×20 并升版本"`

---

### Task 10: 设备探针 —— 打字、交卷点名、回显纪律、历史落盘

**Files:** Create `tools/device/check-answer.mjs`

- [ ] **Step 1** 沿用 `check-projectile.mjs` 的 `readout/locate/press/pressMany/verdict` 骨架,新增打字工具:

```js
/** 往一格填空里打字:先定位那一格,再用 uitest 的 inputText 打进去 */
function typeInto(label, text) {
  const c = locate(label);
  if (c === null) return false;
  p.shell(`uitest uiInput inputText ${c[0]} ${c[1]} ${text}`);
  p.sleep(1200);
  return true;
}
```

- [ ] **Step 2** 断言清单(每条一个 `p.expect*`,失败即非零退出):
  1. 「要交的结论」出现在屏幕上;第一条任务 prompt 的前 8 个字可见(任务文本第一次上屏)。
  2. 两个填空 label 可见:`逐差法的分子` 与 `分母里 T² 的倍数`。
  3. 一条都不填、手上动作做完后交卷 → 判词含"没交",得分 60。
  4. 填成 F1 的值(分子填判词里"只吃首尾"那个数)→ 判词点名,得分 80。
  5. 两格都照应有值填 → 得分 100。
  6. **回显纪律**:填一个明显错的值后、交卷之前,屏幕上不得出现"算对了/算错了/没交"任一字样 —— 这条要能抓住"顺手加了即时反馈"的改动。
  7. 历史回看:进报告页选这条记录,能看到他填的分子数值(证明 `ans.*` 落盘)。
  8. 键盘弹起时截一张 `p.shot('answer-keyboard')`,人眼确认输入框没被顶出可视区。
- [ ] **Step 3** 跑:`node tools/device/check-answer.mjs --install entry/build/default/outputs/default/entry-default-unsigned.hap` → `全部通过`。任何 FAIL 先按探针纪律三分(应用缺陷 / 探针自己错 / 判据判得对)再决定改谁,唯一能定性的证据是那一屏截图。
- [ ] **Step 4** 提交:`git commit -m "填数通道 10:设备侧验收 —— 打字进框、没交扣分、错法点名、输入时不回显、ans.* 落盘"`

---

### Task 11: 变异测试与文档收口

**Files:** Modify `docs/product/优化与更新清单-2026-10.md`

- [ ] **Step 1** 四次变异,每次都要红(改完跑 `node tools/physics-check/check.mjs`,记下红几条,还原):

| 变异 | 改法 | 期望 |
| --- | --- | --- |
| V1 | `AnswerCheck.match` 里把 `out.code = ANSWER_WRONG` 改成 `ANSWER_OK` | "算错"那几条全红 |
| V2 | 匹配顺序改成先比指纹(把 correct 那次比较挪到循环之后) | 恰好填对被判成某种错法 → 红 |
| V3 | 段数不足时也调用 `checkNumber`(去掉 `half()===0` 的短路) | "这题没出不写事实"那条红 |
| V4 | 删掉 `FactLabels.coded` 的 codes 分支 | 判词里露出裸 0/1/2 → 红 |

- [ ] **Step 2** 全量 + 构建 + 装机复跑,含两条回归哨兵:

```bash
node tools/physics-check/check.mjs 2>&1 | tail -1
node tools/device/check-answer.mjs --install entry/build/default/outputs/default/entry-default-unsigned.hap
node tools/device/check-tape.mjs
node tools/device/check-projectile.mjs
```

三条都要通过 —— 后两条是回归:分值重排与点旁标签会碰到它们,红了要如实改断言而不是回滚改动。

- [ ] **Step 3** 文档:W2-3 那一行标 ✅,并写清通道打通后还有五条场景的填空待复制;`#54`(化学台架细则)现在才具备"让学生交处理结果"的能力。
- [ ] **Step 4** 提交:`git commit -m "填数通道 11:变异与回归记录,W2-3 收口"`

---

## 自检对照(spec → 任务)

| spec 章节 | 落在哪个任务 |
| --- | --- |
| §4.1 声明 / §4.2 procedure / §4.3 match / §4.4 事实键 | 1、2、3、5、8、9 |
| §5 sr-003 指纹表与边界 | 4、5、6 |
| §6 sr-007 点旁 y、两张表、边界 | 8、9 |
| §7 分值重排、枚举标签、那处破例 | 5、6、9 |
| §8 UI(第一个 TextInput、不即时回显、令牌) | 7、10 |
| §9 验收(负对照、变异、探针、文案闸门) | 2、4、10、11 |
| §10 明确不做的东西 | 无任务(刻意) |
| §11 风险(判分边界、键盘压缩可视区、枚举表被滥用) | 7、10 的截图断言;枚举表约束写进 Task 5 的实现注释 |

