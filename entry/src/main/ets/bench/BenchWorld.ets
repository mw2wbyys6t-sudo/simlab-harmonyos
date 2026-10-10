import { ExperimentMeta } from '../model/ExperimentTypes';
import { IExperimentRunner } from '../runner/IExperimentRunner';
import { FactSheet } from './Rubric';
import { Glassware, Profile } from './Profile';
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
    if (this.cylinder.isFull() || this.reagent.brine.waterMl <= 1e-9) {
      this.ended = true;
    }
  }

  reset(): void {
    this.setup(this.meta);
  }

  setParam(key: string, value: number): void {
    this.params.set(key, value);
  }

  getParam(key: string): number {
    return this.readParam(key);
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

  spilledMl(): number {
    return this.cylinder.brine.losses.spilledWaterMl;
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
