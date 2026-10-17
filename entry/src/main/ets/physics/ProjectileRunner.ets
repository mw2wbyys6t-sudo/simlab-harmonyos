import { ExperimentMeta } from '../model/ExperimentTypes';
import { FactSheet } from '../model/FactSheet';
import { Physics2DRunner } from './Physics2DRunner';
import {
  BoxShape, CircleShape, LabelShape, SegmentShape, WorldSnapshot
} from './World2D';

const G = 9.8;

/**
 * 斜槽与卡片都是**离散档位**,这是刻意的:
 * 这条实验要判的两件事 —— "每次是不是从同一位置静止释放"、"取点是不是水平等间隔" ——
 * 只有做成档位才留得下事实。拖滑杆得到的连续值,既不像器材也没有"第几次"这个可数对象。
 */
const SLOT_MIN = 1;
const SLOT_MAX = 4;
/** 斜槽每高一格,球到槽口时多落下这么多高度:v0 = sqrt(2gh) */
const SLOT_STEP = 0.05;
const CARD_MIN = 1;
const CARD_MAX = 8;
/** 卡片每往外挪一格,离槽口的水平距离加这么多米 */
const CARD_STEP = 0.15;

/** 槽口(球离开斜槽的那一点) */
const EXIT_X = 1.15;
const EXIT_Y = 2.75;
/** 没标定原点时,坐标只能按木板左下角量 —— 这个偏移就是"没定原点"的代价 */
const CORNER_X = 0.35;
const CORNER_Y = 0.5;
const FLOOR_Y = 0.4;
const BOARD_X1 = 4.35;
const BOARD_Y1 = 4.0;

const C_BOARD = '#E8E2D4';
const C_FRAME = '#8A7A5C';
const C_RAMP = '#5A6B7F';
const C_BALL = '#2F6FB5';
const C_CARD = '#E2574C';
const C_DOT = '#25313F';
const C_PLUMB = '#2E9E7A';
const C_TEXT = '#1F2A3A';

/** 描下来的一个点:坐标按**描它那一刻的原点设定**算,外加两条来路 —— 用了第几格释放、卡片摆在哪 */
class TracedPoint {
  x: number = 0;
  y: number = 0;
  slot: number = 0;
  card: number = 0;
  beforeOrigin: boolean = false;
}

/**
 * 探究平抛运动的特点(高中必修二,地图条目 `phy-sr-007`)。
 *
 * 器材是斜槽、竖直木板上的白纸、复写纸与一张带孔卡片。真实操作里学生**不追时间**:
 * 把卡片挪到某个水平位置、从斜槽同一高度静止释放、球穿过孔时在纸上留下一个点,
 * 换位置再来一次。所以这里让"卡片摆在哪一格"与"从第几格释放"成为可数的动作,
 * 判分读的是它们留下的后果:
 * ① 描了几个点;② 定原点之前描下了几个;③ 这些点用的释放位置是不是同一个;
 * ④ 相邻水平间隔差得有多悬殊(等间隔才量得出竖直方向 1:3:5)。
 *
 * 场景**不画轨迹、不给自动图线**:抛物线的形状正是这条实验要学生自己检验出来的东西
 * (按 y 与 x² 成正比检验,而不是"看着像")。y/x² 的离散度只当读数摆在面板上。
 */
export class ProjectileRunner extends Physics2DRunner {
  private points: TracedPoint[] = [];
  private slot: number = 2;
  private card: number = 3;
  private originSet: boolean = false;
  /** 球在飞的时候取值 0..1 的进度;负值表示不在空中 */
  private flight: number = -1;
  private flightT: number = 0;
  private flightDur: number = 0;
  /** 「球落在卡片之前」这条说明挂到下一次释放为止 —— 它不是倒计时,落地后就停在那儿 */
  private missed: boolean = false;
  private snap: WorldSnapshot = new WorldSnapshot();

  setup(meta: ExperimentMeta): void {
    this.points = [];
    super.setup(meta);
  }

  protected onSetup(): void {
    this.slot = 2;
    this.card = 3;
    this.originSet = false;
    this.flight = -1;
    this.missed = false;
    this.points = [];
  }

  protected onAction(key: string): void {
    if (key === 'slot+') {
      this.slot = this.slot < SLOT_MAX ? this.slot + 1 : SLOT_MAX;
      return;
    }
    if (key === 'slot-') {
      this.slot = this.slot > SLOT_MIN ? this.slot - 1 : SLOT_MIN;
      return;
    }
    if (key === 'card+') {
      this.card = this.card < CARD_MAX ? this.card + 1 : CARD_MAX;
      return;
    }
    if (key === 'card-') {
      this.card = this.card > CARD_MIN ? this.card - 1 : CARD_MIN;
      return;
    }
    if (key === 'origin') {
      this.originSet = true;
      return;
    }
    if (key === 'release') {
      this.launch();
    }
  }

  /** 静止释放:球沿斜槽滑下(这段不计),到槽口水平飞出;飞过卡片所在那条竖线时留下一个点 */
  private launch(): void {
    this.missed = false;
    this.flight = 0;
    this.flightT = 0;
    this.flightDur = this.fallTime();
  }

  step(dt: number): void {
    if (this.flight < 0) {
      return;
    }
    this.time += dt;
    this.flightT += dt;
    if (this.flightT >= this.flightDur) {
      // 球先落地:卡片摆得比落点还远,这一次什么都没描下来
      this.flight = -1;
      this.missed = this.cardDistance() > this.range();
      return;
    }
    if (this.flight !== 0) {
      return;
    }
    if (this.v0() * this.flightT >= this.cardDistance()) {
      this.mark();
      this.flight = 1;
    }
  }

  /** 把此刻球的位置按当前原点设定记到纸上 */
  private mark(): void {
    const d = this.cardDistance();
    const drop = 0.5 * G * (d / this.v0()) * (d / this.v0());
    const point = new TracedPoint();
    point.slot = this.slot;
    point.card = this.card;
    point.beforeOrigin = !this.originSet;
    if (this.originSet) {
      point.x = d;
      point.y = drop;
    } else {
      point.x = EXIT_X + d - CORNER_X;
      point.y = EXIT_Y - drop - CORNER_Y;
    }
    this.points.push(point);
  }

  readObservable(key: string): number {
    switch (key) {
      case 'pjPointCount':
        return this.points.length;
      case 'pjEarlyMarks':
        return this.earlyMarks();
      case 'pjSlotSpread':
        return this.slotSpread();
      case 'pjXGapRatio':
        return this.gapRatio();
      case 'pjRatioErr':
        return this.ratioScatter();
      case 'pjSlot':
        return this.slot;
      case 'pjLaunchSpeed':
        return this.v0();
      case 'pjRange':
        return this.range();
      case 'pjCardDistance':
        return this.cardDistance();
      default:
        return Number.NaN;
    }
  }

  protected onCollectFacts(sheet: FactSheet): void {
    sheet.set('pjPointCount', this.points.length);
    sheet.set('pjEarlyMarks', this.earlyMarks());
    sheet.set('pjSlotSpread', this.slotSpread());
    const gaps = this.gapRatio();
    const scatter = this.ratioScatter();
    if (Number.isFinite(gaps)) {
      sheet.set('pjXGapRatio', gaps);
    }
    if (Number.isFinite(scatter)) {
      sheet.set('pjRatioErr', scatter);
    }
    sheet.mark('traced', this.points.length > 0 ? 0 : -1);
  }

  snapshot(): WorldSnapshot {
    this.snap.clear();

    // 木板与白纸
    const paper = new BoxShape();
    paper.cx = (CORNER_X + BOARD_X1) / 2;
    paper.cy = (CORNER_Y + BOARD_Y1) / 2;
    paper.w = BOARD_X1 - CORNER_X;
    paper.h = BOARD_Y1 - CORNER_Y;
    paper.color = C_BOARD;
    this.snap.boxes.push(paper);
    this.snap.frontSegments.push(this.line(CORNER_X, CORNER_Y, BOARD_X1, CORNER_Y, C_FRAME, 5));
    this.snap.frontSegments.push(this.line(CORNER_X, BOARD_Y1, BOARD_X1, BOARD_Y1, C_FRAME, 5));
    this.snap.frontSegments.push(this.line(CORNER_X, CORNER_Y, CORNER_X, BOARD_Y1, C_FRAME, 5));
    this.snap.frontSegments.push(this.line(BOARD_X1, CORNER_Y, BOARD_X1, BOARD_Y1, C_FRAME, 5));
    this.snap.segments.push(this.line(0.15, FLOOR_Y, 4.6, FLOOR_Y, C_FRAME, 4));

    // 斜槽:三段折线,末端水平 —— 槽口水平是这条实验的前提
    this.snap.frontSegments.push(this.line(0.45, 3.62, 0.72, 3.15, C_RAMP, 6));
    this.snap.frontSegments.push(this.line(0.72, 3.15, 0.95, 2.86, C_RAMP, 6));
    this.snap.frontSegments.push(this.line(0.95, 2.86, EXIT_X + 0.06, 2.81, C_RAMP, 6));
    this.snap.frontSegments.push(this.line(0.45, 3.5, 0.45, 2.86, C_RAMP, 3));

    // 释放位置:第 slot 格画一只待放的球,槽口那格画得实一些
    const restY = 3.5 - this.slot * 0.18;
    const rest = new CircleShape();
    rest.cx = 0.62;
    rest.cy = restY;
    rest.r = 0.09;
    rest.color = C_BALL;
    this.snap.circles.push(rest);

    // 飞行中的球
    if (this.flight !== -1) {
      const t = this.flightT < this.flightDur ? this.flightT : this.flightDur;
      const ball = new CircleShape();
      ball.cx = EXIT_X + this.v0() * t;
      ball.cy = EXIT_Y - 0.5 * G * t * t;
      ball.r = 0.09;
      ball.color = C_BALL;
      this.snap.circles.push(ball);
    }

    // 重垂线:标定过原点才挂得出来(它就是用来定那条竖直线的)
    if (this.originSet) {
      const plumb = new SegmentShape();
      plumb.x1 = EXIT_X;
      plumb.y1 = EXIT_Y + 0.25;
      plumb.x2 = EXIT_X;
      plumb.y2 = CORNER_Y + 0.05;
      plumb.color = C_PLUMB;
      plumb.widthMm = 2;
      plumb.dashed = true;
      this.snap.frontSegments.push(plumb);
      const knot = new CircleShape();
      knot.cx = EXIT_X;
      knot.cy = EXIT_Y;
      knot.r = 0.05;
      knot.color = C_PLUMB;
      this.snap.circles.push(knot);
    }

    // 卡片:摆在第 card 格那条竖线上,孔心跟着轨迹走
    // 球飞不到那一格时卡片贴地放着 —— 它比落点还远,本来就该接不到球
    const cardX = EXIT_X + this.cardDistance();
    this.snap.frontSegments.push(this.line(cardX, EXIT_Y + 0.3, cardX, CORNER_Y + 0.05, C_CARD, 2));
    const holeY = EXIT_Y - 0.5 * G * Math.pow(this.cardDistance() / this.v0(), 2);
    const slotCard = new BoxShape();
    slotCard.cx = cardX;
    slotCard.cy = holeY < FLOOR_Y + 0.11 ? FLOOR_Y + 0.11 : holeY;
    slotCard.w = 0.26;
    slotCard.h = 0.18;
    slotCard.color = C_CARD;
    this.snap.boxes.push(slotCard);

    // 描下来的点
    for (let i = 0; i < this.points.length; i++) {
      const p = this.points[i];
      const dot = new CircleShape();
      dot.cx = this.originSet ? EXIT_X + p.x : p.x + CORNER_X;
      dot.cy = this.originSet ? EXIT_Y - p.y : p.y + CORNER_Y;
      dot.r = 0.05;
      dot.color = C_DOT;
      this.snap.circles.push(dot);
      this.snap.labels.push(this.text('y=' + (p.y * 1000).toFixed(1),
        dot.cx + 0.09, dot.cy - 0.11, 'left', 10));
    }

    this.snap.labels.push(this.text('斜槽 ×' + this.slot, 0.3, 3.78, 'left', 11));
    this.snap.labels.push(this.text('卡片第 ' + this.card + ' 格', cardX - 0.28, CORNER_Y - 0.28, 'left', 11));
    if (!this.originSet) {
      this.snap.labels.push(this.text('未挂重垂线:坐标只能按板角量', 1.6, BOARD_Y1 - 0.35, 'left', 11));
    }
    if (this.missed) {
      this.snap.labels.push(this.text('球落在卡片之前,这次没描上点', 1.6, CORNER_Y + 0.55, 'left', 11));
    }
    return this.snap;
  }

  private text(content: string, x: number, y: number, align: string, sizeVp: number): LabelShape {
    const label = new LabelShape();
    label.text = content;
    label.x = x;
    label.y = y;
    label.align = align;
    label.sizeVp = sizeVp;
    label.color = C_TEXT;
    return label;
  }

  private line(x1: number, y1: number, x2: number, y2: number,
    color: string, widthMm: number): SegmentShape {
    const seg = new SegmentShape();
    seg.x1 = x1;
    seg.y1 = y1;
    seg.x2 = x2;
    seg.y2 = y2;
    seg.color = color;
    seg.widthMm = widthMm;
    return seg;
  }

  /** 槽口速度只由释放高度决定:这就是"必须从同一位置静止释放"的理由所在 */
  private v0(): number {
    return Math.sqrt(2 * G * this.slot * SLOT_STEP);
  }

  private cardDistance(): number {
    return this.card * CARD_STEP;
  }

  /** 从槽口到落地 */
  private fallTime(): number {
    return Math.sqrt(2 * (EXIT_Y - FLOOR_Y) / G);
  }

  /** 这一次能飞多远 */
  private range(): number {
    return this.v0() * this.fallTime();
  }

  private earlyMarks(): number {
    let n = 0;
    for (let i = 0; i < this.points.length; i++) {
      if (this.points[i].beforeOrigin) {
        n++;
      }
    }
    return n;
  }

  /** 描这些点用过的释放位置最大差几格:0 才是"每次都从同一位置静止释放" */
  private slotSpread(): number {
    if (this.points.length < 2) {
      return 0;
    }
    let low = this.points[0].slot;
    let high = low;
    for (let i = 1; i < this.points.length; i++) {
      if (this.points[i].slot < low) {
        low = this.points[i].slot;
      }
      if (this.points[i].slot > high) {
        high = this.points[i].slot;
      }
    }
    return high - low;
  }

  /** 相邻水平间隔的最大/最小:接近 1 才叫等间隔,量得出竖直方向 1:3:5 */
  private gapRatio(): number {
    if (this.mixedBaseline()) {
      return Number.NaN;
    }
    const xs = this.sortedX();
    if (xs.length < 3) {
      return Number.NaN;
    }
    let low = Number.POSITIVE_INFINITY;
    let high = 0;
    for (let i = 0; i + 1 < xs.length; i++) {
      const gap = xs[i + 1] - xs[i];
      if (gap < low) {
        low = gap;
      }
      if (gap > high) {
        high = gap;
      }
    }
    if (low <= 1e-9) {
      return Number.POSITIVE_INFINITY;
    }
    return high / low;
  }

  /**
   * y/x² 的相对离散(百分比):这条实验自己该做的检验。
   *
   * 只当读数摆在面板上,不做判分 —— 定过原点、释放位置一致时它是 0,
   * 也就是说这条数只能被 ②③ 两条带着走,拿它当判据就是留一条永远跟着别人响的判据。
   */
  private ratioScatter(): number {
    if (this.points.length < 2 || this.mixedBaseline()) {
      return Number.NaN;
    }
    let low = Number.POSITIVE_INFINITY;
    let high = 0;
    let any = false;
    for (let i = 0; i < this.points.length; i++) {
      const p = this.points[i];
      if (p.x <= 1e-6) {
        continue;
      }
      const ratio = p.y / (p.x * p.x);
      any = true;
      if (ratio < low) {
        low = ratio;
      }
      if (ratio > high) {
        high = ratio;
      }
    }
    if (!any || high <= 0) {
      return Number.NaN;
    }
    return (high - low) / high * 100;
  }

  private sortedX(): number[] {
    const xs: number[] = [];
    for (let i = 0; i < this.points.length; i++) {
      xs.push(this.points[i].x);
    }
    return xs.sort((a: number, b: number): number => a - b);
  }

  /**
   * 描的点是不是混了两套基准:挂重垂线之前按板角量、之后按抛出点量。
   * 混了就没有任何"水平间隔"或 y/x² 可言,这两条读数一律不给值,
   * 而不是拿一个把基准问题算成间隔问题的假数去扣分。
   */
  private mixedBaseline(): boolean {
    const early = this.earlyMarks();
    return early > 0 && early < this.points.length;
  }
}
