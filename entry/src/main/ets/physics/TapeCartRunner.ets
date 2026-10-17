import { FactSheet } from '../model/FactSheet';
import { InclineRunner } from './InclineRunner';
import { WorldSnapshot } from './World2D';
import { TickerTape } from './TickerTape';
import { TAPE_SCALE, TapeStrip } from './TapeStrip';
import { TapeChunkProcedure } from './TapeChunkProcedure';

/** 纸带画在世界顶部这一条上:斜面最长 5 m、60° 时顶点在 4.9 m 以下,互不遮挡 */
const TAPE_Y = 4.9;
const TAPE_X = 0.8;

/**
 * 拖着纸带做匀加速的小车:斜面动力学复用 InclineRunner,新加的是打点计时器。
 *
 * 这里把"运动"和"记录"拆成两个由学生分别按下的动作 —— 先接通电源还是先释放小车,
 * 是这条实验真正的扣分点,也是唯一能当场量出来的那一个:释放与接通之间那段运动
 * 没被打下来,纸带头上就是空的。合成一条"开始"按钮就没有这个事实可读了。
 */
export class TapeCartRunner extends InclineRunner {
  protected tape: TickerTape = new TickerTape();
  /**
   * 撞上板尾那一格打下来的最后一个点号,没撞上则是 -1。
   *
   * 逐差法的窗口要它才能判断"最后一段是不是被板尾截短的":车到底端时 `s` 被夹在
   * 板长上,那一格的位移比该走的间隔少一截,量出来就是最短的那一段。这个信号只能由
   * runner 报(Controller Ruling L 修正),拿段长数组自己猜会把完好窗口也切掉一段。
   */
  private clipDot: number = -1;

  protected onSetup(): void {
    super.onSetup();
    this.tape.reset();
    this.clipDot = -1;
  }

  step(dt: number): void {
    if (!this.tape.isReleased()) {
      // 车还没放开:时间在走,位移不动。电源此时打出来的是一段重叠点(车静止)
      this.time += dt;
      this.tape.tick(this.time, this.readObservable('distance'), 0, 0);
      return;
    }
    const dotsBefore = this.tape.count();
    super.step(dt);
    this.tape.tick(this.time, this.readObservable('distance'),
      this.readObservable('velocity'), this.readObservable('acceleration'));
    if (this.clipDot < 0 && this.finished()) {
      // 只有这一格真的打下了一个点,截断才落到纸面上(时刻还没到就没打出来的点不受影响)
      this.clipDot = this.tape.count() > dotsBefore ? this.tape.count() - 1 : -1;
    }
  }

  protected onAction(key: string): void {
    if (key === 'power') {
      this.tape.setPower(!this.tape.isPowered(), this.time);
      return;
    }
    if (key === 'release') {
      this.tape.release(this.time);
    }
  }

  readObservable(key: string): number {
    switch (key) {
      case 'tapeDotCount':
        return this.tape.count();
      case 'tapeLostHead':
        return this.tape.lostHeadDots();
      case 'tapeSegments':
        return this.tape.segmentCount(this.startDot(), this.everyGap());
      case 'tapeChunkStart':
        // Ruling N:滑杆写的是一个数,应用量的是另一个 —— 把夹住后的有效起点露出来,
        // 学生才知道"应有值"凭什么从第 76 个点起,而不是照滑杆上的 40 去对段。
        return this.startDot();
      case 'tapeChunkSegments':
        // 奇数段窗口的尾段不进运算(截到 2h 整)。这个数不给,填空里的"后一半"就只能靠猜。
        return this.chunkUsedCount();
      case 'tapeShortestMm':
        return this.tape.shortestSegment(this.startDot(), this.everyGap()) * 1000;
      case 'tapeSpanMm':
        return this.tape.tapeLength() * 1000;
      case 'tapeEveryMs':
        return this.everyGap() / this.tape.hz * 1000;
      default:
        return super.readObservable(key);
    }
  }

  protected onCollectFacts(sheet: FactSheet): void {
    const start = this.startDot();
    const every = this.everyGap();
    const win = this.chunkWindowMm();
    // 两问都读同一个窗口:应有值必须是学生手上那条纸带的应有值
    this.checkNumber(sheet, 'tapeNumerator', TapeChunkProcedure.numerator(win),
      TapeChunkProcedure.fingerprints(win), 3);
    this.checkNumber(sheet, 'tapeDenFactor', TapeChunkProcedure.denFactor(win),
      TapeChunkProcedure.denPrints(win), 0);
    sheet.set('tapeDotCount', this.tape.count());
    sheet.set('tapeLostHead', this.tape.lostHeadDots());
    sheet.set('tapeSegments', this.tape.segmentCount(start, every));
    // 应用口径两格:应有值是从哪个点量起、有几段真的进了逐差 —— 判据要在判词里报给学生
    sheet.set('tapeChunkStart', start);
    sheet.set('tapeChunkSegments', this.chunkUsedCount());
    const shortest = this.tape.shortestSegment(start, every);
    if (Number.isFinite(shortest)) {
      sheet.set('tapeShortestMm', shortest * 1000);
    }
    sheet.mark('taped', this.tape.count() > 0 ? this.time : -1);
  }

  snapshot(): WorldSnapshot {
    const snap = super.snapshot();
    TapeStrip.paint(snap, this.tape, TAPE_X, TAPE_Y, this.startDot(), this.everyGap(),
      '纸带 · 点距按 ' + String(TAPE_SCALE) + ' 倍展开');
    return snap;
  }

  /**
   * 逐差法那两问用的段长窗口(Controller Ruling H / L)。
   *
   * 两道处理,顺序与理由都记在这里:
   * ① 起点由 startDot() 夹到 movingStart() —— 通电而未放车那一段点全叠在原地,刻度尺
   *    量出来是 0 mm,它压根不该进窗口(照做 summary 那句"舍开头密着的那一段"的人
   *    不该被判"算错");
   * ② 小车撞到板尾、且最后一段正好压在撞板尾那一格打出的点上时,丢掉那一段 —— 它是被
   *    "s = 板长"夹短的。条件性丢:无条件丢尾巴会把 27% 本来完好的窗口也切掉一段,
   *    还会破掉 spec §5 钉死的那张样例表;
   * ③ 剩下的交给 procedure:它自己再过一次 liveFrom(舍死头、把尾部截到 2h 整),
   *    这一步是幂等的,这里舍过的头不会被再舍一遍。
   */
  protected chunkWindowMm(): number[] {
    const start = this.startDot();
    const every = this.everyGap();
    const seg = this.tape.segmentsMm(start, every);
    if (!this.tailClipped(start, every, seg.length)) {
      return seg;
    }
    const out: number[] = [];
    for (let i = 0; i + 1 < seg.length; i++) {
      out.push(seg[i]);
    }
    return out;
  }

  /** 最后一段的终点就是撞上板尾那一格打出的点 → 这一段被截短了,不该拿去逐差 */
  private tailClipped(start: number, every: number, segments: number): boolean {
    return this.clipDot >= 0 && segments > 0 && start + segments * every === this.clipDot;
  }

  /**
   * 参与逐差法的段数(= 2h,Controller Ruling N)。
   *
   * 窗口再过一遍 liveFrom:奇数段时末尾凑不满一对的那段不进运算。这个数与
   * `tapeSegments` 可以不同 —— 差在哪、应用凭什么这么算,必须作为读数给学生,
   * 否则"后一半 减 前一半"在 13 段这种窗口上只能靠猜,按另一种口径算的人会被判错。
   */
  private chunkUsedCount(): number {
    return TapeChunkProcedure.liveFrom(this.chunkWindowMm()).length;
  }

  /**
   * 计数起点:学生选的起点与"头上那段重叠点"取更靠后的那个。
   *
   * 量不到的段不进量窗 —— 与 NewtonSecondRunner.startDot() 同一条先例(Ruling H 实测
   * 过:不夹住的话,窗口前 7 段全是 0 mm,反推的 a 会从 0.879 掉到 0.705)。
   */
  private startDot(): number {
    const raw = this.readParam('countStart');
    const from = raw < 0 ? 0 : Math.floor(raw);
    const moving = this.tape.movingStart();
    return from > moving ? from : moving;
  }

  /** 每几个点取一个计数点。参数是滑杆给的浮点,这里一律收成不小于 1 的整数 */
  private everyGap(): number {
    const raw = this.readParam('countEvery');
    return raw < 1 ? 1 : Math.floor(raw);
  }

  private readParam(key: string): number {
    const value = this.getParam(key);
    return Number.isFinite(value) ? value : 0;
  }
}
