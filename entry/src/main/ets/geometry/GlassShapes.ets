import { Glassware, Profile } from './Profile';

/**
 * 器材种类 → 回转体几何。
 *
 * 键用字符串而不是 `VesselKind`:这张表住在 bench/,而枚举住在 chemistry/,
 * 反向依赖会让"共用外壳"变成"共用循环引用"。VesselKind 是字符串枚举,直接传值即可。
 *
 * 认不出的种类退回试管而不是抛错或返回空剖面 —— 空剖面会让液面高度、落差、
 * 能否装下全部悄悄变成 0,那是最难查的一类错。
 */
export class GlassShapes {
  private static readonly cache: Map<string, Profile> = new Map();

  static of(kind: string): Profile {
    const key = kind === undefined || kind === null ? '' : kind;
    const hit = GlassShapes.cache.get(key);
    if (hit !== undefined) {
      return hit;
    }
    const built = GlassShapes.build(key);
    GlassShapes.cache.set(key, built);
    return built;
  }

  private static build(key: string): Profile {
    if (key === 'beaker') {
      return Glassware.beaker100();
    }
    if (key === 'flask') {
      return Glassware.conicalFlask();
    }
    if (key === 'cylinder') {
      return Glassware.graduatedCylinder10();
    }
    if (key === 'funnel') {
      return Glassware.funnelStem();
    }
    if (key === 'dish') {
      return Glassware.evaporatingDish();
    }
    return Glassware.testTube();
  }
}
