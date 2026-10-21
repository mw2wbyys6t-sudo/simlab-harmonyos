import { common } from '@kit.AbilityKit';
import { Appearance } from '../common/Appearance';
import { DeviceClass, Layout } from '../common/Layout';
import { Theme } from '../common/Theme';
import { AppearanceStore } from '../platform/AppearanceStore';
import { AppChips } from '../view/AppChips';

/**
 * 显示设置:深浅色三档开关。
 *
 * 为什么做成应用内开关而不是跟着系统走:整套主题色原来是硬钉浅色的,
 * 教室里投影和家用平板是两种光环境,学生应该能自己选,而不是被系统设置代选。
 *
 * 页面自己不管系统 API:`Appearance` 出档位、`AppearanceStore` 负责落盘与生效。
 */
@Component
export struct SettingsPage {
  @Prop hostWidth: number = 0;
  /** 宿主高度。转屏后高度变了,档位可能变(横屏手机不再是平板) */
  @Prop hostHeight: number = 0;
  @State choice: string = Appearance.SYSTEM;

  private cls(): DeviceClass {
    return Layout.classify(this.hostWidth, this.hostHeight);
  }

  /** 矮屏(横屏手机):阅读列要收窄,一行塞 100 个汉字就不是阅读了 */
  private compact(): boolean {
    return Layout.isCompact(this.hostHeight);
  }

  aboutToAppear(): void {
    const context = this.abilityContext();
    if (context !== undefined) {
      this.choice = AppearanceStore.load(context);
    }
  }

  private abilityContext(): common.UIAbilityContext | undefined {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private pick(index: number): void {
    const next: string = Appearance.at(index);
    this.choice = next;
    const context = this.abilityContext();
    if (context !== undefined) {
      AppearanceStore.save(context, next);
      AppearanceStore.apply(context, next);
    }
  }

  private hint(): string {
    if (this.choice === Appearance.DARK) {
      return '深色底：弱光下不刺眼。实验画布仍保持浅底，图线与器材的颜色不跟着反转。';
    }
    if (this.choice === Appearance.LIGHT) {
      return '浅色底：教室投影下最稳，不依赖系统设置。';
    }
    return '跟随系统：手机开了深色模式时应用一起变。';
  }

  build() {
    NavDestination() {
      Column({ space: Layout.listGap(this.cls()) }) {
        AppChips({
          labels: Appearance.LABELS,
          selected: Appearance.indexOf(this.choice),
          onPick: (index: number): void => {
            this.pick(index);
          }
        })
          .width('100%')

        Text(this.hint())
          .fontSize(Layout.bodySize(this.cls()))
          .fontColor(Theme.TEXT_SECONDARY)
          .width('100%')

        Text('这里的设置会存下来，下次打开还是这一档。')
          .fontSize(Layout.captionSize(this.cls()))
          .fontColor(Theme.TEXT_SECONDARY)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({
        left: Layout.pageInsetX(this.hostWidth, this.cls(), this.compact()),
        right: Layout.pageInsetX(this.hostWidth, this.cls(), this.compact()),
        top: Layout.listGap(this.cls()),
        bottom: Layout.pageInset(this.cls())
      })
    }
    .title('深浅色')
    .backgroundColor(Theme.BG_PAGE)
  }
}
