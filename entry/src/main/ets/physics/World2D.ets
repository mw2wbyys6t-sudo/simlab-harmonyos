/**
 * 2D 场景图:仿真世界给渲染层看到的全部内容。
 *
 * 求解器只负责往这里填图元,绘制代码集中在 CanvasPainter 一处。
 * 好处是新增力学/光学等 2D 实验时只写求解器,不需要再写一个 View。
 * 世界坐标单位为米,x 向右、y 向上;翻转与缩放由绘制层统一处理。
 */

export enum FillStyle {
  SOLID = 'solid',
  OUTLINE = 'outline'
}

export class BoxShape {
  cx: number = 0;
  cy: number = 0;
  w: number = 1;
  h: number = 1;
  /** 绕自身中心旋转,度 */
  angleDeg: number = 0;
  color: string = '#3A7BD5';
  fill: FillStyle = FillStyle.SOLID;
}

export class CircleShape {
  cx: number = 0;
  cy: number = 0;
  r: number = 0.2;
  color: string = '#3A7BD5';
  fill: FillStyle = FillStyle.SOLID;
}

export class SegmentShape {
  x1: number = 0;
  y1: number = 0;
  x2: number = 0;
  y2: number = 0;
  color: string = '#4E5A6B';
  widthMm: number = 3;
  dashed: boolean = false;
}

/** 螺旋弹簧:两个端点 + 圈数 + 摆幅,由绘制层展开成折线 */
export class SpringShape {
  x1: number = 0;
  y1: number = 0;
  x2: number = 0;
  y2: number = 0;
  coils: number = 8;
  amplitude: number = 0.18;
  color: string = '#8E5BD9';
}

export class LabelShape {
  x: number = 0;
  y: number = 0;
  text: string = '';
  sizeVp: number = 14;
  color: string = '#1F2A3A';
}

/** 带标签的矢量,用于力、速度、加速度 */
export class ArrowShape {
  x: number = 0;
  y: number = 0;
  dx: number = 1;
  dy: number = 0;
  label: string = '';
  color: string = '#E2574C';
}

export class WorldSnapshot {
  boxes: BoxShape[] = [];
  circles: CircleShape[] = [];
  segments: SegmentShape[] = [];
  springs: SpringShape[] = [];
  labels: LabelShape[] = [];
  arrows: ArrowShape[] = [];

  clear(): void {
    this.boxes.length = 0;
    this.circles.length = 0;
    this.segments.length = 0;
    this.springs.length = 0;
    this.labels.length = 0;
    this.arrows.length = 0;
  }
}

/** 世界坐标到画布的映射:保持纵横比居中放置,避免图形被拉扁。 */
export class Viewport {
  worldWidth: number = 10;
  worldHeight: number = 6;
  scale: number = 1;
  offsetX: number = 0;
  offsetY: number = 0;

  fit(canvasWidth: number, canvasHeight: number): void {
    const sx = canvasWidth / this.worldWidth;
    const sy = canvasHeight / this.worldHeight;
    this.scale = sx < sy ? sx : sy;
    this.offsetX = (canvasWidth - this.worldWidth * this.scale) / 2;
    this.offsetY = (canvasHeight - this.worldHeight * this.scale) / 2;
  }

  /** 世界 x → 画布 x */
  px(wx: number): number {
    return this.offsetX + wx * this.scale;
  }

  /** 世界 y → 画布 y(翻转:世界向上为正,画布向下为正) */
  py(wy: number): number {
    return this.offsetY + (this.worldHeight - wy) * this.scale;
  }

  /** 世界长度 → 画布像素 */
  len(worldLength: number): number {
    return worldLength * this.scale;
  }
}
