/**
 * WCAG 2.1 相对亮度与对比度。
 *
 * 为什么要有它:学科辅色要承担识别度,饱和度必然高;而文字压在上面必须可读。
 * 靠人眼挑「看起来够深」的颜色,换一套配色就得重新检查一遍。对比度是算出来的。
 */
export class Contrast {
  /** 解析 #RGB / #RRGGBB 的第 index 个通道(0=R,1=G,2=B),返回 0..1;非法输入为 NaN */
  private static channel(hex: string, index: number): number {
    const shortened = hex.length === 4;
    const expanded = hex.length === 7;
    if ((!shortened && !expanded) || hex.charAt(0) !== '#') {
      return Number.NaN;
    }
    const step = shortened ? 1 : 2;
    const start = 1 + index * step;
    const text = shortened ? hex.charAt(start) + hex.charAt(start) : hex.substring(start, start + 2);
    const value = parseInt(text, 16);
    if (Number.isNaN(value) || value < 0 || value > 255) {
      return Number.NaN;
    }
    return value / 255;
  }

  /** sRGB 解码到线性光。0.04045 与系数取自 WCAG 定义,不是拟合出来的 */
  private static linear(channel: number): number {
    if (Number.isNaN(channel)) {
      return Number.NaN;
    }
    if (channel <= 0.04045) {
      return channel / 12.92;
    }
    return Math.pow((channel + 0.055) / 1.055, 2.4);
  }

  static luminance(hex: string): number {
    const r = Contrast.linear(Contrast.channel(hex, 0));
    const g = Contrast.linear(Contrast.channel(hex, 1));
    const b = Contrast.linear(Contrast.channel(hex, 2));
    if (Number.isNaN(r) || Number.isNaN(g) || Number.isNaN(b)) {
      return Number.NaN;
    }
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /** 对比度恒 ≥ 1,与顺序无关,最大 21(纯黑对白) */
  static ratio(a: string, b: string): number {
    const la = Contrast.luminance(a);
    const lb = Contrast.luminance(b);
    if (Number.isNaN(la) || Number.isNaN(lb)) {
      return Number.NaN;
    }
    const lighter = la > lb ? la : lb;
    const darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }
}
