import { SessionRecord } from '../model/SessionRecord';
import { FactSheet } from '../model/FactSheet';
import { CriterionBuilder, CriterionOp, Rubric } from './Rubric';
import { RubricBrine } from './RubricBrine';
import { RubricSpring } from './RubricSpring';
import { RubricOhm } from './RubricOhm';

/**
 * 量取参考细则。
 *
 * 刻意只有两条判据:「偏差」与「洒失」。
 *
 * 本来想再加一条「读数与实际不符(视差)」,但在「学生倒到自己以为到达目标为止」这个
 * 典型动作下,`readErrorMl` 与 `deviationMl` 是同一个错误的两面 —— 两条都判等于同一个
 * 错扣两次。不变量 R3 是宁漏不误,所以视差的数值只进**证据文本**,让学生看见原因,
 * 不单独扣分。
 */
export class RubricMeasure {
  static readonly ID: string = 'measure-pouring';

  static create(): Rubric {
    const rubric = new Rubric();
    rubric.id = RubricMeasure.ID;
    rubric.label = '用量筒量取指定体积的液体';
    // 括号与版本号都是给学生看的字:半角括号、内部代号 draft1 属于工程词外泄
    rubric.source = '参考细则（非官方标准）';
    rubric.version = '2026.09 第1版';
    rubric.totalPoints = 100;

    rubric.criteria.push(CriterionBuilder.numeric('M01', '量取偏差超出允许范围', CriterionOp.ABS_GT,
      'deviationMl', 0.5, 0, 70,
      '实际量取 {actualMl} mL，目标 {goalMl} mL，偏差 {deviationMl} mL；'
      + '自报读数 {readMl} mL，与实际的差 {readErrorMl} mL，说明视线未与凹液面齐平'));

    rubric.criteria.push(CriterionBuilder.numeric('M02', '倾倒过程洒失', CriterionOp.GT,
      'spilledMl', 1, 0, 30,
      '倾倒过程洒失 {spilledMl} mL，倒出仰角 {tiltDeg}°'));

    return rubric;
  }

  /**
   * 把记录里的原始观测变成判据可读的事实。
   *
   * 派生量(偏差、读数误差)在这里算,不进记录:记录只存观测,结论随时可重算。
   * 输入不齐时**不写**派生量,让判据按「事实缺失」放过而不是拿 NaN 去比。
   */
  static factsOf(record: SessionRecord): FactSheet {
    const sheet = new FactSheet();
    for (const item of record.facts) {
      sheet.set(item.key, item.value);
    }
    const goal = sheet.num('goalMl');
    const actual = sheet.num('actualMl');
    const read = sheet.num('readMl');
    if (RubricMeasure.isReal(goal) && RubricMeasure.isReal(actual)) {
      sheet.set('deviationMl', actual - goal);
    }
    if (RubricMeasure.isReal(read) && RubricMeasure.isReal(actual)) {
      sheet.set('readErrorMl', read - actual);
    }
    RubricMeasure.carryMoments(sheet, record);
    return sheet;
  }

  /**
   * 把记录里的时刻搬进事实清单。
   *
   * 报告页的「步骤时序」段读的就是它。不搬的话链路一切到量取就整段空掉,
   * 而判据一条都不会失败 —— 静默消失的字段正是最难发现的那类缺陷。
   */
  static carryMoments(sheet: FactSheet, record: SessionRecord): FactSheet {
    for (const item of record.moments) {
      sheet.mark(item.event, item.atSeconds);
    }
    return sheet;
  }

  private static isReal(value: number): boolean {
    return Number.isFinite(value);
  }
}

/**
 * 细则索引。
 *
 * 记录里只存 `rubricId`,分数不存:回看时按这份索引找回细则从事实**重算**。
 * 把分数存死,细则换版本后历史记录就和判据脱钩,违反不变量 I4。
 */
export class Rubrics {
  static byId(id: string): Rubric | null {
    if (id === RubricMeasure.ID) {
      return RubricMeasure.create();
    }
    if (id === RubricBrine.ID) {
      return RubricBrine.create();
    }
    if (id === RubricSpring.ID) {
      return RubricSpring.create();
    }
    if (id === RubricOhm.ID) {
      return RubricOhm.create();
    }
    return null;
  }

  /**
   * 按记录里的 rubricId 分发到对应的派生规则。
   *
   * 存在的理由:让报告页不必按细则写 if。认不出的细则只做原样搬运,
   * 绝不替它编派生量 —— 派生错了就会产出看起来合理但无依据的扣分。
   * 两条分支都搬时刻:搬运对任何细则都是原样复制,不算派生。
   */
  static factsFor(record: SessionRecord): FactSheet {
    if (record.rubricId === RubricMeasure.ID) {
      return RubricMeasure.factsOf(record);
    }
    const sheet = new FactSheet();
    for (const item of record.facts) {
      sheet.set(item.key, item.value);
    }
    return RubricMeasure.carryMoments(sheet, record);
  }
}
