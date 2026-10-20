import { ExperimentMeta } from '../model/ExperimentTypes';
import { FactSheet } from '../model/FactSheet';
import { Physics2DRunner } from './Physics2DRunner';
import { Fingerprint } from './AnswerCheck';
import { ProjectileGProcedure } from './ProjectileGProcedure';
import {
  BoxShape, CircleShape, LabelShape, SegmentShape, WorldSnapshot
} from './World2D';

const G = 9.8;

/**
 * 斜槽与卡片都是**离散档位**,这是刻意的:
 * 这条实验要判的两件事 —— "每次是不是从同一位置静止释放"、"取点是不是水平等间隔" ——
 * 只有做成档位才留得下事实。拖滑杆得到的连续值,既不像器材也没有"第几次"这个可数对象。
 */
const SLOT_MIN = 1;
const SLOT_MAX = 4;
/** 斜槽每高一格,球到槽口时多落下这么多高度:v0 = sqrt(2gh) */
const SLOT_STEP = 0.05;
const CARD_MIN = 1;
const CARD_MAX = 8;
/** 卡片每往外挪一格,离槽口的水平距离加这么多米 */
const CARD_STEP = 0.15;

/** 槽口(球离开斜槽的那一点) */
const EXIT_X = 1.15;
const EXIT_Y = 2.75;
/** 没标定原点时,坐标只能按木板左下角量 —— 这个偏移就是"没定原点"的代价 */
const CORNER_X = 0.35;
const CORNER_Y = 0.5;
const FLOOR_Y = 0.4;
const BOARD_X1 = 4.35;
const BOARD_Y1 = 4.0;

const C_BOARD = '#E8E2D4';
const C_FRAME = '#8A7A5C';
const C_RAMP = '#5A6B7F';
const C_BALL = '#2F6FB5';
const C_CARD = '#E2574C';
const C_DOT = '#25313F';
const C_PLUMB = '#2E9E7A';
const C_TEXT = '#1F2A3A';

/**
 * 描下来的一个点:坐标按**描它那一刻的原点设定**算,外加两条来路 —— 用了第几格释放、卡片摆在哪。
 *
 * `drop` 与 `x`/`y` 是两套东西,必须同时记(Controller Ruling I):
 * `drop` 是从槽口算起的**真实下落**(米),与基准无关,反求 g 的应有值一律由它算;
 * `x`/`y` 是学生在他自己那套基准下量到的坐标 —— 没挂重垂线时它是板角基准,
 * 拿它反求 g 会得到另一个数,这正是"没定原点"的代价,标签上得把基准写出来。
 */
class TracedPoint {
  x: number = 0;
  y: number = 0;
  drop: number = 0;
  slot: number = 0;
  card: number = 0;
  beforeOrigin: boolean = false;
}

/**
 * 探究平抛运动的特点(高中必修二,地图条目 `phy-sr-007`)。
 *
 * 器材是斜槽、竖直木板上的白纸、复写纸与一张带孔卡片。真实操作里学生**不追时间**:
 * 把卡片挪到某个水平位置、从斜槽同一高度静止释放、球穿过孔时在纸上留下一个点,
 * 换位置再来一次。所以这里让"卡片摆在哪一格"与"从第几格释放"成为可数的动作,
 * 判分读的是它们留下的后果:
 * ① 描了几个点;② 定原点之前描下了几个;③ 这些点用的释放位置是不是同一个;
 * ④ 相邻水平间隔差得有多悬殊(等间隔才量得出竖直方向 1:3:5)。
 *
 * 场景**不画轨迹、不给自动图线**:抛物线的形状正是这条实验要学生自己检验出来的东西
 * (按 y 与 x² 成正比检验,而不是"看着像")。y/x² 的离散度只当读数摆在面板上。
 *
 * 两格填空(`pjG` / `pjSegRatio`)把数据处理那一层接进事实,应有值的算式全在
 * `ProjectileGProcedure`,这里只负责"从哪批数取"。**作废与不作废这一对**是这条场景自己定的:
 * ① 改斜槽档位(`slot+`/`slot-`)、挪卡片(`card+`/`card-`)、挂重垂线(`origin`)都不作废 ——
 *    这三下只改世界的当前状态,不动已经描在纸上的点,而两格的应有值恰恰只由那些点带着的
 *    `drop`/`card`/`slot` 决定(描完之后再去升档位,拿新的 v0 配旧的点会假扣分);
 * ② 再描一个点(`release` 真的在纸上留下点时)**只在段比那一问的数真的变了才作废那一格** ——
 *    段比那一问的窗口是"离槽口最近的那两个点":新点落在更近处才会换掉窗口、数才跟着变;
 *    落在更远处(第 5、6 格这类)窗口纹丝不动,交过的数就原样留着。判据是
 *    "**这一格问的那个数变了没有**",不是"纸带动过没有" —— 描点落笔不等于作废(最终评审 C1:
 *    旧写法每次落笔无条件作废,交对的人再描一个远点就被读成"没交",白丢 20 分)。
 *    g 那一格不在其列:它只读第 1 个点,而点只会追加,它的应有值纹丝不动,
 *    作废一个没动的数就是把做对的人判成"没交"。
 *    这与 sr-003 声明的"power/release 不作废"不一样,是这条实验自己的事实逼出来的:
 *    那边纸带已经走完,再按键不改窗口;这边纸还在长。
 * ③ 两格都还有一道共同的门:**描的点混了两套基准时段比那一格不出题**。它的窗口按 x 挑,
 *    而 x 在挂线前后是两套基准(板角 vs 抛出点),跨基准挑出来的"最近两个点"根本不是那回事;
 *    `pjXGapRatio` 与 `pjRatioErr` 两条读数早就为此拒答了(`mixedBaseline()`),这一格照同一把门。
 */
export class ProjectileRunner extends Physics2DRunner {
  private points: TracedPoint[] = [];
  private slot: number = 2;
  private card: number = 3;
  private originSet: boolean = false;
  /** 球在飞的时候取值 0..1 的进度;负值表示不在空中 */
  private flight: number = -1;
  private flightT: number = 0;
  private flightDur: number = 0;
  /** 「球落在卡片之前」这条说明挂到下一次释放为止 —— 它不是倒计时,落地后就停在那儿 */
  private missed: boolean = false;
  private snap: WorldSnapshot = new WorldSnapshot();

  setup(meta: ExperimentMeta): void {
    this.points = [];
    super.setup(meta);
  }

  protected onSetup(): void {
    this.slot = 2;
    this.card = 3;
    this.originSet = false;
    this.flight = -1;
    this.missed = false;
    this.points = [];
  }

  protected onAction(key: string): void {
    if (key === 'slot+') {
      this.slot = this.slot < SLOT_MAX ? this.slot + 1 : SLOT_MAX;
      return;
    }
    if (key === 'slot-') {
      this.slot = this.slot > SLOT_MIN ? this.slot - 1 : SLOT_MIN;
      return;
    }
    if (key === 'card+') {
      this.card = this.card < CARD_MAX ? this.card + 1 : CARD_MAX;
      return;
    }
    if (key === 'card-') {
      this.card = this.card > CARD_MIN ? this.card - 1 : CARD_MIN;
      return;
    }
    if (key === 'origin') {
      this.originSet = true;
      return;
    }
    if (key === 'release') {
      this.launch();
    }
  }

  /** 静止释放:球沿斜槽滑下(这段不计),到槽口水平飞出;飞过卡片所在那条竖线时留下一个点 */
  private launch(): void {
    this.missed = false;
    this.flight = 0;
    this.flightT = 0;
    this.flightDur = this.fallTime();
  }

  step(dt: number): void {
    if (this.flight < 0) {
      return;
    }
    this.time += dt;
    this.flightT += dt;
    if (this.flightT >= this.flightDur) {
      // 球先落地:卡片摆得比落点还远,这一次什么都没描下来
      this.flight = -1;
      this.missed = this.cardDistance() > this.range();
      return;
    }
    if (this.flight !== 0) {
      return;
    }
    if (this.v0() * this.flightT >= this.cardDistance()) {
      this.mark();
      this.flight = 1;
    }
  }

  /**
   * 把此刻球的位置按当前原点设定记到纸上;真实下落另存一份(drop)。
   *
   * 落笔这一刻**只在段比那一格问的数真的变了才作废它**。段比那一问的窗口是"离槽口最近的
   * 那两个点":落笔前后各取一次 `segRatio()`(窗口化出来的那个数),两次都是有限值且相等,
   * 说明这一笔点落在更远的位置、窗口纹丝不动 —— 交过的数仍属于这批数据,**不作废**;
   * 任一侧是 NaN(窗口从"凑不出两段"变成"能算了",或反过来)或两个数不等(新点更近、
   * 把窗口换掉了)→ 作废。Controller Ruling D 的原话仍然成立:窗口一挪,上一次交的那个数
   * 就属于另一批数据了;但最终评审 C1 补了另一半 —— 判据是"这一格问的那个数变了没有",
   * 不是"纸带动过没有":无条件作废会把交对的人判成"没交"(评审在真树上实测:1..4 格描点、
   * 交段比 3、再描第 5 格,应有值仍是 3,答案却被清、outcome 变 2、白丢 20 分)。
   * 作废只在这一笔落笔发生:`release` 空放(球先落地、纸上什么都没添)不进这里,也就不牵连
   * 作废 —— 触发点是"纸上多了一个点",不是那颗按钮。
   *
   * g 那一格**不作废**,因为它的应有值根本不会移动:`firstPointArgs()` 只读 `points[0]`,
   * 而 `points` 在 setup/reset 之间只会追加(评审把 240 010 个动作序列穷举过一遍证明了这点)。
   * 以前这里整框 clear(),于是"中途把 g 交了、再继续描点"这个做对了的人被判定"没交",
   * 白丢 20 分,判词还写着"你交的 g 是 —" —— 那是本项目最不能有的错法。
   * Task 7 的页面要按 key 镜像清空(只清段比那一框),不许整框清(Ruling F)。
   */
  private mark(): void {
    const ratioBefore = this.segRatio();
    const d = this.cardDistance();
    const drop = 0.5 * G * (d / this.v0()) * (d / this.v0());
    const point = new TracedPoint();
    point.slot = this.slot;
    point.card = this.card;
    point.beforeOrigin = !this.originSet;
    // 真实的那一套:下落存 drop,水平距离不必再存 —— 它就是 card · CARD_STEP
    point.drop = drop;
    if (this.originSet) {
      point.x = d;
      point.y = drop;
    } else {
      point.x = EXIT_X + d - CORNER_X;
      point.y = EXIT_Y - drop - CORNER_Y;
    }
    this.points.push(point);
    const ratioAfter = this.segRatio();
    if (!(Number.isFinite(ratioBefore) && Number.isFinite(ratioAfter) && ratioBefore === ratioAfter)) {
      this.dropAnswer('pjSegRatio');
    }
  }

  readObservable(key: string): number {
    switch (key) {
      case 'pjPointCount':
        return this.points.length;
      case 'pjEarlyMarks':
        return this.earlyMarks();
      case 'pjSlotSpread':
        return this.slotSpread();
      case 'pjXGapRatio':
        return this.gapRatio();
      case 'pjRatioErr':
        return this.ratioScatter();
      case 'pjSlot':
        return this.slot;
      case 'pjLaunchSpeed':
        return this.v0();
      case 'pjRange':
        return this.range();
      case 'pjCardDistance':
        return this.cardDistance();
      case 'pjGTrue':
        return this.gFromDrop();
      case 'pjGSeen':
        return this.gFromSeen();
      default:
        return Number.NaN;
    }
  }

  /**
   * 第 1 个描下的点上,按**真实下落**反求的 g —— 也是 `pjG` 那一格的应有值。
   *
   * 它与原点无关:drop 是从槽口量下来的距离,水平距离就是 card · CARD_STEP,
   * 用的 v0 是**描下那个点时**的释放格(points[0].slot),不是当前滑槽位置。
   * 读数口 `pjGTrue` 与事实 `pjGTrue` 走的就是这一个方法(harness 有一条断言对着它,
   * 两处各写各的会当场红)。
   */
  private gFromDrop(): number {
    const a = this.firstPointArgs();
    return ProjectileGProcedure.gFromPoint(a[0], a[1], a[2]);
  }

  /** `pjG` 那一格的错法表:与上面同一个点、同一组入参 */
  private gPrintsFromDrop(): Fingerprint[] {
    const a = this.firstPointArgs();
    return ProjectileGProcedure.fingerprints(a[0], a[1], a[2]);
  }

  /**
   * 第 1 个点那一格的三个入参:真实下落(毫米)、卡片格对应的水平距离(毫米)、
   * **描它那一刻**的释放格给出的槽口速度。
   *
   * 三个数一律取自那个点自己带着的字段,不取自世界的当前状态 —— 这是 Ruling G 的落点:
   * 期望值绑在"数据被记下的那一刻"。水平距离取 card · CARD_STEP 而不是 point.x:
   * 没挂重垂线时描下的点,`x` 是板角基准下的横坐标,拿它配 drop 会拼出第三套基准。
   */
  private firstPointArgs(): number[] {
    if (this.points.length === 0) {
      return [Number.NaN, Number.NaN, Number.NaN];
    }
    const p = this.points[0];
    return [p.drop * 1000, p.card * CARD_STEP * 1000, ProjectileRunner.v0At(p.slot)];
  }

  /**
   * 段比那一格用的两个下落(毫米):离槽口**最近**的那两个点的真实下落,不是描点先后。
   * 不足两个点给空数组,procedure 那边返回 NaN → 这道题不出。
   */
  private segRatioYmm(): number[] {
    const drops = this.sortedDrop();
    if (drops.length < 2) {
      return [];
    }
    return [drops[0] * 1000, drops[1] * 1000];
  }

  private segRatio(): number {
    return ProjectileGProcedure.segmentRatio(this.segRatioYmm());
  }

  private segRatioPrints(): Fingerprint[] {
    return ProjectileGProcedure.ratioFingerprints(this.segRatioYmm());
  }

  /** 第 1 个描下的点上,按**他看到的那个 y**(没定原点时是板角基准)反求的 g */
  private gFromSeen(): number {
    if (this.points.length === 0) {
      return Number.NaN;
    }
    const p = this.points[0];
    return ProjectileGProcedure.gFromPoint(p.y * 1000, p.x * 1000,
      ProjectileRunner.v0At(p.slot));
  }

  protected onCollectFacts(sheet: FactSheet): void {
    sheet.set('pjPointCount', this.points.length);
    sheet.set('pjEarlyMarks', this.earlyMarks());
    sheet.set('pjSlotSpread', this.slotSpread());
    const gaps = this.gapRatio();
    const scatter = this.ratioScatter();
    if (Number.isFinite(gaps)) {
      sheet.set('pjXGapRatio', gaps);
    }
    if (Number.isFinite(scatter)) {
      sheet.set('pjRatioErr', scatter);
    }
    // 两格填空都要求"定过原点":没定原点时他手上那套坐标算出来的 g 不是这一格问的 g,
    // 基准那件事由 pj-origin-late 去扣,不在这里抢同一个错(所以那种情形是"这道题没出"、
    // 判据不响,不是判"没交")。应有值一律取 drop,不取标签上那个 y —— 见 ProjectileGProcedure
    // 的入参契约(Controller Ruling I)。
    // g 那一格只要一对 (x, y) 就出得来,描了一个点就问;段比按 spec §6 的边界要凑得出三个点
    // 才问 —— 两个点上"等时间间隔相邻两段之比"还没谈得上检验,宁可不出这道题(不扣分),
    // 也不要拿一个学生没处核对的数去判他。
    if (this.originSet) {
      this.checkNumber(sheet, 'pjG', this.gFromDrop(), this.gPrintsFromDrop(), 3);
    }
    // 段比这一格再多一道门:点混了两套基准时**不出这道题**,与 pjXGapRatio、pjRatioErr
    // 那两条读数是同一个理由(`mixedBaseline()`)。它的窗口按存下来的 x 挑"离槽口最近的
    // 两个点",而 x 在挂线前后是两套基准(板角 vs 抛出点),跨基准挑出来的那两个点根本不是一条
    // 抛物线上的邻居 —— 拿这个窗口量出的数去判人"算错了",会把你自己的判词写矛盾:
    // 判词一边说"相邻两段之比才是 1:3:5",一边报一个 1:3:5 里根本不该出现的"应为 0.44"。
    // 学生照课本答 3 反而被扣 20 分,这是本项目最不能有的错法(Controller Ruling I 的同一条理由)。
    if (this.originSet && !this.mixedBaseline() && this.points.length >= 3) {
      this.checkNumber(sheet, 'pjSegRatio', this.segRatio(), this.segRatioPrints(), 3);
    }
    sheet.mark('traced', this.points.length > 0 ? 0 : -1);
  }

  snapshot(): WorldSnapshot {
    this.snap.clear();

    // 木板与白纸
    const paper = new BoxShape();
    paper.cx = (CORNER_X + BOARD_X1) / 2;
    paper.cy = (CORNER_Y + BOARD_Y1) / 2;
    paper.w = BOARD_X1 - CORNER_X;
    paper.h = BOARD_Y1 - CORNER_Y;
    paper.color = C_BOARD;
    this.snap.boxes.push(paper);
    this.snap.frontSegments.push(this.line(CORNER_X, CORNER_Y, BOARD_X1, CORNER_Y, C_FRAME, 5));
    this.snap.frontSegments.push(this.line(CORNER_X, BOARD_Y1, BOARD_X1, BOARD_Y1, C_FRAME, 5));
    this.snap.frontSegments.push(this.line(CORNER_X, CORNER_Y, CORNER_X, BOARD_Y1, C_FRAME, 5));
    this.snap.frontSegments.push(this.line(BOARD_X1, CORNER_Y, BOARD_X1, BOARD_Y1, C_FRAME, 5));
    this.snap.segments.push(this.line(0.15, FLOOR_Y, 4.6, FLOOR_Y, C_FRAME, 4));

    // 斜槽:三段折线,末端水平 —— 槽口水平是这条实验的前提
    this.snap.frontSegments.push(this.line(0.45, 3.62, 0.72, 3.15, C_RAMP, 6));
    this.snap.frontSegments.push(this.line(0.72, 3.15, 0.95, 2.86, C_RAMP, 6));
    this.snap.frontSegments.push(this.line(0.95, 2.86, EXIT_X + 0.06, 2.81, C_RAMP, 6));
    this.snap.frontSegments.push(this.line(0.45, 3.5, 0.45, 2.86, C_RAMP, 3));

    // 释放位置:第 slot 格画一只待放的球,槽口那格画得实一些
    const restY = 3.5 - this.slot * 0.18;
    const rest = new CircleShape();
    rest.cx = 0.62;
    rest.cy = restY;
    rest.r = 0.09;
    rest.color = C_BALL;
    this.snap.circles.push(rest);

    // 飞行中的球
    if (this.flight !== -1) {
      const t = this.flightT < this.flightDur ? this.flightT : this.flightDur;
      const ball = new CircleShape();
      ball.cx = EXIT_X + this.v0() * t;
      ball.cy = EXIT_Y - 0.5 * G * t * t;
      ball.r = 0.09;
      ball.color = C_BALL;
      this.snap.circles.push(ball);
    }

    // 重垂线:标定过原点才挂得出来(它就是用来定那条竖直线的)
    if (this.originSet) {
      const plumb = new SegmentShape();
      plumb.x1 = EXIT_X;
      plumb.y1 = EXIT_Y + 0.25;
      plumb.x2 = EXIT_X;
      plumb.y2 = CORNER_Y + 0.05;
      plumb.color = C_PLUMB;
      plumb.widthMm = 2;
      plumb.dashed = true;
      this.snap.frontSegments.push(plumb);
      const knot = new CircleShape();
      knot.cx = EXIT_X;
      knot.cy = EXIT_Y;
      knot.r = 0.05;
      knot.color = C_PLUMB;
      this.snap.circles.push(knot);
    }

    // 卡片:摆在第 card 格那条竖线上,孔心跟着轨迹走
    // 球飞不到那一格时卡片贴地放着 —— 它比落点还远,本来就该接不到球
    const cardX = EXIT_X + this.cardDistance();
    this.snap.frontSegments.push(this.line(cardX, EXIT_Y + 0.3, cardX, CORNER_Y + 0.05, C_CARD, 2));
    const holeY = EXIT_Y - 0.5 * G * Math.pow(this.cardDistance() / this.v0(), 2);
    const slotCard = new BoxShape();
    slotCard.cx = cardX;
    slotCard.cy = holeY < FLOOR_Y + 0.11 ? FLOOR_Y + 0.11 : holeY;
    slotCard.w = 0.26;
    slotCard.h = 0.18;
    slotCard.color = C_CARD;
    this.snap.boxes.push(slotCard);

    // 描下来的点
    for (let i = 0; i < this.points.length; i++) {
      const p = this.points[i];
      const dot = new CircleShape();
      dot.cx = this.originSet ? EXIT_X + p.x : p.x + CORNER_X;
      dot.cy = this.originSet ? EXIT_Y - p.y : p.y + CORNER_Y;
      dot.r = 0.05;
      dot.color = C_DOT;
      this.snap.circles.push(dot);
      // 标签要说清它是按哪套基准量出来的:没挂重垂线时那个数是板角基准下的 y,不是下落距离。
      // 把它光秃秃地印成 y=…,就等于应用替学生把错的基准认成了对的(Controller Ruling I)。
      const shown = (p.y * 1000).toFixed(1);
      this.snap.labels.push(this.text(p.beforeOrigin ? 'y（按板角）=' + shown : 'y=' + shown,
        dot.cx + 0.09, dot.cy - 0.11, 'left', 10));
    }

    this.snap.labels.push(this.text('斜槽 ×' + this.slot, 0.3, 3.78, 'left', 11));
    this.snap.labels.push(this.text('卡片第 ' + this.card + ' 格', cardX - 0.28, CORNER_Y - 0.28, 'left', 11));
    if (!this.originSet) {
      this.snap.labels.push(this.text('未挂重垂线:坐标只能按板角量', 1.6, BOARD_Y1 - 0.35, 'left', 11));
    }
    if (this.missed) {
      this.snap.labels.push(this.text('球落在卡片之前,这次没描上点', 1.6, CORNER_Y + 0.55, 'left', 11));
    }
    return this.snap;
  }

  private text(content: string, x: number, y: number, align: string, sizeVp: number): LabelShape {
    const label = new LabelShape();
    label.text = content;
    label.x = x;
    label.y = y;
    label.align = align;
    label.sizeVp = sizeVp;
    label.color = C_TEXT;
    return label;
  }

  private line(x1: number, y1: number, x2: number, y2: number,
    color: string, widthMm: number): SegmentShape {
    const seg = new SegmentShape();
    seg.x1 = x1;
    seg.y1 = y1;
    seg.x2 = x2;
    seg.y2 = y2;
    seg.color = color;
    seg.widthMm = widthMm;
    return seg;
  }

  /** 槽口速度只由释放格数决定:这就是"必须从同一位置静止释放"的理由所在 */
  static v0At(slot: number): number {
    return Math.sqrt(2 * G * slot * SLOT_STEP);
  }

  private v0(): number {
    return ProjectileRunner.v0At(this.slot);
  }

  private cardDistance(): number {
    return this.card * CARD_STEP;
  }

  /** 从槽口到落地 */
  private fallTime(): number {
    return Math.sqrt(2 * (EXIT_Y - FLOOR_Y) / G);
  }

  /** 这一次能飞多远 */
  private range(): number {
    return this.v0() * this.fallTime();
  }

  private earlyMarks(): number {
    let n = 0;
    for (let i = 0; i < this.points.length; i++) {
      if (this.points[i].beforeOrigin) {
        n++;
      }
    }
    return n;
  }

  /** 描这些点用过的释放位置最大差几格:0 才是"每次都从同一位置静止释放" */
  private slotSpread(): number {
    if (this.points.length < 2) {
      return 0;
    }
    let low = this.points[0].slot;
    let high = low;
    for (let i = 1; i < this.points.length; i++) {
      if (this.points[i].slot < low) {
        low = this.points[i].slot;
      }
      if (this.points[i].slot > high) {
        high = this.points[i].slot;
      }
    }
    return high - low;
  }

  /** 相邻水平间隔的最大/最小:接近 1 才叫等间隔,量得出竖直方向 1:3:5 */
  private gapRatio(): number {
    if (this.mixedBaseline()) {
      return Number.NaN;
    }
    const xs = this.sortedX();
    if (xs.length < 3) {
      return Number.NaN;
    }
    let low = Number.POSITIVE_INFINITY;
    let high = 0;
    for (let i = 0; i + 1 < xs.length; i++) {
      const gap = xs[i + 1] - xs[i];
      if (gap < low) {
        low = gap;
      }
      if (gap > high) {
        high = gap;
      }
    }
    if (low <= 1e-9) {
      return Number.POSITIVE_INFINITY;
    }
    return high / low;
  }

  /**
   * y/x² 的相对离散(百分比):这条实验自己该做的检验。
   *
   * 只当读数摆在面板上,不做判分 —— 定过原点、释放位置一致时它是 0,
   * 也就是说这条数只能被 ②③ 两条带着走,拿它当判据就是留一条永远跟着别人响的判据。
   */
  private ratioScatter(): number {
    if (this.points.length < 2 || this.mixedBaseline()) {
      return Number.NaN;
    }
    let low = Number.POSITIVE_INFINITY;
    let high = 0;
    let any = false;
    for (let i = 0; i < this.points.length; i++) {
      const p = this.points[i];
      if (p.x <= 1e-6) {
        continue;
      }
      const ratio = p.y / (p.x * p.x);
      any = true;
      if (ratio < low) {
        low = ratio;
      }
      if (ratio > high) {
        high = ratio;
      }
    }
    if (!any || high <= 0) {
      return Number.NaN;
    }
    return (high - low) / high * 100;
  }

  private sortedX(): number[] {
    const xs: number[] = [];
    for (let i = 0; i < this.points.length; i++) {
      xs.push(this.points[i].x);
    }
    return xs.sort((a: number, b: number): number => a - b);
  }

  /**
   * 按离槽口的远近排好的**真实下落**序列(米)。
   *
   * 两件事都在这里定死:① 顺序按 x 排,不按描点先后(学生完全可能先把卡片摆到第 4 格);
   * ② 取的是 `drop` 而不是 `y` —— ProjectileGProcedure 的入参契约要的是"从槽口算起的那套 y",
   * 挂线之前描下的点存的是板角基准坐标,拿它当从槽口算起的下落,等于应用把错的基准供认成
   * 应有值(Controller Ruling I 同一条理由,段比这一格也适用)。
   */
  private sortedDrop(): number[] {
    const order: number[] = [];
    for (let i = 0; i < this.points.length; i++) {
      order.push(i);
    }
    order.sort((a: number, b: number): number => this.points[a].x - this.points[b].x);
    const out: number[] = [];
    for (let i = 0; i < order.length; i++) {
      out.push(this.points[order[i]].drop);
    }
    return out;
  }

  /**
   * 描的点是不是混了两套基准:挂重垂线之前按板角量、之后按抛出点量。
   * 混了就没有任何"水平间隔"或 y/x² 可言,这两条读数一律不给值,
   * 而不是拿一个把基准问题算成间隔问题的假数去扣分。
   */
  private mixedBaseline(): boolean {
    const early = this.earlyMarks();
    return early > 0 && early < this.points.length;
  }
}
