import { CircleShape, LabelShape, SegmentShape, WorldSnapshot } from './World2D';
import { TickerTape } from './TickerTape';

/** 点距展开倍数:1:1 时毫米级间距在屏幕上不到一个像素,而真实数据不动 */
export const TAPE_SCALE = 6;

const C_STRIP = '#B9C2CC';
const C_DOT = '#25313F';
const C_MARK = '#2F6FB5';
const C_TEXT = '#1F2A3A';
const DOT_R = 0.022;

/**
 * 纸带的画法:一条横带 + 上面一排点,计数点放大成蓝点。
 *
 * 抽出来是因为两条实验共用同一条带子:测加速度把它挂在斜面顶上,验证机械能守恒
 * 把它挂在铁架台旁边。两处的**数据**都由 TickerTape 算,这里只负责按同一比例画出来,
 * 免得两条实验对同一条纸带画出两种样子。
 */
export class TapeStrip {
  /** 画在 (x, y) 这一条上;start/every 是学生选的计数约定 */
  static paint(snap: WorldSnapshot, tape: TickerTape, x: number, y: number,
    start: number, every: number, note: string): void {
    const count = tape.count();
    const first = tape.dotAt(0);
    if (first === null) {
      return;
    }
    const length = tape.tapeLength() * TAPE_SCALE;
    const span = length < 0.6 ? 0.6 : length + 0.4;
    snap.segments.push(TapeStrip.line(x - 0.15, y - 0.24, x + span, y - 0.24));
    snap.segments.push(TapeStrip.line(x - 0.15, y + 0.24, x + span, y + 0.24));

    const gap = every < 1 ? 1 : every;
    const from = start < 0 ? 0 : start;
    for (let i = 0; i < count; i++) {
      const dot = tape.dotAt(i);
      if (dot === null) {
        continue;
      }
      const shape = new CircleShape();
      shape.cx = x + (dot.s - first.s) * TAPE_SCALE;
      shape.cy = y;
      const isMark = i >= from && (i - from) % gap === 0;
      shape.r = isMark ? DOT_R * 1.5 : DOT_R;
      shape.color = isMark ? C_MARK : C_DOT;
      snap.circles.push(shape);
    }
    // 不给计数点编号:前几个点彼此只隔几毫米,编号会挤成一团盖住真正要看的东西(实测)
    if (note.length > 0) {
      const tag = new LabelShape();
      tag.x = x - 0.15;
      tag.y = y + 0.46;
      tag.text = note;
      tag.sizeVp = 11;
      tag.color = C_TEXT;
      snap.labels.push(tag);
    }
  }

  private static line(x1: number, y1: number, x2: number, y2: number): SegmentShape {
    const seg = new SegmentShape();
    seg.x1 = x1;
    seg.y1 = y1;
    seg.x2 = x2;
    seg.y2 = y2;
    seg.color = C_STRIP;
    seg.widthMm = 1.2;
    return seg;
  }
}
