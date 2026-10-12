import { FactSheet } from '../model/FactSheet';
import { InclineRunner } from './InclineRunner';
import { CircleShape, LabelShape, SegmentShape, WorldSnapshot } from './World2D';
import { TickerTape } from './TickerTape';

/** 纸带画在世界顶部这一条上,斜面最高也就 1.2 m 长、30° 时顶点在 1.2 m,互不遮挡 */
const TAPE_Y = 4.9;
const TAPE_X = 0.8;
/** 点距按 6 倍展开画:1:1 时毫米级的间距在屏幕上不到一个像素,而真实数据不动 */
const TAPE_SCALE = 6;
const DOT_R = 0.022;

const C_STRIP = '#B9C2CC';
const C_DOT = '#25313F';
const C_MARK = '#2F6FB5';
const C_TEXT = '#1F2A3A';

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
    const count = this.tape.count();
    const first = this.tape.dotAt(0);
    if (first === null) {
      return snap;
    }
    // 纸带底条:按实际打出来的长度画,后面留白就是还没走的部分
    const span = Math.max(0.6, this.tape.tapeLength() * TAPE_SCALE + 0.4);
    snap.segments.push(this.strip(TAPE_X - 0.15, TAPE_Y - 0.24, TAPE_X + span, TAPE_Y - 0.24));
    snap.segments.push(this.strip(TAPE_X - 0.15, TAPE_Y + 0.24, TAPE_X + span, TAPE_Y + 0.24));

    const start = this.startDot();
    const every = this.everyGap();
    for (let i = 0; i < count; i++) {
      const dot = this.tape.dotAt(i);
      if (dot === null) {
        continue;
      }
      const x = TAPE_X + (dot.s - first.s) * TAPE_SCALE;
      const isMark = i >= start && (i - start) % every === 0;
      const shape = new CircleShape();
      shape.cx = x;
      shape.cy = TAPE_Y;
      shape.r = isMark ? DOT_R * 1.5 : DOT_R;
      shape.color = isMark ? C_MARK : C_DOT;
      snap.circles.push(shape);
    }
    // 计数点用放大蓝点标出来,不给它们编号:前几个点彼此只隔几毫米,编号会挤成一团
    // 反而盖住要看的东西(实测 T0…T5 糊成一条)。段数与最短段都在读数区里给数字。
    const note = new LabelShape();
    note.x = TAPE_X - 0.15;
    note.y = TAPE_Y + 0.46;
    note.text = '纸带 · 点距按 ' + String(TAPE_SCALE) + ' 倍展开';
    note.sizeVp = 11;
    note.color = C_TEXT;
    snap.labels.push(note);
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

  private strip(x1: number, y1: number, x2: number, y2: number): SegmentShape {
    const seg = new SegmentShape();
    seg.x1 = x1;
    seg.y1 = y1;
    seg.x2 = x2;
    seg.y2 = y2;
    seg.color = C_STRIP;
    seg.widthMm = 1.2;
    return seg;
  }

  private readParam(key: string): number {
    const value = this.getParam(key);
    return Number.isFinite(value) ? value : 0;
  }
}
