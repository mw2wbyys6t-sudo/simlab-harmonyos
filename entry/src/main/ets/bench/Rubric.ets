/**
 * 事实清单:判定层唯一允许读取的输入。
 *
 * 里面只放数字和时刻。之所以不允许放「学生想做什么」这类意图字段,
 * 是因为意图一旦被记进来,判定就从「读事实」退化成「读我们替他写的结论」。
 * 所有值都必须由世界层与账本层在操作过程中算出。
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

/**
 * 判据类型。
 *
 * spec 里原本写「几何阈值 / 时序 / 数值范围」三原语,但几何阈值与数值范围
 * 在机械上是同一件事(拿一个数与阈值比),分开只会多出没有意义的分支。
 * 因此实现为两原语:NUMERIC 与 SEQUENCE。
 */
export enum CriterionKind {
  NUMERIC = 'numeric',
  SEQUENCE = 'sequence'
}

/** 比较算子。NUMERIC 用前五个,SEQUENCE 只用 BEFORE。 */
export enum CriterionOp {
  /** 值大于阈值即违规(如「浊度 > 20 NTU」) */
  GT = 'gt',
  /** 值小于阈值即违规(如「回收率 < 85%」) */
  LT = 'lt',
  /** |值| 大于阈值即违规(如「视线偏离液面 > 0.2 cm」) */
  ABS_GT = 'absGt',
  /** 值落在 [threshold, threshold2] 之外即违规(如「加水量 3~5 mL」) */
  OUT_OF = 'outOf',
  /** 值等于 threshold 即违规(把布尔量当 0/1 用,如「未引流」= eq 0) */
  EQ = 'eq',
  /** metric 必须早于 metric2 */
  BEFORE = 'before'
}

export class Criterion {
  id: string = '';
  /** 扣分点名称,直接呈现给学生 */
  title: string = '';
  kind: CriterionKind = CriterionKind.NUMERIC;
  op: CriterionOp = CriterionOp.GT;
  /** 事实名 */
  metric: string = '';
  /** SEQUENCE 的后继事件;其余类型忽略 */
  metric2: string = '';
  threshold: number = 0;
  threshold2: number = 0;
  points: number = 0;
  /** 证据模板,{value} 与 {threshold} 会被替换成实际数值 */
  evidence: string = '';
}

export class Rubric {
  id: string = '';
  label: string = '';
  /** 判据来源。自建的必须写「参考细则(非官方标准)」,不得留空或含糊 */
  source: string = '';
  version: string = '';
  totalPoints: number = 100;
  criteria: Criterion[] = [];
}

export class CriterionBuilder {
  static numeric(id: string, title: string, op: CriterionOp, metric: string, threshold: number,
    threshold2: number, points: number, evidence: string): Criterion {
    const item = new Criterion();
    item.id = id;
    item.title = title;
    item.kind = CriterionKind.NUMERIC;
    item.op = op;
    item.metric = metric;
    item.threshold = threshold;
    item.threshold2 = threshold2;
    item.points = points;
    item.evidence = evidence;
    return item;
  }

  static sequence(id: string, title: string, metric: string, metric2: string, points: number,
    evidence: string): Criterion {
    const item = new Criterion();
    item.id = id;
    item.title = title;
    item.kind = CriterionKind.SEQUENCE;
    item.op = CriterionOp.BEFORE;
    item.metric = metric;
    item.metric2 = metric2;
    item.points = points;
    item.evidence = evidence;
    return item;
  }
}

/**
 * 细则自检。细则是本系统唯一真正的外部输入边界,必须在加载时就校验干净 ——
 * 分值不守恒或算子写错,会让整份报告不可信,而这种错误靠肉眼看数据表很难发现。
 */
export class RubricValidator {
  static validate(rubric: Rubric): string[] {
    const issues: string[] = [];
    if (rubric.id.length === 0 || rubric.label.length === 0) {
      issues.push('细则缺少 id 或名称');
    }
    if (rubric.source.length === 0) {
      issues.push('细则必须声明判据来源(自建的写「参考细则(非官方标准)」)');
    }
    if (rubric.version.length === 0) {
      issues.push('细则必须带版本号，否则报告无法复现');
    }
    if (rubric.criteria.length === 0) {
      issues.push('细则没有任何判据');
    }

    const seen: Map<string, boolean> = new Map();
    let sum = 0;
    for (let i = 0; i < rubric.criteria.length; i++) {
      const item = rubric.criteria[i];
      if (seen.has(item.id)) {
        issues.push('判据 id 重复：' + item.id);
      }
      seen.set(item.id, true);
      if (item.title.length === 0) {
        issues.push(item.id + ' 缺少名称');
      }
      if (item.metric.length === 0) {
        issues.push(item.id + ' 未指定事实名');
      }
      if (item.kind === CriterionKind.SEQUENCE && item.metric2.length === 0) {
        issues.push(item.id + ' 时序判据缺少后继事件');
      }
      if (item.op === CriterionOp.OUT_OF && item.threshold2 <= item.threshold) {
        issues.push(item.id + ' 区间上限不大于下限');
      }
      if (item.points <= 0) {
        issues.push(item.id + ' 分值必须为正');
      }
      if (item.evidence.length === 0) {
        issues.push(item.id + ' 缺少证据模板 —— 没有证据的扣分不能出现在报告里');
      }
      sum += item.points;
    }
    if (Math.abs(sum - rubric.totalPoints) > 1e-9) {
      issues.push('判据分值合计 ' + sum + ' ≠ 满分 ' + rubric.totalPoints);
    }
    return issues;
  }
}
