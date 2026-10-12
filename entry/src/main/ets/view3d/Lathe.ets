import { Profile } from '../geometry/Profile';

/** 母线上的一点:高度与半径,单位 cm */
export class LatheSample {
  h: number = 0;
  r: number = 0;
}

/**
 * 回转体:把 Profile 的截面积表读成母线。
 *
 * 刻意只是 Profile 的一层薄读法,不另存一份形状数据 —— 否则「画出来的」和
 * 「算容积的」会有两套真相,迟早对不上。渲染层要宽度只能问这里,这里只问 Profile。
 */
export class Lathe {
  profile: Profile = new Profile();

  static fromProfile(profile: Profile): Lathe {
    const lathe = new Lathe();
    lathe.profile = profile;
    return lathe;
  }

  radiusAt(h: number): number {
    return this.profile.radiusAt(h);
  }

  totalHeight(): number {
    return this.profile.totalHeight();
  }

  /** 液面高度由容积反推,和判定层读到的液面是同一个函数 */
  liquidHeight(volumeMl: number): number {
    return this.profile.heightForVolume(volumeMl);
  }

  /** 自底向上的母线采样,用于生成左右轮廓 */
  silhouette(stepCm: number): LatheSample[] {
    const total = this.profile.totalHeight();
    const step = stepCm > 0 ? stepCm : (total > 0 ? total : 1);
    // 用 round 而不是 ceil:total 常带浮点尾差(70 × 0.1 = 7.000000000000001),
    // ceil 会多出一段几乎重合的采样点,让锥形母线出现"平台"。
    const steps = Math.max(1, Math.round(total / step));
    const out: LatheSample[] = [];
    for (let i = 0; i <= steps; i++) {
      const h = Math.min(total, i * step);
      const sample = new LatheSample();
      sample.h = h;
      sample.r = this.profile.radiusAt(h);
      out.push(sample);
    }
    return out;
  }
}

/**
 * 柱面明暗。
 *
 * 回转体表面在方位角 φ 处的法线水平朝外,光在水平面内从 lightPhiDeg 射入,
 * 则 Lambert 项为 cos(φ - lightPhiDeg)。可见的是朝向观察者的前半周,
 * φ ∈ [-90°, 90°],所以从左边缘到右边缘亮度先升后降,高光带偏向光源一侧。
 * 这正是"一眼看上去是圆的"所需要的全部信息,不需要真的光栅化。
 */
export class Shading {
  /** 归一化到 0..1 的亮度 */
  static brightness(phiDeg: number, lightPhiDeg: number): number {
    const cosine = Math.cos((phiDeg - lightPhiDeg) * Math.PI / 180);
    if (cosine < 0) {
      return 0;
    }
    return cosine > 1 ? 1 : cosine;
  }

  /** 从左边缘到右边缘等间隔取 count 个亮度停靠点。可见半周是 φ ∈ [-90°, 90°] */
  static stops(lightPhiDeg: number, count: number): number[] {
    const out: number[] = [];
    if (count <= 0) {
      return out;
    }
    for (let i = 0; i < count; i++) {
      const phi = count === 1 ? 0 : -90 + 180 * i / (count - 1);
      out.push(Shading.brightness(phi, lightPhiDeg));
    }
    return out;
  }
}
