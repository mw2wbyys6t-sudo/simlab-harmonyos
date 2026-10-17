import { ExperimentMeta } from '../model/ExperimentTypes';
import { IExperimentRunner } from '../runner/IExperimentRunner';
import { FactSheet } from '../model/FactSheet';
import { Glassware, Profile } from '../geometry/Profile';
import { Calibration } from './Brine';
import { Container, PourModel, ReadingModel } from './Container';
import { Support } from './Pose';

/**
 * 量取训练的世界。
 *
 * 实现既有的 `IExperimentRunner` 契约,因此定步长累加、掉帧补偿、采样与抽稀
 * 全部复用 `RunController` —— 液面推进与弹簧振子同属「随时间演化的确定性世界」。
 *
 * 本类不 import 任何 ArkUI 类型(不变量 I3):量筒的画面由 ArkUI 组件按
 * 这里暴露的数值投影而成,判据一律来自数值,不来自画面。
 */
export class BenchWorld implements IExperimentRunner {
  private reagent: Container = Container.of('reagent', '试剂瓶', Glassware.beaker100());
  private cylinder: Container = Container.of('cylinder', '量筒', Glassware.graduatedCylinder10());
  private meta: ExperimentMeta = new ExperimentMeta();
  private time: number = 0;
  private ended: boolean = false;
  private pouredMl: number = 0;
  private missedMl: number = 0;

  setup(meta: ExperimentMeta): void {
    this.meta = meta;
    this.time = 0;
    this.ended = false;
    this.pouredMl = 0;
    this.missedMl = 0;
    this.answers.clear();
    this.cylinder = Container.of('cylinder', '量筒', Glassware.graduatedCylinder10());
    this.reagent = Container.of('reagent', '试剂瓶', Glassware.beaker100());
    // 试剂瓶不该装到瓶口:满瓶一歪,液面就被器沿夹住,「液面保持水平」这件事在屏幕上根本看不见。
    // 七成是实验室里一瓶试剂的正常样子,也留出了整场量取要倒的十倍量还多的余量。
    this.reagent.brine.waterMl = this.reagent.profile.capacity() * 0.7;
    // 量取训练里瓶子始终握在手中;放在桌上的瓶子倒不出东西,那是另一条判据
    this.reagent.support = Support.HELD;
    this.reagent.pose.tiltDeg = this.readParam('tilt');
    this.cylinder.stirred = false;
  }

  /** 世界参数表由外壳通过 setParam 驱动,这里只存放与判据有关的量 */
  private params: Map<string, number> = new Map();

  /**
   * 学生交上来的处理结果。量取训练今天不出填空题,这张表正常是空的,但格子得存得住。
   * dispose() 刻意不清它:答案随 runner 实例走,量取页每次打开都是新实例(Controller Ruling E)。
   */
  private answers: Map<string, number> = new Map();

  private readParam(key: string): number {
    const hit = this.params.get(key);
    return hit === undefined ? 0 : hit;
  }

  step(dt: number): void {
    if (this.ended) {
      return;
    }
    this.reagent.pose.tiltDeg = this.readParam('tilt');
    // 水平偏移:模拟手没对准,液体就会洒在桌面上而不是进量筒
    this.reagent.pose.x = this.readParam('aim');
    const guided = this.readParam('guided') >= 0.5;
    const result = PourModel.step(this.reagent, this.cylinder, dt, guided);
    this.pouredMl += result.leftSourceMl;
    this.missedMl += result.missedTarget ? result.leftSourceMl : 0;
    this.time += dt;
    // 漫出就是"这一杯倒到头了"。终止条件原来写的是 cylinder.isFull(),但每一步的溅失
    // 都会把液面拉回筒口之下,那个条件永远不成立 —— 于是学生不停手就会把整瓶 70 mL 抽干,
    // 并读出几十毫升的"溅失"(#66)。
    if (result.overflowed || this.reagent.brine.waterMl <= 1e-9) {
      this.ended = true;
    }
  }

  reset(): void {
    this.setup(this.meta);
  }

  setParam(key: string, value: number): void {
    this.params.set(key, value);
    // Controller Ruling D:改了数据窗口就作废上一次的答案,与 Physics2DRunner 保持一致。
    this.answers.clear();
  }

  getParam(key: string): number {
    return this.readParam(key);
  }

  setAnswer(key: string, value: number): void {
    this.answers.set(key, value);
  }

  /** 没填就是 NaN:0 是一个合法答案,不能当缺省 —— 未知 key 同样读 NaN,不抛异常 */
  answer(key: string): number {
    const hit = this.answers.get(key);
    return hit === undefined ? Number.NaN : hit;
  }

  /** 学生主动收手:之后的判定就是终局判定 */
  stop(): void {
    this.ended = true;
  }

  /** 量取世界里学生能主动做的就这一件:收手。其余是连续操纵,归手势层(M6) */
  doAction(key: string): void {
    if (key === 'stop') {
      this.stop();
    }
  }

  /**
   * 事实仍由 MeasurePage 现读现算(它持有视线高度与读数视差那几项)。
   * 这里刻意不重复算一遍 —— 两处各算一份同一个数,迟早会漂成两个答案。
   */
  collectFacts(sheet: FactSheet): void {
  }

  finished(): boolean {
    return this.ended;
  }

  elapsedTime(): number {
    return this.time;
  }

  dispose(): void {
    this.params.clear();
  }

  goalMl(): number {
    const goal = this.readParam('goal');
    return goal <= 0 ? 10 : goal;
  }

  eyeHeight(): number {
    return this.readParam('eye');
  }

  /** 量筒的几何与内容,视图层据此画液面、刻度与视线 */
  cylinderProfile(): Profile {
    return this.cylinder.profile;
  }

  /**
   * 试剂瓶的几何与剩余量,视图层据此画那只**会歪**的瓶子。
   *
   * 三个读数是同一份世界状态的投影,不是第二套真相:I1 的守恒账仍在 `reagent.brine` 里,
   * 瓶子画矮一截就是液面真的降了一截。
   */
  reagentProfile(): Profile {
    return this.reagent.profile;
  }

  reagentVolumeMl(): number {
    return this.reagent.brine.waterMl;
  }

  /**
   * 倾倒仰角取**输入参数**,不取 `pose.tiltDeg`。
   *
   * `pose.tiltDeg` 是 `step()` 里从参数派生出来的:暂停时参数已经跟着滑杆变了,
   * pose 还停在上一帧的 0 —— 画它,瓶子就永远不歪(模拟器实测抓到)。
   * 参数才是这一帧的真值,而 `flowRate` 下一迈读到的也正是它,两边不会分家。
   */
  reagentTiltDeg(): number {
    return this.readParam('tilt');
  }

  /**
   * 洒出 = 离开试剂瓶的水 − 还留在量筒里的水。
   *
   * 原来读的是量筒自己的损失账本(`cylinder.brine.losses`),可"没对准、整股洒在桌面上"
   * 的那部分是直接从试剂瓶扣掉的,不进这个数 —— 屏幕上于是同时出现「实际 0.00 mL」和
   * 「洒失 0.00 mL」,而瓶里 71 mL 真的空了(#66)。按倒出量减实际量算,守恒是构造出来的。
   */
  spilledMl(): number {
    const lost = this.pouredMl - this.cylinder.brine.waterMl;
    return lost > 0 ? lost : 0;
  }

  readObservable(key: string): number {
    const actual = this.cylinder.brine.waterMl;
    switch (key) {
      case 'actual':
        return actual;
      case 'apparent':
        return ReadingModel.readVolume(this.cylinder.profile, actual, this.eyeHeight());
      case 'error':
        return actual - this.goalMl();
      case 'errorPct':
        return this.goalMl() <= 0 ? Number.NaN : (actual - this.goalMl()) / this.goalMl() * 100;
      case 'eyeOffset':
        return this.eyeHeight() - this.cylinder.liquidHeight();
      case 'poured':
        return this.pouredMl;
      case 'spilled':
        return this.spilledMl();
      case 'missed':
        return this.missedMl;
      case 'aimOffset':
        return Math.abs(this.reagent.pose.x - this.cylinder.pose.x);
      case 'tiltDeg':
        return this.reagent.pose.tiltDeg;
      case 'surfaceArea':
        return this.cylinder.surfaceArea();
      case 'onsetDeg':
        return Calibration.POUR_ONSET_DEG;
      default:
        return Number.NaN;
    }
  }
}
