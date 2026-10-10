import { Calibration } from './Brine';

/**
 * 一次投放的可测几何。
 *
 * `verticalDropCm` 是块体落到器底前的**竖直**落差 —— 这个量把「慢竖」和「直投」区分开:
 * 横放放在管口再慢慢竖起,块体沿壁滑下,竖直落差只有一个管半径;直立着从管口松手,
 * 落差就是整个管长。调用方(知道容器姿态与几何的那一层)算它,模型不猜。
 */
export class ChunkPose {
  /** 块状固体质量(g) */
  massG: number = 0;
  /** 容器轴与水平面的夹角(度)。0 = 横放,90 = 直立 */
  tiltDeg: number = 0;
  /** 落到器底前的竖直落差(cm) */
  verticalDropCm: number = 0;
}

/**
 * 投放后果的分账。前三项之和恒等于投放质量。
 *
 * `bottomDamage` 不在质量账上,它是**容器**的连续损伤量(0 = 无损,1 = 砸穿)。
 * 取连续值而不是布尔,是因为「裂而未破」与「砸穿」在真实操作里都存在,而连续模型
 * 正是本项目相对离散仿真的立论:破损程度决定随后漏多少,而不是一个开关。
 */
export class ChunkResult {
  landedG: number = 0;
  /** 撞挂在壁上没到底的 */
  stuckWallG: number = 0;
  /** 砸击崩出容器外的 */
  escapedG: number = 0;
  bottomDamage: number = 0;
}

/**
 * 块状固体取用(镊子):「一横二放三慢竖」。
 *
 * 考点落在最硬的那个后果上 —— 直立着把锌粒丢进试管,砸破的是管底。破底之后容器漏液,
 * 这一轮收到的量真的少,而扣分依据是"管底损伤 0.64、崩出 0.32 g"这样的可复算数字。
 *
 * 与粉末取用同一个思路:**不为这个失误新增判据**。破损 → 漏失 → 既有的产率判据命中。
 */
export class ChunkSolid {
  static deliver(pose: ChunkPose): ChunkResult {
    const result = new ChunkResult();
    const mass = ChunkSolid.real(pose.massG, 0);
    if (mass <= 0) {
      return result;
    }
    const tilt = ChunkSolid.real(pose.tiltDeg, 0);
    const drop = Math.max(0, ChunkSolid.real(pose.verticalDropCm, 0));
    const over = drop - Calibration.CHUNK_BREAK_ONSET_CM;

    if (over > 0) {
      result.bottomDamage = Math.min(1, over * Calibration.CHUNK_BREAK_PER_CM);
      result.escapedG = Math.min(mass, mass * Math.min(Calibration.CHUNK_ESCAPE_MAX,
        Calibration.CHUNK_ESCAPE_PER_CM * over));
    }
    // 直立时块体撞在管壁上挂住;横放则沿壁滑到底,sin 恰好把两者分开
    const wallFactor = Math.max(0, Math.min(1, Math.sin(tilt * Math.PI / 180)));
    const left = mass - result.escapedG;
    result.stuckWallG = left * Calibration.CHUNK_STICK_FRACTION * wallFactor;
    // 落底量取余数,保证三项之和精确等于投放量
    result.landedG = left - result.stuckWallG;
    return result;
  }

  private static real(value: number, fallback: number): number {
    return Number.isFinite(value) ? value : fallback;
  }
}
