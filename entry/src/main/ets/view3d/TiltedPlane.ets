import { Profile } from '../geometry/Profile';

/** 液面边界上的一点：器坐标里的轴上高度与半径，单位 cm */
export class SurfacePoint {
  hCm: number = 0;
  radiusCm: number = 0;
}

/**
 * 倾斜时器内自由面的几何。
 *
 * 器身绕屏幕横轴倾 α 之后，器内的自由面就不再是「等高面」，而是世界水平面斜切回转体，
 * 所以 heightForVolume 那一套在这里不再适用。本模块只回答三个数：某个世界高度的平面
 * 切出的液体体积、给定体积对应的自由面世界高度、以及圆盘被一条直线割掉一块后的面积。
 *
 * 推导：器坐标 (h, ρ, φ) 里 φ=0 是正对观察者的一侧，绕屏幕横轴倾 α 后世界高度
 *   Y = h·cosα − ρ·cosφ·sinα
 * 于是「液面以下」就是 Y ≤ 平面高度 Z，即 ρ·cosφ·sinα ≥ h·cosα − Z。
 * 每个截面圆盘被一条垂直于视线的直线割成两段，割线到圆心的有向距离
 *   d(h) = (h·cosα − Z) / sinα
 * 浸没的那块就是一个圆缺 —— 体积就是圆缺面积沿轴线的累加。
 *
 * α = 0 单独走 Profile 现成的算法，不是近似：一是那条分界线本身就退化成等高面，
 * 二是这样能保证「不倾斜时画出来的液面」和「判定层算出的液面」是同一个数。
 * 取点用段底而不是段中，也是同一个理由：与 Profile.volumeBelow 对齐，倾斜一开始液面不跳变。
 *
 * 刻意不 import 任何 @kit 类型（不变量 I3），全部算法可被离线断言直接实例化。
 */
export class TiltedPlane {
  /** |sinα| 小于这个数就当平放处理：此时 d(h) 要除以近乎零，误差会盖过形状本身 */
  private static readonly FLAT_SIN: number = 1e-12;
  /** 二分次数。区间宽度 2·(器高+半径)，40 次已经远小于 Profile 的 0.1 cm 分段 */
  private static readonly BISECTIONS: number = 48;

  /**
   * 半径 r 的圆盘被直线 ρ·cosφ = d 割开后，靠 d 正方向那一侧（含 φ=0 的近侧点）的面积。
   *
   * d ≥ r 时是空盘，d ≤ −r 时是整盘，中间取标准圆缺公式。
   */
  static segmentArea(radiusCm: number, distanceCm: number): number {
    const r = radiusCm > 0 ? radiusCm : 0;
    if (r === 0) {
      return 0;
    }
    if (distanceCm >= r) {
      return 0;
    }
    if (distanceCm <= -r) {
      return Math.PI * r * r;
    }
    const t = distanceCm / r;
    return r * r * (Math.acos(t) - t * Math.sqrt(Math.max(0, 1 - t * t)));
  }

  /** 世界高度 Z 的水平面切出的液体体积(mL)。不检查是否已漫出器口，那是世界层的事 */
  static volumeBelowPlane(profile: Profile, tiltDeg: number, planeWorldCm: number): number {
    const areas = profile.areas;
    const seg = profile.segHeight;
    if (areas.length === 0 || seg <= 0) {
      return 0;
    }
    const rad = tiltDeg * Math.PI / 180;
    const sin = Math.sin(rad);
    const cos = Math.cos(rad);
    if (Math.abs(sin) < TiltedPlane.FLAT_SIN) {
      return profile.volumeBelow(planeWorldCm);
    }
    let volume = 0;
    for (let i = 0; i < areas.length; i++) {
      const area = areas[i];
      if (area <= 0) {
        continue;
      }
      const r = Math.sqrt(area / Math.PI);
      const d = (i * seg * cos - planeWorldCm) / sin;
      const near = TiltedPlane.segmentArea(r, d);
      // sinα < 0 时不等式方向反过来，浸没的是割线的另一侧
      const submerged = sin > 0 ? near : Math.PI * r * r - near;
      volume += submerged * seg;
    }
    return volume;
  }

  /**
   * 给定液体体积，解出自由面的世界高度(cm)。
   *
   * 体积对平面高度单调不减，所以直接二分。无解的两端夹到「刚好全空 / 刚好全满」。
   */
  static planeForVolume(profile: Profile, tiltDeg: number, volumeMl: number): number {
    const areas = profile.areas;
    const seg = profile.segHeight;
    if (areas.length === 0 || seg <= 0) {
      return 0;
    }
    const rad = tiltDeg * Math.PI / 180;
    const sin = Math.sin(rad);
    const cos = Math.cos(rad);
    if (Math.abs(sin) < TiltedPlane.FLAT_SIN) {
      return profile.heightForVolume(volumeMl);
    }

    const capacity = profile.capacity();
    const target = volumeMl < 0 ? 0 : (volumeMl > capacity ? capacity : volumeMl);
    // 器内世界高度的两个极值:同一张截面上最高/最低点相差 r·|sinα|
    const absSin = Math.abs(sin);
    let low = 0;
    let high = 0;
    let first = true;
    for (let i = 0; i < areas.length; i++) {
      const r = Math.sqrt(Math.max(0, areas[i]) / Math.PI);
      const h = i * seg * cos;
      const top = h + r * absSin;
      const bottom = h - r * absSin;
      if (first) {
        low = bottom;
        high = top;
        first = false;
      } else {
        low = bottom < low ? bottom : low;
        high = top > high ? top : high;
      }
    }
    low -= 1;
    high += 1;

    let lo = low;
    let hi = high;
    for (let k = 0; k < TiltedPlane.BISECTIONS; k++) {
      const mid = (lo + hi) / 2;
      if (TiltedPlane.volumeBelowPlane(profile, tiltDeg, mid) < target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /** 液面边界上方位角 φ 处的点(切片 2 的实现目标) */
  static surfacePoint(profile: Profile, tiltDeg: number, planeWorldCm: number,
    phiDeg: number): SurfacePoint {
    const out = new SurfacePoint();
    const areas = profile.areas;
    const seg = profile.segHeight;
    const total = profile.totalHeight();
    if (areas.length === 0 || !(seg > 0) || !(total > 0)) {
      out.hCm = 0;
      out.radiusCm = 0;
      return out;
    }
    const rad = tiltDeg * Math.PI / 180;
    const sin = Math.sin(rad);
    const cos = Math.cos(rad);
    const c = Math.cos(phiDeg * Math.PI / 180);
    // 这里不为 α=0 开特判:通用循环在 sinα=0 时偏移项直接为 0,解出的就是 h = Z、半径取该处的
    // 台阶值,和专用分支逐位相同(把分支删掉后全部断言仍绿,这就是当场验过的证据)。
    // 上面 volumeBelowPlane 必须有特判,是因为那里要除以 sinα,平放时会得到 0/0。

    // 母线上的世界高度 Y(h) = h·cosα − r(h)·c·sinα。Profile 的半径是分段常量,所以每段内
    // Y 对 h 是斜率 cosα > 0 的直线,段内交点直接解出,不需要求根器:
    //   h* = (Z + r_i·c·sinα) / cosα
    // 要的是「最高的那个湿润点」,所以逐段取候选再比大小,而不是找到第一个就返回:
    // 器壁是分段的台阶,半径随高度变(烧杯上口大、锥形瓶收颈、试管半球底),
    // 于是 Y 在段界上不连续、整体并不单调 —— 在中段解出「交点高于本段」并不说明这条母线全湿。
    // 候选只取严格落在段内的交点,这样半径与 Profile.radiusAt(h) 用的是同一段,共面性就是代数恒等。
    let bestH = -1;
    for (let i = 0; i < areas.length; i++) {
      const r = Math.sqrt(Math.max(0, areas[i]) / Math.PI);
      const low = i * seg;
      const high = low + seg;
      const offset = r * c * sin;
      const yLow = low * cos - offset;
      const yHigh = high * cos - offset;
      if (yHigh <= planeWorldCm) {
        if (high > bestH) {
          bestH = high;
        }
      } else if (yLow <= planeWorldCm) {
        const hit = (planeWorldCm + offset) / cos;
        if (hit > bestH) {
          bestH = hit;
        }
      }
    }
    if (bestH >= 0) {
      out.hCm = bestH;
      // 半径读回 Profile:绘制器的器身轮廓用的就是这条台阶函数,边界点必须贴在画出来的那条线上,
      // 而不是贴在另一个台阶上 —— 否则液面会有一处超出器身。代价是共面性差一个台阶(见下)。
      out.radiusCm = profile.radiusAt(bestH);
      return out;
    }

    // 走到这里说明连器底那条母线都在平面之上 —— 自由面从这个方位是从**器底**穿出的。
    // 器底上 Y = −ρ·c·sinα,解出 ρ = −Z/(c·sinα);落在盘外就夹到最近的点(该方位其实无交点)。
    const r0 = profile.radiusAt(0);
    const denom = c * sin;
    if (Math.abs(denom) < TiltedPlane.FLAT_SIN) {
      out.hCm = 0;
      out.radiusCm = 0;
      return out;
    }
    let rho = -planeWorldCm / denom;
    if (rho < 0) {
      rho = 0;
    }
    if (rho > r0) {
      rho = r0;
    }
    out.hCm = 0;
    out.radiusCm = rho;
    return out;
  }
}
