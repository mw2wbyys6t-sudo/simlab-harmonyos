import { ExperimentMeta } from '../model/ExperimentTypes';
import { FactSheet } from '../bench/Rubric';
import { Physics2DRunner } from './Physics2DRunner';
import { BoxShape, LabelShape, SegmentShape, SpringShape, WorldSnapshot } from './World2D';

const G: number = 9.8;
/** 阻尼比,不是阻尼系数:换砝码时质量变了,写死系数会让轻重砝码的停稳时间差好几倍 */
const DAMPING_RATIO: number = 0.15;
const MAX_WEIGHTS: number = 12;

const C_RULER = '#33404F';
const C_SPRING = '#8E5BD9';
const C_PAN = '#2F6FB5';
const C_WEIGHT = '#5A6B7D';
const C_TEXT = '#1F2A3A';
const C_LIMIT = '#E2574C';

/**
 * 探究弹簧弹力与形变量的关系(竖直弹簧 + 逐次增挂钩码)。
 *
 * 两个刻意的设计:
 *
 * 1. **形变量分两段算**。弹性伸长 e 由 `m·e'' = m·g − k·e − c·e'` 解出,
 *    而塑性变形 residual 只作为长度偏移叠加。若把 residual 也写进受力平衡,
 *    弹簧一坏就会正反馈地无限拉长 —— 那是模型的错,不是物理的错。
 * 2. **超过弹性限度不留提示、只留后果**。学生看不到「你超了」的弹窗,
 *    但撤去砝码后指针回不到零,而判定层读的就是这个回不去的数。
 *
 * 记录读数是一次**离散动作**,记录瞬间的速度一并落进事实 —— 在还在振的弹簧上按记录,
 * 和停下来再按,是两个不同的事实值,这是这条实验里唯一能被判的「操作规范」。
 */
export class SpringForceRunner extends Physics2DRunner {
  /** 弹性伸长(从原长度量,不含塑性变形),m */
  private e: number = 0;
  private v: number = 0;
  private weights: number = 0;
  private residual: number = 0;
  /** 加载过程中到过的最大弹性伸长,塑性变形就由它超出弹性限度的部分定出 */
  private maxElastic: number = 0;
  private unloadSteps: number = 0;
  private records: number[] = [];
  private recordLoads: number[] = [];
  private maxRecordSpeed: number = 0;
  private snap: WorldSnapshot = new WorldSnapshot();

  protected onSetup(): void {
    this.e = this.mass() * G / this.k();
    this.v = 0;
    this.weights = 0;
    this.residual = 0;
    this.maxElastic = this.e;
    this.unloadSteps = 0;
    this.records = [];
    this.recordLoads = [];
    this.maxRecordSpeed = 0;
  }

  private k(): number {
    const k = this.getParam('stiffness');
    return k <= 0.01 ? 0.01 : k;
  }

  private mass(): number {
    const pan = this.getParam('panMass');
    const each = this.getParam('weightMass');
    return pan + this.weights * each;
  }

  step(dt: number): void {
    const m = this.mass();
    const k = this.k();
    const c = 2 * DAMPING_RATIO * Math.sqrt(k * m);
    // 半隐式欧拉:与弹簧振子同一套积分方案,保证两条实验的数值行为可比
    const acc = (m * G - k * this.e - c * this.v) / m;
    this.v += acc * dt;
    this.e += this.v * dt;
    if (this.e < 0) {
      // 弹簧只能被拉不能被压(竖直悬挂、绳状弹簧的简化),压缩段按零处理
      this.e = 0;
      this.v = 0;
    }
    if (this.e > this.maxElastic) {
      this.maxElastic = this.e;
    }
    const limit = this.getParam('limitExtension');
    if (this.maxElastic > limit) {
      this.residual = this.maxElastic - limit;
    }
    this.time += dt;
  }

  protected onAction(key: string): void {
    if (key === 'weight+') {
      if (this.weights < MAX_WEIGHTS) {
        this.weights++;
      }
      return;
    }
    if (key === 'weight-') {
      if (this.weights > 0) {
        this.weights--;
        this.unloadSteps++;
      }
      return;
    }
    if (key === 'record') {
      this.records.push(this.readObservable('extension'));
      this.recordLoads.push(this.weights);
      const speed = Math.abs(this.v);
      if (speed > this.maxRecordSpeed) {
        this.maxRecordSpeed = speed;
      }
    }
  }

  readObservable(key: string): number {
    switch (key) {
      case 'weights':
        return this.weights;
      case 'load':
        return this.weights * this.getParam('weightMass') * G;
      case 'force':
        return this.k() * this.e;
      case 'extension':
        return this.e + this.residual;
      case 'length':
        return this.getParam('naturalLength') + this.e + this.residual;
      case 'residual':
        return this.residual;
      case 'maxExtension':
        return this.maxElastic;
      case 'beyondLimit':
        return this.maxElastic > this.getParam('limitExtension') ? 1 : 0;
      case 'limitExtension':
        return this.getParam('limitExtension');
      case 'speed':
        return this.v;
      case 'recordCount':
        return this.records.length;
      default:
        return Number.NaN;
    }
  }

  /** 只报载荷种类数:同一挡挂着重按两次记录,不算两个独立数据点 */
  private distinctLoads(): number {
    const seen: number[] = [];
    for (let i = 0; i < this.recordLoads.length; i++) {
      if (seen.indexOf(this.recordLoads[i]) < 0) {
        seen.push(this.recordLoads[i]);
      }
    }
    return seen.length;
  }

  protected onCollectFacts(sheet: FactSheet): void {
    sheet.set('recordCount', this.records.length);
    sheet.set('distinctLoads', this.distinctLoads());
    sheet.set('maxRecordSpeed', this.maxRecordSpeed);
    sheet.set('maxExtension', this.maxElastic);
    sheet.set('beyondLimit', this.maxElastic > this.getParam('limitExtension') ? 1 : 0);
    sheet.set('unloadSteps', this.unloadSteps);
    sheet.set('residual', this.residual);
    sheet.mark('recorded', this.records.length > 0 ? this.time : -1);
  }

  snapshot(): WorldSnapshot {
    this.snap.clear();
    // 世界只有 1.1 × 0.9 m:装置本身就在米级(弹簧 20 cm、砝码 3 cm),
    // 若照别的场景开一个 3 m 高的世界,整台仪器会被 fit() 缩到画布顶上一小条里。
    const x = 0.42;
    const ceilingY = 0.84;
    const natural = this.getParam('naturalLength');
    const ext = this.e + this.residual;
    const panY = ceilingY - natural - ext;
    const rulerX = 0.78;
    const zeroY = ceilingY - natural;

    const ceiling = new SegmentShape();
    ceiling.x1 = x - 0.18;
    ceiling.y1 = ceilingY;
    ceiling.x2 = x + 0.18;
    ceiling.y2 = ceilingY;
    ceiling.color = C_RULER;
    ceiling.widthMm = 8;
    this.snap.segments.push(ceiling);

    const spring = new SpringShape();
    spring.x1 = x;
    spring.y1 = ceilingY;
    spring.x2 = x;
    spring.y2 = panY + 0.02;
    spring.coils = 10;
    spring.amplitude = 0.06;
    spring.color = C_SPRING;
    this.snap.springs.push(spring);

    const pan = new BoxShape();
    pan.cx = x;
    pan.cy = panY;
    pan.w = 0.16;
    pan.h = 0.02;
    pan.color = C_PAN;
    this.snap.boxes.push(pan);

    // 砝码逐个叠在盘下:数量是学生的选择,画出来才判得出「他确实加过」
    for (let i = 0; i < this.weights; i++) {
      const w = new BoxShape();
      w.cx = x;
      w.cy = panY - 0.03 - i * 0.033;
      w.w = 0.12;
      w.h = 0.026;
      w.color = C_WEIGHT;
      this.snap.boxes.push(w);
    }

    // 标尺:零刻度对齐原长末端 —— 学生该读形变量,不是弹簧总长
    const ruler = new SegmentShape();
    ruler.x1 = rulerX;
    ruler.y1 = zeroY + 0.03;
    ruler.x2 = rulerX;
    ruler.y2 = 0.02;
    ruler.color = C_RULER;
    ruler.widthMm = 3;
    this.snap.segments.push(ruler);
    for (let cm = 0; cm <= 40; cm++) {
      const tick = new SegmentShape();
      const ty = zeroY - cm * 0.01;
      if (ty < 0.02) {
        break;
      }
      tick.x1 = rulerX;
      tick.y1 = ty;
      tick.x2 = rulerX + (cm % 5 === 0 ? 0.045 : 0.022);
      tick.y2 = ty;
      tick.color = C_RULER;
      tick.widthMm = cm % 5 === 0 ? 2 : 1;
      this.snap.segments.push(tick);
    }

    const limit = this.getParam('limitExtension');
    const limitLine = new SegmentShape();
    limitLine.x1 = x - 0.3;
    limitLine.y1 = zeroY - limit;
    limitLine.x2 = rulerX;
    limitLine.y2 = zeroY - limit;
    limitLine.color = C_LIMIT;
    limitLine.widthMm = 2;
    limitLine.dashed = true;
    this.snap.segments.push(limitLine);

    const pointer = new SegmentShape();
    pointer.x1 = rulerX - 0.04;
    pointer.y1 = zeroY - ext;
    pointer.x2 = rulerX + 0.02;
    pointer.y2 = zeroY - ext;
    pointer.color = C_TEXT;
    pointer.widthMm = 3;
    this.snap.segments.push(pointer);

    const extLabel = new LabelShape();
    extLabel.x = 0.03;
    extLabel.y = panY + 0.05;
    extLabel.text = '形变量 ' + (ext * 100).toFixed(1) + ' cm';
    extLabel.color = C_TEXT;
    this.snap.labels.push(extLabel);

    const zeroLabel = new LabelShape();
    zeroLabel.x = rulerX + 0.05;
    zeroLabel.y = zeroY + 0.01;
    zeroLabel.text = '原长位置';
    zeroLabel.color = C_RULER;
    this.snap.labels.push(zeroLabel);

    const limitLabel = new LabelShape();
    limitLabel.x = x - 0.3;
    limitLabel.y = zeroY - limit - 0.05;
    limitLabel.text = '弹性限度';
    limitLabel.color = C_LIMIT;
    this.snap.labels.push(limitLabel);

    if (this.residual > 1e-4) {
      const hurt = new LabelShape();
      hurt.x = 0.03;
      hurt.y = panY - 0.1;
      hurt.text = '撤去砝码后回不到零:' + (this.residual * 100).toFixed(1) + ' cm';
      hurt.color = C_LIMIT;
      this.snap.labels.push(hurt);
    }

    return this.snap;
  }

  dispose(): void {
    super.dispose();
    this.records = [];
    this.recordLoads = [];
  }
}
