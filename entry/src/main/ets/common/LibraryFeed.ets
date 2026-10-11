import { ExperimentMeta, Subject } from '../model/ExperimentTypes';

/**
 * 实验库列表项的视图模型。
 *
 * 存在的理由:量取训练与化学实验台是「实操项」,它们没有 runner 工厂,不能注册进
 * ExperimentRegistry;但它们又该出现在实验列表里,而不是占掉首屏顶部的导航位。
 * 所以列表用这个视图模型统一渲染,`ExperimentMeta` 与注册表都不被导航语义污染。
 */
export class FeedItem {
  key: string = '';
  title: string = '';
  subject: Subject = Subject.PHYSICS_MECHANICS;
  gradeBand: string = '';
  durationMinutes: number = 0;
  summary: string = '';
  /** navDestination 路由名 */
  route: string = 'experiment';
  /** route 为 experiment 时据此取 runner;实操项留空 */
  experimentId: string = '';
}

/**
 * 筛选条上的一枚 chip。叫 FilterChip 而不是 Chip:后者是 ArkUI 的内置组件名,
 * 同名会在编译期与内置成员撞车。
 */
export class FilterChip {
  label: string = '';
  /** null 表示「全部」 */
  subject: Subject | null = null;
}

export class LibraryFeed {
  static readonly ALL_LABEL: string = '全部';
  /** 手机内容区可用宽度:360vp 屏宽减去左右两侧页边距 */
  static readonly PHONE_CONTENT_WIDTH: number = 320;
  /**
   * 一枚 chip 的宽度构成:两个汉字 + 左右内边距。前提是短标签恒为双字。
   *
   * 这组数在换成系统 `ChipGroup` 后重测过一次(2026-10-11,Pura 90 Pro 模拟器):
   * SMALL 档一枚实测 56vp、间距 8vp。旧值 28+16=44 是按手搓 Text 量的,
   * 用它算「五颗放得下」而屏幕上最右那颗被切掉半字 —— 护栏算的是已经不存在的布局。
   */
  static readonly CHIP_TEXT_VP: number = 28;
  static readonly CHIP_PADDING_VP: number = 28;
  static readonly CHIP_GAP_VP: number = 8;
  /** chip 与分组的呈现顺序,与 Subject 声明顺序一致 */
  private static readonly ORDER: Subject[] = [
    Subject.PHYSICS_MECHANICS, Subject.PHYSICS_ELECTRICAL, Subject.CHEMISTRY,
    Subject.BIOLOGY, Subject.GEOGRAPHY, Subject.MATH_VISUAL, Subject.INSTRUMENT
  ];

  /** 二字符短标签。窄屏筛选条与卡片色标共用,长度必须为 2,否则一行放不下。 */
  static shortLabel(subject: Subject): string {
    if (subject === Subject.PHYSICS_MECHANICS) {
      return '力学';
    }
    if (subject === Subject.PHYSICS_ELECTRICAL) {
      return '电学';
    }
    if (subject === Subject.CHEMISTRY) {
      return '化学';
    }
    if (subject === Subject.BIOLOGY) {
      return '生物';
    }
    if (subject === Subject.GEOGRAPHY) {
      return '地理';
    }
    if (subject === Subject.MATH_VISUAL) {
      return '数学';
    }
    return '仪器';
  }

  /** 完整学科标签,用于实验页与报告页。 */
  static fullLabel(subject: Subject): string {
    if (subject === Subject.PHYSICS_MECHANICS) {
      return '物理 · 力学';
    }
    if (subject === Subject.PHYSICS_ELECTRICAL) {
      return '物理 · 电学';
    }
    if (subject === Subject.CHEMISTRY) {
      return '化学';
    }
    if (subject === Subject.BIOLOGY) {
      return '生物';
    }
    if (subject === Subject.GEOGRAPHY) {
      return '地理';
    }
    if (subject === Subject.MATH_VISUAL) {
      return '数学可视化';
    }
    return '仪器实操';
  }

  static fromMeta(meta: ExperimentMeta): FeedItem {
    const item = new FeedItem();
    item.key = meta.id;
    item.title = meta.title;
    item.subject = meta.subject;
    item.gradeBand = meta.gradeBand;
    item.durationMinutes = meta.durationMinutes;
    item.summary = meta.summary;
    item.route = 'experiment';
    item.experimentId = meta.id;
    return item;
  }

  /**
   * 没有 runner 工厂、但同样出现在实验列表里的两项实操。
   *
   * 它们刻意不走 `ExperimentRegistry`:那张表要求一个 `RunnerFactory`,而这两页的界面
   * 是手写的 ArkUI 组件,不是 `ExperimentPage` 的自动渲染。把它们做成列表条目而不是
   * 顶部导航胶囊,首屏才只有一件事:挑实验。
   */
  static practiceItems(): FeedItem[] {
    const measure = new FeedItem();
    measure.key = 'practice-measure';
    measure.title = '量取训练';
    measure.subject = Subject.INSTRUMENT;
    measure.gradeBand = '实验基本操作 · 量筒读数';
    measure.durationMinutes = 10;
    measure.summary = '向量筒倾倒氯化钠溶液，仰视、俯视与齐平三种视线读到的体积不同。';
    measure.route = 'measure';

    const bench = new FeedItem();
    bench.key = 'practice-bench';
    bench.title = '化学实验台';
    bench.subject = Subject.CHEMISTRY;
    bench.gradeBand = '初高中化学 · 自由搭建';
    bench.durationMinutes = 0;
    bench.summary = '把试剂与器材拖上台面，混合后按物质的量算生成物与剩余物。';
    bench.route = 'bench';

    return [measure, bench];
  }

  /** 由数据推导筛选条:只列出真的有内容的学科,「全部」恒在首位。 */
  static chips(items: FeedItem[]): FilterChip[] {
    const all = new FilterChip();
    all.label = LibraryFeed.ALL_LABEL;
    all.subject = null;
    const out: FilterChip[] = [all];
    for (const subject of LibraryFeed.ORDER) {
      let present = false;
      for (const item of items) {
        if (item.subject === subject) {
          present = true;
        }
      }
      if (present) {
        const chip = new FilterChip();
        chip.label = LibraryFeed.shortLabel(subject);
        chip.subject = subject;
        out.push(chip);
      }
    }
    return out;
  }

  static select(items: FeedItem[], chip: FilterChip): FeedItem[] {
    const wanted: Subject | null = chip.subject;
    if (wanted === null) {
      return items;
    }
    return items.filter((item: FeedItem) => item.subject === wanted);
  }

  static chipRowWidth(chips: FilterChip[]): number {
    if (chips.length === 0) {
      return 0;
    }
    const perChip = LibraryFeed.CHIP_TEXT_VP + LibraryFeed.CHIP_PADDING_VP;
    return chips.length * perChip + (chips.length - 1) * LibraryFeed.CHIP_GAP_VP;
  }

  /** 一行放得下吗。将来加学科时这条断言会先红,提醒改布局而不是等真机截图。 */
  static fitsOnPhone(chips: FilterChip[]): boolean {
    return LibraryFeed.chipRowWidth(chips) <= LibraryFeed.PHONE_CONTENT_WIDTH;
  }
}
