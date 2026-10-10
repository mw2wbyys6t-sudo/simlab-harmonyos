import { Calibration } from './Brine';

/**
 * 一次滴加的可测几何。只有长度、体积与朝向,不含任何「学生想干什么」的意图字段 ——
 * 意图一旦被记进来,判定就从读事实退化成读我们替他写的结论。
 */
export class DropPose {
  /** 计划滴入的体积(mL) */
  volumeMl: number = 0;
  /** 滴管尖端相对容器口的高度(cm)。正 = 悬空在口上方;负 = 伸进口内 */
  tipAboveRimCm: number = 0;
  /** 容器口到液面的深度(cm) */
  mouthToSurfaceCm: number = 0;
  /** 尖端是否接触内壁 */
  touchesWall: boolean = false;
  /** 胶头是否朝上。false = 平放或倒置 */
  bulbUp: boolean = true;
}

/**
 * 一次滴加的去向。
 *
 * 前四项是**滴管里那份液体**的分账,之和恒等于 volumeMl。
 * `carriedBackMl` 不在这个账上:它是尖端从**容器里**带走的液体,属于交叉污染,
 * 记在同一份里会让人以为滴进去的比计划少是因为"损失"了,而实际是被带回去了。
 */
export class DropResult {
  deliveredMl: number = 0;
  /** 挂在器壁上,没进液面 */
  stuckWallMl: number = 0;
  /** 液滴冲击液面溅出容器外 */
  splashedMl: number = 0;
  /** 倒流进胶头的那部分(腐蚀胶头,同时让试剂被橡胶污染) */
  refluxMl: number = 0;
  /** 尖端从容器里带回的液体(mL),交叉污染的量 */
  carriedBackMl: number = 0;
}

/**
 * 滴加(胶头滴管)。
 *
 * 三个考点各自对应一个可测量后果,而不是动作标签:
 * - 伸入容器内或接触内壁 → 尖端被容器里的溶液润湿,提出来带走 `carriedBackMl`,
 *   这就是「污染试剂」;同时挂在器壁上的 `stuckWallMl` 不再进液面。
 * - 胶头朝下 → 药液倒流进胶头 `refluxMl`,既腐蚀胶头又污染原试剂。
 * - 滴得过高 → 液滴冲击造成 `splashedMl`。
 *
 * 规范动作(悬空约 1 cm、不碰壁、胶头朝上)必须精确地四项都不损失,否则"失误"
 * 没有对照基线。系数是教学演示标定值(与 R2 同类),可信的是守恒与单调关系。
 */
export class Dropper {
  static deliver(pose: DropPose): DropResult {
    const result = new DropResult();
    const volume = Dropper.real(pose.volumeMl, 0);
    if (volume <= 0) {
      return result;
    }
    const tip = Dropper.real(pose.tipAboveRimCm, 0);
    const depth = Math.max(0, Dropper.real(pose.mouthToSurfaceCm, 0));
    // 尖端在口内时落差可以为负,那是在液面下释放,没有冲击
    const fall = Math.max(0, tip + depth);
    const inside = Math.max(0, -tip);
    let left = volume;

    const stickFraction = Math.min(1, Calibration.DROP_STICK_PER_CM * inside
      + (pose.touchesWall ? Calibration.DROP_STICK_WALL : 0));
    result.stuckWallMl = volume * stickFraction;
    left -= result.stuckWallMl;

    const overFall = fall - Calibration.DROP_SPLASH_ONSET_CM;
    if (overFall > 0) {
      const splashFraction = Math.min(Calibration.DROP_SPLASH_MAX,
        Calibration.DROP_SPLASH_PER_CM * overFall);
      result.splashedMl = Math.min(left, volume * splashFraction);
      left -= result.splashedMl;
    }

    if (!pose.bulbUp) {
      result.refluxMl = Math.min(left, volume * Calibration.DROP_REFLUX_FRACTION);
      left -= result.refluxMl;
    }

    // 落底量取余数而不是独立算一遍,保证四项之和精确等于计划体积
    result.deliveredMl = left;
    result.carriedBackMl = Calibration.DROP_CARRY_PER_CM * inside
      + (pose.touchesWall ? Calibration.DROP_CARRY_CONTACT : 0);
    return result;
  }

  private static real(value: number, fallback: number): number {
    return Number.isFinite(value) ? value : fallback;
  }
}
