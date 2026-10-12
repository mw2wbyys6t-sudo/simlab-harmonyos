import { Profile } from '../geometry/Profile';
import { Footprint, Pose, Support } from './Pose';

/**
 * 容器的共用外壳:几何、位姿、支撑状态与器底损伤。
 *
 * 刻意**不含内容物账本**。提纯链路按「相」记账(水 / 已溶盐 / 未溶盐 / 悬浮砂 / 沉底砂,
 * 随溶解、沉降、过滤、蒸发演化),反应链路按「试剂键 → 摩尔」记账(随化学计量反应)。
 * 两者不是同一件事的两种写法,强行并成一套要么丢掉整张反应表,要么给 NaCl 编出一个
 * 不存在的试剂键。真正重复的只有外壳,所以合并到这一层为止。
 *
 * 这里的算法一律**收体积作参数**(`liquidHeightFor(volumeMl)` 而不是 `liquidHeight()`):
 * 外壳不知道也不该知道账本长什么样,两个子类各自传自己的液体量进来。
 */
export class VesselBase {
  id: string = '';
  label: string = '';
  profile: Profile = Profile.cylinder(10, 5);
  pose: Pose = new Pose();
  support: Support = Support.TABLE;
  /** 是否正在被搅拌(玻璃棒在体系内往复运动) */
  stirred: boolean = false;
  /**
   * 器底损伤程度,0 = 完好,1 = 砸穿。
   *
   * 取连续值而不是布尔:「裂而未破」与「砸穿」在真实操作里都存在。
   * 它同时就是本次漏走的内容物比例,所以不再另设一个漏失系数 —— 少一个系数就少一处拍脑袋。
   */
  damage: number = 0;

  /** 指定液体体积对应的液面高度(cm) */
  liquidHeightFor(volumeMl: number): number {
    return this.profile.heightForVolume(VesselBase.real(volumeMl, 0));
  }

  /** 指定液体体积下的液面表面积(cm²)。蒸发快慢由它决定,所以必须是几何算出来的 */
  surfaceAreaFor(volumeMl: number): number {
    return this.profile.areaAt(this.liquidHeightFor(volumeMl));
  }

  /** 指定液体体积下还剩多少容积(mL),不会为负 */
  freeCapacityFor(volumeMl: number): number {
    const free = this.profile.capacity() - VesselBase.real(volumeMl, 0);
    return free > 0 ? free : 0;
  }

  /** 口部等效圆半径(cm),由口部截面积反算 */
  rimHalfWidth(): number {
    const area = this.profile.areaAt(this.profile.totalHeight() - 0.05);
    return Math.sqrt(area / Math.PI);
  }

  /** 占位:空间关系判定的输入 */
  footprint(): Footprint {
    return Footprint.of(this.pose.x, this.pose.y, this.rimHalfWidth());
  }

  /** 只有握在手里才可能倒出东西;放桌上的瓶子不会自己流水 */
  canPour(): boolean {
    return this.support === Support.HELD;
  }

  /**
   * 沿容器轴距离器底 atAxialCm 处释放的物体,落到器底前的**竖直**落差(cm)。
   *
   * 这一个量把「一横二放三慢竖」和「直立着丢下去」分开:横放时 sin 0 = 0,块体沿壁滑下,
   * 竖直方向几乎没有位移;直立时落差就是那段轴向距离。调用方给轴向距离,外壳给投影,
   * 谁都不用自己偷偷乘一个 sin。
   */
  verticalDropCm(atAxialCm: number): number {
    const distance = VesselBase.real(atAxialCm, 0);
    const tilt = VesselBase.real(this.pose.tiltDeg, 0);
    const drop = distance * Math.sin(tilt * Math.PI / 180);
    return drop > 0 ? drop : 0;
  }

  /** 该漏走多少比例的内容物。损伤程度即比例 */
  leakFraction(): number {
    const value = VesselBase.real(this.damage, 0);
    if (value < 0) {
      return 0;
    }
    return value > 1 ? 1 : value;
  }

  private static real(value: number, fallback: number): number {
    return Number.isFinite(value) ? value : fallback;
  }
}
