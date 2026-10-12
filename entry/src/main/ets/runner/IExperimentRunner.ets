import { ExperimentMeta } from '../model/ExperimentTypes';
import { FactSheet } from '../model/FactSheet';

/**
 * 渲染器契约。实现者只负责「世界如何随时间演化」与「当前观测量是多少」,
 * 不接触 ArkUI 类型 —— 时间推进由 RunController 统一驱动,绘制在各自的 View 组件里。
 * 这样求解器可以被 LocalUnit 测试直接实例化验证。
 */
export interface IExperimentRunner {
  /** 载入场景并初始化到 t=0 的静止状态 */
  setup(meta: ExperimentMeta): void;

  /** 推进一个固定步长。实现必须是纯函数式的步进:同样的参数序列得到同样的结果 */
  step(dt: number): void;

  /** 回到 setup 之后的初始状态,保留用户已调的参数 */
  reset(): void;

  /** 用户调节参数。实现需在下一 step 生效,不得要求重启实验 */
  setParam(key: string, value: number): void;

  /**
   * 学生按下一个动作按钮(加砝码、记读数)。
   *
   * 这是判定层唯一的「学生做过什么」入口:动作必须改变世界并留下时刻与后果,
   * 而不是只弹一条提示。未知的 key 应被忽略而不是抛出。
   */
  doAction(key: string): void;

  /**
   * 把本次操作产生的事实写进给定清单(只放数值与时刻,不放意图)。
   * 判定层拿不到事实时一律放过,所以宁可少写也不要编。
   */
  collectFacts(sheet: FactSheet): void;

  getParam(key: string): number;

  /** 读取观测量当前值,键来自 ExperimentMeta.observables */
  readObservable(key: string): number;

  /** 仿真已推进的时间(秒),不是墙钟时间 */
  elapsedTime(): number;

  /**
   * 实验是否已到达自然终点(滑块到底、反应完成、流程走完)。
   * 为 true 时 RunController 会自动停表,避免画面静止但仍在计时的误导。
   */
  finished(): boolean;

  dispose(): void;
}

/** 按 id 创建 runner 的构造函数。注册表用它把场景包与实现解绑。 */
export type RunnerFactory = () => IExperimentRunner;
