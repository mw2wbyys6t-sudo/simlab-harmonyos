import { DeviceClass, Layout } from '../common/Layout';
import { FeedItem, FilterChip, LibraryFeed } from '../common/LibraryFeed';
import { Theme } from '../common/Theme';
import { ExperimentMeta } from '../model/ExperimentTypes';
import { ExperimentRegistry } from '../runner/ExperimentRegistry';
import { ElectricalScenes } from '../scenes/ElectricalScenes';
import { MechanicsScenes } from '../scenes/MechanicsScenes';
import { BenchPage } from './BenchPage';
import { ChemistryPage } from './ChemistryPage';
import { ExperimentPage } from './ExperimentPage';
import { MapPage } from './MapPage';
import { MeasurePage } from './MeasurePage';
import { ReportPage } from './ReportPage';

/**
 * 实验库首页。首屏只有一件事:挑实验。
 *
 * 排版约束全部来自 `Layout`/`Theme` 令牌与 `LibraryFeed` 的算式,页面里不出现裸字号、
 * 裸间距、裸色值 —— 这样换配色或调密度时,改的是令牌而不是这 200 行。
 */
@Entry
@Component
struct Index {
  @State pathStack: NavPathStack = new NavPathStack();
  @State widthVp: number = 0;
  /** 指向 this.chips 的下标,0 恒为「全部」 */
  @State activeChip: number = 0;
  @State currentId: string = '';
  @State items: FeedItem[] = [];
  @State chips: FilterChip[] = [];

  aboutToAppear(): void {
    MechanicsScenes.registerAll();
    ElectricalScenes.registerAll();
    const feed: FeedItem[] = LibraryFeed.practiceItems();
    const metas: ExperimentMeta[] = ExperimentRegistry.all();
    for (const meta of metas) {
      feed.push(LibraryFeed.fromMeta(meta));
    }
    this.items = feed;
    this.chips = LibraryFeed.chips(feed);
  }

  private cls(): DeviceClass {
    return Layout.classify(this.widthVp);
  }

  private visible(): FeedItem[] {
    if (this.activeChip < 0 || this.activeChip >= this.chips.length) {
      return this.items;
    }
    return LibraryFeed.select(this.items, this.chips[this.activeChip]);
  }

  /**
   * 标题栏右侧的两个入口。
   *
   * 不用 NavigationMenuItem:实测它在 Mini 标题模式下只画图标位,`value` 的文字不显示,
   * 没有图标资源时就剩两个空心圆。CustomBuilder 直接画文字,标签自己说得清。
   */
  @Builder
  menuBar() {
    Row({ space: 2 }) {
      Text('课程地图')
        .fontSize(Layout.captionSize(this.cls()))
        .fontColor(Theme.ACCENT)
        .height(Layout.chipHeight(this.cls()))
        .padding({ left: 8, right: 8 })
        .onClick(() => {
          this.pathStack.pushPath({ name: 'curriculum' });
        })
      Text('速查表')
        .fontSize(Layout.captionSize(this.cls()))
        .fontColor(Theme.ACCENT)
        .height(Layout.chipHeight(this.cls()))
        .padding({ left: 8, right: 8 })
        .onClick(() => {
          this.pathStack.pushPath({ name: 'reactions' });
        })
      Text('报告')
        .fontSize(Layout.captionSize(this.cls()))
        .fontColor(Theme.ACCENT)
        .height(Layout.chipHeight(this.cls()))
        .padding({ left: 8, right: 8 })
        .onClick(() => {
          this.pathStack.pushPath({ name: 'report' });
        })
    }
    // 每项自带 8vp 右内边距,这里补到与标题左内缩等距 —— 否则最后一项的字贴着屏幕边
    .padding({ right: Layout.pageInset(this.cls()) - 8 })
  }

  private openItem(item: FeedItem): void {
    this.currentId = item.experimentId;
    this.pathStack.pushPath({ name: item.route });
  }

  /**
   * 路由表。必须写成 if / else if 单链:五个平级 if 会各自生成一个 if 容器,
   * 而 Navigation 只取第一个容器的输出 —— 第一个容器为空时目标页就是一片空白。
   */
  @Builder
  routeMap(name: string) {
    if (name === 'experiment') {
      ExperimentPage({ experimentId: this.currentId, hostWidth: this.widthVp })
    } else if (name === 'reactions') {
      ChemistryPage({ hostWidth: this.widthVp })
    } else if (name === 'bench') {
      BenchPage({ hostWidth: this.widthVp })
    } else if (name === 'measure') {
      MeasurePage({ hostWidth: this.widthVp })
    } else if (name === 'report') {
      ReportPage({ hostWidth: this.widthVp })
    } else if (name === 'curriculum') {
      MapPage({ hostWidth: this.widthVp })
    } else {
      NavDestination() {
        Text('没有名为 ' + name + ' 的页面')
          .fontSize(Layout.bodySize(this.cls()))
          .fontColor(Theme.TEXT_SECONDARY)
      }
      .title('路由缺失')
    }
  }

  @Builder
  filterChip(chip: FilterChip, index: number) {
    Text(chip.label)
      .fontSize(Layout.bodySize(this.cls()))
      .fontColor(this.activeChip === index ? Theme.textOn(Theme.ACCENT) : Theme.TEXT_SECONDARY)
      .fontWeight(this.activeChip === index ? FontWeight.Medium : FontWeight.Normal)
      .textAlign(TextAlign.Center)
      .height(Layout.chipHeight(this.cls()))
      .borderRadius(Layout.chipRadius(this.cls()))
      .backgroundColor(this.activeChip === index ? Theme.ACCENT : Theme.BG_CARD)
      .border({
        width: 1,
        color: this.activeChip === index ? Theme.ACCENT : Theme.DIVIDER
      })
      .layoutWeight(1)
      .onClick(() => {
        this.activeChip = index;
      })
  }

  @Builder
  card(item: FeedItem) {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Column()
          .width(Layout.dotSize())
          .height(Layout.dotSize())
          .borderRadius(Layout.dotSize() / 2)
          .backgroundColor(Theme.subjectColor(item.subject))
        Text(item.title)
          .fontSize(Layout.cardTitleSize(this.cls()))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (item.durationMinutes > 0) {
          Text('约 ' + item.durationMinutes + ' 分钟')
            .fontSize(Layout.captionSize(this.cls()))
            .fontColor(Theme.TEXT_SECONDARY)
        }
      }
      .width('100%')

      Row({ space: 6 }) {
        Text(LibraryFeed.shortLabel(item.subject))
          .fontSize(Layout.captionSize(this.cls()))
          .fontColor(Theme.subjectColor(item.subject))
        Text(item.gradeBand)
          .fontSize(Layout.captionSize(this.cls()))
          .fontColor(Theme.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(Layout.cardPadding(this.cls()))
    .backgroundColor(Theme.BG_CARD)
    .borderRadius(Layout.cardRadius(this.cls()))
    .border({ width: 1, color: Theme.DIVIDER })
    .onClick(() => {
      this.openItem(item);
    })
  }

  @Builder
  emptyState() {
    Column({ space: 8 }) {
      Text('这个学科还没有可做的实验')
        .fontSize(Layout.bodySize(this.cls()))
        .fontColor(Theme.TEXT_SECONDARY)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Navigation(this.pathStack) {
      Column({ space: Layout.listGap(this.cls()) }) {
        Row({ space: LibraryFeed.CHIP_GAP_VP }) {
          ForEach(this.chips, (chip: FilterChip, index: number) => {
            this.filterChip(chip, index)
          }, (chip: FilterChip) => chip.label)
        }
        .width('100%')
        .constraintSize({ maxWidth: 520 })

        if (this.visible().length === 0) {
          this.emptyState()
        } else {
          List({ space: Layout.listGap(this.cls()) }) {
            ForEach(this.visible(), (item: FeedItem) => {
              ListItem() {
                this.card(item)
              }
            }, (item: FeedItem) => item.key)
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .height('100%')
      .padding({
        left: Layout.pageInset(this.cls()),
        right: Layout.pageInset(this.cls()),
        bottom: Layout.pageInset(this.cls())
      })
    }
    .title('仿真实验室')
    .titleMode(NavigationTitleMode.Mini)
    .hideBackButton(true)
    .menus(this.menuBar)
    .mode(NavigationMode.Stack)
    .navDestination(this.routeMap)
    .backgroundColor(Theme.BG_PAGE)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.widthVp = Number(newValue.width);
    })
  }
}
