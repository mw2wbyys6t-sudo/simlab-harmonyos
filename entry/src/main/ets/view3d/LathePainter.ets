import { Profile } from '../geometry/Profile';
import { Camera, Ring } from './Camera';
import { Lathe, Shading } from './Lathe';
import { TiltedPlane } from './TiltedPlane';

const GLASS = '#D9E4EF';
const GLASS_EDGE = '#8FA0B2';
const LIQUID = '#7FB3E8';
const SHADOW = '#1F2A3A';
const TICK = '#33475B';

/** 一条判读标记:世界高度(cm)与它的语义色 */
export class GaugeMark {
  heightCm: number = 0;
  color: string = '';
  dashed: boolean = true;
}

/**
 * 一次绘制所需的全部输入。
 *
 * 量取页要刻度数字与判读线,实验台的容器是「份」制容量(mL 数字对它没有意义),
 * 还要按试剂上色 —— 用同一个 spec 表达,两个页面才真的共用一个绘制器。
 */
export class LatheSpec {
  profile: Profile = new Profile();
  /** 器内液体体积,单位与 profile 的容积一致 */
  volumeMl: number = 0;
  /** 叠在器身上的判读线(目标、读数、视线),高度单位 cm */
  marks: GaugeMark[] = [];
  /** 是否画分度。份制容器没有 mL 语义,连不带数字的弧线也不该画 —— 那会暗示一套不存在的量程 */
  graduated: boolean = true;
  liquidColor: string = LIQUID;
  /**
   * 器身绕屏幕横轴的倾角(度),正值 = 器口朝观察者倒。默认 0 = 立着,与接线前逐位相同。
   *
   * 倾斜时器身照旧是回转体(投影式与正立只差俯角变成 θ+α),但器内液面必须留在**世界水平面**上 ——
   * 这是这款教操作的应用里最不能画错的一件事:把整块画布转过去,液面会跟着玻璃一起歪。
   */
  tiltDeg: number = 0;
}

/** 一套刻度的排布 */
export class TickPlan {
  /** 每小格代表的容积(mL) */
  step: number = 1;
  /** 小格数,最后一个标签是 step × minors */
  minors: number = 0;
  /** 每隔几小格标一个数字、画一条长刻度 */
  majorStride: number = 4;
  /** 标签保留几位小数,由 step 决定 */
  decimals: number = 0;
}

/**
 * 回转体绘制器:把 Profile 的截面积表画成有体积感的玻璃器皿。
 *
 * 说是 3D,做的不是光栅化管线。模拟器上没有 core3d 着色器(实测记在 spec 里),而量筒、
 * 烧杯、漏斗、蒸发皿全都是**回转体** —— 回转体在正交投影下的外形由一条母线和一个圆环
 * 唯一确定,明暗只依赖方位角的余弦。所以这里直接算轮廓、算渐变,不建网格、不上 GPU:
 * 结果确定、可复算,真机上不必换第二套实现。
 *
 * 本文件刻意做薄:能判对错的几何全部下沉到 Camera / Lathe / Shading 并被断言覆盖,
 * 这里只剩「把算好的数交给 Canvas2D」的调用编排,只能靠眼睛验。
 */
export class LathePainter {
  /** 母线采样步长(cm)。Profile 本身按 0.1 cm 分段,再密也不会多出形状 */
  private static readonly SAMPLE_CM: number = 0.2;
  /** 明暗停靠点数:9 段已看不出余弦折角 */
  private static readonly STOPS: number = 9;
  /** 水平放大倍率的上限。再放就成扁片,宁可整体缩小 */
  static readonly MAX_GAIN: number = 6.5;
  /** 光源方位角(度,自正对观察者起算,向右为正)。偏左前:高光带在中偏左 */
  private static readonly LIGHT_PHI: number = -32;
  /** 俯角。小俯角既能看见口沿的水面,又不至于把器身压扁 */
  static readonly ELEVATION_DEG: number = 20;
  /**
   * 倾斜后俯角的上下限。投影椭圆的高低之比是 sin(俯角):平视塌成一条线。
   *
   * 上限留到 86° 而不是更小,是因为滑杆量程到 90°:夹得太早会出现「数字还在涨、画面不再动」,
   * 那是界面在说谎(见 spec 8.20 同类缺陷)。86° 时瓶口几乎正对观察者,画成一枚近圆就是它该有的样子。
   * 真要超过这个区间(器身侧倒、需要看见内壁),回转体这套就不够了,那是 3D 的活。
   */
  static readonly MIN_VIEW_ELEVATION: number = 4;
  static readonly MAX_VIEW_ELEVATION: number = 86;
  /** 液面曲线沿方位角的采样步长(度)。5° 已经看不出折角,再密只是多算 */
  private static readonly SURFACE_STEP_DEG: number = 5;
  /** 器身半宽最多占画布宽度的这个比例,剩下的是判读游标的余量 */
  static readonly WIDTH_FILL: number = 0.40;
  /** 器形(含椭圆凸出与投影)最多占画布高度的这个比例 */
  static readonly VERTICAL_FILL: number = 0.88;
  /**
   * 刻度与数字所在的方位角(度,都取左半周的大小,实际用的是负值)。
   * 90 是左切点,0 是正对观察者:刻度从外侧轮廓画向内侧,数字紧跟内端。
   */
  private static readonly TICK_OUTER: number = 58;
  private static readonly TICK_MAJOR: number = 26;
  private static readonly TICK_MINOR: number = 44;
  private static readonly TICK_LABEL: number = 12;
  /** 目标格数:真实量具大多落在 20 格上下 */
  private static readonly TARGET_MINORS: number = 20;
  /** 分度量候选:只有这些数会出现在教学量具的刻度上 */
  private static readonly NICE_STEPS: number[] = [0.1, 0.2, 0.25, 0.5, 1, 2, 2.5, 5, 10, 20, 25, 50, 100];

  /**
   * 画一个装了液体的回转体。液面高度由 Profile 反推,与判定层读的是同一个函数。
   *
   * spec.tiltDeg 非零时走另一条路:器身按俯角 θ+α 照旧画(投影式逐项相同),
   * 只有液体改由 `TiltedPlane` 按**世界水平面**切出来 —— 液面不跟着玻璃一起歪。
   */
  static draw(ctx: CanvasRenderingContext2D, spec: LatheSpec): void {
    const w = ctx.width;
    const h = ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    const lathe = Lathe.fromProfile(spec.profile);
    const tilt = spec.tiltDeg;
    const tilted = Math.abs(tilt) >= 0.0001;
    const cam = LathePainter.fitFor(lathe, w, h, tilt);
    const total = lathe.totalHeight();
    const flatH = Math.max(0, Math.min(total, lathe.liquidHeight(spec.volumeMl)));
    // 自由面的世界高度 Z,以及它与左右母线(切点)相交的那个高度 —— 切点处偏移项为 0,
    // 所以两侧同高、都等于 Z/cosα。填充路径的顶盖两头就接在这个高度上,不会留缝。
    let planeZ = flatH;
    let topH = flatH;
    if (tilted) {
      planeZ = TiltedPlane.planeForVolume(spec.profile, tilt, spec.volumeMl);
      topH = Math.max(0, Math.min(total, planeZ / Math.cos(tilt * Math.PI / 180)));
    }

    ctx.clearRect(0, 0, w, h);
    LathePainter.drawShadow(ctx, cam, lathe, w, h);
    LathePainter.fillBand(ctx, cam, lathe, total, GLASS, 0.62);
    if (spec.volumeMl > 0) {
      if (tilted) {
        LathePainter.fillTiltedLiquid(ctx, cam, lathe, tilt, planeZ, topH, spec.liquidColor);
        LathePainter.drawTiltedSurface(ctx, cam, lathe, tilt, planeZ, spec.liquidColor);
      } else {
        LathePainter.fillBand(ctx, cam, lathe, topH, spec.liquidColor, 1);
        LathePainter.drawSurface(ctx, cam, lathe, topH, spec.liquidColor);
      }
    }
    LathePainter.drawInnerWall(ctx, cam, lathe);
    if (spec.graduated) {
      LathePainter.drawTicks(ctx, cam, lathe, topH);
    }
    LathePainter.drawMarks(ctx, cam, lathe, spec.marks);
    LathePainter.drawOutline(ctx, cam, lathe);
  }

  /**
   * 定标:先按器高铺满,再按器宽收进画布;两个方向共用同一个 px/cm。
   *
   * 公开是为了让离线断言钉住「画出来一定不出框」和「水平放大不改变形状比例」这两条 ——
   * 这是手绘渲染最容易悄悄跑偏的两处。
   */
  static fitFor(lathe: Lathe, w: number, h: number, tiltDeg: number = 0): Camera {
    const cam = new Camera();
    // 倾斜不改变器身的画法,只把俯角从 θ 换成 θ+α —— 投影式逐项相同(见 TiltedPlane 头部)。
    // 夹在 [MIN, MAX] 之间是因为超出后椭圆退化,见 MIN_VIEW_ELEVATION 的说明。
    cam.elevationDeg = Math.min(LathePainter.MAX_VIEW_ELEVATION,
      Math.max(LathePainter.MIN_VIEW_ELEVATION, LathePainter.ELEVATION_DEG + tiltDeg));
    cam.centerX = w * 0.5;
    const samples = lathe.silhouette(LathePainter.SAMPLE_CM);
    let rMax = 0.0001;
    for (let i = 0; i < samples.length; i++) {
      if (samples[i].r > rMax) {
        rMax = samples[i].r;
      }
    }
    const total = Math.max(0.0001, lathe.totalHeight());
    // 竖直需求 = 器身投影高 + 上下两个椭圆的凸出 + 器底投影(按最大倍率估,留余量)
    const want = total * cam.heightScale() + 2.6 * rMax * LathePainter.MAX_GAIN * cam.flatten();
    let px = (h * LathePainter.VERTICAL_FILL) / Math.max(0.0001, want);
    const availHalf = w * LathePainter.WIDTH_FILL;
    let gain = availHalf / Math.max(0.0001, px * rMax);
    if (gain < 1) {
      // 画布太窄:整体等比缩小,宁可留白也不把回转体压成扁片
      px = px * gain;
      gain = 1;
    }
    cam.pxPerCm = px;
    cam.widthGain = Math.min(gain, LathePainter.MAX_GAIN);
    const bulge = rMax * px * cam.widthGain * cam.flatten();
    // 器底坐在画布下沿,只留出投影的高度。各自垂直居中会让矮的器皿「浮」起来,
    // 而并排的器材必须共用同一条台面。竖直预算在解 px 时已经按 2.6 倍凸出留过,不会顶出上沿。
    cam.baseY = h - 1.7 * bulge - 1;
    return cam;
  }

  /** 器底投影:把器皿「放」在台面上而不是浮着。宽度取最粗处,圆底试管才有影子 */
  private static drawShadow(ctx: CanvasRenderingContext2D, cam: Camera, lathe: Lathe,
    w: number, h: number): void {
    const ring = cam.ring(0, LathePainter.maxRadius(lathe, lathe.totalHeight()));
    if (ring.rx <= 0.5) {
      return;
    }
    ctx.save();
    ctx.globalAlpha = 0.16;
    ctx.fillStyle = SHADOW;
    ctx.beginPath();
    ctx.ellipse(cam.centerX, Math.min(h - 1, ring.cy + ring.ry * 0.55),
      Math.min(w * 0.48, ring.rx * 1.18), Math.max(1.5, ring.ry * 1.05), 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  /**
   * 轮廓:左母线自下而上 → 顶椭圆远半 → 右母线自上而下 → 底椭圆近半。
   * 顶走远半、底走近半才是外形的上下边界;左右切点就是方位角 ±90°。
   */
  private static bodyPath(ctx: CanvasRenderingContext2D, cam: Camera, lathe: Lathe,
    topH: number): void {
    const samples = lathe.silhouette(LathePainter.SAMPLE_CM);
    const baseRing = cam.ring(0, lathe.radiusAt(0));
    const topRing = cam.ring(topH, lathe.radiusAt(topH));
    ctx.beginPath();
    ctx.moveTo(baseRing.cx - baseRing.rx, baseRing.cy);
    for (let i = 0; i < samples.length; i++) {
      const s = samples[i];
      if (s.h > topH) {
        break;
      }
      ctx.lineTo(cam.centerX - cam.halfWidth(s.r), cam.screenY(s.h));
    }
    ctx.lineTo(topRing.cx - topRing.rx, topRing.cy);
    LathePainter.farHalf(ctx, topRing);
    for (let i = samples.length - 1; i >= 0; i--) {
      const s = samples[i];
      if (s.h > topH) {
        continue;
      }
      ctx.lineTo(cam.centerX + cam.halfWidth(s.r), cam.screenY(s.h));
    }
    ctx.lineTo(baseRing.cx + baseRing.rx, baseRing.cy);
    LathePainter.nearHalf(ctx, baseRing);
    ctx.closePath();
  }

  /** 椭圆上半(远侧):左切点 → 上 → 右切点。平视时椭圆塌成线段,退化成一条线 */
  private static farHalf(ctx: CanvasRenderingContext2D, ring: Ring): void {
    if (ring.rx <= 0.05) {
      ctx.lineTo(ring.cx + ring.rx, ring.cy);
      return;
    }
    ctx.ellipse(ring.cx, ring.cy, ring.rx, ring.ry, 0, Math.PI, Math.PI * 2);
  }

  /** 椭圆下半(近侧):右切点 → 下 → 左切点 */
  private static nearHalf(ctx: CanvasRenderingContext2D, ring: Ring): void {
    if (ring.rx <= 0.05) {
      ctx.lineTo(ring.cx + ring.rx, ring.cy);
      return;
    }
    ctx.ellipse(ring.cx, ring.cy, ring.rx, ring.ry, 0, 0, Math.PI);
  }

  /** 指定高度以下的最大半径:渐变按它铺开,最宽处才有一整段明暗 */
  private static maxRadius(lathe: Lathe, topH: number): number {
    const samples = lathe.silhouette(LathePainter.SAMPLE_CM);
    let r = lathe.radiusAt(0);
    for (let i = 0; i < samples.length; i++) {
      if (samples[i].h <= topH && samples[i].r > r) {
        r = samples[i].r;
      }
    }
    return Math.max(0.0001, r);
  }

  private static fillBand(ctx: CanvasRenderingContext2D, cam: Camera, lathe: Lathe,
    topH: number, base: string, alpha: number): void {
    LathePainter.bodyPath(ctx, cam, lathe, topH);
    LathePainter.paintBody(ctx, cam, lathe, topH, base, alpha);
  }

  /** 柱面渐变按最宽处铺开;调用前路径必须已经建好(正立与倾斜两种轮廓共用这一层) */
  private static paintBody(ctx: CanvasRenderingContext2D, cam: Camera, lathe: Lathe,
    topH: number, base: string, alpha: number): void {
    const half = Math.max(1, cam.halfWidth(LathePainter.maxRadius(lathe, topH)));
    const grad = ctx.createLinearGradient(cam.centerX - half, 0, cam.centerX + half, 0);
    const stops = Shading.stops(LathePainter.LIGHT_PHI, LathePainter.STOPS);
    for (let i = 0; i < stops.length; i++) {
      grad.addColorStop(i / Math.max(1, stops.length - 1), LathePainter.tone(base, stops[i]));
    }
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.fillStyle = grad;
    ctx.fill();
    ctx.restore();
  }

  /** 倾斜时的液体本体:左母线 → 液面远半 → 右母线 → 器底近半。顶盖不再是椭圆而是切出来的折线 */
  private static fillTiltedLiquid(ctx: CanvasRenderingContext2D, cam: Camera, lathe: Lathe,
    tiltDeg: number, planeZ: number, topH: number, base: string): void {
    const samples = lathe.silhouette(LathePainter.SAMPLE_CM);
    const baseRing = cam.ring(0, lathe.radiusAt(0));
    ctx.beginPath();
    ctx.moveTo(baseRing.cx - baseRing.rx, baseRing.cy);
    for (let i = 0; i < samples.length; i++) {
      const s = samples[i];
      if (s.h > topH) {
        break;
      }
      ctx.lineTo(cam.centerX - cam.halfWidth(s.r), cam.screenY(s.h));
    }
    LathePainter.surfaceArc(ctx, cam, lathe, tiltDeg, planeZ, 90, 270);
    for (let i = samples.length - 1; i >= 0; i--) {
      const s = samples[i];
      if (s.h > topH) {
        continue;
      }
      ctx.lineTo(cam.centerX + cam.halfWidth(s.r), cam.screenY(s.h));
    }
    ctx.lineTo(baseRing.cx + baseRing.rx, baseRing.cy);
    LathePainter.nearHalf(ctx, baseRing);
    ctx.closePath();
    LathePainter.paintBody(ctx, cam, lathe, topH, base, 1);
  }

  /** 倾斜时的液面:同一个切出来的闭合圈,亮一档填、描边,与正立那条 drawSurface 同权 */
  private static drawTiltedSurface(ctx: CanvasRenderingContext2D, cam: Camera, lathe: Lathe,
    tiltDeg: number, planeZ: number, base: string): void {
    let widest = 0;
    for (let phi = 0; phi < 360; phi += LathePainter.SURFACE_STEP_DEG) {
      const sp = TiltedPlane.surfacePoint(lathe.profile, tiltDeg, planeZ, phi);
      const half = cam.halfWidth(sp.radiusCm) * Math.abs(Math.sin(phi * Math.PI / 180));
      if (half > widest) {
        widest = half;
      }
    }
    if (widest <= 0.5) {
      return;
    }
    ctx.save();
    ctx.beginPath();
    LathePainter.surfaceArc(ctx, cam, lathe, tiltDeg, planeZ, 0, 360);
    ctx.closePath();
    ctx.fillStyle = LathePainter.tone(base, 1);
    ctx.fill();
    // 整圈描一遍:浅层液体只剩一枚歪的扁圈,只描一半会融进玻璃里看不见
    ctx.strokeStyle = LathePainter.tone(base, 0.3);
    ctx.lineWidth = 1.4;
    ctx.stroke();
    ctx.restore();
  }

  /** 沿方位角把「自由面贴器壁」那些点连成折线;收尾补一次终点,免得最后一段差一个步长 */
  private static surfaceArc(ctx: CanvasRenderingContext2D, cam: Camera, lathe: Lathe,
    tiltDeg: number, planeZ: number, fromDeg: number, toDeg: number): void {
    const step = LathePainter.SURFACE_STEP_DEG;
    for (let phi = fromDeg; phi < toDeg; phi += step) {
      LathePainter.lineToSurface(ctx, cam, lathe, tiltDeg, planeZ, phi);
    }
    LathePainter.lineToSurface(ctx, cam, lathe, tiltDeg, planeZ, toDeg);
  }

  private static lineToSurface(ctx: CanvasRenderingContext2D, cam: Camera, lathe: Lathe,
    tiltDeg: number, planeZ: number, phiDeg: number): void {
    const sp = TiltedPlane.surfacePoint(lathe.profile, tiltDeg, planeZ, phiDeg);
    const p = cam.ring(sp.hCm, sp.radiusCm).pointAt(phiDeg);
    ctx.lineTo(p.x, p.y);
  }

  /** 液面:椭圆盘亮一档,近侧交界描一条深线 —— 一眼看出器口是开的。色相由液体本色推出 */
  private static drawSurface(ctx: CanvasRenderingContext2D, cam: Camera, lathe: Lathe,
    liquidH: number, base: string): void {
    const ring = cam.ring(liquidH, lathe.radiusAt(liquidH));
    if (ring.rx <= 0.5) {
      return;
    }
    ctx.save();
    ctx.beginPath();
    ctx.ellipse(ring.cx, ring.cy, ring.rx, ring.ry, 0, 0, Math.PI * 2);
    ctx.fillStyle = LathePainter.tone(base, 1);
    ctx.fill();
    // 整圈描一遍:浅层液体只有一枚扁椭圆,只描近半的话无色溶液会融进玻璃里看不见
    ctx.beginPath();
    ctx.ellipse(ring.cx, ring.cy, ring.rx, ring.ry, 0, 0, Math.PI * 2);
    ctx.strokeStyle = LathePainter.tone(base, 0.3);
    ctx.lineWidth = 1.4;
    ctx.stroke();
    ctx.restore();
  }

  /** 玻璃厚度与器底内壁:透过去看得见的那两条远侧弧线 */
  private static drawInnerWall(ctx: CanvasRenderingContext2D, cam: Camera, lathe: Lathe): void {
    const top = cam.ring(lathe.totalHeight(), lathe.radiusAt(lathe.totalHeight()));
    const base = cam.ring(0, lathe.radiusAt(0));
    const wall = Math.max(2.5, top.rx * 0.07);
    const flatten = cam.flatten();
    ctx.save();
    ctx.strokeStyle = GLASS_EDGE;
    ctx.lineWidth = 1;
    ctx.globalAlpha = 0.75;
    if (top.rx > wall + 0.5) {
      ctx.beginPath();
      ctx.ellipse(top.cx, top.cy, top.rx - wall, Math.max(0, top.ry - wall * flatten),
        0, 0, Math.PI * 2);
      ctx.stroke();
    }
    if (base.rx > wall + 0.5) {
      ctx.beginPath();
      ctx.ellipse(base.cx, base.cy, base.rx - wall, Math.max(0, base.ry - wall * flatten),
        0, Math.PI, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }

  /**
   * 刻度排布:把「量程除以二十」得到的 5.02 mL、4.52 mL 这类数换成量具上真会出现的数。
   *
   * 真实玻璃仪器的分度是 0.1 / 0.2 / 0.5 / 1 / 2 / 5 / 10 这一族,因为刻度是给人读的。
   * 这里按同样的候选表挑一个「不小于量程/20」的最小值 —— 20 格上下最像真量具,再多就读不动了。
   * 长刻度每 2 格或 4 格一道,取决于总格数够不够密。
   *
   * 公开是为了让断言钉住:候选表漏一档,标签就会悄悄变回 4.52 这种假精确数字。
   */
  static ticksFor(capacity: number): TickPlan {
    const plan = new TickPlan();
    if (!(capacity > 0) || !LathePainter.finite(capacity)) {
      return plan;
    }
    const want = capacity / LathePainter.TARGET_MINORS;
    let step = LathePainter.NICE_STEPS[LathePainter.NICE_STEPS.length - 1];
    for (let i = 0; i < LathePainter.NICE_STEPS.length; i++) {
      if (LathePainter.NICE_STEPS[i] >= want - 1e-9) {
        step = LathePainter.NICE_STEPS[i];
        break;
      }
    }
    plan.step = step;
    plan.minors = Math.max(1, Math.floor(capacity / step + 1e-9));
    plan.majorStride = plan.minors >= 16 ? 4 : 2;
    // 小数位按「被标出来的那个数」定,不按分度:0.5 mL 分度配 4 格一标就是 2 mL,写 "2" 不写 "2.0"
    let rest = step * plan.majorStride;
    let decimals = 0;
    while (decimals < 3 && Math.abs(rest - Math.round(rest)) > 1e-9) {
      rest = rest * 10;
      decimals = decimals + 1;
    }
    plan.decimals = decimals;
    return plan;
  }

  /** 刻度:刻在筒壁上,所以每条都是贴着椭圆下凸的扁弧,数字也一样贴在曲面上 */
  private static drawTicks(ctx: CanvasRenderingContext2D, cam: Camera, lathe: Lathe,
    liquidH: number): void {
    const plan = LathePainter.ticksFor(lathe.profile.capacity());
    if (plan.minors < 1) {
      return;
    }
    ctx.save();
    ctx.strokeStyle = TICK;
    ctx.fillStyle = TICK;
    ctx.lineCap = 'round';
    ctx.globalAlpha = 0.82;
    for (let i = 1; i <= plan.minors; i++) {
      const volume = i * plan.step;
      const h = lathe.profile.heightForVolume(volume);
      const ring = cam.ring(h, lathe.radiusAt(h));
      if (ring.rx <= 0.5) {
        continue;
      }
      const major = i % plan.majorStride === 0;
      // 刻度线从左侧轮廓(φ = -TICK_OUTER)画向筒身内侧(φ = -inner),长刻度画得更长;
      // 数字紧跟在内端的右边 —— 真量具就是这么排的。
      const inner = major ? LathePainter.TICK_MAJOR : LathePainter.TICK_MINOR;
      ctx.lineWidth = major ? 1.5 : 0.9;
      ctx.beginPath();
      ctx.ellipse(ring.cx, ring.cy, ring.rx, ring.ry, 0,
        LathePainter.degToRad(90 + inner), LathePainter.degToRad(90 + LathePainter.TICK_OUTER));
      ctx.stroke();
      if (major) {
        ctx.font = '9vp sans-serif';
        ctx.textAlign = 'left';
        ctx.textBaseline = 'middle';
        // 液面以下压在水色上,颜色提白才读得清
        if (h <= liquidH) {
          ctx.globalAlpha = 1;
          ctx.fillStyle = '#F4F9FF';
        }
        // 数字也钉在同一张曲面上(参数角 t = 90° − φ):刻度、数字、近侧液面同一个深度,
        // 才谈得上「液面到没到这条线」
        const label = ring.pointAt(-LathePainter.TICK_LABEL);
        ctx.fillText(volume.toFixed(plan.decimals), label.x, label.y);
        ctx.globalAlpha = 0.82;
        ctx.fillStyle = TICK;
      }
    }
    ctx.restore();
  }

  /** 判读线:横切器身,右端带一个指向刻度的实心游标 */
  private static drawMarks(ctx: CanvasRenderingContext2D, cam: Camera, lathe: Lathe,
    marks: GaugeMark[]): void {
    const total = lathe.totalHeight();
    for (let i = 0; i < marks.length; i++) {
      const mark = marks[i];
      if (!LathePainter.finite(mark.heightCm)) {
        continue;
      }
      const clamped = Math.max(0, Math.min(total, mark.heightCm));
      const y = cam.screenY(mark.heightCm);
      const half = cam.halfWidth(lathe.radiusAt(clamped)) + 4;
      ctx.save();
      ctx.strokeStyle = mark.color;
      ctx.fillStyle = mark.color;
      ctx.lineWidth = 1.6;
      if (mark.dashed) {
        ctx.setLineDash([6, 4]);
      }
      ctx.beginPath();
      ctx.moveTo(cam.centerX - half, y);
      ctx.lineTo(cam.centerX + half, y);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.beginPath();
      ctx.moveTo(cam.centerX + half + 9, y - 5);
      ctx.lineTo(cam.centerX + half + 9, y + 5);
      ctx.lineTo(cam.centerX + half + 1, y);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }
  }

  private static drawOutline(ctx: CanvasRenderingContext2D, cam: Camera, lathe: Lathe): void {
    LathePainter.bodyPath(ctx, cam, lathe, lathe.totalHeight());
    ctx.save();
    ctx.strokeStyle = GLASS_EDGE;
    ctx.lineWidth = 2;
    ctx.lineJoin = 'round';
    ctx.stroke();
    ctx.restore();
  }

  /**
   * 亮度 → 颜色。系数 0.52 到 1.18:暗部压到一半多一档,高光处故意溢出成近白,
   * 溢出正是玻璃与液面反光该有的样子。
   *
   * 公开是因为颜色手拼:拼错一位 Canvas 不报错,只是什么都不画,只能让断言盯住格式。
   */
  static tone(hex: string, brightness: number): string {
    const k = 0.52 + 0.66 * Math.max(0, Math.min(1, brightness));
    return '#' + LathePainter.hx(LathePainter.byte(hex, 1) * k)
      + LathePainter.hx(LathePainter.byte(hex, 3) * k)
      + LathePainter.hx(LathePainter.byte(hex, 5) * k);
  }

  private static byte(hex: string, at: number): number {
    if (hex.length < at + 2) {
      return 0;
    }
    const value = Number.parseInt(hex.substring(at, at + 2), 16);
    return LathePainter.finite(value) ? value : 0;
  }

  private static hx(value: number): string {
    const n = Math.max(0, Math.min(255, Math.round(value)));
    const digits = '0123456789ABCDEF';
    return digits.charAt(Math.floor(n / 16)) + digits.charAt(n % 16);
  }

  private static degToRad(deg: number): number {
    return deg * Math.PI / 180;
  }

  private static finite(value: number): boolean {
    return value === value && value !== Number.POSITIVE_INFINITY
      && value !== Number.NEGATIVE_INFINITY;
  }
}
