import { DeviceClass, Layout } from '../common/Layout';
import { Theme } from '../common/Theme';
import { ChartDef, ExperimentMeta, ObservableDef, ParamControl, ParamDef } from '../model/ExperimentTypes';
import { Physics2DRunner } from '../physics/Physics2DRunner';
import { ExperimentRegistry } from '../runner/ExperimentRegistry';
import { IExperimentRunner } from '../runner/IExperimentRunner';
import { RunController } from '../runner/RunController';
import { SeriesChart } from '../view/SeriesChart';
import { SimCanvas } from '../view/SimCanvas';

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

  @Builder
  transportButton(label: string, accent: string, action: () => void) {
    Text(label)
      .fontSize(Layout.bodySize(this.cls()))
      .fontColor(Color.White)
      .fontWeight(FontWeight.Medium)
      .height(Layout.buttonHeight(this.cls()))
      .padding({ left: 20, right: 20 })
      .borderRadius(Layout.controlRadius(this.cls()))
      .backgroundColor(accent)
      .onClick(action)
  }

  @Builder
  transportBar() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        this.transportButton(this.running ? '暂停' : '开始',
          this.running ? Theme.DANGER : Theme.RUNNING, (): void => {
            if (this.controller.running) {
              this.controller.pause();
            } else {
              this.controller.start();
            }
            this.refreshReadouts();
          })

        this.transportButton('重置', Theme.TEXT_SECONDARY, (): void => {
          this.controller.pause();
          this.controller.restart();
          this.refreshReadouts();
        })

        this.transportButton('图线', this.chartsVisible ? Theme.ACCENT : Theme.TEXT_SECONDARY, (): void => {
          this.chartsVisible = !this.chartsVisible;
        })

        Blank()

        Text('t = ' + this.simTime.toFixed(2) + ' s')
          .fontSize(Layout.sectionSize(this.cls()))
          .fontColor(Theme.TEXT_PRIMARY)
          .fontFamily('HarmonyOS Sans')
      }
      .width('100%')

      // 倍速单独一行:和三个按钮挤在同一行时,手机档会把后两颗推出屏幕,
      // 而推出去的控件既看不见也点不着。
      Row({ space: 8 }) {
        ForEach(SPEEDS, (speed: number, index: number) => {
          Text(speed + '×')
            .fontSize(Layout.labelSize(this.cls()))
            .fontColor(this.speedIndex === index ? Color.White : Theme.TEXT_SECONDARY)
            .height(Layout.touchMin(this.cls()))
            .padding({ left: 12, right: 12 })
            .borderRadius(Layout.controlRadius(this.cls()))
            .backgroundColor(this.speedIndex === index ? Theme.ACCENT : Theme.BG_PAGE)
            .onClick(() => {
              this.speedIndex = index;
              this.controller.timeScale = SPEEDS[index];
            })
        }, (speed: number) => speed.toString())
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
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

  @Builder
  chartStrip() {
    Column({ space: 10 }) {
      ForEach(this.meta.charts, (chart: ChartDef) => {
        SeriesChart({ chart: chart, controller: this.controller, hostWidth: this.hostWidth, tick: this.chartTick })
          .layoutWeight(1)
          .width('100%')
      }, (chart: ChartDef) => chart.title)
    }
    .width('100%')
    .height(Layout.chartAreaHeight(this.cls()))
  }

  @Builder
  panel() {
    Scroll() {
      Column({ space: 16 }) {
        if (this.meta.summary.length > 0) {
          Text(this.meta.summary)
            .fontSize(Layout.bodySize(this.cls()))
            .fontColor(Theme.TEXT_SECONDARY)
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
    .scrollBar(BarState.Auto)
    .backgroundColor(Theme.BG_CARD)
    .borderRadius(Layout.cardRadius(this.cls()))
    .width(Layout.isStacked(this.cls()) ? '100%' : Layout.panelWidth(this.cls()))
    .height(Layout.isStacked(this.cls()) ? Layout.stackedChartHeight() : '100%')
    .align(Alignment.TopStart)
  }

  build() {
    NavDestination() {
      if (this.scene === null) {
        Column() {
          Text('该实验的渲染器尚未实现')
            .fontColor(Theme.TEXT_SECONDARY)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (Layout.isStacked(this.cls())) {
        Column({ space: 10 }) {
          SimCanvas({ controller: this.controller, scene: this.scene, meta: this.meta, hostWidth: this.hostWidth })
            .layoutWeight(1)
          this.transportBar()
          if (this.chartsVisible && this.meta.charts.length > 0) {
            this.chartStrip()
          }
          this.panel()
        }
        .padding(Layout.pageInset(this.cls()))
        .width('100%')
        .height('100%')
      } else {
        Row({ space: 12 }) {
          Column({ space: 10 }) {
            SimCanvas({ controller: this.controller, scene: this.scene, meta: this.meta, hostWidth: this.hostWidth })
              .layoutWeight(1)
            this.transportBar()
            if (this.chartsVisible && this.meta.charts.length > 0) {
              this.chartStrip()
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
