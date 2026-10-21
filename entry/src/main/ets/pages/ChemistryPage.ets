import { DeviceClass, Layout } from '../common/Layout';
import { Theme } from '../common/Theme';
import { Phase, ReactionSpec, ReactionText, Substance, Term } from '../chemistry/ChemistryModel';
import { ChemistryLibrary, Reagents } from '../chemistry/ChemistryLibrary';

function phaseLabel(phase: Phase): string {
  if (phase === Phase.SOLID) {
    return '固';
  }
  if (phase === Phase.LIQUID) {
    return '液';
  }
  if (phase === Phase.GAS) {
    return '气';
  }
  return '溶液';
}

function bandLabel(band: string): string {
  return band + '化学';
}

@Component
export struct ChemistryPage {
  @Prop hostWidth: number = 0;
  /** 宿主高度。转屏后高度变了,档位可能变(横屏手机不再是平板) */
  @Prop hostHeight: number = 0;
  @State reactions: ReactionSpec[] = [];
  @State query: string = '';

  aboutToAppear(): void {
    ChemistryLibrary.registerReagents();
    this.reactions = ChemistryLibrary.all();
  }

  private cls(): DeviceClass {
    return Layout.classify(this.hostWidth, this.hostHeight);
  }

  /** 矮屏(横屏手机):阅读列要收窄,一行塞 100 个汉字就不是阅读了 */
  private compact(): boolean {
    return Layout.isCompact(this.hostHeight);
  }

  private matched(): ReactionSpec[] {
    const text = this.query.trim().toLowerCase();
    if (text.length === 0) {
      return this.reactions;
    }
    return this.reactions.filter((spec: ReactionSpec) => {
      if (spec.title.toLowerCase().includes(text)) {
        return true;
      }
      if (ReactionText.equation(spec).toLowerCase().includes(text)) {
        return true;
      }
      return ChemistryPage.hasSubstance(spec, text);
    });
  }

  /** 计数行跟着搜索条件走:搜出零结果时,屏幕上不能还写着全库数量 */
  private searchSummary(): string {
    const matched = this.matched().length;
    if (this.query.trim().length === 0) {
      return '已收录 ' + this.reactions.length + ' 个反应 · ' + Reagents.size()
        + ' 种试剂，每条都已配平（元素种类、质量与电荷都守恒）';
    }
    return '匹配 ' + matched + ' / 共 ' + this.reactions.length + ' 个反应';
  }

  private static hasSubstance(spec: ReactionSpec, text: string): boolean {
    const all: Term[] = spec.reactants.concat(spec.products);
    for (let i = 0; i < all.length; i++) {
      const substance: Substance = all[i].substance;
      if (substance.name.toLowerCase().includes(text) || substance.formula.toLowerCase().includes(text)) {
        return true;
      }
    }
    return false;
  }

  @Builder
  substanceRow(terms: Term[]) {
    Text(terms.map((term: Term) => term.substance.name + '(' + term.substance.formula
      + '·' + phaseLabel(term.substance.phase) + ')').join(' + '))
      .fontSize(Layout.labelSize(this.cls()))
      .fontColor(Theme.TEXT_SECONDARY)
      .lineHeight(20)
  }

  @Builder
  numbered(items: string[], color: ResourceColor) {
    Column({ space: 4 }) {
      ForEach(items, (item: string, index: number) => {
        Row({ space: 6 }) {
          Text((index + 1).toString())
            .fontSize(Layout.captionSize(this.cls()))
            .fontColor(color)
          Text(item)
            .fontSize(Layout.labelSize(this.cls()))
            .fontColor(Theme.TEXT_PRIMARY)
            .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
      }, (item: string) => item)
    }
    .width('100%')
  }

  @Builder
  card(spec: ReactionSpec) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(bandLabel(spec.band))
          .fontSize(Layout.captionSize(this.cls()))
          .fontColor(Theme.ACCENT)
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .borderRadius(Layout.controlRadius(this.cls()))
          .backgroundColor(Theme.BAND_BG)
        Text(spec.title)
          .fontSize(Layout.cardTitleSize(this.cls()))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')

      Text(ReactionText.equation(spec))
        .fontSize(Layout.sectionSize(this.cls()))
        .fontColor(Theme.TEXT_PRIMARY)
        .fontWeight(FontWeight.Medium)
        .width('100%')

      if (spec.ionic !== null) {
        Text('离子式 ' + ReactionText.equation(spec.ionic))
          .fontSize(Layout.labelSize(this.cls()))
          .fontColor(Theme.TEXT_PRIMARY)
          .width('100%')
      }

      this.substanceRow(spec.reactants);
      this.substanceRow(spec.products);

      if (spec.conditions.length > 0) {
        Text('条件：' + spec.conditions.join('、'))
          .fontSize(Layout.labelSize(this.cls()))
          .fontColor(Theme.TEXT_SECONDARY)
      }

      Column({ space: 4 }) {
        Text('现象')
          .fontSize(Layout.captionSize(this.cls()))
          .fontColor(Theme.TEXT_SECONDARY)
        this.numbered(spec.phenomena, Theme.RUNNING)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      if (spec.safety.length > 0) {
        Column({ space: 4 }) {
          Text('注意与安全')
            .fontSize(Layout.captionSize(this.cls()))
            .fontColor(Theme.DANGER)
          this.numbered(spec.safety, Theme.DANGER)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(Layout.cardPadding(this.cls()))
    .backgroundColor(Theme.BG_CARD)
    .borderRadius(Layout.cardRadius(this.cls()))
  }

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        // 系统搜索件:放大镜、清除按钮、回车键都是它自带的,不用我们画图标
        Search({ value: this.query, placeholder: '搜索反应名称、物质名称或化学式' })
          .height(Layout.touchMin(this.cls()))
          .backgroundColor(Theme.BG_CARD)
          .textFont({ size: Layout.bodySize(this.cls()) })
          .placeholderFont({ size: Layout.bodySize(this.cls()) })
          .onChange((value: string) => {
            this.query = value;
          })

        // 搜索时这一行必须跟着变:原来永远报全库计数,
        // 学生搜出零结果却看到「已收录 22 个反应」,以为界面坏了
        Text(this.searchSummary())
          .fontSize(Layout.captionSize(this.cls()))
          .fontColor(Theme.TEXT_SECONDARY)

        List({ space: 12 }) {
          ForEach(this.matched(), (spec: ReactionSpec) => {
            ListItem() {
              this.card(spec)
            }
          }, (spec: ReactionSpec) => spec.id)
        }
        .layoutWeight(1)
        .width('100%')
        // 空结果不能是一片空白:说清没找到什么、下一步怎么办
        .visibility(this.matched().length > 0 ? Visibility.Visible : Visibility.None)

        if (this.matched().length === 0) {
          Column({ space: 8 }) {
            Text('没找到与「' + this.query.trim() + '」匹配的反应')
              .fontSize(Layout.bodySize(this.cls()))
              .fontColor(Theme.TEXT_PRIMARY)
            Text('化学式要连着写，如 H2SO4；也可以只输一种物质名，如「硫酸」或「氧气」。')
              .fontSize(Layout.captionSize(this.cls()))
              .fontColor(Theme.TEXT_SECONDARY)
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding(Layout.cardPadding(this.cls()))
        }
      }
      .padding({
        left: Layout.pageInsetX(this.hostWidth, this.cls(), this.compact()),
        right: Layout.pageInsetX(this.hostWidth, this.cls(), this.compact()),
        bottom: Layout.pageInset(this.cls())
      })
      .width('100%')
      .height('100%')
    }
    .title('反应速查表')
    .backgroundColor(Theme.BG_PAGE)
  }
}
