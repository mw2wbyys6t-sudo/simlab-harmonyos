import { Fingerprint } from './AnswerCheck';

function of(id: number, value: number): Fingerprint {
  const f = new Fingerprint();
  f.id = id;
  f.value = value;
  return f;
}

/**
 * 「探究平抛运动的特点」的数据处理层。
 *
 * y = g·x²/(2v0²) 反解出 g = 2·(y/x²)·v0²。这一步是这条实验的全部落点:它同时说明
 * 水平分运动匀速(x 与 t 成正比)与竖直分运动是自由落体(y 与 t² 成正比)。
 * 面板给的是 y/x² 的**离散度**,没给 g —— 学生必须自己把这三个量凑一次。
 */
export class ProjectileGProcedure {
  /** 由一个点反求 g。yMm、xMm 都是毫米,v0 米每秒 */
  static gFromPoint(yMm: number, xMm: number, v0: number): number {
    if (!(yMm > 0) || !(xMm > 0) || !(v0 > 0)) {
      return Number.NaN;
    }
    const y = yMm / 1000;
    const x = xMm / 1000;
    return 2 * (y / (x * x)) * v0 * v0;
  }

  /** G1 漏乘 2、G2 把 x 当时间、G4/G5 单位错。G3(板角坐标)由调用方喂错数据自然命中 */
  static fingerprints(yMm: number, xMm: number, v0: number): Fingerprint[] {
    const correct = ProjectileGProcedure.gFromPoint(yMm, xMm, v0);
    if (!Number.isFinite(correct)) {
      return [];
    }
    const y = yMm / 1000;
    const x = xMm / 1000;
    const out: Fingerprint[] = [];
    out.push(of(1, correct / 2));
    out.push(of(2, 2 * y / (x * x)));
    out.push(of(4, correct * 1000));
    out.push(of(5, correct / 1000));
    return out;
  }

  /**
   * 竖直方向第二段与第一段位移之比。等水平间隔下,从抛出点数起应当是 1:3:5:7 → 3。
   *
   * 传进来的必须是**已定原点**那套坐标下的 y:没定原点时这个比根本不是这个意思,
   * 那种情形由 g 那一格的 G3 去点名,不在这里重复判。
   */
  static segmentRatio(yMmFirstTwo: number[]): number {
    if (yMmFirstTwo.length < 2 || !(yMmFirstTwo[0] > 0)) {
      return Number.NaN;
    }
    const first = yMmFirstTwo[0];
    const second = yMmFirstTwo[1] - yMmFirstTwo[0];
    if (!(second > 0)) {
      return Number.NaN;
    }
    return second / first;
  }

  /** V1 拿两点总位移之比(y₂/y₁ = 4)、V2 以为每段翻倍 */
  static ratioFingerprints(yMmFirstTwo: number[]): Fingerprint[] {
    const correct = ProjectileGProcedure.segmentRatio(yMmFirstTwo);
    if (!Number.isFinite(correct)) {
      return [];
    }
    return [of(1, yMmFirstTwo[1] / yMmFirstTwo[0]), of(2, 2)];
  }
}
