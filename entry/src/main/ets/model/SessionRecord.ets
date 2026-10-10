import { Subject } from './ExperimentTypes';

/** 一条事实。用数组而不是 Map 存:Map 过 JSON 会变成空对象,读数会静默清零。 */
export class FactEntry {
  key: string = '';
  value: number = 0;
}

/** 一个时刻事件:发生在仿真第几秒。同样存数组,理由与 FactEntry 一致。 */
export class MomentEntry {
  event: string = '';
  atSeconds: number = 0;
}

/**
 * 一次已完成操作的记录。
 *
 * 它是"复盘"这条主张的载体:学生做完一次量取或一次提纯,当时的数字必须留得下来,
 * 否则关掉应用就等于什么都没发生,报告页也只能永远跑规范示例。
 */
export class SessionRecord {
  /** 由操作方给出的稳定 id;空串视为非法,账本会拒绝 */
  id: string = '';
  experimentId: string = '';
  title: string = '';
  subject: Subject = Subject.PHYSICS_MECHANICS;
  /** 结束时刻的毫秒时间戳。0 表示未知,不猜 */
  endedAtMs: number = 0;
  durationSec: number = 0;
  /** 未评分时三个 rubric 字段留空,awarded 留 NaN */
  rubricId: string = '';
  rubricVersion: string = '';
  rubricSource: string = '';
  total: number = 0;
  /** NaN 表示这次没有评分。序列化必须把它原样带回来,不能变成 0 */
  awarded: number = Number.NaN;
  deductionTitles: string[] = [];
  facts: FactEntry[] = [];
  /** 分步时刻。判据可以不用它,但「步骤回放」段要用,不落盘就等于那条验收标准没闭合 */
  moments: MomentEntry[] = [];
}

export function fact(key: string, value: number): FactEntry {
  const entry = new FactEntry();
  entry.key = key;
  entry.value = value;
  return entry;
}

export function moment(event: string, atSeconds: number): MomentEntry {
  const entry = new MomentEntry();
  entry.event = event;
  entry.atSeconds = atSeconds;
  return entry;
}
