import { GlassShapes } from '../geometry/GlassShapes';
import { VesselKind } from '../chemistry/BenchModel';
import { LathePainter, LatheSpec } from './LathePainter';

/**
 * 一只回转体容器的视图。
 *
 * 实验台一次要摆好几只,所以绘制上下文归组件自己持有,父组件只传"哪类器皿、装了几成、
 * 什么颜色"。Canvas 是命令式的:状态变了它不会自己重画,必须用 @Watch 把刷新入口接上。
 *
 * 这里不画分度:实验台的容量是「份」制,任何一套刻度线(哪怕不带数字)都在暗示一个
 * 并不存在的量程。量取页才画刻度与数字,因为那只量筒真的按 mL 判定。
 */
@Component
export struct VesselView {
  @Prop @Watch('repaint') kind: VesselKind = VesselKind.TUBE;
  @Prop @Watch('repaint') fillRatio: number = 0;
  @Prop @Watch('repaint') liquidColor: string = '#DCE6F2';

  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  repaint(): void {
    if (this.ctx.width <= 0 || this.ctx.height <= 0) {
      return;
    }
    const profile = GlassShapes.of(this.kind);
    const spec = new LatheSpec();
    spec.profile = profile;
    spec.volumeMl = Math.max(0, Math.min(1, this.fillRatio)) * profile.capacity();
    spec.liquidColor = this.liquidColor;
    spec.graduated = false;
    LathePainter.draw(this.ctx, spec);
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.repaint();
      })
      .onAreaChange((oldValue: Area, newValue: Area) => {
        this.repaint();
      })
  }
}
