import { CriterionBuilder, CriterionOp, Rubric } from './Rubric';

/**
 * 「探究平抛运动的特点」参考细则(高中必修二,配场景 `projectile-frame`)。
 *
 * 六条判据分两层。前四条读的是**这几个点是怎么描出来的**:
 * ① 描了几个点(两三个点连不成轨迹);② 有没有先挂重垂线定原点(在那之前描下的点,
 * 坐标是按板角量的,拿去检验 y 与 x² 成正比必然对不上);③ 这些点用的释放位置是不是同一格
 * (差一格,槽口速度就变了,几个点根本不在同一条抛物线上);④ 卡片摆的位置是不是大致等间隔
 * (只有水平等间隔才等于等时间间隔,竖直方向 1:3:5 那条才量得出来)。
 * 后两条读的是**学生自己交上来的那两个数对不对** —— 由他描的点反求的 g、竖直方向相邻两段的比。
 * 这两格由场景的填空收进来(`pjG` / `pjSegRatio`),runner 拿同一批点按正确流程再算一遍,
 * 把结果码(0 算对 / 1 算错 / 2 没交)写成事实,这里只比码值:细则仍然不懂物理,
 * 物理在 `physics/ProjectileGProcedure`。
 *
 * 为什么没有"y 与 x² 成正比"这一条判据:定过原点、释放位置又一致时,这个比值本来就恒定 ——
 * 它只能被 ②③ 带着走,拿它当判据就是留一条永远跟着别人响的判据。所以它只当读数摆在面板上,
 * 让学生自己拿它去检验。与本地值比大小、说明槽面要不要光滑 —— 这些仍未开填空,不写进细则。
 *
 * **两处必须如实交代的空洞**(Ruling G 把扫描域铺到 slot 1..4 × card 1..8 之后量出来的,
 * 不是漏写;判词不许承诺抓住它们,写进去就是一句兑现不了的话):
 * ① 「把横坐标当成时间」那个错法(g = 2y/x²,数值上等于应有值的 1/v0²)在第 1 格释放时得到
 *   10.00,与应有值 9.80 只差 2.04%,落进 3% 判分带宽 —— 那个人被判"算对了",这条指纹永远
 *   点不着名,于是它已从错法表里删掉;
 * ② 先描点后挂线的人照标签上那套板角数反求,在第 2 格释放·卡片第 1 格得到 9.5285(差 2.77%)、
 *   第 4 格释放·卡片第 3 格得到 10.02(差 2.24%),同样落进带宽 —— 「板角基准的 g」因此压根
 *   没进错法表。
 * 结果**不是**"这两种人都会被放过"。把 25 个可达的"第 1 个点"组合(slot 1..4 × card 1..8,
 * 球飞不到的那些格描不上点)逐个真跑一遍,harness 把这几个数钉成断言:
 * 落进带宽、在 g 那一格被放过的只有 slot2·card1 与 slot4·card3 这 **2 个**;其余 **23 个**会被判
 * "算错了",同时吃 pj-origin-late 15 与 pj-g-value 20 这两条 = 35 分 —— 可是错法表点不出他犯的
 * 是哪一种(那 23 个的错法码全是 0),判词只能给一句光秃秃的"算错了"。
 * 也就是说:基准这一层一个人也没漏(25 个全扣 pj-origin-late),漏的是"**说清他错在哪**"那一笔。
 * 宁可少一条能点名的判据,不留一张会撒谎的错法表。
 *
 * "没交"要扣分、"这道题在这批数据上出不来"不扣分,这条界线收在 `AnswerCheck.match`
 * 与 `Physics2DRunner.checkNumber`(不写事实 → 判定层按缺失放过),细则不重复实现。
 * 这条场景的"出不出来"有三道门:
 * ① **没定过原点时两格都不出题** —— 那一套按板角量的坐标算出来的不是这一格问的 g,
 *    基准那件事归上面 ② 去说,不在这里抢同一个错;
 * ② **点混了两套基准时段比那一格不出题**(与面板上 pjXGapRatio、pjRatioErr 那两条读数同一把门):
 *    它的窗口按存下来的远近挑"最近那两个点",跨基准挑出来的那两个根本不是一条抛物线上的邻居,
 *    拿那种窗口量出的数去判人,会出现"判词自己写着相邻两段之比是 1:3:5、却报一个 0.44 当应有值"
 *    这种自相矛盾,而照课本答 3 的人要被扣 20 —— 这是把做对的人判错,比漏判严重;
 * ③ 点数不够:g 那一格一个点就问,段比那一格要三个点才问(spec §6 的边界)。
 *    g 那一格与基准无关(应有值按真实下落算),所以 ② 那种人照 9.8 交仍然判对。
 *
 * 分值做成**能被满足的**:先挂重垂线、固定第 2 格释放、卡片依次摆第 1/2/3/4 格各描一次,
 * 两格按应有值交上来(g 那格 9.80、段比那格 3),一分不扣 —— harness 里那条走的就是真 runner、
 * 走的就是这四个卡片。**别照"卡片第 2/4/6/8 格"那套老说法做**:第 8 格离槽口 1.20 m,
 * 只有第 4 格释放(能飞 1.37 m)接得住球,第 1-3 格那几次释放球先落地、纸上什么都没添
 * (harness 数过:卡片第 8 格只有 1 个释放格描得上)。
 * 手上四条做足而两格空着只到 60:填空框到 Task 7 才上线,那 40 分在此之前拿不到。
 */
export class RubricProjectile {
  /** 这份细则配哪个场景注册表 id,由细则自己声明 */
  static readonly SCENE: string = 'projectile-frame';
  static readonly ID: string = 'projectile-frame-rubric';
  /** 2026.10.1:加了两条数据处理判据并把 4×25 重排成 4×15 + 2×20(满分仍是 100) */
  static readonly VERSION: string = '2026.10.1';

  static create(): Rubric {
    const rubric = new Rubric();
    rubric.id = RubricProjectile.ID;
    rubric.label = '探究平抛运动的特点 · 参考细则';
    rubric.source = '参考细则（非官方标准），依据人教版必修二「探究平抛运动的特点」课题的常见扣分点自建';
    rubric.version = RubricProjectile.VERSION;
    rubric.totalPoints = 100;

    // 标题与证据是直接印给学生看的，标点一律全角
    const fewPoints = CriterionBuilder.numeric('pj-few-points', '描下的点太少，连不成一条轨迹',
      CriterionOp.LT, 'pjPointCount', 4, 0, 15,
      '纸上一共 {pjPointCount} 个点：两三个点既能连成抛物线也能连成圆弧，分不出竖直方向到底是自由落体还是别的什么');
    const originLate = CriterionBuilder.numeric('pj-origin-late', '挂重垂线之前就描了点，坐标没有基准',
      CriterionOp.GT, 'pjEarlyMarks', 0, 0, 15,
      '有 {pjEarlyMarks} 个点是在挂重垂线、标定抛出点之前描下的：那几个点的横纵坐标是按木板角量的，抛出点并不在那里，拿去检验 y 与 x² 成正比必然对不上');
    const mixedLaunch = CriterionBuilder.numeric('pj-mixed-launch', '几次释放不在同一高度，这些点不在同一条抛物线上',
      CriterionOp.GT, 'pjSlotSpread', 0, 0, 15,
      '描这些点用过的释放位置最大差了 {pjSlotSpread} 格：槽口速度只由释放高度决定，高度一变每条轨迹就跟着变，几个点连起来就不再是一条曲线');
    const unevenX = CriterionBuilder.numeric('pj-uneven-x', '卡片摆得忽近忽远，等时间间隔这条前提就没了',
      CriterionOp.GT, 'pjXGapRatio', 2, 0, 15,
      '相邻两点的水平间隔最大是最小的 {pjXGapRatio} 倍：水平等间隔才等于等时间间隔，间隔不齐，竖直方向 1:3:5 那个比就量不出来');

    // 数据处理这两条读的是结果码:0 算对、1 算错、2 没交 —— 判据本身不懂物理。
    // 标题写"没算对或没交"而不是"算错了":同一条判据要同时容纳 1 与 2 两种码,
    // 学生明明没填却看到"算错了",会以为应用吞了他的输入。
    // 证据只点名表里真有的错法(漏乘 2、乘/除一千倍;总位移之比、每段翻倍),
    // 不承诺头注释里那两条已经删掉/没进表的错法。段比那条把"哪两个点算第一段"也说给学生:
    // 窗口按离槽口的远近取,不按描点先后 —— 这是应用内部在做的事,不写就是埋雷。
    const gValue = CriterionBuilder.numeric('pj-g-value', '反求的 g 没算对或没交',
      CriterionOp.GT, 'pjGOutcome', 0, 0, 20,
      '你交的 g 是 {ans.pjG} m/s²，按你描的第 1 个点应为 {pjGTrue} m/s²，判定：{pjGOutcome}。'
        + '由 y = ½gt² 与 x = v0t 消去 t 得 g = 2·(y/x²)·v0²：漏掉那个 2、'
        + '或者把毫米当成米、把米当成毫米（乘一千倍、除一千倍），都会得到另一个数');
    const ratioValue = CriterionBuilder.numeric('pj-seg-ratio-value',
      '竖直方向相邻两段的比没算对或没交',
      CriterionOp.GT, 'pjSegRatioOutcome', 0, 0, 20,
      '你交的第二段与第一段之比是 {ans.pjSegRatio}，按你描的最近那两个点应为 {pjSegRatioTrue}，'
        + '判定：{pjSegRatioOutcome}。第一段是从槽口量到离槽口最近那个点，第二段是它到次近那个点；'
        + 'y 与 x² 成正比说的是总位移，等时间间隔下相邻两段之比才是 1:3:5。'
        + '把两点的总位移之比当成段比，那个数总比段比大 1（总位移之比 = 1 + 第二段 ÷ 第一段）；'
        + '以为每段翻倍会得到 2');

    rubric.criteria.push(fewPoints);
    rubric.criteria.push(originLate);
    rubric.criteria.push(mixedLaunch);
    rubric.criteria.push(unevenX);
    rubric.criteria.push(gValue);
    rubric.criteria.push(ratioValue);
    return rubric;
  }
}
