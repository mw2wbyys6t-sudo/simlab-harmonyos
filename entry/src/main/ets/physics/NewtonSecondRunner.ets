import { ExperimentMeta } from '../model/ExperimentTypes';
import { FactSheet } from '../model/FactSheet';
import { Physics2DRunner } from './Physics2DRunner';
import {
  BoxShape, CircleShape, FillStyle, LabelShape, SegmentShape, WorldSnapshot
} from './World2D';
import { TAPE_SCALE, TapeStrip } from './TapeStrip';
import { TickerTape } from './TickerTape';

const G = 9.8;
/** 判定「已经停了」的速度阈值:低于它按静止处理,静摩擦能否扛住要看下一条判据 */
const V_REST = 0.008;

/**
 * 木板长度(米)。真实器材是 1 m 上下的长木板,这里和同组斜面场景一样按场景比例放大到
 * 看得清 —— 放大只作用于画面,所有**比值**保持真实:每层垫块抬高 160 mm 配 4 m 板长,
 * 倾角正切 0.04,与实验室里 30 mm 垫块配 0.75 m 板是同一档。
 */
const BOARD_LEN = 4.0;
/** 一层垫块把板端抬多高(米)。两层恰好抵消 μ=0.08 —— 平衡摩擦的答案是「两层」,不由我们报给学生 */
const RISE_PER_LAYER = 0.16;
const MAX_LAYERS = 3;
/** 板面与轮轴的等效动摩擦因数(器材属性,学生不能调,只能靠垫块去抵) */
const MU = 0.08;
/** 小车能朝滑轮走多远:受砝码桶的落地距离限制,再长就先把桶放到底 */
const RUN = 1.2;

const CART_MASS = 0.2;
const SLOT_MASS = 0.05;
const MAX_SLOTS = 6;
const BUCKET_MASS = 0.005;
const LOAD_MASS = 0.01;
const MAX_LOADS = 6;
/** 轻推给的初速度:不推就只能看见「抬得不够车不动」,推一把才看得见它在减速 */
const PUSH_V = 0.3;

const CART_W = 0.7;
const CART_H = 0.34;
const BUCKET_W = 0.34;
const BUCKET_H = 0.4;
/** 逐差法前后两半各取三段:纸带上真正被用到的就是这六段 */
const PER_HALF = 3;

const GROUND_Y = 0.5;
/** 桌面高度:滑轮端离地要够高,桶降完 RUN 米之后还贴在地面线以上(第一版画穿了地板) */
const TABLE_TOP = 2.9;
/** 板低端(挂滑轮那一端)坐在桌面边缘 */
const PULLEY_X = 5.12;
const PULLEY_Y = 2.75;
const PULLEY_R = 0.15;
/** 绳下垂段在小车出发时的长度:配上 RUN 之后,桶走到尽头时正好贴在地面线上 */
const HANG = 0.45;
/** 小车起点:离开打点计时器,朝滑轮走 RUN 米后桶到位 */
const START_S = 0.75;
const TAPE_Y = 4.9;
const TAPE_X = 0.8;

const C_TABLE = '#4E5A6B';
const C_BOARD = '#5A6B7F';
const C_CART = '#D9863D';
const C_SLOT = '#8E5BD9';
const C_BUCKET = '#2F6FB5';
const C_STRING = '#25313F';
const C_WEDGE = '#C7A44A';
const C_TIMER = '#2E9E7A';
const C_TEXT = '#1F2A3A';

/** 一次「记录这一条纸带」存下来的组:当时的两个质量,与这条纸带逐差法算出的 a */
class NewtonTrial {
  cartKg: number = 0;
  pullKg: number = 0;
  accel: number = Number.NaN;
}

/** 板面上的一个点 */
class BoardPoint {
  x: number = 0;
  y: number = 0;
}

/**
 * 探究加速度与物体受力、物体质量的关系(高中必修一,地图条目 `phy-sr-006`)。
 *
 * 动力学是**两体**的:小车在板上,砝码桶挂在滑轮另一侧,两者由同一根绳连着,
 * a = (m桶g + Mg·sinθ − μMg·cosθ)/(M + m桶)。分母里那个 m桶 是整条实验的题眼 ——
 * 只有 m桶 ≪ M 时才能把绳的拉力近似成 m桶g,a-F 图才近乎一条直线;桶加重到跟
 * 小车一个量级,图线就在高力端往下弯。所以这里按精确解算,不把拉力写成 m桶g。
 *
 * 判的几件事全在学生自己的动作里:垫了几层垫块不算分,算分的是**取下桶轻推一次**
 * 之后那条纸带均不均匀(匀速=平衡到位,越打越密=抬得不够,越打越疏=抬过头);
 * 记下几组、其中同一质量下换过几档拉力、同一拉力下试过几种质量、纸带够不够逐差。
 */
export class NewtonSecondRunner extends Physics2DRunner {
  private tape: TickerTape = new TickerTape();
  private trials: NewtonTrial[] = [];
  private spreads: number[] = [];
  private layers: number = 0;
  private slots: number = 0;
  private loads: number = 0;
  private attached: boolean = true;
  private s: number = 0;
  private v: number = 0;
  private acc: number = 0;
  private ended: boolean = false;
  /** 本次运动开始时的两个质量:记录时按这两个归档,免得中途改了砝码把组配错 */
  private runCartKg: number = CART_MASS;
  private runPullKg: number = 0;
  /** 这一段运动是不是「空载轻推」那次检查 */
  private checking: boolean = false;
  /** 第一次按下「记录」的时刻:报告页那条"分步时刻"要的是这个,不是交卷那一瞬 */
  private firstRecordAt: number = Number.NaN;

  /** 只有第一次进页面才清空记录本与器材;按「重置」只是让车回到起点,垫块与槽码都还摆着 */
  setup(meta: ExperimentMeta): void {
    this.trials = [];
    this.spreads = [];
    this.firstRecordAt = Number.NaN;
    this.layers = 0;
    this.slots = 0;
    this.loads = 0;
    this.attached = true;
    super.setup(meta);
  }

  /** 按「重置」只是让车回到起点:正在走的这次检查要结案的,不能因为重置就凭空消失 */
  reset(): void {
    this.commitCheck();
    super.reset();
  }

  protected onSetup(): void {
    this.tape.reset();
    this.s = 0;
    this.v = 0;
    this.acc = 0;
    this.ended = false;
    this.checking = false;
    this.runCartKg = this.cartKg();
    this.runPullKg = this.pullKg();
  }

  protected onAction(key: string): void {
    if (key === 'wedge+') {
      this.layers = this.layers < MAX_LAYERS ? this.layers + 1 : MAX_LAYERS;
      return;
    }
    if (key === 'wedge-') {
      this.layers = this.layers > 0 ? this.layers - 1 : 0;
      return;
    }
    if (key === 'slot+') {
      this.slots = this.slots < MAX_SLOTS ? this.slots + 1 : MAX_SLOTS;
      return;
    }
    if (key === 'slot-') {
      this.slots = this.slots > 0 ? this.slots - 1 : 0;
      return;
    }
    if (key === 'load+') {
      this.loads = this.loads < MAX_LOADS ? this.loads + 1 : MAX_LOADS;
      return;
    }
    if (key === 'load-') {
      this.loads = this.loads > 0 ? this.loads - 1 : 0;
      return;
    }
    if (key === 'hook') {
      this.attached = !this.attached;
      return;
    }
    if (key === 'power') {
      this.tape.setPower(!this.tape.isPowered(), this.time);
      return;
    }
    if (key === 'release') {
      this.beginRun(false);
      return;
    }
    if (key === 'push') {
      this.beginRun(true);
      return;
    }
    if (key === 'record') {
      this.recordTrial();
    }
  }

  /** 开始一段新的运动。上一段若是检查,先把它量出来的点距跨度结下来 */
  private beginRun(pushed: boolean): void {
    this.commitCheck();
    this.tape.release(this.time);
    this.ended = false;
    this.runCartKg = this.cartKg();
    this.runPullKg = this.pullKg();
    this.checking = pushed && !this.attached;
    if (pushed && Math.abs(this.v) <= V_REST) {
      this.v = PUSH_V;
    }
  }

  /** 把这一段纸带连同当时的两个质量记进本子:学生自己决定哪一段算一组数据 */
  private recordTrial(): void {
    const trial = new NewtonTrial();
    trial.cartKg = this.runCartKg;
    trial.pullKg = this.runPullKg;
    trial.accel = this.tapeAccel();
    this.trials.push(trial);
    if (!Number.isFinite(this.firstRecordAt)) {
      this.firstRecordAt = this.time;
    }
  }

  step(dt: number): void {
    if (this.ended) {
      // 桶降到底就不再推进时间:与同组那条斜面纸带一致,免得画面上一路叠到最后一点
      return;
    }
    if (!this.tape.isReleased()) {
      // 车还按在手里:时间在走、电源在打点,纸上是一段重叠点(车静止)
      this.time += dt;
      this.tape.tick(this.time, this.s, 0, 0);
      return;
    }
    const m = this.runPullKg;
    const M = Math.max(0.05, this.runCartKg);
    const sinT = this.sinT();
    const cosT = this.cosT();
    const drive = m * G + M * G * sinT;
    const resisting = MU * M * G * cosT;

    if (Math.abs(this.v) <= V_REST) {
      if (drive > resisting) {
        this.acc = (drive - resisting) / (M + m);
      } else {
        // 静摩擦扛住了:车不动,计时器却还在打 —— 这条纸带就是「没平衡好」的样子
        this.v = 0;
        this.acc = 0;
      }
    } else {
      const sign = this.v > 0 ? 1 : -1;
      this.acc = (drive - resisting * sign) / (M + m);
      const nextV = this.v + this.acc * dt;
      if ((this.v > 0 && nextV < 0) || (this.v < 0 && nextV > 0)) {
        // 摩擦把速度推过零点时就停在零点,不让它自己反向加速
        this.v = 0;
        this.acc = 0;
      }
    }

    // 恒加速度的精确推进,而且**只推一次**:s 用这一格起点的 v 再补 ½a·dt²。
    // 分支里若先 v += a·dt、这里又加一次,读出来的 a 就是真实值的两倍(实测踩过)。
    this.s += this.v * dt + 0.5 * this.acc * dt * dt;
    this.v += this.acc * dt;
    this.time += dt;
    if (this.s >= RUN) {
      this.s = RUN;
      this.v = 0;
      this.acc = 0;
      this.ended = true;
    }
    this.tape.tick(this.time, this.s, this.v, this.acc);
  }

  readObservable(key: string): number {
    switch (key) {
      case 'distance':
        return this.s;
      case 'velocity':
        return this.v;
      case 'n2CartMassKg':
        return this.cartKg();
      case 'n2PullMassKg':
        return this.pullKg();
      case 'n2WedgeLayers':
        return this.layers;
      case 'n2RiseMm':
        return this.layers * RISE_PER_LAYER * 1000;
      case 'n2TiltDeg':
        return Math.asin(this.sinT()) * 180 / Math.PI;
      case 'n2AccelTape':
        return this.tapeAccel();
      case 'n2IdleSpreadMm':
        return this.currentSpread();
      case 'n2ChecksDone':
        return this.checkList().length;
      case 'n2UsableCount':
        return this.usable().length;
      case 'n2ForceSteps':
        return this.stepCount(true);
      case 'n2MassSteps':
        return this.stepCount(false);
      case 'tapeDotCount':
        return this.tape.count();
      case 'tapeSegments':
        return this.tape.segmentCount(this.startDot(), this.everyGap());
      default:
        return Number.NaN;
    }
  }

  protected onCollectFacts(sheet: FactSheet): void {
    const usable = this.usable();
    sheet.set('n2RecordCount', this.trials.length);
    sheet.set('n2UsableCount', usable.length);
    sheet.set('n2ForceSteps', this.stepCount(true));
    sheet.set('n2MassSteps', this.stepCount(false));
    const checks = this.checkList();
    sheet.set('n2ChecksDone', checks.length);
    if (checks.length > 0) {
      const spread = checks[checks.length - 1];
      if (Number.isFinite(spread)) {
        sheet.set('n2IdleSpreadMm', spread);
      }
    }
    sheet.set('tapeDotCount', this.tape.count());
    sheet.mark('recorded', Number.isFinite(this.firstRecordAt) ? this.firstRecordAt : -1);
  }

  finished(): boolean {
    return this.ended;
  }

  snapshot(): WorldSnapshot {
    const snap = new WorldSnapshot();
    const sinT = this.sinT();
    const cosT = this.cosT();
    const deg = Math.asin(sinT) * 180 / Math.PI;
    const rx = PULLEY_X - 0.2;
    const ry = TABLE_TOP;
    const lx = rx - BOARD_LEN * cosT;
    const ly = ry + BOARD_LEN * sinT;

    // 桌面与桌腿:板低端坐在桌面边缘,桶从边外垂下去。
    // 两条读数摆在**两腿之间的空档** —— 摆在板以上会压住滑轮,摆在桌外会压住桶(设备截图各翻过一次)
    snap.segments.push(this.line(0.8, TABLE_TOP, rx, TABLE_TOP, C_TABLE, 5));
    snap.segments.push(this.line(1.1, TABLE_TOP, 1.1, GROUND_Y, C_TABLE, 3));
    snap.segments.push(this.line(rx - 0.25, TABLE_TOP, rx - 0.25, GROUND_Y, C_TABLE, 3));
    snap.segments.push(this.line(0.3, GROUND_Y, this.meta.worldWidth - 0.3, GROUND_Y, C_TABLE, 4));

    // 垫块:一层一块,叠在板的高端下面
    for (let i = 0; i < this.layers; i++) {
      const block = new BoxShape();
      block.cx = lx + 0.5;
      block.cy = TABLE_TOP + RISE_PER_LAYER * (i + 0.5);
      block.w = 0.9;
      block.h = RISE_PER_LAYER * 0.92;
      block.angleDeg = -deg;
      block.color = C_WEDGE;
      snap.boxes.push(block);
    }

    // 木板:高端靠左、低端靠滑轮
    snap.segments.push(this.line(lx, ly, rx, ry, C_BOARD, 9));

    // 打点计时器固定在高端,纸带从它下面穿过接到车上
    const timer = this.alongBoard(lx, ly, cosT, sinT, 0.28);
    const tBox = new BoxShape();
    tBox.cx = timer.x;
    tBox.cy = timer.y + CART_H * 0.5;
    tBox.w = 0.5;
    tBox.h = 0.3;
    tBox.angleDeg = -deg;
    tBox.color = C_TIMER;
    snap.boxes.push(tBox);
    snap.labels.push(this.text('打点计时器', timer.x - 0.25, timer.y + 0.62, 'left', 11));

    // 小车(上面摞着槽码,一只是 50 g)
    const cart = this.alongBoard(lx, ly, cosT, sinT, START_S + this.s);
    const body = new BoxShape();
    body.cx = cart.x;
    body.cy = cart.y + CART_H * 0.5;
    body.w = CART_W;
    body.h = CART_H;
    body.angleDeg = -deg;
    body.color = C_CART;
    snap.boxes.push(body);
    const wheelA = new CircleShape();
    wheelA.cx = cart.x - CART_W * 0.28;
    wheelA.cy = cart.y - CART_H * 0.16;
    wheelA.r = 0.09;
    wheelA.color = C_STRING;
    snap.circles.push(wheelA);
    const wheelB = new CircleShape();
    wheelB.cx = cart.x + CART_W * 0.28;
    wheelB.cy = cart.y - CART_H * 0.16;
    wheelB.r = 0.09;
    wheelB.color = C_STRING;
    snap.circles.push(wheelB);
    for (let i = 0; i < this.slots; i++) {
      const slot = new BoxShape();
      slot.cx = cart.x;
      slot.cy = cart.y + CART_H * 0.5 + 0.16 + i * 0.17;
      slot.w = 0.42;
      slot.h = 0.14;
      slot.angleDeg = -deg;
      slot.color = C_SLOT;
      snap.boxes.push(slot);
    }

    // 滑轮与绳:板上这段平行于板面,过了滑轮就竖直下垂
    const pulley = new CircleShape();
    pulley.cx = PULLEY_X;
    pulley.cy = PULLEY_Y;
    pulley.r = PULLEY_R;
    pulley.color = C_STRING;
    pulley.fill = FillStyle.OUTLINE;
    snap.circles.push(pulley);
    const front = this.alongBoard(lx, ly, cosT, sinT, START_S + this.s + CART_W * 0.5);
    snap.segments.push(this.line(front.x, front.y + CART_H * 0.35,
      PULLEY_X - PULLEY_R * 0.4, PULLEY_Y + PULLEY_R * 0.4, C_STRING, 1.4));
    const bucketCy = PULLEY_Y - PULLEY_R - HANG - this.s - BUCKET_H * 0.5;
    if (this.attached) {
      snap.segments.push(this.line(PULLEY_X, PULLEY_Y - PULLEY_R,
        PULLEY_X, bucketCy + BUCKET_H * 0.5, C_STRING, 1.4));
      const bucket = new BoxShape();
      bucket.cx = PULLEY_X;
      bucket.cy = bucketCy;
      bucket.w = BUCKET_W;
      bucket.h = BUCKET_H;
      bucket.color = C_BUCKET;
      bucket.fill = FillStyle.OUTLINE;
      snap.boxes.push(bucket);
      // 桶的标签摆在桶右边那一列:挪到左边就会和桌腿之间那两块读数撞上(截图量过)
      snap.labels.push(this.text('砝码桶 ×' + String(this.loads) +
        (this.ended ? '（已降到底）' : ''), PULLEY_X + 0.3, bucketCy, 'left', 11));
    } else {
      snap.labels.push(this.text('砝码桶已取下', PULLEY_X + 0.25, PULLEY_Y - 1.25, 'left', 11));
    }

    snap.labels.push(this.text('s=' + this.s.toFixed(2) + ' m  v=' + this.v.toFixed(2) + ' m/s',
      1.45, 1.6, 'left', 12));

    TapeStrip.paint(snap, this.tape, TAPE_X, TAPE_Y, this.startDot(), this.everyGap(),
      '纸带 · 点距按 ' + String(TAPE_SCALE) + ' 倍展开');
    return snap;
  }

  /** 沿板面走 distance 米处的板面点:以板高端为原点,朝滑轮为正 */
  private alongBoard(lx: number, ly: number, cosT: number, sinT: number, distance: number): BoardPoint {
    const point = new BoardPoint();
    point.x = lx + distance * cosT;
    point.y = ly - distance * sinT;
    return point;
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

  private cartKg(): number {
    return CART_MASS + this.slots * SLOT_MASS;
  }

  private pullKg(): number {
    return this.attached ? BUCKET_MASS + this.loads * LOAD_MASS : 0;
  }

  private sinT(): number {
    const rise = this.layers * RISE_PER_LAYER;
    return rise > BOARD_LEN ? 1 : rise / BOARD_LEN;
  }

  private cosT(): number {
    const g = this.sinT();
    return Math.sqrt(1 - g * g);
  }

  /** 逐差法:本条纸带上前后各三段。段数凑不满就是没量出来,给 NaN */
  private tapeAccel(): number {
    return this.tape.accelByChunking(this.startDot(), this.everyGap(), PER_HALF);
  }

  /**
   * 轻推检查的量法:用到的那几段计数段里,最长与最短差多少(毫米)。
   *
   * 窗口只取前面 2·PER_HALF+1 段,与逐差法用的是同一段纸 —— 车到头之后纸带走不动,
   * 末段本来就短,而末段落在这个窗口之外,所以不必再为它写特判。
   */
  private spreadOf(start: number, every: number): number {
    let segments = this.tape.segmentCount(start, every);
    if (segments > 2 * PER_HALF + 1) {
      segments = 2 * PER_HALF + 1;
    }
    if (segments < 2) {
      return Number.NaN;
    }
    let low = Number.POSITIVE_INFINITY;
    let high = Number.NEGATIVE_INFINITY;
    for (let i = 0; i + 1 < segments; i++) {
      const from = this.tape.dotAt(start + i * every);
      const to = this.tape.dotAt(start + (i + 1) * every);
      if (from === null || to === null) {
        continue;
      }
      const span = to.s - from.s;
      if (span < low) {
        low = span;
      }
      if (span > high) {
        high = span;
      }
    }
    if (!Number.isFinite(low) || !Number.isFinite(high)) {
      return Number.NaN;
    }
    return (high - low) * 1000;
  }

  /** 结清正在进行的这次检查 */
  private commitCheck(): void {
    if (!this.checking) {
      return;
    }
    this.spreads.push(this.spreadOf(this.startDot(), this.everyGap()));
    this.checking = false;
  }

  /** 已结案的,加上正在走的这一次:交卷时不必等到车停 */
  private checkList(): number[] {
    const list: number[] = [];
    for (let i = 0; i < this.spreads.length; i++) {
      list.push(this.spreads[i]);
    }
    if (this.checking) {
      list.push(this.spreadOf(this.startDot(), this.everyGap()));
    }
    return list;
  }

  private currentSpread(): number {
    const list = this.checkList();
    return list.length > 0 ? list[list.length - 1] : Number.NaN;
  }

  private usable(): NewtonTrial[] {
    const list: NewtonTrial[] = [];
    for (let i = 0; i < this.trials.length; i++) {
      if (Number.isFinite(this.trials[i].accel)) {
        list.push(this.trials[i]);
      }
    }
    return list;
  }

  /** 控制变量:byForce 数「同一质量下换过几档拉力」,否则数「同一拉力下试过几种质量」 */
  private stepCount(byForce: boolean): number {
    const usable = this.usable();
    let best = 0;
    for (let i = 0; i < usable.length; i++) {
      const fixed = this.keyOf(byForce ? usable[i].cartKg : usable[i].pullKg);
      const steps: string[] = [];
      for (let j = 0; j < usable.length; j++) {
        const held = this.keyOf(byForce ? usable[j].cartKg : usable[j].pullKg);
        if (held !== fixed) {
          continue;
        }
        const step = this.keyOf(byForce ? usable[j].pullKg : usable[j].cartKg);
        if (steps.indexOf(step) < 0) {
          steps.push(step);
        }
      }
      if (steps.length > best) {
        best = steps.length;
      }
    }
    return best;
  }

  /** 质量按克取整再比:0.049999 与 0.05 是同一档,不该被当成两档 */
  private keyOf(kg: number): string {
    return String(Math.round(kg * 1000));
  }

  /** 计数起点:学生选的起点与"头上那一段重叠点"取更靠后的那个 —— 量不到的段不进量窗 */
  private startDot(): number {
    const raw = this.readParam('countStart');
    const from = raw < 0 ? 0 : Math.floor(raw);
    const moving = this.tape.movingStart();
    return from > moving ? from : moving;
  }

  private everyGap(): number {
    const raw = this.readParam('countEvery');
    return raw < 1 ? 1 : Math.floor(raw);
  }

  private readParam(key: string): number {
    const value = this.getParam(key);
    return Number.isFinite(value) ? value : 0;
  }
}
