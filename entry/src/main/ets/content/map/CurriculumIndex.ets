import { ExperimentEntry, Feasibility, MapSubject, SchoolStage } from './CurriculumTypes';
import { ChemicalElement, PeriodicTable } from './PeriodicTable';
import { KnowledgePoint } from './KnowledgeTypes';
import { KnowledgePhysics } from './KnowledgePhysics';
import { KnowledgePhysicsJunior } from './KnowledgePhysicsJunior';
import { KnowledgePhysicsSenior } from './KnowledgePhysicsSenior';
import { KnowledgeChemistry } from './KnowledgeChemistry';
import { KnowledgeChemistryJunior } from './KnowledgeChemistryJunior';
import { KnowledgeChemistrySenior } from './KnowledgeChemistrySenior';
import { KnowledgeBiology } from './KnowledgeBiology';
import { KnowledgeBiologyJunior } from './KnowledgeBiologyJunior';
import { KnowledgeBiologySenior } from './KnowledgeBiologySenior';
import { KnowledgeElectronicsJunior } from './KnowledgeElectronicsJunior';
import { KnowledgeElectronicsSenior } from './KnowledgeElectronicsSenior';
import { KnowledgeElectronics } from './KnowledgeElectronics';
import { UniversityPhysics } from './UniversityPhysics';
import { SchoolPhysics } from './SchoolPhysics';
import { UniversityChemistry } from './UniversityChemistry';
import { SchoolChemistry } from './SchoolChemistry';
import { UniversityBiology } from './UniversityBiology';
import { SchoolBiology } from './SchoolBiology';
import { UniversityElectronics } from './UniversityElectronics';

/**
 * 课程地图的唯一取用口。
 *
 * 页面只许从这里取,不许自己拼四张表 —— 一旦页面各读各的,分类计数就会和逐条统计分家,
 * 而那种不一致正是这张地图存在的理由(它要回答"还剩什么没做")。
 * 所以本类的存在本身就带一条断言:各分组之和必须等于总数。
 */
export class CurriculumIndex {
  static experiments(): ExperimentEntry[] {
    return SchoolPhysics.all().concat(UniversityPhysics.all())
      .concat(SchoolChemistry.all()).concat(UniversityChemistry.all())
      .concat(UniversityBiology.all()).concat(SchoolBiology.all())
      .concat(UniversityElectronics.all());
  }

  static knowledge(): KnowledgePoint[] {
    return KnowledgePhysicsJunior.all().concat(KnowledgePhysicsSenior.all())
      .concat(KnowledgePhysics.all()).concat(KnowledgeChemistryJunior.all())
      .concat(KnowledgeChemistrySenior.all()).concat(KnowledgeChemistry.all())
      .concat(KnowledgeBiologyJunior.all()).concat(KnowledgeBiologySenior.all())
      .concat(KnowledgeBiology.all()).concat(KnowledgeElectronicsJunior.all())
      .concat(KnowledgeElectronicsSenior.all()).concat(KnowledgeElectronics.all());
  }

  static elements(): ChemicalElement[] {
    return PeriodicTable.all();
  }

  /** 地图上的四个学科轴,顺序即浏览页的呈现顺序 */
  static subjects(): MapSubject[] {
    return [MapSubject.PHYSICS, MapSubject.CHEMISTRY, MapSubject.BIOLOGY, MapSubject.ELECTRONICS];
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

  static experimentsOf(subject: MapSubject): ExperimentEntry[] {
    return CurriculumIndex.experiments().filter(
      (e: ExperimentEntry): boolean => e.subject === subject);
  }

  static knowledgeOf(subject: MapSubject): KnowledgePoint[] {
    return CurriculumIndex.knowledge().filter(
      (k: KnowledgePoint): boolean => k.subject === subject);
  }

  /** 学段的呈现顺序:初中 → 高中 → 大学 */
  static readonly STAGE_ORDER: SchoolStage[] = [SchoolStage.JUNIOR, SchoolStage.SENIOR,
    SchoolStage.UNIVERSITY];

  static knowledgeOfStage(subject: MapSubject, stage: SchoolStage): KnowledgePoint[] {
    return CurriculumIndex.knowledgeOf(subject).filter(
      (k: KnowledgePoint): boolean => k.stage === stage);
  }

  static experimentsOfStage(subject: MapSubject, stage: SchoolStage): ExperimentEntry[] {
    return CurriculumIndex.experimentsOf(subject).filter(
      (e: ExperimentEntry): boolean => e.stage === stage);
  }

  /**
   * 某学科**实际有数据**的学段。
   *
   * 浏览页用它决定要不要摆出学段这一排:物理现在有三个学段,化学/生物/电子只有大学一个,
   * 把一排只有一个选项的筛选器摆在学生面前是噪声。
   * 这一条也是"哪个学段哪一科还空着"的直接读法 —— 地图的作用就是说清还剩什么没做。
   */
  static stagesOf(subject: MapSubject): SchoolStage[] {
    const out: SchoolStage[] = [];
    for (let i = 0; i < CurriculumIndex.STAGE_ORDER.length; i++) {
      const stage = CurriculumIndex.STAGE_ORDER[i];
      if (CurriculumIndex.experimentsOfStage(subject, stage).length > 0 ||
        CurriculumIndex.knowledgeOfStage(subject, stage).length > 0) {
        out.push(stage);
      }
    }
    return out;
  }

  /** 学段的中文名,浏览页与校验报告共用一份口径 */
  static stageName(stage: SchoolStage): string {
    if (stage === SchoolStage.JUNIOR) {
      return '初中';
    }
    if (stage === SchoolStage.SENIOR) {
      return '高中';
    }
    return '大学';
  }

  /** 某学科下的课程名,按首次出现顺序去重(浏览页的二级分组) */
  static coursesOf(subject: MapSubject): string[] {
    const out: string[] = [];
    const rows = CurriculumIndex.experimentsOf(subject);
    for (let i = 0; i < rows.length; i++) {
      if (out.indexOf(rows[i].course) < 0) {
        out.push(rows[i].course);
      }
    }
    return out;
  }

  /** 一门课下的全部实验(浏览页的三级列表) */
  static experimentsInCourse(course: string): ExperimentEntry[] {
    return CurriculumIndex.experiments().filter((e: ExperimentEntry): boolean => e.course === course);
  }

  /** 一门课相关的知识点:按 course 精确匹配,再按学科兜底(知识表的课程名与实验表不必相同) */
  static knowledgeInCourse(course: string): KnowledgePoint[] {
    return CurriculumIndex.knowledge().filter((k: KnowledgePoint): boolean => k.course === course);
  }

  static knowledgeOfSubject(subject: MapSubject): KnowledgePoint[] {
    return CurriculumIndex.knowledgeOf(subject);
  }

  static countByFeasibility(rows: ExperimentEntry[], feasibility: Feasibility): number {
    let n = 0;
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].feasibility === feasibility) {
        n++;
      }
    }
    return n;
  }

  /** 现在就能做的实验:浏览页顶栏那句"其中 N 个已经能打开" */
  static runnableExperiments(): ExperimentEntry[] {
    return CurriculumIndex.experiments().filter(
      (e: ExperimentEntry): boolean => e.feasibility === Feasibility.RUNNABLE);
  }

  static findExperiment(id: string): ExperimentEntry | null {
    const rows = CurriculumIndex.experiments();
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].id === id) {
        return rows[i];
      }
    }
    return null;
  }

  static findKnowledge(id: string): KnowledgePoint | null {
    const rows = CurriculumIndex.knowledge();
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].id === id) {
        return rows[i];
      }
    }
    return null;
  }

  /** 元素周期表按周期分组(浏览页的周期表视图) */
  static elementsInPeriod(period: number): ChemicalElement[] {
    return CurriculumIndex.elements().filter((e: ChemicalElement): boolean => e.period === period);
  }

  /** 按原子序数取元素;越界返回 null,由界面决定显示什么 */
  static findElement(atomicNumber: number): ChemicalElement | null {
    const rows = CurriculumIndex.elements();
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].number === atomicNumber) {
        return rows[i];
      }
    }
    return null;
  }

  /** 学段码,供校验器比对 id 与 stage 是否一致 */
  static stageCode(stage: SchoolStage): string {
    if (stage === SchoolStage.JUNIOR) {
      return 'jr';
    }
    if (stage === SchoolStage.SENIOR) {
      return 'sr';
    }
    return 'u';
  }

  static subjectCodeOf(subject: MapSubject): string {
    return CurriculumIndex.subjectCode(subject);
  }
}
