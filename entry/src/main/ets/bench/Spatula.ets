import { Calibration } from './Brine';
import { Container } from './Container';

/** 一次粉末取用的去向。三项之和恒等于投料量 —— 守恒断言用它 */
export class SpatulaResult {
  deliveredG: number = 0;
  stuckWallG: number = 0;
  spilledG: number = 0;
}

/**
 * 粉末状固体取用(药匙或纸槽):「一斜二送三直立」。
 *
 * 考点落在**后果**上而不是动作标签上:送不到底,粉末就撞在管口与内壁上,那部分盐
 * 从此不参与溶解,这一轮的产率真的低。沾壁量单独记在 `Brine.saltStuckG` /
 * `sandStuckG`,而不是并进 `saltSolidG` —— 并进可溶存量等于把操作失误从账本上抹掉。
 *
 * 可信的是守恒与单调关系(送得越深越少、越接近横放越少);两个占比系数是教学演示
 * 标定值,与 R2 同类,不声称与真实粉末粘附量相符。
 */
export class Spatula {
  /**
   * @param tiltDeg  容器轴与水平面的夹角。90 = 直立,0 = 横放
   * @param reachCm  药匙末端沿容器轴伸入的深度,负数表示没伸进去
   */
  static deliver(target: Container, saltG: number, sandG: number, tiltDeg: number,
    reachCm: number): SpatulaResult {
    const salt = saltG > 0 ? saltG : 0;
    const sand = sandG > 0 ? sandG : 0;
    const total = salt + sand;
    const result = new SpatulaResult();
    if (total <= 0) {
      return result;
    }

    const fallen: number = Spatula.freeFallCm(target.profile.totalHeight(), reachCm);
    // 横放时粉末顺着壁滑到底,直立时才撞壁;sin 恰好把「直立」映射到 1、「横放」映射到 0
    const wallFactor = Spatula.clamp01(Math.sin(tiltDeg * Math.PI / 180));
    const stickFraction = Math.min(1, Calibration.POWDER_STICK_PER_CM * fallen * wallFactor);
    const spillFraction = Math.min(Calibration.POWDER_SPILL_MAX,
      Calibration.POWDER_SPILL_PER_CM * fallen * wallFactor);

    result.stuckWallG = total * stickFraction;
    result.spilledG = total * spillFraction;
    // 落底量取余数而不是独立算一遍,保证三项之和精确等于投料
    result.deliveredG = total - result.stuckWallG - result.spilledG;

    const saltRatio = salt / total;
    const brine = target.brine;
    brine.saltSolidG += result.deliveredG * saltRatio;
    brine.sandSettledG += result.deliveredG * (1 - saltRatio);
    brine.saltStuckG += result.stuckWallG * saltRatio;
    brine.sandStuckG += result.stuckWallG * (1 - saltRatio);
    brine.losses.addSpilled(0, result.spilledG * saltRatio, result.spilledG * (1 - saltRatio));
    
    return result;
  }

  /** 药匙末端到落点之间那段自由下落的路程 */
  private static freeFallCm(depthCm: number, reachCm: number): number {
    const left = depthCm - reachCm;
    return left > 0 ? left : 0;
  }

  private static clamp01(value: number): number {
    if (value < 0) {
      return 0;
    }
    return value > 1 ? 1 : value;
  }
}
