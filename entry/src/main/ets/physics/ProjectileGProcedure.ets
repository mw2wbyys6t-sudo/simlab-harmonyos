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
 *
 * 入参契约(Controller Ruling I,重要):gFromPoint 的 yMm 必须是**从槽口算起的真实下落**
 * (ProjectileRunner 的 TracedPoint.drop),不是标签上那个 y。描点时还没挂重垂线的那几个点,
 * 存的是板角基准下的坐标,拿它当 y 反求会得到 19.3 而不是 9.8 —— 那等于应用把错的基准
 * 供认成正确答案。基准这件事由标签自己说清(y=… 与 y(按板角)=…),由细则 pj-origin-late 扣分。
 *
 * id 空间:本文件两张表(g 题、段比题)各自独立编号,只在**同一格填空内**唯一,不跨题对齐;
 * id 0 是 AnswerCheck 留给"没命中"的,两张表都不占它,也不留空号。
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

  /**
   * g 那一格的错法:漏乘 2、单位错(×1000、÷1000)。
   *
   * 原表里的 2 号「把 x 当时间」已删除(Ruling G 的宽域扫描扫出来的)。它等于 2y/x²,
   * 也就是正确值的 1/v0² —— 扫描域铺到 slot 1..4 × card 1..8 之后,slot=1 那一档
   * v0² = 2·g·1·0.05 = 0.98 ≈ 1,于是它算出来是 10.00 而对正确值 9.8 只差 2.04%,
   * 落在判分容差 3% 之内:把横坐标当成时间的学生直接被判"算对了",这条指纹永远点不着名。
   * 规定动作是删掉它(宁可点不出"把 x 当时间",也不留一张会撒谎的表),编号随之收成连续的 1/2/3。
   *
   * 也不补 G3「板角基准的 g」:实测它在 slot=2/card=1(9.53 对 9.80,差 2.77%)与
   * slot=4/card=3(10.02 对 9.80,差 2.24%)上同样落进 3% 容差,同样是点不着名的那条。
   */
  static fingerprints(yMm: number, xMm: number, v0: number): Fingerprint[] {
    const correct = ProjectileGProcedure.gFromPoint(yMm, xMm, v0);
    if (!Number.isFinite(correct)) {
      return [];
    }
    const out: Fingerprint[] = [];
    out.push(of(1, correct / 2));
    out.push(of(2, correct * 1000));
    out.push(of(3, correct / 1000));
    return out;
  }

  /**
   * 竖直方向第二段与第一段位移之比。等水平间隔下,从抛出点数起应当是 1:3:5:7 → 3。
   *
   * 传进来的必须是**从槽口算起**的那套 y(TracedPoint.drop 化成的毫米):没定原点时这个比
   * 根本不是这个意思,而"没定原点"这件事由标签自己说明、由 pj-origin-late 那条去扣,
   * 不在这里重复判。
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
