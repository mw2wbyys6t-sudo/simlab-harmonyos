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
  @State reactions: ReactionSpec[] = [];
  @State query: string = '';

  aboutToAppear(): void {
    ChemistryLibrary.registerReagents();
    this.reactions = ChemistryLibrary.all();
  }

  private cls(): DeviceClass {
    return Layout.classify(this.hostWidth);
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
  numbered(items: string[], color: string) {
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
          .backgroundColor('#EAF1F9')
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
        TextInput({ text: this.query, placeholder: '搜索反应名称、物质名称或化学式' })
          .height(Layout.touchMin(this.cls()))
          .fontSize(Layout.bodySize(this.cls()))
          .backgroundColor(Theme.BG_CARD)
          .onChange((value: string) => {
            this.query = value;
          })

        Text('已收录 ' + this.reactions.length + ' 个反应 · ' + Reagents.size() + ' 种试剂，全部通过元素、质量与电荷守恒校验')
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
      }
      .padding({ left: 16, right: 16, bottom: 12 })
      .width('100%')
      .height('100%')
    }
    .title('反应速查表')
    .backgroundColor(Theme.BG_PAGE)
  }
}
