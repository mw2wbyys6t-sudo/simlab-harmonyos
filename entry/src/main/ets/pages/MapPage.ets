import { DeviceClass, Layout } from '../common/Layout';
import { Theme } from '../common/Theme';
import { CurriculumIndex } from '../content/map/CurriculumIndex';
import { ExperimentEntry, Feasibility, MapSubject, SchoolStage } from '../content/map/CurriculumTypes';
import { ChemicalElement } from '../content/map/PeriodicTable';
import { KnowledgeLevel, KnowledgePoint } from '../content/map/KnowledgeTypes';
import { AppChips } from '../view/AppChips';

/**
 * 课程地图页:只读浏览。
 *
 * 它回答两个问题:这门课要做什么实验、其中哪些这个应用现在真能打开。
 * 第二个问题的答案可能是「一条都不能」—— 生物那 41 条就是这样,这一栏不许粉饰。
 *
 * 数据一律走 `CurriculumIndex`,页面不自己拼表:一旦各读各的,分类计数就会和逐条统计分家。
 * 未核实的条目照常显示,但带着「未核实」标记 —— 地图的可信度不能靠假装确定来撑。
 */
class MapRow {
  id: string = '';
  title: string = '';
  /** 组首才显示课程名 */
  course: string = '';
  showCourse: boolean = false;
  badge: string = '';
  /** 出处没核查过:逐行标出来,不能只靠顶栏那个总数 */
  unverified: boolean = false;
  /** 周期表视图下的原子序数,另两个视图恒为 0 */
  elementNumber: number = 0;
}

@Component
export struct MapPage {
  @Prop hostWidth: number = 0;
  @State subjectIndex: number = 0;
  /** 指向 this.stages,不是固定三档 —— 只有物理现在有初中与高中数据 */
  @State stageIndex: number = 0;
  @State stages: SchoolStage[] = [];
  /** 0 = 实验清单,1 = 知识点,2 = 元素周期表(只有化学有) */
  @State mode: number = 0;
  @State rows: MapRow[] = [];
  @State selected: number = -1;
  /** 列表滚动控制器:展开详情时把这一行顶到视口上沿,不然正文可能全在屏幕外 */
  private listScroller: Scroller = new Scroller();

  private subjects: MapSubject[] = [MapSubject.PHYSICS, MapSubject.CHEMISTRY,
    MapSubject.BIOLOGY, MapSubject.ELECTRONICS];
  private subjectNames: string[] = ['物理', '化学', '生物', '电子'];

  aboutToAppear(): void {
    this.computeStages();
    this.rebuild();
  }

  /**
   * 换学科后重算这一学科实际有数据的学段,并把下标夹回去。
   *
   * 从物理的「大学」(下标 2)切到只有大学一格的化学,若不夹,下标会越界、
   * currentStage() 取到 undefined,列表就空着 —— 而空列表看起来像"化学没数据"。
   */
  private computeStages(): void {
    this.stages = CurriculumIndex.stagesOf(this.currentSubject());
    if (this.stageIndex >= this.stages.length) {
      this.stageIndex = 0;
    }
  }

  private cls(): DeviceClass {
    return Layout.classify(this.hostWidth);
  }

  private currentSubject(): MapSubject {
    return this.subjects[this.subjectIndex];
  }

  private currentStage(): SchoolStage {
    return this.stages[this.stageIndex];
  }

  /**
   * 可行性徽章。
   *
   * 枚举里分「缺场景 / 缺模型 / 缺渲染器」是我们排产用的,学生不需要知道少了哪一层 ——
   * 对他们只有三种事实:现在就能做、还没做出来、这实验本来就得用真器材。
   */
  private static badgeOf(feasibility: Feasibility): string {
    if (feasibility === Feasibility.RUNNABLE) {
      return '能动手做';
    }
    if (feasibility === Feasibility.NEEDS_REAL_GEARS) {
      return '要用真器材';
    }
    return '还没做出来';
  }

  private static levelOf(level: KnowledgeLevel): string {
    if (level === KnowledgeLevel.RECALL) {
      return '知道';
    }
    if (level === KnowledgeLevel.APPLY) {
      return '会用';
    }
    return '能迁移';
  }

  private hasPeriodicTable(): boolean {
    return this.currentSubject() === MapSubject.CHEMISTRY;
  }

  private modeName(index: number): string {
    if (index === 1) {
      return '知识点';
    }
    if (index === 2) {
      return '周期表';
    }
    return '实验清单';
  }

  /**
   * 重建当前列表。
   *
   * 按课程分组:同一门课只在组首显示一次课程名。这个「组首」判断要比**上一行的组**,
   * 不能比上一行的显示名 —— 后者会让连续同名的组只标出第一行,分组标题就漏了。
   */
  private rebuild(): void {
    const rows: MapRow[] = [];
    const subject = this.currentSubject();
    const stage = this.currentStage();
    let lastCourse = '';
    if (this.mode === 0) {
      const list = CurriculumIndex.experimentsOfStage(subject, stage);
      for (let i = 0; i < list.length; i++) {
        const e: ExperimentEntry = list[i];
        const row = new MapRow();
        row.id = e.id;
        row.title = e.title;
        row.course = e.course;
        row.showCourse = e.course !== lastCourse;
        row.badge = MapPage.badgeOf(e.feasibility) + ' · ' + e.term;
        row.unverified = !e.verified;
        rows.push(row);
        lastCourse = e.course;
      }
    } else if (this.mode === 1) {
      const list = CurriculumIndex.knowledgeOfStage(subject, stage);
      for (let i = 0; i < list.length; i++) {
        const k: KnowledgePoint = list[i];
        const row = new MapRow();
        row.id = k.id;
        row.title = k.title;
        row.course = k.chapter;
        row.showCourse = k.chapter !== lastCourse;
        row.badge = MapPage.levelOf(k.level);
        row.unverified = !k.verified;
        rows.push(row);
        lastCourse = k.chapter;
      }
    } else {
      const list = CurriculumIndex.elements();
      let lastPeriod = 0;
      for (let i = 0; i < list.length; i++) {
        const el: ChemicalElement = list[i];
        const row = new MapRow();
        row.id = 'el-' + el.number;
        row.elementNumber = el.number;
        row.title = el.name + ' (' + el.symbol + ')';
        row.course = '第 ' + el.period + ' 周期';
        row.showCourse = el.period !== lastPeriod;
        row.badge = el.mass + ' · ' + el.block + ' 区 · ' + el.state;
        row.unverified = !el.verified;
        rows.push(row);
        lastPeriod = el.period;
      }
    }
    this.rows = rows;
    this.selected = -1;
  }

  /**
   * 顶栏那句总数。按**当前学科 + 当前学段**报,不报全表 ——
   * 「共 75 个实验 · 现在能打开 1 个」和「高中 15 个 · 能打开 2 个」是两个不同的问题,
   * 后者才是学生站在这屏前想问的。周期表那一档不属于任何学段,它报的是全表。
   */
  /**
   * 顶部计数行。
   *
   * 原来印的是「共 18 个实验 · 现在能打开 2 个 · 出处未核实 2 个」—— 后半句是核对数据时
   * 用的工艺术语,学生读到只会问"未核实跟我有什么关系"。核实状态本来就标在每一行上,
   * 这一行只留两件事:这里有多少条,其中几条现在就能动手做。
   */
  private totalLabel(): string {
    const subject = this.currentSubject();
    const stage = this.currentStage();
    const stageName = CurriculumIndex.stageName(stage);
    const where = stageName + this.subjectNames[this.subjectIndex];
    if (this.mode === 0) {
      const list = CurriculumIndex.experimentsOfStage(subject, stage);
      if (list.length === 0) {
        return where + ' · 这里还没有可做的实验';
      }
      let runnable = 0;
      for (let i = 0; i < list.length; i++) {
        if (list[i].feasibility === Feasibility.RUNNABLE) {
          runnable++;
        }
      }
      return where + ' · 共 ' + list.length + ' 个实验，其中 ' + runnable + ' 个现在就能动手做';
    }
    if (this.mode === 1) {
      const list = CurriculumIndex.knowledgeOfStage(subject, stage);
      return list.length === 0
        ? where + ' · 这里还没有知识点'
        : where + ' · 共 ' + list.length + ' 条知识点';
    }
    return '共 ' + CurriculumIndex.elements().length + ' 种元素 · ' +
      '相对原子质量取教学常用值';
  }

  /** 选中条目的正文。取不到就返回空 —— 列表重建后下标会失效,这里不猜 */
  private detailBody(): string {
    if (this.selected < 0 || this.selected >= this.rows.length) {
      return '';
    }
    if (this.mode === 2) {
      const el = CurriculumIndex.findElement(this.rows[this.selected].elementNumber);
      if (el === null) {
        return '';
      }
      let text = '第 ' + el.period + ' 周期 · 第 ' + el.group + ' 族 · ' + el.block + ' 区\n' +
        '相对原子质量 ' + el.mass + ' · 常温' + el.state + ' · ' + el.kind + '\n' +
        '常见化合价：' + el.valenceLabel();
      if (el.note.length > 0) {
        text = text + '\n\n' + el.note;
      }
      return text;
    }
    const id = this.rows[this.selected].id;
    if (this.mode === 0) {
      const e = CurriculumIndex.findExperiment(id);
      if (e === null) {
        return '';
      }
      let text = e.principle;
      if (e.dataHandling.length > 0) {
        text = text + '\n\n数据处理：' + e.dataHandling;
      }
      text = text + '\n\n器材与试剂：' + e.apparatus.join('、');
      text = text + '\n\n涉及的知识点：' + e.knowledge.join('、');
      return text;
    }
    const k = CurriculumIndex.findKnowledge(id);
    if (k === null) {
      return '';
    }
    let text = k.statement;
    if (k.symbols.length > 0) {
      text = text + '\n\n符号与单位：' + k.symbols.join('、');
    }
    const prereqNames: string[] = [];
    for (let i = 0; i < k.prerequisites.length; i++) {
      const one = CurriculumIndex.findKnowledge(k.prerequisites[i]);
      prereqNames.push(one === null ? k.prerequisites[i] : one.title);
    }
    if (prereqNames.length > 0) {
      // 「先修」是课程设计的行话,学生要的是"这条得先会哪些"
      text = text + '\n\n要先会这些：' + prereqNames.join('、');
    }
    return text;
  }

  private detailSource(): string {
    if (this.selected < 0 || this.selected >= this.rows.length) {
      return '';
    }
    const id = this.rows[this.selected].id;
    if (this.mode === 2) {
      const el = CurriculumIndex.findElement(this.rows[this.selected].elementNumber);
      return el === null ? '' : el.source;
    }
    if (this.mode === 0) {
      const e = CurriculumIndex.findExperiment(id);
      return e === null ? '' : e.source;
    }
    const k = CurriculumIndex.findKnowledge(id);
    return k === null ? '' : k.source;
  }

  /**
   * 空列表要说清"是这里还没登记,还是这个应用没做"。
   *
   * 学段轴刚打开时最容易撞见:初中物理已有 40 条知识点,但实验条目一条还没登记 ——
   * 界面若什么都不显示,看起来像坏了,而实际上这正是地图在报"这里还空着"。
   * 所以空态里要指出另一格里有什么,让人能切过去。
   */
  private emptyText(): string {
    const subject = this.currentSubject();
    const stage = this.currentStage();
    const where = CurriculumIndex.stageName(stage) + this.subjectNames[this.subjectIndex];
    if (this.mode === 0) {
      const kn = CurriculumIndex.knowledgeOfStage(subject, stage).length;
      return '这张地图上' + where + '还没有收录实验' +
        (kn > 0 ? ' · 已有 ' + kn + ' 条知识点，可切到「知识点」' : '');
    }
    const exp = CurriculumIndex.experimentsOfStage(subject, stage).length;
    return '这张地图上' + where + '还没有收录知识点' +
      (exp > 0 ? ' · 已有 ' + exp + ' 个实验，可切到「实验清单」' : '');
  }

  private stageLabels(): string[] {
    return this.stages.map((stage: SchoolStage): string => CurriculumIndex.stageName(stage));
  }

  /** 周期表只属于化学,所以这一排只有化学是三个选项 */
  private modeLabels(): string[] {
    const count = this.hasPeriodicTable() ? 3 : 2;
    const out: string[] = [];
    for (let i = 0; i < count; i++) {
      out.push(this.modeName(i));
    }
    return out;
  }

  private pickSubject(index: number): void {
    this.subjectIndex = index;
    // 周期表只属于化学:切到别的学科时不能停留在一个已经没有意义的视图上
    if (this.mode === 2 && this.subjects[index] !== MapSubject.CHEMISTRY) {
      this.mode = 0;
    }
    this.computeStages();
    this.rebuild();
  }

  /**
   * 一行条目。
   *
   * 参数只接**下标**,内容在 Builder 体里现读 this.rows —— 按值传字符串的 @Builder
   * 不随 @State 刷新,这个坑在别处已经踩过两次(见 spec 8.13)。
   */
  @Builder
  rowCell(index: number) {
    Column({ space: 2 }) {
      if (this.rows[index].showCourse) {
        Text(this.rows[index].course)
          .fontSize(Layout.sectionSize(this.cls()))
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
          .margin({ top: 10, bottom: 2 })
      }
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(this.rows[index].title)
            .fontSize(Layout.bodySize(this.cls()))
            .fontColor(Theme.TEXT_PRIMARY)
          Text(this.rows[index].badge + (this.rows[index].unverified ? ' · 未核实' : ''))
            .fontSize(Layout.microSize(this.cls()))
            .fontColor(Theme.TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.selected === index ? '收起' : '详情')
          .fontSize(Layout.captionSize(this.cls()))
          .fontColor(Theme.ACCENT)
          .height(Layout.touchMin(this.cls()))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      // 整行就是命中区(「详情」只是提示),所以反馈也加在行上而不是那两个字上
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .onClick(() => {
        const opening = this.selected !== index;
        this.selected = opening ? index : -1;
        // 展开后立刻把这一行滚到视口上沿:否则点在屏幕下沿的条目时,
        // 刚展开的正文整段落在折叠线以下,看着像点了没反应
        if (opening) {
          this.listScroller.scrollToIndex(index, true, ScrollAlign.START);
        }
      })

      if (this.selected === index) {
        Column({ space: 6 }) {
          // 正文自带抬头:点在视口下沿的行上,标题行会被顶出屏幕,
          // 429 字的正文就成了没有名字的一段(模拟器实测 bounds 高 2px)
          Text(this.rows[index].title)
            .fontSize(Layout.sectionSize(this.cls()))
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.TEXT_PRIMARY)
          Text(this.detailBody())
            .fontSize(Layout.labelSize(this.cls()))
            .fontColor(Theme.TEXT_PRIMARY)
          Text('出处 ' + this.detailSource())
            .fontSize(Layout.microSize(this.cls()))
            .fontColor(Theme.TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({
          left: Layout.pageInset(this.cls()),
          right: Layout.pageInset(this.cls()),
          top: Layout.listGap(this.cls()),
          bottom: Layout.listGap(this.cls())
        })
        .backgroundColor(Theme.BG_CANVAS)
        .borderRadius(Layout.controlRadius(this.cls()))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  build() {
    NavDestination() {
      Column({ space: 8 }) {
        Text(this.totalLabel())
          .fontSize(Layout.captionSize(this.cls()))
          .fontColor(Theme.TEXT_SECONDARY)
          .width('100%')

        AppChips({
          labels: this.subjectNames,
          selected: this.subjectIndex,
          onPick: (index: number): void => {
            this.pickSubject(index);
          }
        })
          .width('100%')

        if (this.stages.length > 1) {
          AppChips({
            labels: this.stageLabels(),
            selected: this.stageIndex,
            onPick: (index: number): void => {
              this.stageIndex = index;
              this.rebuild();
            }
          })
            .width('100%')
        }

        AppChips({
          labels: this.modeLabels(),
          selected: this.mode,
          accent: Theme.SUBJECT_CHEMISTRY,
          onPick: (index: number): void => {
            this.mode = index;
            this.rebuild();
          }
        })
          .width('100%')

        if (this.rows.length === 0) {
          Column() {
            Text(this.emptyText())
              .fontSize(Layout.labelSize(this.cls()))
              .fontColor(Theme.TEXT_SECONDARY)
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          List({ space: 4, scroller: this.listScroller }) {
            ForEach(this.rows, (row: MapRow, index: number) => {
              ListItem() {
                this.rowCell(index)
              }
            }, (row: MapRow): string => row.id)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .height('100%')
      .padding({
        left: Layout.pageInset(this.cls()),
        right: Layout.pageInset(this.cls()),
        top: Layout.listGap(this.cls())
      })
    }
    .title('课程地图')
    .backgroundColor(Theme.BG_PAGE)
  }
}
