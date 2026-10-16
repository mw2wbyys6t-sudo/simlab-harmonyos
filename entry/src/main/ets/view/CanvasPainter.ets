import { Palette } from './Palette';
import {
  ArrowShape, BoxShape, CircleShape, FillStyle, LabelShape, SegmentShape, SpringShape, Viewport, WorldSnapshot
} from '../physics/World2D';

const DEG = Math.PI / 180;

/**
 * 2D 场景图的唯一绘制出口。所有 2D 实验共用这一个组件,
 * 所以绘制相关的适配(高对比、远距离可读字号、线宽随视口缩放)只需改这里。
 *
 * 世界坐标 y 向上、画布坐标 y 向下,翻转只发生在 Viewport 的 px/py 里;
 * 因此涉及旋转的角度要从世界系取反再交给 ctx.rotate。
 */
export class CanvasPainter {
  static draw(ctx: CanvasRenderingContext2D, snap: WorldSnapshot, vp: Viewport): void {
    ctx.fillStyle = Palette.canvasBg();
    ctx.fillRect(0, 0, ctx.width, ctx.height);

    CanvasPainter.drawSegments(ctx, snap.segments, vp);
    CanvasPainter.drawSprings(ctx, snap.springs, vp);
    CanvasPainter.drawBoxes(ctx, snap.boxes, vp);
    CanvasPainter.drawSegments(ctx, snap.frontSegments, vp);
    CanvasPainter.drawCircles(ctx, snap.circles, vp);
    CanvasPainter.drawArrows(ctx, snap.arrows, vp);
    CanvasPainter.drawLabels(ctx, snap.labels, vp);
  }

  private static drawSegments(ctx: CanvasRenderingContext2D, items: SegmentShape[], vp: Viewport): void {
    for (let i = 0; i < items.length; i++) {
      const seg = items[i];
      ctx.save();
      ctx.strokeStyle = seg.color;
      ctx.lineWidth = seg.widthMm;
      if (seg.dashed) {
        ctx.setLineDash([8, 6]);
      }
      ctx.beginPath();
      ctx.moveTo(vp.px(seg.x1), vp.py(seg.y1));
      ctx.lineTo(vp.px(seg.x2), vp.py(seg.y2));
      ctx.stroke();
      ctx.restore();
    }
  }

  private static drawSprings(ctx: CanvasRenderingContext2D, items: SpringShape[], vp: Viewport): void {
    for (let i = 0; i < items.length; i++) {
      const sp = items[i];
      const x1 = vp.px(sp.x1);
      const y1 = vp.py(sp.y1);
      const x2 = vp.px(sp.x2);
      const y2 = vp.py(sp.y2);
      const dx = x2 - x1;
      const dy = y2 - y1;
      const long = Math.sqrt(dx * dx + dy * dy);
      if (long < 1) {
        continue;
      }
      const ux = dx / long;
      const uy = dy / long;
      // 画布系的法线,用于把线圈推出轴线
      const nx = -uy;
      const ny = ux;
      const amp = sp.amplitude * vp.scale;
      const lead = long * 0.12;
      const body = long - lead * 2;
      const points = sp.coils * 2;

      ctx.save();
      ctx.strokeStyle = sp.color;
      ctx.lineWidth = 2.5;
      ctx.lineJoin = 'round';
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x1 + ux * lead, y1 + uy * lead);
      for (let k = 0; k <= points; k++) {
        const along = lead + body * (k / points);
        const side = k % 2 === 0 ? -1 : 1;
        const offset = (k === 0 || k === points) ? 0 : side * amp;
        ctx.lineTo(x1 + ux * along + nx * offset, y1 + uy * along + ny * offset);
      }
      ctx.lineTo(x2, y2);
      ctx.stroke();
      ctx.restore();
    }
  }

  private static drawBoxes(ctx: CanvasRenderingContext2D, items: BoxShape[], vp: Viewport): void {
    for (let i = 0; i < items.length; i++) {
      const box = items[i];
      const w = vp.len(box.w);
      const h = vp.len(box.h);
      ctx.save();
      ctx.translate(vp.px(box.cx), vp.py(box.cy));
      ctx.rotate(-box.angleDeg * DEG);
      ctx.fillStyle = box.color;
      ctx.strokeStyle = box.color;
      if (box.fill === FillStyle.OUTLINE) {
        ctx.lineWidth = 2;
        ctx.strokeRect(-w / 2, -h / 2, w, h);
      } else {
        ctx.fillRect(-w / 2, -h / 2, w, h);
      }
      ctx.restore();
    }
  }

  private static drawCircles(ctx: CanvasRenderingContext2D, items: CircleShape[], vp: Viewport): void {
    for (let i = 0; i < items.length; i++) {
      const c = items[i];
      ctx.save();
      ctx.beginPath();
      ctx.arc(vp.px(c.cx), vp.py(c.cy), Math.max(1, vp.len(c.r)), 0, Math.PI * 2);
      if (c.fill === FillStyle.OUTLINE) {
        ctx.strokeStyle = c.color;
        ctx.lineWidth = 2;
        ctx.stroke();
      } else {
        ctx.fillStyle = c.color;
        ctx.fill();
      }
      ctx.restore();
    }
  }

  private static drawArrows(ctx: CanvasRenderingContext2D, items: ArrowShape[], vp: Viewport): void {
    for (let i = 0; i < items.length; i++) {
      const a = items[i];
      const x0 = vp.px(a.x);
      const y0 = vp.py(a.y);
      const ex = x0 + a.dx * vp.scale;
      // 画布 y 向下,世界里的 +dy 对应向上,故取负
      const ey = y0 - a.dy * vp.scale;
      const dx = ex - x0;
      const dy = ey - y0;
      const long = Math.sqrt(dx * dx + dy * dy);
      if (long < 6) {
        continue;
      }
      const ux = dx / long;
      const uy = dy / long;
      const head = Math.min(12, long * 0.3);

      ctx.save();
      ctx.strokeStyle = a.color;
      ctx.fillStyle = a.color;
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(x0, y0);
      ctx.lineTo(ex - ux * head, ey - uy * head);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(ex, ey);
      ctx.lineTo(ex - ux * head - uy * head * 0.45, ey - uy * head + ux * head * 0.45);
      ctx.lineTo(ex - ux * head + uy * head * 0.45, ey - uy * head - ux * head * 0.45);
      ctx.closePath();
      ctx.fill();

      if (a.label.length > 0) {
        ctx.font = 'bold 15vp sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(a.label, ex + ux * 14, ey + uy * 14);
      }
      ctx.restore();
    }
  }

  /**
   * 文字逐条按锚点画,并把整行兜回画布内。
   *
   * 模型层只知道米、不知道一行字占多少像素,任何"往旁边挪 0.12"的偏移都只是估计;
   * 越界的那一刀只能在有 measureText 的这一层补(V₂ 读数被裁成「3.6…」就是这么来的)。
   */
  private static drawLabels(ctx: CanvasRenderingContext2D, items: LabelShape[], vp: Viewport): void {
    for (let i = 0; i < items.length; i++) {
      const lb = items[i];
      ctx.save();
      ctx.fillStyle = lb.color;
      ctx.font = lb.sizeVp + 'vp sans-serif';
      // 逐条落到字面量上:canvas 的 textAlign 是有限枚举,直接喂 string 过不了类型检查
      const align = lb.align === 'center' ? 'center' : (lb.align === 'right' ? 'right' : 'left');
      ctx.textAlign = align;
      ctx.textBaseline = 'alphabetic';
      const width = ctx.measureText(lb.text).width;
      let px = vp.px(lb.x);
      if (align === 'left') {
        px = Math.min(Math.max(px, 0), ctx.width - width);
      } else if (align === 'center') {
        px = Math.min(Math.max(px, width / 2), ctx.width - width / 2);
      } else {
        px = Math.min(Math.max(px, width), ctx.width);
      }
      ctx.fillText(lb.text, px, vp.py(lb.y));
      ctx.restore();
    }
  }
}
