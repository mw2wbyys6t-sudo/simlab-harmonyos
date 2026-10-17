import { ExperimentMeta, RendererKind, Subject } from '../model/ExperimentTypes';
import { ExperimentRegistry } from '../runner/ExperimentRegistry';
import { SceneBuilders } from './SceneBuilders';
import { InclineRunner } from '../physics/InclineRunner';
import { TapeCartRunner } from '../physics/TapeCartRunner';
import { FreeFallRunner } from '../physics/FreeFallRunner';
import { StopwatchCartRunner } from '../physics/StopwatchCartRunner';
import { NewtonSecondRunner } from '../physics/NewtonSecondRunner';
import { SpringImageRunner } from '../physics/SpringImageRunner';
import { ProjectileRunner } from '../physics/ProjectileRunner';
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
    ExperimentRegistry.register(MechanicsScenes.stopwatchCart(), (): StopwatchCartRunner => new StopwatchCartRunner());
    ExperimentRegistry.register(MechanicsScenes.newtonSecond(), (): NewtonSecondRunner => new NewtonSecondRunner());
    ExperimentRegistry.register(MechanicsScenes.springImage(), (): SpringImageRunner => new SpringImageRunner());
    ExperimentRegistry.register(MechanicsScenes.projectileFrame(), (): ProjectileRunner => new ProjectileRunner());
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
    // Ruling N:这两格把"应用凭什么这么算"露出来 —— 滑杆起点会被夹到第一个移动点,
    // 奇数段窗口的尾段不进逐差。不给学生看,逐差法的"后一半"就只能靠猜口径。
    meta.observables.push(SceneBuilders.observable('tapeChunkStart', '有效计数起点', '个', 0, false));
    meta.observables.push(SceneBuilders.observable('tapeChunkSegments', '参与逐差法的段数', '段', 0, false));
    meta.charts.push(SceneBuilders.timeChart('速度-时间 v-t（斜率即 a）', 'v', 'm/s', [
      SceneBuilders.trace('velocity', 'v', SceneBuilders.palette(0))
    ]));
    meta.tasks.push(SceneBuilders.task('tape-a-by-difference',
      '用逐差法把各计数段写成 a 的表达式再代入：说明它为什么比“相邻两段之差逐个平均”用上了更多数据。', Number.NaN, 0));
    meta.tasks.push(SceneBuilders.task('tape-a-from-slope',
      '由每段位移除以对应时间得到各计数点速度，作 v-t 图，从斜率取第二个 a 并与逐差法结果比对。', Number.NaN, 0));
    // 两格填空都挂在逐差法那条任务上:分子要毫米刻度尺量出来的段长之和,倍数是个纯个数。
    // 问句里不写"后三段/前三段"这种只属于样例表的字数 —— 学生手上那条纸带切得出几段,
    // 由他选的间隔与这条板长共同决定,问句必须对任何段数都成立。
    // Ruling N:真窗口约一半段数是奇数,"后一半 减 前一半"必须有唯一分法 ——
    // 配对约定(末尾凑不满一对的那段舍掉)直接写进句子,学生照句子量就和应有值同口径。
    meta.submissions.push(SceneBuilders.submission('tapeNumerator', 'tape-a-by-difference',
      '逐差法的分子：后一半各段之和 减 前一半各段之和（末尾凑不满一对的那段舍掉）', 'mm', 1));
    meta.submissions.push(SceneBuilders.submission('tapeDenFactor', 'tape-a-by-difference',
      '分母里 T² 的倍数（a = 分子 ÷（倍数 × T²））', '', 0));
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
   * 测量物体运动的速度(地图条目 `phy-jr-007`,初中第一条力学场景)。
   *
   * 动力学复用斜面:默认 7° 垫块、1.5 m 长板、μ=0.05 → a≈0.71 m/s²,
   * 走完全程约 2.1 s。这个时长是刻意挑的:再快,学生按停表的反应时间就占进读数里,
   * 而"倾角取小便于计时"这条理由要能被体验,全程必须明显长于反应时间。
   *
   * 停表是两个按钮:按下记下起点与时刻,松开记下终点与时长 —— 一次测量就此成为
   * 一个可数的对象(按了几次、覆盖几段、最长一段多久),而不是屏幕上的一行说明。
   */
  private static stopwatchCart(): ExperimentMeta {
    const meta = new ExperimentMeta();
    meta.id = 'stopwatch-cart';
    meta.title = '测量物体运动的速度';
    meta.subject = Subject.PHYSICS_MECHANICS;
    meta.renderer = RendererKind.PHYSICS_2D;
    meta.summary = '让小车从斜面顶端由静止下滑，用停表分别测上半程与全程用的时间，按 v=s/t 算各段平均速度再比较。';
    meta.gradeBand = '初中物理 · 八年级上';
    meta.durationMinutes = 40;
    meta.worldWidth = 9;
    meta.worldHeight = 5.4;
    meta.params.push(SceneBuilders.param('angle', '斜面倾角 θ', '°', 3, 45, 1, 7, '装置'));
    meta.params.push(SceneBuilders.param('length', '木板长度', 'm', 1, 2.5, 0.1, 1.5, '装置'));
    meta.params.push(SceneBuilders.param('mass', '小车质量', 'kg', 0.2, 2, 0.1, 0.5, '小车'));
    meta.params.push(SceneBuilders.param('friction', '动摩擦因数 μ', '', 0, 0.3, 0.01, 0.05, '小车'));
    meta.actions.push(SceneBuilders.action('timeStart', '按下停表', '停表'));
    meta.actions.push(SceneBuilders.action('timeStop', '松开停表', '停表'));
    meta.observables.push(SceneBuilders.observable('distance', '小车离开坡顶的距离 s', 'm', 3, true));
    meta.observables.push(SceneBuilders.observable('velocity', '速度 v', 'm/s', 3, true));
    meta.observables.push(SceneBuilders.observable('watchReading', '停表读数', 's', 2, false));
    meta.observables.push(SceneBuilders.observable('speedTrials', '按完的次数', '次', 0, false));
    meta.observables.push(SceneBuilders.observable('speedSegments', '测到的不同区间', '段', 0, false));
    meta.observables.push(SceneBuilders.observable('speedLongestS', '最长一段用的时间', 's', 2, false));
    meta.charts.push(SceneBuilders.timeChart('速度-时间 v-t', 'v', 'm/s', [
      SceneBuilders.trace('velocity', 'v', SceneBuilders.palette(0))
    ]));
    meta.tasks.push(SceneBuilders.task('speed-three-segments',
      '上半程、下半程与全程各算一个平均速度，说明全程那个为什么不是前两个的算术平均。', Number.NaN, 0));
    meta.tasks.push(SceneBuilders.task('speed-reaction-bias',
      '手按停表总比松车慢半拍。说明这会让算出来的平均速度偏大还是偏小，再说说斜面垫矮为什么能压住它。', Number.NaN, 0));
    meta.rubricId = 'stopwatch-cart-rubric';
    return meta;
  }

  /**
   * 探究加速度与物体受力、物体质量的关系(地图条目 `phy-sr-006`)。
   *
   * 动力学是两体的:a =(m桶g + Mg·sinθ − μMg·cosθ)/(M + m桶)。分母里那个 m桶 不能省 ——
   * 省掉就等于把绳的拉力写成砝码桶重力,a-F 图高力端往下弯这一条就再也弯不出来了,
   * 而它恰恰是这个实验最容易被写错的地方。
   *
   * 平衡摩擦靠「取下砝码桶 + 轻推小车」这两下做出来,靠纸带上的点距匀不匀读出来:
   * 层数是我们施给它的,不能当学生的选择来判;判的是它留下的那段纸带。
   */
  private static newtonSecond(): ExperimentMeta {
    const meta = new ExperimentMeta();
    meta.id = 'newton-second-cart';
    meta.title = '探究加速度与物体受力、物体质量的关系';
    meta.subject = Subject.PHYSICS_MECHANICS;
    meta.renderer = RendererKind.PHYSICS_2D;
    meta.summary = '先取下砝码桶、轻推小车，用空载纸带上的点距把摩擦力抵干净；再控制小车质量不变改拉力、控制拉力不变加槽码，各测三组 a。';
    meta.gradeBand = '高中物理 · 必修一';
    meta.durationMinutes = 45;
    meta.worldWidth = 9;
    meta.worldHeight = 5.4;
    meta.params.push(SceneBuilders.param('countStart', '计数起点：从第几个点量起', '个', 0, 80, 1, 10, '纸带'));
    meta.params.push(SceneBuilders.param('countEvery', '每几个点取一个计数点', '个', 1, 10, 1, 5, '纸带'));
    meta.actions.push(SceneBuilders.action('wedge+', '加一层垫块', '垫块'));
    meta.actions.push(SceneBuilders.action('wedge-', '取一层垫块', '垫块'));
    meta.actions.push(SceneBuilders.action('slot+', '小车上加一只槽码', '小车'));
    meta.actions.push(SceneBuilders.action('slot-', '从小车上取一只槽码', '小车'));
    meta.actions.push(SceneBuilders.action('load+', '桶里加一只砝码', '砝码桶'));
    meta.actions.push(SceneBuilders.action('load-', '从桶里取一只砝码', '砝码桶'));
    meta.actions.push(SceneBuilders.action('hook', '挂上／取下砝码桶', '砝码桶'));
    meta.actions.push(SceneBuilders.action('power', '接通／断开电源', '计时器'));
    meta.actions.push(SceneBuilders.action('push', '轻推小车', '计时器'));
    meta.actions.push(SceneBuilders.action('release', '释放小车', '计时器'));
    meta.actions.push(SceneBuilders.action('record', '记录这一条纸带', '记录'));
    meta.observables.push(SceneBuilders.observable('distance', '小车沿板朝滑轮走的距离 s', 'm', 3, true));
    meta.observables.push(SceneBuilders.observable('velocity', '速度 v', 'm/s', 3, true));
    meta.observables.push(SceneBuilders.observable('n2CartMassKg', '小车与槽码 M', 'kg', 3, false));
    meta.observables.push(SceneBuilders.observable('n2PullMassKg', '砝码桶与砝码 m', 'kg', 3, false));
    meta.observables.push(SceneBuilders.observable('n2WedgeLayers', '垫块层数', '层', 0, false));
    meta.observables.push(SceneBuilders.observable('n2RiseMm', '板端抬高', 'mm', 0, false));
    meta.observables.push(SceneBuilders.observable('n2TiltDeg', '板面倾角', '°', 2, false));
    meta.observables.push(SceneBuilders.observable('n2AccelTape', '本条纸带逐差法求出的 a', 'm/s²', 3, false));
    meta.observables.push(SceneBuilders.observable('tapeSegments', '切出的计数段数', '段', 0, false));
    meta.observables.push(SceneBuilders.observable('n2IdleSpreadMm', '轻推那次的点距跨度', 'mm', 2, false));
    meta.observables.push(SceneBuilders.observable('n2ChecksDone', '空载轻推检查', '次', 0, false));
    meta.observables.push(SceneBuilders.observable('n2UsableCount', '算得出 a 的组数', '组', 0, false));
    meta.observables.push(SceneBuilders.observable('n2ForceSteps', '同一质量下换过的拉力档', '档', 0, false));
    meta.observables.push(SceneBuilders.observable('n2MassSteps', '同一拉力下试过质量', '种', 0, false));
    meta.charts.push(SceneBuilders.timeChart('速度-时间 v-t（斜率即 a）', 'v', 'm/s', [
      SceneBuilders.trace('velocity', 'v', SceneBuilders.palette(0))
    ]));
    meta.tasks.push(SceneBuilders.task('n2-a-f-bend',
      '把各组砝码桶重力与对应的 a 描成 a-F 图。桶加重到跟小车一个量级时，图线为什么在高力端往下弯？绳的拉力与 m桶g 到底差在哪个分母上。', Number.NaN, 0));
    meta.tasks.push(SceneBuilders.task('n2-balance-direction',
      '垫块抬得不够与抬过头，空载纸带上的点距各是什么样子？说明为什么只有匀速那一次才算摩擦力被抵住，再说说没抵干净时 a-F 图线与坐标轴的交点在哪。', Number.NaN, 0));
    meta.rubricId = 'newton-second-rubric';
    return meta;
  }

  /**
   * 描绘简谐运动的图像(地图条目 `phy-sr-015`)。
   *
   * 这条场景故意**不声明任何图线**:外壳那张自动 x-t 图,正是学生要自己一下一下按出来的东西。
   * 把它摆在旁边,判「描得准不准」就成了替学生描。振子照常跑,画面下方那块描图区只收他按下的点。
   *
   * 默认 m=4 kg、k=2 N/m → T≈8.9 s:慢到手指跟得上(每半秒一下就是一个周期十八个点),
   * 又不至于让「按太慢」这件事要等上半分钟才显出来。
   */
  private static springImage(): ExperimentMeta {
    const meta = new ExperimentMeta();
    meta.id = 'spring-image';
    meta.title = '描绘简谐运动的图像';
    meta.subject = Subject.PHYSICS_MECHANICS;
    meta.renderer = RendererKind.PHYSICS_2D;
    meta.summary = '让振子跑起来，每隔一点时间按一次「记下这一个点」，再把描出的折线跟真实曲线比一比：按得太慢，图就走样。';
    meta.gradeBand = '高中物理 · 选择性必修一';
    meta.durationMinutes = 40;
    meta.worldWidth = 6;
    meta.worldHeight = 3.6;
    meta.params.push(SceneBuilders.param('mass', '振体质量', 'kg', 0.5, 10, 0.1, 4, '器材'));
    meta.params.push(SceneBuilders.param('stiffness', '弹簧劲度系数', 'N/m', 0.5, 20, 0.1, 2, '器材'));
    meta.params.push(SceneBuilders.param('amplitude', '初始位移（重置后生效）', 'm', 0.2, 1.2, 0.05, 0.9, '条件'));
    meta.actions.push(SceneBuilders.action('sample', '记下这一个点', '描图'));
    meta.observables.push(SceneBuilders.observable('displacement', '位移 x', 'm', 3, false));
    meta.observables.push(SceneBuilders.observable('velocity', '速度 v', 'm/s', 3, false));
    meta.observables.push(SceneBuilders.observable('acceleration', '加速度 a', 'm/s²', 3, false));
    meta.observables.push(SceneBuilders.observable('amplitude', '振幅 A', 'm', 3, false));
    meta.observables.push(SceneBuilders.observable('periodTheory', '周期 T', 's', 3, false));
    meta.observables.push(SceneBuilders.observable('imgSamples', '按下的取样点', '个', 0, false));
    meta.observables.push(SceneBuilders.observable('imgSpanT', '覆盖的周期数', '个', 2, false));
    meta.observables.push(SceneBuilders.observable('imgMaxGapT', '最大的取样间隔', '个周期', 2, false));
    meta.observables.push(SceneBuilders.observable('imgSwingCm', '点铺开的位置范围', 'cm', 0, false));
    meta.observables.push(SceneBuilders.observable('imgDistortCm', '与真实曲线的最大差', 'cm', 1, false));
    meta.tasks.push(SceneBuilders.task('img-read-a-t',
      '从你描的图上读出振幅与周期，各带上单位；再说清你是从哪几个点读出来的，为什么不能只拿相邻两点相减当周期。', Number.NaN, 0));
    meta.tasks.push(SceneBuilders.task('img-alias-threshold',
      '故意把手速拖慢再描一次，看「与真实曲线的最大差」这一格涨到多少。说明取样间隔接近半个周期时，峰和谷为什么会被错接成锯齿，而不只是「没那么平滑」。', Number.NaN, 0));
    meta.rubricId = 'spring-image-rubric';
    return meta;
  }

  /**
   * 探究平抛运动的特点(地图条目 `phy-sr-007`)。
   *
   * 器材的手上功夫是「把带孔卡片挪到某个水平位置、从斜槽某一格静止释放、球穿过孔时在白纸上
   * 留下一个点」,所以这条场景一个滑杆都没有:卡片在第几格、球从第几格释放,都是可数的按下 ——
   * 「每次必须从同一位置静止释放」与「按水平等间隔取点」这两条要求,只有做成档位才留得下事实。
   *
   * 场景不画轨迹、也不给自动图线:抛物线的形状正是这条实验要学生自己按 y 与 x² 检验出来的东西。
   * y/x² 的离散度只当读数摆在面板上,不做判分依据 —— 定过原点、释放高度又一致时它本来就恒定,
   * 拿它当判据就是留一条永远跟着别人响的判据。
   */
  private static projectileFrame(): ExperimentMeta {
    const meta = new ExperimentMeta();
    meta.id = 'projectile-frame';
    meta.title = '探究平抛运动的特点';
    meta.subject = Subject.PHYSICS_MECHANICS;
    meta.renderer = RendererKind.PHYSICS_2D;
    meta.summary = '先挂重垂线、把槽口那一点定成原点；再从斜槽同一格静止释放，把卡片依次往外挪，让球每次穿过孔时留下一个点，检验水平方向匀速、竖直方向是自由落体。';
    meta.gradeBand = '高中物理 · 必修二';
    meta.durationMinutes = 40;
    meta.worldWidth = 4.8;
    meta.worldHeight = 4.2;
    meta.actions.push(SceneBuilders.action('origin', '挂重垂线定抛出点', '基准'));
    meta.actions.push(SceneBuilders.action('slot+', '释放位置往上一格', '斜槽'));
    meta.actions.push(SceneBuilders.action('slot-', '释放位置往下一格', '斜槽'));
    meta.actions.push(SceneBuilders.action('card+', '卡片往外挪一格', '卡片'));
    meta.actions.push(SceneBuilders.action('card-', '卡片往里挪一格', '卡片'));
    meta.actions.push(SceneBuilders.action('release', '静止释放钢球', '描点'));
    meta.observables.push(SceneBuilders.observable('pjPointCount', '描下的点', '个', 0, false));
    meta.observables.push(SceneBuilders.observable('pjEarlyMarks', '定原点前描的点', '个', 0, false));
    meta.observables.push(SceneBuilders.observable('pjSlot', '释放位置', '格', 0, false));
    meta.observables.push(SceneBuilders.observable('pjLaunchSpeed', '槽口速度 v0', 'm/s', 2, false));
    meta.observables.push(SceneBuilders.observable('pjCardDistance', '卡片离槽口', 'm', 2, false));
    meta.observables.push(SceneBuilders.observable('pjRange', '这一次能飞多远', 'm', 2, false));
    meta.observables.push(SceneBuilders.observable('pjSlotSpread', '释放位置最大差', '格', 0, false));
    meta.observables.push(SceneBuilders.observable('pjXGapRatio', '水平间隔最大/最小', '', 2, false));
    meta.observables.push(SceneBuilders.observable('pjRatioErr', 'y/x² 的离散度', '%', 1, false));
    meta.tasks.push(SceneBuilders.task('pj-y-over-x2',
      '用你描下的点算几个 y/x² 出来：它们相等吗？由此为什么能同时说出水平分运动匀速、竖直分运动是自由落体？只说「看着像抛物线」为什么不算检验。', Number.NaN, 0));
    meta.tasks.push(SceneBuilders.task('pj-same-release',
      '说明为什么每次必须从同一位置静止释放；再回答槽面是不是必须光滑、把摩擦考虑进去会不会改变结论。', Number.NaN, 0));
    // 两格填空都挂在 y/x² 那条任务上:反求 g 要的是他描的点,段比要的也是同一批点。
    // 应用内部怎么取数必须写进问句本身(sr-003 的先例:「末尾凑不满一对的那段舍掉」)——
    // ① g 用**描下的第 1 个点**、v0 用**描它那一刻**的释放格(描完再去升档位不算),
    //    下落取「从槽口算起」那一个,不是没挂线时标签上那个按板角量出来的 y;
    // ② 段比的窗口是**离槽口最近**那两个点,按远近取而不按描点先后。
    // 不写清,按另一种取法算的人会被判「算错了」且不命中任何错法。
    meta.submissions.push(SceneBuilders.submission('pjG', 'pj-y-over-x2',
      '由你描的第 1 个点反求的重力加速度 g（g = 2·(y/x²)·v0²；y 是这个点从槽口算起的下落，v0 按描它那一次用的释放格）',
      'm/s²', 2));
    meta.submissions.push(SceneBuilders.submission('pjSegRatio', 'pj-y-over-x2',
      '竖直方向第二段位移 ÷ 第一段位移（第一段从槽口量到离槽口最近那个点，第二段是它到次近那个点；这两个点按远近取，不按描点先后）',
      '', 2));
    meta.rubricId = 'projectile-frame-rubric';
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
