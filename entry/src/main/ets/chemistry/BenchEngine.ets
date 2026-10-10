import { Phase, ReactionSpec, ReactionText } from './ChemistryModel';
import { Reagents } from './ChemistryLibrary';
import { BenchEvent, BenchView, Content, Contents, Palette, PORTION_MOLES, Vessel } from './BenchModel';

/** 可逆反应的转化率。酯化在演示条件下远达不到完全转化,取一个教学演示值。 */
const REVERSIBLE_CONVERSION: number = 0.65;
const EPSILON: number = 1e-12;

/**
 * 实验台引擎:给定「容器里现在有什么 + 有没有加热」,推出该发生哪个反应、
 * 谁不足、生成多少、什么跑掉了。
 *
 * 反应不从界面写死,而是拿整张已校验的反应表去匹配 —— 这样学生把随便两种
 * 药品倒在一起,得到的是真实后果(不反应、或生成预期外的东西),
 * 而不是「本实验不支持该操作」的提示。
 */
export class BenchEngine {
  /**
   * 反复匹配直到不再有新反应发生(上一步的产物可能继续参与下一步)。
   * 每轮只推进一次反应,避免可逆与竞争反应时结果依赖表的顺序。
   */
  static react(vessel: Vessel, reactions: ReactionSpec[]): BenchEvent[] {
    const events: BenchEvent[] = [];
    let guard = 0;
    while (guard < 8) {
      guard++;
      let progressed = false;
      for (let i = 0; i < reactions.length; i++) {
        const spec = reactions[i];
        const blocked = BenchEngine.blockReason(vessel, spec);
        if (blocked.length > 0) {
          continue;
        }
        events.push(BenchEngine.run(vessel, spec));
        progressed = true;
      }
      if (!progressed) {
        break;
      }
    }
    return events;
  }

  /** 为什么这条反应此刻不发生。返回空串表示可以进行。 */
  static blockReason(vessel: Vessel, spec: ReactionSpec): string {
    if (spec.needsHeat && !vessel.heated) {
      return '需要加热';
    }
    if (spec.needsPower && !vessel.powered) {
      return '需要通电';
    }
    for (let i = 0; i < spec.catalystKeys.length; i++) {
      if (Contents.find(vessel.contents, spec.catalystKeys[i]) === null) {
        return '缺少催化剂';
      }
    }
    for (let i = 0; i < spec.reactants.length; i++) {
      const term = spec.reactants[i];
      if (Contents.find(vessel.contents, term.substance.key) === null) {
        return '缺少反应物';
      }
    }
    return '';
  }

  /** 只报告「差什么条件」,用于界面提示「加热后才能发生」。 */
  static pendingHints(vessel: Vessel, reactions: ReactionSpec[]): string[] {
    const hints: string[] = [];
    for (let i = 0; i < reactions.length; i++) {
      const spec = reactions[i];
      if (!BenchEngine.hasAllReactants(vessel, spec)) {
        continue;
      }
      const reason = BenchEngine.blockReason(vessel, spec);
      if (reason.length > 0) {
        hints.push(spec.title + ' —— ' + reason + '后才发生');
      }
    }
    return hints;
  }

  private static hasAllReactants(vessel: Vessel, spec: ReactionSpec): boolean {
    for (let i = 0; i < spec.reactants.length; i++) {
      if (Contents.find(vessel.contents, spec.reactants[i].substance.key) === null) {
        return false;
      }
    }
    return true;
  }

  private static run(vessel: Vessel, spec: ReactionSpec): BenchEvent {
    let extent = Number.POSITIVE_INFINITY;
    for (let i = 0; i < spec.reactants.length; i++) {
      const term = spec.reactants[i];
      const hit = Contents.find(vessel.contents, term.substance.key);
      const available = hit === null ? 0 : hit.moles;
      const ratio = available / term.coefficient;
      if (ratio < extent) {
        extent = ratio;
      }
    }
    if (spec.reversible) {
      extent *= REVERSIBLE_CONVERSION;
    }

    for (let i = 0; i < spec.reactants.length; i++) {
      const term = spec.reactants[i];
      Contents.take(vessel.contents, term.substance.key, extent * term.coefficient);
    }

    const event = new BenchEvent();
    event.reactionId = spec.id;
    event.title = spec.title;
    // 方程式随事件一起出:学生在实验台看到的每一条反应,都应带着它配平后的式子
    event.equation = ReactionText.equation(spec);
    if (spec.ionic !== null) {
      event.ionicEquation = ReactionText.equation(spec.ionic);
    }
    event.phenomena = spec.phenomena;
    for (let i = 0; i < spec.products.length; i++) {
      const term = spec.products[i];
      const moles = extent * term.coefficient;
      if (moles <= EPSILON) {
        continue;
      }
      if (term.marker === '↑') {
        // 敞口容器里气体跑掉:容器质量随之减小,这正是「反应前后称量」考点的真实来源
        Contents.add(vessel.escaped, term.substance.key, moles);
        event.gases.push(term.substance.name);
        continue;
      }
      Contents.add(vessel.contents, term.substance.key, moles);
      if (term.marker === '↓') {
        event.precipitates.push(term.substance.color + term.substance.name);
      }
    }
    return event;
  }

  /** 往容器里加药品。返回 false 表示超过容量,不应记入。 */
  static add(vessel: Vessel, key: string, moles: number): boolean {
    if (BenchEngine.portionsOf(vessel) + moles / PORTION_MOLES > vessel.capacity) {
      return false;
    }
    Contents.add(vessel.contents, key, moles);
    return true;
  }

  /** 把 from 的全部内容并入 to(倾倒/混合)。 */
  static pourInto(to: Vessel, from: Vessel): boolean {
    let needed = 0;
    for (let i = 0; i < from.contents.length; i++) {
      needed += from.contents[i].moles / PORTION_MOLES;
    }
    if (BenchEngine.portionsOf(to) + needed > to.capacity) {
      return false;
    }
    for (let i = 0; i < from.contents.length; i++) {
      Contents.add(to.contents, from.contents[i].key, from.contents[i].moles);
    }
    for (let i = 0; i < from.escaped.length; i++) {
      Contents.add(to.escaped, from.escaped[i].key, from.escaped[i].moles);
    }
    from.contents = [];
    return true;
  }

  static portionsOf(vessel: Vessel): number {
    let sum = 0;
    for (let i = 0; i < vessel.contents.length; i++) {
      sum += vessel.contents[i].moles / PORTION_MOLES;
    }
    return sum;
  }

  /** 容器内现存质量(不含已逸出的气体) */
  static massIn(vessel: Vessel): number {
    return Contents.totalMass(vessel.contents);
  }

  static massEscaped(vessel: Vessel): number {
    return Contents.totalMass(vessel.escaped);
  }

  /** 器底破损漏走的质量。与逸出分开:一个是反应的结果,一个是操作失误的结果 */
  static massLeaked(vessel: Vessel): number {
    return Contents.totalMass(vessel.leaked);
  }

  /** 绘制所需的可视状态。bubbling 由调用方按最近一次事件决定。 */
  static viewOf(vessel: Vessel, bubbling: boolean): BenchView {
    const view = new BenchView();
    view.bubbling = bubbling;
    view.portions = BenchEngine.portionsOf(vessel);

    // 液体颜色只看进入溶液的试剂:不溶的固体沉在底部,不给液体上色
    let dominant: Content | null = null;
    for (let i = 0; i < vessel.contents.length; i++) {
      const item = vessel.contents[i];
      const substance = Reagents.get(item.key);
      if (substance.phase !== Phase.AQUEOUS && substance.phase !== Phase.LIQUID) {
        continue;
      }
      if (dominant === null || item.moles > dominant.moles) {
        dominant = item;
      }
    }
    if (dominant !== null) {
      view.liquidColor = Palette.of(Reagents.get(dominant.key));
    }
    for (let i = 0; i < vessel.contents.length; i++) {
      const substance = Reagents.get(vessel.contents[i].key);
      if (!substance.soluble) {
        view.solids.push(substance.color + '固体');
      }
    }
    return view;
  }

  /** 反应物名称列表,供「已装入」提示。 */
  static describe(vessel: Vessel): string {
    const parts: string[] = [];
    for (let i = 0; i < vessel.contents.length; i++) {
      const item = vessel.contents[i];
      parts.push(item.moles.toFixed(3) + ' mol ' + Reagents.get(item.key).name);
    }
    return parts.join('、');
  }

  static substanceName(key: string): string {
    return Reagents.get(key).name;
  }
}
