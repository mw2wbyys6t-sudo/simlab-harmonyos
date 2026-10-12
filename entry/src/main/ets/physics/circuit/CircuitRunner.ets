import { Physics2DRunner } from '../Physics2DRunner';
import { MnaSolver } from '../MnaSolver';
import {
  ArrowShape, BoxShape, CircleShape, FillStyle, LabelShape, SegmentShape, WorldSnapshot
} from '../World2D';
import { CircuitSpec, Component, ComponentKind, WirePath } from './CircuitModel';

const C_WIRE = '#33404F';
const C_BODY = '#2F6FB5';
const C_METER = '#8E5BD9';
const C_LAMP = '#D9863D';
const C_TEXT = '#1F2A3A';
const C_READ = '#2E9E7A';
const C_OPEN = '#E2574C';

/** 元件符号的几何尺寸(米) */
const SYMBOL_HALF = 0.42;
const SYMBOL_THICK = 0.26;
const METER_R = 0.26;
/** 一行电表读数约占的宽度(米)。是下限估计:真越界时绘制层还会把文字兜回画布内 */
const READOUT_SPAN = 1.0;

/**
 * 直流电路求解与绘制。
 *
 * 用改进节点电压法(MNA)而不是「先识别串并联再套公式」:套公式只能算出题解里
 * 预设的那几种拓扑,而 MNA 对任意连接都成立 —— 学生把电表接错、把导线短接时,
 * 应用给出的仍是真实后果(读数变零、电流过大),这正是虚拟实验相对纸质题目的价值。
 */
export class CircuitRunner extends Physics2DRunner {
  protected spec: CircuitSpec;
  private nodeVoltages: number[] = [];
  private currents: Map<string, number> = new Map();
  private voltages: Map<string, number> = new Map();
  private solved: boolean = false;
  private snap: WorldSnapshot = new WorldSnapshot();

  constructor(spec: CircuitSpec) {
    super();
    this.spec = spec;
  }

  protected onSetup(): void {
    this.solve();
  }

  protected onParamChanged(key: string, value: number): void {
    this.solve();
  }

  /** 直流电路不随时间演化,参数一变即重解 */
  step(dt: number): void {
    this.time += dt;
  }

  private paramValueOf(item: Component): number {
    if (item.paramKey.length === 0) {
      return item.value;
    }
    const hit = this.params.get(item.paramKey);
    return hit === undefined ? item.value : hit;
  }

  /** 节点 → 未知量下标;参考点被消去,故其后继节点整体前移一位 */
  private voltageIndex(node: number): number {
    if (node === this.spec.ground) {
      return -1;
    }
    return node < this.spec.ground ? node : node - 1;
  }

  private nodeCount(): number {
    return this.spec.nodeCount - 1;
  }

  solve(): void {
    const sources: Component[] = [];
    for (let i = 0; i < this.spec.components.length; i++) {
      if (this.spec.components[i].kind === ComponentKind.SOURCE) {
        sources.push(this.spec.components[i]);
      }
    }

    const size = this.nodeCount() + sources.length;
    const matrix: number[][] = [];
    for (let i = 0; i < size; i++) {
      const row: number[] = new Array<number>(size);
      for (let j = 0; j < size; j++) {
        row[j] = 0;
      }
      matrix.push(row);
    }
    const rhs: number[] = new Array<number>(size);
    for (let i = 0; i < size; i++) {
      rhs[i] = 0;
    }

    for (let i = 0; i < this.spec.components.length; i++) {
      const item = this.spec.components[i];
      if (item.kind === ComponentKind.SOURCE) {
        const k = this.nodeCount() + sources.indexOf(item);
        const a = this.voltageIndex(item.nodeA);
        const b = this.voltageIndex(item.nodeB);
        if (a >= 0) {
          matrix[a][k] += 1;
          matrix[k][a] += 1;
        }
        if (b >= 0) {
          matrix[b][k] -= 1;
          matrix[k][b] -= 1;
        }
        rhs[k] = this.paramValueOf(item);
        continue;
      }
      const resistance = item.resistance(this.paramValueOf(item));
      if (resistance <= 0) {
        continue;
      }
      const g = 1 / resistance;
      const a = this.voltageIndex(item.nodeA);
      const b = this.voltageIndex(item.nodeB);
      if (a >= 0) {
        matrix[a][a] += g;
      }
      if (b >= 0) {
        matrix[b][b] += g;
      }
      if (a >= 0 && b >= 0) {
        matrix[a][b] -= g;
        matrix[b][a] -= g;
      }
    }

    const solution = MnaSolver.solve(matrix, rhs);
    this.currents.clear();
    this.voltages.clear();
    if (solution === null) {
      this.solved = false;
      this.nodeVoltages = [];
      return;
    }

    this.nodeVoltages = [];
    for (let node = 0; node < this.spec.nodeCount; node++) {
      const index = this.voltageIndex(node);
      this.nodeVoltages.push(index < 0 ? 0 : solution[index]);
    }

    for (let i = 0; i < this.spec.components.length; i++) {
      const item = this.spec.components[i];
      const va = this.potential(item.nodeA);
      const vb = this.potential(item.nodeB);
      if (item.kind === ComponentKind.SOURCE) {
        const k = this.nodeCount() + sources.indexOf(item);
        // 电压源支路电流的未知量取「自 + 端流出到外电路」为正
        this.currents.set(item.id, -solution[k]);
        this.voltages.set(item.id, va - vb);
        continue;
      }
      const resistance = item.resistance(this.paramValueOf(item));
      this.voltages.set(item.id, va - vb);
      this.currents.set(item.id, resistance <= 0 ? 0 : (va - vb) / resistance);
    }
    this.solved = true;
  }

  private potential(node: number): number {
    if (node < 0 || node >= this.nodeVoltages.length) {
      return 0;
    }
    return this.nodeVoltages[node];
  }

  readObservable(key: string): number {
    if (!this.solved) {
      return Number.NaN;
    }
    if (key === 'Req') {
      return this.equivalentResistance();
    }
    const sep = key.indexOf(':');
    if (sep < 0) {
      return Number.NaN;
    }
    const kind = key.substring(0, sep);
    const id = key.substring(sep + 1);
    if (kind === 'V') {
      return this.potential(Number.parseInt(id, 10));
    }
    const current = this.currents.get(id);
    const voltage = this.voltages.get(id);
    if (kind === 'I') {
      return current === undefined ? Number.NaN : Math.abs(current);
    }
    if (kind === 'SIGNED_I') {
      return current === undefined ? Number.NaN : current;
    }
    if (kind === 'U') {
      return voltage === undefined ? Number.NaN : Math.abs(voltage);
    }
    if (kind === 'P') {
      if (current === undefined || voltage === undefined) {
        return Number.NaN;
      }
      return Math.abs(current * voltage);
    }
    return Number.NaN;
  }

  /** 电源看进去的等效外阻。电流低于 1 μA 即视为开路:否则断开开关时会把
   * 开关的 1e9 Ω 绝缘电阻当成「总电阻」报给学生 */
  private equivalentResistance(): number {
    let source: Component | null = null;
    for (let i = 0; i < this.spec.components.length; i++) {
      if (this.spec.components[i].kind === ComponentKind.SOURCE) {
        source = this.spec.components[i];
      }
    }
    if (source === null) {
      return Number.NaN;
    }
    const current = this.currents.get(source.id);
    const voltage = this.voltages.get(source.id);
    if (current === undefined || voltage === undefined || Math.abs(current) < 1e-6) {
      return Number.NaN;
    }
    return Math.abs(voltage / current);
  }

  snapshot(): WorldSnapshot {
    this.snap.clear();
    for (let i = 0; i < this.spec.wires.length; i++) {
      this.drawWire(this.spec.wires[i]);
    }
    for (let i = 0; i < this.spec.components.length; i++) {
      this.drawComponent(this.spec.components[i]);
    }
    return this.snap;
  }

  private drawWire(path: WirePath): void {
    for (let i = 1; i < path.xs.length; i++) {
      const seg = new SegmentShape();
      seg.x1 = path.xs[i - 1];
      seg.y1 = path.ys[i - 1];
      seg.x2 = path.xs[i];
      seg.y2 = path.ys[i];
      seg.color = C_WIRE;
      seg.widthMm = 2.5;
      this.snap.segments.push(seg);
    }
  }

  private midX(item: Component): number {
    return (item.ax + item.bx) / 2 + item.offsetX;
  }

  private midY(item: Component): number {
    return (item.ay + item.by) / 2 + item.offsetY;
  }

  /** 元件两端的朝向:单位方向向量与世界角度(度) */
  private dirX(item: Component): number {
    const dx = item.bx - item.ax;
    const dy = item.by - item.ay;
    const long = Math.sqrt(dx * dx + dy * dy);
    return long < 1e-6 ? 0 : dx / long;
  }

  private dirY(item: Component): number {
    const dx = item.bx - item.ax;
    const dy = item.by - item.ay;
    const long = Math.sqrt(dx * dx + dy * dy);
    return long < 1e-6 ? 0 : dy / long;
  }

  private angleDeg(item: Component): number {
    return Math.atan2(item.by - item.ay, item.bx - item.ax) * 180 / Math.PI;
  }

  private lead(item: Component, fromEnd: number, toX: number, toY: number): void {
    const seg = new SegmentShape();
    seg.x1 = fromEnd === 0 ? item.ax : item.bx;
    seg.y1 = fromEnd === 0 ? item.ay : item.by;
    seg.x2 = toX;
    seg.y2 = toY;
    seg.color = C_WIRE;
    seg.widthMm = 2.5;
    this.snap.segments.push(seg);
  }

  /** 跨接在两点之间、但符号画在偏移位置的元件(电压表),引线折成两段 */
  private bentLeads(item: Component): void {
    const mx = this.midX(item);
    const my = this.midY(item);
    this.lead(item, 0, mx, my);
    this.lead(item, 1, mx, my);
  }

  private straightLeads(item: Component, half: number): void {
    const ux = this.dirX(item);
    const uy = this.dirY(item);
    this.lead(item, 0, item.ax + ux * half, item.ay + uy * half);
    this.lead(item, 1, item.bx - ux * half, item.by - uy * half);
  }

  private drawComponent(item: Component): void {
    const offset = item.offsetX !== 0 || item.offsetY !== 0;
    switch (item.kind) {
      case ComponentKind.RESISTOR:
      case ComponentKind.RHEOSTAT: {
        this.straightLeads(item, SYMBOL_HALF);
        const box = new BoxShape();
        box.cx = this.midX(item);
        box.cy = this.midY(item);
        box.w = SYMBOL_HALF * 2;
        box.h = SYMBOL_THICK;
        box.angleDeg = this.angleDeg(item);
        box.color = C_BODY;
        box.fill = FillStyle.OUTLINE;
        this.snap.boxes.push(box);
        break;
      }
      case ComponentKind.LAMP: {
        this.straightLeads(item, METER_R);
        const circle = new CircleShape();
        circle.cx = this.midX(item);
        circle.cy = this.midY(item);
        circle.r = METER_R;
        circle.color = C_LAMP;
        circle.fill = FillStyle.OUTLINE;
        this.snap.circles.push(circle);
        this.crossMarks(item, METER_R * 0.72);
        break;
      }
      case ComponentKind.AMMETER:
      case ComponentKind.VOLTMETER: {
        if (offset) {
          this.bentLeads(item);
        } else {
          this.straightLeads(item, METER_R);
        }
        const circle = new CircleShape();
        circle.cx = this.midX(item);
        circle.cy = this.midY(item);
        circle.r = METER_R;
        circle.color = item.kind === ComponentKind.AMMETER ? C_METER : C_BODY;
        circle.fill = FillStyle.OUTLINE;
        this.snap.circles.push(circle);
        const glyph = new LabelShape();
        glyph.x = this.midX(item) - 0.08;
        glyph.y = this.midY(item) + 0.09;
        glyph.text = item.kind === ComponentKind.AMMETER ? 'A' : 'V';
        glyph.sizeVp = 15;
        glyph.color = circle.color;
        this.snap.labels.push(glyph);
        this.readout(item, circle.color);
        break;
      }
      case ComponentKind.SOURCE: {
        this.straightLeads(item, 0.18);
        // 长线是正极、短粗线是负极:正极靠 A 端
        this.plate(item.ax, item.ay, item.bx, item.by, 0.4, 0.42, C_WIRE, 3);
        this.plate(item.ax, item.ay, item.bx, item.by, 0.6, 0.15, C_WIRE, 7);
        const dx = item.bx - item.ax;
        const dy = item.by - item.ay;
        const long = Math.sqrt(dx * dx + dy * dy);
        const nx = long < 1e-6 ? 1 : -dy / long;
        const ny = long < 1e-6 ? 0 : dx / long;
        const plus = new LabelShape();
        plus.x = item.ax + dx * 0.4 + nx * 0.3;
        plus.y = item.ay + dy * 0.4 + ny * 0.3;
        plus.text = '+';
        plus.color = C_TEXT;
        this.snap.labels.push(plus);
        const minus = new LabelShape();
        minus.x = item.ax + dx * 0.6 + nx * 0.3;
        minus.y = item.ay + dy * 0.6 + ny * 0.3;
        minus.text = '−';
        minus.color = C_TEXT;
        this.snap.labels.push(minus);
        break;
      }
      case ComponentKind.SWITCH: {
        const closed = this.paramValueOf(item) >= 0.5;
        const ux = this.dirX(item);
        const uy = this.dirY(item);
        const px = this.midX(item) - ux * 0.36;
        const py = this.midY(item) - uy * 0.36;
        const qx = this.midX(item) + ux * 0.36;
        const qy = this.midY(item) + uy * 0.36;
        this.snap.segments.push(this.seg(item.ax, item.ay, px, py, C_WIRE, 2.5));
        this.snap.segments.push(this.seg(qx, qy, item.bx, item.by, C_WIRE, 2.5));
        this.snap.circles.push(this.dot(px, py, 0.05, C_WIRE));
        this.snap.circles.push(this.dot(qx, qy, 0.05, C_WIRE));
        if (closed) {
          this.snap.segments.push(this.seg(px, py, qx, qy, C_WIRE, 4));
        } else {
          // 闸刀绕支点缩短并始终向上抬起,与元件本身朝哪个方向无关
          this.snap.segments.push(this.seg(px, py,
            px + (qx - px) * 0.87, py + (qy - py) * 0.87 + 0.36, C_OPEN, 4));
        }
        this.nameTag(item, px, py + 0.26, 'center');
        break;
      }
      default:
        break;
    }

    if (item.kind !== ComponentKind.SWITCH && item.kind !== ComponentKind.SOURCE) {
      this.nameTagBeside(item);
      this.currentArrow(item);
    } else if (item.kind === ComponentKind.SOURCE) {
      this.sourceTag(item);
    }
  }

  /**
   * 元件代号一律印在**垂直于轴向**的一侧。
   *
   * 以前不分横竖都往上方抬 0.42 米:横着的元件正好,竖着的元件等于把代号
   * 按在自己身上(串联页竖放的 R₂、本场景竖放的 R 与 V 都被压过字)。
   *
   * 跨接式电压表(带 offset,符号被挪离接线端)是例外:它的两根折引线正好从
   * 侧面汇进圆里,往侧面放就压在引线上 —— 那一类留在上方,与改动前一致。
   */
  private nameTagBeside(item: Component): void {
    const gap = SYMBOL_THICK + 0.16;
    const offsetSymbol = item.offsetX !== 0 || item.offsetY !== 0;
    if (!offsetSymbol && Math.abs(item.by - item.ay) > Math.abs(item.bx - item.ax)) {
      this.nameTag(item, this.midX(item) - gap, this.midY(item) + 0.09, 'center');
      return;
    }
    this.nameTag(item, this.midX(item), this.midY(item) + gap, 'center');
  }

  private seg(x1: number, y1: number, x2: number, y2: number, color: string, widthMm: number): SegmentShape {
    const seg = new SegmentShape();
    seg.x1 = x1;
    seg.y1 = y1;
    seg.x2 = x2;
    seg.y2 = y2;
    seg.color = color;
    seg.widthMm = widthMm;
    return seg;
  }

  private dot(cx: number, cy: number, r: number, color: string): CircleShape {
    const dot = new CircleShape();
    dot.cx = cx;
    dot.cy = cy;
    dot.r = r;
    dot.color = color;
    return dot;
  }

  /** 电池的两块极板:垂直于轴向、长短不同,长线为正极 */
  private plate(ax: number, ay: number, bx: number, by: number, tPos: number,
    halfLen: number, color: string, widthMm: number): void {
    const ux = bx - ax;
    const uy = by - ay;
    const long = Math.sqrt(ux * ux + uy * uy);
    if (long < 1e-6) {
      return;
    }
    const nx = -uy / long;
    const ny = ux / long;
    const cx = ax + ux * tPos;
    const cy = ay + uy * tPos;
    this.snap.segments.push(this.seg(cx - nx * halfLen, cy - ny * halfLen,
      cx + nx * halfLen, cy + ny * halfLen, color, widthMm));
  }

  private crossMarks(item: Component, size: number): void {
    const cx = this.midX(item);
    const cy = this.midY(item);
    this.snap.segments.push(this.seg(cx - size, cy - size, cx + size, cy + size, C_LAMP, 2));
    this.snap.segments.push(this.seg(cx - size, cy + size, cx + size, cy - size, C_LAMP, 2));
  }

  private nameTag(item: Component, x: number, y: number, align: string): void {
    if (item.label.length === 0) {
      return;
    }
    const tag = new LabelShape();
    tag.x = x;
    tag.y = y;
    tag.text = item.label;
    tag.sizeVp = 14;
    tag.color = C_TEXT;
    tag.align = align;
    this.snap.labels.push(tag);
  }

  /**
   * 电源标签放在极板外侧。
   *
   * 原来写死 `(ax+bx)/2 - 0.62` 再左对齐:长极板本身向两侧伸出 0.42,
   * 于是「电源」两个字有一半压在极板上(截图实测)。现在按极板的法线方向外移,
   * 竖放的电源字在左边、横放的电源字在上边,都不碰符号。
   */
  /**
   * 电源代号贴着极板**外侧**起排,而不是居中摆在极板延长线上。
   *
   * 一行「电源 E」约占 1.7 米,以前按 center 放在轴线外 0.56 米处,
   * 于是有一半字压回极板(长极板从轴线伸到 ±0.4 米)—— 每个电路场景的电源都是这样。
   * 改成按极板朝外的那一侧起排,文字朝外长,压不到东西。
   */
  private sourceTag(item: Component): void {
    const dx = item.bx - item.ax;
    const dy = item.by - item.ay;
    const long = Math.sqrt(dx * dx + dy * dy);
    if (long < 1e-6) {
      return;
    }
    const nx = -dy / long;
    const ny = dx / long;
    const vertical = Math.abs(dy) > Math.abs(dx);
    // 0.6 = 极板半长 0.4 之外再留一截:「+」号占在 0.3~0.45 处,贴太近会读成「+电源」
    const gap = 0.6;
    if (!vertical) {
      this.nameTag(item, (item.ax + item.bx) / 2 + nx * gap,
        (item.ay + item.by) / 2 + ny * gap, 'center');
      return;
    }
    this.nameTag(item, (item.ax + item.bx) / 2 + nx * gap,
      (item.ay + item.by) / 2 + 0.09, nx > 0 ? 'left' : 'right');
  }

  /**
   * 电表读数标注:竖着的元件把数字放侧面,横着的放下方,避免压住导线。
   *
   * 侧面这一档以前只有"放右边":V₂ 挂在最右侧支路上时,`midX + METER_R + 0.12`
   * 起头的字直接被画布右边界裁成「3.6…」。模型层只知道米、不知道一行字占多少像素,
   * 所以这里用一个下限估宽判断放不放得下,放不下就退到圆的下方居中 ——
   * 退到左边会压在同一条支路的电阻上(实测)。绘制层还会再兜一次不越界。
   */
  private readout(item: Component, color: string): void {
    if (!this.solved) {
      return;
    }
    const current = this.currents.get(item.id);
    const voltage = this.voltages.get(item.id);
    if (current === undefined || voltage === undefined) {
      return;
    }
    const vertical = Math.abs(this.dirX(item)) < 0.5;
    const isAmmeter = item.kind === ComponentKind.AMMETER;
    const text = (isAmmeter ? current.toFixed(2) + ' A' : Math.abs(voltage).toFixed(2) + ' V');
    const gap = METER_R + 0.12;
    const label = new LabelShape();
    if (vertical && this.midX(item) + gap + READOUT_SPAN <= this.meta.worldWidth) {
      label.x = this.midX(item) + gap;
      label.y = this.midY(item) + 0.06;
      label.align = 'left';
    } else {
      label.x = this.midX(item);
      label.y = this.midY(item) - METER_R - (vertical ? 0.26 : 0.18);
      label.align = 'center';
    }
    label.text = text;
    label.sizeVp = 13;
    label.color = color;
    this.snap.labels.push(label);
  }

  /** 沿轴向画电流方向箭头,方向即约定正方向 */
  private currentArrow(item: Component): void {
    const current = this.currents.get(item.id);
    if (current === undefined || Math.abs(current) < 1e-6) {
      return;
    }
    const ux = this.dirX(item);
    const uy = this.dirY(item);
    const sign = current > 0 ? 1 : -1;
    const arrow = new ArrowShape();
    // 画在元件侧方,避免压住符号本身
    arrow.x = this.midX(item) - uy * sign * 0.46;
    arrow.y = this.midY(item) + ux * sign * 0.46;
    arrow.dx = ux * sign * 0.34;
    arrow.dy = uy * sign * 0.34;
    arrow.color = C_READ;
    this.snap.arrows.push(arrow);
  }
}
