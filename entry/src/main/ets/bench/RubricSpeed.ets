import { CriterionBuilder, CriterionOp, Rubric } from './Rubric';

/**
 * 「测量物体运动的速度」参考细则(初中八年级上,配场景 `stopwatch-cart`)。
 *
 * v = s/t 是求解器与学生都算不错的事,分在**测**上:按了几次表、覆盖了几段不同的区间、
 * 最长那一段走得到 1.5 s 吗。最后一条是教材那句「斜面倾角要取小」的真实理由 ——
 * 但判据读的是"这一段量到多久"这个后果,不是倾角那个参数:施予的值不能当学生的选择来判。
 *
 * 三条互不重叠:一次都没计时只会走第一条(它同时也就是"次数太少"),
 * 不会因为同一处不规范被扣两遍。
 *
 * 没写进去的:各段速度的数值、"反应时间使 v 偏大还是偏小"的解释 —— 要学生把数与话交进来
 * 才判得了(#61 学生填数入口),现在只当读数摆在屏幕上。
 */
export class RubricSpeed {
  /** 这份细则配哪个场景注册表 id,由细则自己声明 —— 加实验时不用回来改一张总表的两处 */
  static readonly SCENE: string = 'stopwatch-cart';
  static readonly ID: string = 'stopwatch-cart-rubric';
  static readonly VERSION: string = '2026.10';

  static create(): Rubric {
    const rubric = new Rubric();
    rubric.id = RubricSpeed.ID;
    rubric.label = '测量物体运动的速度 · 参考细则';
    rubric.source = '参考细则（非官方标准），依据人教版八年级上「测量物体运动的速度」课题的常见扣分点自建';
    rubric.version = RubricSpeed.VERSION;
    rubric.totalPoints = 100;

    // 标题与证据是直接印给学生看的,标点一律全角
    const fewTrials = CriterionBuilder.numeric('speed-few-trials', '计时次数太少，凑不出上半程与全程',
      CriterionOp.LT, 'speedTrials', 3, 0, 40,
      '一共按下并松开了 {speedTrials} 次停表：这条实验要的是上半程、下半程与全程三段各自的时间，一次都没测就一段速度也算不出来');
    const oneSegment = CriterionBuilder.numeric('speed-one-segment', '几次测的都是同一段，比较不了分段快慢',
      CriterionOp.LT, 'speedSegments', 2, 0, 30,
      '测到的不同区间只有 {speedSegments} 段：把终点挪到木板中点再测一次，才有上半程与全程可比');
    const tooFast = CriterionBuilder.numeric('speed-too-fast', '全程走得太快，反应时间占进读数里',
      CriterionOp.LT, 'speedLongestS', 1.5, 0, 30,
      '最长的一段也只走了 {speedLongestS} s：手按停表的反应时间约 0.2 s，占比一到一成多，测出来的平均速度就主要取决于你按得多快，这就是斜面要垫矮的理由');

    rubric.criteria.push(fewTrials);
    rubric.criteria.push(oneSegment);
    rubric.criteria.push(tooFast);
    return rubric;
  }
}
