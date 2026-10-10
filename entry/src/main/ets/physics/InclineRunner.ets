import { Physics2DRunner } from './Physics2DRunner';
import {
  ArrowShape, BoxShape, LabelShape, SegmentShape, WorldSnapshot
} from './World2D';

const G = 9.8;
/** 判定「已停下」的速度阈值。低于它按静摩擦处理,避免数值抖动让物体自启动 */
const V_REST = 0.008;
const GROUND_Y = 0.6;
const TOE_X = 6.2;
const BLOCK_W = 0.62;
const BLOCK_H = 0.42;

const C_SLOPE = '#5A6B7F';
const C_BLOCK = '#D9863D';
const C_GROUND = '#33404F';
const C_FG = '#2E9E7A';
const C_FN = '#2F6FB5';
const C_FFRIC = '#E2574C';
const C_TEXT = '#1F2A3A';

/**
 * 斜面滑块:含摩擦的斜面动力学,支持上滑与下滑。
 *
 * 摩擦力的方向处理是这个实验的关键。它不能写成固定方向的常量,必须实时取
 * sign(-v) 与运动方向相反;速度归零时还要切回静摩擦判据 tanθ ≤ μ,
 * 否则物体会在斜面上自发滑动或来回抖动 —— 那正是学生最容易产生的错误直觉。
 */
export class InclineRunner extends Physics2DRunner {
  private s: number = 0;
  private v: number = 0;
  private acc: number = 0;
  private pathLength: number = 0;
  private startS: number = 0;
  private closestToTop: number = 0;
  private ended: boolean = false;
  private endedAtTop: boolean = false;
  private endTime: number = Number.NaN;
  private endSpeed: number = Number.NaN;
  private snap: WorldSnapshot = new WorldSnapshot();

  private rad(): number {
    return this.getParam('angle') * Math.PI / 180;
  }

  private slopeLen(): number {
    const l = this.getParam('length');
    return l <= 0.2 ? 0.2 : l;
  }

  protected onSetup(): void {
    const start = this.getParam('startDistance');
    this.s = start < 0 ? 0 : (start > this.slopeLen() ? this.slopeLen() : start);
    this.startS = this.s;
    this.closestToTop = this.s;
    this.v = this.getParam('initialVelocity');
    this.acc = 0;
    this.pathLength = 0;
    this.ended = false;
    this.endedAtTop = false;
    this.endTime = Number.NaN;
    this.endSpeed = Number.NaN;
  }

  protected onParamChanged(key: string, value: number): void {
    if (this.time > 0) {
      return;
    }
    if (key === 'initialVelocity') {
      this.v = value;
    }
    if (key === 'startDistance') {
      this.s = value < 0 ? 0 : (value > this.slopeLen() ? this.slopeLen() : value);
      this.startS = this.s;
      this.closestToTop = this.s;
    }
  }

  step(dt: number): void {
    if (this.ended) {
      // 到达端点后不再推进时间,避免「画面静止但还在计时」
      return;
    }
    const m = Math.max(0.05, this.getParam('mass'));
    const mu = this.getParam('friction');
    const th = this.rad();
    const sinT = Math.sin(th);
    const cosT = Math.cos(th);
    const downGravity = G * sinT;
    const frictionMax = mu * G * cosT;

    if (Math.abs(this.v) <= V_REST) {
      // 静止:静摩擦能否扛住下滑分力
      if (downGravity > frictionMax) {
        this.acc = downGravity - frictionMax;
        this.v += this.acc * dt;
      } else {
        this.v = 0;
        this.acc = 0;
      }
    } else {
      const sign = this.v > 0 ? 1 : -1;
      this.acc = downGravity - frictionMax * sign;
      const nextV = this.v + this.acc * dt;
      const reversed = (this.v > 0 && nextV < 0) || (this.v < 0 && nextV > 0);
      if (reversed) {
        // 摩擦力把速度推过零点时应停在零点,而不是反向加速
        this.v = 0;
        this.acc = 0;
      } else {
        this.v = nextV;
      }
    }

    this.s += this.v * dt;
    this.pathLength += Math.abs(this.v) * dt;
    this.time += dt;
    if (this.s < this.closestToTop) {
      this.closestToTop = this.s;
    }

    /*
     * 端点判据必须带上运动方向。只看位置的话,「滑块自坡底以初速度上滑」
     * 这个经典场景会在起步瞬间就被判成已到底端;而反向越过坡顶若被简单归零,
     * 等于凭空吞掉动能,能量守恒实验跟着失真。所以两端都保留越界瞬间的速度。
     */
    const l = this.slopeLen();
    if (this.s >= l && this.v > 0) {
      this.s = l;
      this.endAt(l, false);
    } else if (this.s <= 0 && this.v < 0) {
      this.s = 0;
      this.endAt(0, true);
    }
  }

  private endAt(distance: number, atTop: boolean): void {
    this.s = distance;
    this.acc = 0;
    this.endSpeed = this.v;
    this.ended = true;
    this.endedAtTop = atTop;
    this.endTime = this.time;
  }

  /** 相对底端的高度 */
  private height(): number {
    return (this.slopeLen() - this.s) * Math.sin(this.rad());
  }

  readObservable(key: string): number {
    const m = Math.max(0.05, this.getParam('mass'));
    const mu = this.getParam('friction');
    const th = this.rad();
    switch (key) {
      case 'distance':
        return this.s;
      case 'velocity':
        return this.v;
      case 'acceleration':
        return this.acc;
      case 'height':
        return this.height();
      case 'path':
        return this.pathLength;
      case 'kinetic':
        return 0.5 * m * this.v * this.v;
      case 'potential':
        return m * G * this.height();
      case 'heat':
        return mu * m * G * Math.cos(th) * this.pathLength;
      case 'distanceMax':
        // 上滑最大距离:相对起始位置朝坡顶方向走了多远
        return this.startS - this.closestToTop;
      case 'velocityEnd':
        return Math.abs(this.endSpeed);
      case 'timeToEnd':
        return this.endTime;
      default:
        return Number.NaN;
    }
  }

  finished(): boolean {
    return this.ended;
  }

  snapshot(): WorldSnapshot {
    this.snap.clear();
    const th = this.rad();
    const deg = this.getParam('angle');
    const l = this.slopeLen();
    const sinT = Math.sin(th);
    const cosT = Math.cos(th);
    const base = l * cosT;
    const topY = GROUND_Y + l * sinT;
    // 坡顶 T,坡底 B,直角顶点 C
    const tx = TOE_X - base;
    const ty = topY;
    const bx = TOE_X;
    const by = GROUND_Y;

    const slope = new SegmentShape();
    slope.x1 = tx;
    slope.y1 = ty;
    slope.x2 = bx;
    slope.y2 = by;
    slope.color = C_SLOPE;
    slope.widthMm = 6;
    this.snap.segments.push(slope);

    const back = new SegmentShape();
    back.x1 = tx;
    back.y1 = ty;
    back.x2 = tx;
    back.y2 = by;
    back.color = C_SLOPE;
    back.widthMm = 4;
    this.snap.segments.push(back);

    const ground = new SegmentShape();
    ground.x1 = 0.3;
    ground.y1 = GROUND_Y;
    ground.x2 = this.meta.worldWidth - 0.3;
    ground.y2 = GROUND_Y;
    ground.color = C_GROUND;
    ground.widthMm = 4;
    this.snap.segments.push(ground);

    // 滑块中心:沿坡面向下 s,再沿外法线抬起半个块高
    const ux = cosT;
    const uy = -sinT;
    const nx = sinT;
    const ny = cosT;
    const cx = tx + this.s * ux + nx * (BLOCK_H / 2 + 0.02);
    const cy = ty + this.s * uy + ny * (BLOCK_H / 2 + 0.02);

    const block = new BoxShape();
    block.cx = cx;
    block.cy = cy;
    block.w = BLOCK_W;
    block.h = BLOCK_H;
    block.angleDeg = -deg;
    block.color = C_BLOCK;
    this.snap.boxes.push(block);

    const m = Math.max(0.05, this.getParam('mass'));
    const mu = this.getParam('friction');
    const forceScale = 0.012;

    const weight = new ArrowShape();
    weight.x = cx;
    weight.y = cy;
    weight.dx = 0;
    weight.dy = -m * G * forceScale;
    weight.label = 'mg';
    weight.color = C_FN;
    this.snap.arrows.push(weight);

    const normal = new ArrowShape();
    normal.x = cx;
    normal.y = cy;
    const nMag = m * G * cosT * forceScale;
    normal.dx = nx * nMag;
    normal.dy = ny * nMag;
    normal.label = 'N';
    normal.color = C_FG;
    this.snap.arrows.push(normal);

    if (Math.abs(this.v) > V_REST || (Math.sin(th) > mu * Math.cos(th))) {
      const fric = new ArrowShape();
      fric.x = cx;
      fric.y = cy;
      const moving = Math.abs(this.v) > V_REST;
      const dir = moving ? (this.v > 0 ? -1 : 1) : 1;
      const fMag = mu * m * G * cosT * forceScale;
      fric.dx = ux * dir * fMag;
      fric.dy = uy * dir * fMag;
      fric.label = 'f';
      fric.color = C_FFRIC;
      this.snap.arrows.push(fric);
    }

    const angleLabel = new LabelShape();
    angleLabel.x = bx - 1.1;
    angleLabel.y = GROUND_Y + 0.12;
    angleLabel.text = 'θ=' + deg.toFixed(0) + '°';
    angleLabel.color = C_TEXT;
    this.snap.labels.push(angleLabel);

    const stateLabel = new LabelShape();
    stateLabel.x = cx - 0.6;
    stateLabel.y = cy + 0.75;
    stateLabel.text = 's=' + this.s.toFixed(2) + ' m  v=' + this.v.toFixed(2) + ' m/s';
    stateLabel.color = C_TEXT;
    this.snap.labels.push(stateLabel);

    if (this.ended) {
      const done = new LabelShape();
      done.x = bx - 1.7;
      done.y = by + 0.5;
      done.text = this.endedAtTop ? '已从坡顶滑出' : '已到达底端';
      done.color = C_FFRIC;
      this.snap.labels.push(done);
    }

    return this.snap;
  }
}
