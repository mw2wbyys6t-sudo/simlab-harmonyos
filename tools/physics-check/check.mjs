/**
 * 求解器的离线校验。
 *
 * 为什么需要它:UI 只能在真机/模拟器上看,而本项目真正的价值在于「数字是否正确」——
 * 学生据此得出 T=2π√(m/k)、验证能量守恒,错了就是教学事故。
 * 物理层(model / runner / physics / scenes)刻意不 import 任何 ArkUI 与 @kit,
 * 所以可以被抽出来单独跑。
 *
 * 用法: node tools/physics-check/check.mjs
 */
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import os from 'node:os';
import { makeRecorder } from './record-ctx.mjs';
import { discriminatorRate } from '../coverage-metrics.mjs';
import { BLOCKED_TERMS } from '../visible-copy-blocklist.mjs';

const require = createRequire(import.meta.url);
const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const ts = require('F:/DevEco/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript');

const SRC = join(root, 'entry', 'src', 'main', 'ets');
const OUT = join(os.tmpdir(), 'simlab-check');
rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });

const MODULES = [
  'geometry/Profile',
  'bench/Brine',
  'bench/Container',
  'bench/Pose',
  'bench/Filtration',
  'bench/Spatula',
  'bench/Dropper',
  'bench/ChunkSolid',
  'geometry/GlassShapes',
  'bench/VesselBase',
  'view3d/Camera',
  'view3d/Lathe',
  'view3d/LathePainter',
  'view3d/TiltedPlane',
  'content/map/CurriculumTypes',
  'content/map/UniversityPhysics',
  'content/map/SchoolPhysics',
  'content/map/MapValidator',
  'content/map/KnowledgeTypes',
  'content/map/KnowledgePhysics',
  'content/map/KnowledgePhysicsJunior',
  'content/map/KnowledgePhysicsSenior',
  'content/map/KnowledgeBiology',
  'content/map/KnowledgeBiologyJunior',
  'content/map/KnowledgeBiologySenior',
  'content/map/KnowledgeElectronics',
  'content/map/KnowledgeElectronicsJunior',
  'content/map/KnowledgeElectronicsSenior',
  'content/map/PeriodicTable',
  'content/map/KnowledgeChemistry',
  'content/map/KnowledgeChemistryJunior',
  'content/map/KnowledgeChemistrySenior',
  'content/map/UniversityChemistry',
  'content/map/SchoolChemistry',
  'content/map/UniversityElectronics',
  'content/map/UniversityBiology',
  'content/map/SchoolBiology',
  'content/map/CurriculumIndex',
  'content/map/ContentCodec',
  'bench/Rubric',
  'bench/Judgment',
  'bench/RubricSpring',
  'bench/RubricOhm',
  'bench/RubricEmf',
  'bench/RubricTape',
  'bench/RubricEnergy',
  'bench/RubricSpeed',
  'bench/RubricNewton',
  'bench/RubricImage',
  'bench/RubricProjectile',
  'bench/RubricBrine',
  'bench/RubricMeasure',
  'bench/MeasureVerdict',
  'bench/BrineScenario',
  'bench/BenchWorld',
  'common/Theme',
  'common/Appearance',
  'common/Contrast',
  'common/Layout',
  'common/LibraryFeed',
  'model/ExperimentTypes',
  'model/FactSheet',
  'model/SessionRecord',
  'model/FactLabels',
  'runner/SessionLedger',
  'chemistry/Formula',
  'chemistry/ChemistryModel',
  'chemistry/ChemistryLibrary',
  'chemistry/BenchModel',
  'chemistry/BenchEngine',
  'physics/World2D',
  'view/PlotFrame',
  'physics/Physics2DRunner',
  'physics/SpringForceRunner',
  'physics/MnaSolver',
  'physics/circuit/CircuitModel',
  'physics/circuit/CircuitRunner',
  'physics/circuit/OhmRunner',
  'physics/circuit/EmfRunner',
  'physics/TickerTape',
  'physics/AnswerCheck',
  'physics/TapeCartRunner',
  'physics/TapeStrip',
  'physics/FreeFallRunner',
  'physics/StopwatchCartRunner',
  'physics/NewtonSecondRunner',
  'physics/ProjectileRunner',
  'physics/SpringImageRunner',
  'physics/SpringMassRunner',
  'physics/InclineRunner',
  'runner/IExperimentRunner',
  'runner/RunController',
  'runner/ExperimentRegistry',
  'scenes/SceneBuilders',
  'scenes/MechanicsScenes',
  'scenes/ElectricalScenes'
];

// ArkUI 的 $r() 由框架在运行时注入,离线侧没有,不补一个 require 就直接 ReferenceError。
// 这里返回形状与真实 Resource 一致的句柄,并把资源名按出现顺序编号 —— 这样断言既能验证
// 令牌指向的资源名,也能验证 Palette 那套「按 id 缓存」的语义在离线跑得通。
const resourceIds = new Map();
const resourceNames = [];
globalThis.$r = (resourceName) => {
  let id = resourceIds.get(resourceName);
  if (id === undefined) {
    id = resourceNames.length;
    resourceIds.set(resourceName, id);
    resourceNames.push(resourceName);
  }
  return { id: id, type: 7, params: [], bundleName: '', moduleName: '' };
};
/** 把 $r 句柄还原成资源名,便于断言「这个令牌到底指向哪个色」 */
const resourceNameOf = (res) => resourceNames[res.id];

for (const name of MODULES) {
  const source = readFileSync(join(SRC, name + '.ets'), 'utf8');
  const js = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 },
    fileName: name + '.ts'
  }).outputText;
  const target = join(OUT, name + '.cjs');
  mkdirSync(dirname(target), { recursive: true });
  // 相对 import 不带扩展名,补上 .cjs 才能被 node 解析
  writeFileSync(target, js.replace(/require\("(\.[^"]*)"\)/g, 'require("$1.cjs")'));
}

const { SpringMassRunner } = require(join(OUT, 'physics/SpringMassRunner.cjs'));
const { InclineRunner } = require(join(OUT, 'physics/InclineRunner.cjs'));
const { RunController } = require(join(OUT, 'runner/RunController.cjs'));
const { ExperimentRegistry } = require(join(OUT, 'runner/ExperimentRegistry.cjs'));
const { MechanicsScenes } = require(join(OUT, 'scenes/MechanicsScenes.cjs'));
const { ElectricalScenes } = require(join(OUT, 'scenes/ElectricalScenes.cjs'));

let passed = 0;
const failures = [];

function check(label, actual, expected, tolerance) {
  if (typeof actual !== 'number' || typeof expected !== 'number') {
    failures.push(`${label}: check() 只能比数值,实得 ${typeof actual} 期望 ${typeof expected}(改用 checkText/assertTrue)`);
    return;
  }
  const ok = Number.isFinite(actual) && Math.abs(actual - expected) <= tolerance;
  if (ok) {
    passed++;
  } else {
    failures.push(`${label}: 实得 ${actual}, 期望 ${expected}±${tolerance}`);
  }
}

function assertTrue(label, condition, detail) {
  if (condition) {
    passed++;
  } else {
    failures.push(`${label}: ${detail}`);
  }
}

/** 以固定步长跑满 seconds 秒 */
function run(runner, seconds, dt = 1 / 240) {
  const steps = Math.round(seconds / dt);
  for (let i = 0; i < steps; i++) {
    runner.step(dt);
  }
}

function setAll(runner, values) {
  for (const key of Object.keys(values)) {
    runner.setParam(key, values[key]);
  }
}

const G = 9.8;

// ---- 弹簧振子 -------------------------------------------------------------
function springMeta() {
  return ExperimentRegistry.find('spring-mass').meta;
}

function newSpring(values) {
  const runner = new SpringMassRunner();
  runner.setup(springMeta());
  setAll(runner, values);
  runner.reset();
  return runner;
}

MechanicsScenes.registerAll();
ElectricalScenes.registerAll();

{
  const m = 1, k = 20;
  const runner = newSpring({ mass: m, stiffness: k, damping: 0, amplitude: 0.9 });
  run(runner, 40);
  const theory = 2 * Math.PI * Math.sqrt(m / k);
  check('弹簧振子 理论周期', runner.readObservable('periodTheory'), theory, 1e-9);
  check('弹簧振子 实测周期与理论一致', runner.readObservable('periodMeasured'), theory, theory * 0.01);
}

{
  const runner = newSpring({ mass: 1, stiffness: 20, damping: 0, amplitude: 0.9 });
  const e0 = runner.readObservable('total');
  run(runner, 60);
  const e1 = runner.readObservable('total');
  check('无阻尼时总能量守恒', e1, e0, e0 * 0.01);
  assertTrue('半隐式欧拉能量不漂移', Math.abs(e1 - e0) / e0 < 0.01, `60 秒后能量偏差 ${(100 * (e1 - e0) / e0).toFixed(3)}%`);
}

{
  const runner = newSpring({ mass: 1, stiffness: 20, damping: 1.2, amplitude: 0.9 });
  let previous = runner.readObservable('total');
  let violated = 0;
  for (let i = 0; i < 6000; i++) {
    runner.step(1 / 240);
    const now = runner.readObservable('total');
    if (now > previous + 1e-9) {
      violated++;
    }
    previous = now;
  }
  assertTrue('有阻尼时机械能单调不增', violated === 0, `出现 ${violated} 次能量上升`);
  assertTrue('阻尼确实让振幅衰减', Math.abs(runner.readObservable('displacement')) < 0.9 * 0.9,
    `6000 步后位移 ${runner.readObservable('displacement')}`);
}

// ---- 斜面:无摩擦 ---------------------------------------------------------
function newIncline(values) {
  const runner = new InclineRunner();
  runner.setup(ExperimentRegistry.find('incline-block').meta);
  setAll(runner, values);
  runner.reset();
  return runner;
}

{
  const theta = 30 * Math.PI / 180, L = 3.5;
  // 中途取样验证加速度:到底端后世界冻结,读数是到达瞬间的值
  const mid = newIncline({ angle: 30, friction: 0, length: L, mass: 2, initialVelocity: 0 });
  run(mid, 0.5);
  check('无摩擦斜面加速度 a=g·sinθ', mid.readObservable('acceleration'), G * Math.sin(theta), 1e-6);
  check('无摩擦不产生热量', mid.readObservable('heat'), 0, 1e-9);

  const runner = newIncline({ angle: 30, friction: 0, length: L, mass: 2, initialVelocity: 0 });
  run(runner, 5);
  const vBottom = Math.sqrt(2 * G * Math.sin(theta) * L);
  check('无摩擦到底端速度 v=√(2gL·sinθ)', runner.readObservable('velocityEnd'), vBottom, vBottom * 0.01);
  check('到底端时高度为 0', runner.readObservable('height'), 0, 1e-9);
  check('到底端耗时 t=√(2L/g·sinθ)', runner.readObservable('timeToEnd'),
    Math.sqrt(2 * L / (G * Math.sin(theta))), 0.01);
  assertTrue('到底端后标记终点', runner.finished() === true, 'finished 仍为 false');
  const frozenTime = runner.elapsedTime();
  run(runner, 2);
  check('终点后不再继续计时', runner.elapsedTime(), frozenTime, 1e-9);
}

// ---- 斜面:能量守恒(含摩擦)----------------------------------------------
{
  const m = 2, mu = 0.25, thetaDeg = 35, L = 3.5;
  const theta = thetaDeg * Math.PI / 180;
  const runner = newIncline({ angle: thetaDeg, friction: mu, length: L, mass: m, initialVelocity: 0 });
  const ep0 = runner.readObservable('potential');
  run(runner, 4);
  const epLoss = ep0 - runner.readObservable('potential');
  const ek = runner.readObservable('kinetic');
  const q = runner.readObservable('heat');
  check('减少的重力势能 = 动能 + 摩擦生热', epLoss, ek + q, Math.max(1e-6, epLoss * 0.01));
  assertTrue('摩擦生热为正', q > 0, `Q=${q}`);
}

// ---- 临界角:静止判据 -----------------------------------------------------
{
  const runner = newIncline({ angle: 10, friction: 0.3, length: 3.5, mass: 2, initialVelocity: 0 });
  run(runner, 6);
  check('θ<arctanμ 时滑块保持静止', runner.readObservable('distance'), 0, 1e-9);

  const slide = newIncline({ angle: 25, friction: 0.3, length: 3.5, mass: 2, initialVelocity: 0 });
  run(slide, 1);
  assertTrue('θ>arctanμ 时滑块开始下滑', slide.readObservable('distance') > 0.05,
    `1 秒后位移 ${slide.readObservable('distance')}`);
}

// ---- 从坡底上滑再滑回:经典往返 ------------------------------------------
{
  const mu = 0.4, thetaDeg = 30, L = 3.5, v0 = 2.5;
  const th = thetaDeg * Math.PI / 180;
  const aUp = G * Math.sin(th) + mu * G * Math.cos(th);
  const aDown = G * Math.sin(th) - mu * G * Math.cos(th);
  const climb = v0 * v0 / (2 * aUp);
  const backSpeed = Math.sqrt(2 * aDown * climb);

  // s 是从坡顶量的距离,所以「在坡底上滑」= 起点 s=L、初速度取负
  const runner = newIncline({
    angle: thetaDeg, friction: mu, length: L, mass: 2, initialVelocity: -v0, startDistance: L
  });
  let reversals = 0;
  let lastNonZero = -v0;
  let lowestS = L;
  for (let i = 0; i < 240 * 30 && !runner.finished(); i++) {
    runner.step(1 / 240);
    const v = runner.readObservable('velocity');
    // 速度过零时模型会精确置零,统计反向次数要跳过这个零值而不是把它当成端点
    if (v !== 0 && lastNonZero !== 0 && (v > 0) !== (lastNonZero > 0)) {
      reversals++;
    }
    if (v !== 0) {
      lastNonZero = v;
    }
    lowestS = Math.min(lowestS, runner.readObservable('distance'));
  }
  /*
   * 容差按下限取「一个积分步的位置增量 v₀·dt」而不是百分比:定步长积分在折返点
   * 必然比连续解少走不到一步的路,这是方法的固有残差而不是缺陷。
   * 用 1% 相对容差会把这种正常残差报成失败,反而逼人去做没有意义的算法调整。
   */
  const stepFloor = v0 / 240;
  check('上滑最远距离 d=v₀²/2a上', runner.readObservable('distanceMax'), climb, stepFloor);
  check('上滑起点即坡底,s 最小值 = L-d', lowestS, L - climb, stepFloor);
  check('速度只反向一次(先上滑后下滑)', reversals, 1, 0);
  check('滑回坡底的速度小于上滑初速', runner.readObservable('velocityEnd'), backSpeed, backSpeed * 0.02);
  assertTrue('有摩擦往返必然损耗机械能', runner.readObservable('velocityEnd') < v0,
    `回坡底 ${runner.readObservable('velocityEnd')} 不小于初速 ${v0}`);
  // 离散方案下严格成立的恒等式:摩擦生热 = 摩擦力 × 路程
  check('摩擦生热 = μmg·cosθ × 路程', runner.readObservable('heat'),
    mu * 2 * G * Math.cos(th) * runner.readObservable('path'), 1e-9);
  /*
   * 端点机械能差与摩擦生热的残差来自半隐式欧拉本身:它每步固定耗散 ½·m·a²·dt²。
   * 容差不去手调,直接由物理量推出来 —— 上滑 nUp 步、下滑 nDown 步,
   * 各自的加速度已知,累加即得耗散上界。这个界随 dt 收窄,所以将来换成
   * 更精确的积分器时断言会自动变严,而不是变成一个永远通过的空壳。
   */
  const vEnd = runner.readObservable('velocityEnd');
  const dtStep = 1 / 240;
  const nUp = (climb / (v0 / 2)) / dtStep;
  const nDown = (climb / (vEnd / 2)) / dtStep;
  const dissipation = (nUp * 0.5 * 2 * aUp * aUp + nDown * 0.5 * 2 * aDown * aDown) * dtStep * dtStep;
  const deltaE = 0.5 * 2 * v0 * v0 - 0.5 * 2 * vEnd * vEnd;
  check('往返机械能损失与摩擦生热之差落在数值耗散上界内', runner.readObservable('heat'),
    deltaE, dissipation);
  assertTrue('耗散上界确实小于被测能量', dissipation < deltaE * 0.05,
    `耗散 ${dissipation} 相对 ΔE ${deltaE} 过大`);
}

{
  // 在上端给一个朝坡顶的初速度:应当如实记为「滑出坡顶」并保留越界速度,
  // 而不是把速度归零 —— 那等于凭空吞掉动能
  const runner = newIncline({ angle: 30, friction: 0, length: 3.5, mass: 2, initialVelocity: -3, startDistance: 0 });
  run(runner, 0.5);
  assertTrue('向上越界立即判为滑出坡顶', runner.finished(), '未标记终点');
  // 记录的是越界那一步的速度,与初值差恰好一步 g·sinθ·dt,容差取 1.5 步
  check('滑出坡顶时的速度被保留', runner.readObservable('velocityEnd'), 3,
    1.5 * G * Math.sin(Math.PI / 6) / 240);
  check('滑出后滑块停在坡顶位置', runner.readObservable('distance'), 0, 1e-9);
}

// ---- 帧率无关性:定步长累加器 --------------------------------------------
{
  // 同一份总仿真时间,用均匀帧与忽快忽慢的帧各喂一次,结果必须只差一个积分步以内
  const uniform = 0.005;
  const pattern = [0.001, 0.05, 0.02, 0.08, 0.003, 0.04, 0.011, 0.03, 0.07, 0.002,
    0.06, 0.019, 0.09, 0.004, 0.025, 0.0166, 0.008, 0.045, 0.031, 0.0004];
  const patternSum = pattern.reduce((acc, v) => acc + v, 0);
  const scale = 0.4 / patternSum;

  function feed(deltas) {
    const runner = newSpring({ mass: 1, stiffness: 20, damping: 0, amplitude: 0.9 });
    const controller = new RunController();
    controller.bind(runner, springMeta());
    setAll(runner, { mass: 1, stiffness: 20, damping: 0, amplitude: 0.9 });
    runner.reset();
    controller.start();
    for (const d of deltas) {
      controller.advance(d);
    }
    return { runner, controller };
  }

  const even = [];
  for (let i = 0; i < 800; i++) {
    even.push(uniform);
  }
  const jittery = [];
  for (let r = 0; r < 10; r++) {
    for (const v of pattern) {
      jittery.push(v * scale);
    }
  }

  const a = feed(even);
  const b = feed(jittery);
  const STEP = 1 / 240;
  check('喂入 4 秒仿真时间(均匀帧)', a.runner.elapsedTime(), 4, STEP);
  check('喂入 4 秒仿真时间(抖动帧)', b.runner.elapsedTime(), 4, STEP);
  check('两种帧节奏的仿真时间一致', a.runner.elapsedTime(), b.runner.elapsedTime(), STEP);
  check('两种帧节奏的位移一致', a.runner.readObservable('displacement'),
    b.runner.readObservable('displacement'), 0.05);
  assertTrue('到终点后自动停表', a.controller.running === true, '简谐振动不应提前结束');
  assertTrue('采样序列已累积用于绘图', a.controller.times.length > 40,
    `采样点 ${a.controller.times.length}`);
  assertTrue('采样数据与时间轴等长',
    a.controller.series.get('displacement').length === a.controller.times.length,
    '位移序列与时间轴长度不一致');
}

// ---- 线性方程组求解器 -----------------------------------------------------
{
  const { MnaSolver } = require(join(OUT, 'physics/MnaSolver.cjs'));
  const solution = MnaSolver.solve([[2, 1], [1, 3]], [5, 10]);
  assertTrue('方程组可解时返回解向量', solution !== null, '返回 null');
  check('二元方程组解 x', solution[0], 1, 1e-9);
  check('二元方程组解 y', solution[1], 3, 1e-9);
  assertTrue('奇异矩阵被识别而不是给出错误解',
    MnaSolver.solve([[1, 2], [2, 4]], [1, 2]) === null, '未返回 null');
}

// ---- 直流电路 -------------------------------------------------------------
const { CircuitRunner } = require(join(OUT, 'physics/circuit/CircuitRunner.cjs'));
const { CircuitSpec } = require(join(OUT, 'physics/circuit/CircuitModel.cjs'));
const { ComponentKind } = require(join(OUT, 'physics/circuit/CircuitModel.cjs'));

function electrical(id, values) {
  const found = ExperimentRegistry.find(id);
  if (found === null || found === undefined) {
    // 场景被改名或没注册时,原先这里直接 TypeError 把整个进程打死,
    // 于是**同一次运行里其他断言的结果也一起丢了** —— 看着像"红了一条",实际是"什么都没测"。
    // 记一条具名失败并返回读数全 NaN 的桩:NaN 会让下面每条数值断言都红,不会假绿。
    failures.push(`注册表里没有场景「${id}」(地图或断言还在引用它)`);
    return { readObservable: () => Number.NaN, setParam: () => undefined, setup: () => undefined };
  }
  const runner = ExperimentRegistry.createRunner(id);
  runner.setup(found.meta);
  setAll(runner, values);
  return runner;
}

function adHocRunner(components) {
  const spec = new CircuitSpec();
  for (const c of components) {
    spec.add(c.kind, c.id, c.label, c.nodeA, c.nodeB, c.value, c.paramKey);
  }
  const runner = new CircuitRunner(spec);
  runner.setup(springMeta());
  return runner;
}

function part(kind, id, nodeA, nodeB, value, paramKey) {
  return { kind: kind, id: id, label: id, nodeA: nodeA, nodeB: nodeB, value: value, paramKey: paramKey };
}

function checkText(label, actual, expected) {
  if (typeof actual !== 'string' || typeof expected !== 'string') {
    failures.push(`${label}: checkText() 只能比字符串,实得 ${typeof actual} 期望 ${typeof expected}(改用 assertTrue/check)`);
    return;
  }
  assertTrue(label, actual === expected, `实得「${actual}」,期望「${expected}」`);
}

function checkRel(label, actual, expected, relTolerance) {
  const deviation = expected === 0 ? Math.abs(actual) : Math.abs(actual - expected) / Math.abs(expected);
  assertTrue(label, Number.isFinite(actual) && deviation <= relTolerance,
    `实得 ${actual}, 期望 ${expected}, 相对偏差 ${deviation.toExponential(2)}`);
}

{
  /*
   * 教科书值是「电表理想」下的结果。真实电压表内阻有限,会从被测支路分走电流,
   * 所以这里按「负载误差小于 0.01%」断言,而不是要求与理想值精确相等 ——
   * 后者会诱使人把电压表内阻设成无穷大,而那样一来「电压表误串进回路」
   * 就成了悬空节点、系数矩阵奇异、彻底读不出数。
   */
  const runner = electrical('series-circuit', { emf: 6, r1: 20, r2: 30, switch: 1 });
  checkRel('串联干路电流 I=E/(R₁+R₂)', runner.readObservable('I:a0'), 0.12, 1e-4);
  checkRel('串联分压 U₁=IR₁', runner.readObservable('U:v1'), 2.4, 1e-4);
  checkRel('串联分压 U₂=IR₂', runner.readObservable('U:v2'), 3.6, 1e-4);
  checkRel('串联总电阻 R=R₁+R₂', runner.readObservable('Req'), 50, 1e-4);
  /*
   * 「串联电流处处相等」在接了电压表之后并不严格成立:伏特表跨在 R₁ 两端,
   * 干路电流 = R₁ 电流 + 伏特表分流。直接断言相等会把这条真实效应测成失败,
   * 所以改成断言节点电流守恒 —— 它既验证了解算正确,也如实反映了电表负载。
   * 分流约 2.4e-7 A,读数保留三位小数时仍显示为处处相等,不影响教学结论。
   */
  check('KCL:干路电流 = R₁ 电流 + V₁ 分流', runner.readObservable('I:a0'),
    runner.readObservable('I:r1') + runner.readObservable('I:v1'), 1e-12);
  check('KCL:干路电流 = R₂ 电流 + V₂ 分流', runner.readObservable('I:a0'),
    runner.readObservable('I:r2') + runner.readObservable('I:v2'), 1e-12);
  // KVL 要闭合必须把电流表与闭合开关各自的接触压降算进去(均 1e-4 Ω)
  check('KVL:总电压 = 电流表 + U₁ + U₂ + 开关压降', runner.readObservable('U:src'),
    runner.readObservable('U:a0') + runner.readObservable('U:v1') + runner.readObservable('U:v2') +
    runner.readObservable('U:sw'), 1e-9);
  checkRel('分压之和与总电压的偏差小于 0.01%',
    runner.readObservable('U:v1') + runner.readObservable('U:v2'), runner.readObservable('U:src'), 1e-4);

  const doubled = electrical('series-circuit', { emf: 6, r1: 20, r2: 80, switch: 1 });
  checkRel('R₂ 增大后 U₁ 反而减小', doubled.readObservable('U:v1'), 1.2, 1e-4);
}

{
  // 并联:E=6 V, R₁=20 Ω, R₂=30 Ω → I₁=0.3, I₂=0.2, I=0.5, R=12
  const runner = electrical('parallel-circuit', { emf: 6, r1: 20, r2: 30, switch: 1 });
  checkRel('并联支路电流 I₁=U/R₁', runner.readObservable('I:a1'), 0.3, 1e-4);
  checkRel('并联支路电流 I₂=U/R₂', runner.readObservable('I:a2'), 0.2, 1e-3);
  checkRel('并联总电阻 1/R=1/R₁+1/R₂', runner.readObservable('Req'), 12, 1e-4);
  checkRel('电源输出功率 P=UI', runner.readObservable('P:src'), 3, 1e-4);
  checkRel('支路电流与电阻成反比', runner.readObservable('I:a1') / runner.readObservable('I:a2'), 1.5, 1e-3);
  // KCL 与并联等压是解出来的恒等式,不受参数取值影响
  check('KCL:干路电流等于支路之和', runner.readObservable('I:a0'),
    runner.readObservable('I:a1') + runner.readObservable('I:a2'), 1e-9);
  check('并联两支路电压相等', runner.readObservable('U:r2'), runner.readObservable('U:r1'), 1e-4);
}

{
  // 断开的开关:回路无电流,但电源两端电压仍在
  const series = electrical('series-circuit', { emf: 6, r1: 20, r2: 30, switch: 0 });
  check('断开开关后电流为零(仅余绝缘漏流)', series.readObservable('I:a0'), 0, 1e-7);
  check('断开开关后 R₁ 不分压', series.readObservable('U:v1'), 0, 1e-4);
  check('断开开关后路端电压仍为电动势', series.readObservable('U:src'), 6, 1e-4);
  const parallel = electrical('parallel-circuit', { emf: 6, r1: 20, r2: 30, switch: 0 });
  check('断开开关后两支路均无电流',
    parallel.readObservable('I:a1') + parallel.readObservable('I:a2'), 0, 1e-7);
}

{
  // 电表要像真表:电流表近乎无压降,电压表几乎不分流
  const runner = electrical('series-circuit', { emf: 6, r1: 20, r2: 30, switch: 1 });
  check('电流表两端压降近似为零', runner.readObservable('U:a0'), 0, 1e-4);
  check('电压表分流近似为零', runner.readObservable('I:v1'), 0, 1e-5);
}

{
  // 学生把电压表串进回路:应给出真实后果 —— 几乎无电流,伏特表读出电源电压
  const runner = adHocRunner([
    part(ComponentKind.SOURCE, 'src', 1, 0, 6, ''),
    part(ComponentKind.VOLTMETER, 'v', 1, 2, 0, ''),
    part(ComponentKind.RESISTOR, 'r', 2, 0, 20, '')
  ]);
  check('电压表串联时回路电流趋零', Math.abs(runner.readObservable('I:r')), 0, 1e-5);
  check('电压表串联时读出电源电压', runner.readObservable('U:v'), 6, 1e-3);
}

{
  // 学生把电流表并在电阻两端:该电阻被短路,电流改走电流表
  const runner = adHocRunner([
    part(ComponentKind.SOURCE, 'src', 1, 0, 6, ''),
    part(ComponentKind.RESISTOR, 'r1', 1, 2, 20, ''),
    part(ComponentKind.AMMETER, 'ashunt', 1, 2, 0, ''),
    part(ComponentKind.RESISTOR, 'r2', 2, 0, 30, '')
  ]);
  check('被短路的电阻两端电压为零', runner.readObservable('U:r1'), 0, 1e-3);
  check('短路后总电流仅由剩余电阻决定', Math.abs(runner.readObservable('I:r2')), 0.2, 1e-6);
  check('电流表分走了绝大部分电流', Math.abs(runner.readObservable('I:ashunt')), 0.2, 1e-3);
}

{
  // 纯电压源成环是最容易让求解器崩掉的拓扑,这里必须给出有限解
  const runner = adHocRunner([
    part(ComponentKind.SOURCE, 's1', 1, 0, 6, ''),
    part(ComponentKind.SOURCE, 's2', 2, 1, 3, ''),
    part(ComponentKind.RESISTOR, 'r', 2, 0, 10, '')
  ]);
  check('两电源串联叠加', runner.readObservable('V:2'), 9, 1e-6);
  check('叠加后的回路电流', Math.abs(runner.readObservable('I:r')), 0.9, 1e-6);
  check('电源支路电流方向约定', Math.abs(runner.readObservable('SIGNED_I:s1')), 0.9, 1e-6);
  const snapshot = runner.snapshot();
  assertTrue('电路场景图产出了元件与导线',
    snapshot.boxes.length === 1 && snapshot.segments.length > 0,
    `boxes=${snapshot.boxes.length} segments=${snapshot.segments.length}`);
}

// ---- 画面跟着参数变(E4)与图内文字不越界不压字(E7) ----------------------
{
  // 曾经振体质量 1 kg 与 5 kg 的快照逐像素差为 0:参数只在面板上动,画布上没有任何后果
  const light = electrical('spring-mass', { mass: 1, stiffness: 20, damping: 0, amplitude: 0.6 });
  const heavy = electrical('spring-mass', { mass: 5, stiffness: 20, damping: 0, amplitude: 0.6 });
  const lightBlock = light.snapshot().boxes[0];
  const heavyBlock = heavy.snapshot().boxes[0];
  check('质量放大 5 倍时块边长按立方根放大', heavyBlock.w / lightBlock.w, Math.cbrt(5), 1e-9);
  check('块高与块宽同比放大', heavyBlock.h / lightBlock.h, Math.cbrt(5), 1e-9);
  // 放大后的块底必须还贴在台面上(cy - h/2 就是底边),不然桌子成了摆设
  check('放大后的块底仍贴同一张台面',
    heavyBlock.cy - heavyBlock.h / 2, lightBlock.cy - lightBlock.h / 2, 1e-9);
  const stamped = heavy.snapshot().labels.filter((l) => l.text === '5.0 kg');
  assertTrue('块面上印出质量本身', stamped.length === 1,
    `实得 ${stamped.length} 条,全部文字=${heavy.snapshot().labels.map((l) => l.text).join('|')}`);
}

{
  const meta = ExperimentRegistry.find('series-circuit').meta;
  const runner = electrical('series-circuit', { emf: 6, r1: 20, r2: 30, switch: 1 });
  runner.readObservable('V:v2');
  const labels = runner.snapshot().labels;
  const readouts = labels.filter((l) => / V$| A$/.test(l.text));
  assertTrue('串联场景把三块电表的读数都画出来', readouts.length === 3,
    `实得 ${readouts.length} 条:${readouts.map((l) => `${l.text}@${l.x.toFixed(2)}/${l.align}`)}`);
  // 每条读数都按锚点摊开以后必须整个落在世界里:V₂ 曾经被右边界裁成「3.6…」
  for (const l of readouts) {
    const left = l.align === 'right' ? l.x - 1.0 : (l.align === 'center' ? l.x - 0.5 : l.x);
    assertTrue(`读数「${l.text}」不越出画布`,
      left >= 0 && left + 1.0 <= meta.worldWidth,
      `占 ${left.toFixed(2)}..${(left + 1.0).toFixed(2)},世界宽 ${meta.worldWidth},锚点 ${l.align}`);
  }
}

// ---- 元件代号不许印在自己身上 --------------------------------------------
// 两处真实压字:① 代号不分横竖一律往上抬 0.42 米,竖放的元件(串联页 R₂、本场景的 R 与 V)
// 那一抬正好抬进自己的符号里;②「电源 E」按 center 摆在轴线外 0.56 米,一行字约 1.7 米宽,
// 于是有一半压回从轴线伸到 ±0.4 米的长极板上。
// 判据按**符号自身的形状**算:电阻/变阻器/灯泡是转过的矩形,电表是圆 ——
// 只要求"同名文字里有一条落在形状外",因为 A/V 把字母印在圆圈里是刻意的。
{
  const CIRCUITS = ['series-circuit', 'parallel-circuit', 'kirchhoff', 'max-power', 'ohm-law'];
  const BOXED = [ComponentKind.RESISTOR, ComponentKind.RHEOSTAT, ComponentKind.LAMP];
  const METERS = [ComponentKind.AMMETER, ComponentKind.VOLTMETER];
  const SYMBOL_HALF = 0.42;
  const SYMBOL_THICK = 0.26;
  const METER_R = 0.26;
  const OUTSIDE = 0.06;
  for (const id of CIRCUITS) {
    const runner = electrical(id, {});
    const snap = runner.snapshot();
    const named = runner.spec.components.filter((c) => c.label.length > 0
      && (BOXED.indexOf(c.kind) >= 0 || METERS.indexOf(c.kind) >= 0 || c.kind === ComponentKind.SOURCE));
    assertTrue(`${id} 的元件都带代号`, named.length >= 3, `只收到 ${named.length} 个`);
    for (const item of named) {
      const cx = (item.ax + item.bx) / 2 + item.offsetX;
      const cy = (item.ay + item.by) / 2 + item.offsetY;
      const dx = item.bx - item.ax;
      const dy = item.by - item.ay;
      const long = Math.sqrt(dx * dx + dy * dy);
      const ux = long < 1e-6 ? 1 : dx / long;
      const uy = long < 1e-6 ? 0 : dy / long;
      // 符号的长轴与短轴:矩形沿轴向那半宽是 SYMBOL_HALF,横向那半宽是 SYMBOL_THICK/2
      const halfAlong = item.kind === ComponentKind.SOURCE ? 0.4
        : (BOXED.indexOf(item.kind) >= 0 ? SYMBOL_HALF : METER_R);
      const halfAcross = item.kind === ComponentKind.SOURCE ? 0.4
        : (BOXED.indexOf(item.kind) >= 0 ? SYMBOL_THICK / 2 : METER_R);
      let clear = false;
      let tag = null;
      for (const l of snap.labels.filter((s) => s.text === item.label)) {
        const vx = l.x - cx;
        const vy = l.y - cy;
        const along = Math.abs(vx * ux + vy * uy);
        const across = Math.abs(vx * uy - vy * ux);
        if (along > halfAlong + OUTSIDE || across > halfAcross + OUTSIDE) {
          clear = true;
          tag = l;
        }
      }
      assertTrue(`${id} 的「${item.label}」代号不在自身符号上`, clear,
        `符号半长 ${halfAlong}/${halfAcross},同名文字 ${snap.labels
          .filter((s) => s.text === item.label).map((s) => `(${s.x.toFixed(2)},${s.y.toFixed(2)})`).join(' ')}`);
      if (item.kind === ComponentKind.SOURCE) {
        // 极板从轴线伸到 ±0.4 米:代号要落在板外,还要朝外起排
        const away = tag !== null && tag.align === (tag.x > cx ? 'left' : 'right');
        assertTrue(`${id} 的电源代号朝极板外起排`, away,
          `锚点 ${tag === null ? '无' : `${tag.x.toFixed(2)}/${tag.align}`}`);
      }
    }
  }
}

// ---- 屏幕上的词:内部术语不许进学生可见文案(④ 内部语言外译) ----------------
{
  // 左边这一串全是我们讨论实现时用的词。学生不需要知道少了哪一层、字段叫什么、
  // 也不需要看见 spec / draft1 / meta.xxx 这类标识符 —— 出现一条就是漏翻。
  // 词表住在 tools/visible-copy-blocklist.mjs,设备巡检用的是同一份
  const BLOCKED = BLOCKED_TERMS;

  const visible = [];
  const push = (where, text) => {
    if (typeof text === 'string' && text.length > 0) visible.push([where, text]);
  };

  for (const meta of ExperimentRegistry.all()) {
    push(`${meta.id} 标题`, meta.title);
    push(`${meta.id} 说明`, meta.summary);
    push(`${meta.id} 学段`, meta.gradeBand);
    for (const p of meta.params) push(`${meta.id} 参数`, p.label);
    for (const o of meta.observables) push(`${meta.id} 读数`, o.label);
    for (const c of meta.charts) push(`${meta.id} 图线`, c.title);
    for (const a of meta.actions) push(`${meta.id} 动作`, a.label);
    // 任务正文是打印在实验页上的,以前这一栏压根没进清单:新场景写错标点没人拦
    for (const t of meta.tasks) push(`${meta.id} 任务`, t.prompt);
  }
  // 细则清单由注册表自己长出来:每个场景声明的 rubricId 顺着索引取回细则。
  // 手写四份的写法在加实验时必然漏掉新细则 —— 新细则的标点就是这样漏检过一次
  const { Rubrics } = require(join(OUT, 'bench/RubricMeasure.cjs'));
  const rubrics = [];
  const seenRubric = [];
  const unresolved = [];
  for (const meta of ExperimentRegistry.all()) {
    if (meta.rubricId.length === 0) {
      continue;
    }
    const found = Rubrics.byId(meta.rubricId);
    if (found === null) {
      unresolved.push(`${meta.id}→${meta.rubricId}`);
      continue;
    }
    if (seenRubric.indexOf(found.id) < 0) {
      seenRubric.push(found.id);
      rubrics.push(found);
    }
  }
  assertTrue('场景声明的细则都能被索引认出', unresolved.length === 0, unresolved.join(','));
  assertTrue('收进清单的细则不止一份', rubrics.length > 1, `${rubrics.length} 份`);
  for (const rubric of rubrics) {
    push(`${rubric.id} 名称`, rubric.label);
    push(`${rubric.id} 来源`, rubric.source);
    push(`${rubric.id} 版本`, rubric.version);
    for (const c of rubric.criteria) {
      push(`${c.id} 扣分标题`, c.title);
      push(`${c.id} 证据`, c.evidenceTemplate);
    }
  }

  // 先确认清单真的收满了:否则两条断言会"零命中"假绿
  assertTrue('可见文案清单收满了场景与细则', visible.length > 80,
    `只收到 ${visible.length} 条`);
  const leaks = visible.filter(([, text]) => BLOCKED.some((w) => text.includes(w)));
  assertTrue('学生可见文案里没有内部术语',
    leaks.length === 0, `${leaks.length} 条命中:${leaks.slice(0, 6).map(([w, t]) => `${w}「${t}」`).join(' / ')}`);
  // 半角标点混在中文里是"AI 写的"最直观的痕迹之一,可见文案一律全角
  const halfWidth = visible.filter(([, text]) => /[一-龥][,;()]|[,;()][一-龥]/.test(text));
  assertTrue('可见文案不混半角标点',
    halfWidth.length === 0, `${halfWidth.length} 条命中:${halfWidth.slice(0, 6).map(([w, t]) => `${w}「${t}」`).join(' / ')}`);
}

// ---- 调色板资源:浅色与深色两套都要过 AA(① 色阶令牌化) ------------------
{
  const { Contrast } = require(join(OUT, 'common/Contrast.cjs'));
  const loadPalette = (rel) => {
    const raw = JSON.parse(readFileSync(join(root, rel), 'utf8'));
    const out = new Map();
    for (const item of raw.color) {
      out.set(item.name, item.value);
    }
    return out;
  };
  const light = loadPalette('entry/src/main/resources/base/element/color.json');
  const dark = loadPalette('entry/src/main/resources/dark/element/color.json');

  const SUBJECTS = ['subject_mechanics', 'subject_electrical', 'subject_chemistry',
    'subject_biology', 'subject_geography', 'subject_math', 'subject_instrument'];
  const BRANDS = ['accent', 'running', 'danger'].concat(SUBJECTS);

  // 判定写成「返回失败清单」而不是「直接 assertTrue」,是为了让"这把尺子真的会拦人"
  // 本身成为一条断言(见下面的负对照)。全是过线断言时,一个写反的比较号会让整节变空转。
  const auditPalette = (mode, pal) => {
    const bad = [];
    const need = (label, fg, bg, floor) => {
      const ratio = Contrast.ratio(fg, bg);
      if (!(ratio >= floor)) {
        bad.push(`${mode}·${label} 需 ≥ ${floor},实得 ${Number.isNaN(ratio) ? String(ratio) : ratio.toFixed(2)}`);
      }
    };
    need('正文压卡片底', pal.get('text_primary'), pal.get('bg_card'), 4.5);
    need('正文压页面底', pal.get('text_primary'), pal.get('bg_page'), 4.5);
    need('次要文字压卡片底', pal.get('text_secondary'), pal.get('bg_card'), 4.5);
    need('次要文字压页面底', pal.get('text_secondary'), pal.get('bg_page'), 4.5);
    need('判定文字压判定卡', pal.get('text_primary'), pal.get('verdict_bg'), 4.5);
    need('学科标签压标签底', pal.get('accent'), pal.get('band_bg'), 4.5);
    if (new Set(SUBJECTS.map((k) => pal.get(k))).size !== SUBJECTS.length) {
      bad.push(`${mode}·七个学科辅色出现重色`);
    }
    for (const key of BRANDS) {
      // 品牌色既当文字也当底色:两条路都要过,否则改一处就破另一处
      need(`${key} 作文字压卡片底`, pal.get(key), pal.get('bg_card'), 4.5);
      need(`${key} 上的前景`, pal.get('on_brand'), pal.get(key), 4.5);
      need(`${key} 作色点压页面底`, pal.get(key), pal.get('bg_page'), 3.0);
    }
    return bad;
  };

  const lightBad = auditPalette('浅色', light);
  const darkBad = auditPalette('深色', dark);
  assertTrue('浅色调色板整体过 AA', lightBad.length === 0, lightBad.join(' / '));
  assertTrue('深色调色板整体过 AA', darkBad.length === 0, darkBad.join(' / '));

  // 负对照:把深色次要文字压成与卡片同族的中灰(真实会犯的错:抄了浅色的值)。
  // 它只该被"次要文字"这两条抓到 —— 报出的条数与名字都必须对得上,才说明尺子在量对的东西。
  const broken = new Map(dark);
  broken.set('text_secondary', '#3A424C');
  const caught = auditPalette('坏样板', broken);
  check('负对照:改坏一个色就红两条', caught.length, 2, 1e-12);
  assertTrue('负对照:报的确实是被改的那一项',
    caught.every((s) => s.indexOf('次要文字') >= 0), caught.join(' / '));

  // 少一个键不会编译报错,只会在深色下悄悄拿浅色值 —— 所以键集合必须严格相等
  const keyDiff = (a, b) => {
    const missing = Array.from(a.keys()).filter((k) => !b.has(k));
    const extra = Array.from(b.keys()).filter((k) => !a.has(k));
    return missing.concat(extra);
  };
  assertTrue('深色与浅色调色板键完全对齐', keyDiff(light, dark).length === 0,
    keyDiff(light, dark).join(','));
  assertTrue('负对照:少写一个键就会被发现', keyDiff(light, new Map(Array.from(dark).slice(1))).length > 0,
    '删掉第一项居然没报错');
  assertTrue('两套调色板都不是空表', light.size >= 20 && dark.size >= 20,
    `浅色 ${light.size} 项 / 深色 ${dark.size} 项`);

  // 画布是"实验纸面":物理求解器按深色笔画在浅底上画,两套都保持浅底
  check('画布底色两套一致(纸面不随深色反转)',
    light.get('bg_canvas') === dark.get('bg_canvas') ? 1 : 0, 1, 1e-12);
  // 图线画在那张纸上,所以两套模式共用同一组色值 —— 若有人"顺手调深"会让曲线消失
  for (const k of ['series_1', 'series_2', 'series_3', 'series_4']) {
    check(`图线色 ${k} 两套一致`, light.get(k) === dark.get(k) ? 1 : 0, 1, 1e-12);
  }

  // 代码里引用的每个 app.color 名字都必须真的存在:$r 写错名字不会编译报错,只会运行时变黑块
  const usedNames = new Set();
  const walkDir = (abs) => {
    for (const entry of readdirSync(abs, { withFileTypes: true })) {
      const full = join(abs, entry.name);
      if (entry.isDirectory()) {
        walkDir(full);
      } else if (entry.name.endsWith('.ets')) {
        const src = readFileSync(full, 'utf8');
        for (const m of src.matchAll(/\$r\('app\.color\.([a-z0-9_]+)'\)/g)) {
          usedNames.add(m[1]);
        }
      }
    }
  };
  walkDir(join(root, 'entry', 'src', 'main', 'ets'));
  const danglingOf = (names) => Array.from(names).filter((n) => !light.has(n) && n !== 'start_window_background');
  assertTrue('代码引用的 app.color 名字都在调色板里', danglingOf(usedNames).length === 0,
    `悬空引用:${danglingOf(usedNames).join(',')}`);
  assertTrue('扫描真的读到了引用(不是空集合骗过上面那条)', usedNames.size > 10,
    `只引用了 ${usedNames.size} 个`);
  const fakeNames = new Set(usedNames);
  fakeNames.add('text_primarry');
  check('负对照:资源名写错一个字母就报悬空', danglingOf(fakeNames).length, 1, 1e-12);

  // 每个令牌在两套里都必须有值且是合法 hex:漏一个值不报错,只在运行时变黑块
  const hexShape = /^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/;
  const malformed = [];
  for (const [mode, pal] of [['浅色', light], ['深色', dark]]) {
    for (const [k, v] of pal) {
      if (typeof v !== 'string' || !hexShape.test(v)) {
        malformed.push(`${mode}.${k}=${JSON.stringify(v)}`);
      }
    }
  }
  assertTrue('两套调色板的每个令牌都是合法 hex', malformed.length === 0, malformed.join(','));
  check('负对照:令牌值写成空串会被认出', hexShape.test('') ? 1 : 0, 0, 1e-12);

  // 画布解析器:未绑定时的回退必须是"看得见的品红"。回透明就是回到那个
  // 不报错、不崩溃、只是三条判读线一起消失的静默 bug(2026-10-11 踩过)。
  const paletteSrc = readFileSync(join(SRC, 'view/Palette.ets'), 'utf8');
  assertTrue('未绑定解析器时回退品红而不是透明',
    paletteSrc.includes("'#FF00FF'") && !paletteSrc.includes("'#00000000'"), '回退值被改回透明或删掉了');
  // 唯一的"保证绑定"点在 ability 里:它比任何组件都先活,删掉等于把静默 bug 放回去
  const abilitySrc = readFileSync(join(SRC, 'entryability/EntryAbility.ets'), 'utf8');
  assertTrue('EntryAbility 仍在启动时绑定画布解析器', abilitySrc.includes('Palette.bind('), '这一行被删掉了');
}

// ---- 深浅色偏好:三档开关的纯逻辑(① 的应用内开关) ------------------------
// 存盘与 setColorMode 都在 platform 层,离线跑不了;但"脏数据不能白屏""标签不能漏内部术语"
// "档位与下标不能错一位"这三件事全是纯算式,而它们恰好是最容易在改 UI 时悄悄坏掉的。
{
  const { Appearance } = require(join(OUT, 'common/Appearance.cjs'));

  check('档位就是三档', Appearance.CHOICES.length, 3, 1e-12);
  // 默认档必须排在第一位:chip 的 0 是"没选过"时的落点
  checkText('第一档是跟随系统', Appearance.at(0), Appearance.SYSTEM);
  checkText('第二档是浅色', Appearance.at(1), Appearance.LIGHT);
  checkText('第三档是深色', Appearance.at(2), Appearance.DARK);

  for (const c of [Appearance.SYSTEM, Appearance.LIGHT, Appearance.DARK]) {
    checkText(`normalize 认得自己的值 ${c}`, Appearance.normalize(c), c);
  }
  for (const junk of ['', '   ', 'LIGHT', 'dark ', 'bogus', 'COLOR_MODE_DARK', 'null', 'undefined']) {
    checkText(`normalize 把脏值「${junk}」回落默认档`, Appearance.normalize(junk), Appearance.SYSTEM);
  }

  for (let i = 0; i < Appearance.CHOICES.length; i++) {
    check(`档位下标往返 ${i}`, Appearance.indexOf(Appearance.at(i)), i, 1e-12);
  }
  // chip 越界(比如以后只剩两档却传了 2)不能崩,也不能画出一个不存在的档
  check('越界下标回落默认档', Appearance.indexOf(Appearance.at(7)), Appearance.indexOf(Appearance.SYSTEM), 1e-12);
  check('负下标回落默认档', Appearance.indexOf(Appearance.at(-1)), Appearance.indexOf(Appearance.SYSTEM), 1e-12);

  const labels = Appearance.CHOICES.map((c) => Appearance.label(c));
  check('三个标签互不相同', new Set(labels).size, labels.length, 1e-12);
  labels.forEach((s, i) => check(`标签 ${i} 是中文而不是标识符`, /^[一-龥]+$/.test(s) ? 1 : 0, 1, 1e-12));

  // 负对照:label 如果直接回显内部标识,这条必须拦下来(④ 定的规矩:屏幕上看不到我们的术语)
  check('负对照:标识符当标签会被拦', /^[一-龥]+$/.test(Appearance.LIGHT) ? 1 : 0, 0, 1e-12);
}

// ---- 场景元数据与实现的一致性 --------------------------------------------
{
  for (const id of ['spring-mass', 'incline-block', 'series-circuit', 'parallel-circuit']) {
    const meta = ExperimentRegistry.find(id).meta;
    const runner = ExperimentRegistry.createRunner(id);
    runner.setup(meta);
    for (const p of meta.params) {
      assertTrue(`${id} 参数 ${p.key} 可读`, Number.isFinite(runner.getParam(p.key)), '默认值不是有限数');
    }
    for (const o of meta.observables) {
      const value = runner.readObservable(o.key);
      const declaredNaN = o.key === 'timeToEnd' || o.key === 'velocityEnd' ||
        o.key === 'distanceMax' || o.key === 'periodMeasured';
      assertTrue(`${id} 观测量 ${o.key} 有实现`,
        Number.isFinite(value) || declaredNaN, `返回 ${value}`);
    }
    // 场景图必须真的产出可绘制图元,否则运行页会是空白
    const snap = runner.snapshot();
    assertTrue(`${id} 场景图非空`,
      snap.boxes.length + snap.springs.length > 0 && snap.segments.length > 0, '缺少图元');
  }
}

// ---- 图线数据的结构约束 ---------------------------------------------------
{
  /*
   * 图表按「横轴数组的第 i 个」配「纵轴数组的第 i 个」画图,所以各序列长度必须
   * 与时间轴严格一致;而图线只能用到已声明为采样的观测量 —— 漏标 sampled 不会报错,
   * 只会画出一张空白图。这两条都在编译期查不出来,必须在这里钉住。
   */
  for (const id of ['spring-mass', 'incline-block', 'series-circuit', 'parallel-circuit']) {
    const meta = ExperimentRegistry.find(id).meta;
    assertTrue(`${id} 至少声明一张图`, meta.charts.length > 0, 'charts 为空');

    for (const chart of meta.charts) {
      const axes = chart.xKey === 't' ? [] : [chart.xKey];
      for (const line of chart.series) {
        axes.push(line.observableKey);
      }
      for (const key of axes) {
        const def = meta.observables.find((o) => o.key === key);
        assertTrue(`${id} 图表「${chart.title}」的 ${key} 已在观测量中声明`,
          def !== undefined, '找不到该观测量');
        assertTrue(`${id} 图表「${chart.title}」的 ${key} 必须标记采样`,
          def.sampled === true, '未标 sampled,图线将始终为空');
      }
    }

    const runner = ExperimentRegistry.createRunner(id);
    runner.setup(meta);
    const controller = new RunController();
    controller.bind(runner, meta);
    controller.start();
    for (let i = 0; i < 120; i++) {
      controller.advance(0.0166);
    }
    const sampledCount = meta.observables.filter((o) => o.sampled).length;
    for (const key of controller.series.keys()) {
      assertTrue(`${id} 序列 ${key} 与时间轴等长`,
        controller.series.get(key).length === controller.times.length,
        `${controller.series.get(key).length} != ${controller.times.length}`);
    }
    check(`${id} 采样序列数量与声明一致`, controller.series.size, sampledCount, 0);
    assertTrue(`${id} 确实采到了数据点`, controller.times.length > 10,
      `只有 ${controller.times.length} 个点`);
  }
}

// ---- 长时运行的资源上界 ---------------------------------------------------
{
  /*
   * 一节课 40~45 分钟。若每个 60Hz 帧都往序列里塞一个点,单个采样量就是 15 万个数,
   * 三个量近 50 万个 —— 大屏设备上会明显吃内存,而图线每次重绘都要把这些点全扫一遍。
   * 这里用「点数必须仍有上界」把问题钉死:上界取 4000,足够画出平滑曲线。
   */
  const meta = ExperimentRegistry.find('spring-mass').meta;
  const runner = ExperimentRegistry.createRunner('spring-mass');
  runner.setup(meta);
  const controller = new RunController();
  controller.bind(runner, meta);
  controller.start();
  const framesOf40Minutes = 60 * 60 * 40;
  const started = process.hrtime.bigint();
  for (let i = 0; i < framesOf40Minutes; i++) {
    controller.advance(1 / 60);
  }
  const elapsedMs = Number(process.hrtime.bigint() - started) / 1e6;

  assertTrue('40 分钟运行的时间轴点数有上界', controller.times.length <= 4000,
    `采样到 ${controller.times.length} 个点`);
  for (const [key, list] of controller.series) {
    assertTrue(`序列 ${key} 长度有上界`, list.length <= 4000, `${list.length} 个点`);
  }
  check('40 分钟仿真时间正确', runner.elapsedTime(), 40 * 60, 1);
  assertTrue('推进 40 帧的耗时可接受', elapsedMs < 4000, `耗时 ${elapsedMs.toFixed(0)} ms`);
  // 抽稀之后仍要能画出完整波形
  const displacement = controller.series.get('displacement');
  const theory = 2 * Math.PI * Math.sqrt(runner.getParam('mass') / runner.getParam('stiffness'));
  assertTrue('抽稀后周期信息未丢失', displacement.length > 4 * (40 * 60 / theory) / 10,
    `仅 ${displacement.length} 点,不足以表现 ${Math.round(40 * 60 / theory)} 个周期`);
}

{
  // restart 必须把采样彻底清空,否则图线会残留上一次实验的数据
  const meta = ExperimentRegistry.find('incline-block').meta;
  const runner = ExperimentRegistry.createRunner('incline-block');
  runner.setup(meta);
  const controller = new RunController();
  controller.bind(runner, meta);
  controller.start();
  for (let i = 0; i < 300; i++) {
    controller.advance(1 / 60);
  }
  assertTrue('运行后确实有采样数据', controller.times.length > 1, '无数据');
  controller.restart();
  check('重置后时间轴清空', controller.times.length, 1, 0);
  for (const [key, list] of controller.series) {
    check(`重置后序列 ${key} 清空`, list.length, 1, 0);
  }
  check('重置后仿真时间归零', runner.elapsedTime(), 0, 1e-9);
}

// ---- 极端参数不允许出现 NaN / 发散 ---------------------------------------
{
  const extremes = [
    { mass: 0.2, stiffness: 100, damping: 3, amplitude: 1.2 },
    { mass: 5, stiffness: 1, damping: 0, amplitude: -1.2 },
    { mass: 0.2, stiffness: 1, damping: 0, amplitude: 0 },
    { mass: 5, stiffness: 100, damping: 0, amplitude: 1.2 }
  ];
  for (const values of extremes) {
    const runner = newSpring(values);
    let worst = 0;
    for (let i = 0; i < 60 * 240; i++) {
      runner.step(1 / 240);
      worst = Math.max(worst, Math.abs(runner.readObservable('displacement')));
    }
    const label = `弹簧振子极端组合 m=${values.mass} k=${values.stiffness} c=${values.damping}`;
    assertTrue(`${label} 未发散`, worst < Math.abs(values.amplitude) * 1.5 + 1e-9,
      `振幅涨到 ${worst.toFixed(3)},初幅 ${values.amplitude}`);
    for (const key of ['displacement', 'velocity', 'acceleration', 'kinetic', 'potential', 'total']) {
      assertTrue(`${label} 的 ${key} 有限`,
        Number.isFinite(runner.readObservable(key)), `得到 ${runner.readObservable(key)}`);
    }
  }
}

{
  const runner = newIncline({ angle: 60, friction: 0, length: 5, mass: 0.2, initialVelocity: 0 });
  run(runner, 6);
  assertTrue('最陡无摩擦斜面正常到底', runner.finished(), '未到达底端');
  const vEnd = Math.sqrt(2 * G * 5 * Math.sin(Math.PI / 3));
  check('最陡斜面的端点速度有限且正确', runner.readObservable('velocityEnd'), vEnd, vEnd * 0.01);

  const crawling = newIncline({ angle: 5, friction: 0.8, length: 1, mass: 5, initialVelocity: 0 });
  run(crawling, 20);
  check('高摩擦小倾角应始终静止', crawling.readObservable('distance'), 0, 1e-9);
  check('静止时不产生摩擦热', crawling.readObservable('heat'), 0, 1e-9);
  assertTrue('静止时不应被误判为到达端点', !crawling.finished(), '被误判结束');
}

{
  const maxed = electrical('series-circuit', { emf: 12, r1: 5, r2: 5, switch: 1 });
  checkRel('最大电压最小电阻时电流仍可解', maxed.readObservable('I:a0'), 1.2, 1e-3);
  const minR = electrical('parallel-circuit', { emf: 2, r1: 5, r2: 5, switch: 1 });
  checkRel('并联取阻值下限时总电阻为 R/2', minR.readObservable('Req'), 2.5, 1e-3);
  const open = electrical('series-circuit', { emf: 6, r1: 20, r2: 30, switch: 0 });
  assertTrue('开路时等效电阻读作无意义而不是 0',
    Number.isNaN(open.readObservable('Req')), `得到 ${open.readObservable('Req')}`);
  const toggled = electrical('series-circuit', { emf: 6, r1: 20, r2: 30, switch: 1 });
  toggled.setParam('switch', 0);
  check('运行中断开开关立即生效', toggled.readObservable('I:a0'), 0, 1e-7);
  toggled.setParam('switch', 1);
  check('重新闭合开关立即恢复', toggled.readObservable('I:a0'), 0.12, 1e-4);
}

// ---- 化学:化学式与式量 ---------------------------------------------------
{
  const { Formula } = require(join(OUT, 'chemistry/Formula.cjs'));

  check('H₂SO₄ 式量', Formula.relativeMass('H2SO4'), 98, 1e-9);
  check('Ca(OH)₂ 式量(嵌套括号)', Formula.relativeMass('Ca(OH)2'), 74, 1e-9);
  // 按教材表 Cu=64 算得 250;用真实值 63.5 才是 249.5。式量必须出自同一张表,不能混用
  check('CuSO₄·5H₂O 式量(结晶水整段乘 5)', Formula.relativeMass('CuSO4·5H2O'), 250, 1e-9);
  check('结晶水只作用于 H₂O 不含主盐', Formula.relativeMass('CuSO4') + 5 * Formula.relativeMass('H2O'),
    250, 1e-9);
  check('Fe₂(SO₄)₃ 式量', Formula.relativeMass('Fe2(SO4)3'), 400, 1e-9);
  check('NH₄NO₃ 式量', Formula.relativeMass('NH4NO3'), 80, 1e-9);
  check('CH₃COOC₂H₅ 式量(有机物长链)', Formula.relativeMass('CH3COOC2H5'), 88, 1e-9);
  check('Cl 的相对原子质量取教材值 35.5', Formula.relativeMass('HCl'), 36.5, 1e-9);

  const sulfate = Formula.parse('SO4^2-');  check('硫酸根电荷', sulfate.charge, -2, 1e-9);
  check('高锰酸根电荷', Formula.parse('MnO4^-').charge, -1, 1e-9);
  check('钡离子电荷', Formula.parse('Ba^2+').charge, 2, 1e-9);
  check('中性分子电荷为零', Formula.parse('H2O').charge, 0, 1e-9);
  check('带电荷时原子数仍正确', sulfate.counts.get('O'), 4, 1e-9);

  assertTrue('未知元素被拒绝', Formula.parse('Xy2O3').error.length > 0, '未报错');
  assertTrue('括号未闭合被拒绝', Formula.parse('Ca(OH2').error.length > 0, '未报错');
  assertTrue('合法式不误报', Formula.parse('KMnO4').error.length === 0, Formula.parse('KMnO4').error);
}

// ---- 化学:反应表的守恒校验 -----------------------------------------------
{
  const { ChemistryLibrary, Reagents } = require(join(OUT, 'chemistry/ChemistryLibrary.cjs'));
  const { ReactionValidator } = require(join(OUT, 'chemistry/ChemistryModel.cjs'));
  ChemistryLibrary.registerReagents();
  const reactions = ChemistryLibrary.all();

  assertTrue('反应表非空', reactions.length >= 20, `只有 ${reactions.length} 条`);
  assertTrue('试剂表非空', Reagents.size() >= 40, `只有 ${Reagents.size()} 种`);

  let issueCount = 0;
  for (const reaction of reactions) {
    const issues = ReactionValidator.check(reaction);
    for (const issue of issues) {
      issueCount++;
      failures.push(`反应 ${reaction.id} [${issue.side}] ${issue.detail}`);
    }
    // 现象与条件是「足够真实」的载体,空着等于没做这个实验
    assertTrue(`${reaction.id} 必须有现象描述`, reaction.phenomena.length > 0, 'phenomena 为空');
    assertTrue(`${reaction.id} 标题与学段齐备`,
      reaction.title.length > 0 && reaction.band.length > 0, '元数据缺失');
    // 每个反应项都要能拼出完整的显示文本
    for (const item of reaction.reactants.concat(reaction.products)) {
      assertTrue(`${reaction.id} 的 ${item.substance.formula} 有中文名`,
        item.substance.name.length > 0, 'name 为空');
    }
    if (reaction.ionic !== null) {
      const ionicIssues = ReactionValidator.check(reaction.ionic);
      for (const issue of ionicIssues) {
        issueCount++;
        failures.push(`离子式 ${reaction.id} [${issue.side}] ${issue.detail}`);
      }
    }
  }
  check('全部反应通过守恒校验', issueCount, 0, 0);

  const bands = new Set(reactions.map((r) => r.band));
  assertTrue('覆盖初中', bands.has('初中'), '缺少初中反应');
  assertTrue('覆盖高中', bands.has('高中'), '缺少高中反应');
  assertTrue('覆盖大学', bands.has('大学'), '缺少大学反应');
  const withSafety = reactions.filter((r) => r.safety.length > 0).length;
  assertTrue('多数反应带安全提示', withSafety >= reactions.length * 0.5,
    `${withSafety}/${reactions.length} 条有 safety`);

  // 方程式文本:界面与报告都直接显示它,拼错等于把对的方程式显示成错的
  const { ReactionText } = require(join(OUT, 'chemistry/ChemistryModel.cjs'));
  const kmno4 = reactions.find((r) => r.id === 'kmno4-o2');
  checkText('加热高锰酸钾的方程式文本', ReactionText.equation(kmno4),
    '2KMnO4 →(加热) K2MnO4 + MnO2 + O2↑');
  const ester = reactions.find((r) => r.id === 'esterification');
  assertTrue('可逆反应用可逆号', ReactionText.equation(ester).includes('⇌'),
    ReactionText.equation(ester));
  const zinc = reactions.find((r) => r.id === 'zn-h2');
  checkText('系数为 1 时省略数字', ReactionText.equation(zinc),
    'Zn + H2SO4 → ZnSO4 + H2↑');
  const barium = reactions.find((r) => r.id === 'bacl2-na2so4');
  checkText('沉淀标记保留', ReactionText.equation(barium.ionic),
    'Ba^2+ + SO4^2- → BaSO4↓');
  assertTrue('多个条件用顿号连接',
    ReactionText.equation(reactions.find((r) => r.id === 'nh3-oxidation')).includes('、'),
    '未连接条件');
}

// ---- 化学:校验器必须真的会拒绝错误的方程式 --------------------------------
{
  /*
   * 一个从不报错的校验器等于没有。这里故意喂进配平错误、电荷不平、
   * 漏写元素、旁观离子删错的方程式,逐条确认它们被抓出来。
   * 这四条同时也是校验器行为的说明书。
   */
  const { ReactionValidator, ReactionType } = require(join(OUT, 'chemistry/ChemistryModel.cjs'));
  const { term, reaction } = require(join(OUT, 'chemistry/ChemistryLibrary.cjs'));

  const badBalance = reaction('bad-balance', '故意漏配系数', ReactionType.COMBUSTION, '初中');
  badBalance.reactants.push(term('ch4', 1, ''), term('o2', 1, ''));
  badBalance.products.push(term('co2', 1, ''), term('h2o', 2, ''));
  assertTrue('漏配 O₂ 系数被抓出', ReactionValidator.check(badBalance).length > 0, '居然通过了');

  const badCharge = reaction('bad-charge', '故意漏配电荷', ReactionType.METATHESIS, '高中');
  badCharge.reactants.push(term('ba2', 1, ''), term('so4', 1, ''));
  badCharge.products.push(term('baso4', 1, ''), term('hion', 1, ''));
  const chargeIssues = ReactionValidator.check(badCharge);
  assertTrue('电荷不平被抓出', chargeIssues.some((i) => i.side === '电荷'), '居然通过了');

  const strayElement = reaction('stray', '右侧多出元素', ReactionType.COMBINATION, '初中');
  strayElement.reactants.push(term('h2o', 2, ''));
  strayElement.products.push(term('h2', 2, ''), term('o2', 1, ''), term('co2', 1, ''));
  assertTrue('凭空多出碳元素被抓出',
    ReactionValidator.check(strayElement).some((i) => i.detail.includes('只在右侧')), '居然通过了');

  const badMass = reaction('bad-mass', '系数导致质量不守恒', ReactionType.DECOMPOSITION, '初中');
  badMass.reactants.push(term('kmno4', 2, ''));
  badMass.products.push(term('k2mno4', 1, ''), term('mno2', 1, ''));
  assertTrue('少一个 O₂ 导致质量不等被抓出',
    ReactionValidator.check(badMass).some((i) => i.side === '质量'), '居然通过了');

  // 离子式删错旁观离子:NaCl 里的 Cl 该整条删掉,漏删会让元素净变化对不上
  const wrongIonic = reaction('wrong-ionic', '离子式漏删旁观离子', ReactionType.METATHESIS, '高中');
  wrongIonic.reactants.push(term('bacl2', 1, ''), term('na2so4', 1, ''));
  wrongIonic.products.push(term('baso4', 1, '↓'), term('nacl', 2, ''));
  const nested = reaction('wrong-ionic-inner', '离子方程式', ReactionType.METATHESIS, '高中');
  nested.reactants.push(term('ba2', 1, ''), term('so4', 1, ''), term('clion', 2, ''));
  nested.products.push(term('baso4', 1, '↓'));
  wrongIonic.ionic = nested;
  assertTrue('离子式多留氯离子被抓出',
    ReactionValidator.check(wrongIonic).some((i) => i.side === '离子式'), '居然通过了');

  const emptySide = reaction('empty', '右侧为空', ReactionType.COMBINATION, '初中');
  emptySide.reactants.push(term('h2o', 1, ''));
  assertTrue('生成物为空被抓出',
    ReactionValidator.check(emptySide).some((i) => i.side === '右'), '居然通过了');
}

// ---- 实验台:拖动混合后的真实后果 -----------------------------------------
{
  const { Vessel, VesselKind, PORTION_MOLES } = require(join(OUT, 'chemistry/BenchModel.cjs'));
  const { BenchEngine } = require(join(OUT, 'chemistry/BenchEngine.cjs'));
  const { ChemistryLibrary, Reagents, massOf } = require(join(OUT, 'chemistry/ChemistryLibrary.cjs'));
  ChemistryLibrary.registerReagents();
  const bench = ChemistryLibrary.bench();

  function tube() {
    const vessel = Vessel.of(VesselKind.TUBE, '试管', 8);
    vessel.id = 't1';
    return vessel;
  }
  function fill(vessel, pairs) {
    for (const [key, portions] of pairs) {
      assertTrue('加入药品未被容量拦下', BenchEngine.add(vessel, key, portions * PORTION_MOLES),
        `${key} 加入失败`);
    }
    return vessel;
  }
  /** 容器内存量 + 已逸出 = 加入总量,这条不变量能把任何配平或换算错误逼出来 */
  function assertMassConserved(label, vessel, inputMass) {
    const kept = BenchEngine.massIn(vessel);
    const gone = BenchEngine.massEscaped(vessel);
    checkRel(label, kept + gone, inputMass, 1e-9);
  }
  function inputMassOf(pairs) {
    let sum = 0;
    for (const [key, portions] of pairs) {
      sum += portions * PORTION_MOLES * massOf(key);
    }
    return sum;
  }

  assertTrue('实验台可用反应数量合理', bench.length >= 10, `只有 ${bench.length} 条`);
  assertTrue('需要通风橱/滴定管的反应不进实验台',
    !bench.some((r) => r.id === 'cl2-naoh' || r.id === 'kmno4-oxalic'), '误收不可桌面反应');

  // 事件必须**自带**配平好的方程式。只测 ReactionText 是不够的:
  // 引擎不把式子填进 BenchEvent,页面就什么也显示不出来,而那条断言照样全绿。
  {
    const { ReactionText } = require(join(OUT, 'chemistry/ChemistryModel.cjs'));
    let fired = 0;
    let missingEq = [];
    for (const spec of bench) {
      if (!spec.needsHeat && !spec.needsPower && spec.catalystKeys.length > 0) {
        continue;
      }
      const v = tube();
      for (const term of spec.reactants) {
        BenchEngine.add(v, term.substance.key, 3 * PORTION_MOLES);
      }
      if (spec.needsHeat) {
        v.heated = true;
      }
      const events = BenchEngine.react(v, [spec]);
      for (const ev of events) {
        if (ev.reactionId.length === 0) {
          continue;
        }
        fired++;
        if (ev.equation.length === 0 || ev.equation !== ReactionText.equation(spec)) {
          missingEq.push(`${spec.id}:实得「${ev.equation}」`);
        }
      }
    }
    assertTrue('确实有反应在实验台上跑起来了(否则下面那条是空话)', fired >= 3, `只跑到 ${fired} 次`);
    assertTrue('跑起来的反应,事件都带着与式量表一致的方程式', missingEq.length === 0,
      missingEq.slice(0, 3).join(' | '));
  }

  // 条件闸门:没加热就不能分解
  {
    const vessel = fill(tube(), [['kmno4', 2]]);
    const cold = BenchEngine.react(vessel, bench);
    check('高锰酸钾常温不分解', cold.length, 0, 0);
    check('常温下高锰酸钾仍在容器中', vessel.contents[0].moles, 2 * PORTION_MOLES, 1e-12);
    const hints = BenchEngine.pendingHints(vessel, bench);
    assertTrue('未加热时提示「需要加热」', hints.some((h) => h.includes('加热')), hints.join('|'));

    vessel.heated = true;
    const hot = BenchEngine.react(vessel, bench);
    assertTrue('加热后分解发生', hot.length > 0, '无事件');
    check('生成氧气并已逸出', BenchEngine.massEscaped(vessel),
      1 * PORTION_MOLES * massOf('o2'), 1e-9);
    assertMassConserved('加热分解总质量守恒(含逸出)', vessel, inputMassOf([['kmno4', 2]]));
    assertTrue('固体残留锰酸钾与二氧化锰', vessel.contents.length === 2,
      `残留 ${vessel.contents.length} 种`);
  }

  // 催化剂:没有 MnO₂ 不放行,有则不被消耗
  {
    const plain = fill(tube(), [['h2o2', 3]]);
    check('未加催化剂时过氧化氢不分解', BenchEngine.react(plain, bench).length, 0, 0);

    const vessel = fill(tube(), [['h2o2', 3], ['mno2', 1]]);
    const before = vessel.contents.find((c) => c.key === 'mno2').moles;
    BenchEngine.react(vessel, bench);
    const after = vessel.contents.find((c) => c.key === 'mno2').moles;
    check('二氧化锰反应前后质量不变', after, before, 1e-12);
    check('过氧化氢已完全分解', (vessel.contents.find((c) => c.key === 'h2o2') || { moles: 0 }).moles,
      0, 1e-12);
    assertMassConserved('催化分解总质量守恒', vessel,
      inputMassOf([['h2o2', 3], ['mno2', 1]]));
  }

  // 限量试剂:盐酸不足时碳酸钙有剩余
  {
    const vessel = fill(tube(), [['caco3', 2], ['hcl', 1]]);
    const events = BenchEngine.react(vessel, bench);
    check('大理石与盐酸反应', events.length, 1, 0);
    const left = vessel.contents.find((c) => c.key === 'caco3');
    // 2 份 CaCO₃(0.04 mol)配 1 份 HCl(0.02 mol),盐酸按系数 2 只够反应 0.01 mol
    check('盐酸不足时碳酸钙剩余 0.03 mol', left.moles, 0.03, 1e-12);
    assertTrue('盐酸被耗尽', !vessel.contents.some((c) => c.key === 'hcl'), '仍有盐酸');
    check('生成的 CO₂ 全部逸出', BenchEngine.massEscaped(vessel),
      0.5 * PORTION_MOLES * massOf('co2'), 1e-9);
    assertMassConserved('限量反应总质量守恒', vessel,
      inputMassOf([['caco3', 2], ['hcl', 1]]));
  }

  // 敞口容器变轻:这是「反应前后称量」考点的真实来源
  {
    const vessel = fill(tube(), [['caco3', 1], ['hcl', 2]]);
    const started = BenchEngine.massIn(vessel);
    BenchEngine.react(vessel, bench);
    assertTrue('逸出气体使容器质量减小', BenchEngine.massIn(vessel) < started,
      `${BenchEngine.massIn(vessel)} ≥ ${started}`);
    const lost = started - BenchEngine.massIn(vessel);
    checkRel('减轻的质量等于逸出的 CO₂ 质量', lost, BenchEngine.massEscaped(vessel), 1e-9);
  }

  // 置换与沉淀
  {
    const vessel = fill(tube(), [['fe', 1], ['cuso4', 1]]);
    BenchEngine.react(vessel, bench);
    assertTrue('生成铜单质留在容器', vessel.contents.some((c) => c.key === 'cu'), '没有铜');
    assertTrue('生成硫酸亚铁使溶液呈浅绿色', vessel.contents.some((c) => c.key === 'feso4'),
      '没有硫酸亚铁');
    check('该反应无气体逸出', BenchEngine.massEscaped(vessel), 0, 1e-12);
    assertMassConserved('置换反应质量守恒', vessel, inputMassOf([['fe', 1], ['cuso4', 1]]));
    const view = BenchEngine.viewOf(vessel, false);
    checkText('溶液颜色取硫酸亚铁的浅绿色', view.liquidColor, '#7FC8A9');
    assertTrue('不溶物被列为固体', view.solids.length >= 1, 'solids 为空');
  }

  {
    const vessel = fill(tube(), [['bacl2', 1], ['na2so4', 1]]);
    const events = BenchEngine.react(vessel, bench);
    assertTrue('生成硫酸钡沉淀', events.some((e) => e.precipitates.length > 0),
      JSON.stringify(events.map((e) => e.precipitates)));
    assertTrue('沉淀留在容器中', vessel.contents.some((c) => c.key === 'baso4'), '沉淀不见了');
    assertMassConserved('沉淀反应质量守恒(无损失)', vessel,
      inputMassOf([['bacl2', 1], ['na2so4', 1]]));
    check('无气体时容器质量不变', BenchEngine.massEscaped(vessel), 0, 1e-12);
  }

  // 乱倒不能凭空出名堂
  {
    const vessel = fill(tube(), [['nacl', 2], ['na2so4', 2]]);
    check('两种钠盐溶液混合不反应', BenchEngine.react(vessel, bench).length, 0, 0);
    assertMassConserved('不反应时质量原样保留', vessel,
      inputMassOf([['nacl', 2], ['na2so4', 2]]));
    check('容器内容种类数不变', vessel.contents.length, 2, 0);
  }

  // 倾倒合并与容量约束
  {
    const a = fill(tube(), [['agno3', 1]]);
    const b = fill(tube(), [['nacl', 1]]);
    assertTrue('倾倒成功', BenchEngine.pourInto(a, b), '被拒绝');
    check('倒空的容器不留药品', b.contents.length, 0, 0);
    const events = BenchEngine.react(a, bench);
    assertTrue('合并后生成氯化银沉淀', events.some((e) => e.precipitates.length > 0), '无沉淀');

    const over = tube();
    over.capacity = 3;
    assertTrue('超过容量时拒绝加入', BenchEngine.add(over, 'h2o', 4 * PORTION_MOLES) === false,
      '居然加进去了');
    check('被拒绝后容器仍为空', over.contents.length, 0, 0);

    // 试管默认容量 8,这里显式收窄才能测到溢出
    const full = fill(tube(), [['h2o', 5]]);
    full.capacity = 6;
    const extra = fill(tube(), [['hcl', 3]]);
    assertTrue('倒满后不能再并入', BenchEngine.pourInto(full, extra) === false, '居然并进去了');
    assertTrue('被拒绝的倾倒不清空来源容器', extra.contents.length > 0, '来源被倒空了');
    assertTrue('被拒绝时目标容器内容不变', BenchEngine.portionsOf(full) === 5,
      `目标容器剩 ${BenchEngine.portionsOf(full)} 份`);
  }

  // 钠与水:剧烈反应且有氢气逸出
  {
    const vessel = fill(tube(), [['na', 1], ['h2o', 4]]);
    const events = BenchEngine.react(vessel, bench);
    check('钠与水反应发生', events.length, 1, 0);
    assertTrue('生成氢氧化钠使溶液呈碱性', vessel.contents.some((c) => c.key === 'naoh'), '无 NaOH');
    assertTrue('有氢气逸出', BenchEngine.massEscaped(vessel) > 0, '没有气体');
    assertMassConserved('钠与水总质量守恒', vessel, inputMassOf([['na', 1], ['h2o', 4]]));
  }

  // 药品柜由反应表推导:既不能漏药(桌面反应做不成),也不能多药(摆着永远用不上)
  const shelf = ChemistryLibrary.shelf();
  assertTrue('药品柜非空', shelf.length >= 12, `只有 ${shelf.length} 瓶`);
  const needed = new Set();
  for (const spec of bench) {
    for (const t of spec.reactants) {
      needed.add(t.substance.key);
    }
    for (const c of spec.catalystKeys) {
      needed.add(c);
    }
  }
  check('药品柜数量与所需试剂数一致', shelf.length, needed.size, 0);
  for (const key of needed) {
    assertTrue(`桌面反应需要的 ${key} 在药品柜里`, shelf.includes(key), '缺药,反应做不成');
  }
  for (const key of shelf) {
    assertTrue(`药品柜里的 ${key} 确有用途`, needed.has(key), '摆了用不上的药');
    assertTrue(`${key} 可从试剂表取到`, Reagents.get(key).name.length > 0, '名称缺失');
  }
  checkText('药品柜按键名有序', shelf.join(), [...shelf].sort().join());
}

// ---- M0 世界内核:器皿几何与物质账本 --------------------------------------
{
  const { Profile, Glassware } = require(join(OUT, 'geometry/Profile.cjs'));
  const { Brine, Separations, Calibration } = require(join(OUT, 'bench/Brine.cjs'));

  // 1. 几何:容积↔高度必须互为逆运算,否则「液面高过滤纸多少」就算不出来
  const cylinder = Glassware.graduatedCylinder10();
  checkText('量筒量程约 10 mL', (cylinder.capacity() > 9.9 && cylinder.capacity() < 10.1) ? 'ok' : 'no', 'ok');
  for (const v of [0, 1.5, 3.7, 5, 8.2, 10]) {
    const back = cylinder.volumeBelow(cylinder.heightForVolume(v));
    check(`量筒容积↔高度互逆 v=${v}`, back, v, 1e-6);
  }
  check('量筒总高 15 cm', cylinder.totalHeight(), 15, 1e-9);
  checkText('高度单调:体积越大液面越高',
    (cylinder.heightForVolume(3) < cylinder.heightForVolume(6)) ? 'ok' : 'no', 'ok');

  const beaker = Glassware.beaker100();
  checkRel('烧杯标称 100 mL', beaker.capacity(), 100, 0.05);
  checkText('烧杯上口更大 → 同体积液面低于直筒',
    (beaker.heightForVolume(60) < cylinder.heightForVolume(60) * 100) ? 'low' : 'high', 'low');
  checkRel('蒸发皿浅而宽(面积约 30 cm²)', Glassware.evaporatingDish().areaAt(0.5), 28, 0.2);

  const empty = Profile.cylinder(5, 4);
  check('空容器液面为 0', empty.heightForVolume(0), 0, 1e-12);
  check('体积超量程按满量程封顶', empty.heightForVolume(999), empty.totalHeight(), 1e-12);
  check('体积为负按 0 处理', empty.heightForVolume(-3), 0, 1e-12);

  // 2. 账本守恒:整条粗盐提纯流程跑完,现存 + 逸出 + 损失 = 加入量
  function runProcess(stirredDuringEvaporation, bypassOfOverflow) {
    const beakerBrine = new Brine();
    const filtrate = new Brine();
    const residue = new Brine();

    Separations.addCrudeSalt(beakerBrine, 4.0, 1.0);
    Separations.addWater(beakerBrine, 10);
    const introduced = beakerBrine.totalAccounted();

    for (let i = 0; i < 400; i++) {
      Separations.dissolve(beakerBrine, 0.25, true);
    }
    // 先倒清液走正常过滤,再把底部含泥沙的部分连同溢流倒掉
    Separations.pour(beakerBrine, residue, 8.0, 0);
    let carried = 0;
    for (let i = 0; i < 100; i++) {
      Separations.settle(residue, 0.25);
    }
    const clearVolume = residue.waterMl * 0.7;
    Separations.filter(residue, filtrate, clearVolume, 0);
    // 液面高过滤纸边缘的那部分:悬浊液直灌,穿透比例由几何层传入
    const overflowVolume = residue.waterMl;
    Separations.filter(residue, filtrate, overflowVolume, bypassOfOverflow);

    let area = Glassware.evaporatingDish().areaAt(0.2);
    for (let i = 0; i < 3000; i++) {
      area = Glassware.evaporatingDish().areaAt(
        filtrate.waterMl > 0 ? Math.min(4, filtrate.waterMl / 30) : 0);
      Separations.evaporate(filtrate, 0.1, area, stirredDuringEvaporation);
    }
    return { beakerBrine, filtrate, residue, introduced };
  }

  const clean = runProcess(true, 0);
  checkRel('流程守恒(搅拌、无溢流)',
    (clean.filtrate.totalAccounted() + clean.beakerBrine.totalAccounted()
      + clean.residue.totalAccounted()), clean.introduced, 1e-9);
  check('正常过滤后滤液不含泥沙', clean.filtrate.sandSuspendedG, 0, 1e-12);
  check('正常过滤后滤液浊度为 0', clean.filtrate.turbidity(), 0, 1e-12);
  assertTrue('精盐已析出(有固态 NaCl 剩余)', clean.filtrate.saltSolidG > 0, '没蒸干');
  check('蒸干后已无溶液', clean.filtrate.waterMl, 0, 1e-9);
  check('蒸发过程无溅失', clean.filtrate.losses.spilledSaltG, 0, 1e-12);
  // 绝对产率取决于 Calibration 系数(未经实测),因此只断言回收率上限=投入量
  assertTrue('搅拌蒸发回收率不超过投入量',
    (clean.filtrate.totalAccounted() - clean.filtrate.losses.mass()) <= 5.0 + 1e-9,
    `回收 ${clean.filtrate.totalAccounted() - clean.filtrate.losses.mass()}`);

  // 3. 飞溅导致产率下降 —— 这就是「必须搅拌」扣分点的物理依据
  const messy = runProcess(false, 0);
  assertTrue('不搅拌会溅失 NaCl', messy.filtrate.losses.spilledSaltG > 0.01,
    `溅失 ${messy.filtrate.losses.spilledSaltG} g`);
  assertTrue('不搅拌的回收率低于搅拌',
    (messy.filtrate.totalAccounted() - messy.filtrate.losses.mass()) <
    (clean.filtrate.totalAccounted() - clean.filtrate.losses.mass()),
    '搅拌反而更差');
  checkRel('流程守恒(未搅拌)',
    (messy.filtrate.totalAccounted() + messy.beakerBrine.totalAccounted()
      + messy.residue.totalAccounted()), messy.introduced, 1e-9);

  // 4. 溢流让泥沙进滤液 —— 滤液浑浊是算出来的,不是标记出来的。
  //    绝对浊度阈值取决于未实测的 Calibration,所以只断言单调关系。
  const turbid = runProcess(true, 1);
  assertTrue('溢流后滤液含泥沙', turbid.filtrate.sandSuspendedG > 0,
    `${turbid.filtrate.sandSuspendedG} g`);
  assertTrue('溢流使滤液浊度上升', turbid.filtrate.turbidity() > clean.filtrate.turbidity(),
    `${turbid.filtrate.turbidity()} ≤ ${clean.filtrate.turbidity()}`);
  checkRel('溢流流程同样守恒',
    (turbid.filtrate.totalAccounted() + turbid.beakerBrine.totalAccounted()
      + turbid.residue.totalAccounted()), turbid.introduced, 1e-9);

  {
    const source = new Brine();
    const to = new Brine();
    Separations.addWater(source, 10);
    source.sandSuspendedG = 1.0;
    let prevTurbidity = -1;
    for (const carry of [0, 0.25, 0.5, 1]) {
      const s = new Brine();
      const f = new Brine();
      s.waterMl = 10;
      s.sandSuspendedG = 1.0;
      Separations.filter(s, f, 10, carry);
      // carry=0 即正常滤纸:全部泥沙被截留,滤液应绝对清澈
      checkRel(`穿透比例 ${carry} 时进入滤液的泥沙 = 1g × carry`,
        f.sandSuspendedG, carry, 1e-9);
      assertTrue(`浊度随穿透比例单调上升(carry=${carry})`, f.turbidity() > prevTurbidity,
        `${f.turbidity()} ≤ ${prevTurbidity}`);
      prevTurbidity = f.turbidity();
      checkRel(`过滤不改变总质量(carry=${carry})`, s.mass() + f.mass(), 11.0, 1e-9);
    }
  }

  // 5. 溶解度上限:超过饱和的盐必须以固体形式留着
  {
    const b = new Brine();
    Separations.addWater(b, 10);
    Separations.addCrudeSalt(b, 20, 0);
    for (let i = 0; i < 5000; i++) {
      Separations.dissolve(b, 0.25, true);
    }
    checkRel('10 mL 水饱和溶解约 3.6 g NaCl', b.saltDissolvedG,
      10 * Calibration.NACL_SOLUBILITY, 1e-6);
    assertTrue('过量盐仍未溶解', b.saltSolidG > 16, `${b.saltSolidG}`);
  }

  // 6. 沉降与搅拌可逆;倾倒不凭空产生质量
  {
    const b = new Brine();
    Separations.addWater(b, 20);
    Separations.addCrudeSalt(b, 0, 2.0);
    for (let i = 0; i < 100; i++) {
      Separations.settle(b, 0.25);
    }
    check('静置后全部沉底', b.sandSuspendedG, 0, 1e-9);
    checkRel('沉底质量等于加入量', b.sandSettledG, 2.0, 1e-9);
    const massBefore = b.mass();
    for (let i = 0; i < 40; i++) {
      Separations.stirSand(b, 0.25, true);
    }
    checkRel('搅拌不改变总质量', b.mass(), massBefore, 1e-9);
    assertTrue('搅拌重新扬起泥沙', b.sandSuspendedG > 0.01, `${b.sandSuspendedG}`);

    const into = new Brine();
    check('倒不出空气', Separations.pour(b, into, 5, 0), 5, 1e-12);
    Separations.pour(b, into, 999, 0);
    checkRel('倒超了只搬得走现有的', b.waterMl, 0, 1e-9);
    checkRel('倾倒前后总质量不变', b.mass() + into.mass(), massBefore, 1e-9);
    check('空容器倒不出东西', Separations.pour(b, into, 3, 0), 0, 1e-12);
  }

  // 7. 确定性:同一段操作跑两遍必须完全一致(评分可重放的前提)
  {
    const signature = () => {
      const a = new Brine();
      const c = new Brine();
      Separations.addCrudeSalt(a, 4.0, 1.0);
      Separations.addWater(a, 10);
      for (let i = 0; i < 300; i++) {
        Separations.dissolve(a, 0.2, true);
      }
      for (let i = 0; i < 60; i++) {
        Separations.settle(a, 0.2);
      }
      Separations.pour(a, c, 6.0, 0.2);
      Separations.filter(c, new Brine(), 3, 0.4);
      for (let i = 0; i < 500; i++) {
        Separations.evaporate(c, 0.1, 30, false);
      }
      return `${c.waterMl}|${c.saltDissolvedG}|${c.saltSolidG}|${c.sandSuspendedG}|${c.losses.spilledSaltG}`;
    };
    checkText('两次运行结果完全一致', signature(), signature());
  }
}

// ---- M1 容器、倾倒与量筒读数 ----------------------------------------------
{
  const { Profile, Glassware } = require(join(OUT, 'geometry/Profile.cjs'));
  const { Brine, Separations, Calibration } = require(join(OUT, 'bench/Brine.cjs'));
  const { Container, PourModel, ReadingModel } = require(join(OUT, 'bench/Container.cjs'));
  const { Support } = require(join(OUT, 'bench/Pose.cjs'));

  function vessel(label, profile) {
    return Container.of(label, label, profile);
  }
  /** 把源容器倒空(或到达步数上限),累计各步结果 */
  function drainAll(source, target, guided, limit = 40000) {
    const total = { left: 0, arrived: 0, spilled: 0, overflowCount: 0 };
    for (let i = 0; i < limit && source.brine.waterMl > 1e-9; i++) {
      const r = PourModel.step(source, target, 1 / 60, guided);
      total.left += r.leftSourceMl;
      total.arrived += r.arrivedMl;
      total.spilled += r.spilledMl;
      if (r.overflowed) {
        total.overflowCount++;
      }
    }
    return total;
  }

  // 1. 容器几何
  const beaker = vessel('烧杯', Glassware.beaker100());
  check('空烧杯液面为 0', beaker.liquidHeight(), 0, 1e-12);
  check('空烧杯装填率为 0', beaker.fillRatio(), 0, 1e-12);
  check('空烧杯可用容量即满量程', beaker.freeCapacityMl(), beaker.profile.capacity(), 1e-6);
  beaker.brine.waterMl = 40;
  checkRel('40 mL 时液面高度与几何逆算一致', beaker.profile.volumeBelow(beaker.liquidHeight()), 40, 1e-9);
  checkRel('装填率 0.4', beaker.fillRatio(), 0.4, 0.02);
  checkRel('剩余容量 60 mL', beaker.freeCapacityMl(), 60, 0.02 * 60);
  const areaLow = beaker.surfaceArea();
  beaker.brine.waterMl = 90;
  assertTrue('烧杯越满液面面积越大(锥形)', beaker.surfaceArea() > areaLow,
    `${beaker.surfaceArea()} ≤ ${areaLow}`);
  assertTrue('未装满时不判为满', beaker.isFull() === false, '判成满了');
  beaker.brine.waterMl = beaker.profile.capacity();
  check('装满后剩余容量为 0', beaker.freeCapacityMl(), 0, 1e-9);

  // 2. 流速:起倒仰角、随仰角与液柱的变化
  check('仰角不足则倒不出', PourModel.flowRate(Calibration.POUR_ONSET_DEG - 2, 5), 0, 1e-12);
  check('没液体则倒不出', PourModel.flowRate(80, 0), 0, 1e-12);
  let prevRate = -1;
  for (const tilt of [15, 30, 45, 60, 80]) {
    const rate = PourModel.flowRate(tilt, 5);
    assertTrue(`流速随仰角单调上升(${tilt}°)`, rate > prevRate, `${rate} ≤ ${prevRate}`);
    prevRate = rate;
  }
  assertTrue('液柱越低流速越慢',
    PourModel.flowRate(70, 2) < PourModel.flowRate(70, 8), '与托里拆利相反');

  // 3. 引流 vs 直接对倒:后者溅得明显更多 —— 这是「必须用玻璃棒引流」的物理后果
  function trial(guided) {
    const source = vessel('源', Glassware.beaker100());
    const target = vessel('接收', Glassware.beaker100());
    source.pose.tiltDeg = 70;
    source.support = Support.HELD;
    Separations.addWater(source.brine, 80);
    Separations.addCrudeSalt(source.brine, 20, 3);
    for (let i = 0; i < 300; i++) {
      Separations.dissolve(source.brine, 0.2, true);
    }
    source.brine.sandSuspendedG += 0.0001; // 保证有悬浮物参与溅失比例
    const introduced = source.brine.totalAccounted();
    const stats = drainAll(source, target, guided);
    return { source, target, introduced, stats };
  }
  const guidedTrial = trial(true);
  const roughTrial = trial(false);
  assertTrue('不引流溅失更多',
    roughTrial.target.brine.losses.spillMass() > guidedTrial.target.brine.losses.spillMass() * 3,
    `不引流 ${roughTrial.target.brine.losses.spillMass()} vs 引流 ${guidedTrial.target.brine.losses.spillMass()}`);
  checkRel('倾倒全程守恒(引流)',
    guidedTrial.source.brine.totalAccounted() + guidedTrial.target.brine.totalAccounted(),
    guidedTrial.introduced, 1e-9);
  checkRel('倾倒全程守恒(不引流)',
    roughTrial.source.brine.totalAccounted() + roughTrial.target.brine.totalAccounted(),
    roughTrial.introduced, 1e-9);
  check('倒空后源容器无液体', guidedTrial.source.brine.waterMl, 0, 1e-9);
  assertTrue('到达量不超过离开量',
    guidedTrial.stats.arrived <= guidedTrial.stats.left + 1e-9, '凭空多了');
  checkRel('离开量 = 到达 + 溅失', guidedTrial.stats.left,
    guidedTrial.stats.arrived + guidedTrial.stats.spilled, 1e-9);

  // 4. 溢出:目标装不下时液面被压回杯口,多出来的算洒掉
  {
    const source = vessel('源', Glassware.beaker100());
    const small = vessel('小筒', Glassware.graduatedCylinder10());
    source.pose.tiltDeg = 80;
    source.support = Support.HELD;
    Separations.addWater(source.brine, 30);
    Separations.addWater(small.brine, 9.5);
    const introduced = source.brine.totalAccounted() + small.brine.totalAccounted();
    drainAll(source, small, true);
    assertTrue('小容器不会装超量程',
      small.brine.waterMl <= small.profile.capacity() + 1e-9,
      `溢出后仍有 ${small.brine.waterMl} mL`);
    assertTrue('溢出确实发生了', small.brine.losses.spilledWaterMl > 1,
      `仅溅失 ${small.brine.losses.spilledWaterMl} mL`);
    checkRel('溢出全程守恒',
      source.brine.totalAccounted() + small.brine.totalAccounted(), introduced, 1e-9);
  }

  // 5. 空容器与零仰角不产生任何转移
  {
    const dry = vessel('干', Glassware.beaker100());
    const to = vessel('接收', Glassware.beaker100());
    to.brine.waterMl = 5;
    dry.pose.tiltDeg = 80;
    dry.support = Support.HELD;
    const r = PourModel.step(dry, to, 1 / 60, false);
    check('空源倒不出东西', r.leftSourceMl, 0, 1e-12);
    assertTrue('空源倾倒标记为已倒空', r.sourceEmpty === true, '未标记');
    checkRel('目标内容未被改动', to.brine.waterMl, 5, 1e-12);
    dry.brine.waterMl = 10;
    dry.support = Support.TABLE;
    dry.pose.tiltDeg = 0;
    const flat = PourModel.step(dry, to, 1 / 60, false);
    check('放桌上的瓶子倒不出东西', flat.leftSourceMl, 0, 1e-12);
    assertTrue('未握持时拒绝倾倒', flat.refusedNotHeld === true, '居然倒了');
    dry.support = Support.HELD;
    const level0 = PourModel.step(dry, to, 1 / 60, false);
    check('握着但没倾斜也倒不出', level0.leftSourceMl, 0, 1e-12);
    assertTrue('倾斜不足起倒角时不算拒绝', level0.refusedNotHeld === false, '误判为未握持');

    // 没对准口部:液体整段洒在桌面上,一滴也进不去
    const misaligned = vessel('源', Glassware.beaker100());
    const catcher = vessel('接', Glassware.beaker100());
    misaligned.brine.waterMl = 20;
    misaligned.support = Support.HELD;
    misaligned.pose.tiltDeg = 80;
    misaligned.pose.x = 6;
    catcher.pose.x = 0;
    const missed = PourModel.step(misaligned, catcher, 1 / 60, true);
    assertTrue('偏离口部被判定为洒在外面', missed.missedTarget === true, '判成倒进了');
    check('洒出的液体没进目标容器', catcher.brine.waterMl, 0, 1e-12);
    checkRel('洒出的体积从源容器扣除', missed.leftSourceMl, 20 - misaligned.brine.waterMl, 1e-9);
    checkRel('洒失计入源容器损失', misaligned.brine.losses.spilledWaterMl, missed.leftSourceMl, 1e-9);
    checkRel('偏离时同样守恒', misaligned.brine.totalAccounted(), 20, 1e-9);
  }

  // 6. 量筒读数:视线是一个真实几何量,不靠推断
  const cylinder = Glassware.graduatedCylinder10();
  const targetMl = 5;
  const targetHeight = cylinder.heightForVolume(targetMl);
  checkRel('视线齐平时读数即真值',
    ReadingModel.volumeForTargetReading(cylinder, targetMl, targetHeight), targetMl, 1e-9);
  const lowEye = ReadingModel.volumeForTargetReading(cylinder, targetMl, 0);
  const highEye = ReadingModel.volumeForTargetReading(cylinder, targetMl, cylinder.totalHeight());
  assertTrue('仰视(眼在液面下)实际倒多了', lowEye > targetMl,
    `实际 ${lowEye} mL ≤ 目标 ${targetMl} mL`);
  assertTrue('俯视(眼在液面上)实际倒少了', highEye < targetMl,
    `实际 ${highEye} mL ≥ 目标 ${targetMl} mL`);
  let prevVolume = Infinity;
  for (const eye of [0, 2, 4, targetHeight, 8, 10, 12]) {
    const v = ReadingModel.volumeForTargetReading(cylinder, targetMl, eye);
    assertTrue(`实际体积随视线升高单调下降(眼=${eye})`, v <= prevVolume + 1e-9,
      `${v} > ${prevVolume}`);
    prevVolume = v;
  }
  {
    const fill = new Brine();
    fill.waterMl = 8;
    const actualHeight = cylinder.heightForVolume(8);
    checkRel('视线齐平时表观读数等于实际',
      ReadingModel.readVolume(cylinder, 8, actualHeight), 8, 1e-9);
    assertTrue('仰视使表观读数偏小',
      ReadingModel.readVolume(cylinder, 8, 0) < 8, '未偏小');
    assertTrue('俯视使表观读数偏大',
      ReadingModel.readVolume(cylinder, 8, cylinder.totalHeight()) > 8, '未偏大');
    assertTrue('偏离齐平越多误差越大',
      Math.abs(ReadingModel.readVolume(cylinder, 8, 0) - 8) >
      Math.abs(ReadingModel.readVolume(cylinder, 8, actualHeight - 1) - 8), '误差非单调');
    assertTrue('齐平判定容差内为真',
      ReadingModel.isLevelWith(actualHeight, actualHeight + 0.05, 0.1) === true, '判成不齐平');
    assertTrue('明显偏离时判为不齐平',
      ReadingModel.isLevelWith(actualHeight, 0, 0.1) === false, '判成齐平');
    // 空筒没有弯月面:眼高再高也不该凭空读出一个体积。
    // 这是 #66 的第一半 —— 重来之后量筒明明空了,读数卡还写着 1.17 mL。
    for (const eye of [0, 1, 3, cylinder.totalHeight()]) {
      checkRel(`空筒读数恒为 0(眼高 ${eye})`, ReadingModel.readVolume(cylinder, 0, eye), 0, 1e-12);
    }
    // 但"有液体时俯视读数偏大"这条不能被顺手改成"读数永不超过实际" ——
    // 那是视差模型的定义本身,不是缺陷。
    assertTrue('有液时俯视仍可读得比实际大',
      ReadingModel.readVolume(cylinder, 0.1, 3) > 0.1, '视差被改成了恒不小于实际,模型错了');
  }

  // 6c. 倾倒的终止条件与"洒出"的口径(#66 剩下的两半:61 mL 溅失 / 没对准却报 0)
  {
    const { BenchWorld } = require(join(OUT, 'bench/BenchWorld.cjs'));

    function pour(tilt, aim, guided) {
      const w = new BenchWorld();
      w.setup({ id: 'measure', title: '量取' });
      w.setParam('goal', 5);   // 目标 5 mL:量筒是 10 mL 的,不该因为"倒满"而把整瓶抽干
      w.setParam('eye', 0);
      w.setParam('tilt', tilt);
      w.setParam('aim', aim);
      w.setParam('guided', guided);
      for (let i = 0; i < 40000 && !w.ended; i++) {
        w.step(0.05);
      }
      return w;
    }

    const aligned = pour(30, 0, 0);
    const got = aligned.readObservable('actual');
    const lost = aligned.readObservable('spilled');
    const out = aligned.readObservable('poured');
    // 守恒式是这里唯一的真值定义:倒出去的 = 留下的 + 洒掉的
    checkRel('倒出量 = 实际 + 洒出(对准)', out, got + lost, 1e-9);
    // 终止条件原来是 `cylinder.isFull()`,但每一步的溅失都会把液面拉到筒口之下,
    // 于是它永远不成立 —— 学生"一直倒"会把整瓶 70 mL 抽干、报出 61 mL 溅失。
    assertTrue('漫出就该停,不该把整瓶抽干', aligned.reagentVolumeMl() > 1,
      `瓶里只剩 ${aligned.reagentVolumeMl().toFixed(2)} mL —— 终止条件没咬住`);
    const beforeMore = aligned.readObservable('actual');
    for (let i = 0; i < 2000; i++) {
      aligned.step(0.05);
    }
    checkRel('结束后液面不再增长', aligned.readObservable('actual'), beforeMore, 1e-12);
    assertTrue('量筒里的水不超过筒的容量', got <= 10.0001, `实际 ${got.toFixed(4)} mL`);
    assertTrue('洒出只是溅失,不是整瓶', lost < 5, `洒出 ${lost.toFixed(2)} mL`);

    const missed = pour(30, 6, 0);
    const mGot = missed.readObservable('actual');
    const mLost = missed.readObservable('spilled');
    const mOut = missed.readObservable('poured');
    checkRel('倒出量 = 实际 + 洒出(没对准)', mOut, mGot + mLost, 1e-9);
    // 原来这里读的是量筒自己的损失账本,而没对准的水是从试剂瓶直接扣掉的 ——
    // 于是屏幕上"洒失 0.00 mL"和"实际 0.00 mL"同时成立,而 71 mL 真的倒空了
    assertTrue('没对准时洒出必须计得出来', mLost > 1 && mGot < 0.01,
      `洒出 ${mLost.toFixed(2)} mL、实际 ${mGot.toFixed(2)} mL、倒出 ${mOut.toFixed(2)} mL`);

    const guided = pour(30, 0, 1);
    assertTrue('引流确实减少洒出', guided.readObservable('spilled') <= lost + 1e-9,
      `引流 ${guided.readObservable('spilled').toFixed(2)} > 不引流 ${lost.toFixed(2)}`);

    // 负对照:如果 spilled 被写死成 0,上面两条守恒会立刻红
    assertTrue('负对照:洒出不是恒零', mLost > 0, '没对准的洒出仍被报成 0,说明口径没改对');
  }

  // 6b. 量取判词的自洽性:一句话里不能同时说"正好"和"倒多了"(F5)
  {
    const { MeasureVerdict } = require(join(OUT, 'bench/MeasureVerdict.cjs'));

    const level = MeasureVerdict.of(10, 10, 0, 0, 0);
    assertTrue('齐平且正好:说正好', level.includes('正好到目标量'), level);
    assertTrue('齐平且正好:说读数可信', level.includes('读数可信'), level);

    // 仰视但恰好停在真实值上 —— 视线偏差只决定"读数偏哪边",不决定"倒多倒少"
    const offsetButExact = MeasureVerdict.of(10, 10, 0, -2, 0);
    assertTrue('判词不自相矛盾:说正好时不得同时说倒多了/倒少了',
      !(offsetButExact.includes('正好到目标量') &&
        (offsetButExact.includes('倒多了') || offsetButExact.includes('倒少了'))), offsetButExact);
    assertTrue('仰视仍然要教读数偏小', offsetButExact.includes('读数偏小'), offsetButExact);

    const reallyOver = MeasureVerdict.of(11.2, 10, 1.2, -2, 0);
    assertTrue('负对照:真多倒时确实说多倒了 1.20 mL', reallyOver.includes('多倒了 1.20 mL'), reallyOver);
    assertTrue('因果链闭合时才补一句', reallyOver.includes('这就是多倒的原因'), reallyOver);

    const reallyUnder = MeasureVerdict.of(8.6, 10, -1.4, 2, 0);
    assertTrue('俯视 + 少倒:说少倒了 1.40 mL', reallyUnder.includes('少倒了 1.40 mL'), reallyUnder);
    assertTrue('俯视:读数偏大', reallyUnder.includes('读数偏大'), reallyUnder);

    const splash = MeasureVerdict.of(9.4, 9.4, -0.6, 0, 0.35);
    assertTrue('溅失单独成句', splash.includes('另有 0.35 mL 溅失'), splash);
    assertTrue('齐平时不硬套视差因果', !splash.includes('这就是'), splash);

    // 数字必须和屏幕上读数卡一致:实际、读数两个数都要出现在句子里
    assertTrue('判词带出实际与读数', reallyOver.includes('实际 11.20 mL') && reallyOver.includes('读数 10.00 mL'), reallyOver);
  }

  // 7. 确定性重放:倾倒脚本跑两遍结果必须逐位相同
  {
    function replay() {
      const source = vessel('源', Glassware.beaker100());
      const target = vessel('接收', Glassware.beaker100());
      source.pose.tiltDeg = 55;
      source.support = Support.HELD;
      Separations.addWater(source.brine, 60);
      Separations.addCrudeSalt(source.brine, 10, 2);
      for (let i = 0; i < 200; i++) {
        Separations.dissolve(source.brine, 0.2, true);
        Separations.stirSand(source.brine, 0.2, true);
      }
      drainAll(source, target, false);
      for (let i = 0; i < 800; i++) {
        Separations.evaporate(target.brine, 0.1, target.surfaceArea(), i % 2 === 0);
      }
      const b = target.brine;
      return `${b.waterMl}|${b.saltDissolvedG}|${b.saltSolidG}|${b.sandSuspendedG}` +
        `|${b.sandSettledG}|${b.losses.evaporatedWaterMl}|${b.losses.spilledSaltG}`;
    }
    checkText('倾倒+蒸发脚本两次重放完全一致', replay(), replay());
  }
}

// ---- M4-lite 端到端:学生「看读数收手」这条链 -----------------------------
{
  const { BenchWorld } = require(join(OUT, 'bench/BenchWorld.cjs'));
  const { ExperimentMeta } = require(join(OUT, 'model/ExperimentTypes.cjs'));
  const GOAL = 8;

  /**
   * 模拟一个真实学生:盯着量筒倒水,直到他**看到**的读数到达目标就收手。
   * 视线高度是他自己设定的几何量,系统不去猜他仰视还是俯视 —— 直接按视差给出他会看到什么。
   */
  function drill(eyeHeight, guided) {
    const world = new BenchWorld();
    const meta = new ExperimentMeta();
    const controller = new RunController();
    world.setup(meta);
    controller.bind(world, meta);
    world.setParam('tilt', 55);
    world.setParam('goal', GOAL);
    world.setParam('eye', eyeHeight);
    world.setParam('guided', guided ? 1 : 0);
    controller.start();
    let guard = 0;
    while (!world.finished() && world.readObservable('apparent') < GOAL && guard < 40000) {
      controller.advance(1 / 60);
      guard++;
    }
    world.stop();
    return {
      actual: world.readObservable('actual'),
      apparent: world.readObservable('apparent'),
      poured: world.readObservable('poured'),
      spilled: world.readObservable('spilled'),
      error: world.readObservable('error'),
      world,
      controller
    };
  }

  // 量筒满量程 10 mL / 高 15 cm,8 mL 对应 12 cm
  const level = drill(12, true);
  // 眼位取 6 cm 而非 0:极端仰视下学生要到读数 8 得倒进 10 mL 以上,量筒先满,
  // 那是「超过量程」另一个考点,不该混在这条断言里
  const lowEye = drill(6, true);
  const highEye = drill(15, true);

  checkRel('视线齐平时量取到目标体积', level.actual, GOAL, 0.03);
  assertTrue('仰视导致实际倒多', lowEye.actual > GOAL + 0.2,
    `实际 ${lowEye.actual} mL,目标 ${GOAL} mL`);
  assertTrue('俯视导致实际倒少', highEye.actual < GOAL - 0.2,
    `实际 ${highEye.actual} mL,目标 ${GOAL} mL`);
  assertTrue('三种视线下学生看到的读数都到达目标(他自己没错,错在操作)',
    [level, lowEye, highEye].every((d) => d.apparent >= GOAL - 0.05),
    JSON.stringify([level.apparent, lowEye.apparent, highEye.apparent]));
  checkRel('仰视误差为正', lowEye.error, lowEye.actual - GOAL, 1e-9);

  for (const d of [level, lowEye, highEye]) {
    checkRel('倒出的 = 量筒里的 + 溅掉的', d.poured, d.actual + d.spilled, 1e-9);
  }

  // 收手后世界必须冻结,读数不再变化
  const before = level.world.readObservable('actual');
  for (let i = 0; i < 200; i++) {
    level.controller.advance(1 / 60);
  }
  checkRel('stop() 后世界冻结', level.world.readObservable('actual'), before, 1e-12);
  assertTrue('stop() 后控制器自动停表', level.controller.running === false, '仍在推进');

  // 不引流必须比引流溅得多 —— 同一视线、同一仰角,唯一差别是有没有玻璃棒
  const rough = drill(12, false);
  assertTrue('不引流溅失明显更大', rough.spilled > level.spilled * 5,
    `不引流 ${rough.spilled} mL vs 引流 ${level.spilled} mL`);

  // 经 RunController 重放必须逐位一致(评分可复算的前提)
  function replaySignature() {
    const d = drill(9, true);
    return `${d.actual.toFixed(9)}|${d.apparent.toFixed(9)}|${d.poured.toFixed(9)}|${d.spilled.toFixed(9)}`;
  }
  checkText('端到端重放完全一致', replaySignature(), replaySignature());
}

// ---- M2 空间关系与溢流几何推导 --------------------------------------------
{
  const { Footprint, Spatial, Support } = require(join(OUT, 'bench/Pose.cjs'));
  const { Calibration } = require(join(OUT, 'bench/Brine.cjs'));
  const { Glassware } = require(join(OUT, 'geometry/Profile.cjs'));
  const { Container } = require(join(OUT, 'bench/Container.cjs'));
  const tol = Calibration.CONTACT_TOLERANCE_CM;

  const a = Footprint.of(0, 0, 2.2);
  const touching = Footprint.of(4.4, 0, 2.2);
  checkRel('边缘相切时间距为 0', Spatial.edgeGap(a, touching), 0, 1e-9);
  assertTrue('边缘相切判为紧靠', Spatial.isTouching(a, touching, tol), '未判为紧靠');
  assertTrue('容差内轻微重叠仍算紧靠',
    Spatial.isTouching(a, Footprint.of(4.3, 0, 2.2), tol), '未判为紧靠');
  assertTrue('隔 1 cm 不算紧靠',
    !Spatial.isTouching(a, Footprint.of(5.4, 0, 2.2), tol), '误判为紧靠');

  // 「对准口部」必须不对称:大口往小口里倒,比小口往大口里倒难得多
  const smallIntoBig = Spatial.isAlignedAbove(Footprint.of(1.5, 5, 0.46), Footprint.of(0, 0, 2.22), tol);
  const bigIntoSmall = Spatial.isAlignedAbove(Footprint.of(0.5, 5, 2.22), Footprint.of(0, 0, 0.46), tol);
  assertTrue('小口容器可偏 1.5 cm 仍算对准', smallIntoBig, '误判为没对准');
  assertTrue('大口往小口倒偏 0.5 cm 即算没对准', !bigIntoSmall, '误判为对准了');
  assertTrue('完全同心时一定对准',
    Spatial.isAlignedAbove(Footprint.of(0, 5, 2.22), Footprint.of(0, 0, 0.46), tol), '判成没对准');
  assertTrue('高度关系可判定(悬空 vs 贴桌)',
    Spatial.isElevated(Footprint.of(0, 5, 1), Footprint.of(0, 0, 1), 2), '未判为悬空');
  checkText('支撑状态三种取值互不相同',
    `${Support.HELD}|${Support.TABLE}|${Support.CLAMPED}`, 'held|table|clamped');
  checkText('烧杯口部半宽由截面积反算',
    Container.of('b', 'b', Glassware.beaker100()).rimHalfWidth() > 2 ? 'wide' : 'narrow', 'wide');

  // 溢流必须由几何产生:倒太猛 → 液位涨过滤纸边缘 → 那部分体积不经过滤纸
  const { BrineScenario, BrineScenarioRunner } = require(join(OUT, 'bench/BrineScenario.cjs'));
  function scenarioRun(over) {
    const s = new BrineScenario();
    for (const k of Object.keys(over)) {
      s[k] = over[k];
    }
    return BrineScenarioRunner.run(s);
  }
  const gentle = scenarioRun({ pourTiltDeg: 30 });
  const violent = scenarioRun({ pourTiltDeg: 85 });

  check('慢倒不产生旁通', gentle.facts.num('bypassedMl'), 0, 1e-9);
  check('慢倒时滤液绝对澄清', gentle.facts.num('filtrateTurbidity'), 0, 1e-12);
  check('慢倒液面从未高过滤纸', gentle.facts.num('paperOverRimCm'), 0, 1e-9);
  assertTrue('猛倒产生旁通', violent.facts.num('bypassedMl') > 0.5,
    `仅 ${violent.facts.num('bypassedMl')} mL`);
  assertTrue('猛倒液面涨过滤纸边缘', violent.facts.num('paperOverRimCm') > 0,
    `${violent.facts.num('paperOverRimCm')} cm`);
  assertTrue('旁通使滤液变浑浊', violent.facts.num('filtrateTurbidity') > 0,
    '浊度仍为 0,说明旁通没带走泥沙');
  assertTrue('倾角越大旁通越多(单调)',
    violent.facts.num('bypassedMl') > gentle.facts.num('bypassedMl'), '非单调');
  // 因果链必须完整:漫过 → 旁通 → 浑浊,三者同起同落
  checkText('未漫过就不该有旁通', gentle.facts.num('paperOverRimCm') > 0 ? 'over' : 'fine', 'fine');
}

// ---- M3 细则自检与评分剧本 ------------------------------------------------
{
  const { RubricValidator, Rubric, CriterionBuilder, CriterionOp } = require(join(OUT, 'bench/Rubric.cjs'));
  const { Judgment } = require(join(OUT, 'bench/Judgment.cjs'));
  const { RubricBrine } = require(join(OUT, 'bench/RubricBrine.cjs'));
  const { BrineScenario, BrineScenarioRunner } = require(join(OUT, 'bench/BrineScenario.cjs'));

  function scenarioRun(over) {
    const s = new BrineScenario();
    for (const k of Object.keys(over)) {
      s[k] = over[k];
    }
    return BrineScenarioRunner.run(s);
  }
  function fired(run) {
    return Judgment.score(RubricBrine.create(), run.facts).deductions.map((d) => d.criterionId).sort();
  }

  // 细则自检
  const good = RubricBrine.create();
  check('参考细则通过自检', RubricValidator.validate(good).length, 0, 0);
  check('参考细则分值合计等于满分',
    good.criteria.reduce((acc, c) => acc + c.points, 0), good.totalPoints, 1e-9);
  assertTrue('判据来源被显式标为非官方', good.source.includes('非官方'), good.source);

  function tamper(mutate) {
    const r = RubricBrine.create();
    mutate(r);
    return RubricValidator.validate(r).length > 0;
  }
  assertTrue('分值不守恒被拒绝', tamper((r) => { r.criteria[0].points += 5; }), '居然通过');
  assertTrue('来源留空被拒绝', tamper((r) => { r.source = ''; }), '居然通过');
  assertTrue('无版本号被拒绝', tamper((r) => { r.version = ''; }), '居然通过');
  assertTrue('判据 id 重复被拒绝',
    tamper((r) => { r.criteria[1].id = r.criteria[0].id; }), '居然通过');
  assertTrue('缺证据模板被拒绝', tamper((r) => { r.criteria[0].evidence = ''; }), '居然通过');
  assertTrue('区间上下限颠倒被拒绝',
    tamper((r) => { r.criteria[5].threshold2 = r.criteria[5].threshold - 1; }), '居然通过');
  assertTrue('时序判据缺后继事件被拒绝',
    tamper((r) => { r.criteria[6].metric2 = ''; }), '居然通过');
  assertTrue('判据为空的细则被拒绝',
    RubricValidator.validate((() => { const r = new Rubric(); r.id = 'x'; r.label = 'x';
      r.source = 's'; r.version = 'v'; return r; })()).length > 0, '居然通过');

  // 合法细则在判定前必须再自检一次,不合法就抛错而不是偷偷给个分
  {
    const broken = RubricBrine.create();
    broken.totalPoints = 90;
    let threw = false;
    try {
      Judgment.score(broken, scenarioRun({}).facts);
    } catch (e) {
      threw = true;
    }
    assertTrue('不合法细则在判定时抛错', threw, '返回了分数');
  }

  // 评分剧本:每条都跑真世界,事实不是手写的
  const S01 = scenarioRun({});
  const card01 = Judgment.score(good, S01.facts);
  checkText('S01 规范操作的事实集', fired(S01).join(','), '');
  check('S01 规范操作得满分', card01.awarded, 100, 1e-9);
  checkRel('S01 产率在合理区间', card01.facts.num('yieldPct'), 100, 0.2);
  assertTrue('S01 报告带判据来源', card01.summaryLine().includes('非官方'), card01.summaryLine());
  // 整行钉死:原来是「100.0 / 100 分(判据：参考细则(非官方标准) 2026.09-draft1)」,
  // 括号套括号 + 整数印小数 + 内部代号,三处工程味都在这一行
  checkText('判分汇总行的完整措辞', card01.summaryLine(),
    '得分 100 / 100 · 评分依据：参考细则（非官方标准） · 版本 2026.09 第1版');

  const S02 = scenarioRun({ rodUsed: false });
  const s02fired = fired(S02);
  assertTrue('S02 未用玻璃棒引流命中 B01', s02fired.includes('B01'), s02fired.join(','));
  // 洒落判据必须与洒落量严格对应 —— 不硬写预期,由事实自己决定
  const s02Spill = S02.facts.num('spilledMl');
  checkText('S02 洒落判据与洒落量一致',
    s02fired.includes('B05') === (s02Spill > 1.0) ? 'consistent' : 'inconsistent', 'consistent');
  check('S02 足量水使盐全部溶解(容差取浮点残差级)',
    S02.facts.num('undissolvedAtFilterG'), 0, 1e-9);
  assertTrue('S02 产率因溅失而下降', S02.facts.num('yieldPct') < S01.facts.num('yieldPct'),
    `${S02.facts.num('yieldPct')}% ≥ ${S01.facts.num('yieldPct')}%`);

  const S03 = scenarioRun({ pourTiltDeg: 85 });
  const s03fired = fired(S03);
  assertTrue('S03 倒太猛触发「液面高过滤纸边缘」', s03fired.includes('B02'), s03fired.join(','));
  assertTrue('S03 同时触发「滤液不合格澄清」', s03fired.includes('B03'), s03fired.join(','));
  assertTrue('S03 扣分理由可复算', S03.facts.num('bypassedMl') > 0, '旁通体积为 0');

  const S04 = scenarioRun({ evapStirred: false });
  checkText('S04 蒸发未搅拌', fired(S04).join(','), 'B04');
  assertTrue('S04 确实溅失了盐', S04.facts.num('splashSaltG') > 0.001,
    `${S04.facts.num('splashSaltG')} g`);

  const S05 = scenarioRun({ aimOffsetCm: 6 });
  const s05fired = fired(S05);
  assertTrue('S05 没对准口部触发洒落判据',
    s05fired.includes('B05') || s05fired.includes('B06'), s05fired.join(','));
  assertTrue('S05 因洒失导致产率下降', S05.facts.num('yieldPct') < 100,
    `${S05.facts.num('yieldPct')}%`);

  // S07:粉末取用送不到底。不新增判据 —— 沾壁的盐不溶解,产率自己掉下来
  const S07 = scenarioRun({ powderTiltDeg: 90, powderReachCm: 0 });
  const s07fired = fired(S07);
  assertTrue('S07 有盐沾在壁上', S07.facts.num('powderStuckSaltG') > 0.5,
    `${S07.facts.num('powderStuckSaltG')} g`);
  assertTrue('S07 产率因沾壁下降', S07.facts.num('yieldPct') < S01.facts.num('yieldPct'),
    `${S07.facts.num('yieldPct')}% ≥ ${S01.facts.num('yieldPct')}%`);
  checkText('S07 只由既有的产率判据命中', s07fired.join(','), 'B06');
  // 沾住的盐不可能被回收,所以产率损失至少等于沾壁占比(还会更多,因为另有少量溅失)
  assertTrue('S07 产率损失不小于沾壁占比',
    (100 - S07.facts.num('yieldPct')) / 100
      >= S07.facts.num('powderStuckSaltG') / S07.facts.num('saltAddedG') - 1e-9,
    `产率掉 ${(100 - S07.facts.num('yieldPct')).toFixed(2)}%,沾壁 ${S07.facts.num('powderStuckSaltG').toFixed(2)} / ${S07.facts.num('saltAddedG')} g`);

  // 证据文本必须真的带数字,不能只剩模板
  {
    const withEvidence = Judgment.score(good, S03.facts);
    const sample = withEvidence.deductions[0].evidence;
    assertTrue('证据里有具体数值', /\d/.test(sample), sample);
    assertTrue('证据不残留未替换占位符', !sample.includes('{'), sample);
    assertTrue('证据说明了后果', sample.includes('未经滤纸') || sample.includes('浊度'), sample);
  }

  // 不变量 I4:换细则只改分数,不改世界事实
  {
    const before = JSON.stringify(S03.facts.numbers);
    const stricter = RubricBrine.create();
    for (const c of stricter.criteria) {
      if (c.metric === 'filtrateTurbidity') {
        c.threshold = 0.0001;
      }
    }
    const lenient = RubricBrine.create();
    for (const c of lenient.criteria) {
      if (c.metric === 'filtrateTurbidity') {
        c.threshold = 1e9;
      }
    }
    const strictScore = Judgment.score(stricter, S03.facts).awarded;
    const lenientScore = Judgment.score(lenient, S03.facts).awarded;
    assertTrue('收紧阈值会扣分更多', strictScore < lenientScore,
      `${strictScore} ≥ ${lenientScore}`);
    checkText('换细则不改动任何事实', JSON.stringify(S03.facts.numbers), before);
    check('同一事实集重放分数一致',
      Judgment.score(good, S03.facts).awarded, Judgment.score(good, S03.facts).awarded, 1e-12);
  }
}

// ---- 实验库列表装配 --------------------------------------------------------
// 这一节守的是排版缺陷:chip 由数据推导,空学科不上屏,宽度用算式而不是等真机截图。
{
  const { LibraryFeed, FeedItem } = require(join(OUT, 'common/LibraryFeed.cjs'));
  const { ExperimentMeta, Subject } = require(join(OUT, 'model/ExperimentTypes.cjs'));

  const SUBJECTS = [Subject.PHYSICS_MECHANICS, Subject.PHYSICS_ELECTRICAL, Subject.CHEMISTRY,
    Subject.BIOLOGY, Subject.GEOGRAPHY, Subject.MATH_VISUAL, Subject.INSTRUMENT];

  for (const s of SUBJECTS) {
    const label = LibraryFeed.shortLabel(s);
    check(`短标签「${label}」必须是双字`, label.length, 2, 1e-12);
  }
  checkText('力学短标签', LibraryFeed.shortLabel(Subject.PHYSICS_MECHANICS), '力学');
  checkText('电学短标签', LibraryFeed.shortLabel(Subject.PHYSICS_ELECTRICAL), '电学');
  checkText('化学短标签', LibraryFeed.shortLabel(Subject.CHEMISTRY), '化学');
  checkText('生物短标签', LibraryFeed.shortLabel(Subject.BIOLOGY), '生物');
  checkText('地理短标签', LibraryFeed.shortLabel(Subject.GEOGRAPHY), '地理');
  checkText('数学短标签', LibraryFeed.shortLabel(Subject.MATH_VISUAL), '数学');
  checkText('仪器短标签', LibraryFeed.shortLabel(Subject.INSTRUMENT), '仪器');

  checkText('力学全称', LibraryFeed.fullLabel(Subject.PHYSICS_MECHANICS), '物理 · 力学');
  checkText('电学全称', LibraryFeed.fullLabel(Subject.PHYSICS_ELECTRICAL), '物理 · 电学');
  checkText('化学全称', LibraryFeed.fullLabel(Subject.CHEMISTRY), '化学');
  checkText('仪器全称', LibraryFeed.fullLabel(Subject.INSTRUMENT), '仪器实操');

  const meta = new ExperimentMeta();
  meta.id = 'demo-x';
  meta.title = '演示实验';
  meta.subject = Subject.CHEMISTRY;
  meta.gradeBand = '初中化学 · 九年级';
  meta.durationMinutes = 15;
  meta.summary = '一段简介';
  const mapped = LibraryFeed.fromMeta(meta);
  checkText('fromMeta 用 id 作列表 key', mapped.key, 'demo-x');
  checkText('fromMeta 用 id 定位 runner', mapped.experimentId, 'demo-x');
  checkText('fromMeta 默认路由是实验页', mapped.route, 'experiment');
  checkText('fromMeta 带出标题', mapped.title, '演示实验');
  checkText('fromMeta 带出简介', mapped.summary, '一段简介');
  checkText('fromMeta 带出学段', mapped.gradeBand, '初中化学 · 九年级');
  check('fromMeta 带出时长', mapped.durationMinutes, 15, 1e-12);

  function feed(key, subject) {
    const f = new FeedItem();
    f.key = key;
    f.title = key;
    f.subject = subject;
    f.route = 'experiment';
    return f;
  }

  const registryItems = [feed('m1', Subject.PHYSICS_MECHANICS), feed('e1', Subject.PHYSICS_ELECTRICAL),
    feed('c1', Subject.CHEMISTRY)];

  const practice = LibraryFeed.practiceItems();
  check('实操项有两条', practice.length, 2, 1e-12);
  for (const p of practice) {
    assertTrue(`实操项「${p.title}」不走实验页`, p.route !== 'experiment', 'route 仍是 experiment');
    checkText(`实操项「${p.title}」不占注册表 id`, p.experimentId, '');
    check(`实操项「${p.title}」的学科短标签是双字`, LibraryFeed.shortLabel(p.subject).length, 2, 1e-12);
  }
  check('实操项 key 互不相同', new Set(practice.map((p) => p.key)).size, practice.length, 1e-12);

  const today = practice.concat(registryItems);
  const chips = LibraryFeed.chips(today);
  checkText('筛选条首项恒为全部', chips[0].label, '全部');
  assertTrue('「全部」不绑定任何学科', chips[0].subject === null, `实得 ${chips[0].subject}`);
  const labels = chips.map((c) => c.label).join('/');
  checkText('只有有内容的学科上屏', labels, '全部/力学/电学/化学/仪器');
  checkText('chip 顺序按学科声明序稳定', chips.slice(1).map((c) => c.label).join('/'), '力学/电学/化学/仪器');
  assertTrue('当前数据在手机上一行放得下', LibraryFeed.fitsOnPhone(chips) === true,
    `宽度 ${LibraryFeed.chipRowWidth(chips)} > ${LibraryFeed.PHONE_CONTENT_WIDTH}`);
  assertTrue('没有实验的学科不占位', !labels.includes('生物') && !labels.includes('地理'), labels);

  check('选「全部」返回所有条目', LibraryFeed.select(today, chips[0]).length, today.length, 1e-12);
  const chemChip = chips.find((c) => c.label === '化学');
  check('按化学筛选只剩化学', LibraryFeed.select(today, chemChip).length, 2, 1e-12);
  checkText('筛选命中的第一条是化学实验台', LibraryFeed.select(today, chemChip)[0].key, 'practice-bench');
  assertTrue('筛选不发明条目', LibraryFeed.select(today, chemChip).length <= today.length, '结果比输入还多');

  const emptyChips = LibraryFeed.chips([]);
  check('空列表只剩「全部」一枚 chip', emptyChips.length, 1, 1e-12);
  check('空列表筛选返回空', LibraryFeed.select([], emptyChips[0]).length, 0, 1e-12);

  const allSeven = SUBJECTS.map((s, i) => feed(`s${i}`, s));
  assertTrue('七科齐备时一行放不下,护栏会先红',
    LibraryFeed.fitsOnPhone(LibraryFeed.chips(allSeven)) === false, '宽度算式失效,护栏形同虚设');
}

// ---- 设计令牌:接线与阶梯 ---------------------------------------------------
// 这一节把「别写魔法数」「颜色只能来自资源」从口头要求变成会红的断言。
{
  const { Contrast } = require(join(OUT, 'common/Contrast.cjs'));
  const { Theme } = require(join(OUT, 'common/Theme.cjs'));
  const { Layout, DeviceClass } = require(join(OUT, 'common/Layout.cjs'));
  const { Subject } = require(join(OUT, 'model/ExperimentTypes.cjs'));

  const CLASSES = [DeviceClass.PHONE, DeviceClass.PAD, DeviceClass.LARGE];

  // Contrast 自身的定义必须对,否则整套 AA 判定都是空的
  check('纯黑对白对比度为 21', Contrast.ratio('#000000', '#FFFFFF'), 21, 0.01);
  check('同色对比度为 1', Contrast.ratio('#2F6FB5', '#2F6FB5'), 1, 1e-9);
  check('对比度与前后顺序无关', Contrast.ratio('#FFFFFF', '#2F6FB5'), Contrast.ratio('#2F6FB5', '#FFFFFF'), 1e-9);
  check('三位缩写与六位全写等价', Contrast.ratio('#fff', '#000'), Contrast.ratio('#FFFFFF', '#000000'), 1e-9);
  assertTrue('非法色值返回 NaN 而不是猜一个', Number.isNaN(Contrast.ratio('transparent', '#FFFFFF')),
    '居然给了个数,调用方会被误导');
  check('白色相对亮度为 1', Contrast.luminance('#FFFFFF'), 1, 1e-9);
  check('黑色相对亮度为 0', Contrast.luminance('#000000'), 0, 1e-9);
  check('中灰亮度按 sRGB 解码', Contrast.luminance('#808080'), 0.2159, 0.001);

  // 配色断言已搬到「调色板资源」一节按浅色/深色两套分别判;这里只留接线与阶梯。

  // 接线:令牌名 ↔ 资源名必须一一对应。名字打错一个字母不会编译报错,只会运行时变黑块,
  // 而规则本身就写死了 —— 大写令牌名转小写就是资源名。
  const tokens = Object.keys(Theme).filter((k) => /^[A-Z][A-Z0-9_]*$/.test(k));
  const wiringProblems = (entries) => entries
    .filter(([k, name]) => name !== `app.color.${k.toLowerCase()}`)
    .map(([k, name]) => `${k}→${name}`);
  const wired = tokens.map((k) => [k, resourceNameOf(Theme[k])]);
  assertTrue('Theme 至少列出 20 个色令牌', tokens.length >= 20, `只有 ${tokens.length} 个`);
  assertTrue('每个令牌指向同名资源', wiringProblems(wired).length === 0, wiringProblems(wired).join(','));
  const wrongWiring = wired.slice();
  wrongWiring[0] = [wrongWiring[0][0], 'app.color.text_primaryy'];
  check('负对照:名字多打一个字母就报接线错', wiringProblems(wrongWiring).length, 1, 1e-12);
  check('令牌两两不指向同一个色', new Set(tokens.map((k) => Theme[k].id)).size, tokens.length, 1e-12);
  const hexInTheme = readFileSync(join(SRC, 'common/Theme.ets'), 'utf8').match(/'#[0-9A-Fa-f]{3,8}'/g) || [];
  assertTrue('Theme 里不留裸 hex 字面量(色值只能来自资源)', hexInTheme.length === 0, hexInTheme.join(','));

  // 组件层的 Color.White / Color.Black 是"主题盲"的:浅色档对、深色档就糊(实测按钮白字压
  // 亮蓝底只剩 2.6:1)。品牌底上的字要用 Theme.ON_BRAND,那是一对按模式设计的值。
  // 只有画在"实验纸面"上的色才允许写死 —— 纸面两套模式都是浅底,必须在文件里注明理由。
  const blindInk = [];
  const scanBlindInk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) {
        scanBlindInk(full);
      } else if (entry.name.endsWith('.ets')) {
        const src = readFileSync(full, 'utf8');
        if (src.includes('纸面内色')) {
          continue;
        }
        for (const line of src.split('\n')) {
          // 注释里提到这个写法不算(那正是我们在教后来人别这么写)
          if (line.includes('//')) {
            continue;
          }
          for (const m of line.matchAll(/Color\.(White|Black)/g)) {
            blindInk.push(`${entry.name}:${m[0]}`);
          }
        }
      }
    }
  };
  for (const sub of ['pages', 'view', 'view3d', 'common']) {
    scanBlindInk(join(SRC, sub));
  }
  assertTrue('组件层不写死 Color.White/Black(用 Theme.ON_BRAND)',
    blindInk.length === 0, blindInk.join(','));
  // 负对照:护栏得真的能认出未注明的写法
  const blindSample = 'Text(x).fontColor(Color.White)';
  check('负对照:裸 Color.White 会被这条规则认出', (blindSample.match(/Color\.(White|Black)/g) || []).length, 1, 1e-12);

  // 每个 NavDestination 页都要自己刷页面底色:漏了的那页在深色档会露出系统的纯黑底,
  // 和其他页的 bg_page 差一档(实测课程地图就是这样)。
  const barePages = [];
  let pagesWithNav = 0;
  for (const entry of readdirSync(join(SRC, 'pages'), { withFileTypes: true })) {
    if (!entry.name.endsWith('.ets')) {
      continue;
    }
    const src = readFileSync(join(SRC, 'pages', entry.name), 'utf8');
    if (src.includes('NavDestination()')) {
      pagesWithNav++;
    }
    if (src.includes('NavDestination()') && !src.includes('backgroundColor(Theme.BG_PAGE)')) {
      barePages.push(entry.name);
    }
  }
  // 先证明扫描真的覆盖了子页:0 个文件时上面那条会假绿
  assertTrue('扫描到了 5 个以上以 NavDestination 为根的子页', pagesWithNav >= 5, `只扫到 ${pagesWithNav} 个`);
  assertTrue('每个子页都刷了页面底色', barePages.length === 0, barePages.join(','));
  check('负对照:漏刷底色的页会被认出',
    ('NavDestination() { x }'.includes('NavDestination()') && !'NavDestination() { x }'.includes('backgroundColor(Theme.BG_PAGE)')) ? 1 : 0,
    1, 1e-12);

  // subjectColor 是一条 if 链,学科顺序被打乱时颜色会整体错位一格
  const SUBJECTS_ORDERED = [Subject.PHYSICS_MECHANICS, Subject.PHYSICS_ELECTRICAL, Subject.CHEMISTRY,
    Subject.BIOLOGY, Subject.GEOGRAPHY, Subject.MATH_VISUAL, Subject.INSTRUMENT]
    .map((s) => resourceNameOf(Theme.subjectColor(s)));
  const SUBJECT_EXPECT = ['app.color.subject_mechanics', 'app.color.subject_electrical',
    'app.color.subject_chemistry', 'app.color.subject_biology', 'app.color.subject_geography',
    'app.color.subject_math', 'app.color.subject_instrument'];
  for (let i = 0; i < SUBJECT_EXPECT.length; i++) {
    checkText(`subjectColor 第 ${i} 个学科`, SUBJECTS_ORDERED[i], SUBJECT_EXPECT[i]);
  }

  function assertAscending(label, ladder) {
    let sorted = ladder.length > 0;
    for (let i = 1; i < ladder.length; i++) {
      if (!(ladder[i] > ladder[i - 1])) {
        sorted = false;
      }
    }
    assertTrue(`${label} 严格升序`, sorted, ladder.join(','));
  }
  assertAscending('间距阶梯', Layout.SPACE);
  assertAscending('圆角阶梯', Layout.RADII);
  assertAscending('动效时长阶梯', Layout.MOTION_MS);
  check('间距阶梯以 4 起步(4pt 微调档)', Layout.SPACE[0], 4, 1e-12);
  check('动效阶梯含瞬时 0', Layout.MOTION_MS[0], 0, 1e-12);

  function assertNonDecreasing(label, values) {
    let ok = true;
    for (let i = 1; i < values.length; i++) {
      if (!(values[i] >= values[i - 1])) {
        ok = false;
      }
    }
    assertTrue(`${label} 随档位非递减`, ok, values.join(','));
  }

  const insets = CLASSES.map((c) => Layout.pageInset(c));
  const paddings = CLASSES.map((c) => Layout.cardPadding(c));
  const gaps = CLASSES.map((c) => Layout.listGap(c));
  const captions = CLASSES.map((c) => Layout.captionSize(c));
  assertNonDecreasing('页边距', insets);
  assertNonDecreasing('卡片内边距', paddings);
  assertNonDecreasing('列表间距', gaps);
  assertNonDecreasing('说明字号', captions);
  check('手机页边距 16', insets[0], 16, 1e-12);
  check('平板页边距 24', insets[1], 24, 1e-12);
  check('大屏页边距 32', insets[2], 32, 1e-12);

  // 间距型令牌必须落在阶梯上,否则就是又一个魔法数
  for (const v of insets.concat(paddings).concat(gaps)) {
    assertTrue(`间距 ${v} 在阶梯上`, Layout.onLadder(v) === true, `${v} 不在 ${Layout.SPACE.join(',')}`);
  }

  // 字号层级不得倒挂。允许并列(如 phone 上 body 与 section 同为 15),不允许反超
  const FONT_ORDER = ['microSize', 'captionSize', 'labelSize', 'bodySize', 'sectionSize',
    'cardTitleSize', 'pageTitleSize', 'readoutSize', 'displaySize'];
  for (let i = 0; i < CLASSES.length; i++) {
    const ladder = FONT_ORDER.map((r) => Layout[r](CLASSES[i]));
    for (let j = 1; j < ladder.length; j++) {
      assertTrue(`${CLASSES[i]} 字号层级 ${FONT_ORDER[j - 1]} ≤ ${FONT_ORDER[j]}`,
        ladder[j] >= ladder[j - 1], `${FONT_ORDER.join('/')} = ${ladder.join('/')}`);
    }
    assertTrue(`${CLASSES[i]} 首末两档确实分层`, ladder[0] < ladder[ladder.length - 1],
      `${ladder[0]} vs ${ladder[ladder.length - 1]}`);
  }

  // 触控下限与胶囊形状
  for (const c of CLASSES) {
    const height = Layout.chipHeight(c);
    assertTrue(`${c} chip 高度不低于触控下限`, height >= Layout.touchMin(c), `${height} < ${Layout.touchMin(c)}`);
    check(`${c} chip 圆角等于半高(胶囊)`, Layout.chipRadius(c), height / 2, 1e-9);
  }

  // 卡片圆角必须落在圆角阶梯上
  const radii = CLASSES.map((c) => Layout.cardRadius(c));
  assertNonDecreasing('卡片圆角', radii);
  for (const v of radii) {
    assertTrue(`圆角 ${v} 在圆角阶梯上`, Layout.onRadius(v) === true, `${v} 不在 ${Layout.RADII.join(',')}`);
  }
}

// ---- 操作记录账本与序列化 --------------------------------------------------
// 这一节守的是「复盘」的地基:关掉应用记录还在,而且"未评分"不会被读成"考了零分"。
{
  const { SessionLedger } = require(join(OUT, 'runner/SessionLedger.cjs'));
  const { SessionRecord, fact, moment } = require(join(OUT, 'model/SessionRecord.cjs'));
  const { Subject } = require(join(OUT, 'model/ExperimentTypes.cjs'));

  function rec(id, experimentId, endedAtMs, awarded) {
    const r = new SessionRecord();
    r.id = id;
    r.experimentId = experimentId;
    r.title = '记录 ' + id;
    r.subject = Subject.CHEMISTRY;
    r.endedAtMs = endedAtMs;
    r.durationSec = 30;
    r.rubricId = 'brine-ref';
    r.rubricVersion = '2026.09-draft1';
    r.rubricSource = '参考细则(非官方标准)';
    r.total = 100;
    r.awarded = awarded;
    r.deductionTitles = ['未用玻璃棒引流'];
    r.facts = [fact('bypassedMl', 1.2), fact('yieldPct', 88.5)];
    r.moments = [moment('filter', 4.5), moment('evaporate', 12.25)];
    return r;
  }

  const empty = new SessionLedger();
  check('新账本是空的', empty.size(), 0, 1e-12);
  assertTrue('空账本没有最高分而不是零分', Number.isNaN(empty.bestAwarded('any')), '返回了数');

  const ledger = new SessionLedger();
  assertTrue('合法记录被收下', ledger.add(rec('a', 'measure-10ml', 1000, 82)) === true, '被拒了');
  check('收下后计数加一', ledger.size(), 1, 1e-12);
  assertTrue('缺 id 的记录被拒收', ledger.add(rec('', 'x', 2000, 90)) === false, '居然收了');
  check('拒收不改变计数', ledger.size(), 1, 1e-12);

  ledger.add(rec('b', 'measure-10ml', 3000, Number.NaN));
  ledger.add(rec('c', 'series-circuit', 2000, 64));
  check('三条都进去了', ledger.size(), 3, 1e-12);
  checkText('新的排在最前', ledger.all()[0].id, 'b');
  checkText('时间戳降序排列', ledger.all().map((r) => r.id).join(','), 'b,c,a');

  const tied = new SessionLedger();
  tied.add(rec('t1', 'x', 7000, 60));
  tied.add(rec('t2', 'x', 7000, 70));
  tied.add(rec('t3', 'x', 7000, 80));
  checkText('时间戳全同时后加入的在前,排序稳定',
    tied.all().map((r) => r.id).join(','), 't3,t2,t1');

  check('按实验过滤只剩该实验', ledger.byExperiment('measure-10ml').length, 2, 1e-12);
  check('尝试次数按实验统计', ledger.attempts('measure-10ml'), 2, 1e-12);
  check('未评分的记录也算一次尝试', ledger.attempts('series-circuit'), 1, 1e-12);
  check('最高分忽略未评分记录', ledger.bestAwarded('measure-10ml'), 82, 1e-12);
  check('单条已评分记录的最高分', ledger.bestAwarded('series-circuit'), 64, 1e-12);
  const allUnscored = new SessionLedger();
  allUnscored.add(rec('u1', 'bench', 100, Number.NaN));
  assertTrue('全未评分的实验没有最高分', Number.isNaN(allUnscored.bestAwarded('bench')), '把 NaN 当 0 了');
  check('不存在的实验尝试数为 0', ledger.attempts('nope'), 0, 1e-12);

  // 上限
  const bounded = new SessionLedger();
  for (let i = 0; i < 60; i++) {
    bounded.add(rec(`r${i}`, 'measure-10ml', 1000 + i, i));
  }
  check('账本有上限', bounded.size(), SessionLedger.MAX_RECORDS, 1e-12);
  checkText('丢的是最旧那条', bounded.all()[bounded.size() - 1].id, 'r10');
  checkText('留的是最新那条', bounded.all()[0].id, 'r59');

  // 序列化往返
  const json = ledger.toJson();
  const revived = SessionLedger.fromJson(json);
  check('往返后条数不变', revived.size(), ledger.size(), 1e-12);
  checkText('往返后顺序不变', revived.all().map((r) => r.id).join(','), 'b,c,a');
  const original = ledger.all()[2];
  const back = revived.all()[2];
  checkText('往返保留 id', back.id, original.id);
  checkText('往返保留实验 id', back.experimentId, original.experimentId);
  checkText('往返保留标题', back.title, original.title);
  checkText('往返保留学科', String(back.subject), String(original.subject));
  check('往返保留结束时刻', back.endedAtMs, original.endedAtMs, 1e-12);
  check('往返保留用时', back.durationSec, original.durationSec, 1e-12);
  checkText('往返保留细则来源', back.rubricSource, original.rubricSource);
  checkText('往返保留细则版本', back.rubricVersion, original.rubricVersion);
  check('往返保留满分', back.total, original.total, 1e-12);
  check('往返保留得分', back.awarded, 82, 1e-12);
  check('往返保留扣分条数', back.deductionTitles.length, 1, 1e-12);
  checkText('往返保留扣分标题', back.deductionTitles[0], '未用玻璃棒引流');
  check('往返保留事实条数', back.facts.length, 2, 1e-12);
  check('往返保留事实值', back.facts[0].value, 1.2, 1e-12);
  // 时刻事件:报告页的「步骤时序」段全靠它,丢字段不会有任何判据失败,只能在这里钉
  check('往返保留时刻条数', back.moments.length, 2, 1e-12);
  checkText('往返保留时刻事件名', back.moments.map((m) => m.event).join(','), 'filter,evaporate');
  check('往返保留时刻秒数', back.moments.length > 1 ? back.moments[1].atSeconds : Number.NaN,
    12.25, 1e-12);
  const legacy = SessionLedger.fromJson(JSON.stringify({
    version: 1,
    records: [{ id: 'old', experimentId: 'measure-10ml', title: '老记录', subject: 'chemistry',
      endedAtMs: 500, durationSec: 8, rubricId: 'brine-ref', rubricVersion: 'v', rubricSource: 's',
      total: 100, awardedText: 'nan', deductionTitles: [], facts: [] }]
  }));
  const oldBack = legacy.all()[0];
  check('老 payload 没有 moments 字段时读成空数组', oldBack.moments.length, 0, 1e-12);
  checkText('老 payload 的其余字段照常读出', oldBack.title, '老记录');
  assertTrue('空时刻的记录仍能序列化', legacy.toJson().indexOf('"moments":[]') > 0, '没写出该字段');
  checkText('往返保留事实键', back.facts[0].key, 'bypassedMl');

  // 未评分必须是 NaN。JSON.stringify(NaN) 出 null,朴素反序列化会变成 0
  const unscored = SessionLedger.fromJson(ledger.toJson());
  assertTrue('未评分往返后仍是 NaN,不是 0', Number.isNaN(unscored.all()[0].awarded),
    `实得 ${unscored.all()[0].awarded}`);
  check('未评分的记录仍不参与最高分', unscored.bestAwarded('measure-10ml'), 82, 1e-12);

  // 脏数据不能把应用带崩
  for (const bad of ['', '   ', 'not json', 'null', '[]', '{}', '{"records":null}', '{"records":[]}']) {
    const dirty = SessionLedger.fromJson(bad);
    check(`脏输入「${bad.trim() || '空'}」返回空账本`, dirty.size(), 0, 1e-12);
  }
  const mixed = SessionLedger.fromJson('{"records":[{"id":"ok","experimentId":"e1","awarded":70},{}]}');
  check('坏记录被跳过,好记录留下', mixed.size(), 1, 1e-12);
  checkText('留下的确实是好的那条', mixed.all()[0].id, 'ok');

  // 恢复后仍可继续写,且仍受上限约束
  revived.add(rec('d', 'measure-10ml', 5000, 91));
  check('恢复的账本可以继续写', revived.size(), 4, 1e-12);
  checkText('新记录仍然排在最前', revived.all()[0].id, 'd');
  check('继续写之后最高分更新', revived.bestAwarded('measure-10ml'), 91, 1e-12);

  // ---- 删除与按日期分组 ----------------------------------------------------
  // 报告页的历史条目用 id 当 ForEach 的键,所以删除必须精确到一条:删多了一条无从找回,
  // 少删一条则会在界面上留下一个点不动的幽灵。分组的时间戳一律用本地时间构造,
  // 断言跑在什么时区都不影响结果。
  function at(base, dayOffset, hour) {
    const d = new Date(base.getFullYear(), base.getMonth(), base.getDate() + dayOffset, hour, 30, 0, 0);
    return d.getTime();
  }

  const TODAY = new Date(2026, 8, 26);
  const NOW = at(TODAY, 0, 20);

  function managementTests() {
    const del = new SessionLedger();
    del.add(rec('k1', 'measure-10ml', 1000, 82));
    del.add(rec('k2', 'measure-10ml', 2000, 74));
    del.add(rec('k3', 'series-circuit', 3000, 91));
    assertTrue('删除返回是否真的删掉了', del.remove('k2') === true, '说没删掉');
    check('删一条只剩两条', del.size(), 2, 1e-12);
    checkText('剩下的顺序不变', del.all().map((r) => r.id).join(','), 'k3,k1');
    check('删除只影响那一条的统计', del.attempts('measure-10ml'), 1, 1e-12);
    assertTrue('删掉的记录不再被读到', del.all().every((r) => r.id !== 'k2'), '还在');
    assertTrue('删不存在的 id 返回 false', del.remove('nope') === false, '居然说删掉了');
    assertTrue('空 id 返回 false', del.remove('') === false, '居然说删掉了');
    check('失败的删除不改变计数', del.size(), 2, 1e-12);
    const delJson = SessionLedger.fromJson(del.toJson());
    check('删除会随账本一起落盘', delJson.size(), 2, 1e-12);
    checkText('落盘往返后删掉的那条没回来', delJson.all().map((r) => r.id).join(','), 'k3,k1');
    del.remove('k1');
    del.remove('k3');
    check('删空之后账本是空的', del.size(), 0, 1e-12);
    check('删空之后序列化仍是合法载荷', SessionLedger.fromJson(del.toJson()).size(), 0, 1e-12);
    assertTrue('空账本上继续删除不崩', del.remove('k1') === false, '崩了或误报成功');

    // 同 id 的两条记录会让 ForEach 键冲突,也会让「删一条」变成删两条
    const dup = new SessionLedger();
    assertTrue('第一条同 id 记录被收下', dup.add(rec('same', 'x', 1000, 50)) === true, '被拒了');
    assertTrue('第二条同 id 记录被拒收', dup.add(rec('same', 'x', 2000, 60)) === false, '收了重复 id');
    check('重复 id 不会进账', dup.size(), 1, 1e-12);
    assertTrue('删一次就少一条', dup.remove('same') === true, '没删掉');
    check('删掉后账本空了', dup.size(), 0, 1e-12);

    const grouped = new SessionLedger();
    grouped.add(rec('g_today1', 'measure-10ml', at(TODAY, 0, 9), 70));
    grouped.add(rec('g_today2', 'measure-10ml', at(TODAY, 0, 15), 80));
    grouped.add(rec('g_yday', 'measure-10ml', at(TODAY, -1, 11), 66));
    grouped.add(rec('g_old', 'series-circuit', at(TODAY, -5, 8), 55));
    grouped.add(rec('g_year', 'bench', at(TODAY, -400, 8), 40));

    const days = grouped.groupByDay(NOW);
    check('跨五天分成四个组', days.length, 4, 1e-12);
    check('同一天不拆开(9 点与 15 点同组)', days[0].records.length, 2, 1e-12);
    checkText('日内仍是时间降序', days[0].records.map((r) => r.id).join(','), 'g_today2,g_today1');
    checkText('日期组按新到旧排', days.map((d) => d.key).join(' > '),
      '2026-9-26 > 2026-9-25 > 2026-9-21 > 2025-8-22');
    checkText('今天标成「今天」', days[0].label, '今天');
    checkText('昨天标成「昨天」', days[1].label, '昨天');
    checkText('今年内的更早日期用「M月D日」', days[2].label, '9月21日');
    checkText('跨年补上年份', days[3].label, '2025年8月22日');
    check('分组不丢记录', days.reduce((sum, d) => sum + d.records.length, 0), 5, 1e-12);
    check('空账本分组得到空数组', new SessionLedger().groupByDay(NOW).length, 0, 1e-12);

    // 日界的判别用例。上面那批时间全在早上 8 点之后,UTC+8 减八小时仍落在同一天,
    // 所以它们分不出「本地日界」和「UTC 日界」+ 注入 getUTCDate 变异时 1587 项照样全过。
    // 凌晨这条才是判别式的:本地算今天,UTC 算昨天。
    const edge = new SessionLedger();
    edge.add(rec('e_night', 'measure-10ml', at(TODAY, 0, 0), 60));
    edge.add(rec('e_noon', 'measure-10ml', at(TODAY, 0, 13), 70));
    const edgeDays = edge.groupByDay(NOW);
    check('凌晨与正午算同一天', edgeDays.length, 1, 1e-12);
    checkText('同一天内仍按时间降序', edgeDays[0].records.map((r) => r.id).join(','), 'e_noon,e_night');
    checkText('凌晨那条照样标「今天」', edgeDays[0].label, '今天');
  }

  if (typeof SessionLedger.prototype.remove !== 'function'
    || typeof SessionLedger.prototype.groupByDay !== 'function') {
    assertTrue('SessionLedger.remove 存在', typeof SessionLedger.prototype.remove === 'function',
      '账本还没有删除能力');
    assertTrue('SessionLedger.groupByDay 存在', typeof SessionLedger.prototype.groupByDay === 'function',
      '账本还没有按日期分组能力');
  } else {
    managementTests();
  }
}

// ---- 量取参考细则 ----------------------------------------------------------
// 让历史记录带上分:分数不存进记录,回看时按细则从事实重算(不变量 I4)。
{
  const { RubricMeasure, Rubrics } = require(join(OUT, 'bench/RubricMeasure.cjs'));
  const { Judgment } = require(join(OUT, 'bench/Judgment.cjs'));
  const { RubricValidator } = require(join(OUT, 'bench/Rubric.cjs'));
  const { SessionRecord, fact } = require(join(OUT, 'model/SessionRecord.cjs'));
  const { Subject } = require(join(OUT, 'model/ExperimentTypes.cjs'));

  function scoreOf(rubric, sheet, label) {
    try {
      return Judgment.score(rubric, sheet);
    } catch (error) {
      failures.push(`${label}: 打分抛错 ${error.message}`);
      return null;
    }
  }

  function pour(actualMl, readMl, spilledMl, goalMl) {
    const record = new SessionRecord();
    record.id = 'pour-' + String(actualMl);
    record.experimentId = 'measure-10ml';
    record.title = '用量筒量取 10 mL 水';
    record.subject = Subject.INSTRUMENT;
    record.rubricId = RubricMeasure.ID;
    record.endedAtMs = 1000;
    const facts = [fact('goalMl', goalMl), fact('actualMl', actualMl),
      fact('readMl', readMl), fact('spilledMl', spilledMl), fact('tiltDeg', 26)];
    record.facts = facts;
    return record;
  }

  const rubric = RubricMeasure.create();
  const problems = RubricValidator.validate(rubric);
  check('细则本身合法(校验零问题)', problems.length, 0, 1e-12);
  check('满分 100', rubric.totalPoints, 100, 1e-12);
  checkText('细则标注为非官方', rubric.source, '参考细则（非官方标准）');
  // 版本直接印在报告上,内部代号(draft1)与半角括号都是工程词外泄
  checkText('版本号印给学生看的写法', rubric.version, '2026.09 第1版');
  assertTrue('细则带版本号', rubric.version.length > 0, '版本为空');
  check('判据条数', rubric.criteria.length, 2, 1e-12);
  check('判据分值合计等于满分',
    rubric.criteria.reduce((s, c) => s + c.points, 0), rubric.totalPoints, 1e-12);

  // 派生量由桥接层算,不进记录
  const sheet = RubricMeasure.factsOf(pour(9.95, 10, 0, 10));
  check('从记录派生出偏差', sheet.num('deviationMl'), -0.05, 1e-9);
  check('从记录派生出读数误差', sheet.num('readErrorMl'), 0.05, 1e-9);
  check('原始事实被带进事实清单', sheet.num('spilledMl'), 0, 1e-12);

  const perfect = scoreOf(rubric, RubricMeasure.factsOf(pour(9.95, 10, 0, 10)), '完美操作');
  if (perfect !== null) {
    check('完美操作拿满分', perfect.awarded, 100, 1e-12);
    check('完美操作零扣分', perfect.deductions.length, 0, 1e-12);
  }

  // 视差导致倒少:只扣偏差一条,不因同一个错误重复扣
  const parallax = scoreOf(rubric, RubricMeasure.factsOf(pour(8.6, 10, 0.2, 10)), '视差倒少');
  if (parallax !== null) {
    check('视差倒少只扣偏差一条', parallax.deductions.length, 1, 1e-12);
    checkText('扣的是偏差判据', parallax.deductions[0].criterionId, 'M01');
    check('扣掉偏差分', parallax.awarded, 100 - rubric.criteria[0].points, 1e-12);
    assertTrue('证据里能看到实际量到的数', parallax.deductions[0].evidence.includes('8.60'),
      parallax.deductions[0].evidence);
    assertTrue('证据里能看到视差这个原因', parallax.deductions[0].evidence.includes('1.40'),
      parallax.deductions[0].evidence);
  }

  const messy = scoreOf(rubric, RubricMeasure.factsOf(pour(9.9, 10, 3, 10)), '倒得准但洒了');
  if (messy !== null) {
    check('洒失单独成一条扣分', messy.deductions.length, 1, 1e-12);
    checkText('扣的是洒失判据', messy.deductions[0].criterionId, 'M02');
    check('洒失扣掉的分', messy.awarded, 100 - rubric.criteria[1].points, 1e-12);
  }

  const both = scoreOf(rubric, RubricMeasure.factsOf(pour(8, 10, 3, 10)), '又偏又洒');
  if (both !== null) {
    check('两条都犯扣到零分', both.awarded, 0, 1e-12);
    check('两条扣分都在', both.deductions.length, 2, 1e-12);
  }

  // R3 宁漏不误:关键事实缺失时放过,不猜
  const missing = new SessionRecord();
  missing.id = 'no-facts';
  missing.rubricId = RubricMeasure.ID;
  const blind = scoreOf(rubric, RubricMeasure.factsOf(missing), '事实缺失');
  if (blind !== null) {
    check('事实缺失时不扣分', blind.awarded, 100, 1e-12);
    check('事实缺失时不编造扣分项', blind.deductions.length, 0, 1e-12);
  }

  // I4:重算只依赖事实,同一记录两次打分必须一致
  const again = scoreOf(rubric, RubricMeasure.factsOf(pour(8.6, 10, 0.2, 10)), '重放');
  if (parallax !== null && again !== null) {
    check('同一记录重放分数一致', again.awarded, parallax.awarded, 1e-12);
  }

  // 细则索引
  const idOf = (r) => (r === null || r === undefined ? '(null)' : r.id);
  checkText('按 id 找得到量取细则', idOf(Rubrics.byId(RubricMeasure.ID)), RubricMeasure.ID);
  checkText('按 id 找得到提纯细则', idOf(Rubrics.byId('brine-purification')), 'brine-purification');
  assertTrue('未知 id 返回 null 而不是猜一份', Rubrics.byId('nope') === null, '返回了东西');

  // 报告页不该按细则分支写 if,派生事实由索引层按 rubricId 分发
  const dispatched = Rubrics.factsFor(pour(8.6, 10, 0.2, 10));
  check('分发后能拿到派生量', dispatched.num('deviationMl'), -1.4, 1e-9);
  const foreign = new SessionRecord();
  foreign.id = 'other';
  foreign.rubricId = 'some-other-rubric';
  foreign.facts = [fact('actualMl', 8.6), fact('goalMl', 10)];
  const raw = Rubrics.factsFor(foreign);
  check('未知细则只做原样搬运,不替它编派生量', raw.num('actualMl'), 8.6, 1e-9);
  assertTrue('未知细则不产出 deviationMl', Number.isNaN(raw.num('deviationMl')), '凭空派生了');
  check('未知细则下打分不扣分(事实缺失一律放过)',
    scoreOf(RubricMeasure.create(), raw, '未知细则').awarded, 100, 1e-12);
}

// ---- 粉末取用(药匙) ------------------------------------------------------
// 首发链路真正缺的第一步:取粗盐。可信的是单调关系与守恒,不是具体占比(标定同 R2)。
{
  const { Spatula } = require(join(OUT, 'bench/Spatula.cjs'));
  const { Container } = require(join(OUT, 'bench/Container.cjs'));
  const { Glassware } = require(join(OUT, 'geometry/Profile.cjs'));
  const { Separations } = require(join(OUT, 'bench/Brine.cjs'));

  const SALT_G = 4.0;
  const SAND_G = 1.0;

  function beaker() {
    return Container.of('b', '烧杯', Glassware.beaker100());
  }

  function take(tiltDeg, reachCm, saltG, sandG) {
    const vessel = beaker();
    const before = vessel.brine.totalAccounted();
    const result = Spatula.deliver(vessel, saltG === undefined ? SALT_G : saltG,
      sandG === undefined ? SAND_G : sandG, tiltDeg, reachCm);
    return { vessel: vessel, result: result, delta: vessel.brine.totalAccounted() - before };
  }

  // 规范动作:一斜二送三直立。横放 + 送到底 => 一点不沾壁、一点不撒
  const good = take(0, 7);
  check('规范取用全部落底', good.result.deliveredG, SALT_G + SAND_G, 1e-12);
  check('规范取用不沾壁', good.result.stuckWallG, 0, 1e-12);
  check('规范取用不撒落', good.result.spilledG, 0, 1e-12);
  check('规范取用账本增量等于投料', good.delta, SALT_G + SAND_G, 1e-12);

  // 失误动作:容器直立、药匙没伸进去,从瓶口往下倒
  const bad = take(90, 0);
  assertTrue('直立浅取会沾壁', bad.result.stuckWallG > 0, `实得 ${bad.result.stuckWallG}`);
  assertTrue('直立浅取会撒落', bad.result.spilledG > 0, `实得 ${bad.result.spilledG}`);
  assertTrue('直立浅取落底的比投料少', bad.result.deliveredG < SALT_G + SAND_G, '一份没少');

  // 守恒:任何姿态下三项之和必须等于投料量,这是这一节的全部意义
  for (const tilt of [0, 30, 60, 90]) {
    for (const reach of [0, 2, 4, 7, 9]) {
      const run = take(tilt, reach);
      const sum = run.result.deliveredG + run.result.stuckWallG + run.result.spilledG;
      check(`守恒 tilt=${tilt} reach=${reach}`, sum, SALT_G + SAND_G, 1e-9);
      check(`账本守恒 tilt=${tilt} reach=${reach}`, run.delta, SALT_G + SAND_G, 1e-9);
    }
  }

  // 单调性:送得越深沾壁越少
  const shallow = take(90, 0).result.stuckWallG;
  const mid = take(90, 3.5).result.stuckWallG;
  const deep = take(90, 6.5).result.stuckWallG;
  assertTrue('送得越深沾壁越少', shallow > mid && mid > deep, `${shallow} / ${mid} / ${deep}`);

  // 单调性:越接近横放沾壁越少
  const upright = take(90, 0).result.stuckWallG;
  const slanted = take(45, 0).result.stuckWallG;
  const flat = take(0, 0).result.stuckWallG;
  assertTrue('越接近横放沾壁越少', upright > slanted && slanted > flat,
    `${upright} / ${slanted} / ${flat}`);

  // 沾壁的东西去哪了:单独存量,不混进可溶解的那份
  const stuck = take(90, 0);
  assertTrue('沾壁的盐进 saltStuckG', stuck.vessel.brine.saltStuckG > 0, '没进沾壁存量');
  assertTrue('沾壁的砂进 sandStuckG', stuck.vessel.brine.sandStuckG > 0, '没进沾壁存量');
  check('落底的盐才进 saltSolidG', stuck.vessel.brine.saltSolidG,
    stuck.result.deliveredG * (SALT_G / (SALT_G + SAND_G)), 1e-9);

  // 关键后果:沾壁的盐不参与溶解,所以这一轮的产率真的低了
  Separations.addWater(stuck.vessel.brine, 60);
  for (let i = 0; i < 40000; i++) {
    Separations.dissolve(stuck.vessel.brine, 1 / 240, true);
  }
  check('可溶的盐全部溶完', stuck.vessel.brine.saltSolidG, 0, 1e-9);
  assertTrue('沾壁的盐一点没溶', stuck.vessel.brine.saltStuckG > 0, '被溶解吃掉了');
  check('沾壁的盐溶解前后不变', stuck.vessel.brine.saltStuckG,
    stuck.result.stuckWallG * (SALT_G / (SALT_G + SAND_G)), 1e-9);

  // 撒落的进损失账
  const spilled = take(90, 0);
  check('撒落计入损失', spilled.vessel.brine.losses.spilledSaltG
    + spilled.vessel.brine.losses.spilledSandG, spilled.result.spilledG, 1e-9);

  // 边界
  const zero = take(90, 0, 0, 0);
  check('零投料不沾壁', zero.result.stuckWallG, 0, 1e-12);
  check('零投料账本不动', zero.delta, 0, 1e-12);
  const negative = take(90, 0, -5, -3);
  check('负投料被夹到零', negative.result.deliveredG, 0, 1e-12);
  check('负投料不产生负存量', negative.vessel.brine.totalAccounted(), 0, 1e-12);

  // 确定性:同参数两次必须给同一个数(不变量 I2)
  const first = take(70, 1.5).result;
  const second = take(70, 1.5).result;
  check('同参数沾壁量一致', second.stuckWallG, first.stuckWallG, 1e-15);
  check('同参数落底量一致', second.deliveredG, first.deliveredG, 1e-15);
}

// ---- 滴加(胶头滴管)--------------------------------------------------------
// 考点全部落在可测后果上:伸入或碰壁 => 尖端被容器里的溶液润湿(交叉污染量),
// 胶头朝下 => 药液倒流进胶头(既腐蚀胶头又污染试剂),滴得过高 => 冲击飞溅。
// 规范动作必须精确地什么都不损失,否则"失误"就没有对照基线。
{
  const { Dropper, DropPose } = require(join(OUT, 'bench/Dropper.cjs'));
  const VOL = 2.0;

  function drop(tipAboveRimCm, touchesWall, bulbUp, mouthToSurfaceCm, volumeMl) {
    const pose = new DropPose();
    pose.volumeMl = volumeMl === undefined ? VOL : volumeMl;
    pose.tipAboveRimCm = tipAboveRimCm;
    pose.touchesWall = touchesWall === true;
    pose.bulbUp = bulbUp !== false;
    pose.mouthToSurfaceCm = mouthToSurfaceCm === undefined ? 2 : mouthToSurfaceCm;
    return Dropper.deliver(pose);
  }
  const sumOf = (r) => r.deliveredMl + r.stuckWallMl + r.splashedMl + r.refluxMl;

  // 规范:垂直悬空在容器口上方约 0.8 cm、不碰壁、胶头朝上
  const good = drop(0.8, false, true);
  check('规范滴加全部进液面', good.deliveredMl, VOL, 1e-12);
  check('规范滴加不挂壁', good.stuckWallMl, 0, 1e-12);
  check('规范滴加不飞溅', good.splashedMl, 0, 1e-12);
  check('规范滴加不倒流', good.refluxMl, 0, 1e-12);
  check('规范滴加不带走容器里的液体', good.carriedBackMl, 0, 1e-12);

  // 守恒:滴管里的体积只分成四处,任何姿态下都不许多也不亏
  for (const tip of [-4, -2, -0.5, 0, 0.8, 2, 6, 12]) {
    for (const wall of [false, true]) {
      for (const up of [true, false]) {
        const r = drop(tip, wall, up);
        check(`守恒 tip=${tip} wall=${wall} up=${up}`, sumOf(r), VOL, 1e-9);
        assertTrue('四项都非负', r.deliveredMl >= 0 && r.stuckWallMl >= 0
          && r.splashedMl >= 0 && r.refluxMl >= 0, JSON.stringify(r));
        assertTrue('带回量不为负', r.carriedBackMl >= 0, String(r.carriedBackMl));
      }
    }
  }

  // 考点一:不得伸入容器内 —— 伸进去尖端就被容器里的溶液沾湿,提出来带回去
  assertTrue('伸入容器内会带回液体', drop(-2, false, true).carriedBackMl > 0, '为 0 就没这个考点');
  assertTrue('伸得越深带回越多',
    drop(-4, false, true).carriedBackMl > drop(-1, false, true).carriedBackMl, '不随深度单调');
  check('悬空在口上方不带回', drop(0.8, false, true).carriedBackMl, 0, 1e-12);
  assertTrue('碰壁即使没伸入也会带回', drop(0.8, true, true).carriedBackMl > 0, '碰壁没后果');
  assertTrue('伸入且碰壁比只伸入更脏',
    drop(-2, true, true).carriedBackMl > drop(-2, false, true).carriedBackMl, '碰壁没加重');
  // 带回的液体不再进容器,所以落进液面的量必然减少
  assertTrue('伸入后落进液面的变少', drop(-2, false, true).deliveredMl < VOL, '一点没少');
  assertTrue('挂壁量随伸入深度增加',
    drop(-4, false, true).stuckWallMl > drop(-1, false, true).stuckWallMl, '不单调');

  // 考点二:胶头不能朝下 —— 药液倒流进胶头,既腐蚀胶头又污染试剂
  assertTrue('倒置时药液倒流进胶头', drop(0.8, false, false).refluxMl > 0, '倒流没被建模');
  check('胶头朝上不倒流', drop(0.8, false, true).refluxMl, 0, 1e-12);
  assertTrue('倒置且体积越大倒流越多',
    drop(0.8, false, false, 2, 4).refluxMl > drop(0.8, false, false, 2, 1).refluxMl, '不单调');

  // 考点三:滴得过高,液滴冲击液面造成飞溅;规范高度必须为零
  assertTrue('滴得越高溅得越多',
    drop(12, false, true).splashedMl > drop(6, false, true).splashedMl, '不单调');
  check('规范高度不溅', drop(0.8, false, true).splashedMl, 0, 1e-12);
  assertTrue('液面越深(落差越大)溅得越多',
    drop(0.8, false, true, 9).splashedMl > drop(0.8, false, true, 3).splashedMl, '落差没进模型');

  // 边界与确定性
  const zero = drop(0.8, false, true, 2, 0);
  check('零体积什么都不产生', sumOf(zero), 0, 1e-12);
  const neg = drop(0.8, false, true, 2, -5);
  assertTrue('负体积按零处理', sumOf(neg) === 0 && Number.isFinite(neg.deliveredMl),
    String(neg.deliveredMl));
  const dirty = drop(Number.NaN, false, true, Number.NaN);
  assertTrue('非法几何不产出 NaN', Number.isFinite(sumOf(dirty)), JSON.stringify(dirty));
  check('同参数两次结果一致', sumOf(drop(-2, true, false)), sumOf(drop(-2, true, false)), 1e-15);
}

// ---- 块状固体取用(镊子)「一横二放三慢竖」--------------------------------
// 这条链路上最硬的后果:直立着把锌粒丢下去,砸破的是试管底。破损取连续损伤量而不是
// 布尔,因为「裂而未破」与「砸穿」在真实操作里都存在,而连续模型正是本设计的立论。
{
  const { ChunkSolid, ChunkPose } = require(join(OUT, 'bench/ChunkSolid.cjs'));
  const MASS = 4.0;

  function drop(tiltDeg, verticalDropCm, massG) {
    const pose = new ChunkPose();
    pose.massG = massG === undefined ? MASS : massG;
    pose.tiltDeg = tiltDeg;
    pose.verticalDropCm = verticalDropCm;
    return ChunkSolid.deliver(pose);
  }
  const sumOf = (r) => r.landedG + r.stuckWallG + r.escapedG;

  // 规范:试管横放、块体放在管口、再慢慢竖起 —— 沿壁滑到底,竖直落差只有一个半径
  const good = drop(0, 1);
  check('规范投放全部落底', good.landedG, MASS, 1e-12);
  check('规范投放不挂壁', good.stuckWallG, 0, 1e-12);
  check('规范投放不崩出', good.escapedG, 0, 1e-12);
  check('规范投放管底无损', good.bottomDamage, 0, 1e-12);

  // 守恒:任何姿态下三处之和等于投放量
  for (const tilt of [0, 30, 60, 90]) {
    for (const fall of [0, 1, 4, 8, 15]) {
      const r = drop(tilt, fall);
      check(`守恒 tilt=${tilt} fall=${fall}`, sumOf(r), MASS, 1e-9);
      assertTrue('三处都非负', r.landedG >= 0 && r.stuckWallG >= 0 && r.escapedG >= 0,
        JSON.stringify(r));
      assertTrue('损伤量落在 0..1', r.bottomDamage >= 0 && r.bottomDamage <= 1,
        String(r.bottomDamage));
    }
  }

  // 考点一:直立丢入会砸坏器底,落差越大伤越重
  assertTrue('直立从管口丢下砸伤管底', drop(90, 12).bottomDamage > 0, '破损没被建模');
  assertTrue('落差越大损伤越重',
    drop(90, 15).bottomDamage > drop(90, 6).bottomDamage, '不随落差单调');
  check('滑到底不损伤', drop(0, 1).bottomDamage, 0, 1e-12);
  check('落差在阈值内不损伤', drop(30, 3).bottomDamage, 0, 1e-12);

  // 考点二:直立时块体撞在管壁上挂住,横放则滑到底
  assertTrue('直立投放会挂壁', drop(90, 2).stuckWallG > 0, '挂壁没被建模');
  assertTrue('越接近直立挂壁越多',
    drop(90, 2).stuckWallG > drop(45, 2).stuckWallG &&
    drop(45, 2).stuckWallG > drop(10, 2).stuckWallG, '不随倾角单调');
  check('横放挂壁为零', drop(0, 8).stuckWallG, 0, 1e-12);

  // 考点三:砸得狠会崩出碎屑,落底的随之减少
  assertTrue('砸得越狠崩出越多', drop(90, 15).escapedG > drop(90, 6).escapedG, '崩出没后果');
  assertTrue('破损时落底的比投放量少', drop(90, 12).landedG < MASS, '全落底了');
  check('轻放时落底量等于投放量', drop(0, 1).landedG, MASS, 1e-12);

  // 边界与确定性
  check('零质量什么都不产生', sumOf(drop(90, 12, 0)), 0, 1e-12);
  const neg = drop(90, 12, -3);
  assertTrue('负质量按零处理', sumOf(neg) === 0 && Number.isFinite(neg.landedG),
    String(neg.landedG));
  const dirty = drop(Number.NaN, Number.NaN);
  assertTrue('非法几何不产出 NaN', Number.isFinite(sumOf(dirty))
    && Number.isFinite(dirty.bottomDamage), JSON.stringify(dirty));
  check('同参数两次结果一致', sumOf(drop(90, 12)), sumOf(drop(90, 12)), 1e-15);
}

// ---- M4:两套容器共用一个外壳,漏失单独成账 --------------------------------
// 合并的是外壳(几何、位姿、支撑、损伤),不是账本:Brine 按相演化,试剂按化学计量反应,
// 强行并成一套要么丢反应表要么编出不存在的试剂键。
// 漏失必须由账本按比例自己取走 —— 否则 I1 当场破掉。
{
  const { Container } = require(join(OUT, 'bench/Container.cjs'));
  const { Glassware, Profile } = require(join(OUT, 'geometry/Profile.cjs'));
  const { GlassShapes } = require(join(OUT, 'geometry/GlassShapes.cjs'));
  const { Separations } = require(join(OUT, 'bench/Brine.cjs'));
  const { Spatula } = require(join(OUT, 'bench/Spatula.cjs'));
  const { Vessel, VesselKind, PORTION_MOLES } = require(join(OUT, 'chemistry/BenchModel.cjs'));
  const { BenchEngine } = require(join(OUT, 'chemistry/BenchEngine.cjs'));
  const { ChemistryLibrary, massOf } = require(join(OUT, 'chemistry/ChemistryLibrary.cjs'));
  ChemistryLibrary.registerReagents();

  function beakerWith() {
    const c = Container.of('b', '烧杯', Glassware.beaker100());
    Separations.addWater(c.brine, 60);
    // 直立浅取一份粉末:于是既有落底的、也有沾在壁上的 —— 沾壁的不该从底部裂缝漏走
    Spatula.deliver(c, 4, 1, 90, 0);
    return c;
  }
  function tubeWith(portions) {
    const v = Vessel.of(VesselKind.TUBE, '试管', 8);
    v.id = 't1';
    BenchEngine.add(v, 'cuso4', (portions === undefined ? 4 : portions) * PORTION_MOLES);
    return v;
  }

  // --- 外壳:竖直落差只由倾角与轴向距离决定 ---
  const flat = beakerWith(); flat.pose.tiltDeg = 0;
  const tilted = beakerWith(); tilted.pose.tiltDeg = 30;
  const upright = beakerWith(); upright.pose.tiltDeg = 90;
  check('横放时竖直落差为零', flat.verticalDropCm(12), 0, 1e-12);
  check('直立时竖直落差等于轴向距离', upright.verticalDropCm(12), 12, 1e-9);
  check('30 度时落差是轴向的一半', tilted.verticalDropCm(12), 6, 1e-9);
  assertTrue('落差随倾角单调',
    flat.verticalDropCm(12) < tilted.verticalDropCm(12) &&
    tilted.verticalDropCm(12) < upright.verticalDropCm(12), '倾角没进落差');
  check('轴向距离为零则落差为零', upright.verticalDropCm(0), 0, 1e-12);
  assertTrue('非法倾角不产出 NaN', Number.isFinite(upright.verticalDropCm(Number.NaN)),
    'NaN 漏出去了');

  // --- 外壳:漏失比例就是损伤程度 ---
  check('无损不漏', beakerWith().leakFraction(), 0, 1e-12);
  const cracked = beakerWith(); cracked.damage = 0.4;
  check('损伤 0.4 漏掉 0.4', cracked.leakFraction(), 0.4, 1e-12);
  const wreck = beakerWith(); wreck.damage = 1.8;
  check('损伤夹在 0..1', wreck.leakFraction(), 1, 1e-12);

  // --- 提纯链路:漏走按比例的一份,且进第三笔账 ---
  const leaky = beakerWith();
  const accountedBefore = leaky.brine.totalAccounted();
  const massBefore = leaky.brine.mass();
  const stuckBefore = leaky.brine.saltStuckG + leaky.brine.sandStuckG;
  assertTrue('前置成立:确实有沾壁的料', stuckBefore > 0, '没有沾壁材料,下面几条测不到东西');
  leaky.damage = 0.5;
  const leakedG = leaky.drainFraction(leaky.leakFraction());
  check('漏失不凭空产生质量', leaky.brine.totalAccounted(), accountedBefore, 1e-9);
  check('现存减少量等于漏出量', massBefore - leaky.brine.mass(), leakedG, 1e-9);
  check('漏走的是可流动部分的一半', leakedG, (massBefore - stuckBefore) * 0.5, 1e-9);
  check('沾壁的料一点没漏', leaky.brine.saltStuckG + leaky.brine.sandStuckG, stuckBefore, 1e-12);
  assertTrue('漏失单独成账', leaky.brine.losses.leakedWaterMl > 0, '没记漏失');
  assertTrue('漏失不混进溅失账', leaky.brine.losses.spilledWaterMl === 0,
    `溅失被污染:${leaky.brine.losses.spilledWaterMl}`);
  const empty = beakerWith();
  const emptyMass = empty.brine.mass();
  const emptyAccounted = empty.brine.totalAccounted();
  const emptyStuck = empty.brine.saltStuckG + empty.brine.sandStuckG;
  empty.damage = 1;
  const drainedAll = empty.drainFraction(empty.leakFraction());
  check('砸穿之后只剩沾壁的料', empty.brine.mass(), emptyStuck, 1e-9);
  check('砸穿时漏出量等于可流动部分', drainedAll, emptyMass - emptyStuck, 1e-9);
  check('砸穿前后总量不变(含损失的总账)', empty.brine.totalAccounted(), emptyAccounted, 1e-9);

  // --- 反应链路:容器有真实几何,漏失同样守恒 ---
  check('默认 Vessel 就带试管剖面', new Vessel().profile.totalHeight(),
    Glassware.testTube().totalHeight(), 1e-12);
  const tubeVessel = tubeWith(4);
  check('试管按 kind 取到几何', tubeVessel.profile.totalHeight(), Glassware.testTube().totalHeight(), 1e-12);
  const keptBefore = BenchEngine.massIn(tubeVessel);
  tubeVessel.damage = 0.5;
  tubeVessel.drainFraction(tubeVessel.leakFraction());
  assertTrue('破底之后容器里的质量真的少了',
    BenchEngine.massIn(tubeVessel) < keptBefore, '一点没漏');
  check('漏出的量等于减少的量', keptBefore - BenchEngine.massIn(tubeVessel),
    BenchEngine.massLeaked(tubeVessel), 1e-9);
  check('现存 + 逸出 + 漏出 = 加入量',
    BenchEngine.massIn(tubeVessel) + BenchEngine.massEscaped(tubeVessel)
    + BenchEngine.massLeaked(tubeVessel),
    4 * PORTION_MOLES * massOf('cuso4'), 1e-9);

  // --- 形状表本身 ---
  check('烧杯形状与 Glassware 同源',
    GlassShapes.of('beaker').capacity(), Glassware.beaker100().capacity(), 1e-12);
  assertTrue('认不出的种类退回一个可用的剖面',
    GlassShapes.of('没有这种东西').totalHeight() > 0, '退化成空剖面');
  assertTrue('同一形状取两次是同一份表', GlassShapes.of('tube') === GlassShapes.of('tube'),
    '每次重建分段表');
}

// ---- 事实键的显示名 --------------------------------------------------------
// 报告页要能换链路显示,事实表就不能硬编码在页面里。这张表的价值全在下一条:
// 新增事实却忘了配标签时,断言会指名是哪个键。
{
  const { FactLabels } = require(join(OUT, 'model/FactLabels.cjs'));
  const { BrineScenario, BrineScenarioRunner } = require(join(OUT, 'bench/BrineScenario.cjs'));
  const { RubricMeasure, Rubrics } = require(join(OUT, 'bench/RubricMeasure.cjs'));
  const { SessionRecord, fact, moment } = require(join(OUT, 'model/SessionRecord.cjs'));

  const brineRun = BrineScenarioRunner.run(new BrineScenario());
  const brineKeys = [...brineRun.facts.numbers.keys()];
  assertTrue('提纯链路确实产出了多个事实', brineKeys.length > 10, `只有 ${brineKeys.length} 个,循环是空的`);
  for (const key of brineKeys) {
    assertTrue(`提纯事实「${key}」配了显示名`, FactLabels.of(key) !== null, '报告页会退回原始键名');
  }
  for (const event of [...brineRun.facts.moments.keys()]) {
    assertTrue(`时刻事件「${event}」配了显示名`, FactLabels.momentLabel(event) !== event,
      '显示成了内部事件名');
  }

  const measure = new SessionRecord();
  measure.id = 'm1';
  measure.rubricId = RubricMeasure.ID;
  measure.facts = [fact('goalMl', 10), fact('actualMl', 8.98), fact('readMl', 7),
    fact('spilledMl', 0.89), fact('tiltDeg', 40), fact('eyeCm', 2)];
  measure.moments = [moment('pourStart', 1.5), moment('pourStop', 9.75)];
  const measureSheet = RubricMeasure.factsOf(measure);
  const measureKeys = [...measureSheet.numbers.keys()];
  check('量取链路含派生量', measureKeys.length, 8, 1e-12);
  for (const key of measureKeys) {
    assertTrue(`量取事实「${key}」配了显示名`, FactLabels.of(key) !== null, '报告页会退回原始键名');
  }
  // 时刻必须被搬进事实清单:报告页的「步骤时序」段读的就是它,漏搬不会有任何判据失败
  check('量取时刻搬进了事实清单', measureSheet.moments.size, 2, 1e-12);
  check('收手停倒的时刻原样保留', measureSheet.at('pourStop'), 9.75, 1e-12);
  for (const event of [...measureSheet.moments.keys()]) {
    assertTrue(`量取时刻「${event}」配了显示名`, FactLabels.momentLabel(event) !== event,
      '显示成了内部事件名');
  }
  checkText('开始倾倒的显示名', FactLabels.momentLabel('pourStart'), '开始倾倒');
  const carried = Rubrics.factsFor(measure);
  check('分发路径同样搬时刻', carried.at('pourStart'), 1.5, 1e-12);

  // 显示名必须是「人话」,不是把键名换个写法
  checkText('投入粗盐的显示名', FactLabels.of('saltAddedG').label, '投入粗盐中 NaCl');
  checkText('沾壁损失的显示名', FactLabels.of('powderStuckSaltG').label, '沾壁损失的盐');
  checkText('量取偏差的显示名', FactLabels.of('deviationMl').label, '量取偏差');
  checkText('产率单位不带前导空格', FactLabels.of('yieldPct').unit, '%');
  checkText('质量单位带前导空格', FactLabels.of('saltRecoveredG').unit, ' g');

  // 格式化:标签列与数值列分开,因为事实表就是两栏布局
  checkText('数值列带单位', FactLabels.valueText('yieldPct', 88.5), '88.50%');
  checkText('数值列质量单位带空格', FactLabels.valueText('saltRecoveredG', 4.2), '4.20 g');
  // 计数与布尔类事实是整数,印成 4.00 会被读成"量出来的";单位前空格由上一行守住
  checkText('整数事实不印小数位', FactLabels.valueText('saltRecoveredG', 4), '4 g');
  // 是非题印成 0/1,学生会以为那格缺数(设备实测报告页正是这样)
  checkText('布尔事实印成是/否', FactLabels.valueText('beyondLimit', 0), '否');
  checkText('布尔事实为真印「是」', FactLabels.valueText('beyondLimit', 1), '是');
  checkText('引流开关也走是/否', FactLabels.valueText('rodUsed', 0), '否');
  checkText('缺值显示破折号而不是 NaN', FactLabels.valueText('yieldPct', Number.NaN), '—');
  checkText('标签列未知键退回键名', FactLabels.labelOf('brandNewKey'), 'brandNewKey');
  assertTrue('查不到的键 of 返回 null 而不是猜一个', FactLabels.of('nope') === null, '猜了一个');
  checkText('时刻事件也有显示名', FactLabels.momentLabel('dissolve'), '溶解完成');
}

// ---- 回转体渲染的几何与明暗 ------------------------------------------------
// 这一节保证两件事:画出来的宽度与算容积的截面积是同一个来源;
// 以及椭圆的扁率与明暗带随俯角、光向单调变化,不是拍出来的常数。
{
  const { Camera } = require(join(OUT, 'view3d/Camera.cjs'));
  const { Lathe, Shading } = require(join(OUT, 'view3d/Lathe.cjs'));
  const { Glassware, Profile } = require(join(OUT, 'geometry/Profile.cjs'));

  const DEG = Math.PI / 180;
  const radiusOf = (area) => Math.sqrt(area / Math.PI);

  // --- Profile.radiusAt:截面积的解析逆 ---
  const cyl = Glassware.graduatedCylinder10();
  check('量筒半径由截面积开方得到', cyl.radiusAt(7), radiusOf(10 / 15), 1e-9);
  check('量筒半径沿高度不变', cyl.radiusAt(0.2), cyl.radiusAt(14.8), 1e-12);
  check('半径平方乘 π 回到截面积',
    Math.PI * cyl.radiusAt(3) * cyl.radiusAt(3), cyl.areaAt(3), 1e-9);
  check('负高度处半径为 0', cyl.radiusAt(-1), 0, 1e-12);
  check('超量程处半径为 0', cyl.radiusAt(cyl.totalHeight() + 1), 0, 1e-12);

  const beaker = Glassware.beaker100();
  check('烧杯底半径', beaker.radiusAt(0), radiusOf(13.5), 1e-9);
  assertTrue('烧杯口半径大于底半径', beaker.radiusAt(6.9) > beaker.radiusAt(0),
    `${beaker.radiusAt(6.9)} ≤ ${beaker.radiusAt(0)}`);
  const dish = Glassware.evaporatingDish();
  check('蒸发皿半径', dish.radiusAt(0), radiusOf(28), 1e-9);
  assertTrue('蒸发皿比烧杯宽', dish.radiusAt(0) > beaker.radiusAt(0),
    `${dish.radiusAt(0)} ≤ ${beaker.radiusAt(0)}`);

  // --- revolve:半球底的试管与锥体细颈的锥形瓶 ---
  // 积分出来的容积必须贴住解析公式。贴不住就说明分段表与形状不是一回事,
  // 而「画出来的宽度」和「算出来的液面」共用这条曲线正是回转体渲染的全部前提。
  const tubeR = 0.9;
  const tubeAnalytic = (2 / 3) * Math.PI * tubeR * tubeR * tubeR +
    Math.PI * tubeR * tubeR * (15 - tubeR);
  const tube = Glassware.testTube();
  check('试管总高', tube.totalHeight(), 15, 1e-9);
  assertTrue('试管容积贴住半球加直筒的解析值',
    Math.abs(tube.capacity() - tubeAnalytic) < tubeAnalytic * 0.005,
    `实得 ${tube.capacity().toFixed(3)},解析 ${tubeAnalytic.toFixed(3)}`);
  check('试管底段按中点采样(半球在 0.05 cm 处的截面)',
    tube.radiusAt(0), Math.sqrt(tubeR * tubeR - (tubeR - 0.05) * (tubeR - 0.05)), 1e-9);
  check('试管口半径就是管径', tube.radiusAt(14.9), tubeR, 1e-9);
  assertTrue('试管半径沿高度不减', (() => {
    let prev = -1;
    for (let h = 0; h <= 15; h += 0.3) {
      const r = tube.radiusAt(h);
      if (r < prev - 1e-12) {
        return false;
      }
      prev = r;
    }
    return true;
  })(), '球底段抖了');
  check('试管半径平方乘 π 回到截面积',
    Math.PI * tube.radiusAt(0.4) * tube.radiusAt(0.4), tube.areaAt(0.4), 1e-9);
  // 球底段的意义:同样多的液体,在底部抬得比直筒段高
  const slabLow = tube.volumeBelow(0.5);
  const slabStraight = Math.PI * tubeR * tubeR * 0.5;
  assertTrue('球底同样高的一段装得比直筒少', slabLow < slabStraight * 0.7,
    `球底 ${slabLow.toFixed(3)} vs 直筒 ${slabStraight.toFixed(3)}`);

  const flaskBase = 3.9;
  const flaskNeck = 1.15;
  const flaskConeH = 8.2;
  const flaskAnalytic = Math.PI * flaskConeH / 3 *
    (flaskBase * flaskBase + flaskBase * flaskNeck + flaskNeck * flaskNeck) +
    Math.PI * flaskNeck * flaskNeck * 3.0;
  const flask = Glassware.conicalFlask();
  check('锥形瓶总高', flask.totalHeight(), flaskConeH + 3.0, 1e-9);
  assertTrue('锥形瓶容积贴住锥体加细颈的解析值',
    Math.abs(flask.capacity() - flaskAnalytic) < flaskAnalytic * 0.005,
    `实得 ${flask.capacity().toFixed(3)},解析 ${flaskAnalytic.toFixed(3)}`);
  // 分段表取的是每段中点的半径,所以 radiusAt(0) 是 0.05 cm 处的值,不是解析底径。
  // 钉住这条约定,否则将来改成左端点/右端点采样时,画出来的轮廓会整体错位半格。
  check('锥形瓶底段按中点采样',
    flask.radiusAt(0), flaskBase + (flaskNeck - flaskBase) * (0.05 / flaskConeH), 1e-9);
  assertTrue('底段比上一段粗(锥度方向正确)',
    flask.radiusAt(0) > flask.radiusAt(1), '锥体画反了');
  check('锥形瓶颈半径', flask.radiusAt(11), flaskNeck, 1e-9);
  assertTrue('锥体段严格收窄', flask.radiusAt(6) < flask.radiusAt(2) &&
    flask.radiusAt(8) < flask.radiusAt(6), '锥度没进去');
  assertTrue('细颈段等粗', Math.abs(flask.radiusAt(9.5) - flask.radiusAt(11.1)) < 1e-12,
    '颈段不该再变');
  check('锥形瓶容积与液面高度互为逆运算',
    flask.volumeBelow(flask.heightForVolume(120)), 120, 1e-6);
  check('试管容积与液面高度互为逆运算',
    tube.volumeBelow(tube.heightForVolume(20)), 20, 1e-6);
  assertTrue('半管液体在锥形瓶里不到一半高(下粗上细)',
    flask.heightForVolume(flask.capacity() / 2) < flask.totalHeight() / 2,
    '锥形瓶的液面高度不该这样');

  // --- Camera:俯仰正交投影 ---
  const cam = new Camera();
  cam.elevationDeg = 0;
  cam.pxPerCm = 10;
  cam.centerX = 200;
  cam.baseY = 500;
  check('平视时椭圆塌成一条线', cam.flatten(), 0, 1e-12);
  check('平视时高度不压缩', cam.heightScale(), 1, 1e-12);
  cam.elevationDeg = 90;
  check('正俯视时圆环是正圆', cam.flatten(), 1, 1e-12);
  check('正俯视时高度全部重合', cam.heightScale(), 0, 1e-12);
  check('正俯视下器底与器口同高', cam.screenY(0), cam.screenY(15), 1e-9);
  cam.elevationDeg = 30;
  check('俯角 30 度扁率是 0.5', cam.flatten(), 0.5, 1e-12);
  check('扁率平方加压缩比平方恒为 1',
    cam.flatten() * cam.flatten() + cam.heightScale() * cam.heightScale(), 1, 1e-12);
  check('半径线性映射到半宽', cam.halfWidth(2.5), 25, 1e-12);
  check('零半径映射到零半宽', cam.halfWidth(0), 0, 1e-12);
  cam.elevationDeg = 20;
  assertTrue('越高在屏幕上越靠上(Canvas y 向下)', cam.screenY(10) < cam.screenY(0),
    `${cam.screenY(10)} ≥ ${cam.screenY(0)}`);
  check('器底投影回 baseY', cam.screenY(0), cam.baseY, 1e-12);

  const ring = cam.ring(4, 2);
  check('圆环中心 x 等于光轴', ring.cx, cam.centerX, 1e-12);
  check('圆环中心 y 等于该高度的投影', ring.cy, cam.screenY(4), 1e-12);
  check('圆环长半轴等于半宽', ring.rx, cam.halfWidth(2), 1e-12);
  check('圆环短半轴等于长半轴乘扁率', ring.ry, ring.rx * cam.flatten(), 1e-12);
  assertTrue('俯角增大时椭圆变胖', cam.ring(4, 2).ry < (() => {
    const steep = new Camera();
    steep.elevationDeg = 60;
    steep.pxPerCm = 10;
    return steep.ring(4, 2).ry;
  })(), '扁率没随俯角单调');

  // --- Camera.widthGain:可读性放大只加宽,不改形状 ---
  check('默认倍率是 1', cam.widthGain, 1, 1e-12);
  cam.widthGain = 4;
  check('半宽随倍率线性放大', cam.halfWidth(2), 80, 1e-12);
  check('倍率不进扁率(椭圆仍是同一俯角的投影)', cam.ring(4, 2).ry / cam.ring(4, 2).rx,
    cam.flatten(), 1e-12);
  check('倍率不进高度方向(纵向不受影响)', cam.screenY(4), cam.baseY - 4 * cam.heightScale() * cam.pxPerCm, 1e-12);
  assertTrue('同一高度上任意两点宽度同比放大',
    Math.abs(cam.ring(4, 2).rx / cam.ring(4, 1).rx - 2) < 1e-12, '不同半径被放大了不同的倍数');
  const gainZero = new Camera();
  gainZero.widthGain = 0;
  check('倍率为 0 时退化成一条中轴', gainZero.ring(3, 2).rx, 0, 1e-12);
  check('倍率为 0 时高度仍如实投影', gainZero.screenY(3), gainZero.baseY - 3 * gainZero.heightScale() * gainZero.pxPerCm, 1e-12);
  cam.widthGain = 1;

  // --- Ring.pointAt:方位角与 Shading 共用同一个角 ---
  const front = cam.ring(5, 2);
  check('正对观察者处落在椭圆最下沿', front.pointAt(0).y, front.cy + front.ry, 1e-9);
  check('正对观察者处水平居中', front.pointAt(0).x, front.cx, 1e-9);
  check('左切点在负 90 度', front.pointAt(-90).x, front.cx - front.rx, 1e-9);
  check('右切点在正 90 度', front.pointAt(90).x, front.cx + front.rx, 1e-9);
  check('切点高度等于环心', front.pointAt(90).y, front.cy, 1e-9);
  check('远侧点在椭圆最上沿', front.pointAt(180).y, front.cy - front.ry, 1e-9);
  assertTrue('近侧比远侧低(Canvas y 向下)', front.pointAt(0).y > front.pointAt(180).y,
    '前后反了');
  assertTrue('可见前半周上 x 随方位角单调右移', (() => {
    let prev = Number.NEGATIVE_INFINITY;
    for (let phi = -90; phi <= 90; phi += 15) {
      const x = front.pointAt(phi).x;
      if (x < prev) {
        return false;
      }
      prev = x;
    }
    return true;
  })(), 'x 与 Shading.stops 的左右顺序不一致');

  // --- Lathe:只读 Profile,不另存形状 ---
  const lathe = Lathe.fromProfile(beaker);
  check('Lathe 半径就是 Profile 半径', lathe.radiusAt(3), beaker.radiusAt(3), 1e-12);
  check('Lathe 总高就是 Profile 总高', lathe.totalHeight(), beaker.totalHeight(), 1e-12);
  check('液面高度与判定层同一个函数', lathe.liquidHeight(50), beaker.heightForVolume(50), 1e-12);
  check('空容器液面为零', lathe.liquidHeight(0), 0, 1e-12);

  const profile = Lathe.fromProfile(cyl).silhouette(1);
  check('母线采样覆盖整高(15cm 步长 1 → 16 点)', profile.length, 16, 1e-12);
  check('首点在底部', profile[0].h, 0, 1e-12);
  check('末点在口沿', profile[profile.length - 1].h, 15, 1e-12);
  assertTrue('直筒母线半径恒定', profile.every((s) => Math.abs(s.r - cyl.radiusAt(0)) < 1e-12),
    '半径抖了');
  const tapered = Lathe.fromProfile(beaker).silhouette(0.5);
  let strictUp = true;
  for (let i = 1; i < tapered.length; i++) {
    if (!(tapered[i].r > tapered[i - 1].r)) {
      strictUp = false;
    }
  }
  assertTrue('锥形母线半径严格递增', strictUp, '有平台段');
  assertTrue('母线高度严格递增', tapered.every((s) => s.h >= 0 && s.r >= 0), '出现负值');
  assertTrue('步长非法时至少给出端点',
    Lathe.fromProfile(beaker).silhouette(0).length >= 2, '退化成了空轮廓');

  // --- Shading:柱面明暗 ---
  check('光正对处最亮', Shading.brightness(30, 30), 1, 1e-12);
  check('背光处全暗', Shading.brightness(30 + 180, 30), 0, 1e-12);
  check('明暗关于光向对称', Shading.brightness(10, 30), Shading.brightness(50, 30), 1e-12);
  assertTrue('亮度恒在 0 到 1 之间', [-90, -45, 0, 45, 90, 135, 180, 270]
    .every((phi) => Shading.brightness(phi, -20) >= 0 && Shading.brightness(phi, -20) <= 1),
    '越界了');

  const centered = Shading.stops(0, 9);
  check('停靠点数量对', centered.length, 9, 1e-12);
  check('居中光下最亮在正中', centered.indexOf(Math.max(...centered)), 4, 1e-12);
  const left = Shading.stops(-45, 9);
  const right = Shading.stops(45, 9);
  check('光偏左时高光带偏左', left.indexOf(Math.max(...left)), 2, 1e-12);
  check('光偏右时高光带偏右', right.indexOf(Math.max(...right)), 6, 1e-12);
  assertTrue('光偏左时左边缘比右边缘亮', left[0] > left[left.length - 1],
    `${left[0]} ≤ ${left[left.length - 1]}`);
  assertTrue('光偏右时右边缘比左边缘亮', right[right.length - 1] > right[0],
    `${right[right.length - 1]} ≤ ${right[0]}`);
  // 单峰:到最大值之前不下降,之后不上升
  assertTrue('明暗带是单峰的', (() => {
    for (const series of [centered, left, right]) {
      const peak = series.indexOf(Math.max(...series));
      for (let i = 1; i < series.length; i++) {
        if (i <= peak && series[i] < series[i - 1]) {
          return false;
        }
        if (i > peak && series[i] > series[i - 1]) {
          return false;
        }
      }
    }
    return true;
  })(), '出现多个亮带或谷');

  // --- LathePainter.fitFor:画出来一定不出框,而且加宽不改变形状 ---
  const { LathePainter } = require(join(OUT, 'view3d/LathePainter.cjs'));
  const wares = [
    ['量筒', Glassware.graduatedCylinder10()],
    ['烧杯', Glassware.beaker100()],
    ['漏斗筒', Glassware.funnelStem()],
    ['蒸发皿', Glassware.evaporatingDish()]
  ];
  const frames = [[132, 252], [196, 400], [300, 300], [90, 200], [480, 120]];
  const widest = (lt) => {
    let r = 0;
    for (const s of lt.silhouette(0.2)) {
      if (s.r > r) {
        r = s.r;
      }
    }
    return r;
  };
  for (const [name, ware] of wares) {
    for (const [w, h] of frames) {
      const lt = Lathe.fromProfile(ware);
      const c = LathePainter.fitFor(lt, w, h);
      const body = lt.totalHeight() * c.heightScale() * c.pxPerCm;
      const bulge = widest(lt) * c.pxPerCm * c.widthGain * c.flatten();
      assertTrue(`${name} 在 ${w}x${h} 里器口不出上沿`, c.baseY - body - bulge >= -1e-6,
        `顶部到 ${(c.baseY - body - bulge).toFixed(2)}`);
      assertTrue(`${name} 在 ${w}x${h} 里器底投影不出下沿`, c.baseY + 1.6 * bulge <= h + 1e-6,
        `底部到 ${(c.baseY + 1.6 * bulge).toFixed(2)} > ${h}`);
      assertTrue(`${name} 在 ${w}x${h} 里半宽不出侧沿`,
        c.halfWidth(widest(lt)) <= w * LathePainter.WIDTH_FILL + 1e-6,
        `${c.halfWidth(widest(lt)).toFixed(2)} > ${(w * LathePainter.WIDTH_FILL).toFixed(2)}`);
      assertTrue(`${name} 在 ${w}x${h} 里定标有效`,
        Number.isFinite(c.pxPerCm) && c.pxPerCm > 0 && c.widthGain >= 1
        && c.widthGain <= LathePainter.MAX_GAIN + 1e-9 && c.centerX === w / 2,
        `px=${c.pxPerCm} gain=${c.widthGain}`);
    }
  }
  // 器底必须坐在画布下沿:并排的器材共用一条台面,各自垂直居中会让矮的「浮」起来
  for (const [name, ware] of wares) {
    const sit = LathePainter.fitFor(Lathe.fromProfile(ware), 132, 252);
    const bulge = widest(Lathe.fromProfile(ware)) * sit.pxPerCm * sit.widthGain * sit.flatten();
    assertTrue(`${name} 的器底贴住台面`, Math.abs(252 - (sit.baseY + 1.7 * bulge) - 1) < 0.5,
      `器底离下沿 ${(252 - sit.baseY).toFixed(2)}`);
  }
  const cylinder = Lathe.fromProfile(Glassware.graduatedCylinder10());
  assertTrue('画布变高就画得更大(高度是主约束)',
    LathePainter.fitFor(cylinder, 132, 400).pxPerCm > LathePainter.fitFor(cylinder, 132, 252).pxPerCm,
    '定标没吃到多出来的高度');
  // 画布变窄时先降倍率、px/cm 不动;倍率降到 1 还不够才整体等比缩小。
  // 这条区分了「把圆压扁」和「把画小」:只允许后者。
  assertTrue('画布变窄先降可读性倍率',
    LathePainter.fitFor(cylinder, 90, 252).widthGain < LathePainter.fitFor(cylinder, 132, 252).widthGain,
    '倍率没让路');
  check('倍率让路时 px/cm 不变(纵向比例不受宽度影响)',
    LathePainter.fitFor(cylinder, 90, 252).pxPerCm,
    LathePainter.fitFor(cylinder, 132, 252).pxPerCm, 1e-12);
  check('倍率的下限是 1:真实比例容得下时不额外加宽',
    LathePainter.fitFor(cylinder, 12, 252).widthGain, 1, 1e-12);
  assertTrue('宽度不够到连真实比例都放不下时,px/cm 让路',
    LathePainter.fitFor(cylinder, 12, 252).pxPerCm < LathePainter.fitFor(cylinder, 132, 252).pxPerCm,
    '既不加宽也不缩小,器皿会画出界');
  const dishLathe = Lathe.fromProfile(dish);
  assertTrue('真实比例也放不下时整体等比缩小',
    LathePainter.fitFor(dishLathe, 40, 252).pxPerCm < LathePainter.fitFor(dishLathe, 132, 252).pxPerCm,
    '宽度不够时改的是倍率而不是比例');
  assertTrue('细量筒确实动用了可读性放大',
    LathePainter.fitFor(cylinder, 132, 252).widthGain > 3, '增益没生效,画出来会是一根线');

  // 均匀加宽:同一俯角下口沿与器底的宽度比,必须严格等于它们的真实半径比
  const cup = Lathe.fromProfile(Glassware.beaker100());
  const cupCam = LathePainter.fitFor(cup, 132, 252);
  const total = cup.totalHeight();
  check('加宽后口底宽度比仍等于真实半径比',
    cupCam.halfWidth(cup.radiusAt(total)) / cupCam.halfWidth(cup.radiusAt(0)),
    cup.radiusAt(total) / cup.radiusAt(0), 1e-12);
  const trueCam = new Camera();
  trueCam.elevationDeg = LathePainter.ELEVATION_DEG;
  trueCam.pxPerCm = cupCam.pxPerCm;
  trueCam.baseY = cupCam.baseY;
  check('加宽不改变高度方向的投影(纵横同一个 px/cm)',
    cupCam.screenY(total), trueCam.screenY(total), 1e-12);
  check('俯角是定下来的教学值', cupCam.elevationDeg, LathePainter.ELEVATION_DEG, 1e-12);

  // --- 接线切片 3:倾斜时俯角改、投影不退化、液面曲线两端正好接在左右母线上 ---
  {
    const { TiltedPlane } = require(join(OUT, 'view3d/TiltedPlane.cjs'));
    const tiltProfile = Glassware.beaker100();
    const tiltLathe = Lathe.fromProfile(tiltProfile);
    check('不倾时第 4 参与旧签名逐位相同',
      LathePainter.fitFor(tiltLathe, 132, 252, 0).pxPerCm, cupCam.pxPerCm, 1e-12);
    check('倾 20° 后俯角就是 θ+α(器身照旧走回转体那套)',
      LathePainter.fitFor(tiltLathe, 132, 252, 20).elevationDeg,
      LathePainter.ELEVATION_DEG + 20, 1e-12);
    const extremeUp = LathePainter.fitFor(tiltLathe, 132, 252, -90);
    const extremeDown = LathePainter.fitFor(tiltLathe, 132, 252, 90);
    assertTrue('反向到底时椭圆没塌成一条线', extremeUp.flatten() > 0.05,
      `扁率 ${extremeUp.flatten()}`);
    assertTrue('正向到底时瓶口几乎正对观察者(近圆),而不是停住不动',
      extremeDown.flatten() > 0.9, `扁率 ${extremeDown.flatten()}`);
    assertTrue('夹过之后高度方向仍是压缩而不是翻面',
      extremeUp.heightScale() >= 0 && extremeDown.heightScale() >= 0,
      `实得 ${extremeUp.heightScale()} / ${extremeDown.heightScale()}`);

    // 填充路径要闭合:液面曲线在左右切点(φ=±90)处必须落在**同一个高度**上,
    // 且那个高度就是自由面过轴线那一点 —— 否则填色多缝一条,液面看上去断开。
    for (const tilt of [-16, -5, 5, 20, 45, 60]) {
      const zt = TiltedPlane.planeForVolume(tiltProfile, tilt, 45);
      const left = TiltedPlane.surfacePoint(tiltProfile, tilt, zt, 90);
      const right = TiltedPlane.surfacePoint(tiltProfile, tilt, zt, 270);
      check(`倾 ${tilt}° 左右切点同高(左)`, left.hCm, zt / Math.cos(tilt * Math.PI / 180), 1e-9);
      check(`倾 ${tilt}° 左右切点同高(右)`, right.hCm, zt / Math.cos(tilt * Math.PI / 180), 1e-9);
      check(`倾 ${tilt}° 左右切点高度相等`, left.hCm, right.hCm, 1e-9);
    }

    // 屏幕上的横向范围不许超过器身最宽处:液面只能在玻璃里面
    for (const tilt of [0, 20, 45]) {
      const cam3 = LathePainter.fitFor(tiltLathe, 132, 252, tilt);
      const z3 = TiltedPlane.planeForVolume(tiltProfile, tilt, 45);
      // 器身最宽处直接由剖面算,不去碰绘制器的私有成员
      let rMax3 = 0;
      for (const a of tiltProfile.areas) {
        const rr = Math.sqrt(a / Math.PI);
        if (rr > rMax3) {
          rMax3 = rr;
        }
      }
      const widest = Math.max(1, cam3.halfWidth(rMax3));
      let inBody = true;
      for (let phi = 0; phi < 360; phi += 5) {
        const sp3 = TiltedPlane.surfacePoint(tiltProfile, tilt, z3, phi);
        const p3 = cam3.ring(sp3.hCm, sp3.radiusCm).pointAt(phi);
        if (Math.abs(p3.x - cam3.centerX) > widest + 1e-6) {
          inBody = false;
        }
      }
      assertTrue(`倾 ${tilt}° 液面曲线横向不出器身`, inBody, '画到玻璃外面去了');
    }
  }
  assertTrue('俯角看得见水面(椭圆有可辨高度)', cupCam.flatten() >= 0.3,
    `扁率 ${cupCam.flatten().toFixed(3)} 太小,口沿会看成一条线`);
  assertTrue('俯角没把器身压掉一半', cupCam.heightScale() >= 0.8,
    `高度剩 ${cupCam.heightScale().toFixed(3)}`);

  // --- LathePainter.ticksFor:刻度必须是人的数 ---
  const NICE = [0.1, 0.2, 0.25, 0.5, 1, 2, 2.5, 5, 10, 20, 25, 50, 100];
  const capOf = (p) => p.capacity();
  check('量筒分度 0.5 mL、20 格', LathePainter.ticksFor(capOf(cyl)).step, 0.5, 1e-12);
  check('量筒小格数', LathePainter.ticksFor(capOf(cyl)).minors, 20, 1e-12);
  check('量筒每 4 格一标', LathePainter.ticksFor(capOf(cyl)).majorStride, 4, 1e-12);
  check('量筒标签不写假小数(2 不写成 2.0)',
    LathePainter.ticksFor(capOf(cyl)).decimals, 0, 1e-12);
  check('烧杯分度 10 mL', LathePainter.ticksFor(capOf(beaker)).step, 10, 1e-12);
  check('蒸发皿分度 10 mL', LathePainter.ticksFor(capOf(dish)).step, 10, 1e-12);
  check('漏斗筒分度 2 mL', LathePainter.ticksFor(capOf(Glassware.funnelStem())).step, 2, 1e-12);
  // 脏量程:积分出来的容积不是整数(烧杯实为 101.5),分度仍要落在候选表上而不是 5.07
  for (const [name, ware] of wares) {
    const plan = LathePainter.ticksFor(capOf(ware));
    assertTrue(`${name} 的分度落在量具候选表上`, NICE.indexOf(plan.step) >= 0,
      `分度 ${plan.step}`);
    assertTrue(`${name} 的格数读得动(8 到 24 格)`, plan.minors >= 8 && plan.minors <= 24,
      `${plan.minors} 格`);
    assertTrue(`${name} 最上面的标签不超出量程`,
      plan.step * plan.minors <= capOf(ware) + 1e-9 &&
      plan.step * (plan.minors + 1) > capOf(ware),
      `末格 ${plan.step * plan.minors} vs 量程 ${capOf(ware)}`);
    assertTrue(`${name} 的标签小数位够用`,
      Math.abs(plan.step * plan.majorStride * Math.pow(10, plan.decimals)
        - Math.round(plan.step * plan.majorStride * Math.pow(10, plan.decimals))) < 1e-9,
      `${plan.decimals} 位仍写不精确`);
  }
  check('量程为零不画刻度', LathePainter.ticksFor(0).minors, 0, 1e-12);
  check('非有限量程不画刻度', LathePainter.ticksFor(Number.NaN).minors, 0, 1e-12);
  assertTrue('量程极大时分度封顶在候选表内',
    NICE.indexOf(LathePainter.ticksFor(5000).step) >= 0, '溢出候选表');

  // --- LathePainter.tone:手拼的十六进制颜色,拼错就静默不画 ---
  const HEX = /^#[0-9A-F]{6}$/;
  const sumOf = (c) => {
    let s = 0;
    for (const at of [1, 3, 5]) {
      s += Number.parseInt(c.substring(at, at + 2), 16);
    }
    return s;
  };
  for (const b of [-1, 0, 0.25, 0.5, 0.75, 1, 1.5]) {
    assertTrue(`亮度 ${b} 拼出合法颜色`, HEX.test(LathePainter.tone('#7FB3E8', b)),
      LathePainter.tone('#7FB3E8', b));
  }
  checkText('字节小于 16 时补零', LathePainter.tone('#050607', 0).substring(1, 3), '03');
  assertTrue('暗部整体比高光暗',
    sumOf(LathePainter.tone('#7FB3E8', 0)) < sumOf(LathePainter.tone('#7FB3E8', 1)),
    '明暗方向反了');
  check('纯白在高光处溢出封顶,不超过 255',
    sumOf(LathePainter.tone('#FFFFFF', 2)), 765, 1e-12);
  assertTrue('中间亮度按序变亮', (() => {
    let prev = -1;
    for (const b of [0, 0.2, 0.4, 0.6, 0.8, 1]) {
      const s = sumOf(LathePainter.tone('#7FB3E8', b));
      if (s <= prev) {
        return false;
      }
      prev = s;
    }
    return true;
  })(), '渐变带出现了回头');

  // --- GlassShapes:器材种类 → 几何。M4 起这张表住在 bench/,两侧共用 ---
  const { GlassShapes } = require(join(OUT, 'geometry/GlassShapes.cjs'));
  const { VesselKind } = require(join(OUT, 'chemistry/BenchModel.cjs'));
  assertTrue('试管比锥形瓶细',
    GlassShapes.of(VesselKind.TUBE).radiusAt(5) < GlassShapes.of(VesselKind.FLASK).radiusAt(1),
    '形状映射串了');
  assertTrue('烧杯比试管矮',
    GlassShapes.of(VesselKind.BEAKER).totalHeight() < GlassShapes.of(VesselKind.TUBE).totalHeight(),
    '形状映射串了');
  assertTrue('同类容器取回同一份剖面(不每次重建分段表)',
    GlassShapes.of(VesselKind.FLASK) === GlassShapes.of(VesselKind.FLASK), '缓存没生效');
  // 份制容器只借形状不借容积:半管液体在三种容器里的高度必须不同
  const halfTube = GlassShapes.of(VesselKind.TUBE);
  const halfFlask = GlassShapes.of(VesselKind.FLASK);
  assertTrue('同样装一半,锥形瓶的液面相对更矮(下部粗)',
    halfFlask.heightForVolume(halfFlask.capacity() / 2) / halfFlask.totalHeight() <
    halfTube.heightForVolume(halfTube.capacity() / 2) / halfTube.totalHeight(),
    '形状没参与液面换算,画出来会三台一样高');
}

// ---- 系统能力白名单 --------------------------------------------------------
// 「离线」是产品承诺而不是实现细节,而它会被一次 import 悄悄推翻。
// 这条断言让加网络/账号能力必须经过这里,即必须被显式决定过一次。
{
  const { readdirSync, statSync } = require('node:fs');
  // 2026-10-12 放宽一次并留原因:内容更新通道要读沙箱与 rawfile 里的 JSON,
  // 解码 UTF-8 字节需要 @kit.ArkTS 的 util.TextDecoder。仍然没有任何网络与账号能力。
  const KIT_WHITELIST = ['@kit.AbilityKit', '@kit.ArkData', '@kit.ArkGraphics2D', '@kit.ArkTS',
    '@kit.ArkUI', '@kit.CoreFileKit', '@kit.PerformanceAnalysisKit'];
  const FORBIDDEN = ['@kit.NetworkKit', '@kit.AccountKit', '@kit.DistributedDataServiceKit',
    '@kit.CryptoArchitectureKit', '@kit.RemoteCommunicationKit'];

  function scan(dir, acc = []) {
    for (const name of readdirSync(dir)) {
      const p = join(dir, name);
      if (statSync(p).isDirectory()) scan(p, acc);
      else if (name.endsWith('.ets')) acc.push(p);
    }
    return acc;
  }

  const used = new Set();
  for (const file of scan(SRC)) {
    for (const m of readFileSync(file, 'utf8').matchAll(/from '(@kit\.[A-Za-z0-9]+)'/g)) {
      used.add(m[1]);
    }
  }
  const sortedUsed = [...used].sort().join(',');
  const sortedWhite = [...KIT_WHITELIST].sort().join(',');
  checkText('系统能力面等于白名单', sortedUsed, sortedWhite);
  for (const banned of FORBIDDEN) {
    assertTrue(`${banned} 未被引入`, !used.has(banned), '离线/无账号承诺被推翻,需先显式决定');
  }
}

// ---- 字号必须来自 Layout 的角色访问器 --------------------------------------
// 内联 `DeviceClass.LARGE ? a : b` 有两个毛病:同一级文字在 18 种组合里各写一遍,
// 而且它只有两档 —— 平板会静悄悄拿到手机值,和 Layout 里的三档访问器对不上。
// 裸数字更糟:大屏上完全不放大,教师机前排都看不清。这条把两种写法都拦在源码层。
{
  const { readdirSync, statSync, readFileSync } = require('node:fs');
  const DIRS = ['pages', 'view', 'view3d'];
  const offenders = [];

  function walkForFont(dir) {
    for (const name of readdirSync(dir)) {
      const p = join(dir, name);
      if (statSync(p).isDirectory()) {
        walkForFont(p);
      } else if (name.endsWith('.ets')) {
        const lines = readFileSync(p, 'utf8').split('\n');
        for (let i = 0; i < lines.length; i++) {
          const m = /\.fontSize\((.*)/.exec(lines[i]);
          if (m === null) {
            continue;
          }
          const arg = m[1];
          if (arg.indexOf('DeviceClass') >= 0 || /^[0-9]/.test(arg.trim())) {
            offenders.push(`${p}:${i + 1} → ${arg.trim().slice(0, 46)}`);
          }
        }
      }
    }
  }

  const etsRoot = join(SRC);
  for (const dir of DIRS) {
    walkForFont(join(etsRoot, dir));
  }
  assertTrue('页面与视图层不存在内联字号(必须走 Layout 角色访问器)',
    offenders.length === 0, `${offenders.length} 处:\n    ${offenders.join('\n    ')}`);

  // 角色阶本身:三档必须单调不减,且都在可读区间内
  const { Layout, DeviceClass } = require(join(OUT, 'common/Layout.cjs'));
  const roles = ['displaySize', 'readoutSize', 'pageTitleSize', 'sectionSize', 'bodySize',
    'labelSize', 'captionSize', 'cardTitleSize', 'microSize', 'bubbleSize'];
  const classes = [DeviceClass.PHONE, DeviceClass.PAD, DeviceClass.LARGE];
  for (const role of roles) {
    if (typeof Layout[role] !== 'function') {
      assertTrue(`角色 ${role} 存在`, false, 'Layout 里没有这个访问器');
      continue;
    }
    const steps = classes.map((c) => Layout[role](c));
    assertTrue(`${role} 三档单调不减`, steps[0] <= steps[1] && steps[1] <= steps[2],
      `${role} = ${steps.join('/')}`);
    assertTrue(`${role} 落在可读区间 10..46`, steps[0] >= 10 && steps[2] <= 46,
      `${role} = ${steps.join('/')}`);
    assertTrue(`${role} 三档不全等(否则不需要分设备)`,
      !(steps[0] === steps[1] && steps[1] === steps[2]), `${role} = ${steps[0]}`);
  }
  const missing = roles.filter((r) => typeof Layout[r] !== 'function');
  if (missing.length === 0) {
    check('display 是最大的一档', Layout.displaySize(DeviceClass.LARGE), 46, 1e-12);
    check('micro 是最小的一档', Layout.microSize(DeviceClass.PHONE), 10, 1e-12);
    // 角色之间必须真的分层:相邻角色不能撞成同一个数
    const phoneLadder = roles.filter((r) => r !== 'bubbleSize').map((r) => Layout[r](DeviceClass.PHONE));
    assertTrue('phone 档各角色互不重复', new Set(phoneLadder).size >= 7,
      `只有 ${new Set(phoneLadder).size} 个不同值:${phoneLadder.join(',')}`);
  }
}

// ---- 设备档位只能问 Layout,页面里不许自己比较 --------------------------------
// 承接上一条:字号收敛完之后,剩下的 `this.cls() === DeviceClass.X ? a : b` 全是
// 控件尺寸。两档三元对 PAD 的处理是错的(平板拿手机值),所以整类写法都要拦掉。
{
  const { readdirSync, statSync, readFileSync, existsSync } = require('node:fs');
  const tierUsers = [];

  function walkForTier(dir) {
    if (!existsSync(dir)) {
      return;
    }
    for (const name of readdirSync(dir)) {
      const p = join(dir, name);
      if (statSync(p).isDirectory()) {
        walkForTier(p);
      } else if (name.endsWith('.ets')) {
        const lines = readFileSync(p, 'utf8').split('\n');
        for (let i = 0; i < lines.length; i++) {
          const line = lines[i];
          if (/^\s*(\/\/|\*|\/\*)/.test(line)) {
            continue;
          }
          if (/===\s*DeviceClass\.|!==\s*DeviceClass\./.test(line)) {
            tierUsers.push(`${p}:${i + 1} → ${line.trim().slice(0, 60)}`);
          }
        }
      }
    }
  }

  for (const dir of ['pages', 'view', 'view3d']) {
    walkForTier(join(SRC, dir));
  }
  assertTrue('页面与视图层不直接比较设备档位(必须走 Layout 访问器或 isStacked)',
    tierUsers.length === 0, `${tierUsers.length} 处:\n    ${tierUsers.join('\n    ')}`);

  const { Layout, DeviceClass } = require(join(OUT, 'common/Layout.cjs'));
  const classes = [DeviceClass.PHONE, DeviceClass.PAD, DeviceClass.LARGE];
  const controls = ['gaugeWidth', 'gaugeHeight', 'vesselCardWidth', 'vesselCardHeight',
    'toggleWidth', 'toggleHeight', 'buttonHeight', 'shelfMaxHeight', 'chartHeight', 'minSceneHeight', 'panelWidth'];
  for (const name of controls) {
    if (typeof Layout[name] !== 'function') {
      assertTrue(`控件尺寸 ${name} 存在`, false, 'Layout 里没有这个访问器');
      continue;
    }
    const steps = classes.map((c) => Layout[name](c));
    assertTrue(`${name} 三档单调不减`, steps[0] <= steps[1] && steps[1] <= steps[2],
      `${name} = ${steps.join('/')}`);
    assertTrue(`${name} 三档分设备`, !(steps[0] === steps[2]), `${name} 恒为 ${steps[0]}`);
  }
  // 按钮必须点得中,开关的滑轨必须是横的
  for (const c of classes) {
    assertTrue(`${c} 按钮高度不低于触控下限`, Layout.buttonHeight(c) >= Layout.touchMin(c),
      `${Layout.buttonHeight(c)} < ${Layout.touchMin(c)}`);
    assertTrue(`${c} 开关宽大于高`, Layout.toggleWidth(c) > Layout.toggleHeight(c),
      `${Layout.toggleWidth(c)} x ${Layout.toggleHeight(c)}`);
  }
}

// ---- 圆角必须来自角色,或由自身尺寸推导 --------------------------------------
// 阶梯 [4,8,12,16,24] 已经存在,但页面里同一角色在用三个不同值:动作按钮 9 / 10 / 10,
// 卡片 12 / 14。这不是"数字不好看",是同屏两张卡片的圆角差 2vp 却说不清为什么。
// 允许两种来源:Layout 的圆角访问器,或 `尺寸 / 2` 的推导(正方点、细长刻度线本就该是胶囊)。
{
  const { readdirSync, statSync, readFileSync, existsSync } = require('node:fs');
  const radii = [];

  function walkForRadius(dir) {
    if (!existsSync(dir)) {
      return;
    }
    for (const name of readdirSync(dir)) {
      const p = join(dir, name);
      if (statSync(p).isDirectory()) {
        walkForRadius(p);
      } else if (name.endsWith('.ets')) {
        const lines = readFileSync(p, 'utf8').split('\n');
        for (let i = 0; i < lines.length; i++) {
          const m = /\.borderRadius\(([^)]*)\)/.exec(lines[i]);
          if (m === null) {
            continue;
          }
          const arg = m[1].trim();
          const derived = /\/\s*2\s*$/.test(arg) && arg.indexOf('Layout.') === 0;
          const fromToken = /^Layout\.[a-zA-Z]+\(/.test(arg);
          if (!derived && !fromToken) {
            radii.push(`${p}:${i + 1} → ${arg}`);
          }
        }
      }
    }
  }

  for (const dir of ['pages', 'view', 'view3d']) {
    walkForRadius(join(SRC, dir));
  }
  assertTrue('页面与视图层的圆角来自 Layout 角色或由尺寸推导',
    radii.length === 0, `${radii.length} 处:\n    ${radii.join('\n    ')}`);

  const { Layout, DeviceClass } = require(join(OUT, 'common/Layout.cjs'));
  const classes = [DeviceClass.PHONE, DeviceClass.PAD, DeviceClass.LARGE];
  if (typeof Layout.controlRadius !== 'function') {
    assertTrue('Layout.controlRadius 存在', false, '控件圆角还没有角色访问器');
  } else {
    for (const c of classes) {
      // 卡片比控件大,圆角不该比控件更锐
      assertTrue(`${c} 卡片圆角不小于控件圆角`, Layout.cardRadius(c) >= Layout.controlRadius(c),
        `card ${Layout.cardRadius(c)} < control ${Layout.controlRadius(c)}`);
      assertTrue(`${c} 控件圆角落在阶梯上`, Layout.onRadius(Layout.controlRadius(c)) === true,
        `${Layout.controlRadius(c)} 不在 ${Layout.RADII.join(',')}`);
    }
    const ctrl = classes.map((c) => Layout.controlRadius(c));
    assertTrue('控件圆角三档单调不减', ctrl[0] <= ctrl[1] && ctrl[1] <= ctrl[2], ctrl.join('/'));
  }

  // 单参 padding 只有两种归属:卡片内边距、页面容器内边距。两者都已有角色访问器,
  // 所以不该再有裸数字。对象式 padding 不在这条里 —— 控件内部留白随控件尺寸变,
  // 一个 24vp 的标签和一个 44vp 的按钮本来就不该同一个值。
  const pads = [];
  function walkForPadding(dir) {
    if (!existsSync(dir)) {
      return;
    }
    for (const name of readdirSync(dir)) {
      const p = join(dir, name);
      if (statSync(p).isDirectory()) {
        walkForPadding(p);
      } else if (name.endsWith('.ets')) {
        const lines = readFileSync(p, 'utf8').split('\n');
        for (let i = 0; i < lines.length; i++) {
          const m = /\.padding\(([0-9.]+)\)/.exec(lines[i]);
          if (m !== null) {
            pads.push(`${p}:${i + 1} → ${m[1]}`);
          }
        }
      }
    }
  }

  for (const dir of ['pages', 'view', 'view3d']) {
    walkForPadding(join(SRC, dir));
  }
  assertTrue('页面与视图层的单参内边距来自 Layout 角色',
    pads.length === 0, `${pads.length} 处:\n    ${pads.join('\n    ')}`);
}

// ---- 倾斜液面 --------------------------------------------------------------
// 器身绕屏幕横轴倾 α 之后,器内的自由面就不再是「等高面」,而是世界水平面斜切回转体。
// 推导(下面每条断言都落在这两式上):器坐标 (h, ρ, φ) 倾 α 后
//   世界高度 Y = h·cosα − ρ·cosφ·sinα
//   投影 screenY = −h·cos(θ+α) + ρ·cosφ·sin(θ+α)
// 第二式说明器身照旧按俯角 θ+α 走回转体那套,一个数都不用改;只有液面要按斜平面重算。
// 「双 canvas 合成」之所以成立就是因为这一点,所以先把液面的算法单独钉死。
{
  const modPath = join(SRC, 'view3d', 'TiltedPlane.ets');
  assertTrue('倾斜液面几何模块已建立', existsSync(modPath), `缺 ${modPath}`);
  if (existsSync(modPath)) {
    const { Profile, Glassware } = require(join(OUT, 'geometry/Profile.cjs'));
    const { TiltedPlane } = require(join(OUT, 'view3d/TiltedPlane.cjs'));
    const DEG = Math.PI / 180;

    /** 等截面直筒,但分段可比 Glassware 更细 —— 收敛性要用。segH 不给就当场炸,不要生成空剖面 */
    function cyl(area, height, segH) {
      if (!(segH > 0)) {
        throw new Error(`cyl() 必须给分段高度,实得 ${segH}`);
      }
      const areas = [];
      const count = Math.round(height / segH);
      for (let i = 0; i < count; i++) {
        areas.push(area);
      }
      return Profile.of(areas, segH);
    }

    // 1) 圆缺面积:六个能手算的点
    check('圆缺:割线过球心取半圆', TiltedPlane.segmentArea(2, 0), 2 * Math.PI, 1e-9);
    check('圆缺:割线与近侧相切时无液', TiltedPlane.segmentArea(2, 2), 0, 1e-12);
    check('圆缺:割线与远侧相切时整盘', TiltedPlane.segmentArea(2, -2), 4 * Math.PI, 1e-9);
    check('圆缺:割线跑出盘外按空盘', TiltedPlane.segmentArea(2, 5), 0, 1e-12);
    check('圆缺:割线远于球心按整盘', TiltedPlane.segmentArea(2, -5), 4 * Math.PI, 1e-9);
    check('圆缺:零半径盘面积为 0', TiltedPlane.segmentArea(0, 0), 0, 1e-12);
    check('圆缺:负半径按 0 处理', TiltedPlane.segmentArea(-1, 0), 0, 1e-12);
    let segPrev = Infinity;
    let segMonotone = true;
    for (let d = -2; d <= 2.0001; d += 0.25) {
      const a = TiltedPlane.segmentArea(2, d);
      if (!Number.isFinite(a) || a > segPrev + 1e-12) {
        segMonotone = false;
      }
      segPrev = a;
    }
    assertTrue('圆缺面积随割线离开近侧单调不增', segMonotone, '在 r=2 的扫掠里出现回升');

    // 1b) 非退化点的闭式对照 + 独立数值积分。
    //     上面五个点全是退化位置(d=0 时第二项本身就是 0),符号写反的公式在那里也对,
    //     所以必须拿能手算的非退化点和一条独立的积分曲线来钉。
    check('圆缺:d=r/2 时等于 4π/3−√3(r=2)',
      TiltedPlane.segmentArea(2, 1), 4 * Math.PI / 3 - Math.sqrt(3), 1e-12);
    function segmentByQuadrature(r, d) {
      const steps = 200000;
      const dx = (r - d) / steps;
      let sum = 0;
      for (let k = 0; k < steps; k++) {
        const x = d + (k + 0.5) * dx;
        sum += 2 * Math.sqrt(Math.max(0, r * r - x * x));
      }
      return sum * dx;
    }
    for (const d of [-1.3, -0.6, 0, 0.7, 1.6]) {
      check(`圆缺:d=${d} 与独立积分一致`,
        TiltedPlane.segmentArea(2, d), segmentByQuadrature(2, d), 1e-5);
    }
    let compOk = true;
    for (const d of [-1.9, -1, 0, 1, 1.9]) {
      if (Math.abs(TiltedPlane.segmentArea(2, d) + TiltedPlane.segmentArea(2, -d) - 4 * Math.PI) > 1e-9) {
        compOk = false;
      }
    }
    assertTrue('圆缺:割线两侧的两块合起来是整盘', compOk, 'A(r,d)+A(r,−d) ≠ πr²,公式的第二项符号可疑');

    // 2) 倾角为 0 必须精确退回 Profile 现有的等高面算法(两个方向都退)
    const beaker = Glassware.beaker100();
    for (const h of [0, 1.234, 3.5, 6.9, 7]) {
      check(`0° 自由面的容积与 Profile.volumeBelow 同值 h=${h}`,
        TiltedPlane.volumeBelowPlane(beaker, 0, h), beaker.volumeBelow(h), 1e-12);
    }
    for (const v of [0, 20, 55.5, beaker.capacity()]) {
      check(`0° 由容积解出的高度与 Profile.heightForVolume 同值 V=${v}`,
        TiltedPlane.planeForVolume(beaker, 0, v), beaker.heightForVolume(v), 1e-9);
    }

    // 2b) 从平放到「刚倾一点点」不许跳变。差别的下界是 Profile 自己的 0.1 cm 分段:
    //     α→0⁺ 时压在段界上的那张盘面被斜平面平分,而 heightForVolume 的线性插值不计它,
    //     所以解出的自由面最多错开一整段。超过一段就是真跳变(动画里是一次闪烁);
    //     拆掉 α=0 特判会得到 0/0 = NaN,这里也当场抓得住。
    for (const v of [20, 55.5, 90]) {
      const zFlat = TiltedPlane.planeForVolume(beaker, 0, v);
      const zSlight = TiltedPlane.planeForVolume(beaker, 0.0001, v);
      assertTrue(`V=${v} 起倾瞬间自由面不错开超过一段`,
        Number.isFinite(zSlight) && Math.abs(zSlight - zFlat) <= beaker.segHeight,
        `平放 ${zFlat.toFixed(4)} → 微倾 ${zSlight}`);
    }

    // 3) 满与空不随倾角改变 —— 这一组与离散精度无关,是算法和 Profile 的接缝
    for (const tilt of [0, 12, 30, 45, 60, 75]) {
      const zHigh = beaker.totalHeight() / Math.cos(tilt * DEG) + 40;
      check(`${tilt}° 自由面高过器顶时容积即满量程`,
        TiltedPlane.volumeBelowPlane(beaker, tilt, zHigh), beaker.capacity(), 1e-9);
      check(`${tilt}° 自由面低于器内最低点时容积为 0`,
        TiltedPlane.volumeBelowPlane(beaker, tilt, -80), 0, 1e-12);
    }

    // 4) 守恒往返:先定体积解自由面,再按该面读回体积,必须等于原值(I1 在倾斜下的对应物)
    const vessels = [Glassware.beaker100(), Glassware.testTube(), Glassware.conicalFlask()];
    const vesselNames = ['烧杯', '试管', '锥形瓶'];
    for (let vi = 0; vi < vessels.length; vi++) {
      const p = vessels[vi];
      for (const tilt of [0, 5, 10, 15, 20, 25, 30, 35, 40, 45]) {
        for (const v of [10, Math.round(p.capacity() * 0.4), Math.round(p.capacity() * 0.8)]) {
          const z = TiltedPlane.planeForVolume(p, tilt, v);
          assertTrue(`${vesselNames[vi]} ${tilt}° V=${v} 解出的自由面是有限数`,
            Number.isFinite(z), `实得 ${z}`);
          check(`${vesselNames[vi]} ${tilt}° 往返后容积不变`,
            TiltedPlane.volumeBelowPlane(p, tilt, z), v, 1e-6);
        }
      }
    }

    // 4b) 要求超出量程时夹到满量程,而不是解出一个不存在的自由面。
    //     「多出来的液体去哪」是世界层的守恒账,渲染层只保证自己不画出不存在的液面。
    const tube = Glassware.testTube();
    check('试管要 40 mL(超过它的 37.4 mL 量程)时解出的面刚好满',
      TiltedPlane.volumeBelowPlane(tube, 0, TiltedPlane.planeForVolume(tube, 0, 40)),
      tube.capacity(), 1e-9);
    check('试管 30° 时同样夹到满量程',
      TiltedPlane.volumeBelowPlane(tube, 30, TiltedPlane.planeForVolume(tube, 30, 40)),
      tube.capacity(), 1e-6);
    check('要负体积时解出的面刚好全空',
      TiltedPlane.volumeBelowPlane(beaker, 20, TiltedPlane.planeForVolume(beaker, 20, -5)),
      0, 1e-12);

    // 5) 固定倾角下容积随自由面单调不减 —— 二分法成立的前提
    let monoPrev = -1;
    let mono = true;
    for (let z = -10; z <= 20.0001; z += 0.5) {
      const v = TiltedPlane.volumeBelowPlane(beaker, 25, z);
      if (!Number.isFinite(v) || v < monoPrev - 1e-9) {
        mono = false;
      }
      monoPrev = v;
    }
    assertTrue('25° 时容积随自由面升高单调不减', mono, '出现回落,二分求解的前提不成立');

    // 6) 解析对照 + 离散收敛:足够高的直筒、倾角 20° 时自由面既不碰底也不漫口,
    //    此时 ∫∫ρcosφ dA 在圆盘上为零,连续情形下 Z = h0·cosα、且自由面恒过轴线读数位 h0。
    const h0 = 5;
    const analytic = h0 * Math.cos(20 * DEG);
    const errs = [];
    for (const segH of [0.1, 0.02, 0.004]) {
      const z = TiltedPlane.planeForVolume(cyl(10, 20, segH), 20, 50);
      errs.push(Math.abs(z - analytic));
    }
    assertTrue('直筒 20° 的自由面误差随分段变细而缩小',
      errs[0] > errs[1] && errs[1] > errs[2], `误差 ${errs.map((e) => e.toExponential(2)).join(' → ')}`);
    check('直筒 20° 自由面高度收敛到解析值 h0·cosα',
      TiltedPlane.planeForVolume(cyl(10, 20, 0.004), 20, 50), analytic, 0.02);
    check('自由面过轴线的读数位不随倾角改变(Z/cosα = h0)',
      TiltedPlane.planeForVolume(cyl(10, 20, 0.004), 20, 50) / Math.cos(20 * DEG), h0, 0.02);
    check('朝观察者倾与背离倾在未削切区解出同一自由面',
      TiltedPlane.planeForVolume(cyl(10, 20, 0.02), -20, 50), analytic, 0.05);

    // 7) 极端输入不许产生 NaN/Inf:渲染器拿不到数就是整屏空白
    for (const tilt of [0, 1, 45, 80, 89, -89]) {
      for (const v of [0, 5, 50, beaker.capacity()]) {
        const z = TiltedPlane.planeForVolume(beaker, tilt, v);
        assertTrue(`${tilt}° V=${v} 求解不产生 NaN/Inf`, Number.isFinite(z), `实得 ${z}`);
      }
    }
    // ---- 切片 2:液面边界的画法 ------------------------------------------------
    // 9) 0° 时边界点必须正好落在现有绘制器画的那个圆环上 —— 接线不许改变平放的样子。
    //    平放是现状唯一被设备验过的形态,这条是接线的回归闸门。
    const bodies = [cyl(4 * Math.PI, 20, 0.1), Glassware.beaker100(),
      Glassware.testTube(), Glassware.conicalFlask()];
    const bodyNames = ['直筒R2', '烧杯', '试管', '锥形瓶'];
    // 前置:每张剖面都得是个真容器。空剖面的 totalHeight 是 NaN,而 `z > NaN` 恒假,
    // 下面的 continue 会静默跳过全部用例 —— 这条断言就是堵这个的。
    for (let bi = 0; bi < bodies.length; bi++) {
      assertTrue(`${bodyNames[bi]} 是一张有效剖面`,
        bodies[bi].areas.length > 0 && bodies[bi].capacity() > 0,
        `分段 ${bodies[bi].areas.length}、容积 ${bodies[bi].capacity()}`);
    }
    for (let bi = 0; bi < bodies.length; bi++) {
      const p0 = bodies[bi];
      for (const z0 of [1.5, 3.02, 5]) {
        if (z0 > p0.totalHeight()) {
          continue;
        }
        for (const phi0 of [0, 45, 180, 300]) {
          const flat0 = TiltedPlane.surfacePoint(p0, 0, z0, phi0);
          check(`0° 边界点高度就是 Z ${bodyNames[bi]} φ=${phi0}`, flat0.hCm, z0, 1e-9);
          check(`0° 边界点半径就是该处的器壁半径 ${bodyNames[bi]} φ=${phi0}`,
            flat0.radiusCm, p0.radiusAt(z0), 1e-9);
        }
      }
    }
    // 8) 定义即判据:边界上每一个点的世界高度都等于 Z ——「液面保持水平」在代码里只有这一个意思。
    //    前提是这张平面够得到每一个方位角(高于底面最高那条器沿),这条前提也当场断言,
    //    免得用例悄悄退化成"什么都没测"。
    function worldY(hCm, radiusCm, tiltDeg, phiDeg) {
      return hCm * Math.cos(tiltDeg * DEG) -
        radiusCm * Math.cos(phiDeg * DEG) * Math.sin(tiltDeg * DEG);
    }
    for (let bj = 0; bj < bodies.length; bj++) {
      const pb = bodies[bj];
      for (const tilt of [0, 10, 25, 40, 55]) {
        // 适用区:平面与每一条母线都相交于器内 —— 既不从器底穿出,也不从器口漫出。
        // 用例按这个区间取中值构造,而不是猜一个充填比例:后者在 55° 的烧杯与锥形瓶上
        // 会分别落到「漫出口」和「穿出器底」两种真实形态里去(那两种另有专项用例)。
        const absSin = Math.abs(Math.sin(tilt * DEG));
        const zLow = pb.radiusAt(0) * absSin;
        const zHigh = pb.totalHeight() * Math.cos(tilt * DEG) - pb.radiusAt(pb.totalHeight()) * absSin;
        assertTrue(`${bodyNames[bj]} ${tilt}° 存在整条贴壁的区间`, zHigh > zLow, `区间 (${zLow}, ${zHigh})`);
        const zb = (zLow + zHigh) / 2;
        let flat = true;
        let inside = true;
        let highest = true;
        // 台阶界:器壁按 0.1 cm 分段取常量半径,段界上半径会跳,所以「最高湿润点」
        // 的世界高度与 Z 天生相差不到「一个台阶宽 × sinα」。这个上界由剖面自己算出来,不是我猜的。
        let maxStep = 0;
        for (let k = 1; k < pb.areas.length; k++) {
          const step = Math.abs(Math.sqrt(pb.areas[k] / Math.PI) - Math.sqrt(pb.areas[k - 1] / Math.PI));
          if (step > maxStep) {
            maxStep = step;
          }
        }
        const bound = maxStep * Math.abs(Math.sin(tilt * DEG)) + 1e-12;
        for (let phi = 0; phi < 360; phi += 10) {
          const pt = TiltedPlane.surfacePoint(pb, tilt, zb, phi);
          if (!Number.isFinite(pt.hCm) || !Number.isFinite(pt.radiusCm)) {
            flat = false;
            inside = false;
            highest = false;
            continue;
          }
          if (Math.abs(worldY(pt.hCm, pt.radiusCm, tilt, phi) - zb) > bound) {
            flat = false;
          }
          if (pt.hCm < -1e-9 || pt.hCm > pb.totalHeight() + 1e-9 ||
            pt.radiusCm < -1e-9 || pt.radiusCm > pb.radiusAt(pt.hCm) + 1e-9) {
            inside = false;
          }
          // 「最高」的精确定义:严格高于它的每一个整段都在平面之上。
          // 等号要归给它自己那一段:段界上的半径按 Profile 的约定属于上一段,
          // 把 k*seg === h* 也算成「其上」会把同一个点重复计入,判成假红。
          for (let k = 0; k < pb.areas.length; k++) {
            if (k * pb.segHeight <= pt.hCm + 1e-12) {
              continue;
            }
            const rk = Math.sqrt(Math.max(0, pb.areas[k]) / Math.PI);
            if (worldY(k * pb.segHeight, rk, tilt, phi) <= zb + 1e-12) {
              highest = false;
            }
          }
        }
        assertTrue(`${bodyNames[bj]} ${tilt}° 液面边界上的点共面(误差在一个台阶内)`, flat,
          `画出来液面是歪的,界=${bound.toFixed(5)}`);
        assertTrue(`${bodyNames[bj]} ${tilt}° 液面边界不出器身`, inside, '边界点跑到器壁外或器底以下');
        assertTrue(`${bodyNames[bj]} ${tilt}° 边界点是该母线上最高的湿润点`, highest,
          '其上仍有湿润点,画出来液面会低于真实液面');
      }
    }
    // 10) 液体积在近底一侧的形态:小体积 + 大倾角,自由面从器底穿出而不是从器壁。
    //     直筒 R=2、倾 45°、Z=1:远侧器沿(φ=180)的世界高度是 2·sin45°=1.414 > Z,
    //     那一支只能落在器底的弦上;近侧(φ=0)则沿器壁爬高。倾倒过程最常见的就是这一形态。
    const tubeless = cyl(4 * Math.PI, 20, 0.1);
    const shallow = TiltedPlane.surfacePoint(tubeless, 45, 1, 180);
    check('浅液远侧那支落在器底上(h=0)', shallow.hCm, 0, 1e-12);
    assertTrue('浅液远侧那支在器底盘内部而不是器沿',
      shallow.radiusCm > 0 && shallow.radiusCm < 2, `半径实得 ${shallow.radiusCm}`);
    check('浅液远侧那支仍在平面上', worldY(shallow.hCm, shallow.radiusCm, 45, 180), 1, 1e-9);
    const climbing = TiltedPlane.surfacePoint(tubeless, 45, 1, 0);
    assertTrue('浅液近侧沿器壁爬高(高于轴线上的交点)',
      climbing.hCm > 1 / Math.cos(45 * DEG),
      `近侧 ${climbing.hCm} 不高于轴上 ${1 / Math.cos(45 * DEG)}`);
    check('浅液近侧那支也仍在平面上', worldY(climbing.hCm, climbing.radiusCm, 45, 0), 1, 1e-9);
    // 11) 平面够不着的方位(Z 低于底心)与满到顶的极端都不许崩:
    //     夹回器内最近的点,仍然有限且不越界。画不画由体积决定,但不能拿到坏数。
    //     倾 90° 也列进来:此时 cosα=0,通用式里有一处除以 cosα 的分支,必须证明它取不到。
    for (const zt of [30, 90, -90]) {
      for (const zs of [-50, -1, 0, 25, 60, 200]) {
        let ok = true;
        for (let phi = 0; phi < 360; phi += 15) {
          const pt = TiltedPlane.surfacePoint(beaker, zt, zs, phi);
          if (!Number.isFinite(pt.hCm) || !Number.isFinite(pt.radiusCm) ||
            pt.hCm < -1e-9 || pt.hCm > beaker.totalHeight() + 1e-9 ||
            pt.radiusCm < -1e-9 || pt.radiusCm > beaker.radiusAt(pt.hCm) + 1e-9) {
            ok = false;
          }
        }
        assertTrue(`${zt}° Z=${zs} 无交点时边界点仍夹在器身内`, ok, '出现 NaN 或跑到器外');
      }
    }

    // 12) 两套算法互相校准:轴向切片积分(被测)与极坐标二重积分(独立写法)算同一个平面切出的体积。
    //     它们只共用「平面上」这个几何,共用不了代码。比的是收敛,不是等值 ——
    //     轴向积分是段底矩形规则,一阶收敛;把容差写成定值会把算法自己的粒度当成 bug。
    const tilt12 = 30;
    const z12 = 6;
    let polarSum = 0;
    const dr12 = 2 / 400;
    const dPhi12 = 2 * Math.PI / 720;
    const cos12 = Math.cos(tilt12 * DEG);
    const sin12 = Math.sin(tilt12 * DEG);
    for (let i = 0; i < 400; i++) {
      const rho = (i + 0.5) * dr12;
      for (let k = 0; k < 720; k++) {
        const phi = (k + 0.5) * dPhi12;
        const hWet = (z12 + rho * Math.cos(phi) * sin12) / cos12;
        polarSum += (hWet < 0 ? 0 : (hWet > 20 ? 20 : hWet)) * rho * dr12 * dPhi12;
      }
    }
    const axialFine = TiltedPlane.volumeBelowPlane(cyl(4 * Math.PI, 20, 0.01), tilt12, z12);
    const axialCoarse = TiltedPlane.volumeBelowPlane(cyl(4 * Math.PI, 20, 0.1), tilt12, z12);
    check('轴向切片(0.01 分段)与极坐标二重积分对上(直筒 30°)', axialFine, polarSum, 0.1);
    assertTrue('两套积分之差随分段变细而缩小一个量级',
      Math.abs(axialCoarse - polarSum) > 5 * Math.abs(axialFine - polarSum),
      `粗 ${Math.abs(axialCoarse - polarSum).toFixed(4)} vs 细 ${Math.abs(axialFine - polarSum).toFixed(4)}`);
  }
}

// ---- 切片 3 的绘制编排:让「只能靠眼睛验」的那一层也能被断言 ----------------------
// 记录型 ctx 抓下每一次落笔的坐标。这里能证的不是"好不好看",而是四件会悄悄坏掉的事:
// 路径闭合、不出画布、同输入同输出(不变量 I2 在渲染侧的对应物),以及倾斜时真的换成了切出来的折线。
{
  const { LathePainter, LatheSpec } = require(join(OUT, 'view3d/LathePainter.cjs'));
  const { Glassware } = require(join(OUT, 'geometry/Profile.cjs'));
  const W = 116;
  const H = 140;

  function record(tilt, volumeMl, profile, graduated) {
    const rec = makeRecorder(W, H);
    const spec = new LatheSpec();
    spec.profile = profile;
    spec.volumeMl = volumeMl;
    spec.tiltDeg = tilt;
    spec.graduated = graduated === true;
    LathePainter.draw(rec.ctx, spec);
    return rec;
  }

  const bottle = Glassware.beaker100();
  const countOf = (rec, prefix) => rec.calls.filter((c) => c.startsWith(prefix)).length;

  for (const tilt of [0, 20, 40, 60, 76, 90]) {
    const rec = record(tilt, 45, bottle, false);
    const emptyPaint = rec.paths.filter((p) => (p.filled || p.stroked) && p.ops === 0);
    assertTrue(`倾 ${tilt}° 没有空路径上的 fill/stroke`, emptyPaint.length === 0,
      `${emptyPaint.length} 次`);
    assertTrue(`倾 ${tilt}° 有实际落笔`, rec.points.length > 20, `只有 ${rec.points.length} 个点`);
    let out = 0;
    let bad = '';
    for (const p of rec.points) {
      if (!Number.isFinite(p[0]) || !Number.isFinite(p[1]) ||
        p[0] < -0.5 || p[0] > W + 0.5 || p[1] < -0.5 || p[1] > H + 0.5) {
        out++;
        if (bad === '') {
          bad = `${p[0].toFixed(2)},${p[1].toFixed(2)}`;
        }
      }
    }
    assertTrue(`倾 ${tilt}° 每一次落笔都在画布内`, out === 0, `${out} 点越界,首个 ${bad}`);

    const again = record(tilt, 45, bottle, false);
    assertTrue(`倾 ${tilt}° 同一份状态画出逐位相同的一笔(I2 也要管渲染)`,
      again.calls.join('|') === rec.calls.join('|'), '落笔序列随第二次调用发生变化');
  }

  // 倾斜时液面是切出来的多边形:认「折线够长 + 已闭合 + 填了又描边」那一条。
  // 只按「闭合长折线」认会被液体本体顶替满足(它就是闭合长折线),那样液面整条丢了也测不出来。
  const surfacePaths = (rec) => rec.paths.filter(
    (p) => p.lineTos >= 30 && p.closed && p.filled && p.stroked);
  const tippedRun = record(30, 45, bottle, false);
  assertTrue('倾斜时液面是一条闭合折线,填过又描边', surfacePaths(tippedRun).length === 1,
    `实得 ${surfacePaths(tippedRun).length} 条`);

  const flat = record(0, 45, bottle, false);
  assertTrue('平放时液面仍是原来那枚椭圆(没有多出折线液面)', surfacePaths(flat).length === 0,
    `实得 ${surfacePaths(flat).length} 条`);
  assertTrue('倾斜时液面改用切出来的折线(不再沿用正立那枚椭圆)',
    countOf(tippedRun, 'ellipse') < countOf(flat, 'ellipse'),
    `椭圆次数 平放 ${countOf(flat, 'ellipse')} vs 倾斜 ${countOf(tippedRun, 'ellipse')}`);
  assertTrue('倾斜时确实多落了一批构成液面曲线的点',
    countOf(tippedRun, 'lineTo') > countOf(flat, 'lineTo'),
    `lineTo 次数 平放 ${countOf(flat, 'lineTo')} vs 倾斜 ${countOf(tippedRun, 'lineTo')}`);

  // 空瓶不许画液面:同一倾角下,那条折线液面必须整个消失
  const empty = record(30, 0, bottle, false);
  assertTrue('空瓶不画液体', surfacePaths(empty).length === 0,
    `空瓶仍画出 ${surfacePaths(empty).length} 条液面折线`);
}

// ---- 课程地图的校验器 --------------------------------------------------------
{
  const { makeEntry, MapSubject, SchoolStage, Feasibility, UNVERIFIED_PREFIX } =
    require(join(OUT, 'content/map/CurriculumTypes.cjs'));
  const { MapValidator } = require(join(OUT, 'content/map/MapValidator.cjs'));

  function good(over) {
    const e = makeEntry('phy-u-001', MapSubject.PHYSICS, SchoolStage.UNIVERSITY,
      '大学物理实验·光学', '大二上', 0, '例题', ['器材一'], '一句话原理',
      '一句话数据处理', ['知识点'], Feasibility.NEEDS_MODEL, '某校实验中心项目表 http://x.example');
    for (const k of Object.keys(over)) {
      e[k] = over[k];
    }
    return e;
  }

  /** 负对照:每种违规各造一条,必须恰好报一条、且报在该字段上 */
  function expectOne(label, field, entry) {
    const problems = MapValidator.validate([entry]);
    assertTrue(`${label}:恰好报一条`, problems.length === 1,
      `实得 ${problems.length} 条:${problems.map((p) => p.field).join(',')}`);
    assertTrue(`${label}:报在 ${field} 字段上`,
      problems.length > 0 && problems[0].field === field,
      problems.map((p) => `${p.field}:${p.message}`).join(' | '));
  }

  expectOne('标题为空', 'title', good({ title: '' }));
  expectOne('课程为空', 'course', good({ course: '' }));
  expectOne('学期为空', 'term', good({ term: '' }));
  expectOne('出处为空', 'source', good({ source: '' }));
  expectOne('器材为空', 'apparatus', good({ apparatus: [] }));
  expectOne('知识点为空', 'knowledge', good({ knowledge: [] }));
  expectOne('课时为负', 'minutes', good({ minutes: -1 }));
  expectOne('id 不合格式', 'id', good({ id: 'physics-1' }));
  expectOne('id 序号不是三位数字', 'id', good({ id: 'phy-u-1' }));
  expectOne('id 序号含非数字', 'id', good({ id: 'phy-u-ab1' }));
  // 重复 id 要两条一起喂才测得出来 —— 单条用例永远碰不到这一支(第一版就漏了这条)
  const dup = MapValidator.validate([good({ id: 'phy-u-007' }), good({ id: 'phy-u-007' })]);
  assertTrue('同一张地图里 id 重复会被报出', dup.length === 1 && dup[0].field === 'id',
    dup.map((p) => `${p.field}:${p.message}`).join(' | ') || '一条都没报');
  const notDup = MapValidator.validate([good({ id: 'phy-u-007' }), good({ id: 'phy-u-008' })]);
  assertTrue('id 不重复时不误报', notDup.length === 0,
    notDup.map((p) => `${p.field}:${p.message}`).join(' | '));
  expectOne('id 学科码不符', 'subject', good({ subject: MapSubject.CHEMISTRY }));
  expectOne('id 学段码不符', 'stage', good({ stage: SchoolStage.SENIOR }));
  expectOne('可行性取值非法', 'feasibility', good({ feasibility: 'nope' }));
  expectOne('出处写着未核实却标了已核实', 'verified',
    good({ source: UNVERIFIED_PREFIX + '凭印象', verified: true }));
  expectOne('出处是已核实却标了未核实', 'verified',
    good({ source: '某校清单 http://x.example', verified: false }));

  // 真数据:物理那份必须一条问题都不报,且它的规模与分类计数是当场数出来的
  const { UniversityPhysics } = require(join(OUT, 'content/map/UniversityPhysics.cjs'));
  const phys = UniversityPhysics.all();
  const physProblems = MapValidator.validate(phys);
  assertTrue('大学物理地图 75 条全部通过校验', physProblems.length === 0,
    physProblems.map((p) => `${p.entryId}.${p.field}:${p.message}`).join(' | '));
  check('大学物理地图条数', phys.length, 75, 0);
  check('力学与热学条数', UniversityPhysics.mechanics().length, 28, 0);
  check('电磁学条数', UniversityPhysics.electromagnetism().length, 22, 0);
  check('光学条数', UniversityPhysics.optics().length, 13, 0);
  check('近代物理条数', UniversityPhysics.modern().length, 12, 0);
  const byCourse = {};
  for (const e of phys) {
    byCourse[e.course] = (byCourse[e.course] || 0) + 1;
  }
  let sumParts = UniversityPhysics.mechanics().length + UniversityPhysics.electromagnetism().length +
    UniversityPhysics.optics().length + UniversityPhysics.modern().length;
  assertTrue('汇总口的条数等于各分类之和(查询口不许漏项)', sumParts === phys.length,
    `${sumParts} vs ${phys.length}`);
  assertTrue('按课程逐条统计与分类计数一致',
    byCourse[UniversityPhysics.MECHANICS] === 28 && byCourse[UniversityPhysics.OPTICS] === 13,
    JSON.stringify(byCourse));
  const verifiedCount = phys.filter((e) => e.verified).length;
  check('物理这份全部带已核实出处', verifiedCount, 75, 0);
  const realGears = phys.filter((e) => e.feasibility === 'needs_real_gears').length;
  assertTrue('明确排除的「该用真仪器」条目确实存在(不是一句装饰)', realGears >= 10,
    `实得 ${realGears} 条`);
  const ids = phys.map((e) => e.id);
  assertTrue('id 全表唯一', new Set(ids).size === ids.length,
    `去重后 ${new Set(ids).size} / ${ids.length}`);

  // ---- 知识层:大学物理 80 条 ----
  const { makeKnowledge, KnowledgeLevel } = require(join(OUT, 'content/map/KnowledgeTypes.cjs'));
  const { KnowledgePhysics } = require(join(OUT, 'content/map/KnowledgePhysics.cjs'));

  function goodK(over) {
    const item = makeKnowledge('kn-phy-u-001', MapSubject.PHYSICS, SchoolStage.UNIVERSITY,
      '力学', '功与能', '例题', '一句话内容', ['x = 1'],
      KnowledgeLevel.APPLY, [], '某教材体系 http://x.example');
    for (const key of Object.keys(over)) {
      item[key] = over[key];
    }
    return item;
  }
  function expectOneK(label, field, item) {
    const probs = MapValidator.validateKnowledge([item]);
    assertTrue(`${label}:恰好报一条`, probs.length === 1,
      `实得 ${probs.length} 条:${probs.map((p) => p.field).join(',')}`);
    assertTrue(`${label}:报在 ${field} 字段上`,
      probs.length > 0 && probs[0].field === field,
      probs.map((p) => `${p.field}:${p.message}`).join(' | '));
  }
  expectOneK('知识 id 缺 kn 前缀', 'id', goodK({ id: 'phy-u-001' }));
  // 上面那条只分 3 段,先被段数检查拦下,证明不了「必须叫 kn」这一支 —— 这条才测得到
  expectOneK('知识 id 首段不是 kn', 'id', goodK({ id: 'xx-phy-u-001' }));
  expectOneK('知识 id 序号非三位', 'id', goodK({ id: 'kn-phy-u-01' }));
  expectOneK('课程为空', 'course', goodK({ course: '' }));
  expectOneK('章为空', 'chapter', goodK({ chapter: '' }));
  expectOneK('标题为空', 'title', goodK({ title: '' }));
  expectOneK('内容为空', 'statement', goodK({ statement: '' }));
  expectOneK('出处为空', 'source', goodK({ source: '' }));
  expectOneK('认知层次非法', 'level', goodK({ level: 'nope' }));
  expectOneK('verified 与出处不符', 'verified',
    goodK({ source: UNVERIFIED_PREFIX + '凭印象', verified: true }));
  // 悬挂前置:只有机器查得出来,浏览页顺链跳转时才暴露就晚了
  const dangling = MapValidator.validateKnowledge([goodK({ prerequisites: ['kn-phy-u-099'] })]);
  assertTrue('前置指向不存在的知识点会被报出',
    dangling.length === 1 && dangling[0].field === 'prerequisites',
    dangling.map((p) => `${p.field}:${p.message}`).join(' | ') || '一条都没报');
  const okRef = MapValidator.validateKnowledge([
    goodK({ id: 'kn-phy-u-002' }), goodK({ id: 'kn-phy-u-003', prerequisites: ['kn-phy-u-002'] })]);
  assertTrue('前置指向存在时不误报', okRef.length === 0,
    okRef.map((p) => `${p.field}:${p.message}`).join(' | '));

  const kp = KnowledgePhysics.all();
  const kpProblems = MapValidator.validateKnowledge(kp);
  assertTrue('大学物理知识 80 条全部通过校验', kpProblems.length === 0,
    kpProblems.slice(0, 6).map((p) => `${p.id}.${p.field}:${p.message}`).join(' | '));
  check('大学物理知识点条数', kp.length, 80, 0);
  check('力学条数', KnowledgePhysics.mechanics().length, 28, 0);
  check('热学条数', KnowledgePhysics.thermodynamics().length, 10, 0);
  check('电磁学条数', KnowledgePhysics.electromagnetism().length, 16, 0);
  check('光学条数', KnowledgePhysics.optics().length, 14, 0);
  check('近代物理条数', KnowledgePhysics.modern().length, 12, 0);
  const kpIds = kp.map((e) => e.id);
  assertTrue('知识 id 全表唯一', new Set(kpIds).size === kpIds.length,
    `去重后 ${new Set(kpIds).size} / ${kpIds.length}`);
  const noStatement = kp.filter((e) => e.statement.length < 12).length;
  assertTrue('没有一条知识是空话(内容至少一句)', noStatement === 0, `实得 ${noStatement} 条过短`);
  const withPrereq = kp.filter((e) => e.prerequisites.length > 0).length;
  assertTrue('多数知识点确实挂在前置上(不是平铺清单)', withPrereq >= kp.length * 0.6,
    `有前置的 ${withPrereq} / ${kp.length}`);

  // ---- 生物与电子的知识表:同一套标准,同一把尺子 ----
  const { KnowledgeBiology } = require(join(OUT, 'content/map/KnowledgeBiology.cjs'));
  const { KnowledgeElectronics } = require(join(OUT, 'content/map/KnowledgeElectronics.cjs'));
  const tables = [
    ['大学生物', KnowledgeBiology.all(), 82],
    ['大学电子', KnowledgeElectronics.all(), 54]];
  for (const [name, rows, expected] of tables) {
    const probs = MapValidator.validateKnowledge(rows);
    assertTrue(`${name}知识表全部通过校验`, probs.length === 0,
      probs.slice(0, 5).map((p) => `${p.id}.${p.field}:${p.message}`).join(' | '));
    check(`${name}知识条数`, rows.length, expected, 0);
    const ids = rows.map((r) => r.id);
    assertTrue(`${name}知识 id 唯一`, new Set(ids).size === ids.length,
      `去重后 ${new Set(ids).size} / ${ids.length}`);
    const short = rows.filter((r) => r.statement.length < 20).length;
    assertTrue(`${name}没有一条知识是空话`, short === 0, `${short} 条内容过短`);
    const withPre = rows.filter((r) => r.prerequisites.length > 0).length;
    assertTrue(`${name}多数条目挂前置`, withPre >= rows.length * 0.55,
      `有前置 ${withPre} / ${rows.length}`);
    // 已核实/未核实的**当前比例**不写进永久断言:那是今天的状态,P2 补到出处后
    // 合法升级就会变成假警报。一致性由 validateKnowledge 的 verified 规则守,
    // 比例记在 spec 里。这里只查一件不会过期的事:自称已核实的条目必须真带出处。
    const bareClaims = rows.filter((r) => r.verified && r.source.length < 12).length;
    assertTrue(`${name}没有"自称已核实却给不出出处"的条目`, bareClaims === 0, `${bareClaims} 条`);
    // 实测这两张表补判点后都是 100%,地板就取 100 —— 不是留余量,是照实测钉:
    // 谁把某条的判点删回一句光秃秃的定义,这里立刻红(已用变异测确认单条失效即红)。
    const rate = discriminatorRate(rows);
    assertTrue(`${name}判点率保持 100%`, rate === 100, `实得 ${rate}%`);
  }
}

// ---- 元素周期表 ----
{
  const { PeriodicTable } = require(join(OUT, 'content/map/PeriodicTable.cjs'));
  const { Formula } = require(join(OUT, 'chemistry/Formula.cjs'));
  const els = PeriodicTable.all();
  check('周期表收录元素数', els.length, 118, 0);

  const nums = els.map((e) => e.number);
  let contiguous = true;
  for (let i = 0; i < nums.length; i++) {
    if (nums[i] !== i + 1) {
      contiguous = false;
    }
  }
  assertTrue('原子序数从 1 起连续且唯一', contiguous, `首末 ${nums[0]}..${nums[nums.length - 1]}`);
  const symbols = els.map((e) => e.symbol);
  assertTrue('元素符号唯一', new Set(symbols).size === symbols.length,
    `去重后 ${new Set(symbols).size} / ${symbols.length}`);
  const badSymbol = symbols.filter((s) => !/^[A-Z][a-z]?$/.test(s));
  assertTrue('符号大小写规范(首字母大写,第二个小写)', badSymbol.length === 0, badSymbol.join(','));

  // 每周期 2/8/8/18/18/32/32:这条能抓住"把某个元素填错周期"
  const perPeriod = [0, 0, 0, 0, 0, 0, 0, 0];
  for (const e of els) {
    if (e.period < 1 || e.period > 7) {
      continue;
    }
    perPeriod[e.period]++;
  }
  check('第 1 周期元素数', perPeriod[1], 2, 0);
  check('第 2 周期元素数', perPeriod[2], 8, 0);
  check('第 3 周期元素数', perPeriod[3], 8, 0);
  check('第 4 周期元素数', perPeriod[4], 18, 0);
  check('第 5 周期元素数', perPeriod[5], 18, 0);
  check('第 6 周期元素数', perPeriod[6], 32, 0);
  check('第 7 周期元素数', perPeriod[7], 32, 0);

  const badGroup = els.filter((e) => e.group < 1 || e.group > 18).length;
  assertTrue('族号都在 1..18', badGroup === 0, `${badGroup} 条越界`);
  const badBlock = els.filter((e) => ['s', 'p', 'd', 'f'].indexOf(e.block) < 0).length;
  assertTrue('区只能是 s/p/d/f', badBlock === 0, `${badBlock} 条非法`);
  const badState = els.filter((e) => ['气', '液', '固'].indexOf(e.state) < 0).length;
  assertTrue('常温状态三取一', badState === 0, `${badState} 条非法`);
  const badMass = els.filter((e) => !(e.mass > 0.5 && e.mass < 300)).length;
  assertTrue('相对原子质量在合理区间', badMass === 0, `${badMass} 条越界`);
  // 常温气态只有 11 种(H N O F Cl + 稀有气体 He Ne Ar Kr Xe Rn):这条极易在填状态时错
  const gases = els.filter((e) => e.state === '气').map((e) => e.symbol).sort().join(',');
  check('常温气态元素种数', gases.split(',').length, 11, 0);
  assertTrue('常温气态就是那 11 种', gases === 'Ar,Cl,F,H,He,Kr,N,Ne,O,Rn,Xe', gases);
  const liquids = els.filter((e) => e.state === '液').map((e) => e.symbol).sort().join(',');
  assertTrue('常温液态只有汞与溴', liquids === 'Br,Hg', liquids);

  // 与 Formula.ets 的原子量表互校:两处不一致说明有一处录错元素或点错小数点。
  // Formula 表按整数取整(Cl 取 35.5),所以允许差 0.6;任何 ≥0.6 的偏差都会红。
  let mismatches = [];
  let compared = 0;
  for (const e of els) {
    const rounded = Formula.relativeMass(e.symbol);
    if (!(rounded > 0)) {
      continue;
    }
    compared++;
    if (Math.abs(rounded - e.mass) > 0.6) {
      mismatches.push(`${e.symbol}:表 ${e.mass} vs 式量表 ${rounded}`);
    }
  }
  assertTrue('与 Formula 原子量表对得上(至少覆盖 30 种)', compared >= 30, `只比到 ${compared} 种`);
  assertTrue('两张原子量表没有互相矛盾', mismatches.length === 0, mismatches.join(' | '));

  // 应用里真的用到的元素,表里必须有 —— 缺一个,周期表就还不是"够用"的。
  // 从反应库的每个化学式里抽元素符号(Reagents 没有列举接口,反应表有)
  const { ChemistryLibrary } = require(join(OUT, 'chemistry/ChemistryLibrary.cjs'));
  ChemistryLibrary.registerReagents();
  const usedSymbols = new Set();
  for (const spec of ChemistryLibrary.all()) {
    for (const term of spec.reactants.concat(spec.products)) {
      const raw = String(term.substance.formula);
      for (const m of raw.matchAll(/[A-Z][a-z]?/g)) {
        usedSymbols.add(m[0]);
      }
    }
  }
  const missing = [...usedSymbols].filter((s) => symbols.indexOf(s) < 0);
  // 门槛取 12 而不是"更多":当前 28 个反应只碰到 16 种元素,这本身是反应库太窄的信号,
  // 记在 spec 里当扩充依据;断言只守「用到的必须有」这条不会过期的规则。
  assertTrue('反应库用到的元素符号都在周期表里', usedSymbols.size >= 12 && missing.length === 0,
    `比到 ${usedSymbols.size} 种,缺 ${missing.join(',')}`);
}

// ---- 实验台事件必须带着配平好的方程式 ----
{
  const { ChemistryLibrary } = require(join(OUT, 'chemistry/ChemistryLibrary.cjs'));
  const { ReactionText } = require(join(OUT, 'chemistry/ChemistryModel.cjs'));
  ChemistryLibrary.registerReagents();
  const bench = ChemistryLibrary.bench();
  assertTrue('可上台架的反应非空', bench.length >= 8, `只有 ${bench.length} 条`);
  let bad = [];
  let withIonic = 0;
  for (const spec of bench) {
    const eq = ReactionText.equation(spec);
    if (eq.indexOf('→') < 0 && eq.indexOf('⇌') < 0) {
      bad.push(`${spec.id}:没有箭头`);
      continue;
    }
    const arrow = Math.max(eq.indexOf('→'), eq.indexOf('⇌'));
    const left = eq.slice(0, arrow);
    const right = eq.slice(arrow);
    for (const term of spec.reactants) {
      if (left.indexOf(term.substance.formula) < 0) {
        bad.push(`${spec.id}:左侧缺 ${term.substance.formula}`);
      }
      if (term.coefficient > 1 && left.indexOf(term.coefficient + term.substance.formula) < 0) {
        bad.push(`${spec.id}:系数 ${term.coefficient} 没体现在式子里`);
      }
    }
    for (const term of spec.products) {
      if (right.indexOf(term.substance.formula) < 0) {
        bad.push(`${spec.id}:右侧缺 ${term.substance.formula}`);
      }
    }
    if (spec.ionic !== null) {
      withIonic++;
      if (ReactionText.equation(spec.ionic).length < 4) {
        bad.push(`${spec.id}:离子式空`);
      }
    }
  }
  assertTrue('每条可上台架的反应都拼得出完整方程式', bad.length === 0, bad.slice(0, 4).join(' | '));
  assertTrue('至少一部分反应带离子方程式', withIonic >= 3, `只有 ${withIonic} 条`);
}

// ---- 并行代理交付的三份表:统一过同一把尺子,并查跨文件重复 ----
{
  const { MapValidator } = require(join(OUT, 'content/map/MapValidator.cjs'));
  const { KnowledgeChemistry } = require(join(OUT, 'content/map/KnowledgeChemistry.cjs'));
  const { UniversityChemistry } = require(join(OUT, 'content/map/UniversityChemistry.cjs'));
  const { UniversityElectronics } = require(join(OUT, 'content/map/UniversityElectronics.cjs'));
  const { UniversityBiology } = require(join(OUT, 'content/map/UniversityBiology.cjs'));
  const { CurriculumIndex } = require(join(OUT, 'content/map/CurriculumIndex.cjs'));

  const knChem = KnowledgeChemistry.all();
  const knChemProblems = MapValidator.validateKnowledge(knChem);
  assertTrue('大学化学知识表通过校验', knChemProblems.length === 0,
    knChemProblems.slice(0, 5).map((p) => `${p.id}.${p.field}:${p.message}`).join(' | '));
  check('大学化学知识条数', knChem.length, 96, 0);
  // 2026-10-10 逐条核完代理交回的"不确定"清单:9 条查到权威来源并改了值/补了出处。
  // 把 9 钉死 —— 以后谁把出处改回"未核实"或者把常数改回去,这里立刻红。
  check('大学化学知识已核实条数(逐条对过 NIST/LibreTexts/ChemistrySteps)',
    knChem.filter((e) => e.verified).length, 9, 0);
  // 同一个常数在两张表里必须一个写法。化学那条自己写着"计算取到 6.022 即可",
  // 而物理那条原先是 6.02 —— 不是错,是学生会在两页之间看到两个数。
  const naDrift = CurriculumIndex.knowledge().filter((e) => /6\.02[^2\d]/.test(e.statement));
  assertTrue('阿伏加德罗常数全表统一为 6.022×10²³', naDrift.length === 0,
    naDrift.map((e) => e.id).join(','));
  assertTrue('大学化学知识多数挂前置',
    knChem.filter((e) => e.prerequisites.length > 0).length >= knChem.length * 0.55,
    `有前置 ${knChem.filter((e) => e.prerequisites.length > 0).length} / ${knChem.length}`);
  assertTrue('大学化学知识没有空话(每条 ≥20 字)',
    knChem.filter((e) => e.statement.length < 20).length === 0, '有内容过短的条目');

  const expTables = [
    ['大学化学实验', UniversityChemistry.all(), 59],
    ['大学电子实验', UniversityElectronics.all(), 49],
    ['大学生物实验', UniversityBiology.all(), 41]];
  const allExp = [];
  for (const [name, rows, expected] of expTables) {
    const probs = MapValidator.validate(rows);
    assertTrue(`${name}通过校验`, probs.length === 0,
      probs.slice(0, 5).map((p) => `${p.entryId}.${p.field}:${p.message}`).join(' | '));
    check(`${name}条数`, rows.length, expected, 0);
    const gears = rows.filter((r) => r.feasibility === 'needs_real_gears').length;
    assertTrue(`${name}如实标出了「该用真仪器」的条目`, gears >= 5, `只标了 ${gears} 条`);
    allExp.push(...rows);
  }

  // 跨文件重名:并行写的表互相看不见,同一个实验很容易两份各写一遍。
  // 用完整标题比 —— 括号里的限定语(伸长法/弯曲法、拉脱法/毛细管法)正是区分不同实验的部分,
  // 剥掉它会造出假重复(第一版就踩了)。语义近义(如"固体比热"与"固体比热容")字符串抓不到,
  // 那类要靠人逐条判。
  const physics = require(join(OUT, 'content/map/UniversityPhysics.cjs')).UniversityPhysics.all();
  const byTitle = new Map();
  for (const e of physics.concat(allExp)) {
    const key = e.title.trim();
    if (!byTitle.has(key)) {
      byTitle.set(key, []);
    }
    byTitle.get(key).push(e.id);
  }
  const dupes = [...byTitle.entries()].filter(([, ids]) => ids.length > 1);
  assertTrue('实验表之间没有同名条目(跨学科重复要显式决定归属)', dupes.length === 0,
    dupes.map(([t, ids]) => `${t} ← ${ids.join(',')}`).join(' | '));
}

// ---- 学段轴打开:初中与高中物理两张新表 ----
{
  const { MapValidator } = require(join(OUT, 'content/map/MapValidator.cjs'));
  const { KnowledgePhysicsJunior } = require(join(OUT, 'content/map/KnowledgePhysicsJunior.cjs'));
  const { KnowledgePhysicsSenior } = require(join(OUT, 'content/map/KnowledgePhysicsSenior.cjs'));
  const { KnowledgeBiologyJunior } = require(join(OUT, 'content/map/KnowledgeBiologyJunior.cjs'));
  const { KnowledgeBiologySenior } = require(join(OUT, 'content/map/KnowledgeBiologySenior.cjs'));
  const { KnowledgeChemistryJunior } = require(join(OUT, 'content/map/KnowledgeChemistryJunior.cjs'));
  const { KnowledgeChemistrySenior } = require(join(OUT, 'content/map/KnowledgeChemistrySenior.cjs'));
  const { KnowledgeElectronicsJunior } = require(join(OUT, 'content/map/KnowledgeElectronicsJunior.cjs'));
  const { KnowledgeElectronicsSenior } = require(join(OUT, 'content/map/KnowledgeElectronicsSenior.cjs'));
  const { makeKnowledge } = require(join(OUT, 'content/map/KnowledgeTypes.cjs'));
  const { MapSubject, SchoolStage } = require(join(OUT, 'content/map/CurriculumTypes.cjs'));
  const { KnowledgeLevel } = require(join(OUT, 'content/map/KnowledgeTypes.cjs'));
  const { CurriculumIndex } = require(join(OUT, 'content/map/CurriculumIndex.cjs'));

  const tables = [
    ['初中物理', KnowledgePhysicsJunior.all(), SchoolStage.JUNIOR, 'kn-phy-jr-', 70, 3],
    ['高中物理', KnowledgePhysicsSenior.all(), SchoolStage.SENIOR, 'kn-phy-sr-', 73, 5],
    ['初中生物', KnowledgeBiologyJunior.all(), SchoolStage.JUNIOR, 'kn-bio-jr-', 45, 3],
    ['初中化学', KnowledgeChemistryJunior.all(), SchoolStage.JUNIOR, 'kn-chem-jr-', 49, 1],
    ['高中化学', KnowledgeChemistrySenior.all(), SchoolStage.SENIOR, 'kn-chem-sr-', 71, 5],
    ['高中生物', KnowledgeBiologySenior.all(), SchoolStage.SENIOR, 'kn-bio-sr-', 68, 5],
    ['初中电子学', KnowledgeElectronicsJunior.all(), SchoolStage.JUNIOR, 'kn-ele-jr-', 33, 3],
    ['高中电子学', KnowledgeElectronicsSenior.all(), SchoolStage.SENIOR, 'kn-ele-sr-', 49, 5]];
  for (const [name, rows, stage, prefix, expected, minCourses] of tables) {
    const probs = MapValidator.validateKnowledge(rows);
    assertTrue(`${name}知识表通过校验`, probs.length === 0,
      probs.slice(0, 5).map((p) => `${p.id || p.entryId}.${p.field}:${p.message}`).join(' | '));
    check(`${name}条数`, rows.length, expected, 0);
    // 学段不许再靠"没说就是大学"混过去:id 里的码与 stage 字段必须同时是这一档
    assertTrue(`${name}每条 stage 都是 ${stage}`, rows.every((e) => e.stage === stage),
      rows.filter((e) => e.stage !== stage).map((e) => e.id).join(','));
    assertTrue(`${name}每条 id 都以 ${prefix} 开头`, rows.every((e) => e.id.startsWith(prefix)),
      rows.filter((e) => !e.id.startsWith(prefix)).map((e) => e.id).join(','));
    const nums = rows.map((e) => Number(e.id.slice(prefix.length)));
    let contiguous = nums.every((n, i) => n === i + 1);
    assertTrue(`${name}序号从 001 起连续`, contiguous, `首末 ${nums[0]}..${nums[nums.length - 1]}`);
    assertTrue(`${name}没有空话(每条 ≥20 字)`, rows.every((e) => e.statement.length >= 20),
      rows.filter((e) => e.statement.length < 20).map((e) => e.id).join(','));
    assertTrue(`${name}多数挂前置`, rows.filter((e) => e.prerequisites.length > 0).length >= rows.length * 0.55,
      `有前置 ${rows.filter((e) => e.prerequisites.length > 0).length} / ${rows.length}`);
    // 前置不许指向自己,也不许指向还没出现的号(那样先修链在第一遍走不通)
    const badPrereq = [];
    for (let i = 0; i < rows.length; i++) {
      for (const p of rows[i].prerequisites) {
        const at = rows.findIndex((r) => r.id === p);
        if (at >= i) {
          badPrereq.push(`${rows[i].id}→${p}`);
        }
      }
    }
    assertTrue(`${name}的前置全部指向更靠前的条目`, badPrereq.length === 0, badPrereq.slice(0, 4).join(','));
  }

  // 册次分组闭合:每个 course 的条数加起来要等于该表条数(与大学表同一把尺子)
  for (const [name, rows, , , , minCourses] of tables) {
    const courses = [...new Set(rows.map((e) => e.course))];
    let sum = 0;
    for (const c of courses) {
      sum += rows.filter((e) => e.course === c).length;
    }
    check(`${name}的册次分组闭合`, sum, rows.length, 0);
    assertTrue(`${name}至少分 ${minCourses} 册`, courses.length >= minCourses,
      `只有 ${courses.length} 个 course:${courses.join(',')}`);
  }

  // 2026-10-10:三张中学知识表经在线目录核实,去掉未核实前缀后全部 verified。
  // 谁再把 UNVERIFIED_PREFIX 加回去,这里立刻红。
  const jrBioRows = tables.find(([n]) => n === '初中生物')[1];
  check('初中生物知识表已全部核实', jrBioRows.filter((e) => e.verified).length, 45, 0);
  const jrChemRows = tables.find(([n]) => n === '初中化学')[1];
  check('初中化学知识表已全部核实', jrChemRows.filter((e) => e.verified).length, 49, 0);
  const srChemRows = tables.find(([n]) => n === '高中化学')[1];
  check('高中化学知识表已全部核实', srChemRows.filter((e) => e.verified).length, 71, 0);

  // 判点率地板:深不深看的是「有没有能判对错的分界」,不是字数。
  // 2026-10-10 补判点前的实测最低是 21%(大学物理),那一轮补完最低 64%(物理·初中),地板取 60。
  // 2026-10-15 六个并行代理把中学八表逐条补齐,verify-table 实测八表全部 100% —— 地板照实测钉到 100,
  // 不是留余量:谁把某条的判点删回一句光秃秃的定义,这里立刻红(与大学表同一把尺子)。
  // 地板值来自实测,不是先定一个数再去凑(那条教训记在处置断言上)。
  for (const [name, rows] of tables) {
    const rate = discriminatorRate(rows);
    assertTrue(`${name}判点率保持 100%`, rate === 100, `实得 ${rate}%`);
  }

  // 四个学科现在都该有三个学段 —— 电子学曾长期只有大学一格,2026-10-10 补了中学两张表后补齐
  check('物理学段数', CurriculumIndex.stagesOf(MapSubject.PHYSICS).length, 3, 0);
  check('化学学段数', CurriculumIndex.stagesOf(MapSubject.CHEMISTRY).length, 3, 0);
  check('生物学段数', CurriculumIndex.stagesOf(MapSubject.BIOLOGY).length, 3, 0);
  check('电子学段数', CurriculumIndex.stagesOf(MapSubject.ELECTRONICS).length, 3, 0);
  let stageSum = 0;
  for (const s of CurriculumIndex.subjects()) {
    for (const st of CurriculumIndex.STAGE_ORDER) {
      stageSum += CurriculumIndex.knowledgeOfStage(s, st).length;
    }
  }
  check('学科×学段分组之和等于知识总数', stageSum, CurriculumIndex.knowledge().length, 0);
  // 应用真装着的两个高中实验,它们要考的知识现在得在图上
  const srRows = tables[1][1];
  assertTrue('高中表里有支撑斜面实验的摩擦力条目',
    srRows.some((e) => e.title.includes('摩擦')), '找不到');
  assertTrue('高中表里有支撑弹簧振子实验的简谐振动条目',
    srRows.some((e) => e.title.includes('简谐') || e.statement.includes('简谐')), '找不到');

  // 全集校验:合并后应当 0 问题
  const universe = CurriculumIndex.knowledge();
  const uniProbs = MapValidator.validateKnowledgeUniverse(universe);
  assertTrue('知识全集通过跨文件校验(无重复 id、无跨表悬挂)', uniProbs.length === 0,
    uniProbs.slice(0, 5).map((p) => `${p.entryId}.${p.field}:${p.message}`).join(' | '));
  // 同一学科同一学段里不许有同名标题。跨学段重名是合法的(动能定理在高中与大学都教,
  // 深浅不同),但同学段重名意味着同一个单元被写了两遍 —— 拆条目时最容易造出这种重复。
  const stageTitle = new Map();
  for (const e of universe) {
    const key = `${e.subject}/${e.stage}/${e.title}`;
    stageTitle.set(key, (stageTitle.get(key) || 0) + 1);
  }
  const dupStageTitle = [...stageTitle.entries()].filter(([, n]) => n > 1);
  assertTrue('同学段内没有同名知识点', dupStageTitle.length === 0,
    dupStageTitle.slice(0, 5).map(([t, n]) => `${t}×${n}`).join(' | '));

  // 负对照:守卫自己也得验。造一条"高中拿大学当先修"的假数据,校验器必须**只**报那一处 ——
  // 靠"全红"蒙对不算数(这条规矩是 2026-09-26 那批假断言换来的)。
  const bad = [
    makeKnowledge('kn-phy-sr-900', MapSubject.PHYSICS, SchoolStage.SENIOR, '选择性必修一',
      '机械振动', '负对照条目', '这条把大学普通物理当先修,校验器必须抓出来',
      [], KnowledgeLevel.APPLY, ['kn-phy-u-023'], '未核实:负对照'),
    makeKnowledge('kn-phy-sr-901', MapSubject.PHYSICS, SchoolStage.SENIOR, '选择性必修一',
      '机械振动', '正常对照条目', '这条引用同学段的上一条,不该被报',
      [], KnowledgeLevel.APPLY, ['kn-phy-sr-900'], '未核实:负对照')];
  const badProbs = MapValidator.validateKnowledgeUniverse(bad);
  assertTrue('跨学段的先修引用会被单独报出(且不误伤同表条目)',
    badProbs.length === 1 && badProbs[0].entryId === 'kn-phy-sr-900' &&
    badProbs[0].field === 'prerequisites',
    badProbs.map((p) => `${p.entryId}.${p.field}:${p.message}`).join(' | '));
  const dupRow = makeKnowledge('kn-phy-sr-902', MapSubject.PHYSICS, SchoolStage.SENIOR,
    '选择性必修一', '机械振动', '重复 id 对照', '这条被塞了两遍,只该报一次 id 重复',
    [], KnowledgeLevel.RECALL, [], '未核实:负对照');
  const dupProbs = MapValidator.validateKnowledgeUniverse([dupRow, dupRow]);
  assertTrue('跨文件重复 id 会被报出',
    dupProbs.length === 1 && dupProbs[0].field === 'id',
    dupProbs.map((p) => `${p.entryId}.${p.field}`).join(' | '));
}

// ---- 中学物理实验表:第一批真核实的数据 ----
{
  const { MapValidator } = require(join(OUT, 'content/map/MapValidator.cjs'));
  const { SchoolPhysics } = require(join(OUT, 'content/map/SchoolPhysics.cjs'));
  const { CurriculumIndex } = require(join(OUT, 'content/map/CurriculumIndex.cjs'));
  const { Feasibility, MapSubject, SchoolStage } = require(join(OUT, 'content/map/CurriculumTypes.cjs'));

  const rows = SchoolPhysics.all();
  const probs = MapValidator.validate(rows);
  assertTrue('中学物理实验表通过校验', probs.length === 0,
    probs.slice(0, 5).map((p) => `${p.entryId}.${p.field}:${p.message}`).join(' | '));
  check('中学物理实验条数', rows.length, 40, 0);
  check('其中初中', rows.filter((e) => e.stage === SchoolStage.JUNIOR).length, 18, 0);
  check('其中高中', rows.filter((e) => e.stage === SchoolStage.SENIOR).length, 22, 0);
  // 这一档的 RUNNABLE 是拿去和注册表对账的,多一条就是虚报
  const shippedHere = rows.filter((e) => e.feasibility === Feasibility.RUNNABLE).map((e) => e.id).sort();
  assertTrue('中学表里 RUNNABLE 正好是注册表真装着的那十三条',
    shippedHere.join(',') === ['phy-jr-001', 'phy-jr-002', 'phy-jr-007', 'phy-jr-017',
      'phy-sr-001', 'phy-sr-002', 'phy-sr-003', 'phy-sr-004', 'phy-sr-006', 'phy-sr-007',
      'phy-sr-008', 'phy-sr-010', 'phy-sr-015'].join(','),
    shippedHere.join(','));
  // 出处:代理取到了湖南省教育厅《初中必做实验目录(2023版)》与教育部《中小学实验教学基本目录》
  // 两份政府发布页原文。这条断言把"已核实"钉在一个数上 —— 往下掉说明有人把出处改浅了。
  const verified = rows.filter((e) => e.verified).length;
  assertTrue('中学实验多数有可核查出处(政府发布的必做/基本目录)', verified >= 30,
    `已核实 ${verified} / ${rows.length}`);
  assertTrue('该用真仪器的条目没有被做成可仿真',
    rows.filter((e) => e.feasibility === Feasibility.NEEDS_REAL_GEARS).length >= 10,
    `只标了 ${rows.filter((e) => e.feasibility === Feasibility.NEEDS_REAL_GEARS).length} 条`);
  // 每条都要写"这个实验在测什么、数据怎么处理",这两栏是空的进不了施工清单
  assertTrue('每条都有做法与数据处理要求',
    rows.every((e) => e.principle.length >= 20 && e.dataHandling.length >= 20),
    rows.filter((e) => e.principle.length < 20 || e.dataHandling.length < 20).map((e) => e.id).join(','));

  // 学段与学科两轴都要闭合:分学段加起来等于该学科总数
  const phy = CurriculumIndex.experimentsOf(MapSubject.PHYSICS);
  let byStage = 0;
  for (const st of CurriculumIndex.STAGE_ORDER) {
    byStage += CurriculumIndex.experimentsOfStage(MapSubject.PHYSICS, st).length;
  }
  check('物理按学段分组闭合', byStage, phy.length, 0);
  check('物理现在有三个学段的实验', CurriculumIndex.stagesOf(MapSubject.PHYSICS).length, 3, 0);
  // 跨表重名:中学与大学都教弹簧振子,但条目名必须能分辨(大学那条叫「谐振动的研究(弹簧振子)」)
  const titles = phy.map((e) => e.title);
  assertTrue('物理实验表内没有同名条目', new Set(titles).size === titles.length,
    titles.filter((t, i) => titles.indexOf(t) !== i).join(','));
}

// ---- 中学生物实验表:一条都不许自称可打开 ----
{
  const { MapValidator } = require(join(OUT, 'content/map/MapValidator.cjs'));
  const { SchoolBiology } = require(join(OUT, 'content/map/SchoolBiology.cjs'));
  const { Feasibility, SchoolStage } = require(join(OUT, 'content/map/CurriculumTypes.cjs'));

  const rows = SchoolBiology.all();
  const probs = MapValidator.validate(rows);
  assertTrue('中学生物实验表通过校验', probs.length === 0,
    probs.slice(0, 5).map((p) => `${p.entryId}.${p.field}:${p.message}`).join(' | '));
  check('中学生物实验条数', rows.length, 29, 0);
  check('其中初中', rows.filter((e) => e.stage === SchoolStage.JUNIOR).length, 14, 0);
  check('其中高中', rows.filter((e) => e.stage === SchoolStage.SENIOR).length, 15, 0);

  // 应用里没有任何生物实验,而且现有三类渲染器(回转体器皿 / 2D 物理 / 直流电路)
  // 也承载不了生物的教学目的。这两条是这张表最不该被"优化"掉的东西:
  // 一旦有人为了让完成度好看而给生物标上可打开或待补场景,这里就红。
  check('生物表里 RUNNABLE 必须为零',
    rows.filter((e) => e.feasibility === Feasibility.RUNNABLE).length, 0, 0);
  check('生物表里待补场景也必须为零(不是"只差场景",是画法本身没有)',
    rows.filter((e) => e.feasibility === Feasibility.NEEDS_SCENE).length, 0, 0);
  assertTrue('多数生物条目落在"要新画法"与"该用真仪器"两档',
    rows.filter((e) => e.feasibility === Feasibility.NEEDS_RENDERER ||
      e.feasibility === Feasibility.NEEDS_REAL_GEARS).length >= 18,
    `两档共 ${rows.filter((e) => e.feasibility === Feasibility.NEEDS_RENDERER ||
      e.feasibility === Feasibility.NEEDS_REAL_GEARS).length} / ${rows.length}`);

  // 29 条全部引到政府发布的实验目录原文(湖南湘教发〔2023〕40 号 初中 22 条、
  // 教育部《中小学实验教学基本目录》高中 38 项)。这条把"已核实"钉死在满值:
  // 以后谁把出处改浅了立刻红。
  check('生物表已核实条数(全部引到政府实验目录)', rows.filter((e) => e.verified).length, 29, 0);

  // 涉活体/人体/危化/食品的条目,处置要求必须写在数据处理里 —— 不能只写"观察并记录"。
  // 阈值 7 是**当场数出来的**,不是我估的:第一版我拍了个 >= 8 结果红,那是期望值错而不是数据错。
  // 另有 4 条按内容也该有一句而目前没有,已单列成任务:bio-jr-003(人口腔上皮)、
  // bio-jr-004(人体组织)、bio-jr-007(酒精不可直接加热写在正文里但没进这个词表)、bio-sr-014(分离纯化)。
  const disposal = /放回|废液|灭活|品尝|加盖|一次性|消毒|洗手|弃去|深埋|回填/;
  const withDisposal = rows.filter((e) => disposal.test(e.dataHandling)).length;
  check('写明活体与危化处置要求的条数(实测值)', withDisposal, 7, 0);
  assertTrue('处置要求不许被改没', withDisposal >= 7, `只剩 ${withDisposal} 条`);

  const courses = [...new Set(rows.map((e) => e.course))];
  let sum = 0;
  for (const c of courses) {
    sum += SchoolBiology.all().filter((e) => e.course === c).length;
  }
  check('生物表的课程分组闭合', sum, rows.length, 0);
  for (const [label, list, prefix] of [['初中', SchoolBiology.junior(), 'bio-jr-'],
    ['高中', SchoolBiology.senior(), 'bio-sr-']]) {
    const nums = list.map((e) => Number(e.id.slice(prefix.length)));
    assertTrue(`${label}生物 id 连续且以 ${prefix} 开头`,
      list.every((e) => e.id.startsWith(prefix)) && nums.every((n, i) => n === i + 1),
      `首末 ${nums[0]}..${nums[nums.length - 1]}`);
  }
}

// ---- 中学化学实验表 ----
{
  const { MapValidator } = require(join(OUT, 'content/map/MapValidator.cjs'));
  const { SchoolChemistry } = require(join(OUT, 'content/map/SchoolChemistry.cjs'));
  const { Feasibility, SchoolStage } = require(join(OUT, 'content/map/CurriculumTypes.cjs'));

  const rows = SchoolChemistry.all();
  const probs = MapValidator.validate(rows);
  assertTrue('中学化学实验表通过校验', probs.length === 0,
    probs.slice(0, 5).map((p) => `${p.entryId}.${p.field}:${p.message}`).join(' | '));
  check('中学化学实验条数', rows.length, 38, 0);
  check('其中初中', rows.filter((e) => e.stage === SchoolStage.JUNIOR).length, 17, 0);
  check('其中高中', rows.filter((e) => e.stage === SchoolStage.SENIOR).length, 21, 0);
  for (const [label, list, prefix] of [['初中', SchoolChemistry.junior(), 'chem-jr-'],
    ['高中', SchoolChemistry.senior(), 'chem-sr-']]) {
    const nums = list.map((e) => Number(e.id.slice(prefix.length)));
    assertTrue(`${label}化学 id 连续且以 ${prefix} 开头`,
      list.every((e) => e.id.startsWith(prefix)) && nums.every((n, i) => n === i + 1),
      `首末 ${nums[0]}..${nums[nums.length - 1]}`);
    assertTrue(`${label}化学没有短文本条目`,
      list.every((e) => e.principle.length >= 20 && e.dataHandling.length >= 20),
      list.filter((e) => e.principle.length < 20 || e.dataHandling.length < 20)
        .map((e) => e.id).join(','));
  }

  // 代理交回了一份"台架现在就能做"的白名单(jr-001/004/006/009/016、sr-002/005/006/010)。
  // 但 RUNNABLE 的口径是"场景 + 细则 + 渲染都在",而化学实验台**没有细则、不落记录**(#54),
  // 所以这些一律留在 NEEDS_SCENE,由我逐条实测后改判 —— 不许因为"能拖出反应"就算可打开。
  check('中学化学表 RUNNABLE 当前为零(待逐条实测改判)',
    rows.filter((e) => e.feasibility === Feasibility.RUNNABLE).length, 0, 0);
  assertTrue('台架撑得起的那几条记成待补场景而不是可打开',
    rows.filter((e) => e.feasibility === Feasibility.NEEDS_SCENE).length >= 10,
    `只标了 ${rows.filter((e) => e.feasibility === Feasibility.NEEDS_SCENE).length} 条待补场景`);
  // 37/38 引到政府实验目录原文(湖南湘教发〔2023〕40 号初中化学 8 条 +
  // 教育部《中小学实验教学基本目录》初中 35 项、高中 63 项),唯一未核实的是焰色试验。
  check('中学化学表已核实条数', rows.filter((e) => e.verified).length, 37, 0);
  assertTrue('动手类实验该被如实标成"不宜仿真"',
    rows.filter((e) => e.feasibility === Feasibility.NEEDS_REAL_GEARS).length >= 8,
    `只标了 ${rows.filter((e) => e.feasibility === Feasibility.NEEDS_REAL_GEARS).length} 条`);
  const courses = [...new Set(rows.map((e) => e.course))];
  check('中学化学的课程分组闭合', courses.reduce((a, c) =>
    a + rows.filter((e) => e.course === c).length, 0), rows.length, 0);
}

// ---- 查询口:分组之和必须等于总数,否则页面与清单就会分家 ----
{
  const { CurriculumIndex } = require(join(OUT, 'content/map/CurriculumIndex.cjs'));
  const { MapSubject, Feasibility } = require(join(OUT, 'content/map/CurriculumTypes.cjs'));
  const exps = CurriculumIndex.experiments();
  const kps = CurriculumIndex.knowledge();
  check('查询口的实验总数', exps.length, 331, 0);
  check('查询口的知识总数', kps.length, 770, 0);
  check('查询口的元素总数', CurriculumIndex.elements().length, 118, 0);

  let sumExp = 0;
  let sumKp = 0;
  for (const s of CurriculumIndex.subjects()) {
    sumExp += CurriculumIndex.experimentsOf(s).length;
    sumKp += CurriculumIndex.knowledgeOf(s).length;
  }
  check('四个学科分组之和等于实验总数', sumExp, exps.length, 0);
  check('四个学科分组之和等于知识总数', sumKp, kps.length, 0);

  // 二级分组(课程)也要闭合:某学科下每门课的条数加起来要等于该学科的条数
  for (const s of CurriculumIndex.subjects()) {
    const courses = CurriculumIndex.coursesOf(s);
    let sum = 0;
    for (const c of courses) {
      sum += CurriculumIndex.experimentsInCourse(c).length;
    }
    assertTrue(`${s} 的课程分组闭合`, sum === CurriculumIndex.experimentsOf(s).length,
      `${courses.length} 门课共 ${sum} 条 vs 学科 ${CurriculumIndex.experimentsOf(s).length} 条`);
    assertTrue(`${s} 至少有 2 门课`, courses.length >= 2, `只有 ${courses.length} 门`);
  }
  // 六门课:原来那四门大学口径 + 新登记的「初中物理实验」「高中物理实验」
  check('物理分六门课', CurriculumIndex.coursesOf(MapSubject.PHYSICS).length, 6, 0);

  const one = CurriculumIndex.findExperiment('phy-u-001');
  assertTrue('按 id 取得到实验条目', one !== null && one.subject === MapSubject.PHYSICS,
    JSON.stringify(one && one.id));
  assertTrue('不存在的 id 返回 null 而不是猜一个', CurriculumIndex.findExperiment('phy-u-999') === null,
    '取到了别的东西');
  assertTrue('按 id 取得到知识点', CurriculumIndex.findKnowledge('kn-phy-u-001') !== null, '取不到');

  const runnable = CurriculumIndex.runnableExperiments();
  check('可打开的实验数与逐条统计一致', runnable.length,
    CurriculumIndex.countByFeasibility(exps, Feasibility.RUNNABLE), 0);
  // 「现在能打开 N 个」是这张地图最容易吹牛的一个数,所以不许它自证。
  // 上一版写的是 `>= 5` 这样的下限 —— 结果电子那 8 条只因为"求解器够用"就被标成可打开,
  // 而应用里根本没有那 8 个实验(注册表只有 4 条)。下限对虚报是盲的,只有等号不是。
  // 这份清单跟着 Index.ets 的 routeMap 与 ExperimentRegistry 走:
  //   chem-u-004 = 量取训练页(MeasurePage);phy-jr-001/002 = 注册表里的 series/parallel-circuit;
  //   phy-sr-001/002 = 注册表里的 incline-block/spring-mass;ele-u-003 = kirchhoff;
  //   ele-u-007 = max-power。
  // 往地图里加一条 RUNNABLE 之前,先要能在这里指到一个真点得开的实验。
  //
  // **注意 phy-u-014 与 phy-sr-002 背后是同一个 spring-mass 场景** —— 六条地图项,五个真点得开的东西。
  // 这一格重复是有意的:大学的「谐振动的研究」要求从曲线读阻尼衰减并与理论值比较,
  // 现有场景确实给得出这条曲线,所以两门课今天都能开这一个实验。但记账要说明白,
  // 否则"完成度"会被一次实现记两次功劳。
  const SHIPPED_RUNNABLE = ['chem-u-004', 'ele-u-003', 'ele-u-007', 'phy-jr-001', 'phy-jr-002',
    'phy-jr-007', 'phy-jr-017', 'phy-sr-001', 'phy-sr-002', 'phy-sr-003', 'phy-sr-004', 'phy-sr-006',
    'phy-sr-007', 'phy-sr-008', 'phy-sr-010', 'phy-sr-015', 'phy-u-014'];
  const runnableIds = runnable.map((e) => e.id).sort();
  assertTrue('地图自称可打开的条目必须等于应用真装了的实验',
    runnableIds.join(',') === SHIPPED_RUNNABLE.join(','),
    `地图 [${runnableIds.join(',')}] vs 应用 [${SHIPPED_RUNNABLE.join(',')}]`);
  // 上面那份清单是手写的,所以还得反过来对一次:凡声称"按注册表登记"的,注册表里得真有那个场景。
  // 否则改个场景名就能让地图凭空多出一条可打开的实验。
  const registered = ExperimentRegistry.all().map((m) => m.id);
  const BASIS = {
    'phy-jr-001': 'series-circuit', 'phy-jr-002': 'parallel-circuit',
    'phy-sr-001': 'incline-block', 'phy-sr-002': 'spring-mass', 'ele-u-003': 'kirchhoff',
    'ele-u-007': 'max-power', 'phy-sr-004': 'spring-force', 'phy-jr-017': 'ohm-law',
    'phy-sr-010': 'emf-internal-resistance',
    'phy-sr-003': 'tape-cart',
    'phy-sr-008': 'free-fall',
    'phy-jr-007': 'stopwatch-cart',
    'phy-sr-006': 'newton-second-cart',
    'phy-sr-015': 'spring-image',
    'phy-sr-007': 'projectile-frame'
  };
  const lostBasis = Object.keys(BASIS)
    .filter((mapId) => registered.indexOf(BASIS[mapId]) < 0)
    .map((mapId) => `${mapId} 声称可打开,但注册表里没有 ${BASIS[mapId]}`);
  assertTrue('每条按注册表登记的 RUNNABLE 都指得到一个真注册了的场景', lostBasis.length === 0,
    lostBasis.join(' | '));
  check('注册表里的场景数', registered.length, 15, 0);
  assertTrue('生物学科现在一条可打开的都没有(与地图自己的判断一致)',
    CurriculumIndex.experimentsOf(MapSubject.BIOLOGY)
      .every((e) => e.feasibility !== Feasibility.RUNNABLE), '生物出现了 RUNNABLE 条目');
  // 「待补场景」这一档是为电子那 8 条而加的(引擎够、场景没有)。
  // 一条新枚举值若没有数据在用,它就是死代码 —— 这条断言同时守住"最低成本的施工面"别被误降级。
  // 电子 6 + 中学化学 11 = 17 条最低成本的施工面(中学物理这一档已清空)。
  // (中学物理原有 9 条,phy-sr-004 / phy-jr-017 / phy-sr-010 / phy-sr-003 / phy-sr-008 / phy-jr-007 / phy-sr-006 / phy-sr-015 / phy-sr-007 各做成一条场景,减九条;
  //  电子原有 8 条,已做成场景的 ele-u-003 与 ele-u-007 各减一条;中学化学那 11 条
  //  是"台架能拖出反应但没有细则",见 #54)
  check('待补场景的实验条数(引擎够用,只差场景与细则)',
    CurriculumIndex.countByFeasibility(exps, Feasibility.NEEDS_SCENE), 17, 0);

  let periodSum = 0;
  for (let p = 1; p <= 7; p++) {
    periodSum += CurriculumIndex.elementsInPeriod(p).length;
  }
  check('周期分组之和等于元素总数', periodSum, 118, 0);

  // 浏览页按「组首才显示周期标题」渲染,那要求数组沿原子序数走完一周期才进下一周期。
  // 集合闭合(上面那条)对乱序是盲的:把第 3 周期的元素插到第 2 周期中间,分组之和照样等于 118,
  // 而界面上会出现「第 2 周期」标题打两次。所以必须单独断言单调性。
  const elList = CurriculumIndex.elements();
  let periodDip = '';
  for (let i = 1; i < elList.length; i++) {
    if (elList[i].period < elList[i - 1].period) {
      periodDip = `${elList[i - 1].symbol}(第${elList[i - 1].period}周期) 后面接了 ` +
        `${elList[i].symbol}(第${elList[i].period}周期)`;
    }
  }
  assertTrue('元素按原子序数排列时周期号单调不减(浏览页分组依赖此序)', periodDip === '', periodDip);

  const carbon = CurriculumIndex.findElement(6);
  assertTrue('按原子序数取得到元素', carbon !== null && carbon.symbol === 'C',
    JSON.stringify(carbon && carbon.symbol));
  assertTrue('越界原子序数返回 null 而不是猜一个',
    CurriculumIndex.findElement(0) === null && CurriculumIndex.findElement(119) === null, '取到了别的东西');

  // 化合价的显示写法:化学里 +2/-3 的符号是要写出来的,裸数字会被读成"2 价"而不是"+2 价"。
  // 格式化放在数据层而不是页面里,为的是这条能对 118 个元素全量跑 —— 页面只渲染看得见的那几行。
  const allEls = CurriculumIndex.elements();
  assertTrue('氢的化合价写作 -1、+1',
    CurriculumIndex.findElement(1).valenceLabel() === '-1、+1',
    `实际 ${CurriculumIndex.findElement(1).valenceLabel()}`);
  assertTrue('铁的化合价写作 +2、+3',
    CurriculumIndex.findElement(26).valenceLabel() === '+2、+3',
    `实际 ${CurriculumIndex.findElement(26).valenceLabel()}`);
  const badValenceLabel = allEls.filter((e) => {
    const label = e.valenceLabel();
    if (e.valences.length === 0) {
      return label !== '无稳定化合价';
    }
    return label.split('、').some((p) => !/^[+-]\d+$/.test(p));
  }).map((e) => `${e.symbol}:${e.valenceLabel()}`);
  assertTrue('118 个元素的化合价串全部带符号且无空值', badValenceLabel.length === 0,
    badValenceLabel.slice(0, 5).join(' | '));
}

// ---- 基尔霍夫定律验证场景(ele-u-003):两节点三支路 ----
{
  // 拓扑约定(实现必须照这个来,否则下面的符号断言全无意义):
  //   n0 = 底轨 = 参考点; n1 = 节点 A
  //   支路1: n0 -[src1]-> n2 -[r1]-> n3 -[a1]-> n1
  //   支路2: n0 -[r2]-> n4 -[a2]-> n1
  //   支路3: n0 -[src2]-> n5 -[r3]-> n6 -[a3]-> n1
  //   (箭头方向 = 该元件的 nodeA → nodeB)
  // 三只电流表的 nodeB 都接在节点 A 上,所以 SIGNED_I > 0 表示「流入节点 A」 ——
  // KCL 就是三只表读数的代数和为零,而「其中一只是负的」正是本实验要教的东西。
  const k = electrical('kirchhoff', { emf1: 6, emf2: 6, r1: 10, r2: 20, r3: 10 });
  const signed = (id) => k.readObservable(`SIGNED_I:${id}`);

  // 手算工况 A:两源各 6 V,左右各串 10 Ω,中支路 20 Ω
  //   (6−V)/10 + (6−V)/10 = V/20  ⇒  V = 4.8 V  ⇒  两源支路各 0.12 A,中支路 0.24 A 流出
  check('KCL 工况 A 左支路电流', signed('a1'), 0.12, 2e-5);
  check('KCL 工况 A 中支路电流', signed('a2'), -0.24, 2e-5);
  check('KCL 工况 A 右支路电流', signed('a3'), 0.12, 2e-5);
  check('KCL 工况 A 代数和为零', signed('a1') + signed('a2') + signed('a3'), 0, 1e-9);

  // 手算工况 B:6 V / 3 V 不对称 ⇒ 右支路实际方向与参考方向相反(电源被充电)
  //   (6−V)/10 + (3−V)/20 = V/30  ⇒  45 = 11V  ⇒  V = 45/11
  const kb = electrical('kirchhoff', { emf1: 6, emf2: 3, r1: 10, r2: 30, r3: 20 });
  const sb = (id) => kb.readObservable(`SIGNED_I:${id}`);
  check('KCL 工况 B 左支路', sb('a1'), (6 - 45 / 11) / 10, 1e-5);
  check('KCL 工况 B 右支路等于手算值(负)', sb('a3'), (3 - 45 / 11) / 20, 1e-5);
  assertTrue('工况 B 的右支路确实是负的', sb('a3') < 0, `实得 ${sb('a3')}`);
  check('KCL 工况 B 代数和为零', sb('a1') + sb('a2') + sb('a3'), 0, 1e-9);

  // 扫掠一条不变量:换 12 组参数,节点 A 的三条支路电流代数和都得为零。
  // 只测工况 A 会被对称性掩盖(左右同号、中支路反号,闭合差看着像凑出来的);
  // 扫掠才能把「某一支路其实没接到节点 A」这类拓扑错暴露出来。
  //
  // 这里**没有**再加一条 KVL 断言,原因是它测不出东西:沿电位差绕一圈求和
  // 对任何电位赋值都恒为零,是恒等式而不是物理内容;而 `U:` 观测量取的是绝对值,
  // 一旦某条支路反向,把它按绕行方向相加反而必然不为零(第一版就红在这)。
  // 电压关系真正要盯的是"读数与参考方向",那由下面的反向工况守。
  const sweeps = [];
  for (const e1 of [2, 6, 12]) {
    for (const e2 of [0, 4, 9]) {
      for (const [ra, rb, rc] of [[10, 20, 10], [5, 100, 40]]) {
        const r = electrical('kirchhoff', { emf1: e1, emf2: e2, r1: ra, r2: rb, r3: rc });
        const i = (id) => r.readObservable(`SIGNED_I:${id}`);
        const kcl = i('a1') + i('a2') + i('a3');
        sweeps.push({ tag: `${e1}/${e2}/${ra}/${rb}/${rc}`, kcl });
      }
    }
  }
  const badKcl = sweeps.filter((s) => !Number.isFinite(s.kcl) || Math.abs(s.kcl) > 1e-9);
  assertTrue(`${sweeps.length} 组扫掠里节点 A 的电流代数和都为零`, badKcl.length === 0,
    badKcl.slice(0, 3).map((s) => `${s.tag}:${s.kcl}`).join(' | '));

  // 反向工况:E2 从 +9 V 扫到 −9 V,a3 必须穿零变号 —— 学生由此看到"实际方向与参考方向相反"
  // 不是读数坏了,而是电流真的反着流(电源被充电)。符号约定错了这条就红。
  const fwd = electrical('kirchhoff', { emf1: 6, emf2: 9, r1: 10, r2: 30, r3: 20 });
  const rev = electrical('kirchhoff', { emf1: 6, emf2: -9, r1: 10, r2: 30, r3: 20 });
  assertTrue('E2 取 9 V 时右支路流入节点 A', fwd.readObservable('SIGNED_I:a3') > 0,
    `实得 ${fwd.readObservable('SIGNED_I:a3')}`);
  assertTrue('E2 反接后右支路改为流出节点 A', rev.readObservable('SIGNED_I:a3') < 0,
    `实得 ${rev.readObservable('SIGNED_I:a3')}`);
  check('E2 反接后 KCL 仍成立',
    rev.readObservable('SIGNED_I:a1') + rev.readObservable('SIGNED_I:a2') +
    rev.readObservable('SIGNED_I:a3'), 0, 1e-9);

  // 把中支路电阻拉到极大,应当退化成串联:左右两支路电流等值反号。
  // 容差不是 1e-9 而是 1e-6 —— 1e7 Ω 的中支路仍走 3e-7 A 的漏流(V_A≈3 V 除以 1e7),
  // 那是真实后果而不是求解器误差。写成 1e-9 会红,而红的是我的期望值。
  const open = electrical('kirchhoff', { emf1: 6, emf2: 0, r1: 10, r2: 1e7, r3: 10 });
  check('中支路近似断开时左右电流等值反号(留 1e7 Ω 漏流)',
    open.readObservable('SIGNED_I:a1') + open.readObservable('SIGNED_I:a3'), 0, 1e-6);
  check('中支路近似断开时电流约等于 6/(10+10)', open.readObservable('SIGNED_I:a1'), 0.3, 1e-3);
  // 漏流本身也得在:它比 0.3 A 小六个数量级,但绝不能是零 —— 零意味着那条支路断了
  check('中支路的漏流约等于 V_A/1e7', Math.abs(open.readObservable('SIGNED_I:a2')), 3e-7, 2e-8);
}

// ---- 最大功率传输场景(ele-u-007):理想源 + 内阻 R₀ + 可变负载 R_L ----
{
  // 解析解:E=6 V、R₀=10 Ω 时 P(R_L) = E²R_L/(R₀+R_L)²,极大值在 R_L=R₀,
  // P_max = E²/(4R₀) = 0.9 W,此时效率恰为 50%。两侧 R₀/2 与 2R₀ 都该给出 0.8 W ——
  // 这个"对称两点同值、中间最高"的形态是判据,单点通过说明不了极大值存在。
  /*
   * 容差取 1e-4 而不是 1e-9:回路里串着一只 1e-4 Ω 的电流表,
   * 它让总电阻从 20 Ω 变成 20.0001 Ω,于是 P_max = 0.899991 而不是 0.9。
   * 这个残差是场景里的真实元件造成的,不是求解器不精确 —— 想钉到 1e-9 就得把电流表去掉,
   * 而"电表有内阻"正是 ele-u-006 要教的东西。
   */
  const at = (rl) => electrical('max-power', { emf: 6, r0: 10, rL: rl });

  const peak = at(10);
  check('R_L=R₀ 时回路电流', peak.readObservable('SIGNED_I:rL'), 0.3, 1e-4);
  check('R_L=R₀ 时负载电压', peak.readObservable('U:rL'), 3, 1e-4);
  check('R_L=R₀ 时负载功率', peak.readObservable('P:rL'), 0.9, 1e-4);
  check('R_L=R₀ 时电源供给功率', peak.readObservable('P:src'), 1.8, 1e-4);
  check('R_L=R₀ 时电源看进去的总电阻', peak.readObservable('Req'), 20, 1e-3);
  check('R_L=R₀/2 时负载功率', at(5).readObservable('P:rL'), 0.8, 1e-4);
  check('R_L=2R₀ 时负载功率', at(20).readObservable('P:rL'), 0.8, 1e-4);

  // 扫掠 1..100 Ω:峰值必须正好落在 R_L = R₀ = 10。
  // 这条同时是 RHEOSTAT 这个元件第一次被真的用进场景 —— 它此前只有绘制分支、没有调用方。
  let best = { rl: 0, p: -1 };
  for (let rl = 1; rl <= 100; rl += 1) {
    const p = at(rl).readObservable('P:rL');
    if (Number.isFinite(p) && p > best.p) {
      best = { rl: rl, p: p };
    }
  }
  check('扫掠 1..100 Ω 找到的峰值位置', best.rl, 10, 0);
  check('峰值功率', best.p, 0.9, 1e-4);

  // 效率与功率的矛盾:η = P_load/P_src 随 R_L 单调上升,所以在功率最大处效率只有 50%。
  // 这条断言守的是"效率最高"与"功率最大"不同点 —— 把 P: 或 U: 的符号弄错就会同时相等。
  const eta = (rl) => at(rl).readObservable('P:rL') / at(rl).readObservable('P:src');
  assertTrue('效率随 R_L 单调上升', eta(5) < eta(10) && eta(10) < eta(20) && eta(20) < eta(100),
    `η(5)=${eta(5)} η(10)=${eta(10)} η(20)=${eta(20)} η(100)=${eta(100)}`);
  check('功率最大处效率恰为 50%', eta(10), 0.5, 1e-4);
  assertTrue('R_L 远大于 R₀ 时效率趋近 1 但功率跌回峰值以下',
    eta(100) > 0.9 && at(100).readObservable('P:rL') < 0.9,
    `η(100)=${eta(100)} P(100)=${at(100).readObservable('P:rL')}`);
  // 曲线形状:峰值两侧都得单调下降。原先我写的是"两端远小于峰值"并给了个 0.1 的阈值,
  // 而 R_L=0.5 Ω 时 P=0.163 W —— 数是对的,是我的期望写错了。
  assertTrue('短路侧单调上升', at(0.5).readObservable('P:rL') < at(2).readObservable('P:rL') &&
    at(2).readObservable('P:rL') < at(6).readObservable('P:rL'),
    `P(0.5)=${at(0.5).readObservable('P:rL')} P(2)=${at(2).readObservable('P:rL')} ` +
      `P(6)=${at(6).readObservable('P:rL')}`);
  assertTrue('开路侧单调下降', at(14).readObservable('P:rL') > at(30).readObservable('P:rL') &&
    at(30).readObservable('P:rL') > at(120).readObservable('P:rL'),
    `P(14)=${at(14).readObservable('P:rL')} P(30)=${at(30).readObservable('P:rL')} ` +
      `P(120)=${at(120).readObservable('P:rL')}`);

  // 换一组内阻,峰值必须跟着搬走 —— 否则说明场景把 R₀ 写死在了某个常数上
  let best2 = { rl: 0, p: -1 };
  for (let rl = 5; rl <= 200; rl += 5) {
    const x = electrical('max-power', { emf: 6, r0: 40, rL: rl });
    const p = x.readObservable('P:rL');
    if (Number.isFinite(p) && p > best2.p) {
      best2 = { rl: rl, p: p };
    }
  }
  check('内阻改成 40 Ω 后峰值搬到 R_L=40', best2.rl, 40, 0);
  check('内阻 40 Ω 时的峰值功率 = E²/4R₀', best2.p, 36 / 160, 1e-4);
}

// ---- L3 示踪弹:学生的离散动作进事实。phy-sr-004 探究弹簧弹力与形变量的关系 ----
// 立论是「判分依据来自学生自己造成的可测量后果」。这里断言的不是画面,
// 而是三件能被算出来的事:加砝码确实改变了平衡伸长、超过弹性限度确实留下永久变形、
// 以及「在动的弹簧上按记录」和「停下来再按」在事实里是两个不同的数。
{
  const { SpringForceRunner } = require(join(OUT, 'physics/SpringForceRunner.cjs'));
  const { RubricSpring } = require(join(OUT, 'bench/RubricSpring.cjs'));
  const { RubricValidator } = require(join(OUT, 'bench/Rubric.cjs'));
  const { FactSheet } = require(join(OUT, 'model/FactSheet.cjs'));
  const { Judgment } = require(join(OUT, 'bench/Judgment.cjs'));
  const { ExperimentRegistry } = require(join(OUT, 'runner/ExperimentRegistry.cjs'));
  const { MechanicsScenes } = require(join(OUT, 'scenes/MechanicsScenes.cjs'));
  const { ElectricalScenes } = require(join(OUT, 'scenes/ElectricalScenes.cjs'));
  MechanicsScenes.registerAll();
  ElectricalScenes.registerAll();

  // 接口新增了两个方法,先确认每条已注册实验都真能接住动作与出事实,
  // 而不是只有新 runner 有 —— 否则外壳的按钮对老实验是哑的。
  const metas = ExperimentRegistry.all();
  assertTrue('注册表里至少有三条实验可查', metas.length >= 3, `实得 ${metas.length}`);
  let noAction = 0;
  let noFacts = 0;
  for (const m of metas) {
    const r = ExperimentRegistry.createRunner(m.id);
    if (typeof r.doAction !== 'function') { noAction++; }
    if (typeof r.collectFacts !== 'function') { noFacts++; }
  }
  check('每条注册 runner 都有 doAction', noAction, 0, 0);
  check('每条注册 runner 都有 collectFacts', noFacts, 0, 0);

  const G = 9.8;
  const K = 20;
  const PAN = 0.01;
  const EACH = 0.05;
  const DT = 1 / 240;
  const spring = (weights) => {
    const r = new SpringForceRunner();
    const meta = ExperimentRegistry.find('spring-force').meta;
    r.setup(meta);
    r.setParam('stiffness', K);
    r.setParam('panMass', PAN);
    r.setParam('weightMass', EACH);
    for (let i = 0; i < weights; i++) { r.doAction('weight+'); }
    return r;
  };
  const run = (r, seconds) => {
    for (let i = 0; i < Math.round(seconds / DT); i++) { r.step(DT); }
  };

  const s0 = spring(0);
  run(s0, 6);
  check('空盘静止时伸长 = m盘·g/k', s0.readObservable('extension'), PAN * G / K, 1e-4);
  check('空盘时弹力读数 = 盘重', s0.readObservable('force'), PAN * G, 1e-4);

  const s3 = spring(3);
  run(s3, 6);
  check('挂 3 个砝码静止伸长 = (盘+3·码)g/k', s3.readObservable('extension'), (PAN + 3 * EACH) * G / K, 2e-3);
  check('加到 3 个砝码的载荷是 3·m·g', s3.readObservable('load'), 3 * EACH * G, 1e-6);
  const x3 = s3.readObservable('extension');
  s3.doAction('weight-');
  run(s3, 6);
  check('卸下一个后伸长回落到 2 个的水平', s3.readObservable('extension'), (PAN + 2 * EACH) * G / K, 2e-3);
  assertTrue('卸载确实把伸长拉回去了', s3.readObservable('extension') < x3,
    `卸载后 ${s3.readObservable('extension').toFixed(4)} vs 卸载前 ${x3.toFixed(4)}`);

  // 超过弹性限度:模型必须留下永久变形,而不是"弹坏"只写在文案里
  const bad = spring(10);
  run(bad, 6);
  const badFacts = new FactSheet();
  bad.collectFacts(badFacts);
  check('挂到 10 个确实越过弹性限度', badFacts.num('beyondLimit'), 1, 0);
  assertTrue('越限时的最大伸长记进事实', badFacts.num('maxExtension') > 0.12,
    `实得 ${badFacts.num('maxExtension').toFixed(3)} m`);
  for (let i = 0; i < 10; i++) { bad.doAction('weight-'); }
  run(bad, 6);
  const residual = bad.readObservable('residual');
  assertTrue('撤全部砝码后仍留下永久变形(>0)', residual > 1e-4, `实得 ${residual.toFixed(4)} m`);
  check('永久变形量与越限超出量一致', residual, badFacts.num('maxExtension') - bad.readObservable('limitExtension'), 5e-3);

  // 「在动的弹簧上按记录」与「停下来再按」必须是两个不同的事实
  const rush = spring(2);
  run(rush, 0.35);
  rush.doAction('record');
  const rushFacts = new FactSheet();
  rush.collectFacts(rushFacts);
  assertTrue('刚加码就记录 → 记录瞬间速度明显不为零', rushFacts.num('maxRecordSpeed') > 0.02,
    `实得 ${rushFacts.num('maxRecordSpeed').toFixed(3)} m/s`);
  const calm = spring(2);
  run(calm, 6);
  calm.doAction('record');
  const calmFacts = new FactSheet();
  calm.collectFacts(calmFacts);
  assertTrue('静止后记录 → 记录瞬间速度接近零', calmFacts.num('maxRecordSpeed') <= 0.02,
    `实得 ${calmFacts.num('maxRecordSpeed').toFixed(4)} m/s`);

  const one = spring(2);
  run(one, 6);
  one.doAction('record');
  const oneFacts = new FactSheet();
  one.collectFacts(oneFacts);
  check('只记一档时 distinctLoads 是 1', oneFacts.num('distinctLoads'), 1, 0);
  const two = spring(2);
  run(two, 6);
  two.doAction('record');
  two.doAction('weight+');
  run(two, 6);
  two.doAction('record');
  two.doAction('weight-');
  run(two, 6);
  two.doAction('record');
  const twoFacts = new FactSheet();
  two.collectFacts(twoFacts);
  check('同一载荷记两次只算一档(按载荷去重)', twoFacts.num('distinctLoads'), 2, 0);
  assertTrue('做过卸载对照 → unloadSteps 计数', twoFacts.num('unloadSteps') >= 1,
    `实得 ${twoFacts.num('unloadSteps')}`);

  // 细则本身:自检、来源声明、分值守恒
  const rubric = RubricSpring.create();
  const issues = RubricValidator.validate(rubric);
  check('弹簧细则通过自检', issues.length, 0, 0);
  if (issues.length) { console.log('  细则问题:', issues); }
  assertTrue('自建细则必须声明是非官方标准', rubric.source.includes('非官方标准'), rubric.source);
  const sum = rubric.criteria.reduce((a, c) => a + c.points, 0);
  check('弹簧细则分值合计 = 满分', sum, rubric.totalPoints, 0);

  // 报告页的「关键事实」按 FactLabels 印显示名;判据引用了没配标签的键,
  // 学生看到的就是 recordCount 这种内部名。这条把三张细则一起管住。
  const { FactLabels } = require(join(OUT, 'model/FactLabels.cjs'));
  const { RubricMeasure } = require(join(OUT, 'bench/RubricMeasure.cjs'));
  const { RubricBrine } = require(join(OUT, 'bench/RubricBrine.cjs'));
  const unlabeled = [];
  for (const rb of [rubric, RubricMeasure.create(), RubricBrine.create()]) {
    for (const c of rb.criteria) {
      if (c.kind === 'numeric' && FactLabels.of(c.metric) === null) {
        unlabeled.push(rb.id + ':' + c.metric);
      }
    }
  }
  check('每条数值判据引用的事实都配了显示名', unlabeled.length, 0, 0);
  if (unlabeled.length) { console.log('  没配标签的事实键:', unlabeled); }

  // 判定层:事实缺失一律放过(宁漏不误)
  const empty = Judgment.score(rubric, new FactSheet());
  check('没有任何事实时不扣分', empty.awarded, rubric.totalPoints, 0);
  check('没有任何事实时零扣分', empty.deductions.length, 0, 0);

  const hurt = new FactSheet();
  hurt.set('beyondLimit', 1);
  hurt.set('maxExtension', 0.25);
  const hurtCard = Judgment.score(rubric, hurt);
  assertTrue('拉坏弹簧要扣分', hurtCard.deductions.some((d) => d.metric === 'beyondLimit'),
    hurtCard.deductions.map((d) => d.metric).join(','));
  const hurtLine = hurtCard.deductions.find((d) => d.metric === 'beyondLimit');
  assertTrue('扣分的证据里必须是实数而不是占位符', !hurtLine.evidence.includes('{') &&
    hurtLine.evidence.includes('0.25'), hurtLine.evidence);
  // 细则的证据会引用好几个事实。哪一个没被写进清单,报告里就不该留下 {花括号} ——
  // 学生看到的必须是「—」而不是模板。
  const leaked = hurtCard.deductions.filter((d) => d.evidence.includes('{'));
  check('事实缺失时证据里不留模板占位符', leaked.length, 0, 0);
  if (leaked.length) { console.log('  泄漏的占位符:', leaked.map((d) => d.evidence)); }
  assertTrue('缺事实的那一项以破折号呈现', hurtLine.evidence.includes('—'), hurtLine.evidence);

  const thin = new FactSheet();
  thin.set('distinctLoads', 2);
  const thinCard = Judgment.score(rubric, thin);
  assertTrue('只测两档 → 判数据不足', thinCard.deductions
    .some((d) => d.metric === 'distinctLoads'), '');
  const thinLine = thinCard.deductions.find((d) => d.metric === 'distinctLoads');
  assertTrue('计数类证据不印成小数(2 档而不是 2.00 档)',
    thinLine.evidence.includes('2 档') && !thinLine.evidence.includes('2.00'), thinLine.evidence);
  const moving = new FactSheet();
  moving.set('maxRecordSpeed', 0.3);
  assertTrue('在振动中记录 → 判读数不稳', Judgment.score(rubric, moving).deductions
    .some((d) => d.metric === 'maxRecordSpeed'), '');
  const noUnload = new FactSheet();
  noUnload.set('unloadSteps', 0);
  assertTrue('只加不减 → 判缺卸载对照', Judgment.score(rubric, noUnload).deductions
    .some((d) => d.metric === 'unloadSteps'), '');

  // 关键一条:细则必须能被「认真做实验」满足,否则它是台永远扣光的机器
  const proper = new SpringForceRunner();
  proper.setup(ExperimentRegistry.find('spring-force').meta);
  proper.setParam('stiffness', K);
  proper.setParam('panMass', PAN);
  proper.setParam('weightMass', EACH);
  for (const n of [1, 2, 3, 4]) {
    while (Math.round(proper.readObservable('weights')) !== n) { proper.doAction('weight+'); }
    run(proper, 6);
    proper.doAction('record');
  }
  for (const n of [3, 2, 1]) {
    while (Math.round(proper.readObservable('weights')) !== n) { proper.doAction('weight-'); }
    run(proper, 6);
    proper.doAction('record');
  }
  const properFacts = new FactSheet();
  proper.collectFacts(properFacts);
  const properCard = Judgment.score(rubric, properFacts);
  check('认真做完(四档增挂+三档卸载对照、每档静止后记录)不扣分',
    properCard.deductions.length, 0, 0);
  if (properCard.deductions.length) {
    console.log('  意外扣分:', properCard.deductions.map((d) => `${d.metric}=${d.value}`));
  }
  check('满分记录的分值 = 满分', properCard.awarded, rubric.totalPoints, 0);
  assertTrue('认真做完至少留下 7 条读数(四挡增挂 + 三挡卸载对照)',
    properFacts.num('recordCount') >= 7, `实得 ${properFacts.num('recordCount')}`);

  // 场景元数据:动作按钮与 F-x 图都得是数据,外壳不该为这条实验写特判
  const sm = ExperimentRegistry.find('spring-force').meta;
  assertTrue('场景声明了离散动作', sm.actions.length >= 3, `实得 ${sm.actions.length}`);
  check('每个动作都有 key 与 label',
    sm.actions.filter((a) => a.key.length === 0 || a.label.length === 0).length, 0, 0);
  const fx = sm.charts.find((c) => c.xKey === 'force');
  assertTrue('F-x 图以观测量 force 作横轴', fx !== undefined && fx.series.length > 0, '');
  const keys = sm.observables.map((o) => o.key);
  check('图线引用的键都在观测量里',
    [fx.xKey].concat(fx.series.map((s) => s.observableKey)).filter((k) => k !== 't' && keys.indexOf(k) < 0).length, 0, 0);
  // 场景声明了细则 id,注册表就必须认得它 —— 否则「交卷」按钮按下去是空的,
  // 而地图那条实验会被当成"有细则"报出去。
  const { Rubrics } = require(join(OUT, 'bench/RubricMeasure.cjs'));
  const declared = metas.filter((m) => m.rubricId.length > 0);
  const unresolved = declared.filter((m) => Rubrics.byId(m.rubricId) === null);
  check('声明了 rubricId 的场景都能解析到细则', unresolved.length, 0, 0);
  if (unresolved.length) { console.log('  解析不到:', unresolved.map((m) => `${m.id}→${m.rubricId}`)); }
  assertTrue('弹簧场景确实声明了细则', sm.rubricId.length > 0, 'rubricId 为空');
}

// ---- 图线区高度:手机档两张图各 90vp 时 frame 算出来是负数,于是静默不画(E2) ----
// 这条断言先把「旧尺寸确实画不出」钉住,再钉「新尺寸画得出」——
// 只测新值的话,谁都不知道 90vp 为什么不行,下次还会被压回去。
{
  const { PlotLayout } = require(join(OUT, 'view/PlotFrame.cjs'));
  const { DeviceClass, Layout } = require(join(OUT, 'common/Layout.cjs'));

  // 手机档图线宿主宽约 350vp(1256px/3.25 减掉卡片内边距)
  const phoneW = 350;
  const old = PlotLayout.frameFor(phoneW, 90);
  assertTrue('旧的 90vp 每图高度确实画不出(这就是 E2 的根因)', !PlotLayout.drawable(old),
    `frame.height=${old.height.toFixed(1)}`);

  for (const [cls, w] of [[DeviceClass.PHONE, 350], [DeviceClass.PAD, 520], [DeviceClass.LARGE, 900]]) {
    const per = Layout.chartHeight(cls);
    const f = PlotLayout.frameFor(w, per);
    assertTrue(`${cls} 单张图 ${per}vp 必须画得出`, PlotLayout.drawable(f),
      `frame.height=${f.height.toFixed(1)}`);
    assertTrue(`${cls} 绘图区净高 ≥ ${PlotLayout.MIN_PLOT}vp`, f.height >= PlotLayout.MIN_PLOT,
      `实得 ${f.height.toFixed(1)}`);
  }
  // 两张图不能靠"平分固定高度"来放:总高必须按图数给,可视窗再截断滚动
  const two = Layout.chartAreaHeight(DeviceClass.PHONE, 2);
  assertTrue('两张图的图线区按图数给高(不再平分一个固定值)',
    two >= 2 * Layout.chartHeight(DeviceClass.PHONE), `实得 ${two}`);
  assertTrue('图线可视窗不超过两张图的高度(多出来的靠滚动)',
    Layout.chartViewportHeight(DeviceClass.PHONE, 4) <= 2.4 * Layout.chartHeight(DeviceClass.PHONE),
    `实得 ${Layout.chartViewportHeight(DeviceClass.PHONE, 4)}`);
  // E3:开图线把 2D 画面挤成一条,画布必须有下限
  for (const [cls, floor] of [[DeviceClass.PHONE, 200], [DeviceClass.PAD, 230], [DeviceClass.LARGE, 260]]) {
    assertTrue(`${cls} 画布最小高度守住 ${floor}vp 下限`, Layout.minSceneHeight(cls) >= floor,
      `实得 ${Layout.minSceneHeight(cls)}`);
    assertTrue(`${cls} 画布下限在阶梯上`, Layout.onLadder(Layout.minSceneHeight(cls)) ||
      [210, 240, 280].indexOf(Layout.minSceneHeight(cls)) >= 0, `实得 ${Layout.minSceneHeight(cls)}`);
  }
  // 太矮时不许静默:必须给出可读的说明文案
  assertTrue('画不出时必须有说明而不是静默返回', PlotLayout.hintFor(phoneW, 90).length > 6, '');
}

// ---- 内容更新通道:解码器与覆盖表(W1-2)----------------------------------
// 把内容从"只能编译期"放开到"可被一份 JSON 覆盖",代价是多一个运行时入口。
// 所以这一节的规矩只有一条:任何进得来的数据,必须过与编译期同等的校验,
// 且坏数据永远不许盖住内置表 —— 否则更新通道就成了绕过 MapValidator 的后门。
{
  const { ContentCodec, ContentOverride } = require(join(OUT, 'content/map/ContentCodec.cjs'));
  const { SchoolPhysics } = require(join(OUT, 'content/map/SchoolPhysics.cjs'));
  const { UniversityPhysics } = require(join(OUT, 'content/map/UniversityPhysics.cjs'));
  const { CurriculumIndex } = require(join(OUT, 'content/map/CurriculumIndex.cjs'));
  const { MapSubject, UNVERIFIED_PREFIX } = require(join(OUT, 'content/map/CurriculumTypes.cjs'));

  const rows = SchoolPhysics.all();
  const uniCount = UniversityPhysics.all().length;
  const json = ContentCodec.encodeExperiments(rows);
  const back = ContentCodec.decodeExperiments(json);

  check('往返:行数不变', back.rows.length, rows.length, 1e-12);
  checkText('往返:干净数据没有问题清单', back.problems.join(';'), '');
  // 解码失败时 rows 是空的,这里取第一个元素前先兜一下 —— 断言要报"哪条没中",
  // 不能让整个 harness 崩在半路(崩了就连别的失败一起看不见)
  const got0 = back.rows.length > 0 ? back.rows[0] : { id: '(没解出任何行)', title: '', source: '' };
  checkText('往返:id 对得上', got0.id, rows[0].id);
  checkText('往返:标题对得上', got0.title, rows[0].title);
  checkText('往返:出处对得上', got0.source, rows[0].source);
  // 整表再编码一次必须逐字节相同 —— 少序列化一个字段就会在这里红
  checkText('往返:整表逐字节相同', ContentCodec.encodeExperiments(back.rows), json);

  // 防"两边都是空串所以相等"的假绿:编码结果必须真的有内容
  assertTrue('编码结果不是空串', json.length > 500, `只编出 ${json.length} 个字符`);

  const tampered = (mutate) => {
    const empty = { rows: [], problems: ['上游编码是空串,这条没法注入'] };
    let copy;
    try {
      copy = JSON.parse(json);
    } catch (error) {
      return empty;
    }
    if (!Array.isArray(copy) || copy.length === 0) {
      return empty;
    }
    mutate(copy[0]);
    return ContentCodec.decodeExperiments(JSON.stringify(copy));
  };

  const badFeas = tampered((r) => { r.feasibility = 'runnable-ish'; });
  assertTrue('未知档位被拒(不静默当成某一档)',
    badFeas.problems.length > 0 && badFeas.rows.length === 0, JSON.stringify(badFeas.problems));

  const badStage = tampered((r) => { r.stage = 'middle'; });
  assertTrue('未知学段被拒', badStage.rows.length === 0 && badStage.problems.length > 0,
    JSON.stringify(badStage.problems));

  const noId = tampered((r) => { r.id = ''; });
  assertTrue('缺 id 被拒且报出行号',
    noId.problems.length === 1 && noId.problems[0].includes('第 1 行'), JSON.stringify(noId.problems));

  const dupId = tampered((r) => { r.id = rows[1].id; });
  assertTrue('重复 id 被拒', dupId.rows.length === 0, JSON.stringify(dupId.problems));

  const blankSource = tampered((r) => { r.source = ''; });
  assertTrue('出处为空被拒(MapValidator 的规矩)', blankSource.rows.length === 0,
    JSON.stringify(blankSource.problems));

  const marked = tampered((r) => { r.source = UNVERIFIED_PREFIX + '按通行做法概括'; });
  assertTrue('负对照:标了未核实的行必须能过', marked.rows.length === rows.length,
    JSON.stringify(marked.problems));

  const notJson = ContentCodec.decodeExperiments('{ 这不是 JSON');
  assertTrue('坏 JSON 不抛异常,只报问题',
    notJson.rows.length === 0 && notJson.problems.length > 0, JSON.stringify(notJson.problems));
  assertTrue('空表不算合法内容(不许用空覆盖把地图清空)',
    ContentCodec.decodeExperiments('[]').rows.length === 0, '空数组被当成了合法数据');

  // 覆盖表:只有干净数据才允许盖住内置表
  const physicsBefore = CurriculumIndex.experimentsOf(MapSubject.PHYSICS).length;
  check('覆盖前物理条数 = 中学 + 大学两张内置表', physicsBefore, rows.length + uniCount, 1e-12);
  check('空覆盖被拒', ContentOverride.set('school-physics', []) ? 1 : 0, 0, 1e-12);
  check('内置表未被空覆盖影响', CurriculumIndex.experimentsOf(MapSubject.PHYSICS).length, physicsBefore, 1e-12);
  const oneRow = [rows[0]];
  check('干净覆盖被接受', ContentOverride.set('school-physics', oneRow) ? 1 : 0, 1, 1e-12);
  check('覆盖后物理条数按覆盖走', CurriculumIndex.experimentsOf(MapSubject.PHYSICS).length,
    oneRow.length + uniCount, 1e-12);
  ContentOverride.clear('school-physics');
  check('撤销覆盖后回到内置表', CurriculumIndex.experimentsOf(MapSubject.PHYSICS).length, physicsBefore, 1e-12);

  // 随包发布的那份 JSON 必须与内置表逐字节相同。它由 tools/arch/gen-content.mjs 生成,
  // 手改任何一边都会在这里红 —— 否则"默认值"和"事实来源"就成了两套真相。
  const shipped = join(root, 'entry/src/main/resources/rawfile/content/school-physics.json');
  assertTrue('rawfile 里有随包发布的内容默认值', existsSync(shipped),
    '缺文件:跑一次 node tools/arch/gen-content.mjs');
  if (existsSync(shipped)) {
    checkText('rawfile 默认值与内置表逐字节相同', readFileSync(shipped, 'utf8').trim(), json);
  }
}


// ---- L3 示踪弹 2:探究电流与电压、电阻的关系(phy-jr-017 / ohm-law)--------
// 这个实验的分不在"算对 I=U/R"(电路是求解器算的,学生算不错),而在**控制变量有没有真做**。
// 所以这一节判的是:同一电阻下取过几档**互不相同**的电压、换没换过电阻、
// 换完之后有没有把电压调回同一档、以及第一组读数时滑片在不在最大处。
// 细则必须"能被满足",也要每条都能被触发。
{
  const { ExperimentRegistry } = require(join(OUT, 'runner/ExperimentRegistry.cjs'));
  const { Rubrics } = require(join(OUT, 'bench/RubricMeasure.cjs'));
  const { RubricOhm } = require(join(OUT, 'bench/RubricOhm.cjs'));
  const { Judgment } = require(join(OUT, 'bench/Judgment.cjs'));
  const { FactLabels } = require(join(OUT, 'model/FactLabels.cjs'));
  const { SessionRecord, fact } = require(join(OUT, 'model/SessionRecord.cjs'));
  const { FactSheet } = require(join(OUT, 'model/FactSheet.cjs'));

  const meta = ExperimentRegistry.find('ohm-law').meta;
  checkText('地图条目 phy-jr-017 配的场景 id', meta.id, 'ohm-law');
  assertTrue('细则能被索引解析到', Rubrics.byId(meta.rubricId) !== null, meta.rubricId);

  /** 一个空电路:参数按元数据默认值,滑片在最大处 */
  function fresh() {
    const runner = ExperimentRegistry.createRunner('ohm-law');
    runner.setup(meta);
    runner.reset();
    runner.setParam('emf', 3);
    runner.setParam('fixed', 5);
    runner.setParam('slide', 20);
    return runner;
  }

  // 1. 电路本身:欧姆定律必须在读数里成立,不然判"控制变量"没有意义
  {
    const r = fresh();
    r.step(1 / 60);
    const u = r.readObservable('U:rx');
    const i = r.readObservable('I:rx');
    checkRel('U/I 等于定值电阻阻值', u / i, 5, 1e-6);
    r.setParam('slide', 0);
    r.step(1 / 60);
    // 差值来自导线级下限电阻(变阻器与电流表各 1e-4 Ω),不是 0 Ω 被当成断路
    assertTrue('滑片滑到最小处时电压升到电源电动势', Math.abs(r.readObservable('U:rx') - 3) < 1e-3,
      String(r.readObservable('U:rx')));
    const atZero = r.readObservable('I:rx');
    assertTrue('滑片滑到最小处时回路仍在走电流', atZero > 0.5, String(atZero));
    r.setParam('fixed', 20);
    r.step(1 / 60);
    // 跟同一滑片位置下的电流比:换大电阻才应当变小,跟滑片还在最大处时比则不成立
    assertTrue('滑片不动、换大电阻后电流变小', r.readObservable('I:rx') < atZero,
      String(r.readObservable('I:rx')));
    checkRel('换电阻后 U/I 仍等于新阻值', r.readObservable('U:rx') / r.readObservable('I:rx'), 20, 1e-6);
  }

  /** 按一份"操作脚本"跑一遍,返回判分结果 */
  function scoreOf(steps) {
    const r = fresh();
    for (const [key, value] of steps) {
      if (key === 'act') {
        r.doAction(value);
      } else {
        r.setParam(key, value);
      }
      r.step(1 / 60);
    }
    const sheet = new FactSheet();
    r.collectFacts(sheet);
    const card = Judgment.score(RubricOhm.create(), sheet);
    return { card: card, sheet: sheet };
  }

  const DILIGENT = [
    ['slide', 20], ['act', 'record'],
    ['slide', 5], ['act', 'record'],
    ['slide', 0], ['act', 'record'],
    ['act', 'fixed+'],
    ['slide', 10], ['act', 'record']
  ];
  const diligent = scoreOf(DILIGENT);
  // 认真做满:三档电压 + 换过电阻 + 换完把电压调回 1.5 V 那一档 → 一分不该扣
  check('认真做完不扣分', diligent.card.awarded, 100, 1e-9);
  check('扣分条数为 0', diligent.card.deductions.length, 0, 1e-12);
  check('同一电阻下最多三档', diligent.sheet.num('ohmMaxPointsAtOneR'), 3, 1e-12);
  check('测过两种电阻', diligent.sheet.num('ohmResistances'), 2, 1e-12);
  check('同电压可比较的档数至少一格', diligent.sheet.num('ohmSharedVoltages') >= 1 ? 1 : 0, 1, 1e-12);
  check('第一组读数时滑片在最大处', diligent.sheet.num('ohmFirstSlide'), 20, 1e-12);

  // 档数按"互不相同"计而不是按按钮次数计:停在同一个滑片位置连按三次,
  // I-U 图上仍然只有一个点。这条是上一条断言的反面 —— 改成数条数它就红。
  const spam = scoreOf([['slide', 20], ['act', 'record'], ['act', 'record'], ['act', 'record']]);
  check('连按三次记录仍只算一档', spam.sheet.num('ohmMaxPointsAtOneR'), 1, 1e-12);
  assertTrue('只刷按钮要被判为档数太少',
    spam.card.deductions.some((d) => d.criterionId === 'ohm-few-voltage-steps'),
    '得分 ' + spam.card.awarded);

  // 2. 每条判据都要能被触发(写出来却永远不红的判据就是死代码)
  const FIRES = [
    ['ohm-no-record', [['slide', 20]]],
    ['ohm-few-voltage-steps', [['slide', 20], ['act', 'record'], ['slide', 5], ['act', 'record']]],
    ['ohm-single-resistance', [['slide', 20], ['act', 'record'], ['slide', 5], ['act', 'record'],
      ['slide', 0], ['act', 'record']]],
    // 换过电阻但每档电压都错开:唯一该扣的是"没把电压调回同一档"
    ['ohm-no-held-voltage', [['slide', 20], ['act', 'record'], ['slide', 5], ['act', 'record'],
      ['slide', 0], ['act', 'record'], ['act', 'fixed+'], ['slide', 15], ['act', 'record']]],
    // 一上来就把滑片推到底再读第一组:其余动作都做全,只留这一处不规范
    ['ohm-slide-not-max', [['slide', 0], ['act', 'record'], ['slide', 5], ['act', 'record'],
      ['slide', 10], ['act', 'record'], ['act', 'fixed+'], ['slide', 10], ['act', 'record']]]
  ];
  for (const [criterionId, steps] of FIRES) {
    const out = scoreOf(steps);
    const hit = out.card.deductions.filter((d) => d.criterionId === criterionId);
    assertTrue('判据 ' + criterionId + ' 能被触发', hit.length === 1,
      '扣分项:' + out.card.deductions.map((d) => d.criterionId).join(',') + ' / 得分 ' + out.card.awarded);
    assertTrue('判据 ' + criterionId + ' 的证据里带上了当时的数',
      /\d/.test(hit.length > 0 ? hit[0].evidence : ''), hit.length > 0 ? hit[0].evidence : '');
  }

  // 一组都没记时,「滑片在第一组读数时的位置」压根没量过 —— 不进事实清单,
  // 报告里也就不会冒出一句「读数时滑片停在 0 Ω」
  {
    const blank = scoreOf([['slide', 5]]);
    assertTrue('没记录时不编出滑片读数', !Number.isFinite(blank.sheet.num('ohmFirstSlide')),
      String(blank.sheet.num('ohmFirstSlide')));
    assertTrue('没记录时不因滑片位置扣分',
      !blank.card.deductions.some((d) => d.criterionId === 'ohm-slide-not-max'),
      blank.card.deductions.map((d) => d.criterionId).join(','));
    checkText('没量过的事实印成破折号', FactLabels.valueText('ohmFirstSlide', Number.NaN), '—');
  }

  // 3. 判分走的是记录回放:事实键全都有人话标签,带单位的按单位印
  {
    const record = new SessionRecord();
    record.rubricId = RubricOhm.ID;
    record.facts = [
      fact('ohmRecordCount', 4),
      fact('ohmMaxPointsAtOneR', 3),
      fact('ohmResistances', 2),
      fact('ohmSharedVoltages', 1),
      fact('ohmFirstSlide', 5)
    ];
    const replayed = Rubrics.factsFor(record);
    check('回放保留记录条数', replayed.num('ohmRecordCount'), 4, 1e-12);
    const labeled = record.facts.every((f) => FactLabels.of(f.key) !== null);
    assertTrue('每个事实键都有显示名', labeled, record.facts.map((f) => f.key).join(','));
    checkText('滑片位置带欧姆单位', FactLabels.valueText('ohmFirstSlide', 5), '5 Ω');
  }
}

// ---- L3 示踪弹 3:测量电源的电动势和内阻(phy-sr-010 / emf-internal-resistance)--
// E 与 r 在这里是被测的未知量,所以判据一条都不读它们,只读学生那几组读数在电流轴上
// 铺成了什么形状:组数、跨度、有没有靠近开路那端、有没有冲出 0.6 A 量程。
{
  const { ExperimentRegistry } = require(join(OUT, 'runner/ExperimentRegistry.cjs'));
  const { Rubrics } = require(join(OUT, 'bench/RubricMeasure.cjs'));
  const { RubricEmf } = require(join(OUT, 'bench/RubricEmf.cjs'));
  const { Judgment } = require(join(OUT, 'bench/Judgment.cjs'));
  const { FactLabels } = require(join(OUT, 'model/FactLabels.cjs'));
  const { SessionRecord, fact } = require(join(OUT, 'model/SessionRecord.cjs'));
  const { FactSheet } = require(join(OUT, 'model/FactSheet.cjs'));

  const meta = ExperimentRegistry.find('emf-internal-resistance').meta;
  checkText('地图条目 phy-sr-010 配的场景 id', meta.id, 'emf-internal-resistance');
  assertTrue('细则能被索引解析到', Rubrics.byId(meta.rubricId) !== null, meta.rubricId);

  /** 一节新电池:E=1.5 V、内阻 1 Ω,电阻箱从默认 20 Ω 起 */
  function fresh() {
    const runner = ExperimentRegistry.createRunner('emf-internal-resistance');
    runner.setup(meta);
    runner.reset();
    runner.setParam('emf', 1.5);
    runner.setParam('box', 20);
    return runner;
  }

  // 1. 电路本身:路端电压必须按 U = E − I·r 掉下来,不然作图法无从谈起
  {
    const r = fresh();
    r.step(1 / 60);
    const i20 = r.readObservable('I:a1');
    const u20 = r.readObservable('U:v1');
    checkRel('20 Ω 挡的电流', i20, 1.5 / 21, 1e-4);
    checkRel('路端电压 = E − I·r', u20, 1.5 - i20 * 1, 1e-3);
    assertTrue('路端电压比电动势低(内阻分掉了一截)', u20 < 1.5 - 0.05, String(u20));
    r.setParam('box', 2);
    r.step(1 / 60);
    const i2 = r.readObservable('I:a1');
    const u2 = r.readObservable('U:v1');
    assertTrue('外电阻减小则电流增大、路端电压下降', i2 > i20 && u2 < u20,
      `I=${i2.toFixed(4)} U=${u2.toFixed(4)}`);
    checkRel('斜率绝对值就是内阻 r', (u20 - u2) / (i2 - i20), 1, 1e-3);
  }

  // 动作改的是模型里的参数,面板那几格要跟着动。设备侧断言盯屏幕,这里钉住模型侧契约:
  // 换挡走的是电阻箱的十进制挡位表,不是等差一步
  const dial = fresh();
  dial.doAction('box-');
  check('减一档把电阻箱拨到 12 Ω', dial.getParam('box'), 12, 1e-9);
  dial.doAction('box+');
  dial.doAction('box+');
  check('加两档拨到 30 Ω', dial.getParam('box'), 30, 1e-9);
  dial.doAction('box+');
  dial.doAction('box+');
  dial.doAction('box+');
  dial.doAction('box+');
  check('挡位表封顶在 100 Ω', dial.getParam('box'), 100, 1e-9);

  /** 按一份"操作脚本"跑一遍,返回判分结果。act 走按钮,set 走滑杆 */
  function scoreOf(steps) {
    const r = fresh();
    for (const [key, value] of steps) {
      if (key === 'act') {
        r.doAction(value);
      } else {
        r.setParam(key, value);
      }
      r.step(1 / 60);
    }
    const sheet = new FactSheet();
    r.collectFacts(sheet);
    const card = Judgment.score(RubricEmf.create(), sheet);
    return { card: card, sheet: sheet };
  }

  const REC = ['act', 'record'];
  // 只用按钮:从 20 Ω 起连减五挡(20→12→8→5→3→2),每挡记一组
  const DILIGENT = [REC, ['act', 'box-'], REC, ['act', 'box-'], REC,
    ['act', 'box-'], REC, ['act', 'box-'], REC, ['act', 'box-'], REC];
  const diligent = scoreOf(DILIGENT);
  check('认真取点不扣分', diligent.card.awarded, 100, 1e-9);
  check('扣分条数为 0', diligent.card.deductions.length, 0, 1e-12);
  check('记了六组', diligent.sheet.num('emfRecordCount'), 6, 1e-12);
  check('电流铺开 0.43 A', diligent.sheet.num('emfCurrentSpread'), 1.5 / 3 - 1.5 / 21, 1e-3);
  check('最小那组已经贴着开路', diligent.sheet.num('emfMinCurrent') < 0.1 ? 1 : 0, 1, 1e-12);
  check('最大那组没冲出量程', diligent.sheet.num('emfMaxCurrent') < 0.6 ? 1 : 0, 1, 1e-12);
  // 电阻箱走十进制挡:连减五挡要落到 2 Ω(I=0.5 A)。等差一步 5 Ω 从 20 起是够不到 2 的
  check('连减五挡落到 2 Ω 挡', diligent.sheet.num('emfMaxCurrent') > 0.4 ? 1 : 0, 1, 1e-12);

  const FIRES = [
    ['emf-few-records', [REC, ['act', 'box-'], REC, ['act', 'box-'], REC]],
    // 点全挤在 16~20 Ω 那一小段:组数够、跨度不够
    ['emf-narrow-current', [REC, ['box', 19], REC, ['box', 18], REC, ['box', 17], REC, ['box', 16], REC]],
    // 只取大电流那半边:四组、跨度也够,但没有一个点靠近纵轴
    ['emf-no-open-end', [['box', 2], REC, ['box', 3], REC, ['box', 5], REC, ['box', 8], REC]],
    // 1 Ω 挡把电流顶到 0.75 A:其余三条都满足,只有量程这条红
    ['emf-over-range', [['box', 1], REC, ['box', 2], REC, ['box', 3], REC, ['box', 5], REC,
      ['box', 20], REC]]
  ];
  for (const [criterionId, steps] of FIRES) {
    const out = scoreOf(steps);
    const hit = out.card.deductions.filter((d) => d.criterionId === criterionId);
    assertTrue('判据 ' + criterionId + ' 能被触发', hit.length === 1,
      '扣分项:' + out.card.deductions.map((d) => d.criterionId).join(',') + ' / 得分 ' + out.card.awarded);
    assertTrue('判据 ' + criterionId + ' 的证据里带上了当时的数',
      /\d/.test(hit.length > 0 ? hit[0].evidence : ''), hit.length > 0 ? hit[0].evidence : '');
  }

  // 一组都没记:电流的最小/最大值压根没量过,不许拿 0 冒充,也不许因此扣"靠近开路"那条
  {
    const blank = scoreOf([['box', 5]]);
    assertTrue('没记录时不编出最大电流', !Number.isFinite(blank.sheet.num('emfMaxCurrent')),
      String(blank.sheet.num('emfMaxCurrent')));
    assertTrue('没记录时不因"没有开路点"扣分',
      !blank.card.deductions.some((d) => d.criterionId === 'emf-no-open-end'),
      blank.card.deductions.map((d) => d.criterionId).join(','));
    check('跨度按 0 算(一段都没有)', blank.sheet.num('emfCurrentSpread'), 0, 1e-12);
    checkText('没量过的事实印成破折号', FactLabels.valueText('emfMinCurrent', Number.NaN), '—');
  }

  {
    const record = new SessionRecord();
    record.rubricId = RubricEmf.ID;
    record.facts = [
      fact('emfRecordCount', 6),
      fact('emfCurrentSpread', 0.429),
      fact('emfMaxCurrent', 0.5),
      fact('emfMinCurrent', 0.071)
    ];
    const replayed = Rubrics.factsFor(record);
    check('回放保留记录条数', replayed.num('emfRecordCount'), 6, 1e-12);
    const labeled = record.facts.every((f) => FactLabels.of(f.key) !== null);
    assertTrue('每个事实键都有显示名', labeled, record.facts.map((f) => f.key).join(','));
    checkText('电流读数带安培单位', FactLabels.valueText('emfMaxCurrent', 0.5), '0.50 A');
  }
}

// ---- 共用件:打点计时器与纸带(phy-sr-003 / tape-cart,后面 sr-006、sr-008 复用它)----
// 这条实验的分在"纸带是怎么来的":先通电还是先放车、开头密着的一段舍没舍、
// 按所选间隔能不能切出四段做逐差。a 的数值本身要学生填进来才判得了(#61),这里不判。
{
  const { ExperimentRegistry } = require(join(OUT, 'runner/ExperimentRegistry.cjs'));
  const { Rubrics } = require(join(OUT, 'bench/RubricMeasure.cjs'));
  const { RubricTape } = require(join(OUT, 'bench/RubricTape.cjs'));
  const { Judgment } = require(join(OUT, 'bench/Judgment.cjs'));
  const { FactLabels } = require(join(OUT, 'model/FactLabels.cjs'));
  const { FactSheet } = require(join(OUT, 'model/FactSheet.cjs'));
  const { TickerTape } = require(join(OUT, 'physics/TickerTape.cjs'));

  const meta = ExperimentRegistry.find('tape-cart').meta;
  checkText('地图条目 phy-sr-003 配的场景 id', meta.id, 'tape-cart');
  assertTrue('细则能被索引解析到', Rubrics.byId(meta.rubricId) !== null, meta.rubricId);

  /** 打点计时器的纯模型:等间隔、只有通电才打、先放车就漏头 */
  {
    const tape = new TickerTape();
    tape.setPower(true, 0);
    tape.release(0);
    for (let i = 0; i <= 300; i++) {
      tape.tick(i / 60, 0.5 * 0.8 * (i / 60) * (i / 60), 0.8 * (i / 60), 0.8);
    }
    // 50 Hz × 5 s = 250 个点左右(末点是否落进这一格取决于相位)
    assertTrue('5 秒打出约 250 个点', tape.count() >= 248 && tape.count() <= 251, String(tape.count()));
    const d0 = tape.spacing(0);
    const d1 = tape.spacing(1);
    assertTrue('匀加速下相邻点距单调变疏', d1 > d0, `${d0.toFixed(5)} → ${d1.toFixed(5)}`);
    // 从静止起、等时间间隔的位移比是 1:3:5:7 —— 逐差法的算本就是这个
    const r13 = tape.spacing(1) / tape.spacing(0);
    checkRel('第二段/第一段 ≈ 3(初速为零的等时间间隔位移比)', r13, 3, 0.05);
    const off = new TickerTape();
    off.release(0);
    for (let i = 0; i < 120; i++) off.tick(i / 60, 0, 0, 0);
    check('没通电一个点也不打', off.count(), 0, 1e-12);
    off.setPower(true, 2);
    check('两秒后才通电,头一段漏了 100 个点', off.lostHeadDots(), 100, 1e-9);

    // 逐差法本体:每 5 个点取一个计数点,前 3 段与后 3 段对应相减。
    // 恒加速度下这个还原是**精确**的(误差只来自浮点),所以容差给到 1e-6 ——
    // 它是第 6 条实验(a 由纸带逐差法求得)唯一的算本,算错了整条实验都在教错的东西。
    checkRel('逐差法从纸带还原出 a', tape.accelByChunking(0, 5, 3), 0.8, 1e-6);
    checkRel('换个起点照样还原出 a', tape.accelByChunking(20, 5, 3), 0.8, 1e-6);
    assertTrue('段数不够逐差时不报数',
      Number.isNaN(tape.accelByChunking(0, 5, 40)), String(tape.accelByChunking(0, 5, 40)));
  }

  /** 跑一遍操作脚本:act 按按钮,step 走多少帧,其余当参数拖 */
  function run(steps) {
    const runner = ExperimentRegistry.createRunner('tape-cart');
    runner.setup(meta);
    runner.reset();
    for (const [key, value] of steps) {
      if (key === 'act') {
        runner.doAction(value);
      } else if (key === 'run') {
        for (let i = 0; i < value; i++) runner.step(1 / 60);
      } else {
        runner.setParam(key, value);
      }
    }
    const sheet = new FactSheet();
    runner.collectFacts(sheet);
    const card = Judgment.score(RubricTape.create(), sheet);
    return { runner: runner, card: card, sheet: sheet };
  }

  // 1. 认真做:先通电待稳定,再释放;舍开头 20 个点,每 5 点取一个计数点
  const good = run([['act', 'power'], ['run', 6], ['act', 'release'], ['run', 130]]);
  check('纸带上的点够多', good.sheet.num('tapeDotCount') > 70 ? 1 : 0, 1, 1e-12);
  check('切得出四段以上', good.sheet.num('tapeSegments') >= 4 ? 1 : 0, 1, 1e-12);
  check('最短一段读得出来', good.sheet.num('tapeShortestMm') >= 2 ? 1 : 0, 1, 1e-12);
  check('头一段没漏', good.sheet.num('tapeLostHead'), 0, 1e-12);
  check('认真做一分不扣', good.card.awarded, 100, 1e-9);
  check('扣分条数为 0', good.card.deductions.length, 0, 1e-12);
  // 小车走满 1.2 m 的坡:纸带长度应当与位移同量级(不是被放大后的画图坐标)
  const span = good.runner.readObservable('tapeSpanMm');
  assertTrue('纸带打出来的长度不超过木板', span > 0 && span <= 1200, String(span));
  assertTrue('画面上点距按 6 倍展开', span * 6 > 300, String(span));

  // 2. 四条判据各自能被触发,而且各自只被自己那一处不规范触发
  const FIRES = [
    ['tape-few-dots', [['act', 'power'], ['act', 'release'], ['run', 4]]],
    // 先放车、半秒后才想起通电
    ['tape-lost-head', [['act', 'release'], ['run', 30], ['act', 'power'], ['run', 100]]],
    // 一个点都没舍:第一段还是小车静止时打出来的重叠点
    ['tape-crowded-start', [['act', 'power'], ['run', 6], ['act', 'release'], ['run', 130],
      ['countStart', 0], ['countEvery', 1]]],
    // 每 10 个点才取一个,80 个点只够切 8 段 —— 改成起点放到 45 之后只剩 3 段
    ['tape-few-segments', [['act', 'power'], ['act', 'release'], ['run', 130],
      ['countStart', 45], ['countEvery', 10]]],
  ];
  for (const [criterionId, steps] of FIRES) {
    const out = run(steps);
    const hit = out.card.deductions.filter((d) => d.criterionId === criterionId);
    assertTrue('判据 ' + criterionId + ' 能被触发', hit.length === 1,
      '扣分项:' + out.card.deductions.map((d) => d.criterionId).join(',') + ' / 得分 ' + out.card.awarded);
    assertTrue('判据 ' + criterionId + ' 的证据里带上了当时的数',
      /\d/.test(hit.length > 0 ? hit[0].evidence : ''), hit.length > 0 ? hit[0].evidence : '');
  }

  // 3. 纸带画在画面上:点数进快照的圆里,计数点用放大蓝点标出
  {
    const snap = good.runner.snapshot();
    const dots = snap.circles.filter((c) => Math.abs(c.cy - 4.9) < 1e-9);
    assertTrue('纸带上的点被画出来', dots.length >= 60, `实得 ${dots.length} 个`);
    const marks = dots.filter((c) => c.r > 0.03);
    assertTrue('计数点被放大标出', marks.length >= 5, `实得 ${marks.length} 个`);
    const spread = dots.map((c) => c.cx).sort((a, b) => a - b);
    assertTrue('画出来的跨度大于一个板长(6 倍展开)', spread[spread.length - 1] - spread[0] > 1.5,
      String(spread[spread.length - 1] - spread[0]));
    // 点距必须一路变疏:车越滑越快,同一个 0.02 s 里走的距离只会更大。
    // 只管到倒数第二段 —— 最后那一个点被"走到坡底"截断,本来就比理论间隔短,
    // 真纸带走到头也是这样(实测末段 0.123 对上一段 0.171,差值正好是被底端吃掉的那点位移)。
    let monoton = true;
    let worst = '';
    for (let i = 1; i + 1 < spread.length; i++) {
      const gap = spread[i] - spread[i - 1];
      const prev = i > 1 ? spread[i - 1] - spread[i - 2] : gap;
      if (gap < prev - 1e-6) {
        monoton = false;
        worst = `第 ${i} 个间隔 ${gap.toFixed(4)} 比上一段 ${prev.toFixed(4)} 还窄`;
        break;
      }
    }
    assertTrue('纸带上的点一路变疏', monoton, worst);
  }

  // 4. 没打点时:最短段没量过 → 不进事实清单,不扣"过密"那条
  {
    const blank = run([['run', 30]]);
    assertTrue('没打点时不报最短段', !Number.isFinite(blank.sheet.num('tapeShortestMm')),
      String(blank.sheet.num('tapeShortestMm')));
    assertTrue('没打点时不因"过密"扣分',
      !blank.card.deductions.some((d) => d.criterionId === 'tape-crowded-start'),
      blank.card.deductions.map((d) => d.criterionId).join(','));
    check('一条都没打就判点太少', blank.card.deductions.some((d) => d.criterionId === 'tape-few-dots') ? 1 : 0, 1, 1e-12);
    checkText('没量过的事实印成破折号', FactLabels.valueText('tapeShortestMm', Number.NaN), '—');
  }
}

// ---- L3 示踪弹 4:验证机械能守恒定律(phy-sr-008 / free-fall)----------------
// 纸带那条共用件在这里第二次被接上:同一套打点与计数约定,换成一维落体与铁架台。
// 判分只有三条,全读纸带本身 —— ΔEp 与 ΔEk 各是多少要学生填进来才判得了(#61)。
{
  const { ExperimentRegistry } = require(join(OUT, 'runner/ExperimentRegistry.cjs'));
  const { Rubrics } = require(join(OUT, 'bench/RubricMeasure.cjs'));
  const { RubricEnergy } = require(join(OUT, 'bench/RubricEnergy.cjs'));
  const { Judgment } = require(join(OUT, 'bench/Judgment.cjs'));
  const { FactLabels } = require(join(OUT, 'model/FactLabels.cjs'));
  const { FactSheet } = require(join(OUT, 'model/FactSheet.cjs'));

  const meta = ExperimentRegistry.find('free-fall').meta;
  checkText('地图条目 phy-sr-008 配的场景 id', meta.id, 'free-fall');
  assertTrue('细则能被索引解析到', Rubrics.byId(meta.rubricId) !== null, meta.rubricId);

  function run(steps) {
    const runner = ExperimentRegistry.createRunner('free-fall');
    runner.setup(meta);
    runner.reset();
    for (const [key, value] of steps) {
      if (key === 'act') {
        runner.doAction(value);
      } else if (key === 'run') {
        for (let i = 0; i < value; i++) runner.step(1 / 60);
      } else {
        runner.setParam(key, value);
      }
    }
    const sheet = new FactSheet();
    runner.collectFacts(sheet);
    const card = Judgment.score(RubricEnergy.create(), sheet);
    return { runner: runner, card: card, sheet: sheet };
  }

  const FALL = ['run', 60];
  const good = run([['act', 'power'], ['act', 'release'], FALL]);
  // 1. 落体本身:默认 0.5 kg、阻力 0.1 N → a = 9.6 m/s²,落 1 m 约 0.46 s
  checkRel('下落加速度 = g − F/m', good.runner.readObservable('acceleration'), 9.6, 0.02);
  check('落到设定高度就停', good.runner.readObservable('dropHeight'), 1, 1e-9);
  checkRel('v² = 2ah(恒加速度下的精确更新,不留积分余量)',
    Math.pow(good.runner.readObservable('velocity'), 2) / (2 * 9.6 * 1), 1, 1e-9);
  checkRel('减少的重力势能 = mgh', good.runner.readObservable('potentialLost'), 0.5 * 9.8 * 1, 1e-6);
  assertTrue('增加的动能略小于减少的势能(阻力做负功)',
    good.runner.readObservable('kineticGained') < good.runner.readObservable('potentialLost'),
    `ΔEk=${good.runner.readObservable('kineticGained').toFixed(3)} ΔEp=${good.runner.readObservable('potentialLost').toFixed(3)}`);
  checkRel('两者之差就是阻力做的功',
    good.runner.readObservable('potentialLost') - good.runner.readObservable('kineticGained'),
    good.runner.readObservable('dragWork'), 0.02);
  checkRel('相对偏差 ≈ 阻力功 / ΔEp', good.runner.readObservable('energyGapPct'),
    (0.1 * 1) / (0.5 * 9.8 * 1) * 100, 0.06);

  // 2. 认真做满:一分不扣
  check('纸带上的点够多', good.sheet.num('tapeDotCount') >= 10 ? 1 : 0, 1, 1e-12);
  check('第一对点约 2 mm(初速度为零)', good.sheet.num('tapeFirstGapMm') < 2.6 ? 1 : 0, 1, 1e-12);
  check('切得出三段以上', good.sheet.num('tapeSegments') >= 3 ? 1 : 0, 1, 1e-12);
  check('认真做完不扣分', good.card.awarded, 100, 1e-9);
  check('扣分条数为 0', good.card.deductions.length, 0, 1e-12);

  // 3. 三条各自能被触发
  const FIRES = [
    ['energy-few-dots', [['act', 'power'], ['act', 'release'], ['run', 5]]],
    // 先松手、半秒后才想起通电:第一个点打下时重锤已经在动
    ['energy-not-from-rest', [['act', 'release'], ['run', 10], ['act', 'power'], FALL]],
    // 每 10 个点才取一个,二十来个点只够切两段
    ['energy-few-segments', [['act', 'power'], ['act', 'release'], FALL, ['countEvery', 10]]],
  ];
  for (const [criterionId, steps] of FIRES) {
    const out = run(steps);
    const hit = out.card.deductions.filter((d) => d.criterionId === criterionId);
    assertTrue('判据 ' + criterionId + ' 能被触发', hit.length === 1,
      '扣分项:' + out.card.deductions.map((d) => d.criterionId).join(',') + ' / 得分 ' + out.card.awarded);
    assertTrue('判据 ' + criterionId + ' 的证据里带上了当时的数',
      /\d/.test(hit.length > 0 ? hit[0].evidence : ''), hit.length > 0 ? hit[0].evidence : '');
  }

  // 4. 一条都没打:「第一对点间距」没量过 → 不进事实清单,也不扣"初速度不为零"
  {
    const blank = run([['run', 30]]);
    assertTrue('没打点时不报第一对间距', !Number.isFinite(blank.sheet.num('tapeFirstGapMm')),
      String(blank.sheet.num('tapeFirstGapMm')));
    assertTrue('没打点时不因初速度扣分',
      !blank.card.deductions.some((d) => d.criterionId === 'energy-not-from-rest'),
      blank.card.deductions.map((d) => d.criterionId).join(','));
    checkText('没量过的事实印成破折号', FactLabels.valueText('tapeFirstGapMm', Number.NaN), '—');
  }

  // 5. 共用件真的被复用:同一条 TapeStrip 画法,点落在纸带那条线上
  {
    const snap = good.runner.snapshot();
    const dots = snap.circles.filter((c) => Math.abs(c.cy - 4.75) < 1e-9);
    assertTrue('纸带画在落体场景里', dots.length >= 10, `实得 ${dots.length} 个`);
    const xs = dots.map((c) => c.cx).sort((a, b) => a - b);
    let opening = true;
    let where = '';
    for (let i = 2; i + 1 < xs.length; i++) {
      if (xs[i] - xs[i - 1] < xs[i - 1] - xs[i - 2] - 1e-6) {
        opening = false;
        where = `第 ${i} 个间隔 ${xs[i] - xs[i - 1]} 比上一段 ${xs[i - 1] - xs[i - 2]} 还窄`;
        break;
      }
    }
    assertTrue('落体的点一路变疏(末段被落地截断除外)', opening, where);
  }
}

// ---- L3 示踪弹 5:测量物体运动的速度(phy-jr-007 / stopwatch-cart)-----------
// 初中第一条力学场景。手里那只是停表,不是打点计时器:按下记起点与时刻,松开记终点与时长。
// 判的是"按"的后果 —— 按几次、覆盖几段不同区间、最长一段走得到多久(反应时间占进去多少)。
{
  const { ExperimentRegistry } = require(join(OUT, 'runner/ExperimentRegistry.cjs'));
  const { Rubrics } = require(join(OUT, 'bench/RubricMeasure.cjs'));
  const { RubricSpeed } = require(join(OUT, 'bench/RubricSpeed.cjs'));
  const { Judgment } = require(join(OUT, 'bench/Judgment.cjs'));
  const { FactLabels } = require(join(OUT, 'model/FactLabels.cjs'));
  const { FactSheet } = require(join(OUT, 'model/FactSheet.cjs'));

  const meta = ExperimentRegistry.find('stopwatch-cart').meta;
  checkText('地图条目 phy-jr-007 配的场景 id', meta.id, 'stopwatch-cart');
  assertTrue('细则能被索引解析到', Rubrics.byId(meta.rubricId) !== null, meta.rubricId);

  /** 默认 7°、1.5 m、μ=0.05 → a≈0.708 m/s²,走完全程约 2.06 s、半程约 1.46 s */
  const A = 9.8 * (Math.sin(7 * Math.PI / 180) - 0.05 * Math.cos(7 * Math.PI / 180));
  const T_FULL = Math.sqrt(2 * 1.5 / A);
  const T_HALF = Math.sqrt(2 * 0.75 / A);

  /** act 按按钮,run 走多少帧,reset 让车重来(记录本不清),其余当参数拖 */
  function run(steps) {
    const runner = ExperimentRegistry.createRunner('stopwatch-cart');
    runner.setup(meta);
    for (const [key, value] of steps) {
      if (key === 'act') {
        runner.doAction(value);
      } else if (key === 'run') {
        for (let i = 0; i < value; i++) runner.step(1 / 60);
      } else if (key === 'reset') {
        runner.reset();
      } else {
        runner.setParam(key, value);
      }
    }
    const sheet = new FactSheet();
    runner.collectFacts(sheet);
    const card = Judgment.score(RubricSpeed.create(), sheet);
    return { runner: runner, card: card, sheet: sheet };
  }

  const START = ['act', 'timeStart'];
  const STOP = ['act', 'timeStop'];
  const HALF = Math.round(T_HALF * 60);
  const FULL = Math.round(T_FULL * 60);
  const DILIGENT = [START, ['run', HALF], STOP, ['reset'],
    START, ['run', FULL], STOP, ['reset'],
    START, ['run', FULL], STOP];
  const good = run(DILIGENT);

  // 1. 表本身:走的是仿真时间,不是按下按钮那一帧
  check('按完三次', good.sheet.num('speedTrials'), 3, 1e-12);
  check('覆盖两段不同区间', good.sheet.num('speedSegments'), 2, 1e-12);
  checkRel('半程表读数 ≈ √(2s/a)', good.runner.readObservable('speedShortestS'), T_HALF, 0.02);
  checkRel('全程表读数 ≈ √(2L/a)', good.sheet.num('speedLongestS'), T_FULL, 0.02);
  // 平均速度 = 末速度的一半(初速为零的匀加速),这条交叉核对表与位移都对得上
  const vAvg = 0.75 / good.runner.readObservable('speedShortestS');
  checkRel('上半程平均速度 ≈ 末速度的一半', vAvg / (Math.sqrt(2 * A * 0.75) / 2), 1, 0.03);
  // 2. 认真做完不扣分
  check('认真测完不扣分', good.card.awarded, 100, 1e-9);
  check('扣分条数为 0', good.card.deductions.length, 0, 1e-12);
  // 3. 「重置」只让车重来,已抄下的记录不能被抹掉
  const afterReset = run(DILIGENT.concat([['reset']]));
  check('重置后记录还在', afterReset.sheet.num('speedTrials'), 3, 1e-12);
  // 4. 按下了没松开:还没有终点,不算一段
  const open = run([START, ['run', 40]]);
  check('没松开就不算测完', open.sheet.num('speedTrials'), 0, 1e-12);
  check('没松开时段数为 0', open.sheet.num('speedSegments'), 0, 1e-12);
  assertTrue('没松开时表还在走', open.runner.readObservable('watchReading') > 0.5,
    String(open.runner.readObservable('watchReading')));

  const FIRES = [
    ['speed-few-trials', [START, ['run', FULL], STOP]],
    // 三次都测全程:次数够了,但三段速度是同一个数,比较不了
    ['speed-one-segment',
      [START, ['run', FULL], STOP, ['reset'], START, ['run', FULL], STOP, ['reset'],
        START, ['run', FULL], STOP]],
    // 把斜面垫到 40°:三次、三段都够,但最长一段只有 0.71 s,反应时间占进去一成多
    ['speed-too-fast', [['angle', 40], START, ['run', 21], STOP, ['reset'],
      START, ['run', 30], STOP, ['reset'], START, ['run', 43], STOP]],
  ];
  for (const [criterionId, steps] of FIRES) {
    const out = run(steps);
    const hit = out.card.deductions.filter((d) => d.criterionId === criterionId);
    assertTrue('判据 ' + criterionId + ' 能被触发', hit.length === 1,
      '扣分项:' + out.card.deductions.map((d) => d.criterionId).join(',') + ' / 得分 ' + out.card.awarded);
    assertTrue('判据 ' + criterionId + ' 的证据里带上了当时的数',
      /\d/.test(hit.length > 0 ? hit[0].evidence : ''), hit.length > 0 ? hit[0].evidence : '');
  }

  // 5. 一次都没测:「最长一段多久」压根没量过 → 不进事实清单
  {
    const blank = run([['run', 60]]);
    assertTrue('没测时不报最长一段', !Number.isFinite(blank.sheet.num('speedLongestS')),
      String(blank.sheet.num('speedLongestS')));
    assertTrue('没测时不因"太快"扣分',
      !blank.card.deductions.some((d) => d.criterionId === 'speed-too-fast'),
      blank.card.deductions.map((d) => d.criterionId).join(','));
    checkText('没量过的事实印成破折号', FactLabels.valueText('speedLongestS', Number.NaN), '—');
  }

  // 6. 停表画在画面上:表盘 + 读数
  {
    const snap = good.runner.snapshot();
    const dial = snap.circles.filter((c) => Math.abs(c.cx - 0.85) < 1e-9 && Math.abs(c.cy - 4.55) < 1e-9);
    check('画面上有一只停表', dial.length, 1, 1e-12);
    assertTrue('表上印着读数', snap.labels.some((l) => / s$/.test(l.text) && l.align === 'center'),
      snap.labels.map((l) => l.text).join('|'));
  }
}

// ---- L3 示踪弹 6:探究加速度与物体受力、物体质量的关系(phy-sr-006 / newton-second-cart)
// 这条实验有两个别的场景没有的东西:**两体**动力学(绳的拉力不等于砝码桶重力)
// 与**平衡摩擦**(取下桶轻推一次,看空载纸带均不均匀)。判据读的就是这两件。
{
  const { ExperimentRegistry } = require(join(OUT, 'runner/ExperimentRegistry.cjs'));
  const { Rubrics } = require(join(OUT, 'bench/RubricMeasure.cjs'));
  const { RubricNewton } = require(join(OUT, 'bench/RubricNewton.cjs'));
  const { Judgment } = require(join(OUT, 'bench/Judgment.cjs'));
  const { FactLabels } = require(join(OUT, 'model/FactLabels.cjs'));
  const { FactSheet } = require(join(OUT, 'model/FactSheet.cjs'));

  const meta = ExperimentRegistry.find('newton-second-cart').meta;
  checkText('地图条目 phy-sr-006 配的场景 id', meta.id, 'newton-second-cart');
  assertTrue('细则能被索引解析到', Rubrics.byId(meta.rubricId) !== null, meta.rubricId);

  // 与求解器同一套常量:改了器材参数,这里的期望值必须跟着改,不然断言就是在替旧配置背书
  const G = 9.8;
  const MU = 0.08;
  const RISE = 0.16;
  const BOARD = 4.0;
  const CART = 0.2;
  const SLOT = 0.05;
  const BUCKET = 0.005;
  const LOAD = 0.01;
  /** 精确两体解:绳是同一根,加速度由 M+m 一起分 */
  const exactA = (layers, slots, loads) => {
    const sinT = layers * RISE / BOARD;
    const cosT = Math.sqrt(1 - sinT * sinT);
    const m = BUCKET + loads * LOAD;
    const M = CART + slots * SLOT;
    return (m * G + M * G * sinT - MU * M * G * cosT) / (M + m);
  };

  function run(steps) {
    const runner = ExperimentRegistry.createRunner('newton-second-cart');
    runner.setup(meta);
    for (const [key, value] of steps) {
      if (key === 'act') {
        runner.doAction(value);
      } else if (key === 'run') {
        for (let i = 0; i < value; i++) runner.step(1 / 60);
      } else if (key === 'reset') {
        runner.reset();
      } else {
        runner.setParam(key, value);
      }
    }
    const sheet = new FactSheet();
    runner.collectFacts(sheet);
    const card = Judgment.score(RubricNewton.create(), sheet);
    return { runner: runner, card: card, sheet: sheet };
  }

  const SET = (slots, loads) => {
    const s = [];
    for (let i = 0; i < slots; i++) s.push(['act', 'slot+']);
    for (let i = 0; i < loads; i++) s.push(['act', 'load+']);
    return s;
  };
  const CLEAR = (slots, loads) => {
    const s = [];
    for (let i = 0; i < loads; i++) s.push(['act', 'load-']);
    for (let i = 0; i < slots; i++) s.push(['act', 'slot-']);
    return s;
  };
  /** 一次测量:重置让纸带从头打,摆好质量,先通电待稳定再放车,走完记一组 */
  const GROUP = (slots, loads) => [['reset']].concat(SET(slots, loads))
    .concat([['act', 'power'], ['run', 6], ['act', 'release'], ['run', 240], ['act', 'record']])
    .concat(CLEAR(slots, loads));
  /** 平衡摩擦那次检查:垫够层数、取下桶、通电后轻推一把,量完再把桶挂回去 */
  const checkSteps = (layers) => {
    const st = [];
    for (let i = 0; i < layers; i++) st.push(['act', 'wedge+']);
    st.push(['act', 'hook'], ['act', 'power'], ['run', 6], ['act', 'push'], ['run', 260]);
    return st.concat([['reset'], ['act', 'hook']]);
  };
  const allGroups = (list) => list.map((g) => GROUP(g[0], g[1])).reduce((a, b) => a.concat(b), []);
  const GROUPS = [[0, 1], [0, 3], [0, 5], [2, 3], [4, 3], [6, 3]];
  const diligent = (layers) => checkSteps(layers).concat(allGroups(GROUPS));

  // 1. 两体解:纸带逐差法读出的 a 必须等于精确解,而且明显低于"把拉力当成 m桶g"的算法
  {
    const out = run(diligent(2));
    for (const [slots, loads] of GROUPS) {
      const one = run([['act', 'wedge+'], ['act', 'wedge+'], ['act', 'power'], ['run', 6]]
        .concat(SET(slots, loads))
        .concat([['act', 'release'], ['run', 240]]));
      const tape = one.runner.readObservable('n2AccelTape');
      checkRel(`逐差法的 a 等于两体精确解(槽码 ${slots} 只、砝码 ${loads} 只)`,
        tape, exactA(2, slots, loads), 2e-3);
      assertTrue(`同一组里"拉力≈m桶g"的算法偏大(槽码 ${slots} 只、砝码 ${loads} 只)`,
        exactA(2, slots, loads) < (BUCKET + loads * LOAD) * G / (CART + slots * SLOT),
        `${exactA(2, slots, loads).toFixed(4)} vs ${((BUCKET + loads * LOAD) * G / (CART + slots * SLOT)).toFixed(4)}`);
    }
    // 桶越重,精确解与"近似"的差越大 —— a-F 图高力端往下弯就是这么来的
    const lightGap = (BUCKET + 1 * LOAD) * G / CART - exactA(2, 0, 1);
    const heavyGap = (BUCKET + 5 * LOAD) * G / CART - exactA(2, 0, 5);
    assertTrue('砝码越多,把拉力当成 m桶g 错得越离谱', heavyGap > lightGap * 2,
      `一档差 ${lightGap.toFixed(3)}、五档差 ${heavyGap.toFixed(3)} m/s²`);
  }

  // 2. 平衡摩擦:两层刚好抵住(点距差不到 0.4 mm),一层与三层都读得出不匀
  {
    const idle = (layers) => {
      const st = [];
      for (let i = 0; i < layers; i++) st.push(['act', 'wedge+']);
      st.push(['act', 'hook'], ['act', 'power'], ['run', 6], ['act', 'push'], ['run', 260]);
      return run(st);
    };
    const balanced = idle(2);
    check('这次检查被记了一次', balanced.sheet.num('n2ChecksDone'), 1, 1e-12);
    const spread = balanced.sheet.num('n2IdleSpreadMm');
    assertTrue('两层垫块时空载点距匀到 0.4 mm 以内', spread >= 0 && spread < 0.4, String(spread));
    assertTrue('两层垫块不因"不匀"扣分',
      !balanced.card.deductions.some((d) => d.criterionId === 'n2-idle-not-uniform'),
      balanced.card.deductions.map((d) => d.criterionId).join(','));
    // 抬得不够:车被静摩擦按住,纸带头上还有几段,后面全叠在一起
    const low = idle(1);
    assertTrue('一层垫块读得出越打越密', low.sheet.num('n2IdleSpreadMm') > 8,
      String(low.sheet.num('n2IdleSpreadMm')));
    const zero = idle(0);
    check('一层没垫也算做过一次检查', zero.sheet.num('n2ChecksDone'), 1, 1e-12);
    assertTrue('完全没垫时检查照样量得出跨度(不能因为车停了就不报数)',
      Number.isFinite(zero.sheet.num('n2IdleSpreadMm')), String(zero.sheet.num('n2IdleSpreadMm')));
    const high = idle(3);
    assertTrue('三层垫块读得出越打越疏', high.sheet.num('n2IdleSpreadMm') > 8,
      String(high.sheet.num('n2IdleSpreadMm')));
    // 静摩擦该扛住的时候必须真扛住:不挂桶、不垫板,推一下之后车要停下而不是倒着走
    const stuck = idle(0);
    check('停在起点附近不再动', stuck.runner.readObservable('distance') < 0.2 ? 1 : 0, 1, 1e-12);
    assertTrue('速度不会自己翻向', stuck.runner.readObservable('velocity') >= 0,
      String(stuck.runner.readObservable('velocity')));
  }

  // 2b. 人手没那么快:通电之后隔一秒才按第二下,头上那一段重叠点不该进量窗
  {
    const slow = run([['act', 'wedge+'], ['act', 'wedge+'], ['act', 'hook'],
      ['act', 'power'], ['run', 60], ['act', 'push'], ['run', 260]]);
    assertTrue('慢一秒按下的那次检查仍算做过', slow.sheet.num('n2ChecksDone') >= 1,
      String(slow.sheet.num('n2ChecksDone')));
    const spread = slow.sheet.num('n2IdleSpreadMm');
    assertTrue('重叠点不进量窗:两层垫块还是读得出匀速', spread >= 0 && spread < 0.4,
      `实得 ${spread} mm(设备实测漏这一条时读到 30.08 mm)`);
    const slowRun = run([['act', 'wedge+'], ['act', 'wedge+'], ['act', 'load+'], ['act', 'load+'],
      ['act', 'power'], ['run', 60], ['act', 'release'], ['run', 240]]);
    checkRel('慢一秒放车,逐差法照样还原出两体解的 a',
      slowRun.runner.readObservable('n2AccelTape'), exactA(2, 0, 2), 2e-3);
    // 设备实测的那个数:重叠点正好压在默认起点上,一半在原地一半在走
    const mixed = run([['act', 'wedge+'], ['act', 'wedge+'], ['act', 'hook'],
      ['act', 'power'], ['run', 20], ['act', 'push'], ['run', 260]]);
    assertTrue('重叠点跨在量窗边上时也读得出匀速',
      mixed.sheet.num('n2IdleSpreadMm') < 0.4, `实得 ${mixed.sheet.num('n2IdleSpreadMm')} mm`);
    // 一整条都没走:那不该是"a=0 的一组数据",而是没量出来
    // 板子没垫够(一层)、桶又挂着不动力的场景对照:取下桶之后放车,静摩擦把它按住 ——
    // 一整条纸带全叠在原地,那不该是"a=0 的一组数据",而是压根没量出来
    const still = run([['act', 'wedge+'], ['act', 'hook'], ['act', 'power'], ['run', 6],
      ['act', 'release'], ['run', 240], ['act', 'record']]);
    assertTrue('车一步没走时逐差法不报数',
      !Number.isFinite(still.runner.readObservable('n2AccelTape')),
      String(still.runner.readObservable('n2AccelTape')));
    check('这样的组不算"算得出 a 的一组"', still.sheet.num('n2UsableCount'), 0, 1e-12);
  }

  // 3. 认真做完一分不扣
  {
    const good = run(diligent(2));
    check('记下六组', good.sheet.num('n2RecordCount'), 6, 1e-12);
    check('六组都算得出 a', good.sheet.num('n2UsableCount'), 6, 1e-12);
    check('同一质量下换过三档拉力', good.sheet.num('n2ForceSteps'), 3, 1e-12);
    check('同一拉力下试过四种质量', good.sheet.num('n2MassSteps'), 4, 1e-12);
    check('检查做过一次', good.sheet.num('n2ChecksDone'), 1, 1e-12);
    check('认真做完不扣分', good.card.awarded, 100, 1e-9);
    check('扣分条数为 0', good.card.deductions.length, 0, 1e-12);
    // 报告页的"第一次记录读数"用的是动作那一刻,不是交卷那一瞬。
    // 每组开头的「重置」会把时钟归零,所以这里不套整条脚本,单跑一段能对拍的:
    // 按下记录时表上约 1.1 s,之后再空走 2 s 才收事实 —— 收事实那一刻来当时刻就露馅。
    const timed = run([['act', 'wedge+'], ['act', 'wedge+'], ['act', 'load+'], ['act', 'load+'],
      ['act', 'power'], ['run', 6], ['act', 'release'], ['run', 60], ['act', 'record'],
      ['reset'], ['run', 6]]);
    check('时刻是按下记录那一刻,不是交卷那一瞬',
      timed.sheet.at('recorded') > timed.runner.elapsedTime() ? 1 : 0, 1, 1e-12);
    assertTrue('按下记录时表上已走了约 1.1 s', timed.sheet.at('recorded') > 0.8,
      String(timed.sheet.at('recorded')));
    check('一次都没记就不给时刻',
      run([['act', 'power'], ['run', 60]]).sheet.at('recorded'), -1, 1e-12);
  }

  // 4. 五条判据各自能被触发,而且各自只被自己那一处不规范触发
  const FIRES = [
    // 少做一组:五条里只中"组数太少"
    ['n2-records-few', checkSteps(2).concat(allGroups(GROUPS.slice(0, 5)))],
    // 六组只换小车质量、拉力一档没动:组数够,但"改拉力"那一半没做
    ['n2-force-steps-few', checkSteps(2)
      .concat(allGroups([[0, 3], [0, 3], [2, 3], [2, 3], [4, 3], [4, 3], [6, 3]]))],
    // 反过来:六组只换砝码桶,车上槽码一个没动
    ['n2-mass-steps-few', checkSteps(2)
      .concat(allGroups([[0, 1], [0, 1], [0, 3], [0, 3], [0, 5], [0, 5]]))],
    // 一次都没轻推,其余全按认真做来
    ['n2-no-friction-check', (() => {
      const st = [['act', 'wedge+'], ['act', 'wedge+']];
      for (const [slots, loads] of GROUPS) st.push(...GROUP(slots, loads));
      return st;
    })()],
    // 垫一层就去测:组数与两半控制变量都齐,只有摩擦没抵住
    ['n2-idle-not-uniform', diligent(1)],
  ];
  for (const [criterionId, steps] of FIRES) {
    const out = run(steps);
    const hit = out.card.deductions.filter((d) => d.criterionId === criterionId);
    assertTrue('判据 ' + criterionId + ' 能被触发', hit.length === 1,
      '扣分项:' + out.card.deductions.map((d) => d.criterionId).join(',') + ' / 得分 ' + out.card.awarded);
    assertTrue('判据 ' + criterionId + ' 只被自己那一处不规范触发',
      out.card.deductions.length === 1, out.card.deductions.map((d) => d.criterionId).join(','));
    assertTrue('判据 ' + criterionId + ' 的证据里带上了当时的数',
      /\d/.test(hit.length > 0 ? hit[0].evidence : ''), hit.length > 0 ? hit[0].evidence : '');
  }

  // 5. 纸带不够长就记不进"能算的一组":按了记录不等于有一组数据
  {
    const early = run([['act', 'wedge+'], ['act', 'wedge+'], ['act', 'load+'], ['act', 'load+'],
      ['act', 'power'], ['run', 6], ['act', 'release'], ['run', 10], ['act', 'record']]);
    check('按了一次记录', early.sheet.num('n2RecordCount'), 1, 1e-12);
    check('但这条纸带切不出六段', early.sheet.num('n2UsableCount'), 0, 1e-12);
    assertTrue('没段数时不报 a', !Number.isFinite(early.runner.readObservable('n2AccelTape')),
      String(early.runner.readObservable('n2AccelTape')));
    checkText('没量过的事实印成破折号', FactLabels.valueText('n2IdleSpreadMm', Number.NaN), '—');
  }

  // 6. 「重置」只把车放回起点:器材与记录本都不该被清空
  {
    const kept = run(diligent(2).concat([['reset'], ['run', 3]]));
    check('重置后六组还在', kept.sheet.num('n2RecordCount'), 6, 1e-12);
    check('重置后检查还在', kept.sheet.num('n2ChecksDone'), 1, 1e-12);
    check('重置后垫块还垫着两层', kept.runner.readObservable('n2WedgeLayers'), 2, 1e-12);
    check('重置后桶还挂着', kept.runner.readObservable('n2PullMassKg'), BUCKET, 1e-12);
  }

  // 7. 画面上:器材跟着动作变,纸带的点落在纸带那条线上
  {
    const bare = ExperimentRegistry.createRunner('newton-second-cart');
    bare.setup(meta);
    const snap0 = bare.snapshot();
    check('一开始车上没有槽码', snap0.boxes.filter((b) => b.color === '#8E5BD9').length, 0, 1e-12);
    check('一开始板端下面没有垫块', snap0.boxes.filter((b) => b.color === '#C7A44A').length, 0, 1e-12);
    bare.doAction('slot+');
    bare.doAction('slot+');
    bare.doAction('wedge+');
    bare.doAction('wedge+');
    const snap1 = bare.snapshot();
    check('加两只槽码就画两块', snap1.boxes.filter((b) => b.color === '#8E5BD9').length, 2, 1e-12);
    check('加两层垫块就画两块', snap1.boxes.filter((b) => b.color === '#C7A44A').length, 2, 1e-12);
    // 桶挂没挂要看得出来:取下之后那只蓝框与它的悬绳都不该在
    const beforeHook = bare.snapshot();
    bare.doAction('hook');
    const afterHook = bare.snapshot();
    const bucketOf = (snap) => snap.boxes.filter((b) => b.color === '#2F6FB5').length;
    check('挂着时画得出砝码桶', bucketOf(beforeHook), 1, 1e-12);
    check('取下后砝码桶不再画', bucketOf(afterHook), 0, 1e-12);
    assertTrue('板高端比低端高', snap1.segments.some((sg) =>
      sg.color === '#5A6B7F' && sg.y1 > sg.y2), '木板段没有左高右低');

    // 桶走到尽头时应当正好贴在地面线上:画到地板下面去就等于把"桶的落地距离"这条限制画丢了
    const bottomed = run(diligent(2).concat([['reset'], ['act', 'power'], ['run', 6],
      ['act', 'release'], ['run', 300]]));
    const bucket =bottomed.runner.snapshot().boxes.filter((b) => b.color === '#2F6FB5');
    check('跑到尽头时桶还画着', bucket.length, 1, 1e-12);
    assertTrue('桶底不穿到地面线以下', bucket.length > 0 && bucket[0].cy - 0.2 >= 0.5 - 1e-9,
      bucket.length > 0 ? `桶底 ${bucket[0].cy.toFixed(3)} vs 地面 0.5` : '没画桶');
    assertTrue('桶真走到了尽头',bottomed.runner.finished() === true, 'finished 仍为 false');
    // 到头这件事合进桶那一格,不再单开一行 —— 单开那行与读数挤在同一带里撞过
    const bucketTag = bottomed.runner.snapshot().labels.filter((l) => l.text.indexOf('砝码桶') >= 0);
    check('桶那一格只有一条标签', bucketTag.length, 1, 1e-12);
    assertTrue('到头时写在桶那一格里', bucketTag.length > 0 &&
      bucketTag[0].text.indexOf('已降到底') > 0, bucketTag.length > 0 ? bucketTag[0].text : '没有');
    assertTrue('桶的标签留在右侧那一列,不进读数所在的空档',
      bucketTag.length > 0 && bucketTag[0].x > 5.2, bucketTag.length > 0 ? String(bucketTag[0].x) : '');
    // 画布上只留一条状态读数。"板端抬高"那个数改进读数面板:
    // 跟着层数一起写在画布上,那一行就有 20 来个字,右端跨过悬绳压在数字上(截图量过)
    const notes = bottomed.runner.snapshot().labels.filter((l) => l.text.indexOf('s=') === 0);
    check('画面上有一块状态读数', notes.length, 1, 1e-12);
    // 画面里唯一整块空着的地方是两条桌腿之间(桌腿在 x=1.1 与 4.67)。
    // 文字宽度模型层算不出(单位是 vp),所以只能按"起点落在两腿之间"判 —— 压到滑轮或压到桶都出过事
    assertTrue('读数摆在两条桌腿之间的空档里',
      notes.every((l) => l.x > 1.15 && l.x < 4.5), notes.map((l) => l.x.toFixed(2)).join(','));
    assertTrue('读数摆在桌面以下、地面以上',
      notes.every((l) => l.y < 2.9 && l.y > 0.6), notes.map((l) => l.y).join(','));
    assertTrue('板端抬高进读数面板',
      meta.observables.some((o) => o.key === 'n2RiseMm'), '面板里没有这一格');
    check('两层就是 320 mm', bottomed.runner.readObservable('n2RiseMm'), 320, 1e-9);

    const good = run(diligent(2));
    const dots = good.runner.snapshot().circles
      .filter((c) => Math.abs(c.cy - 4.9) < 1e-9 && c.r < 0.05);
    assertTrue('纸带上的点被画出来', dots.length >= 40, `实得 ${dots.length} 个`);
    const xs = dots.map((c) => c.cx).sort((a, b) => a - b);
    let rising = true;
    for (let i = 2; i < xs.length; i++) {
      if (xs[i] - xs[i - 1] < xs[i - 1] - xs[i - 2] - 1e-9) {
        rising = false;
        break;
      }
    }
    assertTrue('挂桶跑的那条纸带一路变疏', rising, xs.length + ' 个点');
  }
}

// ---- L3 示踪弹 7:描绘简谐运动的图像(phy-sr-015 / spring-image)------------------
// 这条的产物就是学生一下一下按出来的那幅图。判三件事:按了几下、覆盖几个周期、
// 描出的折线离真实曲线差多少厘米 —— 最后这件是"采样太稀就走样"唯一能被量的形式。
{
  const { ExperimentRegistry } = require(join(OUT, 'runner/ExperimentRegistry.cjs'));
  const { Rubrics } = require(join(OUT, 'bench/RubricMeasure.cjs'));
  const { RubricImage } = require(join(OUT, 'bench/RubricImage.cjs'));
  const { Judgment } = require(join(OUT, 'bench/Judgment.cjs'));
  const { FactLabels } = require(join(OUT, 'model/FactLabels.cjs'));
  const { FactSheet } = require(join(OUT, 'model/FactSheet.cjs'));

  const meta = ExperimentRegistry.find('spring-image').meta;
  checkText('地图条目 phy-sr-015 配的场景 id', meta.id, 'spring-image');
  assertTrue('细则能被索引解析到', Rubrics.byId(meta.rubricId) !== null, meta.rubricId);
  // 外壳那张自动 x-t 图正是学生要自己描的东西:声明了就等于替他描完
  assertTrue('这条场景不声明自动图线', meta.charts.length === 0,
    `带了 ${meta.charts.length} 张自动图线`);

  const M = 4;
  const K = 2;
  const A = 0.9;
  const W = Math.sqrt(K / M);
  const T = 2 * Math.PI / W;

  function run(steps) {
    const runner = ExperimentRegistry.createRunner('spring-image');
    runner.setup(meta);
    for (const [key, value] of steps) {
      if (key === 'act') {
        runner.doAction(value);
      } else if (key === 'run') {
        for (let i = 0; i < value; i++) runner.step(1 / 60);
      } else if (key === 'reset') {
        runner.reset();
      } else {
        runner.setParam(key, value);
      }
    }
    const sheet = new FactSheet();
    runner.collectFacts(sheet);
    const card = Judgment.score(RubricImage.create(), sheet);
    return { runner: runner, card: card, sheet: sheet };
  }

  /** 每 frames 帧按一次手、连按 times 下:模拟一个手速稳定的学生 */
  const tapEvery = (frames, times) => {
    const s = [];
    for (let i = 0; i < times; i++) s.push(['run', frames], ['act', 'sample']);
    return s;
  };
  const DILIGENT = tapEvery(27, 32);
  const good = run(DILIGENT);

  // 1. 描出来的东西真的进了画面:点数、折线段数、以及"时间越界贴在最右"
  {
    const snap = good.runner.snapshot();
    const dots = snap.circles.filter((c) => c.color === '#E2574C');
    check('按了几下手就画几个点', dots.length, 32, 1e-12);
    check('点按顺序连成折线', snap.segments.filter((g) => g.color === '#2E9E7A').length, 31, 1e-12);
    const xs = dots.map((c) => c.cx).sort((a, b) => a - b);
    assertTrue('点沿横轴从左往右铺', xs[0] < xs[xs.length - 1], `${xs[0]} → ${xs[xs.length - 1]}`);
    // 按 80 下要一分半(每次点击本身一秒多)。横轴若定死 24 s,后半幅的点会叠成
    // 右边界上一条竖线 —— 设备截图里看得见。所以描得久,横轴要跟着一起变长。
    const long = run(tapEvery(27, 120));
    const late = long.runner.snapshot().circles.filter((c) => c.color === '#E2574C')
      .map((c) => c.cx).sort((a, b) => a - b);
    check('描了 120 下', long.sheet.num('imgSamples'), 120, 1e-12);
    assertTrue('点全在画内,没有一个叠到右边界上',
      late[late.length - 1] < 5.7, String(late[late.length - 1]));
    assertTrue('点铺满了横轴的大部分,不是堆在右边界一竖条',
      (late[late.length - 1] - late[0]) / (5.7 - 0.6) > 0.5,
      ((late[late.length - 1] - late[0]) / 5.1).toFixed(3));
    const shortTag = good.runner.snapshot().labels.filter((l) => l.text.indexOf('横轴一格') >= 0);
    const longTag = long.runner.snapshot().labels.filter((l) => l.text.indexOf('横轴一格') >= 0);
    check('描得不久时横轴一格 5 s', shortTag.length > 0 && shortTag[0].text.indexOf('5 s') > 0 ? 1 : 0, 1, 1e-12);
    check('描到 54 s 时横轴自己涨到一格 10 s',
      longTag.length > 0 && longTag[0].text.indexOf('10 s') > 0 ? 1 : 0, 1, 1e-12);
    // 刻度线要真画出来:没有它,"一格几秒"就只是句口号,周期没法从图上量
    check('横轴画了八格刻度', good.runner.snapshot().segments
      .filter((g) => g.color === '#5A6B7F' && Math.abs(g.x2 - g.x1) < 1e-9
        && Math.abs((g.y2 - g.y1) - 0.14) < 1e-9).length,
      8, 1e-12);
    assertTrue('纵轴按真实位移铺:最高与最低差点到 ±振幅',
      Math.abs((Math.max.apply(null, dots.map((c) => c.cy)) - Math.min.apply(null, dots.map((c) => c.cy)))
        - 2 * A * (0.72 / 1.2)) < 0.25,
      '上下铺开 ' + (Math.max.apply(null, dots.map((c) => c.cy)) - Math.min.apply(null, dots.map((c) => c.cy))).toFixed(3));
  }

  // 2. 认真描完一分不扣
  {
    check('按了 32 下', good.sheet.num('imgSamples'), 32, 1e-12);
    checkRel('覆盖约 1.57 个周期', good.sheet.num('imgSpanT'), 31 * 0.45 / T, 0.02);
    assertTrue('失真只有厘米级', good.sheet.num('imgDistortCm') < 3,
      String(good.sheet.num('imgDistortCm')));
    check('认真描完不扣分', good.card.awarded, 100, 1e-9);
    check('扣分条数为 0', good.card.deductions.length, 0, 1e-12);
  }

  // 3. 失真度这个度量本身要站得住:按得越稀,差得越大,而且方向与"半个周期"对得上
  {
    const half8 = run(tapEvery(Math.round(T * 60 / 16), 26)).sheet.num('imgDistortCm');
    const dense = run(tapEvery(Math.round(T * 60 / 8), 20)).sheet.num('imgDistortCm');
    const loose = run(tapEvery(Math.round(T * 60 / 4), 12)).sheet.num('imgDistortCm');
    const aliased = run(tapEvery(Math.round(T * 60 / 2), 12)).sheet.num('imgDistortCm');
    // 间隔足够小时,弦对圆弧的矢高按 Δ² 涨:A(ωΔ)²/8 —— 这是这条度量该有的物理行为,
    // 也是"只比每段两端"那种假实现过不了的一关(那样两个数都会塌到噪声级)
    checkRel('间隔减半,失真约减到四分之一', half8 * 4, dense, 0.35);
    assertTrue('每周期 8 个点还描得出形状(差 < 15 cm)', dense < 15, String(dense));
    assertTrue('每周期 4 个点就越过判分线', loose > 15, String(loose));
    // 每周期只按两下时,折线是一段段直线穿过平衡位置,而真实曲线那时正处在端点附近。
    // 差值不再随间隔猛涨(已被 2A 这个上限压住),但仍在涨,而且稳稳越过 15 cm 这条线
    assertTrue('隔半个周期按一下,失真越过判分线且比四分之一个周期更大',
      aliased > 15 && aliased > loose, `${loose} → ${aliased}`);
    assertTrue('失真不会超过两倍振幅这个物理上限', aliased <= 2 * A * 100 + 1e-6, String(aliased));
  }

  // 4. 三条判据各自能被单独触发
  const FIRES = [
    // 手速够、覆盖够,只是按了 11 下
    ['img-few-samples', tapEvery(80, 11)],
    // 按得密,但只描了约一个周期就停手
    ['img-short-span', tapEvery(27, 21)],
    // 点数与覆盖都够,唯独按得太稀 —— 走样
    ['img-distorted', tapEvery(Math.round(T * 60 / 2), 12)],
  ];
  for (const [criterionId, steps] of FIRES) {
    const out = run(steps);
    const hit = out.card.deductions.filter((d) => d.criterionId === criterionId);
    assertTrue('判据 ' + criterionId + ' 能被触发', hit.length === 1,
      '扣分项:' + out.card.deductions.map((d) => d.criterionId).join(',') + ' / 得分 ' + out.card.awarded);
    assertTrue('判据 ' + criterionId + ' 只被自己那一处不规范触发',
      out.card.deductions.length === 1, out.card.deductions.map((d) => d.criterionId).join(','));
    assertTrue('判据 ' + criterionId + ' 的证据里带上了当时的数',
      /\d/.test(hit.length > 0 ? hit[0].evidence : ''), hit.length > 0 ? hit[0].evidence : '');
  }

  // 5. 一下都没按:除了"点太少",其余三条都拿不到事实,不该跟着扣分
  {
    const blank = run([['run', 300]]);
    check('一个点也没按', blank.sheet.num('imgSamples'), 0, 1e-12);
    assertTrue('没描就不报覆盖几个周期', !Number.isFinite(blank.sheet.num('imgSpanT')),
      String(blank.sheet.num('imgSpanT')));
    assertTrue('没描就不报失真', !Number.isFinite(blank.sheet.num('imgDistortCm')),
      String(blank.sheet.num('imgDistortCm')));
    check('只扣"点太少"这一条', blank.card.deductions.length, 1, 1e-12);
    check('扣完还剩 66 分', blank.card.awarded, 66, 1e-9);
    checkText('没量过的事实印成破折号', FactLabels.valueText('imgDistortCm', Number.NaN), '—');
  }

  // 5b. 描到一半去拖「初始位移」滑杆:那是起跑条件,不该把对照用的真实曲线改掉
  {
    const drift = run(tapEvery(27, 16).concat([['amplitude', 0.3]]).concat(tapEvery(27, 16)));
    checkRel('描出来的形状没变:失真仍是厘米级', drift.sheet.num('imgDistortCm'),
      good.sheet.num('imgDistortCm'), 0.6);
    assertTrue('拖过滑杆之后失真仍远小于判分线', drift.sheet.num('imgDistortCm') < 15,
      String(drift.sheet.num('imgDistortCm')));
  }

  // 6. 「重置」= 换一条纸带:描出来的点清掉,振子回到起点
  {
    const after = run(DILIGENT.concat([['reset'], ['run', 5]]));
    check('重置后纸带空了', after.sheet.num('imgSamples'), 0, 1e-12);
    check('重置后横轴也从零开始', after.runner.readObservable('displacement') > A - 0.02 ? 1 : 0, 1, 1e-12);
  }
}


// ---- L3 示踪弹 8:探究平抛运动的特点(phy-sr-007 / projectile-frame)----------------
// 这条的学生动作只有两下:把卡片挪到第几格、从斜槽第几格静止释放。
// 判的四件事全是这两下留下的后果:描了几个点、有没有先定原点、几次释放是不是同一高度、
// 卡片摆得齐不齐。y/x² 只当读数 —— 它永远被"定没定原点"带着走,当判据就是留一条假判据。
{
  const { ExperimentRegistry } = require(join(OUT, 'runner/ExperimentRegistry.cjs'));
  const { Rubrics } = require(join(OUT, 'bench/RubricMeasure.cjs'));
  const { RubricProjectile } = require(join(OUT, 'bench/RubricProjectile.cjs'));
  const { Judgment } = require(join(OUT, 'bench/Judgment.cjs'));
  const { FactLabels } = require(join(OUT, 'model/FactLabels.cjs'));
  const { FactSheet } = require(join(OUT, 'model/FactSheet.cjs'));

  const meta = ExperimentRegistry.find('projectile-frame').meta;
  checkText('地图条目 phy-sr-007 配的场景 id', meta.id, 'projectile-frame');
  assertTrue('细则能被索引解析到', Rubrics.byId(meta.rubricId) !== null, meta.rubricId);
  // 抛物线本身就是要学生自己检验出来的东西:画出来或给自动图线都等于替他做完
  assertTrue('这条场景不声明自动图线', meta.charts.length === 0,
    `带了 ${meta.charts.length} 张自动图线`);
  // 「每次从同一位置静止释放」与「按水平等间隔取点」只有做成档位才留得下事实
  assertTrue('这条场景一个滑杆也没有', meta.params.length === 0,
    `带了 ${meta.params.length} 个滑杆`);
  check('细则四条各 25 分', RubricProjectile.create().criteria.length, 4, 1e-12);

  const G = 9.8;
  const EXIT_X = 1.15;
  const EXIT_Y = 2.75;
  const SLOT_STEP = 0.05;
  const CARD_STEP = 0.15;
  const FALL = Math.sqrt(2 * (EXIT_Y - 0.4) / G);
  const v0Of = (slot) => Math.sqrt(2 * G * slot * SLOT_STEP);

  /** 每一步都是"按下"而不是"拖到":档位从默认的斜槽第 2 格、卡片第 3 格走 */
  function plan() {
    let slot = 2;
    let card = 3;
    const steps = [];
    const api = {
      steps: steps,
      origin() {
        steps.push(['act', 'origin']);
        return api;
      },
      toSlot(t) {
        while (slot < t) {
          steps.push(['act', 'slot+']);
          slot++;
        }
        while (slot > t) {
          steps.push(['act', 'slot-']);
          slot--;
        }
        return api;
      },
      toCard(t) {
        while (card < t) {
          steps.push(['act', 'card+']);
          card++;
        }
        while (card > t) {
          steps.push(['act', 'card-']);
          card--;
        }
        return api;
      },
      /** 释放一次并跑够落地(0.69 s ≈ 42 帧),默认 50 帧 */
      release(frames) {
        steps.push(['act', 'release']);
        steps.push(['run', frames === undefined ? 50 : frames]);
        return api;
      },
      reset() {
        steps.push(['reset']);
        return api;
      }
    };
    return api;
  }

  function run(steps) {
    const runner = ExperimentRegistry.createRunner('projectile-frame');
    runner.setup(meta);
    for (const [key, value] of steps) {
      if (key === 'act') {
        runner.doAction(value);
      } else if (key === 'run') {
        for (let i = 0; i < value; i++) {
          runner.step(1 / 60);
        }
      } else {
        runner.reset();
      }
    }
    const sheet = new FactSheet();
    runner.collectFacts(sheet);
    const card = Judgment.score(RubricProjectile.create(), sheet);
    return { runner: runner, card: card, sheet: sheet };
  }

  /** 纸上描出来的点,还原成"按抛出点量的坐标" */
  const dotsOf = (runner) => runner.snapshot().circles
    .filter((c) => c.color === '#25313F')
    .map((c) => ({ x: c.cx - EXIT_X, y: EXIT_Y - c.cy }))
    .sort((a, b) => a.x - b.x);

  // 1. 认真做完一分不扣,而且描出来的点真的落在抛物线上
  //    卡片等间隔 → 从抛出点数起的竖直段必须成 1:3:5:7,这条实验要检验的就是它
  const DILIGENT = plan().origin().toSlot(4).toCard(1).release()
    .toCard(2).release().toCard(3).release().toCard(4).release().steps;
  const good = run(DILIGENT);
  const bare = run([['run', 10]]);
  {
    const dots = dotsOf(good.runner);
    check('四次释放描了四个点', dots.length, 4, 1e-12);
    check('按下几次就描几个点,不会一次释放连描一串',
      good.sheet.num('pjPointCount'), 4, 1e-12);
    for (let i = 0; i < dots.length; i++) {
      const wantX = (i + 1) * CARD_STEP;
      const wantY = 0.5 * G * Math.pow(wantX / v0Of(4), 2);
      assertTrue(`第 ${i + 1} 个点横在卡片那一格`, Math.abs(dots[i].x - wantX) < 1e-9,
        String(dots[i].x));
      // y = g/(2v0²)·x² —— 比值恒为 1.25 就是"水平匀速 + 竖直自由落体"的合成结果
      assertTrue(`第 ${i + 1} 个点的 y/x² 等于 g/(2v0²)`,
        Math.abs(dots[i].y - wantY) < 1e-9, `${dots[i].y} vs ${wantY}`);
    }
    checkRel('y/x² 的离散度为 0:原点定对了、高度也没变',
      good.sheet.num('pjRatioErr'), 0, 1e-9);
    const seg = [];
    for (let i = 0; i < dots.length; i++) {
      seg.push(dots[i].y - (i === 0 ? 0 : dots[i - 1].y));
    }
    for (let i = 0; i < seg.length; i++) {
      checkRel(`相等水平间隔的第 ${i + 1} 段竖直 = ${2 * i + 1} 份`,
        seg[i] / seg[0], 2 * i + 1, 1e-9);
    }
    check('认真做完不扣分', good.card.awarded, 100, 1e-9);
    check('扣分条数为 0', good.card.deductions.length, 0, 1e-12);
  }

  // 2. 场景不替学生连轨迹:点描多描少,线段数一个不变
  {
    const originOnly = run(plan().origin().steps);
    const lines = (r) => r.snapshot().segments.length + r.snapshot().frontSegments.length;
    check('没挂线、没描点时的线条数', lines(bare.runner), lines(originOnly.runner) - 1, 1e-12);
    check('描了四个点之后线条数仍不变(没有一条是连出来的)',
      lines(originOnly.runner), lines(good.runner), 1e-12);
    check('画面上只有描下来的点', good.runner.snapshot().circles
      .filter((c) => c.color === '#25313F').length, 4, 1e-12);
    // 重垂线是"定原点"这个动作留下的实物:定了才挂得出来
    // 重垂线、斜槽、卡片导引线都必须画在纸面**之上**:segments 那一层会被不透明的填充件盖掉,
    // 设备截图上表现为"这条线根本没画"(2026-10-15 量到)。
    check('定原点前没有重垂线', bare.runner.snapshot().frontSegments
      .filter((g) => g.color === '#2E9E7A').length, 0, 1e-12);
    check('定原点后就有一条重垂线', good.runner.snapshot().frontSegments
      .filter((g) => g.color === '#2E9E7A').length, 1, 1e-12);
    check('这个场景的线全在纸面之上,底下只剩一条地面线',
      good.runner.snapshot().segments.length, 1, 1e-12);
  }

  // 3. 槽口速度只由释放高度决定:v0² 与格数成正比 —— 这就是"必须同一高度"的所以然
  {
    const s1 = run(plan().toSlot(1).steps).runner.readObservable('pjLaunchSpeed');
    const s2 = run(plan().toSlot(2).steps).runner.readObservable('pjLaunchSpeed');
    const s4 = run(plan().toSlot(4).steps).runner.readObservable('pjLaunchSpeed');
    checkRel('第 2 格是第 1 格的 √2 倍', s2, s1 * Math.SQRT2, 1e-9);
    checkRel('第 4 格是第 2 格的 √2 倍', s4, s2 * Math.SQRT2, 1e-9);
    checkRel('v0² 正比于格数', s4 * s4 / (s1 * s1), 4, 1e-9);
  }

  // 4. 卡片摆到球飞不到的那一格:这一次什么都不该留下,而且要说出来
  {
    const miss = run(plan().toSlot(1).toCard(8).release().steps);
    check('球先落地,卡片那一格什么都没描上', miss.sheet.num('pjPointCount'), 0, 1e-12);
    assertTrue('画面上说明了为什么没描上',
      miss.runner.snapshot().labels.some((l) => l.text.indexOf('球落在卡片之前') >= 0),
      miss.runner.snapshot().labels.map((l) => l.text).join('|'));
    check('这一格卡片离槽口 1.20 m', miss.runner.readObservable('pjCardDistance'), 1.2, 1e-9);
    check('第 1 格只能飞 0.69 m', miss.runner.readObservable('pjRange'),
      v0Of(1) * FALL, 1e-9);
    // 反面对照:同一格释放,摆得近照样描得上 —— 接不住是因为卡片比落点远,不是因为释放高度本身描不了点
    const ok = run(plan().toSlot(1).toCard(4).release().steps);
    check('换到第 4 格就接得住球了', ok.sheet.num('pjPointCount'), 1, 1e-12);
  }

  // 5. 四条判据各自能被单独触发
  const FIRES = [
    // 定好了原点、高度也一致,只是只描了三下
    ['pj-few-points', plan().origin().toSlot(4).toCard(1).release()
      .toCard(2).release().toCard(3).release().steps],
    // 描了四点,但前两下发生在挂重垂线之前(释放高度一直没动)
    ['pj-origin-late', plan().toCard(1).release().toCard(2).release().origin()
      .toCard(5).release().toCard(6).release().steps],
    // 原点定了、间隔也齐,唯独中途换了释放高度
    ['pj-mixed-launch', plan().origin().toSlot(4).toCard(1).release().toCard(3).release()
      .toSlot(3).toCard(5).release().toCard(7).release().steps],
    // 前三格连着描,第四下突然挪到第 8 格
    ['pj-uneven-x', plan().origin().toSlot(4).toCard(1).release().toCard(2).release()
      .toCard(3).release().toCard(8).release().steps],
  ];
  for (const [criterionId, steps] of FIRES) {
    const out = run(steps);
    const hit = out.card.deductions.filter((d) => d.criterionId === criterionId);
    assertTrue('判据 ' + criterionId + ' 能被触发', hit.length === 1,
      '扣分项:' + out.card.deductions.map((d) => d.criterionId).join(',') + ' / 得分 ' + out.card.awarded);
    assertTrue('判据 ' + criterionId + ' 只被自己那一处不规范触发',
      out.card.deductions.length === 1, out.card.deductions.map((d) => d.criterionId).join(','));
    assertTrue('判据 ' + criterionId + ' 的证据里带上了当时的数',
      /\d/.test(hit.length > 0 ? hit[0].evidence : ''), hit.length > 0 ? hit[0].evidence : '');
  }

  // 5b. 换高度那一次,y/x² 立刻散开 25%,但判分只认"没同一高度" —— 读数不偷偷打分
  {
    const mixed = run(FIRES[2][1]);
    checkRel('两条抛物线的点混在一起:y/x² 散开 25%', mixed.sheet.num('pjRatioErr'), 25, 0.02);
    check('这条读数没有多带一条扣分', mixed.card.deductions.length, 1, 1e-12);
  }

  // 5c. 没定原点时按板角量的坐标:y/x² 差到九成,同样只由"原点没定"这一条来扣
  {
    const lateAll = run(plan().toSlot(4).toCard(1).release().toCard(2).release()
      .toCard(3).release().toCard(4).release().steps);
    check('四个点全在定原点之前', lateAll.sheet.num('pjEarlyMarks'), 4, 1e-12);
    assertTrue('按板角量的坐标根本不成正比', lateAll.sheet.num('pjRatioErr') > 50,
      String(lateAll.sheet.num('pjRatioErr')));
    check('基准齐的,间隔比照样报得出数', lateAll.sheet.num('pjXGapRatio'), 1, 1e-9);
    check('仍然只扣"没定原点"一条', lateAll.card.deductions.length, 1, 1e-12);
  }

  // 6. 描了一半才想起挂重垂线:两套基准拼不到一起,两条读数宁可没有值
  //    —— 不能拿一个"基准问题算成间隔问题"的假数去扣间隔那条分
  {
    const half = run(FIRES[1][1]);
    check('定原点前描了两个', half.sheet.num('pjEarlyMarks'), 2, 1e-12);
    assertTrue('混了基准就不报水平间隔比', !Number.isFinite(half.sheet.num('pjXGapRatio')),
      String(half.sheet.num('pjXGapRatio')));
    assertTrue('混了基准就不报 y/x² 离散度', !Number.isFinite(half.sheet.num('pjRatioErr')),
      String(half.sheet.num('pjRatioErr')));
    check('只扣"没定原点"这一条', half.card.deductions.length, 1, 1e-12);
    check('扣完还剩 75 分', half.card.awarded, 75, 1e-9);
    checkText('没量过的事实印成破折号', FactLabels.valueText('pjXGapRatio', Number.NaN), '—');
  }

  // 7. 一下都没释放:只有"点太少"能响,其余三条拿不到事实
  {
    const blank = run([['run', 60]]);
    check('一个点也没描', blank.sheet.num('pjPointCount'), 0, 1e-12);
    assertTrue('没描就不报间隔比', !Number.isFinite(blank.sheet.num('pjXGapRatio')),
      String(blank.sheet.num('pjXGapRatio')));
    assertTrue('没描就不报离散度', !Number.isFinite(blank.sheet.num('pjRatioErr')),
      String(blank.sheet.num('pjRatioErr')));
    check('只扣"点太少"这一条', blank.card.deductions.length, 1, 1e-12);
    check('扣完还剩 75 分', blank.card.awarded, 75, 1e-9);
  }

  // 8. 「重置」= 换一张白纸:描的点清零,原点也得重新挂
  {
    const after = run(DILIGENT.concat([['reset'], ['run', 5]]));
    check('重置后纸上没有点了', after.sheet.num('pjPointCount'), 0, 1e-12);
    check('重置后重垂线也掉了', after.runner.snapshot().segments
      .filter((g) => g.color === '#2E9E7A').length, 0, 1e-12);
    check('重置后卡片回到默认那格', after.runner.readObservable('pjCardDistance'), 3 * CARD_STEP, 1e-9);
  }
}

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

if (failures.length > 0) {
  console.log(`\n✗ ${failures.length} 项失败 / ${passed} 项通过`);
  for (const line of failures) {
    console.log('  - ' + line);
  }
  process.exit(1);
}
console.log(`✓ ${passed} 项物理断言全部通过`);
