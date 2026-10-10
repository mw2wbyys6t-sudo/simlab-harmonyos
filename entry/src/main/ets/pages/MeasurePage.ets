import { DeviceClass, Layout } from '../common/Layout';
import { Theme } from '../common/Theme';
import { ExperimentMeta, ParamControl, ParamDef, RendererKind, Subject } from '../model/ExperimentTypes';
import { fact, SessionRecord } from '../model/SessionRecord';
import { BenchWorld } from '../bench/BenchWorld';
import { RubricMeasure } from '../bench/RubricMeasure';
import { SessionStore } from '../platform/SessionStore';
import { RunController } from '../runner/RunController';
import { GaugeMark, LathePainter, LatheSpec } from '../view3d/LathePainter';

const GOAL_ML: number = 10;

function param(key: string, label: string, unit: string, min: number, max: number, step: number,
  defaultValue: number, control: ParamControl): ParamDef {
  const def = new ParamDef();
  def.key = key;
  def.label = label;
  def.unit = unit;
  def.min = min;
  def.max = max;
  def.step = step;
  def.defaultValue = defaultValue;
  def.control = control;
  return def;
}

function measureMeta(): ExperimentMeta {
  const meta = new ExperimentMeta();
  meta.id = 'measure-10ml';
  meta.title = '用量筒量取 10 mL 水';
  meta.subject = Subject.CHEMISTRY;
  meta.renderer = RendererKind.STEP_RULES;
  meta.summary = '倾倒至你认为读数到达 10 mL 为止。视线没与凹液面齐平时，量取到的体积就会偏。';
  meta.gradeBand = '初中化学 · 基本实验操作';
  meta.worldWidth = 3;
  meta.worldHeight = 16;
  meta.params.push(param('tilt', '倾倒仰角', '°', 0, 90, 1, 0, ParamControl.SLIDER));
  meta.params.push(param('eye', '视线高度', 'cm', 0, 16, 0.2, 0, ParamControl.SLIDER));
  meta.params.push(param('guided', '用玻璃棒引流', '', 0, 1, 1, 1, ParamControl.SWITCH));
  meta.params.push(param('goal', '目标体积', 'mL', 5, 10, 0.5, GOAL_ML, ParamControl.SLIDER));
  return meta;
}

/**
 * 量取训练页。
 *
 * 这一页存在的目的不只是"有个界面":它把 bench 全部代码接进引用链,
 * 使它们第一次经过 ArkTS 类型检查 —— 未被引用的 .ets 文件不会被检查。
 */
@Component
export struct MeasurePage {
  @Prop hostWidth: number = 0;

  @State meta: ExperimentMeta = measureMeta();
  @State actual: number = 0;
  @State apparent: number = 0;
  @State eyeHeight: number = 0;
  @State tiltDeg: number = 0;
  @State guided: number = 1;
  @State running: boolean = false;
  @State verdict: string = '';
  @State spilled: number = 0;
  @State savedRuns: number = 0;

  private world: BenchWorld = new BenchWorld();
  private controller: RunController = new RunController();
  private ticker: number = -1;
  private lastAt: number = 0;
  private gctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  /** 试剂瓶的画布:倾倒仰角要有看得见的载体 */
  private bctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  /** 三条判读线的语义色:读数卡、图例、器身上的线共用这一份对照表 */
  private markColors: string[] = [Theme.RUNNING, Theme.DANGER, Theme.ACCENT];
  private gaugeLabels: string[] = ['实际量取', '你的读数', '目标'];
  private gaugeAccents: string[] = [Theme.TEXT_PRIMARY, Theme.ACCENT, Theme.RUNNING];

  private cls(): DeviceClass {
    return Layout.classify(this.hostWidth);
  }

  /**
   * 把这次操作写进本地记录。
   *
   * 只存观测到的数,不存结论 —— 结论由判据在回看时按当时的细则重算。把分数存死,
   * 细则换版本后历史记录就会和判据脱钩。
   */
  private recordRun(): void {
    const context: Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    const ledger = SessionStore.load(context);
    const rubric = RubricMeasure.create();
    const record = new SessionRecord();
    record.id = 'measure-' + String(Date.now());
    record.experimentId = this.meta.id;
    record.title = this.meta.title;
    record.subject = this.meta.subject;
    record.endedAtMs = Date.now();
    record.durationSec = this.world.elapsedTime();
    record.rubricId = rubric.id;
    record.rubricVersion = rubric.version;
    record.rubricSource = rubric.source;
    record.total = rubric.totalPoints;
    // awarded 刻意不写:分数回看时按当时的细则重算,存死就会和细则版本脱钩
    record.facts = [
      fact('goalMl', GOAL_ML),
      fact('actualMl', this.actual),
      fact('readMl', this.apparent),
      fact('spilledMl', this.spilled),
      fact('tiltDeg', this.tiltDeg),
      fact('eyeCm', this.eyeHeight)
    ];
    // 刻意不写 moments:仿真秒只在倾倒时累加,所以「开始倾倒」恒为 0.0 s、
    // 「收手停倒」恒等于用时 —— 那是两个假时刻。这一页目前只有一个动作,
    // 真正的分步时刻要等直接操纵层(拿起/倾斜/放平/移视线)才有东西可记。
    if (ledger.add(record) && SessionStore.save(context, ledger)) {
      this.savedRuns = ledger.size();
    }
  }

  aboutToAppear(): void {
    this.world.setup(this.meta);
    this.world.setParam('goal', GOAL_ML);
    this.world.setParam('eye', 0);
    this.controller.bind(this.world, this.meta);
    this.refresh();
    this.ticker = setInterval(() => {
      this.tick();
    }, 16);
  }

  aboutToDisappear(): void {
    if (this.ticker >= 0) {
      clearInterval(this.ticker);
      this.ticker = -1;
    }
    this.world.dispose();
  }

  /** 与 SimCanvas 同一套帧驱动:量墙钟时间差交给定步长累加器,保证与帧率无关 */
  private tick(): void {
    const now = Date.now();
    const dt = this.lastAt === 0 ? 0 : (now - this.lastAt) / 1000;
    this.lastAt = now;
    this.controller.advance(dt);
    this.refresh();
  }

  private refresh(): void {
    this.actual = this.world.readObservable('actual');
    this.apparent = this.world.readObservable('apparent');
    this.eyeHeight = this.world.eyeHeight();
    this.spilled = this.world.readObservable('spilled');
    this.running = this.controller.running;
    this.paintGauge();
    this.paintBottle();
  }

  /**
   * 世界体积(cm)→ 器内液面高度。非有限值一律返回 NaN,由绘制层跳过这条线 ——
   * Profile 的换算表对越界输入按满量程处理,直接喂 NaN 会一路落到顶端,画出一条假刻度。
   */
  private heightOf(volumeMl: number): number {
    if (!(volumeMl >= 0)) {
      return Number.NaN;
    }
    return this.world.cylinderProfile().heightForVolume(volumeMl);
  }

  /** 三条判读线共用绘制层的同一个高度函数,所以"齐平"是真的齐平 */
  private marks(): GaugeMark[] {
    const goal = new GaugeMark();
    goal.heightCm = this.heightOf(GOAL_ML);
    goal.color = this.markColors[0];
    goal.dashed = false;
    const reading = new GaugeMark();
    reading.heightCm = this.heightOf(this.apparent);
    reading.color = this.markColors[1];
    const eye = new GaugeMark();
    eye.heightCm = this.eyeHeight;
    eye.color = this.markColors[2];
    const out: GaugeMark[] = [];
    out.push(goal);
    out.push(reading);
    out.push(eye);
    return out;
  }

  /** 器内液体的真实体积决定液面,读数只是眼睛看到的位置,两者在绘制层各画各的 */
  private paintGauge(): void {
    if (this.gctx.width <= 0 || this.gctx.height <= 0) {
      return;
    }
    const spec = new LatheSpec();
    spec.profile = this.world.cylinderProfile();
    spec.volumeMl = this.actual;
    spec.marks = this.marks();
    LathePainter.draw(this.gctx, spec);
  }

  /**
   * 试剂瓶:量取页上唯一会歪的那只器皿。
   *
   * 倾角取世界层的输入参数(`reagentTiltDeg`),暂停时也照着滑杆走 ——
   * 曾经取过 `pose.tiltDeg`,而它只在 `step()` 里被赋值,结果拖着滑杆瓶子一动不动,
   * 界面又变成在说一件没发生的事。倒掉多少,瓶里的液面就矮多少(视图层只读,I3)。
   */
  private paintBottle(): void {
    if (this.bctx.width <= 0 || this.bctx.height <= 0) {
      return;
    }
    const spec = new LatheSpec();
    spec.profile = this.world.reagentProfile();
    spec.volumeMl = this.world.reagentVolumeMl();
    spec.tiltDeg = this.world.reagentTiltDeg();
    spec.graduated = false;
    LathePainter.draw(this.bctx, spec);
  }

  private verdictOf(): string {
    const error = this.world.readObservable('error');
    const offset = this.world.readObservable('eyeOffset');
    const signed = Math.abs(error) < 0.005 ? '正好到目标量'
      : (error > 0 ? `多倒了 ${error.toFixed(2)} mL` : `少倒了 ${(-error).toFixed(2)} mL`);
    let cause = '视线与凹液面齐平，读数可信';
    if (offset < -0.2) {
      cause = '仰视(眼睛低于液面)→ 读数偏小 → 实际倒多了';
    } else if (offset > 0.2) {
      cause = '俯视(眼睛高于液面)→ 读数偏大 → 实际倒少了';
    }
    return `实际 ${this.actual.toFixed(2)} mL,读数 ${this.apparent.toFixed(2)} mL;${signed}。${cause}`
      + (this.spilled > 0.01 ? `;另有 ${this.spilled.toFixed(2)} mL 溅失。` : '。');
  }

  /**
   * 读数卡。
   *
   * @Builder 的入参按值传时不随 @State 刷新(实测:倾倒过程中数字一直停在 0.00),
   * 所以这里只接一个常量下标,要显示的值在 Builder 体里现读 —— 依赖才登记得进来。
   */
  @Builder
  gaugeCell(index: number) {
    Column({ space: 2 }) {
      Text(this.gaugeLabels[index])
        .fontSize(Layout.captionSize(this.cls()))
        .fontColor(Theme.TEXT_SECONDARY)
      Text(this.gaugeValueAt(index))
        .fontSize(Layout.readoutSize(this.cls()))
        .fontWeight(FontWeight.Bold)
        .fontColor(this.gaugeAccents[index])
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  private gaugeValueAt(index: number): string {
    if (index === 0) {
      return this.actual.toFixed(2) + ' mL';
    }
    return index === 1 ? this.apparent.toFixed(2) + ' mL' : GOAL_ML.toFixed(2) + ' mL';
  }

  @Builder
  legendRow(index: number) {
    Row({ space: 5 }) {
      Column()
        .width(Layout.tickWidth())
        .height(Layout.tickHeight())
        .backgroundColor(this.markColors[index])
        .borderRadius(Layout.tickHeight() / 2)
      Text(this.legendTextAt(index))
        .fontSize(Layout.captionSize(this.cls()))
        .fontColor(Theme.TEXT_SECONDARY)
    }
    .alignItems(VerticalAlign.Center)
  }

  private legendTextAt(index: number): string {
    if (index === 0) {
      return `目标 ${GOAL_ML.toFixed(1)} mL 位`;
    }
    if (index === 1) {
      return `读数位 ${this.legendHeight(this.heightOf(this.apparent))}`;
    }
    return `视线位 ${this.legendHeight(this.eyeHeight)}`;
  }

  private legendHeight(heightCm: number): string {
    return !(heightCm >= 0) ? '—' : heightCm.toFixed(1) + ' cm';
  }

  @Builder
  sliderRow(index: number) {
    Column({ space: 2 }) {
      Row() {
        Text(this.meta.params[index].label)
          .fontSize(Layout.labelSize(this.cls()))
          .fontColor(Theme.TEXT_PRIMARY)
          .layoutWeight(1)
        Text(this.sliderValueTextAt(index))
          .fontSize(Layout.labelSize(this.cls()))
          .fontColor(Theme.ACCENT)
      }
      .width('100%')

      Slider({
        value: this.sliderAt(index),
        min: this.meta.params[index].min,
        max: this.meta.params[index].max,
        step: this.meta.params[index].step
      })
        .blockColor(Theme.ACCENT)
        .selectedColor(Theme.ACCENT)
        .onChange((v: number) => {
          this.setSlider(index, v);
        })
    }
    .width('100%')
  }

  private sliderAt(index: number): number {
    return index === 0 ? this.tiltDeg : this.eyeHeight;
  }

  private sliderValueTextAt(index: number): string {
    const def = this.meta.params[index];
    return this.sliderAt(index).toFixed(def.step >= 1 ? 0 : 1) + ' ' + def.unit;
  }

  private setSlider(index: number, value: number): void {
    if (index === 0) {
      this.tiltDeg = value;
      this.world.setParam('tilt', value);
      // Canvas 不会自己重画:这条曾经直接 return,因为当时屏幕上确实没有东西跟着仰角变。
      // 现在试剂瓶要照着这个角度歪,不 repaint 就等于瓶子冻在原地。
      this.refresh();
      return;
    }
    this.eyeHeight = value;
    this.world.setParam('eye', value);
    this.refresh();
  }

  /**
   * 状态行的措辞。原来写的是「松开仰角可停」,可仰角是滑杆,没有「松手」这回事 ——
   * 界面在描述一个不存在的动作。现在说的这句由物理侧给数:低于起倒角就没有液流。
   */
  private statusText(): string {
    if (!this.running) {
      return '已暂停';
    }
    const onset: number = this.world.readObservable('onsetDeg');
    if (this.tiltDeg < onset) {
      return '倾倒中·仰角未到 ' + onset.toFixed(0) + '°，暂无液流';
    }
    return '倾倒中·仰角降回 ' + onset.toFixed(0) + '° 以下即停';
  }

  /**
   * 量筒本体:由回转体绘制器画的玻璃器皿。
   *
   * Canvas 是命令式重绘的,挂在 16ms 的 refresh() 上;这里刻意不把绘制结果写回
   * @State,否则整棵页面树会跟着帧率重建。
   */
  @Builder
  cylinder() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        // 瓶底与筒底同线:两个画布都按「器底坐画布下沿」定标,所以底部对齐就是共用一张台面
        Canvas(this.bctx)
          .width(Layout.bottleWidth(this.cls()))
          .height(Layout.bottleHeight(this.cls()))
          .onReady(() => {
            this.paintBottle();
          })
        Canvas(this.gctx)
          .width(Layout.gaugeWidth(this.cls()))
          .height(Layout.gaugeHeight(this.cls()))
          .onReady(() => {
            this.paintGauge();
          })
      }
      .alignItems(VerticalAlign.Bottom)
      this.legendRow(0)
      this.legendRow(1)
      this.legendRow(2)
    }
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 整页放进 Scroll。
   *
   * 之前是 Column.height('100%') + 中段 layoutWeight(1):加上回转体和图例后内容超过一屏,
   * 被压缩的中段会和后面的判定语重叠在同一处(模拟器实测)。滚动不猜屏幕高度。
   */
  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          Text(this.meta.title)
            .fontSize(Layout.pageTitleSize(this.cls()))
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)
          Text(this.meta.summary)
            .fontSize(Layout.labelSize(this.cls()))
            .fontColor(Theme.TEXT_SECONDARY)

          Row({ space: 10 }) {
            this.gaugeCell(0)
            this.gaugeCell(1)
            this.gaugeCell(2)
          }
          .width('100%')
          .padding(Layout.cardPadding(this.cls()))
          .backgroundColor(Theme.BG_CARD)
          .borderRadius(Layout.cardRadius(this.cls()))

          /* 器皿与操作分两行:量筒要的是竖向空间,滑杆和按钮要的是横向空间。
             把它们挤在同一个 Row 里,两头都不够 —— 侧栏只放状态与三个动作。 */
          Column({ space: 12 }) {
            Row({ space: 12 }) {
              this.cylinder()

              Column({ space: 10 }) {
                Text(this.statusText())
                  .fontSize(Layout.captionSize(this.cls()))
                  .fontColor(this.running ? Theme.RUNNING : Theme.TEXT_SECONDARY)
                  .width('100%')

                Text(this.running ? '暂停' : '开始倾倒')
                  .fontSize(Layout.bodySize(this.cls()))
                  .fontColor(Color.White)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 12, bottom: 12 })
                  .borderRadius(Layout.controlRadius(this.cls()))
                  .backgroundColor(this.running ? Theme.DANGER : Theme.ACCENT)
                  .onClick(() => {
                    if (this.controller.running) {
                      this.controller.pause();
                    } else {
                      this.controller.start();
                    }
                    this.refresh();
                  })
                Text('收手判定')
                  .fontSize(Layout.bodySize(this.cls()))
                  .fontColor(Color.White)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 12, bottom: 12 })
                  .borderRadius(Layout.controlRadius(this.cls()))
                  .backgroundColor(Theme.RUNNING)
                  .onClick(() => {
                    this.world.stop();
                    this.controller.pause();
                    this.verdict = this.verdictOf();
                    this.refresh();
                    this.recordRun();
                  })
                Text('重来')
                  .fontSize(Layout.bodySize(this.cls()))
                  .fontColor(Theme.TEXT_PRIMARY)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 12, bottom: 12 })
                  .borderRadius(Layout.controlRadius(this.cls()))
                  .border({ width: 1, color: Theme.DIVIDER })
                  .backgroundColor(Theme.BG_CARD)
                  .onClick(() => {
                    this.controller.restart();
                    this.verdict = '';
                    this.refresh();
                  })
              }
              .layoutWeight(1)
            }
            .alignItems(VerticalAlign.Top)
            .width('100%')

            Column({ space: 12 }) {
              this.sliderRow(0)
              this.sliderRow(1)
              Row() {
                Text(this.meta.params[2].label)
                  .fontSize(Layout.labelSize(this.cls()))
                  .fontColor(Theme.TEXT_PRIMARY)
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.guided >= 0.5 })
                  .selectedColor(Theme.ACCENT)
                  .onChange((isOn: boolean) => {
                    this.guided = isOn ? 1 : 0;
                    this.world.setParam('guided', this.guided);
                  })
              }
              .width('100%')
            }
            .width('100%')
          }
          .width('100%')

          if (this.verdict.length > 0) {
            Text(this.verdict)
              .fontSize(Layout.labelSize(this.cls()))
              .fontColor(Theme.TEXT_PRIMARY)
              .width('100%')
              .padding(Layout.cardPadding(this.cls()))
              .backgroundColor('#FFF6E8')
              .borderRadius(Layout.cardRadius(this.cls()))
          }

          if (this.savedRuns > 0) {
            Text('已保存 ' + this.savedRuns + ' 次操作记录，可在「报告」里回看')
              .fontSize(Layout.captionSize(this.cls()))
              .fontColor(Theme.TEXT_SECONDARY)
              .width('100%')
          }
        }
        .padding(Layout.pageInset(this.cls()))
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Auto)
    }
    .title('量取训练')
    .backgroundColor(Theme.BG_PAGE)
  }
}
