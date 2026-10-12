import { Substance } from './ChemistryModel';
import { Reagents } from './ChemistryLibrary';
import { GlassShapes } from '../geometry/GlassShapes';
import { VesselBase } from '../bench/VesselBase';

/** 容器种类。决定容量与可用的取用方式。 */
export enum VesselKind {
  TUBE = 'tube',
  BEAKER = 'beaker',
  FLASK = 'flask'
}

/**
 * 实验台上的一只容器 = 共用外壳(几何/位姿/支撑/损伤)+ 试剂账本。
 *
 * 外壳来自 `bench/VesselBase`,与提纯链路的 `Container` 同一套:落差、液面、能否装下、
 * 靠不靠得拢这些几何量只该有一个算法。账本没有合并 —— 这里记的是「试剂键 → 摩尔」,
 * 随化学计量反应演化,和 Brine 的相账本是两种物理。
 */
export class Vessel extends VesselBase {
  kind: VesselKind = VesselKind.TUBE;
  /** 未反应的物质,按试剂键累计 */
  contents: Content[] = [];
  /** 已逸出的气体。敞口容器里气体跑掉,是「反应后称量变轻」这一考点的来源 */
  escaped: Content[] = [];
  /**
   * 从破损处漏走的内容物。与逸出分开记:一个是反应生成的气体跑了,
   * 一个是容器被砸坏漏了 —— 后者是操作失误,报告必须能单独指出来。
   */
  leaked: Content[] = [];
  heated: boolean = false;
  powered: boolean = false;
  /** 容量(份)。倒多了会溢出,这是真实操作约束 */
  capacity: number = 8;

  constructor() {
    super();
    this.profile = GlassShapes.of(this.kind);
  }

  /** 造一只容器。kind 与几何必须一起定 */
  static of(kind: VesselKind, label: string, capacityPortions: number): Vessel {
    const vessel = new Vessel();
    vessel.setKind(kind);
    vessel.label = label;
    vessel.capacity = capacityPortions;
    return vessel;
  }

  /**
   * 换种类。走这个方法而不是直接改 `kind`,否则几何会停在旧形状上 ——
   * 落差、液面、容量全都跟着几何走,悄悄错配比报错难查得多。
   */
  setKind(kind: VesselKind): void {
    this.kind = kind;
    this.profile = GlassShapes.of(kind);
  }

  capacityPortions(): number {
    return this.capacity;
  }

  /** 器底破损时按比例漏走内容物,返回漏走的质量(g) */
  drainFraction(fraction: number): number {
    return Contents.leakInto(this.contents, this.leaked, fraction);
  }
}


/** 容器中某一试剂的存量。 */
export class Content {
  key: string = '';
  moles: number = 0;

  constructor(key: string, moles: number) {
    this.key = key;
    this.moles = moles;
  }

  mass(): number {
    return this.moles * Reagents.get(this.key).molarMass();
  }
}

/** 一次操作的结果,供界面把「发生了什么」讲清楚。 */
export class BenchEvent {
  reactionId: string = '';
  title: string = '';
  /**
   * 配平后的化学方程式(含条件与可逆箭头)。
   *
   * 由引擎在成事那一刻填,而不是让页面拿 reactionId 去反查:方程式是这次反应的事实之一,
   * 与现象同级。让视图层反查会把「这是哪条反应」的判定摊到页面上,而页面不许做判定(不变量 I3)。
   */
  equation: string = '';
  /** 离子方程式;非溶液中的复分解/氧化还原为空 */
  ionicEquation: string = '';
  /** 按观察顺序呈现的现象 */
  phenomena: string[] = [];
  /** 生成的气体(含逸出量),用于气泡与收集提示 */
  gases: string[] = [];
  /** 生成的沉淀颜色描述 */
  precipitates: string[] = [];
  /** 反应被拦下的原因,空表示没有被拦 */
  blocked: string = '';

  static note(reason: string): BenchEvent {
    const event = new BenchEvent();
    event.blocked = reason;
    return event;
  }
}

export const PORTION_MOLES: number = 0.02;
export const DROP_MOLES: number = 0.002;

export class BenchView {
  /** 液面颜色:取现存物质中最「显眼」的一种 */
  liquidColor: string = '#DCE6F2';
  /** 已反应完、静置在底部的固体 */
  solids: string[] = [];
  /** 正在冒泡(本次操作有气体生成且容器未冷却) */
  bubbling: boolean = false;
  portions: number = 0;
}

/** 试剂键 → 存量。容器内容的读写入口。 */
export class Contents {
  static find(items: Content[], key: string): Content | null {
    for (let i = 0; i < items.length; i++) {
      if (items[i].key === key) {
        return items[i];
      }
    }
    return null;
  }

  static add(items: Content[], key: string, moles: number): void {
    const hit = Contents.find(items, key);
    if (hit === null) {
      items.push(new Content(key, moles));
      return;
    }
    hit.moles += moles;
  }

  static take(items: Content[], key: string, moles: number): void {
    const hit = Contents.find(items, key);
    if (hit === null) {
      return;
    }
    hit.moles -= moles;
    if (hit.moles <= 1e-12) {
      const index = items.indexOf(hit);
      items.splice(index, 1);
    }
  }

  static totalMass(items: Content[]): number {
    let sum = 0;
    for (let i = 0; i < items.length; i++) {
      sum += items[i].mass();
    }
    return sum;
  }

  /**
   * 按比例把内容物从 source 搬进 target(器底破损的漏失),返回搬走的质量(g)。
   *
   * 逐键搬,所以"漏掉的是哪种试剂"在账上仍然看得见 —— 报告要能指名。
   * 搬走而不是减掉:凭空减少会让「现存 + 逸出 + 漏出 = 加入量」这条守恒当场破掉,
   * 而那条不变量是这一整套判据可信的前提。
   */
  static leakInto(source: Content[], target: Content[], fraction: number): number {
    const f = Math.min(1, Math.max(0, fraction));
    if (f <= 0) {
      return 0;
    }
    let grams = 0;
    const keep: Content[] = [];
    for (let i = 0; i < source.length; i++) {
      const item = source[i];
      const moved = new Content(item.key, item.moles * f);
      grams += moved.mass();
      Contents.add(target, moved.key, moved.moles);
      item.moles -= moved.moles;
      if (item.moles > 1e-12) {
        keep.push(item);
      }
    }
    source.length = 0;
    for (let i = 0; i < keep.length; i++) {
      source.push(keep[i]);
    }
    return grams;
  }
}

/**
 * 物质颜色描述到绘制色的映射。界面与引擎共用一张表,避免两处不一致。
 *
 * 「无色」不能真的取无色:器皿本身就是这个色调,液体画上去就消失了。取的是
 * 无色溶液装在玻璃管里实际看到的那层冷蓝 —— 名字仍是「无色」,只是绘制色要看得见。
 */
export class Palette {
  /** 无色溶液的绘制色,同时是未知颜色描述的兜底 */
  static readonly COLORLESS: string = '#BBD8F0';

  private static readonly colors: Map<string, string> = new Map([
    ['无色', Palette.COLORLESS],
    ['蓝色', '#2F6FB5'],
    ['浅绿色', '#7FC8A9'],
    ['紫红色', '#7B3FA0'],
    ['紫黑色', '#3B2148'],
    ['墨绿色', '#1F5C42'],
    ['黑色', '#2B2B2B'],
    ['红棕色', '#8B3A1E'],
    ['银白色', '#C9D2DC'],
    ['灰黑色', '#6A6E73'],
    ['白色', '#F2F4F7'],
    ['黄绿色', '#B7D44A']
  ] as [string, string][]);

  static of(substance: Substance): string {
    const hit = Palette.colors.get(substance.color);
    return hit === undefined ? Palette.COLORLESS : hit;
  }
}
