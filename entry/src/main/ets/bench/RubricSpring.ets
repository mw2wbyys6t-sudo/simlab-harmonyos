import { CriterionBuilder, CriterionOp, Rubric } from './Rubric';

/**
 * 「探究弹簧弹力与形变量的关系」参考细则。
 *
 * 四条判据全部读**学生动作造成的后果**,不读意图,也不读我们施予的参数:
 * 超没超弹性限度由最大伸长定,挡数由他按过记录的载荷种类定,
 * 「在动的弹簧上读数」由记录那一瞬间的速度定。
 *
 * 分值刻意做成能被满足的:认真做四挡增挂 + 三挡卸载对照、每挡停下来再记录,应当一分不扣
 * (harness 里有这条断言)。判不出来的扣分点一律不写进细则 —— 宁漏不误。
 */
export class RubricSpring {
  /** 这份细则配哪个场景注册表 id,由细则自己声明 —— 加实验时不用回来改一张总表的两处 */
  static readonly SCENE: string = 'spring-force';
  static readonly ID: string = 'spring-force-rubric';
  static readonly VERSION: string = '2026.10';

  static create(): Rubric {
    const rubric = new Rubric();
    rubric.id = RubricSpring.ID;
    rubric.label = '探究弹簧弹力与形变量的关系 · 参考细则';
    rubric.source = '参考细则（非官方标准），依据人教版高中物理必修一「探究弹力与形变量的关系」课题的常见扣分点自建';
    rubric.version = RubricSpring.VERSION;
    rubric.totalPoints = 100;

    // 标题与证据是直接印给学生看的,标点一律全角
    const damaged = CriterionBuilder.numeric('spring-damaged', '超过弹性限度，弹簧被拉坏',
      CriterionOp.GT, 'beyondLimit', 0, 0, 30,
      '最大弹性伸长 {maxExtension} m 越过了弹性限度，撤去砝码后指针回不到零（残余 {residual} m）');
    const tooFew = CriterionBuilder.numeric('spring-too-few-loads', '载荷档数太少，画不出 F-x 图',
      CriterionOp.LT, 'distinctLoads', 4, 0, 25,
      '只记录了 {distinctLoads} 档不同载荷，拟合一条直线至少需要 4 档');
    const moving = CriterionBuilder.numeric('spring-recorded-while-moving', '弹簧还在振动就记读数',
      CriterionOp.ABS_GT, 'maxRecordSpeed', 0.02, 0, 25,
      '记录读数瞬间指针速度达 {maxRecordSpeed} m/s，此时读到的不是平衡位置的形变量');
    const noUnload = CriterionBuilder.numeric('spring-no-unload', '只增挂不卸载，没有卸载对照',
      CriterionOp.EQ, 'unloadSteps', 0, 0, 20,
      '卸载步数 {unloadSteps}：逐次取下砝码复核是判断弹簧是否发生塑性变形的唯一办法');

    rubric.criteria.push(damaged);
    rubric.criteria.push(tooFew);
    rubric.criteria.push(moving);
    rubric.criteria.push(noUnload);
    return rubric;
  }
}
