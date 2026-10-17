import { Fingerprint } from './AnswerCheck';

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
 */
export class TapeChunkProcedure {
  /** 分子 = 后 h 段之和 减 前 h 段之和(毫米)。逐差法里"用上全部数据"的那一步 */
  static numerator(segMm: number[]): number {
    const h = half(segMm);
    if (h === 0) {
      return Number.NaN;
    }
    let sum = 0;
    for (let i = 0; i < h; i++) {
      sum += segMm[h + i] - segMm[i];
    }
    return sum;
  }

  /** 分母里 T² 的倍数。a = 分子 /(倍数 · T²),分母单独问一遍:漏乘平方是高频错 */
  static denFactor(segMm: number[]): number {
    const h = half(segMm);
    return h === 0 ? Number.NaN : h * h;
  }

  /** 分子的错法,顺序即 spec §5 那张表 */
  static fingerprints(segMm: number[]): Fingerprint[] {
    const h = half(segMm);
    if (h === 0) {
      return [];
    }
    const first = segMm[0];
    const last = segMm[2 * h - 1];
    const correct = TapeChunkProcedure.numerator(segMm);
    let paired = 0;
    for (let i = 0; i + 1 < 2 * h; i += 2) {
      paired += segMm[i + 1] - segMm[i];
    }
    const out: Fingerprint[] = [];
    out.push(of(1, last - first));
    out.push(of(2, (last - first) / (2 * h - 1)));
    out.push(of(3, paired));
    out.push(of(4, correct * 1000));
    out.push(of(5, correct / 1000));
    return out;
  }

  /** 分母那一格的错法:漏乘平方、只乘 h、拿总段数平方 */
  static denPrints(segMm: number[]): Fingerprint[] {
    const h = half(segMm);
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
