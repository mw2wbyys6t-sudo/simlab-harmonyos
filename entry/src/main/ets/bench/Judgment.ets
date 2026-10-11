import { Criterion, CriterionKind, CriterionOp, FactSheet, Rubric, RubricValidator } from './Rubric';

/** 一条扣分。evidence 必须可复算:学生/家长/老师看得懂数字从哪来。 */
export class Deduction {
  criterionId: string = '';
  title: string = '';
  points: number = 0;
  /** 事实名,便于申诉时回查 */
  metric: string = '';
  value: number = Number.NaN;
  evidence: string = '';
}

export class ScoreCard {
  rubricId: string = '';
  rubricVersion: string = '';
  /** 判据来源原样带出,报告首页必须显示 —— 参考细则不得伪装成官方标准 */
  rubricSource: string = '';
  total: number = 0;
  awarded: number = 0;
  deductions: Deduction[] = [];
  /** 判定时用到的全部事实,供申诉与复算 */
  facts: FactSheet = new FactSheet();

  summaryLine(): string {
    // 来源与版本必须露出(R1:参考细则不得伪装成官方标准),但不再括号套括号。
    // 分数是整数就不印小数位:「30.0 分」会被读成一个量出来的数
    const awarded = Number.isInteger(this.awarded) ? String(this.awarded) : this.awarded.toFixed(1);
    return '得分 ' + awarded + ' / ' + this.total.toFixed(0)
      + ' · 评分依据：' + this.rubricSource + ' · 版本 ' + this.rubricVersion;
  }
}

/**
 * 判定层。把事实清单与细则逐条比对,产出分数与可复算证据。
 *
 * 两条铁律:
 * 1. **拿不到事实就不扣分**。缺失的事实(NaN 或未发生的事件)一律放过 ——
 *    误判比漏判破坏性大得多,一次误判就会让家长整份报告都不信。
 * 2. **不读意图,只读数值**。判据里没有「学生是否想搅拌」这种项,
 *    只有搅拌了没有、溅了多少、浊度多少。
 */
export class Judgment {
  static score(rubric: Rubric, facts: FactSheet): ScoreCard {
    const problems = RubricValidator.validate(rubric);
    if (problems.length > 0) {
      throw new Error('细则不合法：' + problems.join(';'));
    }
    const card = new ScoreCard();
    card.rubricId = rubric.id;
    card.rubricVersion = rubric.version;
    card.rubricSource = rubric.source;
    card.total = rubric.totalPoints;
    card.awarded = rubric.totalPoints;
    card.facts = facts;

    for (let i = 0; i < rubric.criteria.length; i++) {
      const criterion = rubric.criteria[i];
      const hit = Judgment.judge(criterion, facts);
      if (hit === null) {
        continue;
      }
      card.deductions.push(hit);
      card.awarded -= hit.points;
    }
    if (card.awarded < 0) {
      card.awarded = 0;
    }
    return card;
  }

  /** 返回 null 表示不违规或因事实缺失而放过 */
  private static judge(criterion: Criterion, facts: FactSheet): Deduction | null {
    if (criterion.kind === CriterionKind.SEQUENCE) {
      const first = facts.at(criterion.metric);
      const second = facts.at(criterion.metric2);
      if (first < 0 || second < 0) {
        return null;
      }
      if (first <= second) {
        return null;
      }
      // 时序判据:违规值取后继事件时刻,{value}=先发生者、{value2}=后发生者
      return Judgment.of(criterion, second, Judgment.fill(criterion, facts, first, second));
    }

    const value = facts.num(criterion.metric);
    if (!Number.isFinite(value)) {
      return null;
    }
    let violated = false;
    switch (criterion.op) {
      case CriterionOp.GT:
        violated = value > criterion.threshold;
        break;
      case CriterionOp.LT:
        violated = value < criterion.threshold;
        break;
      case CriterionOp.ABS_GT:
        violated = Math.abs(value) > criterion.threshold;
        break;
      case CriterionOp.OUT_OF:
        violated = value < criterion.threshold || value > criterion.threshold2;
        break;
      case CriterionOp.EQ:
        violated = Math.abs(value - criterion.threshold) < 1e-9;
        break;
      default:
        // 未实现的算子一律放过并显式抛错:静默按「合格」处理会把细则写错变成偷偷不扣分
        throw new Error('判据 ' + criterion.id + ' 用了判定层不支持的算子');
    }
    if (!violated) {
      return null;
    }
    return Judgment.of(criterion, value, Judgment.fill(criterion, facts, value, 0));
  }

  private static of(criterion: Criterion, value: number, evidence: string): Deduction {
    const item = new Deduction();
    item.criterionId = criterion.id;
    item.title = criterion.title;
    item.points = criterion.points;
    item.metric = criterion.metric;
    item.value = value;
    item.evidence = evidence;
    return item;
  }

  /**
   * 证据模板填充:`{value}` `{threshold}` `{threshold2}` 之外,任何事实名都可以直接引用,
   * 如「漫过 {bypassedMl} mL 未经滤纸」—— 一条扣分的证据往往要同时给出几个数,
   * 只允许报被判定那个数的话,学生看不出自己错在哪。
   *
   * 用 split/join 而不是正则:判定层的模板替换不该依赖正则引擎的行为差异。
   */
  private static fill(criterion: Criterion, facts: FactSheet, value: number,
    second: number): string {
    let out = criterion.evidence.split('{value}').join(Judgment.text(value));
    out = out.split('{threshold}').join(Judgment.text(criterion.threshold));
    out = out.split('{threshold2}').join(Judgment.text(criterion.threshold2));
    out = out.split('{value2}').join(Judgment.text(second));
    facts.numbers.forEach((factValue: number, key: string) => {
      out = out.split('{' + key + '}').join(Judgment.text(factValue));
    });
    // 剩下的花括号只可能是「这条事实压根没被算出来」。留给学生看就是仪器在报告里漏模板,
    // 一律换成破折号 —— 与上面 text() 对 NaN 的处理同一种说法。
    return Judgment.scrub(out);
  }

  /** 把没被填掉的 {xxx} 换成破折号。不用正则:fill 的替换行为要能被离线断言逐字算出来 */
  private static scrub(text: string): string {
    let out = '';
    let i = 0;
    while (i < text.length) {
      const open = text.indexOf('{', i);
      if (open < 0) {
        out += text.slice(i);
        return out;
      }
      out += text.slice(i, open);
      const close = text.indexOf('}', open + 1);
      if (close < 0) {
        // 落单的花括号按普通字符保留,不当占位符处理
        out += text.slice(open);
        return out;
      }
      out += '—';
      i = close + 1;
    }
    return out;
  }

  private static text(value: number): string {
    if (!Number.isFinite(value)) {
      return '—';
    }
    // 整数一律原样印:挡数、步数、「是否超限度」这类计数与布尔事实印成 1.00 挡,
    // 学生会以为那是个量出来的数。
    if (Number.isInteger(value)) {
      return String(value);
    }
    const rounded = Math.abs(value) >= 100 ? value.toFixed(0) : value.toFixed(2);
    return rounded;
  }
}
