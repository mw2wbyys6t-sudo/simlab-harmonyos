import { CriterionBuilder, CriterionOp, Rubric } from './Rubric';

/**
 * 「验证机械能守恒定律」参考细则(高中必修二,配场景 `free-fall`)。
 *
 * 只有三条,而且都读纸带本身:
 * ① 点够不够 —— 重锤下落不到半秒,点太少就配不出"一段高度 + 一段速度";
 * ② 第一对点的间距是不是约 2 mm —— 这是教材自己给的"初速度为零"判据,
 *    比任何口头说明都硬:50 Hz 下 ½·g·0.02² = 1.96 mm;
 * ③ 能切出几段 —— 这条实验要的是几段偏差的分布,单段比较说明不了什么。
 *
 * 没写进去的(判不了就不写,宁漏不误):
 * ΔEp 与 ΔEk 各算多少、相对偏差多大、为什么 ΔEk 总是略小 —— 这些要学生把量到的数
 * 交进来才能判(#61 学生填数入口),现在只能当读数摆在屏幕上;
 * 「不必用天平」这一条也没有可判的动作 —— 应用里压根没给天平。
 */
export class RubricEnergy {
  /** 这份细则配哪个场景注册表 id,由细则自己声明 —— 加实验时不用回来改一张总表的两处 */
  static readonly SCENE: string = 'free-fall';
  static readonly ID: string = 'free-fall-rubric';
  static readonly VERSION: string = '2026.10';

  static create(): Rubric {
    const rubric = new Rubric();
    rubric.id = RubricEnergy.ID;
    rubric.label = '验证机械能守恒定律 · 参考细则';
    rubric.source = '参考细则（非官方标准），依据人教版必修二「验证机械能守恒定律」课题的常见扣分点自建';
    rubric.version = RubricEnergy.VERSION;
    rubric.totalPoints = 100;

    // 标题与证据是直接印给学生看的,标点一律全角
    const fewDots = CriterionBuilder.numeric('energy-few-dots', '纸带上的点太少，配不出高度与速度的一对',
      CriterionOp.LT, 'tapeDotCount', 10, 0, 40,
      '纸带上共 {tapeDotCount} 个点：重锤落一米只用约半秒、计时器每 0.02 s 打一个点，点这么少说明它几乎没在工作');
    const notFromRest = CriterionBuilder.numeric('energy-not-from-rest', '第一个点打下时重锤已经在动，初速度不为零',
      CriterionOp.GT, 'tapeFirstGapMm', 2.6, 0, 30,
      '第一对点之间已经隔了 {tapeFirstGapMm} mm：从静止起这一格只该有约 2 mm，差这么多说明开头那段的初动能不是零，mgh 与 ½mv² 对不上不该赖阻力');
    const fewSegments = CriterionBuilder.numeric('energy-few-segments', '比较的段数太少，看不出偏差的分布',
      CriterionOp.LT, 'tapeSegments', 3, 0, 30,
      '按当前间隔只切出 {tapeSegments} 段：这条实验要的是几段各自的 ΔEp 与 ΔEk，单段比较说明不了 ΔEk 为什么总比 ΔEp 小一点');

    rubric.criteria.push(fewDots);
    rubric.criteria.push(notFromRest);
    rubric.criteria.push(fewSegments);
    return rubric;
  }
}
