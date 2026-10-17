import { Fingerprint } from './AnswerCheck';

/**
 * 一段"真的量得出东西"的段长至少要这么多毫米。
 *
 * 与 TickerTape.movingStart() / firstMovingGapMm() 用的是同一条判据(0.0001 m):
 * 通电而未放车时计时器照样每 0.02 s 打一个点,点全叠在原地,刻度尺量出来是 0。
 */
const LIVE_MM: number = 0.1;

/** 参与运算的段数:前后两半各 h 段,凑不满 2h 段就出不了这道题 */
function half(segMm: number[]): number {
  const h = Math.floor(segMm.length / 2);
  return h < 2 ? 0 : h;
}

function of(id: number, value: number): Fingerprint {
  const f = new Fingerprint();
  f.id = id;
  f.value = value;
  return f;
}

/**
 * 「测匀变速直线运动的加速度」的数据处理层。
 *
 * 纯函数:进一串段长(毫米),出正确流程的答案与几种典型错法的答案。放 runner 里
 * 就测不到这么细,放细则里就等于让判分模块懂物理 —— 两头都不合适。
 *
 * 取窗与 TickerTape.accelByChunking 一致:用前 2h 段,尾巴上凑不满一对的那段丢掉。
 *
 * 入参契约(Controller Ruling H,重要):传进来的可以是 TickerTape.segmentsMm() 原样导出的
 * **全部**计数段,里面可能带着开头那段量不出来的死段。本模块**不假装死段存在** ——
 * 四个入口都先过 liveFrom(),舍掉死头、把尾部截到 2h 整再算。理由:场景自己的 summary
 * 与细则 tape-crowded-start 都告诉学生"舍开头密着的那一段",若应有值是按含死头的窗口
 * 算的,照做的人就会被判"算错"而且点不出任何错法(实测那条纸带:含死头 853.04、
 * 舍掉死头 562.35,差出来的 a 是 0.705 对 0.879)。调用点(Task 5)仍然应当直接从
 * tape.movingStart() 起取段 —— 那是更干净的那一半;这里兜住,是因为判错的代价在人那侧。
 *
 * id 空间:本文件两张表(F 分子题、D 分母题)各自独立编号,只在**同一格填空内**唯一,
 * 不跨题对齐 —— F2 是"相邻逐段平均",D2 是"分母只乘 h",两者没有任何关系。
 * id 为 0 是 AnswerCheck 保留给"没命中"的,两张表都不占用它;表里也不留空号。
 */
export class TapeChunkProcedure {
  /**
   * 取窗:舍掉开头量不出的死段,再把尾部截到 2h 整(凑不满一对的那段丢掉)。
   *
   * 单独开这个口有两个用处:Task 5 的调用点可以把它当作"应有值到底用了哪几段"的
   * 证据打出来;离线闸门可以拿它断言"喂进 procedure 的就是这个窗口"。
   * 整条纸带都没分开时给空数组 —— 分子随之为 NaN,AnswerCheck 判"这题没出",不扣分。
   */
  static liveFrom(segMm: number[]): number[] {
    let first = 0;
    while (first < segMm.length && !(segMm[first] > LIVE_MM)) {
      first++;
    }
    const usable = segMm.length - first;
    const pairs = Math.floor(usable / 2);
    const out: number[] = [];
    for (let i = 0; i < pairs * 2; i++) {
      out.push(segMm[first + i]);
    }
    return out;
  }

  /** 分子 = 后 h 段之和 减 前 h 段之和(毫米)。逐差法里"用上全部数据"的那一步 */
  static numerator(segMm: number[]): number {
    const win = TapeChunkProcedure.liveFrom(segMm);
    const h = half(win);
    if (h === 0) {
      return Number.NaN;
    }
    let sum = 0;
    for (let i = 0; i < h; i++) {
      sum += win[h + i] - win[i];
    }
    return sum;
  }

  /** 分母里 T² 的倍数。a = 分子 /(倍数 · T²),分母单独问一遍:漏乘平方是高频错 */
  static denFactor(segMm: number[]): number {
    const h = half(TapeChunkProcedure.liveFrom(segMm));
    return h === 0 ? Number.NaN : h * h;
  }

  /**
   * 分子的错法,顺序即 spec §5 那张表。
   *
   * 原表里的 5 号"单位错(缩小一千倍)"已删除(Ruling G 的宽域扫描扫出来的):它等于
   * 正确值/1000 = h²·aT²/1000,而 2 号"相邻逐段平均"等于 aT² —— 两者在 h² 接近 1000 的
   * 窗口上重合(实测 angle=17/every=1 与 angle=22/every=1 两类窗口,相差 0.42%,
   * 小于 AnswerCheck.MATCH_TOL 0.5%)。同池里两条指纹彼此的间距小于点名带宽时,
   * 填错了单位的那个学生会被点名成"你只做了相邻逐段平均" —— 指认一个他没犯过的错。
   * 规定动作是删掉撞车的那条:留 2 号(任务文本自己就点名了"相邻两段之差逐个平均"),
   * 删 5 号;单位错这一族仍有 4 号(×1000)在表里。
   */
  static fingerprints(segMm: number[]): Fingerprint[] {
    const win = TapeChunkProcedure.liveFrom(segMm);
    const h = half(win);
    if (h === 0) {
      return [];
    }
    const first = win[0];
    const last = win[2 * h - 1];
    const correct = TapeChunkProcedure.numerator(win);
    let paired = 0;
    for (let i = 0; i + 1 < 2 * h; i += 2) {
      paired += win[i + 1] - win[i];
    }
    const out: Fingerprint[] = [];
    out.push(of(1, last - first));
    out.push(of(2, (last - first) / (2 * h - 1)));
    out.push(of(3, paired));
    out.push(of(4, correct * 1000));
    return out;
  }

  /** 分母那一格的错法:漏乘平方、只乘 h、拿总段数平方 */
  static denPrints(segMm: number[]): Fingerprint[] {
    const h = half(TapeChunkProcedure.liveFrom(segMm));
    if (h === 0) {
      return [];
    }
    const out: Fingerprint[] = [];
    out.push(of(1, 1));
    out.push(of(2, h));
    out.push(of(3, 2 * h * 2 * h));
    return out;
  }
}
