import { Profile } from '../geometry/Profile';
import { Brine, Calibration, Separations } from './Brine';
import { Spatial } from './Pose';
import { VesselBase } from './VesselBase';

/**
 * 容器 = 共用外壳(几何、位姿、支撑、损伤)+ 提纯链路的相账本。
 *
 * 外壳在 `VesselBase`,反应链路的 `chemistry/BenchModel.Vessel` 继承同一个外壳 ——
 * 两套容器模型必然在某个字段上悄悄分叉,而分叉的代价是渲染与判据各说一套。
 * 账本没有合并:`Brine` 按相演化,试剂按化学计量反应,它们不是同一件事的两种写法。
 */
export class Container extends VesselBase {
  brine: Brine = new Brine();

  static of(id: string, label: string, profile: Profile): Container {
    const item = new Container();
    item.id = id;
    item.label = label;
    item.profile = profile;
    return item;
  }

  liquidHeight(): number {
    return this.liquidHeightFor(this.brine.waterMl);
  }

  /** 装了多少(0~1)。> 1 表示已经漫出来 */
  fillRatio(): number {
    const capacity = this.profile.capacity();
    return capacity <= 0 ? 0 : this.brine.waterMl / capacity;
  }

  /** 当前液面的表面积(cm²),蒸发快慢由它决定 */
  surfaceArea(): number {
    return this.surfaceAreaFor(this.brine.waterMl);
  }

  freeCapacityMl(): number {
    return this.freeCapacityFor(this.brine.waterMl);
  }

  isFull(): boolean {
    return this.brine.waterMl >= this.profile.capacity() - 1e-9;
  }

  /**
   * 器底破损时漏走内容物,返回漏走的质量(g)。
   *
   * 外壳只算「该漏多少」(leakFraction),**怎么从账本里取走是账本自己的事** ——
   * 漏失必须按比例从各相扣掉并记进第三笔账,否则 I1 守恒当场破掉。
   */
  drainFraction(fraction: number): number {
    return Separations.leak(this.brine, fraction);
  }
}

/** 一次倾倒步进的结果,每条都是可复算的证据候选。 */
export class PourResult {
  /** 真正离开源容器的体积 */
  leftSourceMl: number = 0;
  /** 最终留在目标容器里的体积 */
  arrivedMl: number = 0;
  /** 溅出或漫出而洒掉的质量(水) */
  spilledMl: number = 0;
  spilledSaltG: number = 0;
  spilledSandG: number = 0;
  /** 目标容器已装不下,液面被压回杯口 */
  overflowed: boolean = false;
  /** 没对准口部,液体整段洒在桌面上 */
  missedTarget: boolean = false;
  /** 源容器已倒空 */
  sourceEmpty: boolean = false;
  /** 因为没被握住而倒不出来 */
  refusedNotHeld: boolean = false;
}

/**
 * 倾倒模型:握在手里才倒得出、倾角决定流多快、对准口部才进得去、引流决定溅多少。
 * 全部单调、确定性、无随机 —— 真实失误来自手的抖动与偏移,而不是我们掷骰子。
 *
 * 流速用 √液柱高 近似托里拆利,是为了让「越倒越慢」这个可观察现象成立;
 * 系数本身属演示标定(R2),所以断言只测单调性与守恒,不测绝对流速真实。
 */
export class PourModel {
  static flowRate(tiltDeg: number, liquidHeight: number): number {
    if (tiltDeg <= Calibration.POUR_ONSET_DEG || liquidHeight <= 0) {
      return 0;
    }
    const span = 90 - Calibration.POUR_ONSET_DEG;
    const tiltFactor = Math.min(1, (tiltDeg - Calibration.POUR_ONSET_DEG) / span);
    return Calibration.POUR_COEFF * tiltFactor * Math.sqrt(liquidHeight);
  }

  /**
   * 推进 dt 秒的倾倒。
   * @param guided 是否用玻璃棒引流
   */
  static step(source: Container, target: Container, dt: number, guided: boolean): PourResult {
    const result = new PourResult();
    result.sourceEmpty = source.brine.waterMl <= 1e-12;
    if (!source.canPour()) {
      result.refusedNotHeld = true;
      return result;
    }
    const rate = PourModel.flowRate(source.pose.tiltDeg, source.liquidHeight());
    const wanted = rate * dt;
    if (wanted <= 0) {
      return result;
    }
    const disturb = guided ? Calibration.GUIDED_DISTURB : Calibration.UNGUIDED_DISTURB;
    const splashFraction = guided ? Calibration.GUIDED_SPILL : Calibration.UNGUIDED_SPILL;
    const available = Math.min(wanted, source.brine.waterMl);
    if (available <= 0) {
      return result;
    }

    // 没对准口部:液体根本进不去目标,全部洒在桌面上。
    // 直接从源容器计入损失,而不是「先进目标再退出来」—— 它从未属于那个容器。
    if (!Spatial.isAlignedAbove(source.footprint(), target.footprint(), Calibration.AIM_TOLERANCE_CM)) {
      Separations.withdraw(source.brine, available);
      result.leftSourceMl = available;
      result.spilledMl = available;
      result.missedTarget = true;
      result.sourceEmpty = source.brine.waterMl <= 1e-12;
      return result;
    }

    const left = Separations.pour(source.brine, target.brine, wanted, disturb);
    result.leftSourceMl = left;
    result.sourceEmpty = source.brine.waterMl <= 1e-12;
    if (left <= 0) {
      return result;
    }

    // 先让全部液体进目标,再按比例取走「溅出 + 漫出」的部分。
    // 这样带走的水/盐/沙比例天然正确,守恒也就自然成立。
    const overflow = Math.max(0, target.brine.waterMl - target.profile.capacity());
    const splash = left * splashFraction;
    const removed = Separations.withdraw(target.brine, overflow + splash);

    result.overflowed = overflow > 1e-9;
    result.spilledMl = removed;
    result.spilledSaltG = target.brine.losses.spilledSaltG;
    result.spilledSandG = target.brine.losses.spilledSandG;
    result.arrivedMl = left - removed;
    return result;
  }
}

/**
 * 量筒读数模型:视线与凹液面不齐平时读到的数与真实值不符。
 *
 * 视线是一个学生亲手设定的连续量(他拖动眼睛游标到某个高度),
 * 系统不去「猜他有没有仰视」,而是按视差几何给出他会看到什么、
 * 以及他在目标刻度停手时实际倒进了多少。
 * 仰视 → 读数偏小 → 为读到目标值就得倒更多 → 实际体积偏大。
 */
export class ReadingModel {
  /** 真实液面高度 → 眼睛在 eyeHeight 处看到的表观高度 */
  static apparentHeight(trueHeight: number, eyeHeight: number): number {
    return trueHeight - (trueHeight - eyeHeight) * Calibration.PARALLAX_RATIO;
  }

  /** 当前内容物的表观读数(mL)。空筒没有弯月面,读不出数 —— 只能是 0 */
  static readVolume(profile: Profile, contentMl: number, eyeHeight: number): number {
    if (!(contentMl > 0)) {
      return 0;
    }
    const trueHeight = profile.heightForVolume(contentMl);
    return profile.volumeBelow(ReadingModel.clampHeight(profile, trueHeight, eyeHeight));
  }

  /**
   * 学生往量筒里倒水、一直倒到「看见」目标读数为止时,实际倒进了多少。
   * 这是「量取 10 mL」这个任务的全部判据来源。
   */
  static volumeForTargetReading(profile: Profile, targetMl: number, eyeHeight: number): number {
    const targetHeight = profile.heightForVolume(targetMl);
    const ratio = Calibration.PARALLAX_RATIO;
    // 表观 = 真实(1-r) + 眼高·r = 目标高度 → 反解真实高度
    const trueHeight = (targetHeight - eyeHeight * ratio) / (1 - ratio);
    const bounded = Math.max(0, Math.min(profile.totalHeight(), trueHeight));
    return profile.volumeBelow(bounded);
  }

  /** 眼睛与液面齐平时读数即真值 */
  static isLevelWith(trueHeight: number, eyeHeight: number, tolerance: number): boolean {
    return Math.abs(trueHeight - eyeHeight) <= tolerance;
  }

  private static clampHeight(profile: Profile, trueHeight: number, eyeHeight: number): number {
    const apparent = ReadingModel.apparentHeight(trueHeight, eyeHeight);
    return Math.max(0, Math.min(profile.totalHeight(), apparent));
  }
}
