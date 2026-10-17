/** 纸带上的一个点:打在什么时刻、小车走到哪儿 */
export class TapeDot {
  t: number = 0;
  s: number = 0;

  constructor(t: number, s: number) {
    this.t = t;
    this.s = s;
  }
}

/**
 * 打点计时器与它打出来的那条纸带。
 *
 * 三件事刻意分开,因为这个实验考的就是它们的先后与疏密:
 * ① 小车什么时候被放开(运动从这一刻开始);
 * ② 电源什么时候接通(**只有接通时才打点** —— 先放车后通电,纸带头一段就是空的);
 * ③ 学生把哪些点当计数点(舍掉开头过密的一段、每几个点取一个)。
 *
 * 点距按**真实比例**存(米),不做任何放大:纸带上"前面密得量不出、后面才开得开"
 * 正是这条实验要人看见的东西,把它归一化掉就等于把结论画成了答案。
 */
export class TickerTape {
  /** 交流电频率:50 Hz 是这台计时器的时钟,两点之间 0.02 s */
  readonly hz: number = 50;
  private dots: TapeDot[] = [];
  private nextAt: number = Number.NaN;
  private powered: boolean = false;
  private poweredAt: number = Number.NaN;
  private releasedAt: number = Number.NaN;

  reset(): void {
    this.dots = [];
    this.nextAt = Number.NaN;
    this.powered = false;
    this.poweredAt = Number.NaN;
    this.releasedAt = Number.NaN;
  }

  /** 接通(或断开)电源。第一次接通时记下时刻,并从那一刻起按 1/hz 打点 */
  setPower(on: boolean, t: number): void {
    if (!on) {
      this.powered = false;
      return;
    }
    if (this.powered) {
      return;
    }
    this.powered = true;
    this.poweredAt = t;
    this.nextAt = t;
  }

  release(t: number): void {
    if (!Number.isFinite(this.releasedAt)) {
      this.releasedAt = t;
    }
  }

  isPowered(): boolean {
    return this.powered;
  }

  isReleased(): boolean {
    return Number.isFinite(this.releasedAt);
  }

  /**
   * 世界每推进一格调用一次:t 是当前时刻,s 是当前位置,v 与 a 是该时刻的速度与加速度。
   *
   * 打点按**时刻**而不是按调用次数,所以倍速与掉帧都不影响点距;落点要回到该打点的
   * 那一瞬间:`s − v·Δ + ½a·Δ²`。只用 `s − v·Δ` 是不够的 —— 那一格里速度本身在变,
   * 用末速度回推会把第一个点推到起点之前(实测第一段与第二段的比从 3 变成 5.75),
   * 而这条实验要判的最短间距就是毫米级的。
   */
  tick(t: number, s: number, v: number, a: number): void {
    if (!this.powered) {
      return;
    }
    const period = 1 / this.hz;
    if (!Number.isFinite(this.nextAt)) {
      this.nextAt = t;
    }
    while (t + 1e-9 >= this.nextAt) {
      const back = t - this.nextAt;
      this.dots.push(new TapeDot(this.nextAt, s - v * back + 0.5 * a * back * back));
      this.nextAt += period;
      if (this.dots.length > 4000) {
        // 一次运行不可能打出这么多点;真到了这里就是哪里在空转
        break;
      }
    }
  }

  count(): number {
    return this.dots.length;
  }

  dotAt(index: number): TapeDot | null {
    if (index < 0 || index >= this.dots.length) {
      return null;
    }
    return this.dots[index];
  }

  /** 第 index 与 index+1 两个点之间的距离(米) */
  spacing(index: number): number {
    const a = this.dotAt(index);
    const b = this.dotAt(index + 1);
    if (a === null || b === null) {
      return Number.NaN;
    }
    return b.s - a.s;
  }

  /**
   * 第一对"真的分开了"的点之间隔多远(毫米)。
   *
   * 验证机械能守恒那条实验拿它当"初速度为零"的判据:50 Hz 下从静止起,第一格走的
   * 距离是 ½·g·0.02² ≈ 1.96 mm。明显大于这个数,说明计时器打下第一个点时重锤已经在下落 ——
   * 那一段的初动能不是零,后面 mgh 与 ½mv² 对不上就不该赖阻力。
   * 一个点都没分开时给 NaN:没量过的事不报数。
   */
  firstMovingGapMm(): number {
    for (let i = 0; i + 1 < this.dots.length; i++) {
      const gap = this.dots[i + 1].s - this.dots[i].s;
      if (gap > 0.0001) {
        return gap * 1000;
      }
    }
    return Number.NaN;
  }

  /**
   * 从第 start 个点起、每 every 个点取一个计数点,能量出几段。
   *
   * 逐差法至少要四段,三段就只能两两相减再平均 —— 那是这条实验明确不让做的做法。
   */
  segmentCount(start: number, every: number): number {
    const step = every < 1 ? 1 : every;
    const from = start < 0 ? 0 : start;
    if (this.dots.length <= from + step) {
      return 0;
    }
    return Math.floor((this.dots.length - from) / step);
  }

  /** 上面那些段里最短的一段(米)。一段都没有时给 NaN:没量过的事不报数 */
  shortestSegment(start: number, every: number): number {
    const step = every < 1 ? 1 : every;
    const segments = this.segmentCount(start, every);
    let best = Number.NaN;
    for (let i = 0; i < segments; i++) {
      const from = this.dotAt(start + i * step);
      const to = this.dotAt(start + (i + 1) * step);
      if (from === null || to === null) {
        continue;
      }
      const span = to.s - from.s;
      if (!Number.isFinite(best) || span < best) {
        best = span;
      }
    }
    return best;
  }

  /**
   * 每一计数段的长度(毫米)。逐差法要的是"这几段各多长",不是段数也不是最短那段。
   *
   * 给毫米而不是米:学生拿毫米刻度尺量出来的就是这个数,判他的数与判他量的数同一单位,
   * 中间不再有一次换算 —— 少一次换算就少一处"到底是谁错了"的扯皮。
   */
  segmentsMm(start: number, every: number): number[] {
    const step = every < 1 ? 1 : every;
    const from = start < 0 ? 0 : start;
    const out: number[] = [];
    const n = this.segmentCount(from, step);
    for (let i = 0; i < n; i++) {
      const here = this.dotAt(from + i * step);
      const next = this.dotAt(from + (i + 1) * step);
      if (here === null || next === null) {
        break;
      }
      out.push((next.s - here.s) * 1000);
    }
    return out;
  }

  /**
   * 逐差法求加速度:计数段切成前后两半,各 perHalf 段,用「后一半减前一半」还原 a。
   *
   * 恒加速度下每段位移是 x_i = v₀T + ½aT²(2i−1),前后两半相减时 v₀ 那一项整项抵消,
   * 剩下的正好是 a·T²·perHalf² —— 所以 a = (Σ后半 − Σ前半)/(perHalf²·T²)。
   * 这个写法把 2·perHalf 段**全部**用上了;相邻两段之差逐个平均只吃掉首尾两段,
   * 中间那些量出来的数其实没参与运算,正是教材明确不让做的做法。
   *
   * 段数凑不满 2·perHalf 时给 NaN:量不出来的东西不报数。
   */
  accelByChunking(start: number, every: number, perHalf: number): number {
    const step = every < 1 ? 1 : every;
    const half = perHalf < 1 ? 1 : perHalf;
    const from = start < 0 ? 0 : start;
    if (this.segmentCount(from, step) < 2 * half) {
      return Number.NaN;
    }
    let sum = 0;
    for (let i = 0; i < half; i++) {
      const early = this.dotAt(from + i * step);
      const late = this.dotAt(from + (i + half) * step);
      const earlyNext = this.dotAt(from + (i + 1) * step);
      const lateNext = this.dotAt(from + (i + half + 1) * step);
      if (early === null || late === null || earlyNext === null || lateNext === null) {
        return Number.NaN;
      }
      sum += (lateNext.s - late.s) - (earlyNext.s - early.s);
    }
    const t = step / this.hz;
    return sum / (half * half * t * t);
  }

  /**
   * 第一个"能当起点"的点:它之后那一段是真的分开了。
   *
   * 通电与放车之间只要隔上一秒(手指的速度),计时器就先把五十来个点打在原地。
   * 那一段用刻度尺量出来是 0,拿它去逐差会把一条匀速纸带读成"点距差 30 mm 不匀" ——
   * 实体实验室里学生的做法本来就是舍开头密着的一段,这里把同一个动作做成锚点。
   * 一整条都没分开时给点数:后面所有量法都会因此返回 NaN,而不是报一个 0。
   */
  movingStart(): number {
    for (let i = 0; i + 1 < this.dots.length; i++) {
      if (this.dots[i + 1].s - this.dots[i].s > 0.0001) {
        return i + 1;
      }
    }
    return this.dots.length;
  }

  /**
   * 先放车、后通电时,纸带头上少了几个点。
   *
   * 这是学生自己的动作顺序留下的后果:释放与接通之间那一段运动计时器压根没在打,
   * 而初速度为零的那一段恰恰是最该量的一段。
   */
  lostHeadDots(): number {
    if (!Number.isFinite(this.releasedAt) || !Number.isFinite(this.poweredAt)) {
      return 0;
    }
    const late = (this.poweredAt - this.releasedAt) * this.hz;
    return late > 0 ? Math.floor(late + 0.5) : 0;
  }

  /** 从第一个点到最后一个点,纸带上实际打出来的长度(米) */
  tapeLength(): number {
    const first = this.dotAt(0);
    const last = this.dotAt(this.dots.length - 1);
    if (first === null || last === null) {
      return 0;
    }
    return last.s - first.s;
  }
}
