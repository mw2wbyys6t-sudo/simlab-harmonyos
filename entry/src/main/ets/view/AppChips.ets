import { Theme } from '../common/Theme';
import { ChipGroupItemOptions, ChipGroup, ChipItemStyle } from '@ohos.arkui.advanced.ChipGroup';
import { ChipSize } from '@ohos.arkui.advanced.Chip';

/**
 * 一行单选筛选器(系统的 ChipGroup)。
 *
 * 换掉它之前,每个页面都自己用 `Text + backgroundColor + border + onClick` 拼一排"看起来像
 * 筛选器"的东西:没有按下反馈、读屏软件读不出选中态,而且三处拼法各不相同。
 *
 * 尺寸固定用 SMALL:实测 NORMAL 档五颗学科筛选器在一行里放不下,最右那颗被屏幕切掉半字。
 */
@Component
export struct AppChips {
  @Prop labels: string[] = [];
  @Prop selected: number = 0;
  /** 选中档的底色:筛选器用主色,视图切换用学科色,免得两种语义看起来是一回事 */
  @Prop accent: ResourceColor = Theme.ACCENT;
  onPick: (index: number) => void = () => {
  };

  private items(): ChipGroupItemOptions[] {
    return this.labels.map((label: string): ChipGroupItemOptions => {
      const item: ChipGroupItemOptions = { label: { text: label } };
      return item;
    });
  }

  private style(): ChipItemStyle {
    const style: ChipItemStyle = {
      size: ChipSize.SMALL,
      fontColor: Theme.TEXT_SECONDARY,
      selectedFontColor: Theme.ON_BRAND,
      backgroundColor: Theme.BG_CARD,
      selectedBackgroundColor: this.accent
    };
    return style;
  }

  build() {
    ChipGroup({
      items: this.items(),
      selectedIndexes: [this.selected],
      multiple: false,
      itemStyle: this.style(),
      onChange: (indexes: number[]): void => {
        if (indexes.length > 0) {
          this.onPick(indexes[0]);
        }
      }
    })
  }
}
