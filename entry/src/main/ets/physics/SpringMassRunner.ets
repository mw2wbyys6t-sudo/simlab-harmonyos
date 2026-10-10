import { Physics2DRunner } from './Physics2DRunner';
import {
  ArrowShape, BoxShape, CircleShape, LabelShape, SegmentShape, SpringShape, WorldSnapshot
} from './World2D';

const WALL_X = 0.6;
const NATURAL_LEN = 2.2;
const TABLE_Y = 0.9;
const BLOCK_W = 0.7;
const BLOCK_H = 0.5;
/** 平衡位置:墙 + 弹簧自然长度 */
const EQUILIBRIUM_X = WALL_X + NATURAL_LEN;

const C_BODY = '#2F6FB5';
const C_WALL = '#33404F';
const C_SPRING = '#8E5BD9';
const C_GUIDE = '#9AA7B8';
const C_TEXT = '#1F2A3A';
const C_V = '#E2574C';

/**
 * 弹簧振子:m x'' = -k x - c x'
 *
 * 用半隐式欧拉(先更新速度再更新位移)。在 240Hz 定步长下,它比显式欧拉的能量
 * 漂移小一个量级 —— 简谐振动实验里「总能量是否守恒」本身就是观测目标,
 * 数值耗散会被学生误读成阻尼,所以积分方案不能随便选。
 */
export class SpringMassRunner extends Physics2DRunner {
  private x: number = 0;
  private v: number = 0;
  private acc: number = 0;
  private prevX: number = 0;
  private lastCrossTime: number = -1;
  private measuredPeriod: number = Number.NaN;
  private snap: WorldSnapshot = new WorldSnapshot();

  protected onSetup(): void {
    this.x = this.getParam('amplitude');
    this.v = 0;
    this.acc = 0;
    this.prevX = this.x;
    this.lastCrossTime = -1;
    this.measuredPeriod = Number.NaN;
  }

  protected onParamChanged(key: string, value: number): void {
    // 初始位移只在尚未起跑时改变构型;m/k/c 则实时生效,便于课堂对照演示
    if (key === 'amplitude' && this.time === 0) {
      this.x = value;
      this.prevX = value;
    }
  }

  step(dt: number): void {
    const m = this.getParam('mass');
    const k = this.getParam('stiffness');
    const c = this.getParam('damping');
    const mass = m <= 0.01 ? 0.01 : m;

    this.acc = (-k * this.x - c * this.v) / mass;
    this.v += this.acc * dt;
    this.prevX = this.x;
    this.x += this.v * dt;
    this.time += dt;

    // 周期实测:连续两次以正方向通过平衡位置的时间间隔
    if (this.prevX < 0 && this.x >= 0 && this.v > 0) {
      if (this.lastCrossTime >= 0) {
        this.measuredPeriod = this.time - this.lastCrossTime;
      }
      this.lastCrossTime = this.time;
    }
  }

  readObservable(key: string): number {
    const m = this.getParam('mass');
    const k = this.getParam('stiffness');
    switch (key) {
      case 'displacement':
        return this.x;
      case 'velocity':
        return this.v;
      case 'acceleration':
        return this.acc;
      case 'kinetic':
        return 0.5 * m * this.v * this.v;
      case 'potential':
        return 0.5 * k * this.x * this.x;
      case 'total':
        return 0.5 * m * this.v * this.v + 0.5 * k * this.x * this.x;
      case 'periodTheory':
        return k <= 0 ? Number.NaN : 2 * Math.PI * Math.sqrt(m / k);
      case 'periodMeasured':
        return this.measuredPeriod;
      default:
        return Number.NaN;
    }
  }

  snapshot(): WorldSnapshot {
    this.snap.clear();
    const cx = EQUILIBRIUM_X + this.x;
    const cy = TABLE_Y + BLOCK_H / 2;

    const wall = new SegmentShape();
    wall.x1 = WALL_X;
    wall.y1 = TABLE_Y;
    wall.x2 = WALL_X;
    wall.y2 = TABLE_Y + 1.6;
    wall.color = C_WALL;
    wall.widthMm = 8;
    this.snap.segments.push(wall);

    const table = new SegmentShape();
    table.x1 = 0.2;
    table.y1 = TABLE_Y;
    table.x2 = this.meta.worldWidth - 0.2;
    table.y2 = TABLE_Y;
    table.color = C_WALL;
    table.widthMm = 4;
    this.snap.segments.push(table);

    const guide = new SegmentShape();
    guide.x1 = EQUILIBRIUM_X;
    guide.y1 = TABLE_Y;
    guide.x2 = EQUILIBRIUM_X;
    guide.y2 = TABLE_Y + 1.7;
    guide.color = C_GUIDE;
    guide.widthMm = 2;
    guide.dashed = true;
    this.snap.segments.push(guide);

    const spring = new SpringShape();
    spring.x1 = WALL_X;
    spring.y1 = cy;
    spring.x2 = cx - BLOCK_W / 2;
    spring.y2 = cy;
    spring.coils = 9;
    spring.amplitude = 0.2;
    spring.color = C_SPRING;
    this.snap.springs.push(spring);

    const block = new BoxShape();
    block.cx = cx;
    block.cy = cy;
    block.w = BLOCK_W;
    block.h = BLOCK_H;
    block.color = C_BODY;
    this.snap.boxes.push(block);

    const anchor = new CircleShape();
    anchor.cx = WALL_X;
    anchor.cy = cy;
    anchor.r = 0.06;
    anchor.color = C_WALL;
    this.snap.circles.push(anchor);

    if (Math.abs(this.v) > 0.02) {
      const arrow = new ArrowShape();
      arrow.x = cx;
      arrow.y = cy + BLOCK_H + 0.25;
      arrow.dx = this.v > 0 ? Math.min(0.9, 0.25 + Math.abs(this.v) * 0.18) : -Math.min(0.9, 0.25 + Math.abs(this.v) * 0.18);
      arrow.dy = 0;
      arrow.label = 'v';
      arrow.color = C_V;
      this.snap.arrows.push(arrow);
    }

    const eq = new LabelShape();
    eq.x = EQUILIBRIUM_X - 0.25;
    eq.y = TABLE_Y - 0.28;
    eq.text = '平衡位置';
    eq.color = C_GUIDE;
    this.snap.labels.push(eq);

    const disp = new LabelShape();
    disp.x = cx - 0.35;
    disp.y = cy + BLOCK_H + 0.45;
    disp.text = 'x=' + this.x.toFixed(2) + ' m';
    disp.color = C_TEXT;
    this.snap.labels.push(disp);

    return this.snap;
  }
}
