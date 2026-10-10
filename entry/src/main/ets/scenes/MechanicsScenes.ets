import { ExperimentMeta, RendererKind, Subject } from '../model/ExperimentTypes';
import { ExperimentRegistry } from '../runner/ExperimentRegistry';
import { SceneBuilders } from './SceneBuilders';
import { InclineRunner } from '../physics/InclineRunner';
import { SpringMassRunner } from '../physics/SpringMassRunner';

/**
 * 力学场景包。新增力学实验在这里加一段元数据 + 一个求解器注册,
 * 外壳的实验库列表、参数面板、读数区、数据图表全部自动生效。
 */
export class MechanicsScenes {
  static registerAll(): void {
    ExperimentRegistry.register(MechanicsScenes.springMass(), (): SpringMassRunner => new SpringMassRunner());
    ExperimentRegistry.register(MechanicsScenes.incline(), (): InclineRunner => new InclineRunner());
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
    meta.params.push(SceneBuilders.param('amplitude', '初始位移(重置后生效)', 'm', -1.2, 1.2, 0.05, 0.9, '条件'));
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
    meta.params.push(SceneBuilders.param('initialVelocity', '初速度(沿坡向下为负即上滑，重置后生效)', 'm/s', -3, 3, 0.1, 0, '条件'));
    meta.params.push(SceneBuilders.param('startDistance', '起始位置：距坡顶(重置后生效)', 'm', 0, 5, 0.1, 0, '条件'));
    meta.observables.push(SceneBuilders.observable('distance', '距坡顶 s', 'm', 3, true));
    meta.observables.push(SceneBuilders.observable('velocity', '速度 v', 'm/s', 3, true));
    meta.observables.push(SceneBuilders.observable('acceleration', '加速度 a', 'm/s²', 3, false));
    meta.observables.push(SceneBuilders.observable('height', '离地高度 h', 'm', 3, false));
    meta.observables.push(SceneBuilders.observable('kinetic', '动能 Ek', 'J', 3, true));
    meta.observables.push(SceneBuilders.observable('potential', '重力势能 Ep', 'J', 3, true));
    meta.observables.push(SceneBuilders.observable('heat', '摩擦生热 Q', 'J', 3, true));
    meta.observables.push(SceneBuilders.observable('distanceMax', '上滑最远距离', 'm', 3, false));
    meta.observables.push(SceneBuilders.observable('path', '路程(上滑与下滑之和)', 'm', 3, false));
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
}
