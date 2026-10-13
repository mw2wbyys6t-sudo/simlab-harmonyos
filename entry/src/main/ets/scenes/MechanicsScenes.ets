import { ExperimentMeta, RendererKind, Subject } from '../model/ExperimentTypes';
import { ExperimentRegistry } from '../runner/ExperimentRegistry';
import { SceneBuilders } from './SceneBuilders';
import { InclineRunner } from '../physics/InclineRunner';
import { TapeCartRunner } from '../physics/TapeCartRunner';
import { FreeFallRunner } from '../physics/FreeFallRunner';
import { SpringMassRunner } from '../physics/SpringMassRunner';
import { SpringForceRunner } from '../physics/SpringForceRunner';

/**
 * 力学场景包。新增力学实验在这里加一段元数据 + 一个求解器注册,
 * 外壳的实验库列表、参数面板、读数区、数据图表全部自动生效。
 */
export class MechanicsScenes {
  static registerAll(): void {
    ExperimentRegistry.register(MechanicsScenes.springMass(), (): SpringMassRunner => new SpringMassRunner());
    ExperimentRegistry.register(MechanicsScenes.incline(), (): InclineRunner => new InclineRunner());
    ExperimentRegistry.register(MechanicsScenes.springForce(), (): SpringForceRunner => new SpringForceRunner());
    ExperimentRegistry.register(MechanicsScenes.tapeCart(), (): TapeCartRunner => new TapeCartRunner());
    ExperimentRegistry.register(MechanicsScenes.freeFall(), (): FreeFallRunner => new FreeFallRunner());
  }

  private static springMass(): ExperimentMeta {
    const meta = new ExperimentMeta();
    meta.id = 'spring-mass';
    meta.title = '弹簧振子的简谐振动';
    meta.subject = Subject.PHYSICS_MECHANICS;
    meta.renderer = RendererKind.PHYSICS_2D;
    meta.summary = '改变振体质量、弹簧劲度系数与阻尼，观察振动周期与能量转化，验证 T=2π√(m/k)。';
    meta.gradeBand = '高中物理 · 选择性必修一';
    meta.durationMinutes = 20;
    meta.worldWidth = 6;
    meta.worldHeight = 3;
    meta.params.push(SceneBuilders.param('mass', '振体质量', 'kg', 0.2, 5, 0.1, 1, '器材'));
    meta.params.push(SceneBuilders.param('stiffness', '弹簧劲度系数', 'N/m', 1, 100, 1, 20, '器材'));
    meta.params.push(SceneBuilders.param('damping', '阻尼系数', 'N·s/m', 0, 3, 0.05, 0, '条件'));
    meta.params.push(SceneBuilders.param('amplitude', '初始位移（重置后生效）', 'm', -1.2, 1.2, 0.05, 0.9, '条件'));
    meta.observables.push(SceneBuilders.observable('displacement', '位移 x', 'm', 3, true));
    meta.observables.push(SceneBuilders.observable('velocity', '速度 v', 'm/s', 3, true));
    meta.observables.push(SceneBuilders.observable('acceleration', '加速度 a', 'm/s²', 3, false));
    meta.observables.push(SceneBuilders.observable('kinetic', '动能 Ek', 'J', 3, true));
    meta.observables.push(SceneBuilders.observable('potential', '弹性势能 Ep', 'J', 3, true));
    meta.observables.push(SceneBuilders.observable('total', '总机械能 E', 'J', 3, true));
    meta.observables.push(SceneBuilders.observable('periodTheory', '理论周期 T', 's', 4, false));
    meta.observables.push(SceneBuilders.observable('periodMeasured', '实测周期 T′', 's', 4, false));
    meta.charts.push(SceneBuilders.timeChart('位移-时间 x-t', 'x', 'm', [
      SceneBuilders.trace('displacement', 'x', SceneBuilders.palette(0))
    ]));
    meta.charts.push(SceneBuilders.timeChart('能量-时间 E-t', 'E', 'J', [
      SceneBuilders.trace('kinetic', 'Ek', SceneBuilders.palette(0)),
      SceneBuilders.trace('potential', 'Ep', SceneBuilders.palette(1)),
      SceneBuilders.trace('total', 'E', SceneBuilders.palette(2))
    ]));
    meta.tasks.push(SceneBuilders.task('period-error', '保持 k=20 N/m，把质量依次改为 0.5 / 1 / 2 / 4 kg，记录实测周期与理论周期的相对偏差。', 0, 0.02));
    meta.tasks.push(SceneBuilders.task('damping-effect', '阻尼从 0 增到 3 N·s/m，周期是否改变？由此说明周期与振幅无关的适用条件。', Number.NaN, 0));
    return meta;
  }

  private static incline(): ExperimentMeta {
    const meta = new ExperimentMeta();
    meta.id = 'incline-block';
    meta.title = '含摩擦的斜面运动';
    meta.subject = Subject.PHYSICS_MECHANICS;
    meta.renderer = RendererKind.PHYSICS_2D;
    meta.summary = '调节倾角、动摩擦因数与初速度，观察上滑与下滑的受力差异，验证摩擦产生的热量等于机械能损失。';
    meta.gradeBand = '高中物理 · 必修二';
    meta.durationMinutes = 25;
    meta.worldWidth = 8;
    meta.worldHeight = 5;
    meta.params.push(SceneBuilders.param('angle', '斜面倾角 θ', '°', 5, 60, 1, 30, '装置'));
    meta.params.push(SceneBuilders.param('length', '斜面长度', 'm', 1, 5, 0.1, 3.5, '装置'));
    meta.params.push(SceneBuilders.param('mass', '滑块质量', 'kg', 0.2, 5, 0.1, 2, '滑块'));
    meta.params.push(SceneBuilders.param('friction', '动摩擦因数 μ', '', 0, 0.8, 0.01, 0.15, '滑块'));
    meta.params.push(SceneBuilders.param('initialVelocity', '初速度（沿坡向下为负即上滑，重置后生效）', 'm/s', -3, 3, 0.1, 0, '条件'));
    meta.params.push(SceneBuilders.param('startDistance', '起始位置：距坡顶（重置后生效）', 'm', 0, 5, 0.1, 0, '条件'));
    meta.observables.push(SceneBuilders.observable('distance', '距坡顶 s', 'm', 3, true));
    meta.observables.push(SceneBuilders.observable('velocity', '速度 v', 'm/s', 3, true));
    meta.observables.push(SceneBuilders.observable('acceleration', '加速度 a', 'm/s²', 3, false));
    meta.observables.push(SceneBuilders.observable('height', '离地高度 h', 'm', 3, false));
    meta.observables.push(SceneBuilders.observable('kinetic', '动能 Ek', 'J', 3, true));
    meta.observables.push(SceneBuilders.observable('potential', '重力势能 Ep', 'J', 3, true));
    meta.observables.push(SceneBuilders.observable('heat', '摩擦生热 Q', 'J', 3, true));
    meta.observables.push(SceneBuilders.observable('distanceMax', '上滑最远距离', 'm', 3, false));
    meta.observables.push(SceneBuilders.observable('path', '路程（上滑与下滑之和）', 'm', 3, false));
    meta.observables.push(SceneBuilders.observable('velocityEnd', '端点速度 v_end', 'm/s', 3, false));
    meta.observables.push(SceneBuilders.observable('timeToEnd', '到达端点用时', 's', 3, false));
    meta.charts.push(SceneBuilders.timeChart('速度-时间 v-t', 'v', 'm/s', [
      SceneBuilders.trace('velocity', 'v', SceneBuilders.palette(0))
    ]));
    meta.charts.push(SceneBuilders.timeChart('能量转化 Ep-Ek-Q', 'E', 'J', [
      SceneBuilders.trace('potential', 'Ep', SceneBuilders.palette(0)),
      SceneBuilders.trace('kinetic', 'Ek', SceneBuilders.palette(1)),
      SceneBuilders.trace('heat', 'Q', SceneBuilders.palette(2))
    ]));
    meta.tasks.push(SceneBuilders.task('critical-angle', '固定 μ=0.3，找到滑块恰好能自动下滑的临界倾角，与 arctan μ 比较。', 16.7, 1.5));
    meta.tasks.push(SceneBuilders.task('energy-balance', '取 μ=0、θ=30°、L=3.5 m 由静止释放，比较减少的重力势能与增加的动能。', 0, 0.02));
    return meta;
  }

  /**
   * 测量匀变速直线运动物体的加速度(地图条目 `phy-sr-003`)。
   *
   * 复用斜面的动力学,新加的是打点计时器与那条纸带。倾角默认 8°、μ 默认 0.05,
   * 让 a 落在 0.9 m/s² 左右:1.2 m 长的坡走下来约 1.6 s、打出八十个点 ——
   * 这是真实纸带的量级(点太少不够分段,太密就回到读不出的老问题)。
   *
   * 「接通电源」与「释放小车」是两个按钮而不是一个「开始」:这条实验要判的那条
   * 顺序(先通电待打点稳定、再放车),只有拆开才留得下事实。
   */
  private static tapeCart(): ExperimentMeta {
    const meta = new ExperimentMeta();
    meta.id = 'tape-cart';
    meta.title = '测量匀变速直线运动物体的加速度';
    meta.subject = Subject.PHYSICS_MECHANICS;
    meta.renderer = RendererKind.PHYSICS_2D;
    meta.summary = '先接通电源、等打点稳定后释放小车；舍开头里密着的那一段，每五个点取一个计数点，用逐差法求 a。';
    meta.gradeBand = '高中物理 · 必修一';
    meta.durationMinutes = 45;
    meta.worldWidth = 9;
    meta.worldHeight = 5.4;
    meta.params.push(SceneBuilders.param('angle', '斜面倾角 θ', '°', 5, 60, 1, 8, '装置'));
    meta.params.push(SceneBuilders.param('length', '木板长度', 'm', 1, 5, 0.1, 1.2, '装置'));
    meta.params.push(SceneBuilders.param('mass', '小车质量', 'kg', 0.2, 5, 0.1, 0.2, '小车'));
    meta.params.push(SceneBuilders.param('friction', '动摩擦因数 μ', '', 0, 0.8, 0.01, 0.05, '小车'));
    meta.params.push(SceneBuilders.param('countStart', '计数起点：从第几个点量起', '个', 0, 80, 1, 40, '纸带'));
    meta.params.push(SceneBuilders.param('countEvery', '每几个点取一个计数点', '个', 1, 10, 1, 5, '纸带'));
    meta.actions.push(SceneBuilders.action('power', '接通／断开电源', '计时器'));
    meta.actions.push(SceneBuilders.action('release', '释放小车', '计时器'));
    meta.observables.push(SceneBuilders.observable('distance', '小车沿板滑下的距离 s', 'm', 3, true));
    meta.observables.push(SceneBuilders.observable('velocity', '速度 v', 'm/s', 3, true));
    meta.observables.push(SceneBuilders.observable('acceleration', '加速度 a', 'm/s²', 3, false));
    meta.observables.push(SceneBuilders.observable('tapeDotCount', '纸带上的点数', '个', 0, false));
    meta.observables.push(SceneBuilders.observable('tapeSegments', '切出的计数段数', '段', 0, false));
    meta.observables.push(SceneBuilders.observable('tapeShortestMm', '最短计数段', 'mm', 1, false));
    meta.observables.push(SceneBuilders.observable('tapeEveryMs', '相邻计数点时间间隔', 'ms', 0, false));
    meta.observables.push(SceneBuilders.observable('tapeLostHead', '头一段漏打的点数', '个', 0, false));
    meta.charts.push(SceneBuilders.timeChart('速度-时间 v-t（斜率即 a）', 'v', 'm/s', [
      SceneBuilders.trace('velocity', 'v', SceneBuilders.palette(0))
    ]));
    meta.tasks.push(SceneBuilders.task('tape-a-by-difference',
      '用逐差法把各计数段写成 a 的表达式再代入：说明它为什么比“相邻两段之差逐个平均”用上了更多数据。', Number.NaN, 0));
    meta.tasks.push(SceneBuilders.task('tape-a-from-slope',
      '由每段位移除以对应时间得到各计数点速度，作 v-t 图，从斜率取第二个 a 并与逐差法结果比对。', Number.NaN, 0));
    meta.rubricId = 'tape-cart-rubric';
    return meta;
  }

  /**
   * 验证机械能守恒定律(地图条目 `phy-sr-008`)。
   *
   * 纸带那条共用件直接接过来用,新的是铁架台与一维落体。阻力默认 0.1 N:
   * 真实实验里 ΔEk 恒略小于 ΔEp,做成严格相等会教出错的结论。
   * 计数默认从第 1 个点起、每 2 点取一个 —— 这条不像测加速度那样要舍开头,
   * 反而要靠开头那两点的间距判断是不是从静止起的。
   */
  private static freeFall(): ExperimentMeta {
    const meta = new ExperimentMeta();
    meta.id = 'free-fall';
    meta.title = '验证机械能守恒定律';
    meta.subject = Subject.PHYSICS_MECHANICS;
    meta.renderer = RendererKind.PHYSICS_2D;
    meta.summary = '重锤带着纸带自由下落，量几段下落高度与这段两端的速度，比较 mgh 与 ½mv²；式两边都含 m，所以不必测质量。';
    meta.gradeBand = '高中物理 · 必修二';
    meta.durationMinutes = 45;
    meta.worldWidth = 9;
    meta.worldHeight = 5.4;
    meta.params.push(SceneBuilders.param('height', '重锤下落高度', 'm', 0.4, 1.5, 0.05, 1, '装置'));
    meta.params.push(SceneBuilders.param('mass', '重锤质量', 'kg', 0.2, 2, 0.05, 0.5, '重锤'));
    meta.params.push(SceneBuilders.param('drag', '纸带与空气的等效阻力', 'N', 0, 0.5, 0.02, 0.1, '重锤'));
    meta.params.push(SceneBuilders.param('countStart', '比较起点：从第几个点量起', '个', 0, 20, 1, 0, '纸带'));
    meta.params.push(SceneBuilders.param('countEvery', '每几个点取一个计数点', '个', 1, 10, 1, 2, '纸带'));
    meta.actions.push(SceneBuilders.action('power', '接通／断开电源', '计时器'));
    meta.actions.push(SceneBuilders.action('release', '松开纸带', '计时器'));
    meta.observables.push(SceneBuilders.observable('dropHeight', '已下落高度 h', 'm', 3, true));
    meta.observables.push(SceneBuilders.observable('velocity', '速度 v', 'm/s', 3, true));
    meta.observables.push(SceneBuilders.observable('acceleration', '下落加速度 a', 'm/s²', 3, false));
    meta.observables.push(SceneBuilders.observable('potentialLost', '减少的重力势能 ΔEp', 'J', 3, true));
    meta.observables.push(SceneBuilders.observable('kineticGained', '增加的动能 ΔEk', 'J', 3, true));
    meta.observables.push(SceneBuilders.observable('dragWork', '阻力做的功', 'J', 3, false));
    meta.observables.push(SceneBuilders.observable('energyGapPct', 'ΔEp 与 ΔEk 的相对偏差', '%', 2, false));
    meta.observables.push(SceneBuilders.observable('tapeDotCount', '纸带上的点数', '个', 0, false));
    meta.observables.push(SceneBuilders.observable('tapeSegments', '切出的计数段数', '段', 0, false));
    meta.observables.push(SceneBuilders.observable('tapeFirstGapMm', '第一对点的间距', 'mm', 2, false));
    meta.charts.push(SceneBuilders.timeChart('能量对照 Ep-Ek', 'E', 'J', [
      SceneBuilders.trace('potentialLost', 'ΔEp', SceneBuilders.palette(0)),
      SceneBuilders.trace('kineticGained', 'ΔEk', SceneBuilders.palette(1))
    ]));
    meta.tasks.push(SceneBuilders.task('energy-why-mass-free',
      '式两边都含质量 m，说明为什么这条实验不必测重锤质量，哪些器材因此是多余的。', Number.NaN, 0));
    meta.tasks.push(SceneBuilders.task('energy-gap-direction',
      '比较几段的 ΔEp 与 ΔEk，说明偏差为什么总是 ΔEk 略小，并把阻力做的那部分功算进去对一次账。', Number.NaN, 0));
    meta.rubricId = 'free-fall-rubric';
    return meta;
  }

  /**
   * 探究弹簧弹力与形变量的关系。这是第一条「靠学生按动作、不靠拖滑杆」做起来的实验:
   * 加/减砝码与记录读数都是离散动作,判定层读的是这些动作留下的后果(超没超弹性限度、
   * 记录瞬间弹簧还在不在动、测了几挡、有没有卸载对照)。
   */
  private static springForce(): ExperimentMeta {
    const meta = new ExperimentMeta();
    meta.id = 'spring-force';
    meta.title = '探究弹簧弹力与形变量的关系';
    meta.subject = Subject.PHYSICS_MECHANICS;
    meta.renderer = RendererKind.PHYSICS_2D;
    meta.summary = '逐次增挂钩码，待弹簧静止后读出形变量，作 F-x 图并检验它是否过原点；超过弹性限度后弹簧会留下回不去的变形。';
    meta.gradeBand = '高中物理 · 必修一';
    meta.durationMinutes = 20;
    meta.worldWidth = 1.1;
    meta.worldHeight = 0.9;
    meta.params.push(SceneBuilders.param('stiffness', '弹簧劲度系数 k', 'N/m', 5, 60, 1, 20, '器材'));
    meta.params.push(SceneBuilders.param('naturalLength', '弹簧原长', 'm', 0.1, 0.4, 0.01, 0.2, '器材'));
    meta.params.push(SceneBuilders.param('limitExtension', '弹性限度（伸长超过它即塑性）', 'm', 0.05, 0.3, 0.01, 0.16, '器材'));
    meta.params.push(SceneBuilders.param('panMass', '砝码盘质量', 'kg', 0.005, 0.05, 0.005, 0.01, '器材'));
    meta.params.push(SceneBuilders.param('weightMass', '每只砝码质量', 'kg', 0.01, 0.1, 0.005, 0.05, '器材'));
    meta.actions.push(SceneBuilders.action('weight+', '加一个砝码', '砝码'));
    meta.actions.push(SceneBuilders.action('weight-', '取下一个砝码', '砝码'));
    meta.actions.push(SceneBuilders.action('record', '记录这一读数', '记录'));
    meta.rubricId = 'spring-force-rubric'; // 字面量:场景层不该为了一个 id 去 import 判分层(由断言保证可解析)
    meta.observables.push(SceneBuilders.observable('force', '弹力 F', 'N', 4, true));
    meta.observables.push(SceneBuilders.observable('extension', '形变量 x', 'm', 4, true));
    meta.observables.push(SceneBuilders.observable('load', '砝码总重', 'N', 3, false));
    meta.observables.push(SceneBuilders.observable('weights', '已挂砝码数', '只', 0, false));
    meta.observables.push(SceneBuilders.observable('length', '弹簧总长', 'm', 4, false));
    meta.observables.push(SceneBuilders.observable('limitExtension', '弹性限度', 'm', 2, false));
    meta.observables.push(SceneBuilders.observable('residual', '撤去载荷后的残余形变', 'm', 4, false));
    meta.observables.push(SceneBuilders.observable('maxExtension', '本次到过的最大伸长', 'm', 4, false));
    meta.observables.push(SceneBuilders.observable('beyondLimit', '是否超过弹性限度', '', 0, false));
    meta.observables.push(SceneBuilders.observable('recordCount', '已记录读数', '条', 0, false));
    meta.charts.push(SceneBuilders.xyChart('弹力-形变量 F-x', 'force', 'F', 'N', 'x', 'm',
      [SceneBuilders.trace('extension', 'x', SceneBuilders.palette(0))]));
    meta.charts.push(SceneBuilders.timeChart('形变量-时间 x-t', 'x', 'm',
      [SceneBuilders.trace('extension', 'x', SceneBuilders.palette(0))]));
    meta.tasks.push(SceneBuilders.task('slope-stiffness',
      '把各挡记录的 F 与 x 描在 F-x 图上作直线：斜率的物理意义是什么？它与器材面板里的 k 相符吗？', Number.NaN, 0));
    meta.tasks.push(SceneBuilders.task('origin-check',
      '图线是否过原点？若横轴改用弹簧总长而不是形变量，图线会怎么变？', Number.NaN, 0));
    return meta;
  }
}
