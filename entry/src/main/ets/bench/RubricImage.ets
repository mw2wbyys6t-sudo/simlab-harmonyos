import { CriterionBuilder, CriterionOp, Rubric } from './Rubric';

/**
 * 「描绘简谐运动的图像」参考细则(选择性必修一,配场景 `spring-image`)。
 *
 * 这条实验的产物就是那幅描出来的图,所以判据全读图本身:
 * ① 按了几下手(点太少连不成形状);② 这些点覆盖了几个周期(不到一个半周期看不出周期性);
 * ③ 折线跟真实曲线最大差多少(按得太慢就走样,这个数是量出来的失真)。
 *
 * ③ 是这条实验真正独有的那条:走样不是讲给学生的结论,是他自己按出来的后果,
 * 而且当场能量。目录里「讨论采样间隔取太大时图形失真」要判的就是它。
 *
 * **只有三条,是量出来的结论而不是偷懒**:候选的第四条「点只铺在半截行程上」(取样全挤在
 * 同一个相位附近)与 ③ 等价 —— 恒振幅无阻尼下,最大间隔一小,点必然铺满整个行程;
 * 铺不满的那几次,③ 一定先红。判分宁少一条,也不留一条永远跟着别人响的判据。
 * 从图上读振幅与周期要写单位、标 a 与 v 同向的位置 —— 那些要学生把数交进来才判得了(#61),
 * 现在一律不写进细则。
 *
 * 分值做成**能被满足的**:默认参数下(T≈8.9 s)每半秒左右按一次、连按三十来下覆盖一个半周期,
 * 一分不扣(harness 里有这条断言)。
 */
export class RubricImage {
  /** 这份细则配哪个场景注册表 id,由细则自己声明 */
  static readonly SCENE: string = 'spring-image';
  static readonly ID: string = 'spring-image-rubric';
  static readonly VERSION: string = '2026.10';

  static create(): Rubric {
    const rubric = new Rubric();
    rubric.id = RubricImage.ID;
    rubric.label = '描绘简谐运动的图像 · 参考细则';
    rubric.source = '参考细则（非官方标准），依据人教版选择性必修一「描绘简谐运动的图像」课题的常见扣分点自建';
    rubric.version = RubricImage.VERSION;
    rubric.totalPoints = 100;

    // 标题与证据是直接印给学生看的，标点一律全角
    const fewDots = CriterionBuilder.numeric('img-few-samples', '只按了几下手，连不成一条曲线',
      CriterionOp.LT, 'imgSamples', 12, 0, 34,
      '图上一共 {imgSamples} 个取样点：一个周期里不到十个点，折线就把峰和谷都抹平了，看不出是不是正弦型');
    const shortSpan = CriterionBuilder.numeric('img-short-span', '描的时间太短，看不出周期性',
      CriterionOp.LT, 'imgSpanT', 1.5, 0, 33,
      '这些点只覆盖了 {imgSpanT} 个周期：不到一个半周期，图上分不出「下一次什么时候重复」，周期也就无从量起');
    const distorted = CriterionBuilder.numeric('img-distorted', '按得太慢，描出来的图失真了',
      CriterionOp.GT, 'imgDistortCm', 15, 0, 33,
      '把你这些点连成的折线跟真实曲线逐段比，最大差 {imgDistortCm} cm（最稀的一段隔了 {imgMaxGapT} 个周期）：间隔接近半个周期时，峰和谷会被错接成锯齿 —— 这就是采样太稀的走样');

    rubric.criteria.push(fewDots);
    rubric.criteria.push(shortSpan);
    rubric.criteria.push(distorted);
    return rubric;
  }
}
