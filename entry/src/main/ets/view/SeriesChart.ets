import { ChartDef, ChartSeries } from '../model/ExperimentTypes';
import { RunController } from '../runner/RunController';
import { Theme } from '../common/Theme';
import { DeviceClass, Layout } from '../common/Layout';

const GRID = '#E1E6ED';
const AXIS_TEXT = '#6B7A8D';
/** 超过这个点数就抽稀。600 点在手绘曲线上已看不出折线感,再密只是白画。 */
const MAX_POINTS = 600;

/** 一次绘制内共享的坐标系,避免每条曲线重算量程。 */
class PlotFrame {
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

/**
 * 通用图线:横轴取采样时间或任一观测量,纵轴叠若干同单位曲线。
 * 横轴可换成观测量这一点,让 x-t 图与 U-I 图共用这一套绘制代码。
 *
 * 重绘由页面低频 tick 触发,不自挂 vsync:图线 10Hz 已足够平滑,
 * 帧回调留给仿真画布独占。
 */
@Component
export struct SeriesChart {
  chart: ChartDef = new ChartDef();
  controller: RunController = new RunController();
  @Prop hostWidth: number = 0;
  @Prop @Watch('redraw') tick: number = 0;
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  private cls(): DeviceClass {
    return Layout.classify(this.hostWidth);
  }

  redraw(): void {
    this.draw();
  }

  private seriesOf(key: string): number[] {
    const hit = this.controller.series.get(key);
    return hit === undefined ? [] : hit;
  }

  private static pick(span: number): number {
    if (span >= 100) {
      return 0;
    }
    if (span >= 1) {
      return 1;
    }
    if (span >= 0.01) {
      return 3;
    }
    return 4;
  }

  /**
   * 一张图里各曲线的量程。取 RunController 在写入样本时记下的历史极值,
   * 而不是每次重绘都把几万个点重扫一遍。
   */
  private extentOf(key: string, includeOrigin: boolean): number[] {
    if (key === 't') {
      const times = this.controller.times;
      if (times.length === 0) {
        return [0, 1];
      }
      return [0, times[times.length - 1]];
    }
    const raw = this.controller.extentOf(key);
    let low = raw[0];
    let high = raw[1];
    if (!Number.isFinite(low) || !Number.isFinite(high)) {
      return [0, 1];
    }
    if (includeOrigin) {
      low = low > 0 ? 0 : low;
      high = high < 0 ? 0 : high;
    }
    if (high - low < 1e-12) {
      // 读数恒定(比如开关未闭合)时给一个可视窗口,别让曲线贴着轴消失
      return [low - 1, high + 1];
    }
    return [low, high];
  }

  private draw(): void {
    const w = this.ctx.width;
    const h = this.ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    const ctx = this.ctx;
    ctx.fillStyle = Theme.BG_CARD;
    ctx.fillRect(0, 0, w, h);

    const fs = w > 700 ? 14 : 11;
    ctx.fillStyle = Theme.TEXT_PRIMARY;
    ctx.font = 'bold ' + fs + 'vp sans-serif';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'alphabetic';
    ctx.fillText(this.chart.title, 10, fs + 4);

    const frame = new PlotFrame();
    frame.font = fs;
    frame.left = fs * 3.6;
    frame.top = fs + 16;
    frame.width = w - frame.left - fs;
    // 底部要同时放得下刻度行与轴标题行,原先只留 2.2 个字号,两行会叠在一起
    frame.height = h - frame.top - fs * 4.6;
    if (frame.width <= 20 || frame.height <= 20) {
      return;
    }

    const times = this.controller.times;
    const xs = this.chart.xKey === 't' ? times : this.seriesOf(this.chart.xKey);
    if (!SeriesChart.plottable(xs, this.chart, this)) {
      ctx.fillStyle = AXIS_TEXT;
      ctx.font = fs + 'vp sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('运行实验或调节参数后开始描点', frame.left + frame.width / 2,
        frame.top + frame.height / 2);
      return;
    }

    const xRange = this.extentOf(this.chart.xKey, false);
    let yLow = Number.POSITIVE_INFINITY;
    let yHigh = Number.NEGATIVE_INFINITY;
    for (let i = 0; i < this.chart.series.length; i++) {
      const span = this.extentOf(this.chart.series[i].observableKey, this.chart.includeOrigin);
      yLow = span[0] < yLow ? span[0] : yLow;
      yHigh = span[1] > yHigh ? span[1] : yHigh;
    }
    if (yHigh - yLow < 1e-12) {
      yLow -= 1;
      yHigh += 1;
    }
    frame.xLow = xRange[0];
    frame.xSpan = xRange[1] - xRange[0];
    frame.yLow = yLow;
    frame.ySpan = yHigh - yLow;

    /*
     * 纵轴刻度是按 `toFixed` 出来的字符串右对齐画的,而左边界原先按字号固定成 fs*3.6。
     * 一旦读数带上负号与三位小数(基尔霍夫场景的 −0.240 就是),字符串比这块留白宽,
     * 于是刻度压到旋转的轴标题上、甚至顶出画布。所以量一次最宽刻度再定左边界。
     */
    const yDecimals = SeriesChart.pick(frame.ySpan);
    ctx.font = fs + 'vp sans-serif';
    let widest = 0;
    for (let i = 0; i <= 4; i++) {
      const label = (yHigh - frame.ySpan * (i / 4)).toFixed(yDecimals);
      const labelWidth = ctx.measureText(label).width;
      if (labelWidth > widest) {
        widest = labelWidth;
      }
    }
    frame.left = Math.max(fs * 3.6, widest + fs * 2.8);
    frame.width = w - frame.left - fs;
    if (frame.width <= 20) {
      return;
    }

    this.drawGrid(frame, xs, xRange, yLow, yHigh, yDecimals);
    for (let i = 0; i < this.chart.series.length; i++) {
      this.drawTrace(this.chart.series[i], xs, frame, i);
    }
  }

  private static plottable(xs: number[], chart: ChartDef, host: SeriesChart): boolean {
    if (xs.length < 2) {
      return false;
    }
    for (let i = 0; i < chart.series.length; i++) {
      if (host.seriesOf(chart.series[i].observableKey).length < 2) {
        return false;
      }
    }
    return true;
  }

  private drawGrid(frame: PlotFrame, xs: number[], xRange: number[], yLow: number, yHigh: number,
    yDecimals: number): void {
    const ctx = this.ctx;
    const fs = frame.font;
    const xDecimals = SeriesChart.pick(frame.xSpan);

    ctx.strokeStyle = GRID;
    ctx.lineWidth = 1;
    ctx.font = fs + 'vp sans-serif';
    ctx.textBaseline = 'alphabetic';
    for (let i = 0; i <= 4; i++) {
      const gx = frame.left + frame.width * (i / 4);
      const gy = frame.top + frame.height * (i / 4);
      ctx.beginPath();
      ctx.moveTo(gx, frame.top);
      ctx.lineTo(gx, frame.top + frame.height);
      ctx.moveTo(frame.left, gy);
      ctx.lineTo(frame.left + frame.width, gy);
      ctx.stroke();

      ctx.fillStyle = AXIS_TEXT;
      ctx.textAlign = 'center';
      ctx.fillText((xRange[0] + frame.xSpan * (i / 4)).toFixed(xDecimals), gx,
        frame.top + frame.height + fs + 4);
      ctx.textAlign = 'right';
      ctx.fillText((yHigh - frame.ySpan * (i / 4)).toFixed(yDecimals), frame.left - 6,
        gy + fs / 2 - 2);
    }

    ctx.fillStyle = AXIS_TEXT;
    ctx.textAlign = 'center';
    ctx.fillText(SeriesChart.axisTitle(this.chart.xLabel, this.chart.xUnit),
      frame.left + frame.width / 2, frame.top + frame.height + fs * 4.0);
    ctx.save();
    ctx.translate(9, frame.top + frame.height / 2);
    ctx.rotate(-Math.PI / 2);
    ctx.fillText(SeriesChart.axisTitle(this.chart.yLabel, this.chart.yUnit), 0, 0);
    ctx.restore();
  }

  private static axisTitle(label: string, unit: string): string {
    return unit.length > 0 ? label + ' / ' + unit : label;
  }

  private drawTrace(series: ChartSeries, xs: number[], frame: PlotFrame, order: number): void {
    const ys = this.seriesOf(series.observableKey);
    const ctx = this.ctx;
    const stride = Math.max(1, Math.floor(ys.length / MAX_POINTS));

    ctx.strokeStyle = series.color;
    ctx.lineWidth = 2;
    ctx.lineJoin = 'round';
    ctx.beginPath();
    let started = false;
    for (let i = 0; i < ys.length; i += stride) {
      const y = ys[i];
      const x = xs[i];
      if (Number.isNaN(y) || Number.isNaN(x)) {
        started = false;
        continue;
      }
      const px = frame.left + (x - frame.xLow) / frame.xSpan * frame.width;
      const py = frame.top + frame.height - (y - frame.yLow) / frame.ySpan * frame.height;
      if (started) {
        ctx.lineTo(px, py);
      } else {
        ctx.moveTo(px, py);
        started = true;
      }
    }
    ctx.stroke();

    ctx.fillStyle = series.color;
    ctx.font = frame.font + 'vp sans-serif';
    ctx.textAlign = 'right';
    ctx.textBaseline = 'middle';
    ctx.fillText(series.label, frame.left + frame.width - frame.font * 0.9,
      frame.top + 6 + order * (frame.font + 5));
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG_CARD)
      .borderRadius(Layout.cardRadius(this.cls()))
      .onReady(() => {
        this.draw();
      })
  }
}
