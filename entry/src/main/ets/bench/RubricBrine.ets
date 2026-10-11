import { Calibration } from './Brine';
import { CriterionBuilder, CriterionOp, Rubric } from './Rubric';

/**
 * 粗盐提纯参考细则。
 *
 * 这是**自建参考判定**,不是任何教育考试院发布的标准 —— 报告首页必须把这一点显示出来,
 * 否则我们就是在拿自己编的分当权威。将来拿到真细则时,只替换本文件即可,
 * 判定层与世界层都不动(不变量 I4)。
 *
 * 每一条都只读事实数值,分值合计必须等于满分,否则 `RubricValidator` 直接拒绝。
 */
export class RubricBrine {
  static readonly ID: string = 'brine-purification';
  static readonly ID_DISSOLVE: string = 'dissolve';
  static readonly ID_FILTER: string = 'filter';
  static readonly ID_EVAPORATE: string = 'evaporate';

  static create(): Rubric {
    const rubric = new Rubric();
    rubric.id = RubricBrine.ID;
    rubric.label = '粗盐中难溶性杂质的去除';
    // 括号与版本号都是给学生看的字:半角括号、内部代号 draft1 属于工程词外泄
    rubric.source = '参考细则（非官方标准）';
    rubric.version = '2026.09 第1版';
    rubric.totalPoints = 100;

    rubric.criteria.push(CriterionBuilder.numeric('B01', '倾倒未用玻璃棒引流', CriterionOp.EQ,
      'rodUsed', 0, 0, 15,
      '未使用玻璃棒引流，倾倒过程溅失 {spilledMl} mL'));

    rubric.criteria.push(CriterionBuilder.numeric('B02', '漏斗内液面高过滤纸边缘', CriterionOp.GT,
      'paperOverRimCm', 0, 0, 20,
      '液面高过滤纸边缘 {value} cm，导致 {bypassedMl} mL 悬浊液未经滤纸直灌'));

    rubric.criteria.push(CriterionBuilder.numeric('B03', '滤液不合格澄清', CriterionOp.GT,
      'filtrateTurbidity', Calibration.TURBIDITY_PASS, 0, 20,
      '滤液浊度 {value} NTU，合格线 {threshold} NTU'));

    rubric.criteria.push(CriterionBuilder.numeric('B04', '蒸发时未用玻璃棒搅拌', CriterionOp.EQ,
      'evapStirred', 0, 0, 10,
      '蒸发过程未搅拌，液滴飞溅损失 NaCl {splashSaltG} g'));

    rubric.criteria.push(CriterionBuilder.numeric('B05', '液体洒落在桌面上', CriterionOp.GT,
      'spilledMl', 1.0, 0, 10,
      '累计洒失 {value} mL，超出允许范围 {threshold} mL'));

    rubric.criteria.push(CriterionBuilder.numeric('B06', '精盐产率异常', CriterionOp.OUT_OF,
      'yieldPct', 85, 105, 15,
      '回收产率 {value}%，应在 {threshold}~{threshold2}% 之间（回收 {saltRecoveredG} g / 投入 {saltAddedG} g）'));

    rubric.criteria.push(CriterionBuilder.sequence('B07', '未先溶解就过滤',
      RubricBrine.ID_DISSOLVE, RubricBrine.ID_FILTER, 5,
      '溶解完成于第 {value} s，过滤开始于第 {value2} s，顺序颠倒'));

    rubric.criteria.push(CriterionBuilder.sequence('B08', '未先过滤就蒸发',
      RubricBrine.ID_FILTER, RubricBrine.ID_EVAPORATE, 5,
      '过滤开始于第 {value} s，蒸发开始于第 {value2} s，顺序颠倒'));

    return rubric;
  }
}
