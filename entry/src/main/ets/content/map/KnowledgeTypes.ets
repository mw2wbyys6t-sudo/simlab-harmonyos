import { MapSubject, SchoolStage, UNVERIFIED_PREFIX } from './CurriculumTypes';

/**
 * 知识层的数据模型。
 *
 * 2026-10-08 改了当天早先的粒度决定:原本「知识点只当实验的标签、不建独立表」,
 * 现在按用户的要求把知识先补全 —— 知识要能脱离实验单独成体系,就必须是一张独立的表。
 *
 * 一条知识点就是一个能被单独提问、单独判对错的最小单元:
 * 「绳的张力处处相等」算一条,「牛顿第二定律」算一条,「F=ma 的矢量性与瞬时性」是它的下级。
 * 章(chapter)用来分组,不做层级树 —— 三级已经够定位,再多一层就没人维护。
 *
 * **与实验表的关系要说清楚:目前没有互查。** 实测 224 条实验的 910 个 `knowledge` 标签里,
 * 只有 1 个能精确对上某条知识点的标题;放宽到子串匹配也只覆盖 149/817 个去重标签,
 * 且带假阳性(「波长」能命中 7 条)。所以两边是**各自成体系的两张表**,
 * 浏览页也不提供「知识点 → 实验」的跳转 —— 那条能力要等按 `kn-` 编号显式建链之后才有。
 */

/** 认知层次。借布卢姆的分法,但只留能一眼判得出来的三档 */
export enum KnowledgeLevel {
  /** 知道有这回事、能说出名词与单位 */
  RECALL = 'recall',
  /** 会套用:给条件能算、能判断方向与正负 */
  APPLY = 'apply',
  /** 会迁移:换情境、组合多个知识点才能解决 */
  TRANSFER = 'transfer'
}

export class KnowledgePoint {
  /** 形如 kn-phy-u-013:前缀 kn 与实验条目的 id 分开,免得两张表撞号 */
  id: string = '';
  subject: MapSubject = MapSubject.PHYSICS;
  stage: SchoolStage = SchoolStage.UNIVERSITY;
  /** 课程名,如「力学」「电磁学」「无机及分析化学」 */
  course: string = '';
  /** 章名,如「牛顿运动定律」「溶液的依数性」 */
  chapter: string = '';
  title: string = '';
  /** 一到两句话说清这条知识本身,不写「本节介绍……」这类空话 */
  statement: string = '';
  /** 常用符号、单位或量纲。没有就留空数组 */
  symbols: string[] = [];
  level: KnowledgeLevel = KnowledgeLevel.RECALL;
  /** 前置知识点的 id。空数组表示它是这一章的起点 */
  prerequisites: string[] = [];
  source: string = '';
  verified: boolean = false;
}

export function makeKnowledge(id: string, subject: MapSubject, stage: SchoolStage,
  course: string, chapter: string, title: string, statement: string, symbols: string[],
  level: KnowledgeLevel, prerequisites: string[], source: string): KnowledgePoint {
  const k = new KnowledgePoint();
  k.id = id;
  k.subject = subject;
  k.stage = stage;
  k.course = course;
  k.chapter = chapter;
  k.title = title;
  k.statement = statement;
  k.symbols = symbols;
  k.level = level;
  k.prerequisites = prerequisites;
  k.source = source;
  k.verified = source.length > 0 && source.indexOf(UNVERIFIED_PREFIX) !== 0;
  return k;
}

/** 未核实前缀直接复用实验那一份,两张表对「什么叫做过证」必须是同一个意思 */
export const KN_UNVERIFIED: string = UNVERIFIED_PREFIX;
