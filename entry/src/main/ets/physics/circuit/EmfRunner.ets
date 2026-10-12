import { FactSheet } from '../../model/FactSheet';
import { CircuitRunner } from './CircuitRunner';
import { CircuitSpec } from './CircuitModel';

/**
 * 电阻箱能拨到的挡位。
 *
 * 不是等差而是十进制挡:真实电阻箱就是 ×1 / ×10 两圈拨出来的,
 * 而"减一档"若是等差的,从 20 Ω 起步要按 19 下才能到开路那端 —— 没人这么做实验。
 */
const BOX_STEPS: number[] = [1, 2, 3, 5, 8, 12, 20, 30, 50, 100];

/** 一条被学生亲手记下的读数:电阻箱挡位、路端电压、干路电流 */
class EmfPoint {
  box: number = 0;
  voltage: number = 0;
  current: number = 0;
}

/**
 * 测量电源的电动势和内阻(高中物理必修三,地图条目 `phy-sr-010`)。
 *
 * 电路是「理想源 + 内阻 + 电阻箱」,电压表接在电源两端读路端电压:
 * U = E − I·r,所以描出来的 U-I 线纵截距是 E、斜率绝对值是 r —— 这条实验的分
 * 全在**取点**上:点取得少、挤在一小段电流里,截距就得靠长距离外推,结果自然不准。
 * 于是判据读的是学生自己按出来的那几下:
 * 记了几组、电流铺开的跨度有多大、最小那组有没有接近开路、有没有哪组冲出电流表量程。
 *
 * E 与 r 在这里是**被测的未知量**,不是判据的尺子 —— 判据一条都不读它们,
 * 只读读数本身的分布。量程(0.6 A)写在读数标签上,不藏进细则。
 */
export class EmfRunner extends CircuitRunner {
  private points: EmfPoint[] = [];

  constructor(spec: CircuitSpec) {
    super(spec);
  }

  protected onSetup(): void {
    super.onSetup();
    this.points = [];
  }

  protected onAction(key: string): void {
    if (key === 'record') {
      const point = new EmfPoint();
      point.box = this.readParam('box');
      point.voltage = this.readObservable('U:v1');
      point.current = this.readObservable('I:a1');
      this.points.push(point);
      return;
    }
    this.dialBox(key === 'box+' ? 1 : key === 'box-' ? -1 : 0);
  }

  /** 沿挡位表拨一格。滑杆也还在:拨档是"换下一种接法",滑杆是"细调",两样都留 */
  private dialBox(direction: number): void {
    if (direction === 0) {
      return;
    }
    const current = this.readParam('box');
    let at = 0;
    for (let i = 1; i < BOX_STEPS.length; i++) {
      if (Math.abs(BOX_STEPS[i] - current) < Math.abs(BOX_STEPS[at] - current)) {
        at = i;
      }
    }
    const next = Math.max(0, Math.min(BOX_STEPS.length - 1, at + direction));
    this.setParam('box', BOX_STEPS[next]);
  }

  readObservable(key: string): number {
    switch (key) {
      case 'emfRecordCount':
        return this.points.length;
      case 'emfCurrentSpread':
        return this.spread();
      case 'emfMaxCurrent':
        return this.extreme(false);
      case 'emfMinCurrent':
        return this.extreme(true);
      default:
        return super.readObservable(key);
    }
  }

  protected onCollectFacts(sheet: FactSheet): void {
    sheet.set('emfRecordCount', this.points.length);
    sheet.set('emfCurrentSpread', this.spread());
    sheet.set('emfMaxCurrent', this.extreme(false));
    sheet.set('emfMinCurrent', this.extreme(true));
    sheet.mark('recorded', this.points.length > 0 ? this.time : -1);
  }

  /** 最大与最小读数之间铺开多大一段。没记或只记一组就是 0 —— 一段都没有 */
  private spread(): number {
    if (this.points.length < 2) {
      return 0;
    }
    return this.extreme(false) - this.extreme(true);
  }

  /** 读数里最靠开路(min=true)或最靠短路那一端的那组电流 */
  private extreme(lowest: boolean): number {
    let best = Number.NaN;
    for (const p of this.points) {
      if (!Number.isFinite(p.current)) {
        continue;
      }
      if (!Number.isFinite(best)) {
        best = p.current;
      } else if (lowest ? p.current < best : p.current > best) {
        best = p.current;
      }
    }
    return best;
  }

  private readParam(key: string): number {
    const value = this.getParam(key);
    return Number.isFinite(value) ? value : 0;
  }
}
