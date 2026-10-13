import { FactSheet } from '../model/FactSheet';
import { InclineRunner } from './InclineRunner';
import { WorldSnapshot } from './World2D';
import { TickerTape } from './TickerTape';
import { TAPE_SCALE, TapeStrip } from './TapeStrip';

/** 纸带画在世界顶部这一条上:斜面最长 5 m、60° 时顶点在 4.9 m 以下,互不遮挡 */
const TAPE_Y = 4.9;
const TAPE_X = 0.8;

/**
 * 拖着纸带做匀加速的小车:斜面动力学复用 InclineRunner,新加的是打点计时器。
 *
 * 这里把"运动"和"记录"拆成两个由学生分别按下的动作 —— 先接通电源还是先释放小车,
 * 是这条实验真正的扣分点,也是唯一能当场量出来的那一个:释放与接通之间那段运动
 * 没被打下来,纸带头上就是空的。合成一条"开始"按钮就没有这个事实可读了。
 */
export class TapeCartRunner extends InclineRunner {
  protected tape: TickerTape = new TickerTape();

  protected onSetup(): void {
    super.onSetup();
    this.tape.reset();
  }

  step(dt: number): void {
    if (!this.tape.isReleased()) {
      // 车还没放开:时间在走,位移不动。电源此时打出来的是一段重叠点(车静止)
      this.time += dt;
      this.tape.tick(this.time, this.readObservable('distance'), 0, 0);
      return;
    }
    super.step(dt);
    this.tape.tick(this.time, this.readObservable('distance'),
      this.readObservable('velocity'), this.readObservable('acceleration'));
  }

  protected onAction(key: string): void {
    if (key === 'power') {
      this.tape.setPower(!this.tape.isPowered(), this.time);
      return;
    }
    if (key === 'release') {
      this.tape.release(this.time);
    }
  }

  readObservable(key: string): number {
    switch (key) {
      case 'tapeDotCount':
        return this.tape.count();
      case 'tapeLostHead':
        return this.tape.lostHeadDots();
      case 'tapeSegments':
        return this.tape.segmentCount(this.startDot(), this.everyGap());
      case 'tapeShortestMm':
        return this.tape.shortestSegment(this.startDot(), this.everyGap()) * 1000;
      case 'tapeSpanMm':
        return this.tape.tapeLength() * 1000;
      case 'tapeEveryMs':
        return this.everyGap() / this.tape.hz * 1000;
      default:
        return super.readObservable(key);
    }
  }

  protected onCollectFacts(sheet: FactSheet): void {
    const start = this.startDot();
    const every = this.everyGap();
    sheet.set('tapeDotCount', this.tape.count());
    sheet.set('tapeLostHead', this.tape.lostHeadDots());
    sheet.set('tapeSegments', this.tape.segmentCount(start, every));
    const shortest = this.tape.shortestSegment(start, every);
    if (Number.isFinite(shortest)) {
      sheet.set('tapeShortestMm', shortest * 1000);
    }
    sheet.mark('taped', this.tape.count() > 0 ? this.time : -1);
  }

  snapshot(): WorldSnapshot {
    const snap = super.snapshot();
    TapeStrip.paint(snap, this.tape, TAPE_X, TAPE_Y, this.startDot(), this.everyGap(),
      '纸带 · 点距按 ' + String(TAPE_SCALE) + ' 倍展开');
    return snap;
  }

  /** 计数起点:从第几个点开始量。前面那段密得读不出来的,本来就该舍掉 */
  private startDot(): number {
    const raw = this.readParam('countStart');
    return raw < 0 ? 0 : Math.floor(raw);
  }

  /** 每几个点取一个计数点。参数是滑杆给的浮点,这里一律收成不小于 1 的整数 */
  private everyGap(): number {
    const raw = this.readParam('countEvery');
    return raw < 1 ? 1 : Math.floor(raw);
  }

  private readParam(key: string): number {
    const value = this.getParam(key);
    return Number.isFinite(value) ? value : 0;
  }
}
