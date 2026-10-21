import { DeviceClass, Layout } from "../common/Layout";
import { Theme } from "../common/Theme";
import { GridCell, GridRow, PeriodicGrid } from "../content/map/PeriodicGrid";

/**
 * 标准长式周期表的表格视图。
 *
 * 18 列硬塞进手机屏宽只有十几 vp 一列,那种表看得见形状点不中 —— 所以手机档不缩表,
 * 整表横向滚动,一格一格都是 44vp 的触控目标(见 Layout.periodicCellSize)。
 *
 * 格子之间留 1vp 是发丝分隔线,不是间距,所以它不上 SPACE 阶梯。
 */
@Component
export struct PeriodicTableView {
  @Prop hostWidth: number = 0;
  /** 选中的元素原子序数;-1 表示没选 */
  @Prop selectedNumber: number = -1;
  /** 选中的系列下标(0 镧系 / 1 锕系);-1 表示没选 */
  @Prop selectedSeries: number = -1;
  onPick: (n: number) => void = () => {
  };
  onPickSeries: (index: number) => void = () => {
  };

  /** 发丝分隔线宽 */
  private readonly line: number = 1;

  private cls(): DeviceClass {
    return Layout.classify(this.hostWidth);
  }

  private cell(): number {
    return Layout.periodicCellSize(this.cls());
  }

  private gutter(): number {
    return Layout.periodicGutter(this.cls());
  }

  /** 一行有多高:表头行矮一档,其余每行都是一排正方格 */
  private rowHeight(row: GridRow): number {
    if (row.kind === "header") {
      return Layout.periodicHeaderHeight(this.cls());
    }
    return this.cell();
  }

  /** 表高:表头 + 9 行格子 + 行间发丝线 */
  private tableHeight(): number {
    return Layout.periodicHeaderHeight(this.cls()) + 9 * this.cell() + 9 * this.line;
  }

  /** 表宽:左侧周期号那一栏 + 18 列 + 列间发丝线 */
  private tableWidth(): number {
    return this.gutter() + PeriodicGrid.GROUPS * this.cell() + PeriodicGrid.GROUPS * this.line;
  }

  /** 左侧那一栏:族号表头写「族号」,周期行写周期号,f 区行写系列名 */
  @Builder
  gutterCell(row: GridRow) {
    Column() {
      Text(row.label)
        .fontSize(Layout.microSize(this.cls()))
        .fontColor(Theme.TEXT_SECONDARY)
        .maxLines(1)
    }
    .width(this.gutter())
    .height(this.rowHeight(row))
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  /** 一格。四种格子:族号表头、元素格、标记格、空位 */
  @Builder
  cellView(cell: GridCell) {
    if (cell.kind === "group") {
      Column() {
        Text(cell.top)
          .fontSize(Layout.microSize(this.cls()))
          .fontColor(Theme.TEXT_SECONDARY)
      }
      .width(this.cell())
      .height(Layout.periodicHeaderHeight(this.cls()))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else if (cell.kind === "element") {
      this.elementCell(cell)
    } else if (cell.kind === "marker") {
      this.markerCell(cell)
    } else {
      // 空位:只占住位置,让 18 列对齐。教材上这些位置本来也是空的,不画比画个空框好
      Column() {
      }
      .width(this.cell())
      .height(this.cell())
    }
  }

  /** 元素格:上行原子序数,下行元素符号 */
  @Builder
  elementCell(cell: GridCell) {
    Column({ space: 0 }) {
      Text(cell.top)
        .fontSize(Layout.microSize(this.cls()))
        .fontColor(this.selectedNumber === cell.atomicNumber ? Theme.ON_BRAND : Theme.TEXT_SECONDARY)
      Text(cell.bottom)
        .fontSize(Layout.periodicSymbolSize(this.cls()))
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selectedNumber === cell.atomicNumber ? Theme.ON_BRAND : Theme.TEXT_PRIMARY)
    }
    .width(this.cell())
    .height(this.cell())
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.selectedNumber === cell.atomicNumber ? Theme.SUBJECT_CHEMISTRY : Theme.BG_CARD)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .onClick(() => {
      this.onPick(cell.atomicNumber);
    })
  }

  /** 标记格:主表里写着「57～71」的那一格,点它看整个系列 */
  @Builder
  markerCell(cell: GridCell) {
    Column({ space: 0 }) {
      Text(cell.top)
        .fontSize(Layout.microSize(this.cls()))
        .fontColor(this.selectedSeries === cell.seriesIndex ? Theme.ON_BRAND : Theme.SUBJECT_CHEMISTRY)
      Text(cell.bottom)
        .fontSize(Layout.captionSize(this.cls()))
        .fontColor(this.selectedSeries === cell.seriesIndex ? Theme.ON_BRAND : Theme.SUBJECT_CHEMISTRY)
    }
    .width(this.cell())
    .height(this.cell())
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.selectedSeries === cell.seriesIndex ? Theme.SUBJECT_CHEMISTRY : Theme.BAND_BG)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .onClick(() => {
      this.onPickSeries(cell.seriesIndex);
    })
  }

  /** 一行:左侧那一栏 + 18 个格子 */
  @Builder
  rowView(row: GridRow) {
    Row({ space: this.line }) {
      this.gutterCell(row)
      ForEach(row.cells, (cell: GridCell) => {
        this.cellView(cell)
      }, (cell: GridCell): string => cell.key)
    }
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Scroll() {
      Column({ space: this.line }) {
        ForEach(PeriodicGrid.rows(), (row: GridRow) => {
          this.rowView(row)
        }, (row: GridRow): string => row.key)
      }
      .width(this.tableWidth())
      .backgroundColor(Theme.BG_PAGE)
    }
    // 横向滚动:18 列在手机屏宽里放不下,缩格又会让格子小于触控下限
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Auto)
    .width("100%")
    .height(this.tableHeight())
  }
}
