import { ExperimentEntry, Feasibility, MapSubject, SchoolStage } from './CurriculumTypes';
import { MapValidator } from './MapValidator';

/**
 * 内容更新通道的编解码与覆盖表。
 *
 * 原来地图全部是编译期常量,理由写在 `CurriculumTypes` 的注释里:「数据进类型系统,
 * 校验进离线断言,而不是丢进 rawfile 等运行时才炸」。这个理由**没有被推翻** ——
 * 内置表仍是兜底,断言一条不减。这里加的是一条受同等约束的旁路:
 *
 * - 一份外部 JSON 可以覆盖某张表,但解码后必须过**同一个** `MapValidator`;
 * - 任何一行不合格就**整批拒绝**,不做"能读几行算几行"——半张地图比没地图更误导人;
 * - 空表不算合法内容,不许用一次坏更新把地图清空。
 *
 * 为什么 rawfile 本身不够:rawfile 打在 HAP 里,改它等于重新装机。真正"不重装"靠的是
 * 应用沙箱里的同名文件(见 `platform/ContentStore`),rawfile 只是随包发布的默认值。
 *
 * 编码刻意不写 `verified`:它是从 `source` 推出来的,写进文件就给了"出处是未核实却
 * verified=true"这种自相矛盾一个藏身处。
 */
const SUBJECTS: string[] = ['physics', 'chemistry', 'biology', 'electronics'];
const STAGES: string[] = ['junior', 'senior', 'university'];
const FEASIBILITIES: string[] = ['runnable', 'needs_scene', 'needs_model', 'needs_renderer',
  'needs_real_gears'];

export class ContentDecode {
  rows: ExperimentEntry[] = [];
  problems: string[] = [];
}

/** 文件里的一行。字段类型与 ExperimentEntry 一致,校验靠显式比对而不是信任它 */
class WireEntry {
  id: string = '';
  title: string = '';
  subject: string = '';
  stage: string = '';
  course: string = '';
  term: string = '';
  minutes: number = 0;
  apparatus: string[] = [];
  principle: string = '';
  dataHandling: string = '';
  knowledge: string[] = [];
  feasibility: string = '';
  source: string = '';
}

export class ContentCodec {
  private static quoted(value: string): string {
    return JSON.stringify(value);
  }

  /** 键序固定,所以"编→解→再编"必须逐字节相同 —— 少写一个字段当场就能被发现 */
  static encodeExperiments(rows: ExperimentEntry[]): string {
    const parts: string[] = [];
    for (const r of rows) {
      parts.push('{' + [
        '"id":' + ContentCodec.quoted(r.id),
        '"title":' + ContentCodec.quoted(r.title),
        '"subject":' + ContentCodec.quoted(String(r.subject)),
        '"stage":' + ContentCodec.quoted(String(r.stage)),
        '"course":' + ContentCodec.quoted(r.course),
        '"term":' + ContentCodec.quoted(r.term),
        '"minutes":' + String(r.minutes),
        '"apparatus":' + JSON.stringify(r.apparatus),
        '"principle":' + ContentCodec.quoted(r.principle),
        '"dataHandling":' + ContentCodec.quoted(r.dataHandling),
        '"knowledge":' + JSON.stringify(r.knowledge),
        '"feasibility":' + ContentCodec.quoted(String(r.feasibility)),
        '"source":' + ContentCodec.quoted(r.source)
      ].join(',') + '}');
    }
    return '[' + parts.join(',') + ']';
  }

  static decodeExperiments(json: string): ContentDecode {
    const out = new ContentDecode();
    let parsed: Object | undefined = undefined;
    try {
      parsed = JSON.parse(json);
    } catch (error) {
      out.problems.push('不是合法 JSON');
      return out;
    }
    if (!Array.isArray(parsed)) {
      out.problems.push('顶层不是数组');
      return out;
    }
    const list = parsed as WireEntry[];
    if (list.length === 0) {
      out.problems.push('空表:不许用一次更新把地图清空');
      return out;
    }

    const seen = new Map<string, number>();
    const rows: ExperimentEntry[] = [];
    for (let i = 0; i < list.length; i++) {
      const at = `第 ${i + 1} 行`;
      const w = list[i];
      const row = new ExperimentEntry();
      if (typeof w.id !== 'string' || w.id.length === 0) {
        out.problems.push(`${at} id 为空`);
        continue;
      }
      if (typeof w.title !== 'string' || w.title.length === 0) {
        out.problems.push(`${at}(${w.id})标题为空`);
        continue;
      }
      if (SUBJECTS.indexOf(String(w.subject)) < 0) {
        out.problems.push(`${at}(${w.id})学科「${String(w.subject)}」不是已知档位`);
        continue;
      }
      if (STAGES.indexOf(String(w.stage)) < 0) {
        out.problems.push(`${at}(${w.id})学段「${String(w.stage)}」不是已知档位`);
        continue;
      }
      if (FEASIBILITIES.indexOf(String(w.feasibility)) < 0) {
        out.problems.push(`${at}(${w.id})可行性「${String(w.feasibility)}」不是已知档位`);
        continue;
      }
      if (typeof w.source !== 'string' || w.source.length === 0) {
        out.problems.push(`${at}(${w.id})出处为空:没有可核查来源要写成「未核实:…」`);
        continue;
      }
      if (!(typeof w.minutes === 'number') || w.minutes < 0) {
        out.problems.push(`${at}(${w.id})课时不是非负数`);
        continue;
      }
      if (!Array.isArray(w.apparatus) || !Array.isArray(w.knowledge)) {
        out.problems.push(`${at}(${w.id})器材或知识点标签不是数组`);
        continue;
      }
      const hit = seen.get(w.id);
      if (hit !== undefined) {
        out.problems.push(`${at}(${w.id})id 与第 ${hit + 1} 行重复`);
        continue;
      }
      seen.set(w.id, i);

      row.id = w.id;
      row.title = w.title;
      row.subject = String(w.subject) as MapSubject;
      row.stage = String(w.stage) as SchoolStage;
      row.course = typeof w.course === 'string' ? w.course : '';
      row.term = typeof w.term === 'string' ? w.term : '';
      row.minutes = w.minutes;
      row.apparatus = w.apparatus;
      row.principle = typeof w.principle === 'string' ? w.principle : '';
      row.dataHandling = typeof w.dataHandling === 'string' ? w.dataHandling : '';
      row.knowledge = w.knowledge;
      row.feasibility = String(w.feasibility) as Feasibility;
      row.source = w.source;
      // verified 从 source 推导,和 makeEntry 同一套规矩
      row.verified = w.source.length > 0 && w.source.indexOf('未核实:') !== 0;
      rows.push(row);
    }

    if (out.problems.length > 0) {
      // 整批拒绝:半张地图比没地图更误导人
      out.rows = [];
      return out;
    }
    const invalid = MapValidator.validate(rows);
    for (const problem of invalid) {
      out.problems.push(`校验未过 ${problem.entryId}.${problem.field}:${problem.message}`);
    }
    if (out.problems.length > 0) {
      out.rows = [];
      return out;
    }
    out.rows = rows;
    return out;
  }
}

/**
 * 覆盖表:按表名存一份"当前生效的行"。
 *
 * 空数据一律拒绝,`apply` 因此永远拿得到一个可用的表 —— 更新失败的表现是"内容没变",
 * 而不是"地图空了"。
 */
export class ContentOverride {
  private static tables: Map<string, ExperimentEntry[]> = new Map();

  static set(key: string, rows: ExperimentEntry[]): boolean {
    if (rows.length === 0) {
      return false;
    }
    ContentOverride.tables.set(key, rows);
    return true;
  }

  static apply(key: string, builtIn: ExperimentEntry[]): ExperimentEntry[] {
    const hit = ContentOverride.tables.get(key);
    if (hit === undefined || hit.length === 0) {
      return builtIn;
    }
    return hit;
  }

  static active(key: string): boolean {
    const hit = ContentOverride.tables.get(key);
    return hit !== undefined && hit.length > 0;
  }

  static clear(key: string): void {
    ContentOverride.tables.delete(key);
  }
}
