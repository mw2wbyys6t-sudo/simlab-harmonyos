/**
 * 图线坐标系与"这张图到底画不画得出来"的判定。
 *
 * 单独成模块而不是留在 SeriesChart 里,是因为这段算术决定了一类很难发现的缺陷:
 * 手机档两张图平分一个 190vp 的固定高度,每张只剩 90vp,扣掉标题与两行刻度后
 * 净高变成负数 —— 于是图线区**静默不画**,学生跑了半天看到的是两张白纸。
 * 算术挪到这里之后,「90vp 画不出」和「150vp 画得出」都能被离线断言钉住。
 */

/** 一次绘制内共享的坐标系,避免每条曲线重算量程。 */
export class PlotFrame {
  left: number = 0;
  top: number = 0;
  width: number = 0;
  height: number = 0;
  xLow: number = 0;
  xSpan: number = 1;
  yLow: number = 0;
  ySpan: number = 1;
  font: number = 11;
}

export class PlotLayout {
  /** 绘图区净高低于这个值就没有读图价值:网格线、刻度、曲线会糊成一团 */
  static readonly MIN_PLOT: number = 40;
  /** 宽方向的下限,再窄连一个纵轴刻度标签都放不下 */
  static readonly MIN_WIDTH: number = 60;

  /** 字号按画布宽选:大屏要能被后排学生看见 */
  static fontFor(w: number): number {
    return w > 700 ? 14 : 11;
  }

  /**
   * 画布尺寸 → 绘图框。
   *
   * 顶部留给标题(1 个字号 + 16),底部要同时放得下刻度行与轴标题行
   * (原先只留 2.2 个字号,两行会叠在一起,所以是 4.6 个)。
   */
  static frameFor(w: number, h: number): PlotFrame {
    const fs = PlotLayout.fontFor(w);
    const frame = new PlotFrame();
    frame.font = fs;
    frame.left = fs * 3.6;
    frame.top = fs + 16;
    frame.width = w - frame.left - fs;
    frame.height = h - frame.top - fs * 4.6;
    return frame;
  }

  static drawable(frame: PlotFrame): boolean {
    return frame.width >= PlotLayout.MIN_WIDTH && frame.height >= PlotLayout.MIN_PLOT;
  }

  /**
   * 画不出来时必须说清为什么画不出来。
   *
   * 静默 return 是这条缺陷最难发现的部分:画面看起来"就是没有曲线",
   * 而不是"这里本该有图但放不下"。
   */
  static hintFor(w: number, h: number): string {
    const frame = PlotLayout.frameFor(w, h);
    if (PlotLayout.drawable(frame)) {
      return '';
    }
    if (frame.width < PlotLayout.MIN_WIDTH) {
      return '图线太窄,转横屏或收起侧栏后可见';
    }
    return '图线区太矮,收起仿真画面后可见';
  }
}
