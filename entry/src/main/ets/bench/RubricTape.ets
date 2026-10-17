import { CriterionBuilder, CriterionOp, Rubric } from './Rubric';

/**
 * 「测量匀变速直线运动物体的加速度」参考细则(高中必修一,配场景 `tape-cart`)。
 *
 * 六条判据分两层。前四条读的是**这条纸带是怎么来的**:
 * ① 纸带上到底打没打出点;② 是不是先释放小车才接通电源(头一段运动压根没记下来);
 * ③ 计数起点有没有舍开前面密得读不出的那一段;④ 按所选间隔能切出几段(逐差法要四段)。
 * 后两条读的是**学生自己交上来的那两个数对不对** —— 逐差法的分子与分母里 T² 的倍数。
 * 这两格由场景的填空收进来(`tapeNumerator` / `tapeDenFactor`),runner 拿同一批段长按
 * 正确流程再算一遍,把结果码(0 算对 / 1 算错 / 2 没交)写成事实,这里只比码值:
 * 细则仍然不懂物理,物理在 `physics/TapeChunkProcedure`。
 *
 * "没交"要扣分、"这道题在这批数据上出不来"不扣分,这条界线收在 `AnswerCheck.match`
 * 与 `Physics2DRunner.checkNumber`(不写事实 → 判定层按缺失放过),细则不重复实现。
 * v-t 图斜率取第二个 a 那一问(`tape-a-from-slope`)仍不判:它要的数还没开填空。
 *
 * 分值做成**能被满足的**:8° 斜面、通电后释放、每 5 个点取一个计数点、起点滑杆放在第 40 个点
 * (应用会把它夹到有效起点,判词与读数都会报出真正用的那个),再把两格按应有值交上来,
 * 一分不扣(harness 里那条走的是真 runner)。
 */
export class RubricTape {
  /** 这份细则配哪个场景注册表 id,由细则自己声明 —— 加实验时不用回来改一张总表的两处 */
  static readonly SCENE: string = 'tape-cart';
  static readonly ID: string = 'tape-cart-rubric';
  /** 2026.10.1:加了两条数据处理判据并把 4×25 重排成 4×15 + 2×20(满分仍是 100) */
  static readonly VERSION: string = '2026.10.1';

  static create(): Rubric {
    const rubric = new Rubric();
    rubric.id = RubricTape.ID;
    rubric.label = '测量匀变速直线运动物体的加速度 · 参考细则';
    rubric.source = '参考细则（非官方标准），依据人教版必修一「测量匀变速直线运动物体的加速度」课题的常见扣分点自建';
    rubric.version = RubricTape.VERSION;
    rubric.totalPoints = 100;

    // 标题与证据是直接印给学生看的,标点一律全角
    const noDots = CriterionBuilder.numeric('tape-few-dots', '纸带上的点太少，量不出几段位移',
      CriterionOp.LT, 'tapeDotCount', 10, 0, 15,
      '纸带上共 {tapeDotCount} 个点：计时器每 0.02 s 打一个点，点这么少说明小车走得太短或电源太晚接通，后面无从量起');
    const lostHead = CriterionBuilder.numeric('tape-lost-head', '先释放小车才接通电源，头一段运动没记下来',
      CriterionOp.GT, 'tapeLostHead', 0, 0, 15,
      '释放与接通之间漏打 {tapeLostHead} 个点：初速度为零那一段最该量，却正好是纸带上空着的那一段');
    // Ruling N 之后,头上密着的重叠点由应用自动舍掉(计数起点夹到第一个移动点),这条不再是
    // "起点太靠前";今天真正触发它的是计数间隔太细、或起点就贴着释放那一下 —— 文案跟着改因与补救。
    const crowded = CriterionBuilder.numeric('tape-crowded-start', '计数间隔太细，最短那段用刻度尺读不出来',
      CriterionOp.LT, 'tapeShortestMm', 2, 0, 15,
      '所选计数段里最短的一段只有 {tapeShortestMm} mm：毫米刻度尺在这一步的读数误差就有 ±0.5 mm，这么短的一段量了等于没量；每几个点取一个计数点的间隔调大一些，或让有效计数起点离释放那一下远一点');
    const fewSegments = CriterionBuilder.numeric('tape-few-segments', '计数段太少，逐差法用不起来',
      CriterionOp.LT, 'tapeSegments', 4, 0, 15,
      '按当前间隔只切出 {tapeSegments} 段：逐差法要用上全部数据，至少得四段，两三组只能两两相减再平均');

    // 数据处理这两条读的是结果码:0 算对、1 算错、2 没交 —— 判据本身不懂物理。
    // 标题写"没算对或没交"而不是"算错了":同一条判据要同时容纳 1 与 2 两种码,
    // 学生明明没填却看到"算错了",会以为应用吞了他的输入。
    // Ruling N:两条判词都报出应用实际用的取窗口径(有效起点与参与逐差的段数 2h),
    // 并写明"末尾凑不满一对的那段舍掉" —— 奇数段窗口不许让学生猜怎么分半。
    const numerator = CriterionBuilder.numeric('tape-numerator-value',
      '逐差法这一问没算对或没交',
      CriterionOp.GT, 'tapeNumeratorOutcome', 0, 0, 20,
      '你交的分子是 {ans.tapeNumerator} mm，这条纸带按逐差法应为 {tapeNumeratorTrue} mm，判定：{tapeNumeratorOutcome}。分子是后一半各段之和 减 前一半各段之和，这条纸带从第 {tapeChunkStart} 个点量起、参与逐差的共 {tapeChunkSegments} 段（末尾凑不满一对的那段舍掉）：只用首尾两段会把中间量出来的数全丢掉，相邻两两相减又退化成逐段平均');
    const denFactor = CriterionBuilder.numeric('tape-den-factor-value',
      '逐差法分母这一问没算对或没交',
      CriterionOp.GT, 'tapeDenFactorOutcome', 0, 0, 20,
      '你交的分母倍数是 {ans.tapeDenFactor}，判定：{tapeDenFactorOutcome}，这条纸带该是 {tapeDenFactorTrue}：它是参与逐差段数的一半再自乘，这条纸带参与逐差的共 {tapeChunkSegments} 段；漏乘段数平方会把加速度放大一大截、段数越多放大得越厉害，只乘一个段数照样放大，拿总段数的平方去除又会把它缩小到四分之一');
    rubric.criteria.push(noDots);
    rubric.criteria.push(lostHead);
    rubric.criteria.push(crowded);
    rubric.criteria.push(fewSegments);
    rubric.criteria.push(numerator);
    rubric.criteria.push(denFactor);
    return rubric;
  }
}
