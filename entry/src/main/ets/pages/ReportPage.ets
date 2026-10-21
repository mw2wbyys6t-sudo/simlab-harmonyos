import { DeviceClass, Layout } from '../common/Layout';
import { Theme } from '../common/Theme';
import { BrineRun, BrineScenario, BrineScenarioRunner } from '../bench/BrineScenario';
import { Deduction, Judgment, ScoreCard } from '../bench/Judgment';
import { RubricBrine } from '../bench/RubricBrine';
import { Rubrics } from '../bench/RubricMeasure';
import { SessionRecord } from '../model/SessionRecord';
import { FactLabels } from '../model/FactLabels';
import { Subject } from '../model/ExperimentTypes';
import { SessionStore } from '../platform/SessionStore';
import { AppButton, ButtonVariant } from '../view/AppButton';

/** 报告里展示的一行事实 */
class FactLine {
  label: string = '';
  value: string = '';

  static of(label: string, value: string): FactLine {
    const line = new FactLine();
    line.label = label;
    line.value = value;
    return line;
  }
}

/**
 * 历史段的一行。
 *
 * 分数在这里就按当前细则算好,不在 @Builder 里算 —— build() 会随任何 @State 变化重跑,
 * 每条记录重新解析一遍细则是不必要的开销。
 */
class HistoryLine {
  key: string = '';
  title: string = '';
  stamp: string = '';
  scoreText: string = '';
  factText: string = '';
  subject: Subject = Subject.PHYSICS_MECHANICS;
  /** 所属日期组的名字,每条都有:删除确认框要靠它区分不同天的同一时刻 */
  dayLabel: string = '';
  /** 组标题只落在该组第一条上 */
  showDay: boolean = false;
}

/**
 * 操作诊断报告。
 *
 * 这是这条链路「闭合」的判据所在:分数不是终点,**每条扣分都必须能被复算**。
 * 所以每一项都带证据文本与它依据的事实数值,判据来源与版本也固定显示 ——
 * 参考细则绝不能看起来像官方标准。
 */
@Component
export struct ReportPage {
  @Prop hostWidth: number = 0;
  /** 宿主高度。转屏后高度变了,档位可能变(横屏手机不再是平板) */
  @Prop hostHeight: number = 0;
  @State score: number = 0;
  @State total: number = 100;
  @State deductions: Deduction[] = [];
  @State factLines: FactLine[] = [];
  @State timeline: string[] = [];
  @State rubricLine: string = '';
  @State passed: boolean = false;
  @State history: HistoryLine[] = [];
  @State rubricLabel: string = '';
  @State showingText: string = '';
  @State selectedKey: string = '';

  private card: ScoreCard = new ScoreCard();
  private run: BrineRun = new BrineRun();
  private records: SessionRecord[] = [];
  private scroller: Scroller = new Scroller();

  private cls(): DeviceClass {
    return Layout.classify(this.hostWidth, this.hostHeight);
  }

  /** 矮屏(横屏手机):阅读列要收窄,一行塞 100 个汉字就不是阅读了 */
  private compact(): boolean {
    return Layout.isCompact(this.hostHeight);
  }

  /**
   * 在 NavDestination 的 onAppear 里读,不在 aboutToAppear 里读。
   *
   * `getUIContext()` 要求组件已挂到某个 UI 上下文上,aboutToAppear 时这一点没有保证。
   */
  private loadHistory(): void {
    const context: Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    const ledger = SessionStore.load(context);
    const records = ledger.all();
    const lines: HistoryLine[] = [];
    // 分组由账本算,不在页面里推:「今天/昨天」的日界换算是要被断言的那部分逻辑。
    // 组标题只在该组第一条上落 —— 比较基准必须是上一组的键,不能是上一行的标题,
    // 因为组内第二行往后标题本来就是空的,拿空值比会让标题隔一条闪一次。
    let lastDayKey = '';
    for (const day of ledger.groupByDay(Date.now())) {
      for (const record of day.records) {
        const line = this.lineOf(record);
        line.dayLabel = day.label;
        line.showDay = day.key !== lastDayKey;
        lastDayKey = day.key;
        lines.push(line);
      }
    }
    this.records = records;
    this.history = lines;
    if (records.length === 0) {
      return;
    }
    // 删掉一条之后不该把主段跳到最新记录上:选中的还在就保持,否则才落到第一条
    let keep = this.selectedKey;
    if (!records.some((record: SessionRecord) => record.id === keep)) {
      keep = records[0].id;
    }
    this.select(keep);
  }

  /** 删除是不可逆的,所以必须二次确认;确认之后重新从盘上读,避免界面和账本两份真相 */
  private confirmDelete(line: HistoryLine): void {
    this.getUIContext().showAlertDialog({
      title: '删除这条记录?',
      message: line.title + ' · ' + line.dayLabel + ' ' + line.stamp,
      primaryButton: {
        value: '删除',
        action: (): void => {
          this.removeRecord(line.key);
        }
      },
      secondaryButton: {
        value: '取消',
        action: (): void => {
        }
      }
    });
  }

  private removeRecord(id: string): void {
    const context: Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    const ledger = SessionStore.load(context);
    if (!ledger.remove(id)) {
      this.loadHistory();
      return;
    }
    SessionStore.save(context, ledger);
    this.loadHistory();
  }

  /**
   * 分数不读记录里存的值,而是按当前细则从事实重算(不变量 I4)。
   *
   * 每行都带上判据来源与版本:自建参考细则绝不能看起来像官方标准(风险 R1)。
   */
  private lineOf(record: SessionRecord): HistoryLine {
    const line = new HistoryLine();
    line.key = record.id;
    line.title = record.title;
    line.subject = record.subject;
    line.stamp = this.stampOf(record);
    line.factText = this.factLineOf(record);
    const rubric = Rubrics.byId(record.rubricId);
    if (rubric === null) {
      line.scoreText = '这次操作只留下了数据，暂时没有对应的评分参考';
      return line;
    }
    const card = Judgment.score(rubric, Rubrics.factsFor(record));
    // 措辞只有一处来源:实验页判完、报告页回看,同一句话不能长成两个样子
    // (来源与版本都必须露出 —— R1:自建细则不能看起来像官方标准)
    line.scoreText = card.summaryLine();
    if (card.deductions.length > 0) {
      const titles: string[] = [];
      for (const item of card.deductions) {
        titles.push(item.title);
      }
      line.factText = titles.join(';') + '。' + line.factText;
    }
    return line;
  }

  private stampOf(record: SessionRecord): string {
    const at = new Date(record.endedAtMs);
    const hh = at.getHours();
    const mm = at.getMinutes();
    return (hh < 10 ? '0' : '') + hh + ':' + (mm < 10 ? '0' : '') + mm;
  }

  /** 历史行的摘要:显示名一律走 FactLabels,不暴露内部键名 */
  private factLineOf(record: SessionRecord): string {
    const parts: string[] = [];
    for (let i = 0; i < record.facts.length && i < 3; i++) {
      const item = record.facts[i];
      parts.push(FactLabels.labelOf(item.key) + ' ' + FactLabels.valueText(item.key, item.value));
    }
    if (record.durationSec > 0) {
      parts.push('用时 ' + record.durationSec.toFixed(0) + ' s');
    }
    return parts.join(' · ');
  }

  aboutToAppear(): void {
    const scenario = new BrineScenario();
    this.run = BrineScenarioRunner.run(scenario);
    const rubric = RubricBrine.create();
    this.loadFrom(Judgment.score(rubric, this.run.facts), rubric.label,
      '规范示例，非你的操作。有真实记录时会自动切换');
  }

  /**
   * 主段完全由传入的 ScoreCard 驱动:事实表遍历 FactSheet 自己的键,显示名查 `FactLabels`。
   *
   * 原来这里硬编码了提纯链路的 12 个键,换成量取记录整张表就会静默变空。
   */
  private loadFrom(card: ScoreCard, rubricLabel: string, showing: string): void {
    this.card = card;
    this.score = card.awarded;
    this.total = card.total;
    this.deductions = card.deductions;
    this.passed = card.awarded >= 80;
    this.rubricLine = card.rubricSource + ' · 版本 ' + card.rubricVersion;
    this.rubricLabel = rubricLabel;
    this.showingText = showing;

    const lines: FactLine[] = [];
    card.facts.numbers.forEach((value: number, key: string) => {
      lines.push(FactLine.of(FactLabels.labelOf(key), FactLabels.valueText(key, value)));
    });
    this.factLines = lines;

    const marks: string[] = [];
    card.facts.moments.forEach((at: number, event: string) => {
      marks.push(FactLabels.momentLabel(event) + ' 于第 ' + at.toFixed(1) + ' s');
    });
    this.timeline = marks;
  }

  /** 点历史行 => 主段改成那次操作。段在屏幕下方而变化发生在顶部,所以同时滚回顶部 */
  private select(key: string): void {
    const rubric = Rubrics.byId(this.rubricIdOf(key));
    if (rubric === null) {
      return;
    }
    const record = this.recordOf(key);
    if (record === null) {
      return;
    }
    this.selectedKey = key;
    this.loadFrom(Judgment.score(rubric, Rubrics.factsFor(record)), rubric.label,
      '你的操作 · ' + this.stampOf(record) + ' · ' + record.title);
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
  }

  private recordOf(key: string): SessionRecord | null {
    for (const item of this.records) {
      if (item.id === key) {
        return item;
      }
    }
    return null;
  }

  private rubricIdOf(key: string): string {
    const record = this.recordOf(key);
    return record === null ? '' : record.rubricId;
  }

  @Builder
  header() {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(this.score.toFixed(0))
          .fontSize(Layout.displaySize(this.cls()))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.passed ? Theme.RUNNING : Theme.DANGER)
        Text('/ ' + this.total.toFixed(0) + ' 分')
          .fontSize(Layout.captionSize(this.cls()))
          .fontColor(Theme.TEXT_SECONDARY)
      }
      Column({ space: 4 }) {
        Text(this.rubricLabel)
          .fontSize(Layout.cardTitleSize(this.cls()))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
        Text(this.showingText)
          .fontSize(Layout.captionSize(this.cls()))
          .fontColor(Theme.TEXT_SECONDARY)
        Text(this.rubricLine)
          .fontSize(Layout.captionSize(this.cls()))
          .fontColor(Theme.DANGER)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(Layout.cardPadding(this.cls()))
    .backgroundColor(Theme.BG_CARD)
    .borderRadius(Layout.cardRadius(this.cls()))
  }

  /**
   * 扣分行与事实行都只接下标。
   *
   * 这两张表的键(criterionId / label)在两条记录之间是**同名**的:换一条记录,
   * ForEach 认为什么都没变,行就停在首次渲染的那一份上。实测切到另一次操作时,
   * 证据写「洒失 26.70 mL」而下面的事实表仍显示上一条的「0.06 mL」—— 同一屏自相矛盾。
   */
  @Builder
  deductionRow(index: number) {
    Column({ space: 3 }) {
      Row() {
        Text('−' + this.deductions[index].points.toFixed(0) + ' 分')
          .fontSize(Layout.labelSize(this.cls()))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.DANGER)
        Text(this.deductions[index].title)
          .fontSize(Layout.bodySize(this.cls()))
          .fontColor(Theme.TEXT_PRIMARY)
          .layoutWeight(1)
          .margin({ left: 8 })
      }
      .width('100%')

      Text('证据：' + this.deductions[index].evidence)
        .fontSize(Layout.captionSize(this.cls()))
        .fontColor(Theme.TEXT_SECONDARY)
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  factRow(index: number) {
    Row() {
      Text(this.factLines[index].label)
        .fontSize(Layout.captionSize(this.cls()))
        .fontColor(Theme.TEXT_SECONDARY)
        .layoutWeight(1)
      Text(this.factLines[index].value)
        .fontSize(Layout.labelSize(this.cls()))
        .fontColor(Theme.TEXT_PRIMARY)
    }
    .width('100%')
    .padding({ top: 3, bottom: 3 })
  }

  build() {
    NavDestination() {
      Scroll(this.scroller) {
        Column({ space: 14 }) {
          this.header()

          Column({ space: 2 }) {
            Text(this.deductions.length === 0 ? '操作全部规范，无扣分项' : '扣分项（每条都附当时的数据）')
              .fontSize(Layout.sectionSize(this.cls()))
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT_PRIMARY)
            ForEach(this.deductions, (item: Deduction, index: number) => {
              this.deductionRow(index)
            }, (item: Deduction) => item.criterionId)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(Layout.cardPadding(this.cls()))
          .backgroundColor(Theme.BG_CARD)
          .borderRadius(Layout.cardRadius(this.cls()))

          Column({ space: 2 }) {
            // 「关键事实 / 步骤时序」是判分层的内部叫法(fact / moment),
            // 学生要的是"当时记下了哪些数"和"每一步是什么时候做的"
            Text('记录到的数据')
              .fontSize(Layout.sectionSize(this.cls()))
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT_PRIMARY)
            ForEach(this.factLines, (item: FactLine, index: number) => {
              this.factRow(index)
            }, (item: FactLine) => item.label)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(Layout.cardPadding(this.cls()))
          .backgroundColor(Theme.BG_CARD)
          .borderRadius(Layout.cardRadius(this.cls()))

          Column({ space: 4 }) {
            Text('分步过程')
              .fontSize(Layout.sectionSize(this.cls()))
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT_PRIMARY)
            if (this.timeline.length === 0) {
              // 原来这句写死了「量取链路…不记录溶解/过滤/蒸发」:物理实验的报告上
              // 冒出化学台架的术语,而这一格对任何没有时刻的记录都成立
              Text('这次操作只记录了结果数值，没有记下每一步的时间。')
                .fontSize(Layout.captionSize(this.cls()))
                .fontColor(Theme.TEXT_SECONDARY)
            } else {
              ForEach(this.timeline, (line: string) => {
                Text(line)
                  .fontSize(Layout.captionSize(this.cls()))
                  .fontColor(Theme.TEXT_SECONDARY)
              }, (line: string) => line)
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(Layout.cardPadding(this.cls()))
          .backgroundColor(Theme.BG_CARD)
          .borderRadius(Layout.cardRadius(this.cls()))

          Column({ space: 4 }) {
            Text('历史操作记录')
              .fontSize(Layout.bodySize(this.cls()))
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT_PRIMARY)
            if (this.history.length === 0) {
              // 按钮上一批改叫「停止并判定」了,这里还写着旧名 —— 界面在指一个不存在的按钮
              Text('还没有保存过任何一次操作。在量取训练里点「停止并判定」就会留下一条。')
                .fontSize(Layout.captionSize(this.cls()))
                .fontColor(Theme.TEXT_SECONDARY)
            } else {
              ForEach(this.history, (line: HistoryLine) => {
                Column({ space: 4 }) {
                  if (line.showDay) {
                    Text(line.dayLabel)
                      .fontSize(Layout.captionSize(this.cls()))
                      .fontColor(Theme.TEXT_SECONDARY)
                      .width('100%')
                  }
                  Column({ space: 2 }) {
                    Row({ space: 6 }) {
                      Column()
                        .width(Layout.dotSize())
                        .height(Layout.dotSize())
                        .borderRadius(Layout.dotSize() / 2)
                        .backgroundColor(Theme.subjectColor(line.subject))
                      Text(line.title)
                        .fontSize(Layout.bodySize(this.cls()))
                        .fontColor(Theme.TEXT_PRIMARY)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                      Text(line.stamp)
                        .fontSize(Layout.captionSize(this.cls()))
                        .fontColor(Theme.TEXT_SECONDARY)
                      AppButton({
                        label: '删除',
                        cls: this.cls(),
                        variant: ButtonVariant.LINK,
                        accent: Theme.DANGER,
                        onPress: (): void => {
                          this.confirmDelete(line);
                        }
                      })
                    }
                    .width('100%')

                    Text(line.scoreText)
                      .fontSize(Layout.captionSize(this.cls()))
                      .fontColor(Theme.ACCENT)
                    Text(line.factText)
                      .fontSize(Layout.captionSize(this.cls()))
                      .fontColor(Theme.TEXT_SECONDARY)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .width('100%')
                  .padding(Layout.cardPadding(this.cls()))
                  .borderRadius(Layout.cardRadius(this.cls()))
                  .border({
                    width: 1,
                    color: this.selectedKey === line.key ? Theme.ACCENT : Theme.DIVIDER
                  })
                  // 可点的卡片也要有按下反馈:没有它,"点中了没有"只能靠下一屏猜
                  .clickEffect({ level: ClickEffectLevel.LIGHT })
                  .onClick(() => {
                    this.select(line.key);
                  })
                }
                .alignItems(HorizontalAlign.Start)
                .width('100%')
              }, (line: HistoryLine) => line.key)
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(Layout.cardPadding(this.cls()))
          .backgroundColor(Theme.BG_CARD)
          .borderRadius(Layout.cardRadius(this.cls()))

          Text('说明：表里的产率、浊度等具体数值按教学演示设定，可信的是它们之间的大小关系与守恒关系；'
            + '评分用的是自建参考细则，不代表任何教育考试院标准。')
            .fontSize(Layout.captionSize(this.cls()))
            .fontColor(Theme.TEXT_SECONDARY)
            .width('100%')
            .padding({ left: 4, right: 4, bottom: 12 })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding({
        left: Layout.pageInsetX(this.hostWidth, this.cls(), this.compact()),
        right: Layout.pageInsetX(this.hostWidth, this.cls(), this.compact())
      })
      .align(Alignment.TopStart)
    }
    .title('操作记录与评分')
    .backgroundColor(Theme.BG_PAGE)
    .onAppear(() => {
      this.loadHistory();
    })
  }
}
