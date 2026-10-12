import { common } from '@kit.AbilityKit';
import { Theme } from '../common/Theme';

/**
 * 画布侧的调色板。
 *
 * 与 `chemistry/BenchModel` 里那个 `Palette` 不是一回事:那个查的是"某物质的溶液该画什么色",
 * 这个把主题令牌解成字符串。同名是因为两者都叫调色板,读代码时按 import 路径区分。
 *
 * `CanvasRenderingContext2D.fillStyle` 只接受字符串,不接受 `Resource` —— 所以
 * 组件层可以直接用 `Theme.X`(系统会按当前深浅模式取色),而画布层必须先把同一个
 * 令牌**解成 hex**。解的动作放在这里,只做一次并缓存,保证画布和组件用的是同一份值,
 * 而不是各自维护一套(那正是"图线和卡片颜色对不上"的来源)。
 *
 * 切换深浅模式后要 `reset()`:缓存里是旧模式的 hex,不清掉就会画出一半新一半旧。
 */
export class Palette {
  private static context: common.Context | undefined = undefined;
  private static cache: Map<number, string> = new Map();

  /**
   * 由带 UIContext 的组件在 aboutToAppear 里绑。
   *
   * 每次绑都清缓存:setColorMode 之后系统会换掉 resource manager,同一个 context 解出来的
   * 色也变了。绑定的次数很少(一个画布一次),多清一次比留着一半旧色便宜。
   */
  static bind(context: common.Context | undefined): void {
    if (context !== undefined) {
      Palette.context = context;
      Palette.cache.clear();
    }
  }

  static reset(): void {
    Palette.cache.clear();
  }

  static color(res: Resource): string {
    const key = res.id === undefined ? -1 : res.id;
    const hit = Palette.cache.get(key);
    if (hit !== undefined) {
      return hit;
    }
    if (Palette.context === undefined) {
      // 品红而不是透明:没绑定解析器是一件编程错误,透明会让它静默成"看不见的小 bug"。
      // 这一轮就踩过一次(量取页三条判读线整排透明,不报错、不崩溃)。
      return '#FF00FF';
    }
    const argb = Palette.context.resourceManager.getColorSync(res);
    const value = '#' + (argb >>> 0).toString(16).padStart(8, '0').slice(2);
    Palette.cache.set(key, value);
    return value;
  }

  static canvasBg(): string {
    return Palette.color(Theme.BG_CANVAS);
  }

  /** 图线画在卡片上,底色是 bg_card 而不是画布那张"纸" */
  static cardBg(): string {
    return Palette.color(Theme.BG_CARD);
  }

  static textPrimary(): string {
    return Palette.color(Theme.TEXT_PRIMARY);
  }

  static textSecondary(): string {
    return Palette.color(Theme.TEXT_SECONDARY);
  }

  static divider(): string {
    return Palette.color(Theme.DIVIDER);
  }

  /** 判读线/游标要画在画布上,所以语义色也得能解成字符串 */
  static accent(): string {
    return Palette.color(Theme.ACCENT);
  }

  static running(): string {
    return Palette.color(Theme.RUNNING);
  }

  static danger(): string {
    return Palette.color(Theme.DANGER);
  }

  /** 图线索引用:画布拿不到 Resource,这里按序号解成 hex */
  static series(index: number): string {
    if (index === 0) {
      return Palette.color(Theme.SERIES_1);
    }
    if (index === 1) {
      return Palette.color(Theme.SERIES_2);
    }
    if (index === 2) {
      return Palette.color(Theme.SERIES_3);
    }
    return Palette.color(Theme.SERIES_4);
  }
}
