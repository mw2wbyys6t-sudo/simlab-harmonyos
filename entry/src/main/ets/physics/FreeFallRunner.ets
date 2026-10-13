import { FactSheet } from '../model/FactSheet';
import { Physics2DRunner } from './Physics2DRunner';
import { BoxShape, LabelShape, SegmentShape, WorldSnapshot } from './World2D';
import { TickerTape } from './TickerTape';
import { TAPE_SCALE, TapeStrip } from './TapeStrip';

const G = 9.8;
/** 铁架台:立柱、底座、伸出的吊臂与挂在臂下的计时器 */
const POST_X = 1.6;
const BASE_Y = 0.6;
const ARM_Y = 3.9;
const TIMER_X = 2.35;
/** 重锤起点的下沿:从这里开始往下掉 */
const HANG_Y = 3.42;
const TAPE_X = 3.5;
const TAPE_Y = 4.75;

const C_STAND = '#5A6B7F';
const C_TIMER = '#2F6FB5';
const C_WEIGHT = '#D9863D';
const C_STRIP = '#B9C2CC';
const C_TEXT = '#1F2A3A';

/**
 * 验证机械能守恒定律(高中必修二,地图条目 `phy-sr-008`)。
 *
 * 重锤带着纸带自由下落,打点计时器那条共用件记录过程(见 TickerTape / TapeStrip)。
 * 与斜面那条的区别只有两件事:运动是一维落体,以及**阻力不能为零** ——
 * 纸带穿过限位孔、重锤排开空气,真实实验里 ΔEk 恒小于 ΔEp,把它做成严格相等
 * 反而教出一个错的结论。阻力做成一个恒定的等效力,大小由参数给。
 *
 * 判分只读纸带怎么来的:点够不够、第一对点是不是从静止起(教材那条 2 mm 判据)、
 * 能切出几段比较。ΔEp 与 ΔEk 各是多少、偏差多大 —— 那些要学生把量到的数交进来
 * 才判得了(#61),这里只当读数给出来看。
 */
export class FreeFallRunner extends Physics2DRunner {
  private h: number = 0;
  private v: number = 0;
  private acc: number = 0;
  private ended: boolean = false;
  private tape: TickerTape = new TickerTape();
  private snap: WorldSnapshot = new WorldSnapshot();

  protected onSetup(): void {
    this.h = 0;
    this.v = 0;
    this.acc = 0;
    this.ended = false;
    this.tape.reset();
  }

  private dropLimit(): number {
    const l = this.getParam('height');
    return l <= 0.1 ? 0.1 : l;
  }

  /** 下落加速度:重力减去阻力产生的减速。阻力是恒定的等效力(纸带与限位孔为主) */
  private gravityNet(): number {
    const m = this.getParam('mass') <= 0.05 ? 0.05 : this.getParam('mass');
    const drag = Math.max(0, this.getParam('drag'));
    const net = G - drag / m;
    return net > 0 ? net : 0;
  }

  step(dt: number): void {
    if (!this.tape.isReleased()) {
      this.time += dt;
      this.tape.tick(this.time, this.h, 0, 0);
      return;
    }
    if (this.ended) {
      return;
    }
    this.acc = this.gravityNet();
    /*
     * 位置更新必须带上 ½at² 那一项。只用 h += v·dt(显式欧拉)会每步少算半格位移,
     * 落满 1 m 累积下来 v² 比 2ah 小 2.8% —— 而这条实验的结论正是"ΔEk 略小于 ΔEp 是阻力造成的"。
     * 让积分器自己吞掉 0.13 J,等于应用先撒一次谎,再把这笔账算到阻力头上。
     * 恒加速度下这个写法是精确的:h = ½at²、v = at,于是 v² = 2ah 严格成立。
     */
    this.h += this.v * dt + 0.5 * this.acc * dt * dt;
    this.v += this.acc * dt;
    this.time += dt;
    const limit = this.dropLimit();
    if (this.h >= limit) {
      // 落地:位置钉在限高上,速度取"经过那一刻"的精确值,不让 overshoot 造出多余动能
      this.h = limit;
      this.v = Math.sqrt(2 * this.acc * limit);
      this.ended = true;
    }
    this.tape.tick(this.time, this.h, this.v, this.ended ? 0 : this.acc);
  }

  finished(): boolean {
    return this.ended;
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
    const m = this.getParam('mass') <= 0.05 ? 0.05 : this.getParam('mass');
    const drag = Math.max(0, this.getParam('drag'));
    switch (key) {
      case 'dropHeight':
        return this.h;
      case 'velocity':
        return this.v;
      case 'acceleration':
        return this.acc;
      case 'potentialLost':
        return m * G * this.h;
      case 'kineticGained':
        return 0.5 * m * this.v * this.v;
      case 'dragWork':
        return drag * this.h;
      case 'energyGapPct':
        // ΔEp 与 ΔEk 的相对偏差:真实实验里它恒为正,大小约等于阻力做的那部分功
        return m * G * this.h <= 0 ? 0
          : (m * G * this.h - 0.5 * m * this.v * this.v) / (m * G * this.h) * 100;
      case 'tapeDotCount':
        return this.tape.count();
      case 'tapeLostHead':
        return this.tape.lostHeadDots();
      case 'tapeSegments':
        return this.tape.segmentCount(this.startDot(), this.everyGap());
      case 'tapeFirstGapMm':
        return this.tape.firstMovingGapMm();
      case 'tapeSpanMm':
        return this.tape.tapeLength() * 1000;
      default:
        return Number.NaN;
    }
  }

  protected onCollectFacts(sheet: FactSheet): void {
    sheet.set('tapeDotCount', this.tape.count());
    sheet.set('tapeSegments', this.tape.segmentCount(this.startDot(), this.everyGap()));
    const firstGap = this.tape.firstMovingGapMm();
    if (Number.isFinite(firstGap)) {
      sheet.set('tapeFirstGapMm', firstGap);
    }
    sheet.mark('dropped', this.ended ? this.time : -1);
  }

  snapshot(): WorldSnapshot {
    this.snap.clear();
    this.snap.segments.push(this.line(POST_X, BASE_Y, POST_X, ARM_Y, C_STAND, 4));
    this.snap.segments.push(this.line(POST_X - 0.75, BASE_Y, POST_X + 0.75, BASE_Y, C_STAND, 5));
    this.snap.segments.push(this.line(POST_X, ARM_Y, TIMER_X + 0.2, ARM_Y, C_STAND, 4));

    const timer = new BoxShape();
    timer.cx = TIMER_X;
    timer.cy = ARM_Y - 0.2;
    timer.w = 0.46;
    timer.h = 0.3;
    timer.angleDeg = 0;
    timer.color = C_TIMER;
    this.snap.boxes.push(timer);
    this.snap.segments.push(this.line(TIMER_X, ARM_Y - 0.35, TIMER_X, HANG_Y + 0.16, C_STRIP, 1.4));

    const weight = new BoxShape();
    weight.cx = TIMER_X;
    weight.cy = HANG_Y - this.h;
    weight.w = 0.3;
    weight.h = 0.32;
    weight.angleDeg = 0;
    weight.color = C_WEIGHT;
    this.snap.boxes.push(weight);

    const stamp = new LabelShape();
    stamp.x = TIMER_X + 0.3;
    stamp.y = HANG_Y - this.h + 0.34;
    stamp.text = 'h=' + this.h.toFixed(2) + ' m  v=' + this.v.toFixed(2) + ' m/s';
    stamp.sizeVp = 13;
    stamp.color = C_TEXT;
    this.snap.labels.push(stamp);
    if (this.ended) {
      const hit = new LabelShape();
      hit.x = TIMER_X;
      hit.y = HANG_Y - this.h - 0.36;
      hit.text = '已落地';
      hit.sizeVp = 13;
      hit.color = '#E2574C';
      hit.align = 'center';
      this.snap.labels.push(hit);
    }
    const timerTag = new LabelShape();
    timerTag.x = TIMER_X - 0.28;
    timerTag.y = ARM_Y + 0.12;
    timerTag.text = '打点计时器';
    timerTag.sizeVp = 11;
    timerTag.color = C_TEXT;
    this.snap.labels.push(timerTag);

    TapeStrip.paint(this.snap, this.tape, TAPE_X, TAPE_Y, this.startDot(), this.everyGap(),
      '纸带 · 点距按 ' + String(TAPE_SCALE) + ' 倍展开');
    return this.snap;
  }

  /** 计数起点:默认 0 —— 这条实验要的就是从第一个点开始比,不存在"舍掉开头" */
  private startDot(): number {
    const raw = this.getParam('countStart');
    return Number.isFinite(raw) && raw > 0 ? Math.floor(raw) : 0;
  }

  /** 每几个点取一个计数点。自由落体点距大,默认每 2 点取一个就够切十几段 */
  private everyGap(): number {
    const raw = this.getParam('countEvery');
    return Number.isFinite(raw) && raw >= 1 ? Math.floor(raw) : 2;
  }

  private line(x1: number, y1: number, x2: number, y2: number, color: string, widthMm: number): SegmentShape {
    const seg = new SegmentShape();
    seg.x1 = x1;
    seg.y1 = y1;
    seg.x2 = x2;
    seg.y2 = y2;
    seg.color = color;
    seg.widthMm = widthMm;
    return seg;
  }
}
