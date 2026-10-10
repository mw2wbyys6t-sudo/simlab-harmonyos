/** 回转体上某个圆环投影到屏幕后的参数 */
export class Ring {
  cx: number = 0;
  cy: number = 0;
  rx: number = 0;
  ry: number = 0;

  /**
   * 圆环上方位角 φ 处的屏幕坐标。
   *
   * φ 从「正对观察者」起算,向右为正,所以可见的前半周是 φ ∈ [-90°, 90°],
   * 与 Shading 用的是同一个角。投影后 x = cx + rx·sinφ、y = cy + ry·cosφ:
   * φ=0 落在椭圆最下沿(近侧),φ=±90 落在左右切点,φ=180 是最上沿(远侧)。
   */
  pointAt(phiDeg: number): ScreenPoint {
    const rad = phiDeg * Math.PI / 180;
    const out = new ScreenPoint();
    out.x = this.cx + this.rx * Math.sin(rad);
    out.y = this.cy + this.ry * Math.cos(rad);
    return out;
  }
}

/** 屏幕坐标(vp) */
export class ScreenPoint {
  x: number = 0;
  y: number = 0;
}

/**
 * 俯仰正交相机。
 *
 * 世界坐标:Y 轴向上(高度 cm),Z 轴朝向观察者。绕 X 轴转俯角 θ 后:
 *   screenX = r·cosφ
 *   screenY = -h·cosθ + r·sinφ·sinθ
 * 所以一个圆环投影成 rx = r、ry = r·sinθ 的椭圆,高度方向整体压缩 cosθ。
 * 平视时椭圆塌成一条线,正俯视时是正圆,两个极限都自然成立。
 *
 * 不做透视缩放:单个器皿尺寸有限,而近侧口沿低于远侧这件事椭圆本身已经表达了。
 * 少一个没法规格的自由度,就少一处只能靠眼睛判断的地方。
 */
export class Camera {
  /** 俯角(度)。0 = 平视,90 = 正上方俯视 */
  elevationDeg: number = 0;
  /** 每厘米对应的像素 */
  pxPerCm: number = 10;
  /** 光轴在屏幕上的 x */
  centerX: number = 0;
  /** 器底(h = 0)在屏幕上的 y,Canvas 的 y 向下为正 */
  baseY: number = 0;
  /**
   * 水平放大倍率,只加宽不改变形状:母线整体乘同一个数,截面之间的相对宽窄(锥形、
   * 收口)一分不少,所以「画出来的轮廓」和「算容积的曲线」仍是同一条。
   *
   * 需要它是因为 10 mL 量筒的名义截面只有 2/3 cm²(直径不足 1 cm),按真实比例画
   * 就是一条看不出刻度的细线。这里承认它是可读性折衷,不是几何事实。
   */
  widthGain: number = 1;


  /** 俯角超出 [0,90] 没有物理意义,夹住而不是让它产生反直觉的投影 */
  private static clampElevation(deg: number): number {
    if (deg < 0) {
      return 0;
    }
    return deg > 90 ? 90 : deg;
  }

  /** 椭圆短长轴之比 = sin(俯角) */
  flatten(): number {
    return Math.sin(Camera.rad(Camera.clampElevation(this.elevationDeg)));
  }

  /** 高度方向的压缩比 = cos(俯角) */
  heightScale(): number {
    return Math.cos(Camera.rad(Camera.clampElevation(this.elevationDeg)));
  }

  private static rad(deg: number): number {
    return deg * Math.PI / 180;
  }

  /** 高度 h(cm)→ 屏幕 y */
  screenY(h: number): number {
    return this.baseY - h * this.heightScale() * this.pxPerCm;
  }

  /** 半径 r(cm)→ 屏幕半宽(px),含水平放大倍率 */
  halfWidth(r: number): number {
    return r * this.pxPerCm * this.widthGain;
  }

  /** 指定高度处、指定半径的圆环 */
  ring(h: number, r: number): Ring {
    const out = new Ring();
    out.cx = this.centerX;
    out.cy = this.screenY(h);
    out.rx = this.halfWidth(r);
    out.ry = out.rx * this.flatten();
    return out;
  }
}
