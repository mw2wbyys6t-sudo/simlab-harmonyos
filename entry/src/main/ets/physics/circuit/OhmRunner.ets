import { FactSheet } from '../../model/FactSheet';
import { CircuitRunner } from './CircuitRunner';
import { CircuitSpec } from './CircuitModel';

/** 一条被学生亲手记下的读数:定值电阻、它两端电压、回路电流 */
class OhmPoint {
  resistance: number = 0;
  voltage: number = 0;
  current: number = 0;
}

/** 电压归到 0.15 V 一档:比这更近的两次读数在实验里就是"同一个电压" */
const VOLTAGE_BUCKET: number = 0.15;

/**
 * 探究导体中的电流与电压、电阻的关系(初中物理,地图条目 `phy-jr-017`)。
 *
 * 电路本身不新:电源 + 滑动变阻器 + 电流表 + 定值电阻,和最大功率那页同一套 MNA。
 * 新的是**这个实验真正考的东西** —— 控制变量:
 * 保持 R 不变改 U(看 I 与 U 成正比),保持 U 不变改 R(看 I 与 R 成反比)。
 * 所以这里记的不是"算得对不对",而是**学生自己按下的那几下有没有章法**:
 * 同一个 R 下取过几档**不同**电压、换过几种电阻、换电阻之后有没有把电压调回同一档、
 * 第一组读数时滑片在不在最大处。
 *
 * 判分只读这些动作留下的事实,不读参数值本身 —— 施予的阻值不能当学生的选择来判。
 * 及格线(滑片多大算"放到最大处")写进细则,不写在这里:这里只报量到的位置。
 */
export class OhmRunner extends CircuitRunner {
  private points: OhmPoint[] = [];
  /** 第一组读数那一刻滑片停在多少欧。没记过就不进事实清单 —— 没量过的事不报 */
  private firstSlide: number = Number.NaN;

  constructor(spec: CircuitSpec) {
    super(spec);
  }

  protected onSetup(): void {
    super.onSetup();
    this.points = [];
    this.firstSlide = Number.NaN;
  }

  protected onAction(key: string): void {
    if (key === 'record') {
      const point = new OhmPoint();
      point.resistance = this.readParam('fixed');
      point.voltage = this.readObservable('U:rx');
      point.current = this.readObservable('I:rx');
      if (this.points.length === 0) {
        this.firstSlide = this.readParam('slide');
      }
      this.points.push(point);
      return;
    }
    const step = this.readParam('fixed') + (key === 'fixed+' ? 5 : key === 'fixed-' ? -5 : 0);
    if (key === 'fixed+' || key === 'fixed-') {
      this.setParam('fixed', Math.max(5, Math.min(20, step)));
    }
  }

  readObservable(key: string): number {
    switch (key) {
      case 'ohmRecordCount':
        return this.points.length;
      case 'ohmMaxPointsAtOneR':
        return this.maxVoltageBuckets();
      case 'ohmResistances':
        return this.distinctResistances();
      case 'ohmSharedVoltages':
        return this.sharedVoltageSteps();
      default:
        return super.readObservable(key);
    }
  }

  protected onCollectFacts(sheet: FactSheet): void {
    sheet.set('ohmRecordCount', this.points.length);
    sheet.set('ohmMaxPointsAtOneR', this.maxVoltageBuckets());
    sheet.set('ohmResistances', this.distinctResistances());
    sheet.set('ohmSharedVoltages', this.sharedVoltageSteps());
    if (this.points.length > 0) {
      sheet.set('ohmFirstSlide', this.firstSlide);
    }
    sheet.mark('recorded', this.points.length > 0 ? this.time : -1);
  }

  /**
   * 同一只电阻下取过几档**不同**电压。
   *
   * 数的是档数而不是记录条数:停在同一个滑片位置连按十次「记录」,
   * 一条 I-U 图线上仍然只有一个点 —— 按条数算就等于奖励刷按钮。
   */
  private maxVoltageBuckets(): number {
    const keys: string[] = [];
    const buckets: string[][] = [];
    for (const p of this.points) {
      const hit = keys.indexOf(String(p.resistance));
      const list = hit < 0 ? this.newBucketGroup(keys, buckets, String(p.resistance)) : buckets[hit];
      const bucket = this.voltageBucket(p);
      if (list.indexOf(bucket) < 0) {
        list.push(bucket);
      }
    }
    let best = 0;
    for (const list of buckets) {
      if (best < list.length) {
        best = list.length;
      }
    }
    return best;
  }

  private newBucketGroup(keys: string[], buckets: string[][], key: string): string[] {
    keys.push(key);
    const list: string[] = [];
    buckets.push(list);
    return list;
  }

  private distinctResistances(): number {
    const seen: number[] = [];
    for (const p of this.points) {
      if (seen.indexOf(p.resistance) < 0) {
        seen.push(p.resistance);
      }
    }
    return seen.length;
  }

  /**
   * 同一个电压档上出现过几种电阻 —— 「保持电压不变改电阻」这半段有没有做,看的就是它。
   *
   * 只数电阻也不同的那些记录:同一档电压上重复读同一个电阻,不构成"比较"。
   */
  private sharedVoltageSteps(): number {
    const keys: string[] = [];
    const resistances: number[][] = [];
    for (const p of this.points) {
      const bucket = this.voltageBucket(p);
      let hit = keys.indexOf(bucket);
      if (hit < 0) {
        keys.push(bucket);
        resistances.push([p.resistance]);
        continue;
      }
      const list = resistances[hit];
      if (list.indexOf(p.resistance) < 0) {
        list.push(p.resistance);
      }
    }
    let shared = 0;
    for (const list of resistances) {
      if (list.length >= 2) {
        shared = shared + 1;
      }
    }
    return shared;
  }

  private voltageBucket(p: OhmPoint): string {
    if (!Number.isFinite(p.voltage)) {
      return 'NaN';
    }
    return String(Math.round(p.voltage / VOLTAGE_BUCKET));
  }

  private readParam(key: string): number {
    const value = this.getParam(key);
    return Number.isFinite(value) ? value : 0;
  }
}
