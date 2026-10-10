import { Subject } from '../model/ExperimentTypes';
import { FactEntry, MomentEntry, SessionRecord } from '../model/SessionRecord';

/**
 * 落盘用的线格式。
 *
 * 两个刻意的选择:
 * - `awardedText` 用字符串而不是数字。`JSON.stringify(NaN)` 会写出 `null`,反序列化端
 *   一个 `Number(null)` 就把「未评分」变成「考了零分」,而这正是最难发现的那类错误。
 * - `subject` 用字符串。枚举过 JSON 之后拿不回类型。
 */
interface WireFact {
  key: string;
  value: number;
}

interface WireMoment {
  event: string;
  atSeconds: number;
}

interface WireRecord {
  id: string;
  experimentId: string;
  title: string;
  subject: string;
  endedAtMs: number;
  durationSec: number;
  rubricId: string;
  rubricVersion: string;
  rubricSource: string;
  total: number;
  awardedText: string;
  deductionTitles: string[];
  facts: WireFact[];
  moments: WireMoment[];
}

interface WireFile {
  version: number;
  records: WireRecord[];
}

/** 按自然日聚合的一组记录 */
export class LedgerDay {
  /** 本地日期键,形如 2026-9-26。同一天的记录一定落在同一个键下 */
  key: string = '';
  /** 面向学生的说法:今天 / 昨天 / 9月21日 / 2025年8月21日 */
  label: string = '';
  records: SessionRecord[] = [];
}

/**
 * 操作记录账本。纯逻辑,不 import 任何 @kit。
 *
 * 落盘由 platform/SessionStore 负责;排序、上限、统计、序列化、按日期分组这些真正会出错的部分
 * 全部留在这里,以便离线断言。
 */
export class SessionLedger {
  /** Preferences 是整串读写,无界增长最终会写不进去,所以保留最近若干条 */
  static readonly MAX_RECORDS: number = 50;
  private static readonly FILE_VERSION: number = 1;
  private static readonly DAY_MS: number = 86400000;

  private records: SessionRecord[] = [];

  /** 收下并返回是否被接受。缺 id 的记录一律拒收;重复 id 也拒收 */
  add(record: SessionRecord): boolean {
    if (record.id.length === 0) {
      return false;
    }
    // 报告页拿 id 当 ForEach 的键,也拿它当删除的目标。两条同 id 会让键冲突,
    // 还会让「删一条」变成删两条。
    for (const existing of this.records) {
      if (existing.id === record.id) {
        return false;
      }
    }
    const next: SessionRecord[] = [record];
    for (const existing of this.records) {
      next.push(existing);
    }
    // 稳定的降序排序:新加入的排在同时间戳记录之前
    next.sort((a: SessionRecord, b: SessionRecord): number => b.endedAtMs - a.endedAtMs);

    while (next.length > SessionLedger.MAX_RECORDS) {
      next.pop();
    }
    this.records = next;
    return true;
  }

  /** 删掉指定 id 的那一条,返回是否真的删了。删不存在的 id 不改变账本 */
  remove(id: string): boolean {
    if (id.length === 0) {
      return false;
    }
    const kept: SessionRecord[] = [];
    let removed: boolean = false;
    for (const record of this.records) {
      if (!removed && record.id === id) {
        removed = true;
        continue;
      }
      kept.push(record);
    }
    if (removed) {
      this.records = kept;
    }
    return removed;
  }

  size(): number {
    return this.records.length;
  }

  /** 新的在前。返回副本:调用方会把结果交给 @State,不能和内部数组是同一个引用 */
  all(): SessionRecord[] {
    return this.records.slice();
  }

  byExperiment(experimentId: string): SessionRecord[] {
    return this.records.filter((record: SessionRecord) => record.experimentId === experimentId);
  }

  attempts(experimentId: string): number {
    return this.byExperiment(experimentId).length;
  }

  /**
   * 已评分记录里的最高分。
   *
   * 一条都没有时返回 NaN 而不是 0 —— 0 会被读成「做过且零分」,那是两件不同的事。
   */
  bestAwarded(experimentId: string): number {
    let best: number = Number.NaN;
    for (const record of this.byExperiment(experimentId)) {
      if (!Number.isNaN(record.awarded)) {
        if (Number.isNaN(best) || record.awarded > best) {
          best = record.awarded;
        }
      }
    }
    return best;
  }

  /**
   * 按自然日分组,新的日期在前。
   *
   * `nowMs` 由调用方给出而不是内部读表:「今天」「昨天」是相对当下的说法,
   * 把当下藏进函数里就没法离线断言它,也没法复现某一次的分组结果。
   */
  groupByDay(nowMs: number): LedgerDay[] {
    const days: LedgerDay[] = [];
    let currentKey: string = '';
    for (const record of this.records) {
      const key = SessionLedger.dayKey(record.endedAtMs);
      if (key !== currentKey) {
        const day = new LedgerDay();
        day.key = key;
        day.label = SessionLedger.dayLabel(record.endedAtMs, nowMs);
        days.push(day);
        currentKey = key;
      }
      days[days.length - 1].records.push(record);
    }
    return days;
  }

  /** 本地日界。用 UTC 切会让深夜的操作归到第二天,而学生关心的是「我昨天做的那次」 */
  private static dayKey(atMs: number): string {
    const d = new Date(atMs);
    return String(d.getFullYear()) + '-' + String(d.getMonth() + 1) + '-' + String(d.getDate());
  }

  private static dayLabel(atMs: number, nowMs: number): string {
    const offset = Math.round((SessionLedger.midnightOf(nowMs) - SessionLedger.midnightOf(atMs))
      / SessionLedger.DAY_MS);
    if (offset === 0) {
      return '今天';
    }
    if (offset === 1) {
      return '昨天';
    }
    const d = new Date(atMs);
    const monthDay = String(d.getMonth() + 1) + '月' + String(d.getDate()) + '日';
    if (d.getFullYear() === new Date(nowMs).getFullYear()) {
      return monthDay;
    }
    return String(d.getFullYear()) + '年' + monthDay;
  }

  /** 该时刻所在自然日的本地零点。日界换算交给 Date,这里只做差值 */
  private static midnightOf(atMs: number): number {
    const d = new Date(atMs);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  }

  toJson(): string {
    const wire: WireRecord[] = [];
    for (const record of this.records) {
      wire.push(SessionLedger.toWire(record));
    }
    const file: WireFile = {
      version: SessionLedger.FILE_VERSION,
      records: wire
    };
    return JSON.stringify(file);
  }

  /** 非法或损坏的输入返回空账本而不是抛出:启动时读到脏数据不该让应用起不来 */
  static fromJson(json: string): SessionLedger {
    const ledger = new SessionLedger();
    if (json.trim().length === 0) {
      return ledger;
    }
    let parsed: WireFile | null = null;
    try {
      parsed = JSON.parse(json) as WireFile;
    } catch (error) {
      return ledger;
    }
    if (parsed === null || parsed.records === undefined || parsed.records === null) {
      return ledger;
    }
    for (const wire of parsed.records) {
      const record = SessionLedger.fromWire(wire);
      ledger.add(record);
    }
    return ledger;
  }

  private static toWire(record: SessionRecord): WireRecord {
    const facts: WireFact[] = [];
    for (const item of record.facts) {
      facts.push({ key: item.key, value: item.value });
    }
    const moments: WireMoment[] = [];
    for (const item of record.moments) {
      moments.push({ event: item.event, atSeconds: item.atSeconds });
    }
    const wire: WireRecord = {
      id: record.id,
      experimentId: record.experimentId,
      title: record.title,
      subject: String(record.subject),
      endedAtMs: record.endedAtMs,
      durationSec: record.durationSec,
      rubricId: record.rubricId,
      rubricVersion: record.rubricVersion,
      rubricSource: record.rubricSource,
      total: record.total,
      awardedText: Number.isNaN(record.awarded) ? 'nan' : String(record.awarded),
      deductionTitles: record.deductionTitles.slice(),
      facts: facts,
      moments: moments
    };
    return wire;
  }

  /** 字段缺失或类型不对的记录被拒收,由 add 返回 false,调用方跳过 */
  private static fromWire(wire: WireRecord): SessionRecord {
    const record = new SessionRecord();
    if (wire === null || wire === undefined || wire.id === undefined) {
      return record;
    }
    record.id = wire.id;
    record.subject = SessionLedger.subjectOf(wire.subject);
    record.experimentId = SessionLedger.text(wire.experimentId);
    record.title = SessionLedger.text(wire.title);
    record.endedAtMs = SessionLedger.number(wire.endedAtMs);
    record.durationSec = SessionLedger.number(wire.durationSec);
    record.rubricId = SessionLedger.text(wire.rubricId);
    record.rubricVersion = SessionLedger.text(wire.rubricVersion);
    record.rubricSource = SessionLedger.text(wire.rubricSource);
    record.total = SessionLedger.number(wire.total);
    record.awarded = SessionLedger.awardedOf(wire.awardedText);
    record.deductionTitles = wire.deductionTitles === undefined ? [] : wire.deductionTitles.slice();
    const facts: FactEntry[] = [];
    if (wire.facts !== undefined) {
      for (const item of wire.facts) {
        const entry = new FactEntry();
        entry.key = SessionLedger.text(item.key);
        entry.value = SessionLedger.number(item.value);
        facts.push(entry);
      }
    }
    record.facts = facts;
    // 时刻是后加的字段:老 payload 里没有它,读成空数组而不是报错
    const moments: MomentEntry[] = [];
    if (wire.moments !== undefined) {
      for (const item of wire.moments) {
        const entry = new MomentEntry();
        entry.event = SessionLedger.text(item.event);
        entry.atSeconds = SessionLedger.number(item.atSeconds);
        moments.push(entry);
      }
    }
    record.moments = moments;
    return record;
  }

  private static text(value: string): string {
    return value === undefined || value === null ? '' : value;
  }

  /** 枚举过 JSON 只剩字符串。脏数据落回力学而不是抛:这条记录还有别的字段可看 */
  private static subjectOf(value: string): Subject {
    if (value === Subject.PHYSICS_ELECTRICAL) {
      return Subject.PHYSICS_ELECTRICAL;
    }
    if (value === Subject.CHEMISTRY) {
      return Subject.CHEMISTRY;
    }
    if (value === Subject.BIOLOGY) {
      return Subject.BIOLOGY;
    }
    if (value === Subject.GEOGRAPHY) {
      return Subject.GEOGRAPHY;
    }
    if (value === Subject.MATH_VISUAL) {
      return Subject.MATH_VISUAL;
    }
    if (value === Subject.INSTRUMENT) {
      return Subject.INSTRUMENT;
    }
    return Subject.PHYSICS_MECHANICS;
  }

  private static number(value: number): number {
    return typeof value === 'number' && Number.isFinite(value) ? value : 0;
  }

  private static awardedOf(value: string): number {
    if (value === undefined || value === null || value === 'nan') {
      return Number.NaN;
    }
    const parsed: number = Number.parseFloat(value);
    return Number.isNaN(parsed) ? Number.NaN : parsed;
  }
}
