import { DeviceClass, Layout } from '../common/Layout';
import { Theme } from '../common/Theme';

/** 按钮的三种角色。系统只给交互态与形状,颜色仍由 Theme 决定 */
export enum ButtonVariant {
  /** 主操作:实心底 */
  PRIMARY = 'primary',
  /** 次操作:卡片底 + 描边 */
  SECONDARY = 'secondary',
  /** 行内文字按钮(删除、展开/收起) */
  LINK = 'link'
}

/**
 * 全应用唯一的按钮。
 *
 * 换掉它之前,工程里**一个原生 `Button` 都没有**:每颗"按钮"都是一个带 onClick 的 `Text`。
 * 后果不只是不好看 —— `Text` 按下没有任何反馈,读屏软件不会念出"按钮",焦点也走不到它上面;
 * 普查里"点了以为没反应"那一类缺陷有一半是这么来的。
 *
 * 尺寸、圆角、字阶仍然走 `Layout` 的令牌:换成原生件不等于放弃设计系统,
 * 只是把"按下去会怎样"这件事交还给系统。
 */
@Component
export struct AppButton {
  @Prop label: string = '';
  @Prop cls: DeviceClass = DeviceClass.PHONE;
  @Prop variant: ButtonVariant = ButtonVariant.PRIMARY;
  /** 主色/强调色:PRIMARY 用作底色,LINK 与 SECONDARY 用作字色 */
  @Prop accent: ResourceColor = Theme.ACCENT;
  /** 手机档竖排时占满一行;横排的动作条按内容宽 */
  @Prop fullWidth: boolean = false;
  onPress: () => void = () => {
  };

  private ink(): ResourceColor {
    if (this.variant === ButtonVariant.PRIMARY) {
      // 品牌底上的字色是调色板里的一对设计值:浅色档白字、深色档近黑字。
      // 原来这里写死 Color.White —— 深色档强调色被提亮了,白字压上去就糊了。
      return Theme.ON_BRAND;
    }
    return this.accent;
  }

  private shell(): ResourceColor {
    if (this.variant === ButtonVariant.PRIMARY) {
      return this.accent;
    }
    return this.variant === ButtonVariant.SECONDARY ? Theme.BG_CARD : Color.Transparent;
  }

  private hairline(): BorderOptions {
    const edge = this.variant === ButtonVariant.SECONDARY ? Theme.DIVIDER : Color.Transparent;
    return { width: 1, color: edge };
  }

  /**
   * 三个分支只差一个 `.width()`。
   *
   * 不是为了好看才写成这样:ArkUI 的属性链不能按条件跳过一环,
   * 而 `.width()` 也没有"保持内容宽"这个取值 —— 传 'auto' 会被当成 0。
   */
  build() {
    if (this.fullWidth) {
      Button(this.label, { type: ButtonType.ROUNDED_RECTANGLE, stateEffect: true })
        .fontSize(this.variant === ButtonVariant.LINK
          ? Layout.captionSize(this.cls) : Layout.bodySize(this.cls))
        .fontWeight(this.variant === ButtonVariant.PRIMARY ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.ink())
        .backgroundColor(this.shell())
        .border(this.hairline())
        .borderRadius(Layout.controlRadius(this.cls))
        .height(Layout.buttonHeight(this.cls))
        .width('100%')
        .padding({ left: 16, right: 16 })
        .onClick((): void => {
          this.onPress();
        })
    } else if (this.variant === ButtonVariant.LINK) {
      // 文字按钮交给系统的 TEXT 样式:它负责按下时的透明度,我们只给颜色
      Button(this.label, {
        type: ButtonType.Normal,
        stateEffect: true,
        buttonStyle: ButtonStyleMode.TEXTUAL
      })
        .fontSize(Layout.captionSize(this.cls))
        .fontColor(this.accent)
        .backgroundColor(Color.Transparent)
        .borderRadius(Layout.controlRadius(this.cls))
        .height(Layout.touchMin(this.cls))
        .padding({ left: 8, right: 8 })
        .onClick((): void => {
          this.onPress();
        })
    } else {
      Button(this.label, { type: ButtonType.ROUNDED_RECTANGLE, stateEffect: true })
        .fontSize(Layout.bodySize(this.cls))
        .fontWeight(this.variant === ButtonVariant.PRIMARY ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.ink())
        .backgroundColor(this.shell())
        .border(this.hairline())
        .borderRadius(Layout.controlRadius(this.cls))
        .height(Layout.buttonHeight(this.cls))
        .padding({ left: 16, right: 16 })
        .onClick((): void => {
          this.onPress();
        })
    }
  }
}
