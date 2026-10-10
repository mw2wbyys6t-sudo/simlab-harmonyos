import { Formula, ParsedFormula } from './Formula';

/** 物质在常温常压下的存在形态。水溶液单独一档,因为反应判定要看离子。 */
export enum Phase {
  SOLID = 'solid',
  LIQUID = 'liquid',
  GAS = 'gas',
  AQUEOUS = 'aqueous'
}

/** 反应类型。决定现象侧重与教学归类。 */
export enum ReactionType {
  DECOMPOSITION = 'decomposition',
  COMBINATION = 'combination',
  DISPLACEMENT = 'displacement',
  METATHESIS = 'metathesis',
  NEUTRALIZATION = 'neutralization',
  REDOX = 'redox',
  COMBUSTION = 'combustion',
  ESTERIFICATION = 'esterification',
  TITRATION = 'titration'
}

export class Substance {
  key: string = '';
  name: string = '';
  /** 化学式,式量由它算出,数据里不手写 */
  formula: string = '';
  phase: Phase = Phase.SOLID;
  /** 中文颜色描述,与教材用语一致(如「蓝色絮状沉淀」由现象负责,这里只记本体颜色) */
  color: string = '';
  /** 是否可溶(仅对固体/液体有意义,复分解判定的输入) */
  soluble: boolean = false;
  /** 危险性或取用注意事项 */
  hazard: string = '';

  molarMass(): number {
    return Formula.relativeMass(this.formula);
  }
}

/** 方程式中的一项:物质 × 系数 */
export class Term {
  substance: Substance = new Substance();
  coefficient: number = 1;
  /** 生成物标注:气体↑ 或 沉淀↓。必须由数据显式声明,引擎不猜 */
  marker: string = '';
}

export class ReactionSpec {
  id: string = '';
  title: string = '';
  type: ReactionType = ReactionType.COMBINATION;
  /** 学段标签:初中 / 高中 / 大学 */
  band: string = '';
  reactants: Term[] = [];
  products: Term[] = [];
  /** 反应条件,如「加热」「MnO₂ 作催化剂」「点燃」。空表示常温即可进行。仅用于显示 */
  conditions: string[] = [];
  /** 上面这些条件的机器可读形式:实验台据此判断此刻是否满足反应条件 */
  needsHeat: boolean = false;
  needsPower: boolean = false;
  /** 催化剂(参与反应但不被消耗),实验台要求容器中确有该试剂才放行 */
  catalystKeys: string[] = [];
  /**
   * 能否在「药品柜 + 容器 + 酒精灯」这套桌面器材里完成。
   * 需要通风橱、滴定管、电解槽或铂铑催化剂的反应标 false,
   * 只进速查表不进实验台 —— 否则学生随便倒一倒就「做出来」一个现实中做不成的实验。
   */
  benchReady: boolean = false;
  /** 可逆反应:平衡体系,不按完全反应计算 */
  reversible: boolean = false;
  /** 现象,按观察顺序书写,供界面逐条呈现 */
  phenomena: string[] = [];
  /** 离子方程式(仅溶液中的复分解/氧化还原需要),同样受守恒校验约束 */
  ionic: ReactionSpec | null = null;
  /** 实验注意事项与安全提示 */
  safety: string[] = [];

  private static sumMass(terms: Term[]): number {
    let sum = 0;
    for (let i = 0; i < terms.length; i++) {
      sum += terms[i].coefficient * terms[i].substance.molarMass();
    }
    return sum;
  }

  /** 反应物总式量,用于按质量配比的限量计算 */
  reactantMass(): number {
    return ReactionSpec.sumMass(this.reactants);
  }

  productMass(): number {
    return ReactionSpec.sumMass(this.products);
  }
}

/** 方程式的可读文本。界面与报告页共用,避免两处拼法不一致。 */
export class ReactionText {
  static equation(spec: ReactionSpec): string {
    const left = ReactionText.side(spec.reactants);
    const right = ReactionText.side(spec.products);
    let arrow = spec.reversible ? ' ⇌ ' : ' → ';
    if (spec.conditions.length > 0) {
      arrow = spec.reversible ? ' ⇌(' + spec.conditions.join('、') + ') '
        : ' →(' + spec.conditions.join('、') + ') ';
    }
    return left + arrow + right;
  }

  private static side(terms: Term[]): string {
    const parts: string[] = [];
    for (let i = 0; i < terms.length; i++) {
      const term = terms[i];
      const count = term.coefficient === 1 ? '' : term.coefficient.toString();
      parts.push(count + term.substance.formula + term.marker);
    }
    return parts.join(' + ');
  }
}

/** 条件词表:决定实验台是否需要提供热源/电源,也用于拦下拼错的条件。 */
export class ConditionTokens {
  /** 需要加热的条件 */
  static readonly HEAT: string[] = ['加热', '高温', '点燃'];
  /** 需要电源的条件 */
  static readonly POWER: string[] = ['通直流电'];
  /**
   * 不影响放行条件的条件项:属于「另加试剂」或「操作方式」,
   * 由催化剂或步骤层单独表达。列全是为了让拼错的条件词在这里报错,
   * 而不是被静默当成「无条件」常温放行。
   */
  static readonly NEUTRAL: string[] = ['硫酸酸化', '滴定', '催化剂', '指示剂'];

  static needsHeat(conditions: string[]): boolean {
    return ConditionTokens.containsAny(conditions, ConditionTokens.HEAT);
  }

  static needsPower(conditions: string[]): boolean {
    return ConditionTokens.containsAny(conditions, ConditionTokens.POWER);
  }

  /** 返回无法识别的条件词;空数组表示全部有条件兜底 */
  static unknown(conditions: string[]): string[] {
    const bad: string[] = [];
    for (let i = 0; i < conditions.length; i++) {
      const text = conditions[i];
      if (ConditionTokens.HEAT.includes(text) || ConditionTokens.POWER.includes(text)) {
        continue;
      }
      if (ConditionTokens.isNeutral(text)) {
        continue;
      }
      bad.push(text);
    }
    return bad;
  }

  private static isNeutral(text: string): boolean {
    for (let i = 0; i < ConditionTokens.NEUTRAL.length; i++) {
      if (text.includes(ConditionTokens.NEUTRAL[i])) {
        return true;
      }
    }
    return false;
  }

  private static containsAny(conditions: string[], tokens: string[]): boolean {
    for (let i = 0; i < conditions.length; i++) {
      if (tokens.includes(conditions[i])) {
        return true;
      }
    }
    return false;
  }
}

/** 校验结论:哪一侧、哪个元素、差多少。 */
export class ConservationIssue {
  reactionId: string = '';
  side: string = '';
  detail: string = '';
}

/**
 * 反应表的自我校验。
 *
 * 「足够真实」在化学里的第一道底线是方程式本身配平正确。人工录入几十条方程式
 * 必然出现漏配、抄错系数、电荷不平的情况,而这类错误靠眼睛查不完,也最容易
 * 被学生当成正确答案学走。所以这里把每条反应都跑一遍:
 * 元素种类与原子个数两侧相等、总质量相等、离子反应电荷相等、化学式可解析。
 * 任何一条不过,数据就不允许注册进来。
 */
export class ReactionValidator {
  static check(reaction: ReactionSpec): ConservationIssue[] {
    const issues: ConservationIssue[] = [];
    ReactionValidator.checkSide(reaction, reaction.reactants, '左', issues);
    ReactionValidator.checkSide(reaction, reaction.products, '右', issues);

    const left = ReactionValidator.elementTotals(reaction.reactants);
    const right = ReactionValidator.elementTotals(reaction.products);
    left.forEach((count: number, symbol: string) => {
      const hit = right.get(symbol);
      if (hit === undefined) {
        issues.push(ReactionValidator.issue(reaction.id, '元素', symbol + ' 只在左侧出现'));
      } else if (hit !== count) {
        issues.push(ReactionValidator.issue(reaction.id, '元素',
          symbol + ' 左 ' + count + ' ≠ 右 ' + hit));
      }
    });
    right.forEach((count: number, symbol: string) => {
      if (!left.has(symbol)) {
        issues.push(ReactionValidator.issue(reaction.id, '元素', symbol + ' 只在右侧出现'));
      }
    });

    const massLeft = reaction.reactantMass();
    const massRight = reaction.productMass();
    if (Math.abs(massLeft - massRight) > 0.05) {
      issues.push(ReactionValidator.issue(reaction.id, '质量',
        massLeft.toFixed(2) + ' ≠ ' + massRight.toFixed(2)));
    }

    const chargeLeft = ReactionValidator.chargeTotal(reaction.reactants);
    const chargeRight = ReactionValidator.chargeTotal(reaction.products);
    if (chargeLeft !== chargeRight) {
      issues.push(ReactionValidator.issue(reaction.id, '电荷',
        chargeLeft + ' ≠ ' + chargeRight));
    }

    // 条件词认不出来就会被当成「常温即可」,等于悄悄放行一个现实中需要加热的反应
    const unknownConditions = ConditionTokens.unknown(reaction.conditions);
    for (let i = 0; i < unknownConditions.length; i++) {
      issues.push(ReactionValidator.issue(reaction.id, '条件',
        '无法识别的反应条件「' + unknownConditions[i] + '」'));
    }
    for (let i = 0; i < reaction.catalystKeys.length; i++) {
      if (reaction.catalystKeys[i].length === 0) {
        issues.push(ReactionValidator.issue(reaction.id, '催化剂', '键名不能为空'));
      }
    }

    if (reaction.ionic !== null) {
      const nested = ReactionValidator.check(reaction.ionic);
      for (let i = 0; i < nested.length; i++) {
        issues.push(ReactionValidator.issue(reaction.id, '离子式', nested[i].detail));
      }
      // 离子方程式必须与化学方程式描述同一个净变化:比对两边元素总量差
      ReactionValidator.checkIonicConsistency(reaction, issues);
    }
    return issues;
  }

  private static checkSide(reaction: ReactionSpec, terms: Term[], side: string,
    issues: ConservationIssue[]): void {
    if (terms.length === 0) {
      issues.push(ReactionValidator.issue(reaction.id, side, '项为空'));
      return;
    }
    for (let i = 0; i < terms.length; i++) {
      const term = terms[i];
      const parsed = Formula.parse(term.substance.formula);
      if (parsed.error.length > 0) {
        issues.push(ReactionValidator.issue(reaction.id, side,
          term.substance.formula + ' ' + parsed.error));
      }
      if (!Number.isFinite(term.substance.molarMass())) {
        issues.push(ReactionValidator.issue(reaction.id, side,
          term.substance.formula + ' 式量算不出'));
      }
      if (term.coefficient <= 0) {
        issues.push(ReactionValidator.issue(reaction.id, side,
          term.substance.formula + ' 系数必须为正'));
      }
    }
  }

  /**
   * 离子方程式必须与化学方程式描述同一个净变化:对离子式里出现的每种元素,
   * 「离子式左右之差」应当等于「化学式左右之差」。
   * 改写时多删或漏删旁观离子都会在这里立刻露出来。
   */
  private static checkIonicConsistency(reaction: ReactionSpec, issues: ConservationIssue[]): void {
    const ionic = reaction.ionic;
    if (ionic === null) {
      return;
    }
    const molecularLeft = ReactionValidator.elementTotals(reaction.reactants);
    const molecularRight = ReactionValidator.elementTotals(reaction.products);
    const ionicLeft = ReactionValidator.elementTotals(ionic.reactants);
    const ionicRight = ReactionValidator.elementTotals(ionic.products);

    ionicLeft.forEach((count: number, symbol: string) => {
      const ionicNet = count - ReactionValidator.valueOf(ionicRight, symbol);
      const molecularNet = ReactionValidator.valueOf(molecularLeft, symbol)
        - ReactionValidator.valueOf(molecularRight, symbol);
      if (ionicNet !== molecularNet) {
        issues.push(ReactionValidator.issue(reaction.id, '离子式',
          symbol + ' 净变化 ' + ionicNet + ' ≠ 化学式的 ' + molecularNet));
      }
    });
  }

  private static valueOf(counts: Map<string, number>, symbol: string): number {
    const hit = counts.get(symbol);
    return hit === undefined ? 0 : hit;
  }

  private static elementTotals(terms: Term[]): Map<string, number> {
    const totals: Map<string, number> = new Map();
    for (let i = 0; i < terms.length; i++) {
      const parsed: ParsedFormula = Formula.parse(terms[i].substance.formula);
      parsed.counts.forEach((count: number, symbol: string) => {
        const hit = totals.get(symbol);
        totals.set(symbol, (hit === undefined ? 0 : hit) + count * terms[i].coefficient);
      });
    }
    return totals;
  }

  private static chargeTotal(terms: Term[]): number {
    let sum = 0;
    for (let i = 0; i < terms.length; i++) {
      sum += Formula.parse(terms[i].substance.formula).charge * terms[i].coefficient;
    }
    return sum;
  }

  private static issue(id: string, side: string, detail: string): ConservationIssue {
    const item = new ConservationIssue();
    item.reactionId = id;
    item.side = side;
    item.detail = detail;
    return item;
  }
}
