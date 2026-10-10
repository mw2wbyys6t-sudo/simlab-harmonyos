/**
 * 实验场景的静态描述。所有外壳页面(实验库、运行页、报告页)只依赖这些类型,
 * 不感知具体实验的物理/化学语义 —— 新增实验不应要求改动外壳。
 */

/** 学科域。 */
export enum Subject {
  PHYSICS_MECHANICS = 'physical_mechanics',
  PHYSICS_ELECTRICAL = 'physical_electrical',
  CHEMISTRY = 'chemistry',
  BIOLOGY = 'biology',
  GEOGRAPHY = 'geography',
  MATH_VISUAL = 'math_visual',
  INSTRUMENT = 'instrument'
}

/** 渲染器族别:决定运行页用哪种 Runner 承载。 */
export enum RendererKind {
  /** 2D 矢量 + 自研定步长求解器,参数需实时响应 */
  PHYSICS_2D = 'physics_2d',
  /** 步骤规则状态机:器材搭建、操作顺序、安全规范校验 */
  STEP_RULES = 'step_rules',
  /** 资源播放器:显微图像/解剖结构 + 可交互标注热区 */
  MEDIA = 'media'
}

/** 参数控件形式。开关类参数用滑杆会既不直观又容易停在半值。 */
export enum ParamControl {
  SLIDER = 'slider',
  SWITCH = 'switch'
}

/** 可调参数。运行页据此自动渲染滑块/开关,无需为每个实验写控件。 */
export class ParamDef {
  key: string = ''
  label: string = ''
  /** 空串表示无量纲 */
  unit: string = ''
  min: number = 0
  max: number = 1
  step: number = 0.01
  defaultValue: number = 0
  /** 参数面板内的分组标题,如「器材」「条件」 */
  group: string = '参数'
  control: ParamControl = ParamControl.SLIDER
}

/** 实时观测量。运行页读数区与报告页数据表共用。 */
export class ObservableDef {
  key: string = ''
  label: string = ''
  unit: string = ''
  /** 显示保留位数 */
  precision: number = 3
  /** 是否随时间连续采样,生成 x-t 图 */
  sampled: boolean = false
}

/** 图线中的一条曲线。同一张图里的曲线必须共用纵轴单位。 */
export class ChartSeries {
  /** 取自 ExperimentMeta.observables 的键,须标为 sampled */
  observableKey: string = ''
  label: string = ''
  color: string = '#2F6FB5'
}

/**
 * 一张图。横轴既可以是时间('t'),也可以是另一个观测量 ——
 * 后者让 x-t 图与 U-I 图共用同一套绘制代码。
 */
export class ChartDef {
  title: string = ''
  /** 't' 表示用采样时间轴 */
  xKey: string = 't'
  xLabel: string = 't'
  xUnit: string = 's'
  yLabel: string = ''
  yUnit: string = ''
  /** 量程是否强制包含原点。伏安特性图需要它才能看出「过原点」 */
  includeOrigin: boolean = true
  series: ChartSeries[] = []
}

/** 实验任务/思考题,进入报告页的作答项。 */
export class TaskDef {
  key: string = ''
  prompt: string = ''
  /** 期望值:学生结论与观测数据比对的判据,NaN 表示纯开放题 */
  expected: number = Number.NaN
  tolerance: number = 0
}

/** 一个实验的完整元数据 + 交互契约。 */
export class ExperimentMeta {
  id: string = ''
  title: string = ''
  subject: Subject = Subject.PHYSICS_MECHANICS
  renderer: RendererKind = RendererKind.PHYSICS_2D
  summary: string = ''
  /** 课标/教材定位,供实验库筛选 */
  gradeBand: string = ''
  /** 预计课堂用时(分钟),0 表示不限 */
  durationMinutes: number = 0
  params: ParamDef[] = []
  observables: ObservableDef[] = []
  charts: ChartDef[] = []
  tasks: TaskDef[] = []
  /** 世界边界与视口(米),2D 渲染器据此做世界坐标到画布坐标的映射 */
  worldWidth: number = 10
  worldHeight: number = 6
}
