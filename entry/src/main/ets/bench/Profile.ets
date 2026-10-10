/**
 * 器皿几何:容积与液面高度的互相换算。
 *
 * 用「等高分段 + 截面积表」做数值积分,而不是解析公式。理由有三:
 * 漏斗是锥形、烧杯略微上口大、蒸发皿浅而宽,一条解析式表达不了;
 * 判定层要的是「液面高过滤纸边缘多少毫升」这种可复算的事实,离散积分给出确定答案;
 * 并且它不 import 任何 ArkUI/@kit 类型(不变量 I3),能被离线断言直接实例化。
 *
 * 单位:长度 cm,面积 cm²,体积 cm³(= mL)。
 */
export class Profile {
  /** 每一段的截面积(cm²),自底向上 */
  areas: number[] = [];
  /** 每段高度(cm) */
  segHeight: number = 0.1;

  static of(areas: number[], segHeight: number): Profile {
    const p = new Profile();
    p.areas = areas;
    p.segHeight = segHeight;
    return p;
  }

  /** 等截面直筒(量筒、近似烧杯) */
  static cylinder(area: number, height: number): Profile {
    const segHeight = 0.1;
    const count = Math.max(1, Math.round(height / segHeight));
    const areas: number[] = [];
    for (let i = 0; i < count; i++) {
      areas.push(area);
    }
    return Profile.of(areas, segHeight);
  }

  /** 直筒但上口略大(烧杯):截面积从底到底口线性放大 */
  static tapered(bottomArea: number, topArea: number, height: number): Profile {
    const segHeight = 0.1;
    const count = Math.max(1, Math.round(height / segHeight));
    const areas: number[] = [];
    for (let i = 0; i < count; i++) {
      const t = count === 1 ? 0 : i / (count - 1);
      areas.push(bottomArea + (topArea - bottomArea) * t);
    }
    return Profile.of(areas, segHeight);
  }

  /**
   * 由「半径函数」生成剖面:半球底的试管、锥体加细颈的锥形瓶都用它。
   *
   * 仍然离散成分段表,不存函数也不写解析公式 —— 和 cylinder/tapered 同源,
   * 判定层要的「液面高过滤纸边缘多少毫升」才是同一个可复算的算法。
   * 每段取中点半径(中点式),对球面与锥面都是二阶精度。
   */
  static revolve(radiusOf: (height: number) => number, height: number, segHeight: number): Profile {
    const count = Math.max(1, Math.round(height / segHeight));
    const areas: number[] = [];
    for (let i = 0; i < count; i++) {
      const r = radiusOf((i + 0.5) * segHeight);
      areas.push(Math.PI * r * r);
    }
    return Profile.of(areas, segHeight);
  }

  totalHeight(): number {
    return this.areas.length * this.segHeight;
  }

  capacity(): number {
    return this.volumeBelow(this.totalHeight());
  }

  /** 指定高度处的截面积;超出量程返回 0 */
  areaAt(height: number): number {
    if (height < 0 || height > this.totalHeight()) {
      return 0;
    }
    const index = Math.min(this.areas.length - 1, Math.floor(height / this.segHeight));
    return this.areas[index];
  }

  /** 液面高度 → 其以下容积。段内按线性(等截面)累加 */
  volumeBelow(height: number): number {
    if (height <= 0) {
      return 0;
    }
    const full = this.totalHeight();
    const capped = height > full ? full : height;
    let volume = 0;
    for (let i = 0; i < this.areas.length; i++) {
      const segTop = (i + 1) * this.segHeight;
      if (capped >= segTop) {
        volume += this.areas[i] * this.segHeight;
      } else {
        volume += this.areas[i] * (capped - i * this.segHeight);
        break;
      }
    }
    return volume;
  }

  /** 容积 → 液面高度。表内单调,超过量程按满量程处理 */
  heightForVolume(volume: number): number {
    if (volume <= 0) {
      return 0;
    }
    let accumulated = 0;
    for (let i = 0; i < this.areas.length; i++) {
      const segmentVolume = this.areas[i] * this.segHeight;
      if (accumulated + segmentVolume >= volume) {
        const within = segmentVolume <= 0 ? 0 : (volume - accumulated) / segmentVolume;
        return (i + within) * this.segHeight;
      }
      accumulated += segmentVolume;
    }
    return this.totalHeight();
  }

  /**
   * 指定高度处的回转半径(cm)。
   *
   * 这是「画出来的形状」与「算出来的容积」共用同一条曲线的地方:
   * area = πr²,所以半径就是截面积的解析逆。渲染层只许读这里,不许自己设宽度。
   */
  radiusAt(height: number): number {
    const area = this.areaAt(height);
    if (area <= 0) {
      return 0;
    }
    return Math.sqrt(area / Math.PI);
  }
}

/** 常用器材的名义尺寸(cm / mL)。数值来自教学演示标定,不是实测。 */
export class Glassware {
  static readonly GRADUATED_CYLINDER_10ML: number = 10;

  static graduatedCylinder10(): Profile {
    // 10 mL 高分辨率量程,总高 15 cm → 截面积 2/3 cm²
    return Profile.cylinder(10 / 15, 15);
  }

  static beaker100(): Profile {
    // 标称 100 mL、高 7 cm,上口略大于底
    return Profile.tapered(13.5, 15.5, 7);
  }

  /**
   * 试管:半球底 + 直筒。内径 1.8 cm、总高 15 cm,初中化学的常用规格。
   *
   * 半球底不只是像:同样倒半管,液面落在球底段时上升得比直筒段快得多,
   * 「读数位」和「视线齐平」这件事因此才有形状依赖。
   */
  static testTube(): Profile {
    const r = 0.9;
    return Profile.revolve((h: number): number => {
      if (h >= r) {
        return r;
      }
      const dy = r - h;
      return Math.sqrt(Math.max(0, r * r - dy * dy));
    }, 15, 0.1);
  }

  /** 锥形瓶(三角烧瓶):锥体 + 细颈。标称 250 mL 级,底径约 7.8 cm、高 11.2 cm */
  static conicalFlask(): Profile {
    const baseR = 3.9;
    const neckR = 1.15;
    const coneH = 8.2;
    const total = coneH + 3.0;
    return Profile.revolve((h: number): number => {
      return h <= coneH ? baseR + (neckR - baseR) * (h / coneH) : neckR;
    }, total, 0.1);
  }

  /** 普通三角漏斗。这里只建模其「承接滤纸的那段筒身」,锥部不计容积 */
  static funnelStem(): Profile {
    return Profile.cylinder(3.2, 9);
  }

  static evaporatingDish(): Profile {
    // 浅而宽:大表面积正是蒸发快的原因,也是判定「液面过浅易飞溅」的依据
    return Profile.tapered(28, 32, 4);
  }
}
