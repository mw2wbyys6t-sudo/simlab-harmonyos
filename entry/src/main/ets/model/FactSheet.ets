/**
 * 事实清单:判定层唯一允许读取的输入。
 *
 * 里面只放数字和时刻。之所以不允许放「学生想做什么」这类意图字段,
 * 是因为意图一旦被记进来,判定就从「读事实」退化成「读我们替他写的结论」。
 * 所有值都必须由世界层与账本层在操作过程中算出。
 *
 * 它住在 `model/` 而不是 `bench/`:世界层(`physics/`、`runner/`)要往里写,
 * 判定层从里读。原先定义在 `bench/Rubric.ets` 里,导致所有下游为了说一句话
 * 被迫 import 判分模块,目录级 `runner ↔ bench` 成环(架构审计 A1)。
 */
export class FactSheet {
  /** 命名事实 → 数值(体积 mL、长度 cm、比例 %、布尔量 0/1) */
  numbers: Map<string, number> = new Map();
  /** 命名事件 → 发生时刻(仿真秒)。负值表示该事件未发生 */
  moments: Map<string, number> = new Map();

  set(key: string, value: number): void {
    this.numbers.set(key, value);
  }

  num(key: string): number {
    const hit = this.numbers.get(key);
    return hit === undefined ? Number.NaN : hit;
  }

  mark(event: string, atSeconds: number): void {
    const existing = this.moments.get(event);
    // 同名事件取首次发生时刻:顺序考点关心的是「有没有先做」
    if (existing === undefined || atSeconds < existing) {
      this.moments.set(event, atSeconds);
    }
  }

  at(event: string): number {
    const hit = this.moments.get(event);
    return hit === undefined ? -1 : hit;
  }

  /** 合并另一份事实(装置子流程各自产出,最后汇总) */
  merge(other: FactSheet): void {
    other.numbers.forEach((value: number, key: string) => {
      this.numbers.set(key, value);
    });
    other.moments.forEach((value: number, key: string) => {
      this.mark(key, value);
    });
  }
}
