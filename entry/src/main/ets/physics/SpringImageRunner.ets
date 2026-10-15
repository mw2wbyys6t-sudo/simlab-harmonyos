import { ExperimentMeta } from '../model/ExperimentTypes';
import { FactSheet } from '../model/FactSheet';
import { Physics2DRunner } from './Physics2DRunner';
import {
  BoxShape, CircleShape, LabelShape, SegmentShape, SpringShape, WorldSnapshot
} from './World2D';

/** 弹簧常数被拖到 0 时周期无穷大,给个兜底值免得除零(读数面板会显示"周期 = —") */
const OMEGA_REF = 1;

const WALL_X = 0.5;
const NATURAL_LEN = 1.6;
const TABLE_Y = 2.7;
const BLOCK_W = 0.62;
const BLOCK_H = 0.44;
const EQUILIBRIUM_X = WALL_X + NATURAL_LEN;

/** 描图区:横轴是时间,纵轴是位移 */
const PLOT_X0 = 0.6;
const PLOT_X1 = 5.7;
const PLOT_CY = 1.15;
const PLOT_HALF = 0.72;
/** 横轴最短画多少秒:描得少的时候不把几秒的图摊成一整幅,免得看着像直线 */
const PLOT_MIN_SPAN_S = 24;
/** 横轴分几格:格数固定,每格的秒数跟着描图时长涨(见 tickSeconds) */
const PLOT_TICKS = 8;
/** 每格只能取这些秒数:刻度线要落在整秒上,学生才量得出周期 */
const TICK_STEPS = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600];
/** 纵轴 1 m 位移画多高 */
const PLOT_Y_SCALE = PLOT_HALF / 1.2;

const C_BODY = '#2F6FB5';
const C_WALL = '#33404F';
const C_SPRING = '#8E5BD9';
const C_GUIDE = '#9AA7B8';
const C_AXIS = '#5A6B7F';
const C_DOT = '#E2574C';
const C_LINE = '#2E9E7A';
const C_TEXT = '#1F2A3A';

/** 学生按下一次「记下这一个点」留下的一个取样 */
class SampleDot {
  t: number = 0;
  x: number = 0;

  constructor(t: number, x: number) {
    this.t = t;
    this.x = x;
  }
}

/**
 * 描绘简谐运动的图像(选择性必修一,地图条目 `phy-sr-015`)。
 *
 * 这条实验考的不是振子怎么动(那是求解器的事),而是**图是怎么描出来的**:
 * 学生一下一下按「记下这一个点」,把离散取样攒成一条 x-t 折线。
 * 按得够密,折线就是正弦;按到半个周期一下,折线立刻变成一副不像样子的锯齿 ——
 * 走样不是我们讲给他的结论,是他自己描出来、并且当场量得出差多少的东西。
 *
 * 失真度 `imgDistortCm` 拿折线与解析曲线 A·cos(ωt) 在整段覆盖区间上逐点比,
 * 取最大差。阻尼锁在 0,这条对照才成立(有阻尼时"真实曲线"另说)。
 */
export class SpringImageRunner extends Physics2DRunner {
  private x: number = 0;
  private v: number = 0;
  private acc: number = 0;
  private samples: SampleDot[] = [];
  /** 起跑那一刻的位移:失真度要对照的"真实曲线"以它当振幅,
    之后再拖初位移滑杆不该把这条参考曲线一起改掉 */
  private refAmp: number = 1;
  private snap: WorldSnapshot = new WorldSnapshot();

  setup(meta: ExperimentMeta): void {
    this.samples = [];
    super.setup(meta);
  }

  protected onSetup(): void {
    this.x = this.getParam('amplitude');
    this.refAmp = Math.abs(this.x) <= 0.02 ? 0.02 : Math.abs(this.x);
    this.v = 0;
    this.acc = 0;
    // 「重置」在这条场景里等于换一条纸带:描出来的点是这次测量的全部产物
    this.samples = [];
  }

  protected onAction(key: string): void {
    if (key === 'sample') {
      this.samples.push(new SampleDot(this.time, this.x));
    }
  }

  step(dt: number): void {
    const m = this.mass();
    const k = this.getParam('stiffness');
    // 半隐式欧拉:与弹簧振子那条同一套方案,无阻尼下能量与相位都稳
    this.acc = -k * this.x / m;
    this.v += this.acc * dt;
    this.x += this.v * dt;
    this.time += dt;
  }

  readObservable(key: string): number {
    switch (key) {
      case 'displacement':
        return this.x;
      case 'velocity':
        return this.v;
      case 'acceleration':
        return this.acc;
      case 'periodTheory':
        return this.period();
      case 'amplitude':
        return this.refAmp;
      case 'imgSamples':
        return this.samples.length;
      case 'imgSpanT':
        return this.spanPeriods();
      case 'imgMaxGapT':
        return this.maxGap();
      case 'imgSwingCm':
        return this.swingCm();
      case 'imgDistortCm':
        return this.distortion();
      default:
        return Number.NaN;
    }
  }

  protected onCollectFacts(sheet: FactSheet): void {
    sheet.set('imgSamples', this.samples.length);
    const span = this.spanPeriods();
    const gap = this.maxGap();
    const swing = this.swingCm();
    const distort = this.distortion();
    if (Number.isFinite(span)) {
      sheet.set('imgSpanT', span);
    }
    if (Number.isFinite(gap)) {
      sheet.set('imgMaxGapT', gap);
    }
    if (Number.isFinite(swing)) {
      sheet.set('imgSwingCm', swing);
    }
    if (Number.isFinite(distort)) {
      sheet.set('imgDistortCm', distort);
    }
    sheet.mark('recorded', this.samples.length > 0 ? this.samples[0].t : -1);
  }

  snapshot(): WorldSnapshot {
    this.snap.clear();
    const cx = EQUILIBRIUM_X + this.x;
    const cy = TABLE_Y + BLOCK_H / 2;

    const wall = new SegmentShape();
    wall.x1 = WALL_X;
    wall.y1 = TABLE_Y;
    wall.x2 = WALL_X;
    wall.y2 = TABLE_Y + 0.8;
    wall.color = C_WALL;
    wall.widthMm = 8;
    this.snap.segments.push(wall);

    const table = new SegmentShape();
    table.x1 = 0.2;
    table.y1 = TABLE_Y;
    table.x2 = 3.6;
    table.y2 = TABLE_Y;
    table.color = C_WALL;
    table.widthMm = 4;
    this.snap.segments.push(table);

    const guide = new SegmentShape();
    guide.x1 = EQUILIBRIUM_X;
    guide.y1 = TABLE_Y;
    guide.x2 = EQUILIBRIUM_X;
    guide.y2 = TABLE_Y + 0.85;
    guide.color = C_GUIDE;
    guide.widthMm = 2;
    guide.dashed = true;
    this.snap.segments.push(guide);

    const spring = new SpringShape();
    spring.x1 = WALL_X;
    spring.y1 = cy;
    spring.x2 = cx - BLOCK_W / 2;
    spring.y2 = cy;
    spring.coils = 8;
    spring.amplitude = 0.17;
    spring.color = C_SPRING;
    this.snap.springs.push(spring);

    const block = new BoxShape();
    block.cx = cx;
    block.cy = cy;
    block.w = BLOCK_W;
    block.h = BLOCK_H;
    block.color = C_BODY;
    this.snap.boxes.push(block);

    const blockText = new LabelShape();
    blockText.x = cx;
    blockText.y = cy;
    blockText.text = this.mass().toFixed(0) + ' kg';
    blockText.sizeVp = 11;
    blockText.align = 'center';
    blockText.color = '#FFFFFF';
    this.snap.labels.push(blockText);

    const eqTag = new LabelShape();
    eqTag.x = EQUILIBRIUM_X - 0.3;
    eqTag.y = TABLE_Y - 0.3;
    eqTag.text = '平衡位置';
    eqTag.sizeVp = 11;
    eqTag.color = C_GUIDE;
    this.snap.labels.push(eqTag);

    this.paintPlot();
    return this.snap;
  }

  /** 学生描出来的那幅图:坐标轴 + 他按下的点 + 把这些点连起来的折线 */
  private paintPlot(): void {
    const axis = new SegmentShape();
    axis.x1 = PLOT_X0;
    axis.y1 = PLOT_CY;
    axis.x2 = PLOT_X1;
    axis.y2 = PLOT_CY;
    axis.color = C_AXIS;
    axis.widthMm = 2;
    this.snap.segments.push(axis);

    // 刻度线:没有它们,"横轴一格几秒"就只是句口号,周期也就没法从图上量
    for (let i = 1; i <= PLOT_TICKS; i++) {
      const tickX = PLOT_X0 + (PLOT_X1 - PLOT_X0) * i / PLOT_TICKS;
      const tick = new SegmentShape();
      tick.x1 = tickX;
      tick.y1 = PLOT_CY - 0.07;
      tick.x2 = tickX;
      tick.y2 = PLOT_CY + 0.07;
      tick.color = C_AXIS;
      tick.widthMm = 2;
      this.snap.segments.push(tick);
    }

    const left = new SegmentShape();
    left.x1 = PLOT_X0;
    left.y1 = PLOT_CY - PLOT_HALF - 0.1;
    left.x2 = PLOT_X0;
    left.y2 = PLOT_CY + PLOT_HALF + 0.1;
    left.color = C_AXIS;
    left.widthMm = 2;
    this.snap.segments.push(left);

    for (let i = 0; i + 1 < this.samples.length; i++) {
      const a = this.px(this.samples[i]);
      const b = this.px(this.samples[i + 1]);
      const link = new SegmentShape();
      link.x1 = a.x;
      link.y1 = a.y;
      link.x2 = b.x;
      link.y2 = b.y;
      link.color = C_LINE;
      link.widthMm = 2;
      this.snap.segments.push(link);
    }
    for (let i = 0; i < this.samples.length; i++) {
      const p = this.px(this.samples[i]);
      const dot = new CircleShape();
      dot.cx = p.x;
      dot.cy = p.y;
      dot.r = 0.055;
      dot.color = C_DOT;
      this.snap.circles.push(dot);
    }

    const title = new LabelShape();
    title.x = PLOT_X0;
    title.y = PLOT_CY + PLOT_HALF + 0.28;
    title.text = '你描下的 x-t 图 · 横轴一格 ' + this.tickSeconds().toFixed(0) + ' s';
    title.sizeVp = 11;
    title.color = C_TEXT;
    this.snap.labels.push(title);

    const zero = new LabelShape();
    zero.x = PLOT_X0 - 0.16;
    zero.y = PLOT_CY - 0.24;
    zero.text = '0';
    zero.sizeVp = 11;
    zero.color = C_AXIS;
    this.snap.labels.push(zero);

    const now = new LabelShape();
    now.x = 4.0;
    now.y = 0.35;
    now.text = '此刻 x=' + this.x.toFixed(2) + ' m  t=' + this.time.toFixed(1) + ' s';
    now.sizeVp = 11;
    now.color = C_TEXT;
    this.snap.labels.push(now);
  }

  /**
   * 横轴一格多少秒:格数固定 8 格,每格从整秒里挑一个刚好铺得下的档。
   *
   * 定死不涨是错的:设备上按 80 下要一分半,横轴若停在 24 s,后半幅的点会被压成
   * 右边界上一条竖线(截图里看得见)。但"跟着涨"也不能涨成 3.5 s 一格 ——
   * 这条场景的任务就是让学生从图上读周期,刻度必须落在整秒上。
   */
  private tickSeconds(): number {
    const last = this.samples.length > 0 ? this.samples[this.samples.length - 1].t : 0;
    const need = (last + 1 > PLOT_MIN_SPAN_S ? last + 1 : PLOT_MIN_SPAN_S) / PLOT_TICKS;
    for (let i = 0; i < TICK_STEPS.length; i++) {
      if (TICK_STEPS[i] >= need) {
        return TICK_STEPS[i];
      }
    }
    return TICK_STEPS[TICK_STEPS.length - 1];
  }

  /** 横轴总时长:八格整 */
  private spanSeconds(): number {
    return this.tickSeconds() * PLOT_TICKS;
  }

  /** 一个取样落在图上的位置 */
  private px(dot: SampleDot): PlotPoint {
    const p = new PlotPoint();
    const frac = dot.t / this.spanSeconds();
    p.x = PLOT_X0 + frac * (PLOT_X1 - PLOT_X0);
    p.y = PLOT_CY + dot.x * PLOT_Y_SCALE;
    return p;
  }

  private mass(): number {
    const m = this.getParam('mass');
    return m <= 0.05 ? 0.05 : m;
  }

  private omega(): number {
    const k = this.getParam('stiffness');
    return k <= 0 ? OMEGA_REF : Math.sqrt(k / this.mass());
  }

  private period(): number {
    const w = this.omega();
    return w <= 0 ? Number.NaN : 2 * Math.PI / w;
  }

  /** 这些点覆盖了几个周期 */
  private spanPeriods(): number {
    if (this.samples.length < 2) {
      return Number.NaN;
    }
    const t0 = this.samples[0].t;
    const t1 = this.samples[this.samples.length - 1].t;
    const p = this.period();
    return p > 0 ? (t1 - t0) / p : Number.NaN;
  }

  /** 相邻两个取样之间最大隔了几个周期:走样就是这么来的 */
  private maxGap(): number {
    if (this.samples.length < 2) {
      return Number.NaN;
    }
    let worst = 0;
    const p = this.period();
    for (let i = 0; i + 1 < this.samples.length; i++) {
      const gap = this.samples[i + 1].t - this.samples[i].t;
      if (gap > worst) {
        worst = gap;
      }
    }
    return p > 0 ? worst / p : Number.NaN;
  }

  /** 描出来的点覆盖到多大的位移范围(厘米):只采到半截曲线时这个数明显小 */
  private swingCm(): number {
    if (this.samples.length < 2) {
      return Number.NaN;
    }
    let low = this.samples[0].x;
    let high = low;
    for (let i = 1; i < this.samples.length; i++) {
      const x = this.samples[i].x;
      if (x < low) {
        low = x;
      }
      if (x > high) {
        high = x;
      }
    }
    return (high - low) * 100;
  }

  /**
   * 折线与真实曲线的最大差(厘米)。
   *
   * 每段里等分 9 个点比:恒振幅无阻尼下,折线对真曲线的误差在段内单峰,
   * 段中点附近就是最大处 —— 逐段扫比全区间细扫更省,也不会漏掉"只按了两下"这种段很长的情况。
   */
  private distortion(): number {
    const n = this.samples.length;
    if (n < 2) {
      return Number.NaN;
    }
    const w = this.omega();
    const a = this.refAmp;
    let worst = 0;
    for (let i = 0; i + 1 < n; i++) {
      const t0 = this.samples[i].t;
      const t1 = this.samples[i + 1].t;
      const x0 = this.samples[i].x;
      const x1 = this.samples[i + 1].x;
      for (let k = 0; k <= 8; k++) {
        const t = t0 + (t1 - t0) * k / 8;
        const line = x0 + (x1 - x0) * (t1 - t0 <= 0 ? 0 : (t - t0) / (t1 - t0));
        const err = Math.abs(line - a * Math.cos(w * t));
        if (err > worst) {
          worst = err;
        }
      }
    }
    return worst * 100;
  }

}

/** 图上的一个位置 */
class PlotPoint {
  x: number = 0;
  y: number = 0;
}
