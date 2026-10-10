/** 器皿被什么撑着。这个状态本身就在产出考点,不需要另设「错误选项」。 */
export enum Support {
  /** 握在手里:可以倾倒,但不能稳定加热 */
  HELD = 'held',
  /** 放在桌面上:稳,倒不出东西 */
  TABLE = 'table',
  /** 被铁架台夹住:可以稳定加热,位置固定 */
  CLAMPED = 'clamped'
}

/** 位姿:桌面水平坐标 x、离桌高度 y、倾角。全部是「学生手出来的结果」,不是设定值。 */
export class Pose {
  x: number = 0;
  y: number = 0;
  tiltDeg: number = 0;

  static at(x: number, y: number): Pose {
    const p = new Pose();
    p.x = x;
    p.y = y;
    return p;
  }
}

/**
 * 器皿在桌面上的占位。
 *
 * 半宽取口部等效圆半径,这样「紧靠」「对准口部」这些教材用语才有可计算的对应物 ——
 * 它们的判据必须是几何距离加容差,而不是像素对齐。
 */
export class Footprint {
  x: number = 0;
  y: number = 0;
  halfWidth: number = 0;

  static of(x: number, y: number, halfWidth: number): Footprint {
    const f = new Footprint();
    f.x = x;
    f.y = y;
    f.halfWidth = halfWidth;
    return f;
  }
}

/** 空间关系谓词。判定层只允许通过这些关系读事实,不允许自己算几何。 */
export class Spatial {
  /** 边缘间距;负值表示已经重叠 */
  static edgeGap(a: Footprint, b: Footprint): number {
    return Math.abs(a.x - b.x) - (a.halfWidth + b.halfWidth);
  }

  /** 「紧靠」:边缘间距在容差内 */
  static isTouching(a: Footprint, b: Footprint, tolerance: number): boolean {
    return Math.abs(Spatial.edgeGap(a, b)) <= tolerance;
  }

  /** 「对准口部」:上方容器的中心落在下方容器口范围内(含容差) */
  static isAlignedAbove(upper: Footprint, lower: Footprint, tolerance: number): boolean {
    const offset = Math.abs(upper.x - lower.x);
    const limit = lower.halfWidth > upper.halfWidth
      ? lower.halfWidth - upper.halfWidth + tolerance
      : tolerance;
    return offset <= limit;
  }

  /** 中心水平偏移量,直接作为可复算证据 */
  static centerOffset(a: Footprint, b: Footprint): number {
    return Math.abs(a.x - b.x);
  }

  /** 上下关系:上方确实悬在高处,而非贴在桌上 */
  static isElevated(upper: Footprint, lower: Footprint, clearance: number): boolean {
    return upper.y - lower.y >= clearance;
  }

  /** 两物体是否大致同高(用于判断「能否接到」) */
  static sameLevel(a: Footprint, b: Footprint, tolerance: number): boolean {
    return Math.abs(a.y - b.y) <= tolerance;
  }
}
