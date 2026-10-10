/** 元件类型。直流电路一期只需这些。 */
export enum ComponentKind {
  RESISTOR = 'resistor',
  RHEOSTAT = 'rheostat',
  LAMP = 'lamp',
  SOURCE = 'source',
  SWITCH = 'switch',
  AMMETER = 'ammeter',
  VOLTMETER = 'voltmeter'
}

/** 电流表内阻:不是 0,否则与理想电压源成环时系数矩阵奇异。1e-4 Ω 对教学读数无影响。 */
export const AMMETER_R: number = 1e-4;
/** 电压表内阻:不是无穷大,理由同上。1e7 Ω 分流可忽略。 */
export const VOLTMETER_R: number = 1e7;
/** 闭合开关的接触电阻 */
const SWITCH_CLOSED_R: number = 1e-4;
/** 断开开关的等效绝缘电阻 */
const SWITCH_OPEN_R: number = 1e9;

export class Component {
  id: string = '';
  kind: ComponentKind = ComponentKind.RESISTOR;
  /** 面板与图上显示的代号,如 R₁ */
  label: string = '';
  /** A 端为正极/电流流入端(对电源而言 A 是 + 极) */
  nodeA: number = 0;
  nodeB: number = 0;
  /** 电阻值(Ω)或电动势(V);开关用 1 表示闭合 */
  value: number = 0;
  /** 关联 ExperimentMeta 里的可调参数键,空串表示固定值 */
  paramKey: string = '';
  /** 世界坐标下的两个接线端 */
  ax: number = 0;
  ay: number = 0;
  bx: number = 0;
  by: number = 0;
  /**
   * 符号相对两端中点的偏移。跨接式电压表用得上:接线端留在主导线上,
   * 表本身画到旁边,引线折过去,避免与同一处的电阻符号重叠。
   */
  offsetX: number = 0;
  offsetY: number = 0;

  /** 求解用的等效电阻;-1 表示按电压源处理。value 由调用方给出(可调参数已代入) */
  resistance(value: number): number {
    switch (this.kind) {
      case ComponentKind.RESISTOR:
      case ComponentKind.RHEOSTAT:
      case ComponentKind.LAMP:
        return value;
      case ComponentKind.AMMETER:
        return AMMETER_R;
      case ComponentKind.VOLTMETER:
        return VOLTMETER_R;
      case ComponentKind.SWITCH:
        return value >= 0.5 ? SWITCH_CLOSED_R : SWITCH_OPEN_R;
      default:
        return -1;
    }
  }
}

/** 仅用于绘图的导线折线,不参与拓扑(拓扑已由节点编号表达)。 */
export class WirePath {
  xs: number[] = [];
  ys: number[] = [];

  point(x: number, y: number): WirePath {
    this.xs.push(x);
    this.ys.push(y);
    return this;
  }
}

/**
 * 一道电路 = 节点数 + 参考地点 + 元件表 + 连线形状。
 * 一期由代码手写拓扑,参数(阻值、电动势、开关)走数据通道实时可调。
 */
export class CircuitSpec {
  nodeCount: number = 1;
  ground: number = 0;
  components: Component[] = [];
  wires: WirePath[] = [];

  add(kind: ComponentKind, id: string, label: string, nodeA: number, nodeB: number,
    value: number, paramKey: string): Component {
    const item = new Component();
    item.kind = kind;
    item.id = id;
    item.label = label;
    item.nodeA = nodeA;
    item.nodeB = nodeB;
    item.value = value;
    item.paramKey = paramKey;
    if (nodeA >= this.nodeCount) {
      this.nodeCount = nodeA + 1;
    }
    if (nodeB >= this.nodeCount) {
      this.nodeCount = nodeB + 1;
    }
    this.components.push(item);
    return item;
  }

  wire(path: WirePath): void {
    this.wires.push(path);
  }

  find(id: string): Component | null {
    for (let i = 0; i < this.components.length; i++) {
      if (this.components[i].id === id) {
        return this.components[i];
      }
    }
    return null;
  }
}
