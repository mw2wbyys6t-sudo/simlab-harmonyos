import { DeviceClass, Layout } from '../common/Layout';
import { Theme } from '../common/Theme';
import { ReactionSpec, Substance } from '../chemistry/ChemistryModel';
import { BenchEngine } from '../chemistry/BenchEngine';
import { BenchView, PORTION_MOLES, Vessel, VesselKind } from '../chemistry/BenchModel';
import { ChemistryLibrary, Reagents } from '../chemistry/ChemistryLibrary';
import { VesselView } from '../view3d/VesselView';

/** 容器的显示快照。引擎状态每次操作后重建一份,避免深层对象观测。 */
class VesselCard {
  title: string = '';
  kind: VesselKind = VesselKind.TUBE;
  liquidColor: string = '#DCE6F2';
  fillRatio: number = 0;
  contentsText: string = '';
  solidsText: string = '';
  bubbling: boolean = false;
  heated: boolean = false;
  mass: number = 0;
  escaped: number = 0;
}

function newVessel(kind: VesselKind, title: string, capacity: number): Vessel {
  return Vessel.of(kind, title, capacity);
}

@Component
export struct BenchPage {
  @Prop hostWidth: number = 0;
  @State shelf: Substance[] = [];
  @State cards: VesselCard[] = [];
  @State log: string[] = [];
  @State selected: number = 0;
  @State dragPayload: string = '';

  private vessels: Vessel[] = [];
  private blankCard: VesselCard = new VesselCard();
  /** 不能在这里初始化:试剂表要到 aboutToAppear 才注册,提前取会抛「试剂表中没有」 */
  private benchReactions: ReactionSpec[] = [];

  aboutToAppear(): void {
    ChemistryLibrary.registerReagents();
    this.benchReactions = ChemistryLibrary.bench();
    const keys = ChemistryLibrary.shelf();
    const list: Substance[] = [];
    for (let i = 0; i < keys.length; i++) {
      list.push(Reagents.get(keys[i]));
    }
    this.shelf = list;

    this.vessels = [
      newVessel(VesselKind.TUBE, '试管 ①', 8),
      newVessel(VesselKind.TUBE, '试管 ②', 8),
      newVessel(VesselKind.BEAKER, '烧杯', 16)
    ];
    this.publish(false);
    this.log = ['从药品柜把试剂拖到容器上即可加入；把容器拖到另一个容器上即倾倒。'];
  }

  private cls(): DeviceClass {
    return Layout.classify(this.hostWidth);
  }

  /** 越界时回一张空卡:重绘与数组替换之间总有一瞬对不齐,不该崩 */
  private cardAt(index: number): VesselCard {
    return index < this.cards.length ? this.cards[index] : this.blankCard;
  }

  /** 操作后统一重算可视状态并把现象写进日志 */
  private publish(bubbling: boolean): void {
    const cards: VesselCard[] = [];
    for (let i = 0; i < this.vessels.length; i++) {
      const vessel = this.vessels[i];
      const view: BenchView = BenchEngine.viewOf(vessel, bubbling);
      const card = new VesselCard();
      card.title = vessel.label;
      card.kind = vessel.kind;
      card.liquidColor = view.liquidColor;
      card.fillRatio = vessel.capacity === 0 ? 0 : view.portions / vessel.capacity;
      card.contentsText = BenchEngine.describe(vessel);
      card.solidsText = view.solids.join('、');
      card.bubbling = view.bubbling;
      card.heated = vessel.heated;
      card.mass = BenchEngine.massIn(vessel);
      card.escaped = BenchEngine.massEscaped(vessel);
      cards.push(card);
    }
    this.cards = cards;
  }

  private apply(index: number): void {
    const vessel = this.vessels[index];
    const events = BenchEngine.react(vessel, this.benchReactions);
    let bubbling = false;
    const lines: string[] = [];
    for (let i = 0; i < events.length; i++) {
      const event = events[i];
      bubbling = bubbling || event.gases.length > 0;
      lines.push(vessel.label + ':' + event.title);
      // 先给式子再给现象:学生认的是这条反应,现象是它的证据,顺序反了就像在背现象
      if (event.equation.length > 0) {
        lines.push('  方程式  ' + event.equation);
      }
      if (event.ionicEquation.length > 0) {
        lines.push('  离子式  ' + event.ionicEquation);
      }
      for (let j = 0; j < event.phenomena.length; j++) {
        lines.push('  · ' + event.phenomena[j]);
      }
      if (event.gases.length > 0) {
        lines.push('  · 气体从敞口容器逸出，容器质量随之减小');
      }
    }
    if (lines.length === 0) {
      const hints = BenchEngine.pendingHints(vessel, this.benchReactions);
      for (let i = 0; i < hints.length; i++) {
        lines.push(vessel.label + ':' + hints[i]);
      }
    }
    if (lines.length > 0) {
      this.log = lines.concat(this.log).slice(0, 40);
    }
    this.publish(bubbling);
  }

  /** 不能叫 onDrop:那是 CustomComponent 的内置属性方法,同名会被基类签名覆盖 */
  private handleDrop(target: number): void {
    if (this.dragPayload.length === 0) {
      return;
    }
    const separator = this.dragPayload.indexOf(':');
    const kind = this.dragPayload.substring(0, separator);
    const value = this.dragPayload.substring(separator + 1);
    const vessel = this.vessels[target];
    if (kind === 'reagent') {
      const substance = Reagents.get(value);
      const ok = BenchEngine.add(vessel, value, PORTION_MOLES);
      this.log = [ok ? '向 ' + vessel.label + ' 加入 ' + substance.name
        : vessel.label + ' 已满，' + substance.name + ' 加不进去'].concat(this.log).slice(0, 40);
    } else {
      const sourceIndex = Number.parseInt(value, 10);
      if (Number.isNaN(sourceIndex) || sourceIndex === target ||
        sourceIndex >= this.vessels.length) {
        this.dragPayload = '';
        return;
      }
      const source = this.vessels[sourceIndex];
      const ok = BenchEngine.pourInto(vessel, source);
      this.log = [ok ? '把 ' + source.label + ' 倒入 ' + vessel.label
        : vessel.label + ' 装不下，' + source.label + ' 未被倒出'].concat(this.log).slice(0, 40);
    }
    this.dragPayload = '';
    this.selected = target;
    this.apply(target);
  }

  @Builder
  bottle(item: Substance) {
    Column({ space: 2 }) {
      Text(item.name)
        .fontSize(Layout.captionSize(this.cls()))
        .fontColor(Theme.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(item.formula)
        .fontSize(Layout.microSize(this.cls()))
        .fontColor(Theme.TEXT_SECONDARY)
    }
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .borderRadius(Layout.cardRadius(this.cls()))
    .backgroundColor(Theme.BG_CARD)
    .border({ width: 1, color: Theme.DIVIDER })
    .margin(3)
    .draggable(true)
    .onDragStart(() => {
      this.dragPayload = 'reagent:' + item.key;
      return this.dragChip(item.name);
    })
  }

  /** 不能叫 dragPreview:与 CommonMethod.dragPreview 同名,会被判定为属性方法覆盖 */
  @Builder
  dragChip(name: string) {
    Text(name)
      .fontSize(Layout.captionSize(this.cls()))
      .fontColor(Color.White)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(Theme.ACCENT)
      .borderRadius(Layout.controlRadius(this.cls()))
  }

  /**
   * 容器卡。只接一个下标,卡的内容在 Builder 体里现读 this.cards ——
   * 按值传 card 对象进来会让整张卡停在首次渲染的那一份(液面、质量数字全都不会动)。
   */
  @Builder
  vesselCard(index: number) {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.Bottom }) {
        VesselView({
          kind: this.cardAt(index).kind,
          fillRatio: this.cardAt(index).fillRatio,
          liquidColor: this.cardAt(index).liquidColor
        })
        if (this.cardAt(index).bubbling) {
          Row({ space: 6 }) {
            Text('·').fontSize(Layout.bubbleSize(this.cls())).fontColor(Color.White)
            Text('·').fontSize(Layout.bubbleSize(this.cls())).fontColor(Color.White)
            Text('·').fontSize(Layout.bubbleSize(this.cls())).fontColor(Color.White)
          }
        }
      }
      .width(Layout.vesselCardWidth(this.cls()))
      .height(Layout.vesselCardHeight(this.cls()))
      .borderRadius(Layout.cardRadius(this.cls()))
      .border({ width: 2, color: index === this.selected ? Theme.ACCENT : '#B7C2CE' })

      Text(this.cardAt(index).title)
        .fontSize(Layout.labelSize(this.cls()))
        .fontWeight(index === this.selected ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(Theme.TEXT_PRIMARY)
      if (this.cardAt(index).heated) {
        Text('加热中')
          .fontSize(Layout.captionSize(this.cls()))
          .fontColor(Theme.DANGER)
      }
      if (this.cardAt(index).solidsText.length > 0) {
        Text('沉底：' + this.cardAt(index).solidsText)
          .fontSize(Layout.microSize(this.cls()))
          .fontColor(Theme.TEXT_SECONDARY)
          .maxLines(1)
      }
      Text(this.cardAt(index).mass.toFixed(3) + ' g')
        .fontSize(Layout.captionSize(this.cls()))
        .fontColor(Theme.ACCENT)
    }
    .padding(Layout.cardPadding(this.cls()))
    .borderRadius(Layout.cardRadius(this.cls()))
    .backgroundColor(index === this.selected ? '#EAF1F9' : Theme.BG_CARD)
    .onClick(() => {
      this.selected = index;
    })
    .draggable(true)
    .onDragStart(() => {
      this.dragPayload = 'vessel:' + index.toString();
      return this.dragChip(this.cardAt(index).title);
    })
    .onDrop(() => {
      this.handleDrop(index);
    })
  }

  @Builder
  action(label: string, accent: string, action: () => void) {
    Text(label)
      .fontSize(Layout.labelSize(this.cls()))
      .fontColor(Color.White)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .borderRadius(Layout.controlRadius(this.cls()))
      .backgroundColor(accent)
      .margin({ right: 8 })
      .onClick(action)
  }

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        Column({ space: 4 }) {
          Text('药品柜').fontSize(Layout.labelSize(this.cls())).fontColor(Theme.TEXT_SECONDARY)
          Scroll() {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.shelf, (item: Substance) => {
                this.bottle(item)
              }, (item: Substance) => item.key)
            }
          }
          .constraintSize({ maxHeight: Layout.shelfMaxHeight(this.cls()) })
          .scrollBar(BarState.Auto)
          .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Row() {
          ForEach(this.cards, (card: VesselCard, index: number) => {
            this.vesselCard(index)
          }, (card: VesselCard, index: number) => card.title + index)
        }
        .justifyContent(FlexAlign.SpaceAround)
        .alignItems(VerticalAlign.Bottom)
        .width('100%')

        Row() {
          this.action(this.vessels[this.selected].heated ? '熄灭酒精灯' : '点燃酒精灯',
            this.vessels[this.selected].heated ? Theme.DANGER : Theme.RUNNING, (): void => {
              const vessel = this.vessels[this.selected];
              vessel.heated = !vessel.heated;
              this.log = [(vessel.heated ? '点燃酒精灯加热 ' : '熄灭酒精灯 ') + vessel.label]
                .concat(this.log).slice(0, 40);
              this.apply(this.selected);
            })
          this.action('倒掉洗净', Theme.TEXT_SECONDARY, (): void => {
            const vessel = this.vessels[this.selected];
            vessel.contents = [];
            vessel.escaped = [];
            vessel.heated = false;
            this.log = ['清空并洗净 ' + vessel.label].concat(this.log).slice(0, 40);
            this.publish(false);
          })
        }
        .width('100%')

        if (this.cards.length > this.selected) {
          Text('现存：' + this.cards[this.selected].contentsText)
            .fontSize(Layout.captionSize(this.cls()))
            .fontColor(Theme.TEXT_SECONDARY)
            .width('100%')
        }

        Scroll() {
          Column({ space: 2 }) {
            ForEach(this.log, (line: string) => {
              Text(line)
                .fontSize(Layout.captionSize(this.cls()))
                .fontColor(line.startsWith('  ') ? Theme.TEXT_SECONDARY : Theme.TEXT_PRIMARY)
                .width('100%')
            }, (line: string, index: number) => index + ':' + line)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        }
        .layoutWeight(1)
        .padding(Layout.cardPadding(this.cls()))
        .backgroundColor(Theme.BG_CARD)
        .borderRadius(Layout.cardRadius(this.cls()))
        .width('100%')
        .align(Alignment.TopStart)
      }
      .padding(Layout.pageInset(this.cls()))
      .width('100%')
      .height('100%')
    }
    .title('化学实验台')
    .backgroundColor(Theme.BG_PAGE)
  }
}
