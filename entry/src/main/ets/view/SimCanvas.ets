import { displaySync } from '@kit.ArkGraphics2D';
import { ExperimentMeta } from '../model/ExperimentTypes';
import { Physics2DRunner } from '../physics/Physics2DRunner';
import { Viewport } from '../physics/World2D';
import { RunController } from '../runner/RunController';
import { Theme } from '../common/Theme';
import { DeviceClass, Layout } from '../common/Layout';
import { CanvasPainter } from './CanvasPainter';

/**
 * 2D 仿真的承载组件:vsync 节拍 → 定步长推进 → 命令式重绘。
 *
 * 这里刻意不触碰 @State。Canvas 每帧重绘是命令式的,若把帧驱动接到状态变量上,
 * 整棵页面树会跟着 60Hz 重建;读数刷新交给页面侧的低频定时器。
 */
@Component
export struct SimCanvas {
  controller: RunController = new RunController();
  scene: Physics2DRunner | null = null;
  meta: ExperimentMeta = new ExperimentMeta();
  @Prop hostWidth: number = 0;

  private cls(): DeviceClass {
    return Layout.classify(this.hostWidth);
  }

  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private vsync: displaySync.DisplaySync = displaySync.create();
  private vp: Viewport = new Viewport();
  private lastAt: number = 0;
  private frameCb: Callback<displaySync.IntervalInfo> = (): void => {
    this.tick();
  };

  aboutToAppear(): void {
    this.vp.worldWidth = this.meta.worldWidth;
    this.vp.worldHeight = this.meta.worldHeight;
  }

  aboutToDisappear(): void {
    this.vsync.off('frame', this.frameCb);
    this.vsync.stop();
  }

  private tick(): void {
    const now = Date.now();
    const dt = this.lastAt === 0 ? 0 : (now - this.lastAt) / 1000;
    this.lastAt = now;
    this.controller.advance(dt);
    this.render();
  }

  private render(): void {
    if (this.scene === null) {
      return;
    }
    const w = this.ctx.width;
    const h = this.ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    this.vp.fit(w, h);
    CanvasPainter.draw(this.ctx, this.scene.snapshot(), this.vp);
  }

  build() {
    Canvas(this.ctx)
      .layoutWeight(1)
      .width('100%')
      .backgroundColor(Theme.BG_CANVAS)
      .borderRadius(Layout.cardRadius(this.cls()))
      .onReady(() => {
        this.render();
        this.lastAt = Date.now();
        this.vsync.on('frame', this.frameCb);
        this.vsync.start();
      })
  }
}
