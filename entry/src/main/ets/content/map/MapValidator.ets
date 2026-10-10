import { ExperimentEntry, MapSubject, SchoolStage, UNVERIFIED_PREFIX } from './CurriculumTypes';
import { KnowledgeLevel, KnowledgePoint } from './KnowledgeTypes';

/** 一条校验问题:落在哪个条目、哪个字段、为什么 */
export class MapProblem {
  entryId: string = '';
  field: string = '';
  message: string = '';
}

/**
 * 课程地图的校验器。
 *
 * 存在的理由和 RubricValidator 一样:这类错误靠肉眼看数据表看不出来,
 * 而一旦带着它们进浏览页,学生看到的就是错的分分类。
 *
 * 刻意做成「每个条目每条规则各报一次」而不是「报第一个问题就走」:
 * 数据是手写的,一次看全比挤牙膏省时间。但每条规则之间不互相掩盖 ——
 * 出处为空时不再重复报 verified(那种情况下推导值本来就一致)。
 */
export class MapValidator {
  private static readonly SUBJECT_CODES: string[] = ['phy', 'chem', 'bio', 'ele'];
  private static readonly STAGE_CODES: string[] = ['u', 'jr', 'sr'];
  private static readonly FEASIBILITIES: string[] = ['runnable', 'needs_scene', 'needs_model',
    'needs_renderer', 'needs_real_gears'];
  private static readonly LEVELS: string[] = ['recall', 'apply', 'transfer'];

  private static problem(entries: MapProblem[], id: string, field: string,
    message: string): void {
    const p = new MapProblem();
    p.entryId = id;
    p.field = field;
    p.message = message;
    entries.push(p);
  }

  private static subjectCode(subject: MapSubject): string {
    if (subject === MapSubject.CHEMISTRY) {
      return 'chem';
    }
    if (subject === MapSubject.BIOLOGY) {
      return 'bio';
    }
    if (subject === MapSubject.ELECTRONICS) {
      return 'ele';
    }
    return 'phy';
  }

  private static stageCode(stage: SchoolStage): string {
    if (stage === SchoolStage.JUNIOR) {
      return 'jr';
    }
    if (stage === SchoolStage.SENIOR) {
      return 'sr';
    }
    return 'u';
  }

  /** id 必须是 <学科码>-<学段码>-<三位序号>;序号故意不许缺位,免得出现 phy-u-1 与 phy-u-01 并存 */
  private static idWellFormed(id: string): boolean {
    const parts: string[] = id.split('-');
    if (parts.length !== 3) {
      return false;
    }
    if (MapValidator.SUBJECT_CODES.indexOf(parts[0]) < 0) {
      return false;
    }
    if (MapValidator.STAGE_CODES.indexOf(parts[1]) < 0) {
      return false;
    }
    const digits = parts[2];
    if (digits.length !== 3) {
      return false;
    }
    for (let i = 0; i < 3; i++) {
      if (digits.charAt(i) < '0' || digits.charAt(i) > '9') {
        return false;
      }
    }
    return true;
  }

  static validate(entries: ExperimentEntry[]): MapProblem[] {
    const out: MapProblem[] = [];
    const seen: string[] = [];
    for (let i = 0; i < entries.length; i++) {
      const e = entries[i];
      const id = e.id;
      if (!MapValidator.idWellFormed(id)) {
        MapValidator.problem(out, id, 'id', `id 不合 <学科>-<学段>-<三位序号> 式:${id}`);
      } else if (seen.indexOf(id) >= 0) {
        MapValidator.problem(out, id, 'id', 'id 重复:同一张地图里必须唯一(它同时是删除与定位的键)');
      } else {
        seen.push(id);
      }
      if (e.title.length === 0) {
        MapValidator.problem(out, id, 'title', '标题为空');
      }
      if (e.course.length === 0) {
        MapValidator.problem(out, id, 'course', '课程名为空');
      }
      if (e.term.length === 0) {
        MapValidator.problem(out, id, 'term', '学期或册次为空,这条进不了分组');
      }
      if (e.source.length === 0) {
        MapValidator.problem(out, id, 'source', '出处为空:没有出处的条目也要写明「未核实:」而不是留白');
      }
      if (e.apparatus.length === 0) {
        MapValidator.problem(out, id, 'apparatus', '器材为空');
      }
      if (e.knowledge.length === 0) {
        MapValidator.problem(out, id, 'knowledge', '知识点标签为空:知识点当标签是这张地图的设计前提');
      }
      if (e.minutes < 0) {
        MapValidator.problem(out, id, 'minutes', `课时为负:${e.minutes}`);
      }
      if (MapValidator.SUBJECT_CODES.indexOf(id.split('-')[0]) >= 0 &&
        MapValidator.subjectCode(e.subject) !== id.split('-')[0]) {
        MapValidator.problem(out, id, 'subject',
          `id 的学科码 ${id.split('-')[0]} 与 subject ${e.subject} 不一致`);
      }
      if (MapValidator.STAGE_CODES.indexOf(id.split('-')[1]) >= 0 &&
        MapValidator.stageCode(e.stage) !== id.split('-')[1]) {
        MapValidator.problem(out, id, 'stage',
          `id 的学段码 ${id.split('-')[1]} 与 stage ${e.stage} 不一致`);
      }
      if (MapValidator.FEASIBILITIES.indexOf(e.feasibility) < 0) {
        MapValidator.problem(out, id, 'feasibility', `可行性取值非法:${e.feasibility}`);
      }
      // verified 必须由 source 前缀推出。两个方向都要查:手写 true 会虚报可信度,
      // 手写 false 会把已核实的东西埋掉。
      const expected = e.source.length > 0 && e.source.indexOf(UNVERIFIED_PREFIX) !== 0;
      if (e.source.length > 0 && e.verified !== expected) {
        MapValidator.problem(out, id, 'verified',
          `verified 必须由 source 推出(应为 ${expected.toString()})`);
      }
    }
    return out;
  }

  /**
   * 知识表校验。除实验表那套规则外,多一条只有机器查得出来的:
   * **前置必须指向真实存在的知识点**。人写引用时最容易写出 kn-phy-u-013 这种看着对、其实不存在的号,
   * 而浏览页顺着前置链跳转时才会暴露 —— 那时已经晚了。
   */
  static validateKnowledge(points: KnowledgePoint[]): MapProblem[] {
    const out: MapProblem[] = [];
    const seen: string[] = [];
    for (let i = 0; i < points.length; i++) {
      const e = points[i];
      const id = e.id;
      const parts: string[] = id.split('-');
      const wellFormed = parts.length === 4 && parts[0] === 'kn' &&
        MapValidator.SUBJECT_CODES.indexOf(parts[1]) >= 0 &&
        MapValidator.STAGE_CODES.indexOf(parts[2]) >= 0 &&
        MapValidator.isThreeDigits(parts[3]);
      if (!wellFormed) {
        MapValidator.problem(out, id, 'id', `id 不合 kn-<学科>-<学段>-<三位序号> 式:${id}`);
      } else if (seen.indexOf(id) >= 0) {
        MapValidator.problem(out, id, 'id', 'id 重复');
      } else {
        seen.push(id);
      }
      if (e.course.length === 0) {
        MapValidator.problem(out, id, 'course', '课程名为空');
      }
      if (e.chapter.length === 0) {
        MapValidator.problem(out, id, 'chapter', '章名为空,这条进不了分组');
      }
      if (e.title.length === 0) {
        MapValidator.problem(out, id, 'title', '标题为空');
      }
      if (e.statement.length === 0) {
        MapValidator.problem(out, id, 'statement', '知识内容为空');
      }
      if (e.source.length === 0) {
        MapValidator.problem(out, id, 'source', '出处为空');
      }
      if (MapValidator.LEVELS.indexOf(e.level) < 0) {
        MapValidator.problem(out, id, 'level', `认知层次取值非法:${e.level}`);
      }
      const expected = e.source.length > 0 && e.source.indexOf(UNVERIFIED_PREFIX) !== 0;
      if (e.source.length > 0 && e.verified !== expected) {
        MapValidator.problem(out, id, 'verified', 'verified 必须由 source 推出');
      }
    }
    // 第二遍:引用完整性。第一遍建好 id 全集才能查悬挂引用
    for (let i = 0; i < points.length; i++) {
      const e = points[i];
      for (let j = 0; j < e.prerequisites.length; j++) {
        if (seen.indexOf(e.prerequisites[j]) < 0) {
          MapValidator.problem(out, e.id, 'prerequisites',
            `前置 ${e.prerequisites[j]} 在表中不存在`);
        }
      }
    }
    return out;
  }

  private static isThreeDigits(s: string): boolean {
    if (s.length !== 3) {
      return false;
    }
    for (let i = 0; i < 3; i++) {
      if (s.charAt(i) < '0' || s.charAt(i) > '9') {
        return false;
      }
    }
    return true;
  }

  /** 学段先后。用来判「前置不许来自更晚的学段」这条规则 */
  private static stageRank(stage: SchoolStage): number {
    if (stage === SchoolStage.JUNIOR) {
      return 0;
    }
    if (stage === SchoolStage.SENIOR) {
      return 1;
    }
    return 2;
  }

  /**
   * 全集校验 —— 必须把**所有学科所有学段**并在一起才查得出来的三条。
   *
   * `validateKnowledge` 只能看见传给它的那一批,所以「高中引用初中的号」会被它误报成悬挂,
   * 而跨文件的重复 id 它根本看不见。这一遍才是真话。
   *
   * 第三条是逻辑规则而不是数据规则:**一条知识点的先修,学段不许比它自己更晚。**
   * 人写这种引用时是完全顺手的 —— 高中简谐振动那条,拿大学 `kn-phy-u-023` 当先修看着更"一般"。
   * 但那是给一个还没学微积分的学生开的方子。浏览页不会报,只有顺着先修链往下走的学生会撞上。
   */
  static validateKnowledgeUniverse(points: KnowledgePoint[]): MapProblem[] {
    const out: MapProblem[] = [];
    const ids: string[] = [];
    const ranks: number[] = [];
    for (let i = 0; i < points.length; i++) {
      if (ids.indexOf(points[i].id) >= 0) {
        MapValidator.problem(out, points[i].id, 'id', 'id 在跨文件层面重复');
      } else {
        ids.push(points[i].id);
        ranks.push(MapValidator.stageRank(points[i].stage));
      }
    }
    for (let i = 0; i < points.length; i++) {
      const e = points[i];
      const own = MapValidator.stageRank(e.stage);
      for (let j = 0; j < e.prerequisites.length; j++) {
        const at = ids.indexOf(e.prerequisites[j]);
        if (at < 0) {
          MapValidator.problem(out, e.id, 'prerequisites',
            `前置 ${e.prerequisites[j]} 在全集里不存在`);
        } else if (ranks[at] > own) {
          MapValidator.problem(out, e.id, 'prerequisites',
            `前置 ${e.prerequisites[j]} 的学段比本条更晚`);
        }
      }
    }
    return out;
  }
}
