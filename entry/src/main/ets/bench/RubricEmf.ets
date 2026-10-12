import { CriterionBuilder, CriterionOp, Rubric } from './Rubric';

/**
 * 「测量电源的电动势和内阻」参考细则(高中必修三,配场景 `emf-internal-resistance`)。
 *
 * 这条实验的分全在**取点**:U-I 线的纵截距是 E、斜率绝对值是 r,
 * 所以点少、点挤在一小段电流上、或者压根没有靠近开路那一端,截距就得靠外推猜。
 * 四条判据读的都是学生按出来的读数分布,一条都不读 E 与 r —— 那两个量在这里
 * 是被测的未知数,拿它们当尺子等于拿答案改卷。
 *
 * 分值做成**能被满足的**:六组读数从 2 Ω 铺到 30 Ω 一分不扣(harness 有这条断言)。
 * 判不出来的不写:电池极化使图线弯曲、电流表内阻对 E 与 r 的影响方向,
 * 这两条要么需要模型有极化、要么需要学生把处理结果交进来(#61),现在都判不了。
 */
export class RubricEmf {
  /** 这份细则配哪个场景注册表 id,由细则自己声明 —— 加实验时不用回来改一张总表的两处 */
  static readonly SCENE: string = 'emf-internal-resistance';
  static readonly ID: string = 'emf-internal-resistance-rubric';
  static readonly VERSION: string = '2026.10';

  static create(): Rubric {
    const rubric = new Rubric();
    rubric.id = RubricEmf.ID;
    rubric.label = '测量电源的电动势和内阻 · 参考细则';
    rubric.source = '参考细则（非官方标准），依据人教版必修三「测量电源的电动势和内阻」课题的常见扣分点自建';
    rubric.version = RubricEmf.VERSION;
    rubric.totalPoints = 100;

    // 标题与证据是直接印给学生看的,标点一律全角
    const few = CriterionBuilder.numeric('emf-few-records', '读数组数太少，只能解方程不能作图',
      CriterionOp.LT, 'emfRecordCount', 4, 0, 30,
      '共记录 {emfRecordCount} 组：两组读数也能凑出 E 与 r，但描不出 U-I 线，更分不出哪几点该剔');
    const narrow = CriterionBuilder.numeric('emf-narrow-current', '读数挤在一小段电流里，截距全靠外推',
      CriterionOp.LT, 'emfCurrentSpread', 0.3, 0, 25,
      '读数铺开的电流跨度只有 {emfCurrentSpread} A：点都挤在一小段上，纵截距要沿这条短线外推很远才能拿到');
    const noOpen = CriterionBuilder.numeric('emf-no-open-end', '没有靠近开路那一端的读数',
      CriterionOp.GT, 'emfMinCurrent', 0.1, 0, 20,
      '最接近开路的一组电流是 {emfMinCurrent} A：把电阻箱调到几十欧取一个接近零电流的点，图线才贴着纵轴');
    const overRange = CriterionBuilder.numeric('emf-over-range', '有读数超过电流表量程',
      CriterionOp.GT, 'emfMaxCurrent', 0.6, 0, 25,
      '最大电流 {emfMaxCurrent} A 超过电流表 0.6 A 量程：大电流下干电池极化明显，那几点本身就不在直线上');

    rubric.criteria.push(few);
    rubric.criteria.push(narrow);
    rubric.criteria.push(noOpen);
    rubric.criteria.push(overRange);
    return rubric;
  }
}
