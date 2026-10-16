import { CriterionBuilder, CriterionOp, Rubric } from './Rubric';

/**
 * 「探究平抛运动的特点」参考细则(高中必修二,配场景 `projectile-frame`)。
 *
 * 这条实验的手上功夫是"摆卡片 + 同一高度释放",所以四条判据读的是这两下留下的后果:
 * ① 描了几个点(两三个点连不成轨迹);② 有没有先挂重垂线定原点(在那之前描下的点,
 * 坐标是按板角量的,拿去检验 y 与 x² 成正比必然对不上);③ 这些点用的释放位置是不是同一格
 * (差一格,槽口速度就变了,几个点根本不在同一条抛物线上);④ 卡片摆的位置是不是大致等间隔
 * (只有水平等间隔才等于等时间间隔,竖直方向 1:3:5 那条才量得出来)。
 *
 * 为什么没有"y 与 x² 成正比"这一条判据:定过原点、释放位置又一致时,这个比值本来就恒定 ——
 * 它只能被 ②③ 带着走,拿它当判据就是留一条永远跟着别人响的判据。所以它只当读数摆在面板上,
 * 让学生自己拿它去检验。算 v0、由 y=½gt² 反求 g 与本地值比较、说明槽面要不要光滑 ——
 * 这些要学生把数交进来才判得了(#61 学生填数入口),现在一律不写进细则:宁漏不误。
 *
 * 分值做成**能被满足的**:先挂重垂线,再固定第 2 格释放、卡片依次摆第 2/4/6/8 格各放一次,
 * 一分不扣(harness 里有这条断言)。
 */
export class RubricProjectile {
  /** 这份细则配哪个场景注册表 id,由细则自己声明 */
  static readonly SCENE: string = 'projectile-frame';
  static readonly ID: string = 'projectile-frame-rubric';
  static readonly VERSION: string = '2026.10';

  static create(): Rubric {
    const rubric = new Rubric();
    rubric.id = RubricProjectile.ID;
    rubric.label = '探究平抛运动的特点 · 参考细则';
    rubric.source = '参考细则（非官方标准），依据人教版必修二「探究平抛运动的特点」课题的常见扣分点自建';
    rubric.version = RubricProjectile.VERSION;
    rubric.totalPoints = 100;

    // 标题与证据是直接印给学生看的，标点一律全角
    const fewPoints = CriterionBuilder.numeric('pj-few-points', '描下的点太少，连不成一条轨迹',
      CriterionOp.LT, 'pjPointCount', 4, 0, 25,
      '纸上一共 {pjPointCount} 个点：两三个点既能连成抛物线也能连成圆弧，分不出竖直方向到底是自由落体还是别的什么');
    const originLate = CriterionBuilder.numeric('pj-origin-late', '挂重垂线之前就描了点，坐标没有基准',
      CriterionOp.GT, 'pjEarlyMarks', 0, 0, 25,
      '有 {pjEarlyMarks} 个点是在挂重垂线、标定抛出点之前描下的：那几个点的横纵坐标是按木板角量的，抛出点并不在那里，拿去检验 y 与 x² 成正比必然对不上');
    const mixedLaunch = CriterionBuilder.numeric('pj-mixed-launch', '几次释放不在同一高度，这些点不在同一条抛物线上',
      CriterionOp.GT, 'pjSlotSpread', 0, 0, 25,
      '描这些点用过的释放位置最大差了 {pjSlotSpread} 格：槽口速度只由释放高度决定，高度一变每条轨迹就跟着变，几个点连起来就不再是一条曲线');
    const unevenX = CriterionBuilder.numeric('pj-uneven-x', '卡片摆得忽近忽远，等时间间隔这条前提就没了',
      CriterionOp.GT, 'pjXGapRatio', 2, 0, 25,
      '相邻两点的水平间隔最大是最小的 {pjXGapRatio} 倍：水平等间隔才等于等时间间隔，间隔不齐，竖直方向 1:3:5 那个比就量不出来');

    rubric.criteria.push(fewPoints);
    rubric.criteria.push(originLate);
    rubric.criteria.push(mixedLaunch);
    rubric.criteria.push(unevenX);
    return rubric;
  }
}
