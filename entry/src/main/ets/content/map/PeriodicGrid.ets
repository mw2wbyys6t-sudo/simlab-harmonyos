import { ChemicalElement, PeriodicTable } from "./PeriodicTable";

/**
 * 标准长式周期表的格子。
 *
 * 四种格子共用一个类,靠 kind 区分:族号表头、元素格、标记格、空位。
 * 不拆成四个类,是因为渲染时格子是按行按列铺开的,「这一格是什么」是数据而不是结构。
 */
export class GridCell {
  /** group 族号表头 / element 元素格 / marker 标记格 / empty 空位 */
  kind: string = "";
  /** 行内唯一键,给 ForEach 用 */
  key: string = "";
  /** 上行文字:族号、原子序数、原子序数区间 */
  top: string = "";
  /** 下行文字:元素符号、系列名 */
  bottom: string = "";
  /** 元素格的原子序数;其余为 0 */
  atomicNumber: number = 0;
  /** 标记格指向的系列下标;其余为 -1 */
  seriesIndex: number = -1;
}

/**
 * 周期表的一行。
 *
 * 表头行、七个周期行、表下方两个 f 区行,都是同一种行:左边一栏标签,右边 18 个格子。
 */
export class GridRow {
  /** header 族号表头 / period 周期行 / series f 区行 */
  kind: string = "";
  key: string = "";
  /** 左侧那一栏:族号表头写「族号」,周期行写周期号,f 区行写系列名 */
  label: string = "";
  /** f 区行指向的系列下标;其余为 -1 */
  seriesIndex: number = -1;
  cells: GridCell[] = [];
}

/**
 * 主表里的标记格。
 *
 * 人教版的标准表在第 6 周期第 3 族的位置写「57～71」、第 7 周期第 3 族的位置写「89～103」,
 * 提醒学生镧系与锕系被从主表里摘出去了、在表下方单独两行。这两格是那一提醒本身。
 */
export class PeriodicMarker {
  period: number = 0;
  group: number = 0;
  /** 原子序数区间,例如 57～71 */
  range: string = "";
  /** 系列名,例如 镧系 */
  series: string = "";
  seriesIndex: number = 0;

  constructor(period: number, group: number, range: string, series: string, seriesIndex: number) {
    this.period = period;
    this.group = group;
    this.range = range;
    this.series = series;
    this.seriesIndex = seriesIndex;
  }
}

/** f 区的一个系列(镧系或锕系)及其 15 个元素 */
export class SeriesInfo {
  label: string = "";
  /** 原子序数区间,例如 57～71 */
  range: string = "";
  index: number = 0;
  elements: ChemicalElement[] = [];
}

/**
 * 标准长式周期表的网格模型。
 *
 * 这里只做一件事:把「118 个元素各有周期、族、区」这件事摆成教材上那张表的样子 ——
 * 18 族 × 7 周期,顶端族号 1–18,左侧周期号 1–7,镧系与锕系另起两行排在主表下方。
 * 元素的周期、族、区本来就在数据里(见 PeriodicTable),所以这里不重新录任何数据,
 * 只是把它们摆到该在的位置上。
 *
 * 一处容易踩的坑:f 区元素在数据里族号统一记 3(镧系 57–71 全是第 6 周期第 3 族,
 * 锕系 89–103 全是第 7 周期第 3 族),所以写格子表时必须把 block 为 f 的排除掉。
 * 不排除的后果不是「一格塞进 15 个元素」—— 它们都落进同一格,后写的覆盖先写的,
 * 渲染层又被标记格挡住,看上去没差别;坏的是格子查询层:`cellAt(6, 3)` 会返回
 * 一个 f 区元素,查第 6 周期第 3 族就查错了。所以这条排除由 check.mjs 的
 * 「格子查询层」一组断言钉住,不是靠渲染层看着对就算对。
 */
export class PeriodicGrid {
  static readonly GROUPS: number = 18;
  static readonly PERIODS: number = 7;
  static readonly SERIES_LABELS: string[] = ["镧系", "锕系"];
  static readonly SERIES_RANGES: string[] = ["57～71", "89～103"];
  /** 两个系列各自所属的周期 */
  static readonly SERIES_PERIODS: number[] = [6, 7];
  /** f 区行从第 3 族的位置起,与主表的标记格对齐 */
  static readonly SERIES_INSET: number = 2;

  private static elementCache: ChemicalElement[] = [];
  private static slotCache: number[] = [];
  private static rowCache: GridRow[] = [];
  private static seriesCache: SeriesInfo[] = [];

  private static ensureElements(): void {
    if (PeriodicGrid.elementCache.length > 0) {
      return;
    }
    const els = PeriodicTable.all();
    for (let i = 0; i < els.length; i++) {
      PeriodicGrid.elementCache.push(els[i]);
    }
  }

  /**
   * 主表每个格子放哪个元素。
   *
   * 下标是 (周期 - 1) * 18 + (族 - 1),值是原子序数;0 表示这一格没有元素。
   * f 区元素不写进来 —— 它们在表下方那两行。
   */
  private static ensureSlots(): void {
    if (PeriodicGrid.slotCache.length > 0) {
      return;
    }
    PeriodicGrid.ensureElements();
    const slots: number[] = [];
    for (let i = 0; i < PeriodicGrid.GROUPS * PeriodicGrid.PERIODS; i++) {
      slots.push(0);
    }
    const els = PeriodicGrid.elementCache;
    for (let i = 0; i < els.length; i++) {
      const el = els[i];
      if (el.block === "f") {
        continue;
      }
      if (el.period < 1 || el.period > PeriodicGrid.PERIODS) {
        continue;
      }
      if (el.group < 1 || el.group > PeriodicGrid.GROUPS) {
        continue;
      }
      slots[(el.period - 1) * PeriodicGrid.GROUPS + (el.group - 1)] = el.number;
    }
    PeriodicGrid.slotCache = slots;
  }

  /** 按原子序数取元素;序数非法或没有这个元素返回 null */
  static byNumber(n: number): ChemicalElement | null {
    if (n < 1) {
      return null;
    }
    PeriodicGrid.ensureElements();
    const els = PeriodicGrid.elementCache;
    for (let i = 0; i < els.length; i++) {
      if (els[i].number === n) {
        return els[i];
      }
    }
    return null;
  }

  /** 主表某一格是哪个元素;空位返回 null */
  static cellAt(period: number, group: number): ChemicalElement | null {
    if (period < 1 || period > PeriodicGrid.PERIODS || group < 1 || group > PeriodicGrid.GROUPS) {
      return null;
    }
    PeriodicGrid.ensureSlots();
    const num = PeriodicGrid.slotCache[(period - 1) * PeriodicGrid.GROUPS + (group - 1)];
    if (num <= 0) {
      return null;
    }
    return PeriodicGrid.byNumber(num);
  }

  /** 主表某一格是不是标记格;不是返回 null */
  static markerAt(period: number, group: number): PeriodicMarker | null {
    if (group !== 3) {
      return null;
    }
    if (period === PeriodicGrid.SERIES_PERIODS[0]) {
      return new PeriodicMarker(period, group, PeriodicGrid.SERIES_RANGES[0],
        PeriodicGrid.SERIES_LABELS[0], 0);
    }
    if (period === PeriodicGrid.SERIES_PERIODS[1]) {
      return new PeriodicMarker(period, group, PeriodicGrid.SERIES_RANGES[1],
        PeriodicGrid.SERIES_LABELS[1], 1);
    }
    return null;
  }

  /** 两个 f 区系列及其元素 */
  static series(): SeriesInfo[] {
    if (PeriodicGrid.seriesCache.length > 0) {
      return PeriodicGrid.seriesCache;
    }
    PeriodicGrid.ensureElements();
    const out: SeriesInfo[] = [];
    for (let s = 0; s < PeriodicGrid.SERIES_LABELS.length; s++) {
      const info = new SeriesInfo();
      info.label = PeriodicGrid.SERIES_LABELS[s];
      info.range = PeriodicGrid.SERIES_RANGES[s];
      info.index = s;
      const period = PeriodicGrid.SERIES_PERIODS[s];
      const els = PeriodicGrid.elementCache;
      for (let i = 0; i < els.length; i++) {
        if (els[i].period === period && els[i].block === "f") {
          info.elements.push(els[i]);
        }
      }
      out.push(info);
    }
    PeriodicGrid.seriesCache = out;
    return out;
  }

  /**
   * 元素的中文名,拿不准能不能显示时返回空串。
   *
   * 两种情况返回空:一是这个名字压根没录(104 号元素的空名),二是名字里有非 BMP 的字 ——
   * 105 号往后有一批元素名在 CJK 扩展区,字体缺这些字时会显示成方框,比不显示更糟。
   * 判据看高代理项(0xD800–0xDBFF):有高代理项就说明用了扩展区的字。
   */
  static safeName(el: ChemicalElement): string {
    if (el.name.length === 0) {
      return "";
    }
    for (let i = 0; i < el.name.length; i++) {
      const code = el.name.charCodeAt(i);
      if (code >= 0xD800 && code <= 0xDBFF) {
        return "";
      }
    }
    return el.name;
  }

  /** 顶端那一行:18 个族号 */
  private static headerRow(): GridRow {
    const row = new GridRow();
    row.kind = "header";
    row.key = "row-header";
    row.label = "族号";
    for (let g = 1; g <= PeriodicGrid.GROUPS; g++) {
      const cell = new GridCell();
      cell.kind = "group";
      cell.key = "h-" + g;
      cell.top = String(g);
      row.cells.push(cell);
    }
    return row;
  }

  /** 一个周期行:有元素放元素,有标记放标记,其余是空位 */
  private static periodRow(period: number): GridRow {
    const row = new GridRow();
    row.kind = "period";
    row.key = "row-period-" + period;
    row.label = String(period);
    for (let g = 1; g <= PeriodicGrid.GROUPS; g++) {
      const cell = new GridCell();
      cell.key = "p" + period + "-" + g;
      const marker = PeriodicGrid.markerAt(period, g);
      if (marker !== null) {
        cell.kind = "marker";
        cell.top = marker.range;
        cell.bottom = marker.series;
        cell.seriesIndex = marker.seriesIndex;
        row.cells.push(cell);
        continue;
      }
      const el = PeriodicGrid.cellAt(period, g);
      if (el === null) {
        cell.kind = "empty";
        row.cells.push(cell);
        continue;
      }
      cell.kind = "element";
      cell.top = String(el.number);
      cell.bottom = el.symbol;
      cell.atomicNumber = el.number;
      row.cells.push(cell);
    }
    return row;
  }

  /** 表下方的一个 f 区行:前面空两格,15 个元素,末尾空一格,凑满 18 列 */
  private static seriesRow(index: number): GridRow {
    const row = new GridRow();
    row.kind = "series";
    row.key = "row-series-" + index;
    row.seriesIndex = index;
    const list = PeriodicGrid.series()[index];
    row.label = list.label;
    for (let i = 0; i < PeriodicGrid.SERIES_INSET; i++) {
      const blank = new GridCell();
      blank.kind = "empty";
      blank.key = "s" + index + "-blank-" + i;
      row.cells.push(blank);
    }
    for (let i = 0; i < list.elements.length; i++) {
      const el = list.elements[i];
      const cell = new GridCell();
      cell.kind = "element";
      cell.key = "s" + index + "-" + el.number;
      cell.top = String(el.number);
      cell.bottom = el.symbol;
      cell.atomicNumber = el.number;
      row.cells.push(cell);
    }
    const tail = new GridCell();
    tail.kind = "empty";
    tail.key = "s" + index + "-tail";
    row.cells.push(tail);
    return row;
  }

  /**
   * 整张表:表头 + 7 个周期行 + 2 个 f 区行。
   *
   * 返回的是同一份缓存:表是死的,每次重算只是把 180 个格子重新 new 一遍,没有意义。
   */
  static rows(): GridRow[] {
    if (PeriodicGrid.rowCache.length > 0) {
      return PeriodicGrid.rowCache;
    }
    const out: GridRow[] = [];
    out.push(PeriodicGrid.headerRow());
    for (let p = 1; p <= PeriodicGrid.PERIODS; p++) {
      out.push(PeriodicGrid.periodRow(p));
    }
    for (let s = 0; s < PeriodicGrid.SERIES_LABELS.length; s++) {
      out.push(PeriodicGrid.seriesRow(s));
    }
    PeriodicGrid.rowCache = out;
    return out;
  }
}
