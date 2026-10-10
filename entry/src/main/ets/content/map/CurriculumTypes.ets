/**
 * 课程地图的数据模型。
 *
 * 这张地图回答的是「这门课要做什么实验、需要什么器材、现在这个应用能不能做」,
 * 它不是仿真本身:每一条都只是施工清单上的一个节点。所以这里刻意不放任何运行期
 * 状态,全部是编译期常量 —— 与 ChemistryLibrary 同源的做法:数据进类型系统,
 * 校验进离线断言,而不是丢进 rawfile 等运行时才炸。
 *
 * 出处规则(硬约束,由 MapValidator 把关):
 * `source` 不许为空;确实没有可核查来源的条目,必须以 `UNVERIFIED_PREFIX` 开头,
 * 于是 `verified` 为假 —— 检索到的事实与凭印象写的东西,在数据里就必须是分得开的两件事。
 */

/** 地图的四个学科轴。与 Subject(渲染/判分用的分类)不是一回事,故另起一名 */
export enum MapSubject {
  PHYSICS = 'physics',
  CHEMISTRY = 'chemistry',
  BIOLOGY = 'biology',
  ELECTRONICS = 'electronics'
}

/** 学段。地图里「按年级排」的第一级分组 */
export enum SchoolStage {
  JUNIOR = 'junior',
  SENIOR = 'senior',
  UNIVERSITY = 'university'
}

/**
 * 当前引擎能不能做这件事。这四档的区别不是工作量,而是**做法不同**:
 * 前两档是「补模型」,第三档要先补渲染器,第四档根本不该做成仿真。
 *
 * `RUNNABLE` 是这里唯一会被应用对外显示成一个数字的档位("现在能打开 N 个"),
 * 所以它的定义必须能被机器核对:一条只能算 RUNNABLE 的条目,得在 `Index.ets` 的 routeMap
 * 或 `ExperimentRegistry` 里指到一个真点得开的实验。2026-10-08 就因为这条没钉住,
 * 电子那 8 条按"求解器够用"被标成可打开,而应用里其实只有串并联两个电路场景。
 * "求解器与渲染器都够用、缺的是一条场景和它的细则"是另一种活,记 `NEEDS_SCENE`。
 */
export enum Feasibility {
  /** 应用里已经真的有一个点得开的实验(场景 + 细则 + 渲染都在) */
  RUNNABLE = 'runnable',
  /** 模型与渲染器都够,缺的是一条新场景 + 它的细则:改数据不改引擎 */
  NEEDS_SCENE = 'needs_scene',
  /** 现有回转体/2D 求解器/电路求解器不够用,缺的是物理或化学模型 */
  NEEDS_MODEL = 'needs_model',
  /** 需要新的画法:波动与干涉、光谱、三维结构、显微视野 */
  NEEDS_RENDERER = 'needs_renderer',
  /** 依赖真实仪器的手感、调节步骤或实物观察 —— 做成仿真就是假实验 */
  NEEDS_REAL_GEARS = 'needs_real_gears'
}

/** 没有可核查来源时,source 必须以此开头(MapValidator 据此判 verified) */
export const UNVERIFIED_PREFIX: string = '未核实:';

/** 一条实验。id 在整张地图内唯一,删除或合并过的 id 不复用 */
export class ExperimentEntry {
  id: string = '';
  title: string = '';
  subject: MapSubject = MapSubject.PHYSICS;
  stage: SchoolStage = SchoolStage.UNIVERSITY;
  /** 课程名,如「大学物理实验(一)」「无机及分析化学实验」 */
  course: string = '';
  /** 排课位置:大学用「大一上」这类学期,中学用「八年级下」「必修二」这类册次 */
  term: string = '';
  /** 建议课时(分钟)。0 = 该来源未给出 */
  minutes: number = 0;
  /** 所需器材/试剂/试件 */
  apparatus: string[] = [];
  /** 一句话说清这个实验在测什么、怎么测 */
  principle: string = '';
  /** 数据处理与误差要求:大学实验真正的教学目的多在这一栏 */
  dataHandling: string = '';
  /** 知识点标签。地图不单独建知识点表,知识点从这些标签里汇总出来 */
  knowledge: string[] = [];
  feasibility: Feasibility = Feasibility.NEEDS_MODEL;
  source: string = '';
  /** 由 source 推出来,不是手写:免得出现「出处是未核实但 verified=true」这种自相矛盾 */
  verified: boolean = false;
}

/** 构造一条记录。位置参数而不是对象字面量,是为了让每一行数据在文件里只占一行 */
export function makeEntry(id: string, subject: MapSubject, stage: SchoolStage, course: string,
  term: string, minutes: number, title: string, apparatus: string[], principle: string,
  dataHandling: string, knowledge: string[], feasibility: Feasibility, source: string): ExperimentEntry {
  const e = new ExperimentEntry();
  e.id = id;
  e.subject = subject;
  e.stage = stage;
  e.course = course;
  e.term = term;
  e.minutes = minutes;
  e.title = title;
  e.apparatus = apparatus;
  e.principle = principle;
  e.dataHandling = dataHandling;
  e.knowledge = knowledge;
  e.feasibility = feasibility;
  e.source = source;
  e.verified = source.length > 0 && source.indexOf(UNVERIFIED_PREFIX) !== 0;
  return e;
}
