import { CriterionBuilder, CriterionOp, Rubric } from './Rubric';

/**
 * 「测量匀变速直线运动物体的加速度」参考细则(高中必修一,配场景 `tape-cart`)。
 *
 * 这条实验的分在**纸带是怎么来的**,不在 a 算得对不对(小车怎么动是求解器算的,
 * 学生算不出错的运动)。四条判据读的全是学生自己的动作留下的后果:
 * ① 纸带上到底打没打出点;② 是不是先释放小车才接通电源(头一段运动压根没记下来);
 * ③ 计数起点有没有舍开前面密得读不出的那一段;④ 按所选间隔能切出几段(逐差法要四段)。
 *
 * a 的数值本身、逐差法算得对不对、v-t 图斜率取第二个 a —— 这些要学生把量到的数
 * 交进来才判得了(#61 学生填数入口),现在一律不写进细则:宁漏不误。
 *
 * 分值做成**能被满足的**:8° 斜面、通电后释放、每 5 个点取一个计数点、起点放在第 20 个点,
 * 一分不扣(harness 里有这条断言)。
 */
export class RubricTape {
  /** 这份细则配哪个场景注册表 id,由细则自己声明 —— 加实验时不用回来改一张总表的两处 */
  static readonly SCENE: string = 'tape-cart';
  static readonly ID: string = 'tape-cart-rubric';
  static readonly VERSION: string = '2026.10';

  static create(): Rubric {
    const rubric = new Rubric();
    rubric.id = RubricTape.ID;
    rubric.label = '测量匀变速直线运动物体的加速度 · 参考细则';
    rubric.source = '参考细则（非官方标准），依据人教版必修一「测量匀变速直线运动物体的加速度」课题的常见扣分点自建';
    rubric.version = RubricTape.VERSION;
    rubric.totalPoints = 100;

    // 标题与证据是直接印给学生看的,标点一律全角
    const noDots = CriterionBuilder.numeric('tape-few-dots', '纸带上的点太少，量不出几段位移',
      CriterionOp.LT, 'tapeDotCount', 10, 0, 25,
      '纸带上共 {tapeDotCount} 个点：计时器每 0.02 s 打一个点，点这么少说明小车走得太短或电源太晚接通，后面无从量起');
    const lostHead = CriterionBuilder.numeric('tape-lost-head', '先释放小车才接通电源，头一段运动没记下来',
      CriterionOp.GT, 'tapeLostHead', 0, 0, 25,
      '释放与接通之间漏打 {tapeLostHead} 个点：初速度为零那一段最该量，却正好是纸带上空着的那一段');
    const crowded = CriterionBuilder.numeric('tape-crowded-start', '计数起点太靠前，最短那段用刻度尺读不出来',
      CriterionOp.LT, 'tapeShortestMm', 2, 0, 25,
      '所选计数段里最短的一段只有 {tapeShortestMm} mm：毫米刻度尺在这一步的读数误差就有 ±0.5 mm，这么短的一段量了等于没量，开头密着的点应当舍掉');
    const fewSegments = CriterionBuilder.numeric('tape-few-segments', '计数段太少，逐差法用不起来',
      CriterionOp.LT, 'tapeSegments', 4, 0, 25,
      '按当前间隔只切出 {tapeSegments} 段：逐差法要用上全部数据，至少得四段，两三组只能两两相减再平均');

    rubric.criteria.push(noDots);
    rubric.criteria.push(lostHead);
    rubric.criteria.push(crowded);
    rubric.criteria.push(fewSegments);
    return rubric;
  }
}
