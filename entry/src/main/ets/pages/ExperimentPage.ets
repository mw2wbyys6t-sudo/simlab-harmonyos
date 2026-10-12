import { DeviceClass, Layout } from '../common/Layout';
import { Theme } from '../common/Theme';
import { ActionDef, ChartDef, ExperimentMeta, ObservableDef, ParamControl, ParamDef } from '../model/ExperimentTypes';
import { fact, SessionRecord } from '../model/SessionRecord';
import { FactSheet } from '../model/FactSheet';
import { Rubric } from '../bench/Rubric';
import { Judgment } from '../bench/Judgment';
import { Rubrics } from '../bench/RubricMeasure';
import { SessionStore } from '../platform/SessionStore';
import { Physics2DRunner } from '../physics/Physics2DRunner';
import { ExperimentRegistry } from '../runner/ExperimentRegistry';
import { IExperimentRunner } from '../runner/IExperimentRunner';
import { RunController } from '../runner/RunController';
import { SeriesChart } from '../view/SeriesChart';
import { SimCanvas } from '../view/SimCanvas';
import { AppButton } from '../view/AppButton';
import { AppChips } from '../view/AppChips';

const SPEEDS: number[] = [0.25, 0.5, 1];

@Component
export struct ExperimentPage {
  @Prop hostWidth: number = 0;
  @State experimentId: string = '';

  @State meta: ExperimentMeta = new ExperimentMeta();
  @State paramValues: number[] = [];
  @State readouts: string[] = [];
  @State running: boolean = false;
  @State speedIndex: number = 2;
  @State simTime: number = 0;
  /** 自增以触发图线重绘,取代让整棵树跟着帧率重建 */
  @State chartTick: number = 0;
  @State chartsVisible: boolean = true;
  /** 交卷后的判定结果,含每条扣分的证据 */
  @State verdict: string = '';
  /** 这条实验有没有细则(meta.rubricId 且 Rubrics 认得);没有就不给「交卷」按钮 */
  @State scorable: boolean = false;

  private runner: IExperimentRunner | null = null;
  private scene: Physics2DRunner | null = null;
  private controller: RunController = new RunController();
  private ticker: number = -1;

  aboutToAppear(): void {
    const created = ExperimentRegistry.createRunner(this.experimentId);
    if (created === null) {
      return;
    }
    const entry = ExperimentRegistry.find(this.experimentId);
    if (entry === null) {
      return;
    }
    this.meta = entry.meta;
    this.runner = created;
    // 元数据声明用哪种渲染族,决定这页能不能画它
    if (created instanceof Physics2DRunner) {
      this.scene = created;
    }
    this.controller.bind(created, this.meta);
    const values: number[] = [];
    for (let i = 0; i < this.meta.params.length; i++) {
      values.push(this.meta.params[i].defaultValue);
    }
    this.paramValues = values;
    this.scorable = this.meta.rubricId.length > 0 && Rubrics.byId(this.meta.rubricId) !== null;
    this.refreshReadouts();
    // 手机竖屏纵向空间紧张,图线默认收起;平板与大屏直接展开
    this.chartsVisible = !Layout.isStacked(this.cls());
    // 读数按 10Hz 刷新:Canvas 自己每帧重绘,不必让整棵状态树跟着 60Hz 重建
    this.ticker = setInterval(() => {
      this.refreshReadouts();
      this.chartTick = this.chartTick + 1;
    }, 100);
  }

  aboutToDisappear(): void {
    if (this.ticker >= 0) {
      clearInterval(this.ticker);
      this.ticker = -1;
    }
    if (this.runner !== null) {
      this.runner.dispose();
    }
  }

  private cls(): DeviceClass {
    return Layout.classify(this.hostWidth);
  }

  private refreshReadouts(): void {
    if (this.runner === null) {
      return;
    }
    const list: string[] = [];
    for (let i = 0; i < this.meta.observables.length; i++) {
      const def = this.meta.observables[i];
      list.push(ExperimentPage.format(this.runner.readObservable(def.key), def.precision));
    }
    this.readouts = list;
    this.simTime = this.runner.elapsedTime();
    this.running = this.controller.running;
  }

  static format(value: number, precision: number): string {
    if (Number.isNaN(value)) {
      return '—';
    }
    return value.toFixed(precision);
  }

  private onParamChange(index: number, value: number): void {
    if (this.runner === null || index >= this.meta.params.length) {
      return;
    }
    const def = this.meta.params[index];
    this.runner.setParam(def.key, value);
    // 暂停时拖动参数也要留下数据点,否则 U-I 图在暂停态下画不出来
    this.controller.sampleNow();
    const next = this.paramValues.slice();
    next[index] = value;
    this.paramValues = next;
  }

  /** 学生按下一个动作按钮。动作改变世界,读数与图线当场跟着变 —— 这是「他做的」唯一可见的证据 */
  private pressAction(key: string): void {
    if (this.runner === null) {
      return;
    }
    this.runner.doAction(key);
    // 挂上砝码就是松手:世界必须开始走,否则学生看到的是「砝码吊上去、弹簧一动不动」,
    // 那比不动更误导 —— 它会教出一个错的物理。
    if (!this.controller.running) {
      this.controller.start();
    }
    // 暂停态下按动作也要在图线上留下新坐标,与拖动参数同一条规矩
    this.controller.sampleNow();
    this.syncParams();
    this.refreshReadouts();
  }

  /**
   * 把面板那几格数字对回模型里的真实参数。
   *
   * 「换大一档电阻」「电阻箱减一档」这类动作会**自己**改参数:runner 里的值变了,
   * 而 @State paramValues 还停在学生上一次拖到的位置 —— 屏幕上那格数字不动,
   * 等于面板在学生按完按钮之后撒了一次谎。
   */
  private syncParams(): void {
    if (this.runner === null) {
      return;
    }
    let changed = false;
    const next: number[] = [];
    for (let i = 0; i < this.meta.params.length; i++) {
      const value = this.runner.getParam(this.meta.params[i].key);
      next.push(Number.isFinite(value) ? value : this.paramValues[i]);
      if (next[i] !== this.paramValues[i]) {
        changed = true;
      }
    }
    if (changed) {
      this.paramValues = next;
    }
  }

  /**
   * 交卷:把本次操作产生的事实交给判定层。
   *
   * 记录里存事实、不存分数(与量取页同一条规矩):细则换版本后,历史仍按当期细则重算,
   * 不会留下一堆和判据脱钩的死分数。
   */
  private submitRun(): void {
    const context: Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined || this.runner === null) {
      return;
    }
    const rubric: Rubric | null = Rubrics.byId(this.meta.rubricId);
    if (rubric === null) {
      return;
    }
    const sheet = new FactSheet();
    this.runner.collectFacts(sheet);
    const card = Judgment.score(rubric, sheet);
    const record = new SessionRecord();
    record.id = this.experimentId + '-' + String(Date.now());
    record.experimentId = this.meta.id;
    record.title = this.meta.title;
    record.subject = this.meta.subject;
    record.endedAtMs = Date.now();
    record.durationSec = this.runner.elapsedTime();
    record.rubricId = rubric.id;
    record.rubricVersion = rubric.version;
    record.rubricSource = rubric.source;
    record.total = rubric.totalPoints;
    // awarded 刻意不写:回看时按当期细则重算(见 MeasurePage.recordRun 同一条理由)
    record.facts = [];
    sheet.numbers.forEach((value: number, key: string): void => {
      record.facts.push(fact(key, value));
    });
    const ledger = SessionStore.load(context);
    if (!ledger.add(record) || !SessionStore.save(context, ledger)) {
      this.verdict = '本次记录没能保存：分数只在本页显示，不进历史';
      return;
    }
    const lines: string[] = [];
    lines.push(card.summaryLine());
    for (let i = 0; i < card.deductions.length; i++) {
      const hit = card.deductions[i];
      lines.push('· ' + hit.title + '（扣 ' + hit.points + ' 分）'
        + (hit.evidence.length > 0 ? '：' + hit.evidence : ''));
    }
    if (card.deductions.length === 0) {
      lines.push('没有扣分项。评分依据是' + rubric.source + '，不是官方标准。');
    }
    this.verdict = lines.join('\n');
  }

  /**
   * 传输按钮。标签与底色都在 Builder 体内现读 @State,调用处只传一个常量下标。
   *
   * 按值传 label/颜色时 ArkUI 不跟踪依赖,按钮会永远停在首次渲染的那句上 ——
   * 实测「开始」在仿真跑了 100 多秒后仍写着「开始」,界面在对学生撒谎。
   */
  @Builder
  transportButton(kind: number) {
    AppButton({
      label: this.buttonLabel(kind),
      cls: this.cls(),
      accent: this.buttonColor(kind),
      onPress: (): void => {
        this.pressTransport(kind);
      }
    })
  }

  private speedLabels(): string[] {
    return SPEEDS.map((speed: number): string => speed + '×');
  }

  private buttonLabel(kind: number): string {
    if (kind === 0) {
      return this.running ? '暂停' : '开始';
    }
    if (kind === 1) {
      return '重置';
    }
    return this.chartsVisible ? '收起图线' : '展开图线';
  }

  private buttonColor(kind: number): ResourceColor {
    if (kind === 0) {
      return this.running ? Theme.DANGER : Theme.RUNNING;
    }
    if (kind === 1) {
      return Theme.TEXT_SECONDARY;
    }
    return this.chartsVisible ? Theme.ACCENT : Theme.TEXT_SECONDARY;
  }

  private pressTransport(kind: number): void {
    if (kind === 0) {
      if (this.controller.running) {
        this.controller.pause();
      } else {
        this.controller.start();
      }
    } else if (kind === 1) {
      this.controller.pause();
      this.controller.restart();
      this.verdict = '';
    } else {
      this.chartsVisible = !this.chartsVisible;
    }
    this.refreshReadouts();
  }

  @Builder
  transportBar() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        this.transportButton(0)

        this.transportButton(1)

        if (this.meta.charts.length > 0) {
          this.transportButton(2)
        }
      }
      .width('100%')

      // 倍速单独一行:和三个按钮挤在同一行时,手机档会把后两颗推出屏幕,
      // 而推出去的控件既看不见也点不着。
      // 靠左并给「倍速」二字:原来整行右对齐,左边 636px 空着,
      // 谁也不知道这四颗是干什么的
      Row({ space: 8 }) {
        Text('倍速')
          .fontSize(Layout.captionSize(this.cls()))
          .fontColor(Theme.TEXT_SECONDARY)

        AppChips({
          labels: this.speedLabels(),
          selected: this.speedIndex,
          onPick: (index: number): void => {
            this.speedIndex = index;
            this.controller.timeScale = SPEEDS[index];
          }
        })
          .layoutWeight(1)

        // 仿真钟从传输行挪到这里:三颗按钮 + 时钟挤一行时,时钟被右边界裁掉(实测 t=0.00 s 顶到 1256),
        // 而这一行右侧本来就空着 400 多像素
        Text('t = ' + this.simTime.toFixed(2) + ' s')
          .fontSize(Layout.sectionSize(this.cls()))
          .fontColor(Theme.TEXT_PRIMARY)
          .fontFamily('HarmonyOS Sans')
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
  }

  /**
   * 操作区:学生主动按的按钮,由场景元数据渲染 —— 外壳不为某条实验写特判。
   *
   * 「交卷」只在场景声明了细则(且 Rubrics 认得)时出现。没有细则的实验
   * 宁可没有评分,也不给一个永远满分的假分数。
   */
  @Builder
  actionBar() {
    Column({ space: 10 }) {
      Text('操作')
        .fontSize(Layout.sectionSize(this.cls()))
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_PRIMARY)

      ForEach(this.meta.actions, (def: ActionDef, index: number) => {
        if (index === 0 || this.meta.actions[index - 1].group !== def.group) {
          Text(def.group)
            .fontSize(Layout.captionSize(this.cls()))
            .fontColor(Theme.TEXT_SECONDARY)
        }
        AppButton({
          label: def.label,
          cls: this.cls(),
          fullWidth: true,
          onPress: (): void => {
            this.pressAction(def.key);
          }
        })
      }, (def: ActionDef) => def.key)

      if (this.scorable) {
        AppButton({
          label: '交卷评分',
          cls: this.cls(),
          accent: Theme.RUNNING,
          fullWidth: true,
          onPress: (): void => {
            this.submitRun();
          }
        })
      }

      if (this.verdict.length > 0) {
        Text(this.verdict)
          .fontSize(Layout.labelSize(this.cls()))
          .fontColor(Theme.TEXT_PRIMARY)
          .width('100%')
          .padding(Layout.cardPadding(this.cls()))
          .borderRadius(Layout.controlRadius(this.cls()))
          .backgroundColor(Theme.BG_PAGE)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  paramRow(def: ParamDef, index: number) {
    Column({ space: 4 }) {
      Row() {
        Text(def.label)
          .fontSize(Layout.labelSize(this.cls()))
          .fontColor(Theme.TEXT_PRIMARY)
          .layoutWeight(1)
        if (def.control === ParamControl.SWITCH) {
          Text(def.unit)
            .fontSize(Layout.labelSize(this.cls()))
            .fontColor(Theme.TEXT_SECONDARY)
        } else {
          Text(this.paramValues[index].toFixed(def.step >= 1 ? 0 : 2) + (def.unit.length > 0 ? ' ' + def.unit : ''))
            .fontSize(Layout.labelSize(this.cls()))
            .fontColor(Theme.ACCENT)
        }
      }
      .width('100%')

      if (def.control === ParamControl.SWITCH) {
        Row() {
          Text(this.paramValues[index] >= 0.5 ? '闭合' : '断开')
            .fontSize(Layout.labelSize(this.cls()))
            .fontColor(this.paramValues[index] >= 0.5 ? Theme.RUNNING : Theme.DANGER)
          Toggle({ type: ToggleType.Switch, isOn: this.paramValues[index] >= 0.5 })
            .selectedColor(Theme.ACCENT)
            .width(Layout.toggleWidth(this.cls()))
            .height(Layout.toggleHeight(this.cls()))
            .onChange((isOn: boolean) => {
              this.onParamChange(index, isOn ? 1 : 0);
            })
        }
        .justifyContent(FlexAlign.SpaceBetween)
        .width('100%')
      } else {
        Slider({
          value: this.paramValues[index],
          min: def.min,
          max: def.max,
          step: def.step,
          style: SliderStyle.OutSet
        })
          .blockColor(Theme.ACCENT)
          .selectedColor(Theme.ACCENT)
          .onChange((value: number) => {
            this.onParamChange(index, value);
          })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  /**
   * 图线列。每张图按 `Layout.chartHeight` 占高,不再平分一个固定值 ——
   * 手机档两张图平分 190vp 时净高算出来是负数,图线就静默不画了(见 view/PlotFrame)。
   * 高度由外层滚动容器消化,这里只声明内容高。
   */
  @Builder
  chartStrip() {
    Column({ space: 10 }) {
      ForEach(this.meta.charts, (chart: ChartDef) => {
        SeriesChart({ chart: chart, controller: this.controller, hostWidth: this.hostWidth, tick: this.chartTick })
          .width('100%')
          .height(Layout.chartHeight(this.cls()))
      }, (chart: ChartDef) => chart.title)
    }
    .width('100%')
  }

  /** 参数与读数面板的内容本体。滚动与卡片外壳由调用方决定:侧栏布局自带滚动,
   *  竖屏下与图线共用一个滚动区 —— 否则图线一开,画面就被挤成一条。 */
  @Builder
  panelContent() {
      Column({ space: 16 }) {
        if (this.meta.summary.length > 0) {
          Text(this.meta.summary)
            .fontSize(Layout.bodySize(this.cls()))
            .fontColor(Theme.TEXT_SECONDARY)
        }

        if (this.meta.actions.length > 0) {
          this.actionBar()
          Divider().color(Theme.DIVIDER)
        }

        Text('参数')
          .fontSize(Layout.sectionSize(this.cls()))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)

        Column({ space: 14 }) {
          ForEach(this.meta.params, (def: ParamDef, index: number) => {
            if (index === 0 || this.meta.params[index - 1].group !== def.group) {
              Text(def.group)
                .fontSize(Layout.captionSize(this.cls()))
                .fontColor(Theme.TEXT_SECONDARY)
            }
            this.paramRow(def, index)
          }, (def: ParamDef) => def.key)
        }
        .width('100%')

        Divider().color(Theme.DIVIDER)

        Text('实时读数')
          .fontSize(Layout.sectionSize(this.cls()))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)

        Column({ space: 10 }) {
          ForEach(this.meta.observables, (def: ObservableDef, index: number) => {
            Row() {
              Text(def.label)
                .fontSize(Layout.labelSize(this.cls()))
                .fontColor(Theme.TEXT_PRIMARY)
                .layoutWeight(1)
              Text((this.readouts.length > index ? this.readouts[index] : '—') +
                (def.unit.length > 0 ? ' ' + def.unit : ''))
                .fontSize(Layout.readoutSize(this.cls()))
                .fontColor(Theme.ACCENT)
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')
          }, (def: ObservableDef) => def.key)
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(Layout.cardPadding(this.cls()))
  }

  /** 侧栏布局(平板、大屏)下的面板:自带滚动与卡片底 */
  @Builder
  panel() {
    Scroll() {
      this.panelContent()
    }
    .scrollBar(BarState.Auto)
    .backgroundColor(Theme.BG_CARD)
    .borderRadius(Layout.cardRadius(this.cls()))
    .width(Layout.panelWidth(this.cls()))
    .height('100%')
    .align(Alignment.TopStart)
  }

  build() {
    NavDestination() {
      if (this.scene === null) {
        Column() {
          // 原来写「该实验的渲染器尚未实现」—— 渲染器是我们自己的分层词,
          // 学生看到的应该是"这条还没做出来",而不是我们缺哪一层
          Text('这个实验还没做出来，先做清单里标了「能动手做」的那几条')
            .fontColor(Theme.TEXT_SECONDARY)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (Layout.isStacked(this.cls())) {
        Column({ space: 10 }) {
          // 画面高度给死而不是 layoutWeight:开图线时被挤成一条,2D 世界就没法读了
          SimCanvas({ controller: this.controller, scene: this.scene, meta: this.meta, hostWidth: this.hostWidth })
            .width('100%')
            .height(Layout.minSceneHeight(this.cls()))
          this.transportBar()
          // 图线与参数面板共用一个滚动区:各自带滚动时,图线一开就把画面顶出屏幕
          Scroll() {
            Column({ space: 10 }) {
              if (this.chartsVisible && this.meta.charts.length > 0) {
                this.chartStrip()
              }
              this.panelContent()
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .width('100%')
        }
        .padding(Layout.pageInset(this.cls()))
        .width('100%')
        .height('100%')
      } else {
        Row({ space: 12 }) {
          Column({ space: 10 }) {
            SimCanvas({ controller: this.controller, scene: this.scene, meta: this.meta, hostWidth: this.hostWidth })
              .layoutWeight(1)
              .constraintSize({ minHeight: Layout.minSceneHeight(this.cls()) })
            this.transportBar()
            if (this.chartsVisible && this.meta.charts.length > 0) {
              Scroll() {
                this.chartStrip()
              }
              .scrollBar(BarState.Auto)
              .width('100%')
              .height(Layout.chartViewportHeight(this.cls(), this.meta.charts.length))
            }
          }
          .layoutWeight(1)
          .height('100%')

          this.panel()
        }
        .padding(Layout.pageInset(this.cls()))
        .width('100%')
        .height('100%')
      }
    }
    .title(this.meta.title)
    .backgroundColor(Theme.BG_PAGE)
  }
}
