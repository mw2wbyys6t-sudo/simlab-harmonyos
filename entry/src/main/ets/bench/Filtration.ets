import { Calibration, Separations } from './Brine';
import { Container, PourModel, PourResult } from './Container';
import { Glassware } from '../geometry/Profile';
import { Support } from './Pose';

/**
 * 过滤装置:漏斗 + 滤纸 + 下方接收烧杯。
 *
 * 这里要解决的核心问题是:**「液面高过滤纸边缘」的后果必须是算出来的**。
 * 早期版本里 `sandCarryFraction` 由测试手工传值,那等于我们把结论喂给了模型 ——
 * 现在它由液位几何决定:超出滤纸边缘的那部分体积不经过滤纸,直接从滤纸与
 * 漏斗壁的间隙直灌下去,并等比带走悬浮泥沙。
 */
export class FilterAssembly {
  funnel: Container = Container.of('funnel', '漏斗', Glassware.funnelStem());
  filtrate: Container = Container.of('filtrate', '接收烧杯', Glassware.beaker100());
  /**
   * 滤纸边缘相对漏斗底的高度(cm)。取 2.0 使滤纸容纳约 6.4 mL ——
   * 低于漏斗口(教材要求的「滤纸边缘低于漏斗口」),且一次倒入超过约 6.4 mL
   * 悬浊液就会涨过边缘。若把这里设得比倾倒总量还大,旁通永远不会发生,
   * 「漫过滤纸」这条判据就成了死代码。
   */
  paperRimHeight: number = 1.2;
  /** 是否用玻璃棒引流 */
  rodUsed: boolean = false;
  /** 玻璃棒是否轻抵三层滤纸一侧(空间关系,由操纵层写入) */
  rodOnTripleSide: boolean = false;
  /** 累计未经滤纸直灌的体积,直接作为扣分证据 */
  bypassedMl: number = 0;
  /**
   * 全程「液面高过滤纸边缘」的最大值。
   * 必须边流边记峰值:装置排空后液面归零,事后再量等于什么都没看见。
   */
  maxLevelOverRimCm: number = 0;
  /** 滤液是否已收集过(用于「滤液浑浊」判定) */
  drainedMl: number = 0;

  static of(): FilterAssembly {
    return new FilterAssembly();
  }

  /** 悬浊液倒入漏斗。未引流时溅失更大,由 PourModel 统一处理 */
  pourIntoFunnel(source: Container, dt: number): PourResult {
    return PourModel.step(source, this.funnel, dt, this.rodUsed);
  }

  /**
   * 抽滤速度由滤纸决定(演示标定);漫过滤纸边缘的部分按体积直接旁通。
   *
   * @returns 本步进入滤液的体积
   */
  drain(dt: number): number {
    const capacity = this.funnel.brine.waterMl;
    if (capacity <= 0) {
      return 0;
    }
    const drainVolume = Math.min(capacity, Calibration.FILTER_DRAIN_RATE * dt);
    if (drainVolume <= 0) {
      return 0;
    }

    const rimVolume = this.funnel.profile.volumeBelow(this.paperRimHeight);
    const aboveRim = Math.max(0, this.funnel.brine.waterMl - rimVolume);
    const over = this.funnel.liquidHeight() - this.paperRimHeight;
    if (over > this.maxLevelOverRimCm) {
      this.maxLevelOverRimCm = over;
    }
    const bypass = Math.min(drainVolume, aboveRim);
    const filtered = drainVolume - bypass;

    if (filtered > 0) {
      Separations.filter(this.funnel.brine, this.filtrate.brine, filtered, 0);
    }
    if (bypass > 0) {
      // 漫过边缘的那部分不经过滤纸:悬浮泥沙等比直穿
      Separations.filter(this.funnel.brine, this.filtrate.brine, bypass, 1);
      this.bypassedMl += bypass;
    }
    this.drainedMl += drainVolume;
    return drainVolume;
  }

  /** 漏斗内泥沙会沉降,沉底的部分既不会穿滤纸也不会被旁通冲走 */
  settle(dt: number): void {
    Separations.settle(this.funnel.brine, dt);
  }

  /** 液面高度与滤纸边缘的差值,正数即「漫过了」 */
  levelVsRim(): number {
    return this.funnel.liquidHeight() - this.paperRimHeight;
  }

  filtrateTurbidity(): number {
    return this.filtrate.brine.turbidity();
  }

  /** 装置作为一个整体是否被架在铁架台上(漏斗需要被支撑,不能悬空) */
  isPropped(): boolean {
    return this.funnel.support === Support.CLAMPED || this.funnel.support === Support.TABLE;
  }
}
