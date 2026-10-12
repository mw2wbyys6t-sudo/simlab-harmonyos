import { ExperimentMeta, RendererKind, Subject } from '../model/ExperimentTypes';
import { CircuitRunner } from '../physics/circuit/CircuitRunner';
import { OhmRunner } from '../physics/circuit/OhmRunner';
import { CircuitSpec, Component, ComponentKind, WirePath } from '../physics/circuit/CircuitModel';
import { ExperimentRegistry } from '../runner/ExperimentRegistry';
import { SceneBuilders } from './SceneBuilders';

/**
 * 世界宽 10 而不是刚好包住电路:最右侧支路上的电压表要往圆的外侧印读数
 * (V₂ 在 x=8.25,一行读数约占 1 米),按 9 收边时读数被画布右边界裁成「3.6…」。
 */
const WORLD_W = 10;
const WORLD_H = 5.4;

/**
 * 直流电路场景包:串联分压、并联分流。
 *
 * 拓扑与画图坐标在这里手写;阻值、电动势、开关走参数通道,运行中即时重解。
 */
export class ElectricalScenes {
  static registerAll(): void {
    ExperimentRegistry.register(ElectricalScenes.seriesMeta(),
      (): CircuitRunner => new CircuitRunner(ElectricalScenes.seriesCircuit()));
    ExperimentRegistry.register(ElectricalScenes.parallelMeta(),
      (): CircuitRunner => new CircuitRunner(ElectricalScenes.parallelCircuit()));
    ExperimentRegistry.register(ElectricalScenes.kirchhoffMeta(),
      (): CircuitRunner => new CircuitRunner(ElectricalScenes.kirchhoffCircuit()));
    ExperimentRegistry.register(ElectricalScenes.maxPowerMeta(),
      (): CircuitRunner => new CircuitRunner(ElectricalScenes.maxPowerCircuit()));
    ExperimentRegistry.register(ElectricalScenes.ohmMeta(),
      (): OhmRunner => new OhmRunner(ElectricalScenes.ohmCircuit()));
  }

  /**
   * 探究电流与电压、电阻的关系(地图条目 `phy-jr-017`,限流接法)。
   *
   * 滑动变阻器在这里不是摆设:它的用途是**改电压**,以及**换电阻之后把电压调回同一档** ——
   * 而这两件事正是这个实验要判的动作。电路本身与最大功率那页共用同一套 MNA。
   */
  private static ohmCircuit(): CircuitSpec {
    const spec = new CircuitSpec();
    const left = 1.6;
    const right = 7.4;
    const top = 4.2;
    const bottom = 1.2;

    ElectricalScenes.place(spec.add(ComponentKind.SOURCE, 'src', '电源 E', 1, 0, 3, 'emf'),
      left, 3.4, left, 2.4, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.RHEOSTAT, 'slide', 'R′', 2, 1, 20, 'slide'),
      3.4, top, 2.4, top, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.AMMETER, 'a1', 'A', 2, 3, 0, ''),
      4.4, top, 5.4, top, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.RESISTOR, 'rx', 'R', 3, 0, 5, 'fixed'),
      right, 3.2, right, 2.2, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.VOLTMETER, 'v1', 'V', 3, 0, 0, ''),
      8.7, 3.2, 8.7, 2.2, 0, 0);

    spec.wire(ElectricalScenes.poly([[left, 2.4], [left, bottom]]));
    spec.wire(ElectricalScenes.poly([[left, bottom], [right, bottom]]));
    spec.wire(ElectricalScenes.poly([[right, bottom], [right, 2.2]]));
    spec.wire(ElectricalScenes.poly([[left, 3.4], [left, top]]));
    spec.wire(ElectricalScenes.poly([[left, top], [2.4, top]]));
    spec.wire(ElectricalScenes.poly([[3.4, top], [4.4, top]]));
    spec.wire(ElectricalScenes.poly([[5.4, top], [right, top]]));
    spec.wire(ElectricalScenes.poly([[right, top], [right, 3.2]]));
    spec.wire(ElectricalScenes.poly([[8.7, 3.2], [right, 3.2]]));
    spec.wire(ElectricalScenes.poly([[8.7, 2.2], [right, 2.2]]));
    return spec;
  }

  private static ohmMeta(): ExperimentMeta {
    const meta = new ExperimentMeta();
    meta.id = 'ohm-law';
    meta.title = '探究电流与电压、电阻的关系';
    meta.subject = Subject.PHYSICS_ELECTRICAL;
    meta.renderer = RendererKind.PHYSICS_2D;
    meta.summary = '先保持定值电阻不变、用滑动变阻器改它两端电压；再换电阻、把电压调回同一档比较。';
    meta.gradeBand = '初中物理 · 九年级';
    meta.durationMinutes = 45;
    // 电压表画在 x=8.7 且读数往圆外侧印,世界宽要留出这一格
    meta.worldWidth = 10.6;
    meta.worldHeight = WORLD_H;
    meta.params.push(SceneBuilders.param('emf', '电源电动势 E', 'V', 1.5, 6, 0.5, 3, '电源'));
    meta.params.push(SceneBuilders.param('slide', '滑动变阻器 R′', 'Ω', 0, 20, 0.5, 20, '控制'));
    meta.params.push(SceneBuilders.param('fixed', '定值电阻 R', 'Ω', 5, 20, 5, 5, '控制'));
    meta.actions.push(SceneBuilders.action('fixed+', '换大一档电阻', '定值电阻'));
    meta.actions.push(SceneBuilders.action('fixed-', '换小一档电阻', '定值电阻'));
    meta.actions.push(SceneBuilders.action('record', '记录这一组 U 和 I', '记录'));
    meta.observables.push(SceneBuilders.observable('U:rx', '定值电阻两端电压 U', 'V', 3, true));
    meta.observables.push(SceneBuilders.observable('I:rx', '通过定值电阻的电流 I', 'A', 4, true));
    meta.observables.push(SceneBuilders.observable('ohmRecordCount', '已记录组数', '组', 0, false));
    meta.observables.push(SceneBuilders.observable('ohmMaxPointsAtOneR', '同一电阻下的电压档数', '档', 0, false));
    meta.observables.push(SceneBuilders.observable('ohmResistances', '测过的电阻种数', '种', 0, false));
    meta.observables.push(SceneBuilders.observable('ohmSharedVoltages', '同电压可比较的档数', '档', 0, false));
    meta.charts.push(SceneBuilders.xyChart('I–U 图（应为过原点的直线）', 'U:rx', 'U', 'V', 'I', 'A', [
      SceneBuilders.trace('I:rx', 'I', SceneBuilders.palette(0))
    ]));
    meta.tasks.push(SceneBuilders.task('ohm-ratio',
      '保持电阻不变，算一算每组的 U/I，说明它们为什么应当相等。', Number.NaN, 0));
    meta.tasks.push(SceneBuilders.task('ohm-hold-voltage',
      '换电阻之后要把电压调回同一档，写清这一步在操作上是怎么做的。', Number.NaN, 0));
    meta.rubricId = 'ohm-law-rubric';
    return meta;
  }

  private static place(item: Component, ax: number, ay: number, bx: number, by: number,
    offsetX: number, offsetY: number): Component {
    item.ax = ax;
    item.ay = ay;
    item.bx = bx;
    item.by = by;
    item.offsetX = offsetX;
    item.offsetY = offsetY;
    return item;
  }

  private static poly(points: number[][]): WirePath {
    const path = new WirePath();
    for (let i = 0; i < points.length; i++) {
      path.point(points[i][0], points[i][1]);
    }
    return path;
  }

  private static seriesCircuit(): CircuitSpec {
    const spec = new CircuitSpec();
    // n0 电源负极(参考点) n1 正极 n2 电流表后 n3 R1 后 n4 R2 后
    ElectricalScenes.place(spec.add(ComponentKind.SOURCE, 'src', '电源 E', 1, 0, 6, 'emf'),
      1.3, 3.0, 1.3, 2.0, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.AMMETER, 'a0', 'A', 1, 2, 0, ''),
      1.9, 4.3, 2.9, 4.3, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.RESISTOR, 'r1', 'R₁', 2, 3, 20, 'r1'),
      3.4, 4.3, 4.8, 4.3, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.RESISTOR, 'r2', 'R₂', 3, 4, 30, 'r2'),
      7.0, 3.5, 7.0, 2.1, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.SWITCH, 'sw', 'S', 4, 0, 1, 'switch'),
      4.6, 1.1, 2.0, 1.1, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.VOLTMETER, 'v1', 'V₁', 2, 3, 0, ''),
      3.4, 4.3, 4.8, 4.3, 0, -1.05);
    ElectricalScenes.place(spec.add(ComponentKind.VOLTMETER, 'v2', 'V₂', 3, 4, 0, ''),
      7.0, 3.5, 7.0, 2.1, 1.25, 0);

    spec.wire(ElectricalScenes.poly([[1.3, 4.3], [1.9, 4.3]]));
    spec.wire(ElectricalScenes.poly([[2.9, 4.3], [3.4, 4.3]]));
    spec.wire(ElectricalScenes.poly([[4.8, 4.3], [7.0, 4.3]]));
    spec.wire(ElectricalScenes.poly([[1.3, 4.3], [1.3, 3.0]]));
    spec.wire(ElectricalScenes.poly([[1.3, 2.0], [1.3, 1.1]]));
    spec.wire(ElectricalScenes.poly([[1.3, 1.1], [2.0, 1.1]]));
    spec.wire(ElectricalScenes.poly([[4.6, 1.1], [7.0, 1.1]]));
    spec.wire(ElectricalScenes.poly([[7.0, 1.1], [7.0, 2.1]]));
    spec.wire(ElectricalScenes.poly([[7.0, 3.5], [7.0, 4.3]]));
    return spec;
  }

  private static parallelCircuit(): CircuitSpec {
    const spec = new CircuitSpec();
    // n0 负极 n1 正极 n2 分叉点(顶轨) n3 汇合点(底轨) n4/n5 两条支路的中点
    ElectricalScenes.place(spec.add(ComponentKind.SOURCE, 'src', '电源 E', 1, 0, 6, 'emf'),
      1.3, 3.2, 1.3, 2.2, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.AMMETER, 'a0', 'A', 1, 2, 0, ''),
      1.9, 4.6, 2.9, 4.6, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.RESISTOR, 'r1', 'R₁', 2, 4, 20, 'r1'),
      4.6, 4.0, 4.6, 2.8, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.AMMETER, 'a1', 'A₁', 4, 3, 0, ''),
      4.6, 2.3, 4.6, 1.3, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.RESISTOR, 'r2', 'R₂', 2, 5, 30, 'r2'),
      7.2, 4.0, 7.2, 2.8, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.AMMETER, 'a2', 'A₂', 5, 3, 0, ''),
      7.2, 2.3, 7.2, 1.3, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.SWITCH, 'sw', 'S', 3, 0, 1, 'switch'),
      3.2, 1.0, 2.0, 1.0, 0, 0);

    spec.wire(ElectricalScenes.poly([[1.3, 4.6], [1.9, 4.6]]));
    spec.wire(ElectricalScenes.poly([[2.9, 4.6], [7.9, 4.6]]));
    spec.wire(ElectricalScenes.poly([[1.3, 4.6], [1.3, 3.2]]));
    spec.wire(ElectricalScenes.poly([[1.3, 2.2], [1.3, 1.0]]));
    spec.wire(ElectricalScenes.poly([[1.3, 1.0], [2.0, 1.0]]));
    spec.wire(ElectricalScenes.poly([[3.2, 1.0], [7.9, 1.0]]));
    spec.wire(ElectricalScenes.poly([[4.6, 4.6], [4.6, 4.0]]));
    spec.wire(ElectricalScenes.poly([[7.2, 4.6], [7.2, 4.0]]));
    spec.wire(ElectricalScenes.poly([[4.6, 2.8], [4.6, 2.3]]));
    spec.wire(ElectricalScenes.poly([[7.2, 2.8], [7.2, 2.3]]));
    spec.wire(ElectricalScenes.poly([[4.6, 1.3], [4.6, 1.0]]));
    spec.wire(ElectricalScenes.poly([[7.2, 1.3], [7.2, 1.0]]));
    return spec;
  }

  /**
   * 基尔霍夫定律验证板:两个节点、三条支路,其中两条各含一个电源。
   *
   * 参考方向是这条电路的全部教学目的,所以三只电流表**统一**取「nodeB 接节点 A」,
   * 于是读数 SIGNED_I > 0 就是流入节点 A —— KCL 变成"三个读数相加为零"这一件可算的事,
   * 而其中一只为负不是故障,是电流真的反着流(E₂ 被充电)。
   * 反接 E₂ 就能把这个符号约定从"老师说的"变成"学生自己撞见的"。
   *
   * 不接电压表:每条元件的端电压求解器都直接给(`U:<id>`),再并一只 1e7 Ω 的表
   * 只会给读数添一个量级 1e-6 的扰动 —— 那是 ele-u-006 要专门研究的误差,不该顺路混进来。
   */
  private static kirchhoffCircuit(): CircuitSpec {
    const spec = new CircuitSpec();
    // n0 底轨(参考点) n1 节点 A;n2/n3 左支路中间点,n4 中支路,n5/n6 右支路
    const x0 = 1.6;
    const x1 = 4.5;
    const x2 = 7.4;
    const railTop = 4.5;
    const railBottom = 1.0;

    ElectricalScenes.place(spec.add(ComponentKind.SOURCE, 'src1', 'E₁', 2, 0, 6, 'emf1'),
      x0, 2.2, x0, 1.2, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.RESISTOR, 'r1', 'R₁', 3, 2, 10, 'r1'),
      x0, 3.6, x0, 2.6, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.AMMETER, 'a1', 'A₁', 3, 1, 0, ''),
      x0, 4.0, x0, railTop, 0, 0);

    ElectricalScenes.place(spec.add(ComponentKind.RESISTOR, 'r2', 'R₂', 4, 0, 20, 'r2'),
      x1, 2.6, x1, 1.2, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.AMMETER, 'a2', 'A₂', 4, 1, 0, ''),
      x1, 4.0, x1, railTop, 0, 0);

    ElectricalScenes.place(spec.add(ComponentKind.SOURCE, 'src2', 'E₂', 5, 0, 6, 'emf2'),
      x2, 2.2, x2, 1.2, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.RESISTOR, 'r3', 'R₃', 6, 5, 10, 'r3'),
      x2, 3.6, x2, 2.6, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.AMMETER, 'a3', 'A₃', 6, 1, 0, ''),
      x2, 4.0, x2, railTop, 0, 0);

    spec.wire(ElectricalScenes.poly([[x0, railTop], [x2, railTop]]));
    spec.wire(ElectricalScenes.poly([[x0, railBottom], [x2, railBottom]]));
    spec.wire(ElectricalScenes.poly([[x0, 1.2], [x0, railBottom]]));
    spec.wire(ElectricalScenes.poly([[x1, 1.2], [x1, railBottom]]));
    spec.wire(ElectricalScenes.poly([[x2, 1.2], [x2, railBottom]]));
    spec.wire(ElectricalScenes.poly([[x0, 2.2], [x0, 2.6]]));
    spec.wire(ElectricalScenes.poly([[x0, 3.6], [x0, 4.0]]));
    spec.wire(ElectricalScenes.poly([[x1, 2.6], [x1, 4.0]]));
    spec.wire(ElectricalScenes.poly([[x2, 2.2], [x2, 2.6]]));
    spec.wire(ElectricalScenes.poly([[x2, 3.6], [x2, 4.0]]));
    return spec;
  }

  /**
   * 最大功率传输电路:理想电源 + 固定内阻 R₀ + 可变负载 R_L,单回路。
   *
   * 这是 `RHEOSTAT` 元件第一次被场景用上 —— 它有绘制分支却没有调用方已经很久了。
   * 负载用变阻器而不是定值电阻,因为这条实验的全部内容就是"扫一个量找极大值":
   * 学生要亲手把 RL 从远小于 R₀ 拉到远大于 R₀,看功率先升后降、看效率单调上升,
   * 然后撞上"输出功率最大时效率只有 50%"这个矛盾 —— 那才是电力工程与信号工程
   * 分头设计的原因。
   */
  private static maxPowerCircuit(): CircuitSpec {
    const spec = new CircuitSpec();
    // n0 底轨(参考点) n1 电源正极 n2 R₀ 与电流表之间 n3 负载上端
    const left = 1.6;
    const right = 7.4;
    const top = 4.2;
    const bottom = 1.2;

    ElectricalScenes.place(spec.add(ComponentKind.SOURCE, 'src', '电源 E', 1, 0, 6, 'emf'),
      left, 3.4, left, 2.4, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.RESISTOR, 'r0', 'R₀', 2, 1, 10, 'r0'),
      4.0, top, 2.6, top, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.AMMETER, 'a1', 'A', 2, 3, 0, ''),
      5.2, top, 6.2, top, 0, 0);
    ElectricalScenes.place(spec.add(ComponentKind.RHEOSTAT, 'rL', 'RL', 3, 0, 10, 'rL'),
      right, 3.2, right, 2.2, 0, 0);

    spec.wire(ElectricalScenes.poly([[left, 2.4], [left, bottom]]));
    spec.wire(ElectricalScenes.poly([[left, bottom], [right, bottom]]));
    spec.wire(ElectricalScenes.poly([[right, bottom], [right, 2.2]]));
    spec.wire(ElectricalScenes.poly([[left, 3.4], [left, top]]));
    spec.wire(ElectricalScenes.poly([[left, top], [2.6, top]]));
    spec.wire(ElectricalScenes.poly([[4.0, top], [5.2, top]]));
    spec.wire(ElectricalScenes.poly([[6.2, top], [right, top]]));
    spec.wire(ElectricalScenes.poly([[right, top], [right, 3.2]]));
    return spec;
  }

  private static maxPowerMeta(): ExperimentMeta {
    const meta = new ExperimentMeta();
    meta.id = 'max-power';
    meta.title = '负载获得最大功率的条件';
    meta.subject = Subject.PHYSICS_ELECTRICAL;
    meta.renderer = RendererKind.PHYSICS_2D;
    meta.summary = '固定电源电动势与内阻 R₀，连续改变负载 RL，作 P–I 曲线找极大值，并对照同一批读数下的电源效率。';
    meta.gradeBand = '大学电工电子 · 大一下';
    meta.durationMinutes = 90;
    meta.worldWidth = WORLD_W;
    meta.worldHeight = WORLD_H;
    meta.params.push(SceneBuilders.param('emf', '电源电动势 E', 'V', 2, 12, 0.5, 6, '电源'));
    meta.params.push(SceneBuilders.param('r0', '电源内阻 R₀', 'Ω', 1, 100, 1, 10, '电源'));
    meta.params.push(SceneBuilders.param('rL', '负载电阻 RL', 'Ω', 0.5, 200, 0.5, 10, '负载'));
    meta.observables.push(SceneBuilders.observable('SIGNED_I:rL', '回路电流 I', 'A', 4, true));
    meta.observables.push(SceneBuilders.observable('U:rL', '负载两端电压 U_L', 'V', 3, true));
    meta.observables.push(SceneBuilders.observable('U:r0', '内阻 R₀ 两端电压', 'V', 3, false));
    meta.observables.push(SceneBuilders.observable('P:rL', '负载获得的功率 P_L', 'W', 3, true));
    meta.observables.push(SceneBuilders.observable('P:src', '电源输出的总功率 P', 'W', 3, true));
    meta.observables.push(SceneBuilders.observable('Req', '电源看进去的总电阻', 'Ω', 2, false));
    /*
     * 两条曲线各说一半:横轴取电流的这条是向下弯的抛物线,极大值就在 I = E/(2R₀) ——
     * 也就是 R_L = R₀ 那一点。另一条把负载功率与电源总功率画在一起,
     * 两线的间距就是内阻烧掉的部分:R_L 越大两线越贴近(效率高),但功率线却往下掉。
     * 「最大输出功率」与「最高效率」的矛盾是看出来的,不是背下来的。
     */
    meta.charts.push(SceneBuilders.xyChart('负载功率随电流变化', 'SIGNED_I:rL', 'I', 'A', 'P', 'W', [
      SceneBuilders.trace('P:rL', 'P_L', SceneBuilders.palette(0))
    ]));
    meta.charts.push(SceneBuilders.timeChart('负载功率与电源总功率', 'P', 'W', [
      SceneBuilders.trace('P:src', '电源输出 P', SceneBuilders.palette(1)),
      SceneBuilders.trace('P:rL', '负载获得 P_L', SceneBuilders.palette(0))
    ]));
    meta.tasks.push(SceneBuilders.task('peak-power',
      '保持 E=6 V、R₀=10 Ω，把 RL 从 1 Ω 扫到 100 Ω，给出负载功率的最大值。', 0.9, 0.02));
    meta.tasks.push(SceneBuilders.task('peak-at-r0',
      '最大功率出现时 RL 是 R₀ 的多少倍？换一组 R₀ 再验一次。', 1, 0.05));
    meta.tasks.push(SceneBuilders.task('efficiency-at-peak',
      '在最大功率点算电源效率 η = P_L / P，并说明为什么把 RL 再调大反而更省电却损失功率。', 0.5, 0.02));
    meta.tasks.push(SceneBuilders.task('power-vs-efficiency',
      '举一个电力工程按「高效率」设计、一个信号工程按「匹配负载」设计的例子，说明这两种追求为什么相反。',
      Number.NaN, 0));
    return meta;
  }

  private static seriesMeta(): ExperimentMeta {
    const meta = new ExperimentMeta();
    meta.id = 'series-circuit';
    meta.title = '串联电路的电压与电阻规律';
    meta.subject = Subject.PHYSICS_ELECTRICAL;
    meta.renderer = RendererKind.PHYSICS_2D;
    meta.summary = '两只定值电阻串联，同时读取干路电流与各段电压，验证 U=U₁+U₂ 与 R=R₁+R₂。';
    meta.gradeBand = '初中物理 · 九年级';
    meta.durationMinutes = 15;
    meta.worldWidth = WORLD_W;
    meta.worldHeight = WORLD_H;
    meta.params.push(SceneBuilders.param('emf', '电源电压', 'V', 2, 12, 0.5, 6, '电源'));
    meta.params.push(SceneBuilders.switchParam('switch', '开关 S', true, '电源'));
    meta.params.push(SceneBuilders.param('r1', '电阻 R₁', 'Ω', 5, 100, 1, 20, '定值电阻'));
    meta.params.push(SceneBuilders.param('r2', '电阻 R₂', 'Ω', 5, 100, 1, 30, '定值电阻'));
    meta.observables.push(SceneBuilders.observable('I:a0', '干路电流 I', 'A', 3, true));
    meta.observables.push(SceneBuilders.observable('I:r1', '通过 R₁ 的电流', 'A', 4, true));
    meta.observables.push(SceneBuilders.observable('I:r2', '通过 R₂ 的电流', 'A', 4, false));
    meta.observables.push(SceneBuilders.observable('U:v1', 'R₁ 两端电压 U₁', 'V', 3, true));
    meta.observables.push(SceneBuilders.observable('U:v2', 'R₂ 两端电压 U₂', 'V', 3, false));
    meta.observables.push(SceneBuilders.observable('U:src', '总电压 U', 'V', 3, false));
    meta.observables.push(SceneBuilders.observable('Req', '总电阻 R', 'Ω', 2, false));
    /*
     * 伏安特性图的横轴是另一只电表的读数而不是时间。要描出过原点的直线,
     * 操作方式是固定 R₁、连续改变电源电压 —— 若反过来改 R₁,
     * 各点会落在斜率不同的多条直线上,图就失去意义了。
     */
    meta.charts.push(SceneBuilders.xyChart('R₁ 的伏安特性', 'I:r1', 'I₁', 'A', 'U', 'V', [
      SceneBuilders.trace('U:v1', 'U₁=IR₁', SceneBuilders.palette(0))
    ]));
    meta.charts.push(SceneBuilders.timeChart('干路电流 I-t', 'I', 'A', [
      SceneBuilders.trace('I:a0', 'I', SceneBuilders.palette(0))
    ]));
    meta.tasks.push(SceneBuilders.task('series-voltage', '令 R₁=20 Ω、R₂=30 Ω，读出 U₁ 与 U₂，检验 U₁+U₂ 是否等于总电压。', 0, 0.02));
    meta.tasks.push(SceneBuilders.task('series-ratio', '保持电源电压不变，把 R₂ 改为 80 Ω，U₁ 如何变化？说明串联分压与电阻的关系。', Number.NaN, 0));
    return meta;
  }

  private static kirchhoffMeta(): ExperimentMeta {
    const meta = new ExperimentMeta();
    meta.id = 'kirchhoff';
    meta.title = '基尔霍夫定律的验证';
    meta.subject = Subject.PHYSICS_ELECTRICAL;
    meta.renderer = RendererKind.PHYSICS_2D;
    meta.summary = '两条含源支路与一条纯电阻支路并接在节点 A 与底轨之间，按参考方向读三条支路电流，检验 ΣI=0 与回路 ΣU=0。';
    meta.gradeBand = '大学电工电子 · 大一下';
    meta.durationMinutes = 90;
    meta.worldWidth = WORLD_W;
    meta.worldHeight = WORLD_H;
    meta.params.push(SceneBuilders.param('emf1', '电源电动势 E₁', 'V', -12, 12, 0.5, 6, '电源'));
    meta.params.push(SceneBuilders.param('emf2', '电源电动势 E₂', 'V', -12, 12, 0.5, 6, '电源'));
    meta.params.push(SceneBuilders.param('r1', '支路 1 电阻 R₁', 'Ω', 1, 200, 1, 10, '定值电阻'));
    meta.params.push(SceneBuilders.param('r2', '支路 2 电阻 R₂', 'Ω', 1, 200, 1, 20, '定值电阻'));
    meta.params.push(SceneBuilders.param('r3', '支路 3 电阻 R₃', 'Ω', 1, 200, 1, 10, '定值电阻'));
    /*
     * 三条支路电流一律用 SIGNED_I:本实验要验的是"代数和为零",
     * 取绝对值的 I: 会把方向信息抹掉,三个正数相加永远不为零,实验就变成错的。
     */
    meta.observables.push(SceneBuilders.observable('SIGNED_I:a1', '支路 1 电流 I₁（流入节点 A 为正）', 'A', 4, true));
    meta.observables.push(SceneBuilders.observable('SIGNED_I:a2', '支路 2 电流 I₂（流入节点 A 为正）', 'A', 4, true));
    meta.observables.push(SceneBuilders.observable('SIGNED_I:a3', '支路 3 电流 I₃（流入节点 A 为正）', 'A', 4, true));
    meta.observables.push(SceneBuilders.observable('V:1', '节点 A 的电位 U_A（对底轨）', 'V', 3, false));
    meta.observables.push(SceneBuilders.observable('U:r1', 'R₁ 两端电压', 'V', 3, false));
    meta.observables.push(SceneBuilders.observable('U:r2', 'R₂ 两端电压', 'V', 3, false));
    meta.observables.push(SceneBuilders.observable('U:r3', 'R₃ 两端电压', 'V', 3, false));
    meta.observables.push(SceneBuilders.observable('U:src1', 'E₁ 两端电压（路端电压）', 'V', 3, false));
    meta.observables.push(SceneBuilders.observable('U:src2', 'E₂ 两端电压（路端电压）', 'V', 3, false));
    meta.charts.push(SceneBuilders.timeChart('三条支路电流', 'I', 'A', [
      SceneBuilders.trace('SIGNED_I:a1', 'I₁', SceneBuilders.palette(0)),
      SceneBuilders.trace('SIGNED_I:a2', 'I₂', SceneBuilders.palette(1)),
      SceneBuilders.trace('SIGNED_I:a3', 'I₃', SceneBuilders.palette(2))
    ]));
    meta.tasks.push(SceneBuilders.task('kcl-closure',
      '把 I₁、I₂、I₃ 按参考方向（流入节点 A 为正）相加，给出节点 A 的电流闭合差。', 0, 0.02));
    meta.tasks.push(SceneBuilders.task('kcl-ratio',
      '令 E₁=E₂=6 V、R₁=R₃=10 Ω、R₂=20 Ω，读出中支路电流与一条源支路电流的比值 I₂/I₁。', 2, 0.05));
    meta.tasks.push(SceneBuilders.task('kvl-loop',
      '把 E₁ 调到 0（或反接），说明 I₂ 的符号为什么可能翻转；再按顺时针与逆时针各累加一次回路 1 的电压，给回路相对闭合差。',
      Number.NaN, 0));
    return meta;
  }

  private static parallelMeta(): ExperimentMeta {
    const meta = new ExperimentMeta();
    meta.id = 'parallel-circuit';
    meta.title = '并联电路的电流规律';
    meta.subject = Subject.PHYSICS_ELECTRICAL;
    meta.renderer = RendererKind.PHYSICS_2D;
    meta.summary = '两只电阻并联，三条支路各接一只电流表，验证 I=I₁+I₂ 与支路电流同电阻成反比。';
    meta.gradeBand = '初中物理 · 九年级';
    meta.durationMinutes = 15;
    meta.worldWidth = WORLD_W;
    meta.worldHeight = WORLD_H;
    meta.params.push(SceneBuilders.param('emf', '电源电压', 'V', 2, 12, 0.5, 6, '电源'));
    meta.params.push(SceneBuilders.switchParam('switch', '开关 S', true, '电源'));
    meta.params.push(SceneBuilders.param('r1', '电阻 R₁', 'Ω', 5, 100, 1, 20, '定值电阻'));
    meta.params.push(SceneBuilders.param('r2', '电阻 R₂', 'Ω', 5, 100, 1, 30, '定值电阻'));
    meta.observables.push(SceneBuilders.observable('I:a0', '干路电流 I', 'A', 3, true));
    meta.observables.push(SceneBuilders.observable('I:a1', '支路电流 I₁', 'A', 3, true));
    meta.observables.push(SceneBuilders.observable('I:a2', '支路电流 I₂', 'A', 3, true));
    meta.observables.push(SceneBuilders.observable('U:r1', 'R₁ 两端电压', 'V', 3, false));
    meta.observables.push(SceneBuilders.observable('U:r2', 'R₂ 两端电压', 'V', 3, false));
    meta.observables.push(SceneBuilders.observable('Req', '并联总电阻 R', 'Ω', 2, false));
    meta.observables.push(SceneBuilders.observable('P:src', '电源输出功率', 'W', 2, false));
    meta.charts.push(SceneBuilders.timeChart('干路与支路电流', 'I', 'A', [
      SceneBuilders.trace('I:a0', 'I', SceneBuilders.palette(0)),
      SceneBuilders.trace('I:a1', 'I₁', SceneBuilders.palette(1)),
      SceneBuilders.trace('I:a2', 'I₂', SceneBuilders.palette(2))
    ]));
    // 并联时两支路电压相同,故 I₂ 与 I₁ 成正比、斜率为 R₁/R₂
    meta.charts.push(SceneBuilders.xyChart('两支路电流关系', 'I:a1', 'I₁', 'A', 'I', 'A', [
      SceneBuilders.trace('I:a2', 'I₂', SceneBuilders.palette(0))
    ]));
    meta.tasks.push(SceneBuilders.task('parallel-current', '读出 I、I₁、I₂，检验 I 是否等于两支路电流之和。', 0, 0.02));
    meta.tasks.push(SceneBuilders.task('parallel-inverse', '令 R₁=20 Ω、R₂=60 Ω，比较 I₁ 与 I₂ 的比值，并解释为什么与电阻不成正比。', 3, 0.05));
    return meta;
  }
}
