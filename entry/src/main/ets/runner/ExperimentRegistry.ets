import { ExperimentMeta } from '../model/ExperimentTypes';
import { IExperimentRunner, RunnerFactory } from './IExperimentRunner';

/** 一条注册项:元数据 + 创建对应 runner 的工厂。 */
export class ExperimentEntry {
  meta: ExperimentMeta = new ExperimentMeta();
  factory: RunnerFactory = (): IExperimentRunner => {
    throw new Error('runner factory not registered');
  };
}

/**
 * 实验注册表。外壳只通过它拿到元数据与 runner,不知道任何具体实验的实现细节。
 *
 * 分工边界(重要):元数据、参数、观测量、任务项都是**数据**,外壳据此自动渲染控件;
 * 而「世界如何演化」的求解器仍是**代码**,按 id 注册。上不上完整的场景 DSL 是后续决策,
 * 当前这样切分已保证:调参、加读数、改任务、改文案都不需要碰外壳。
 */
export class ExperimentRegistry {
  private static entries: Map<string, ExperimentEntry> = new Map();

  static register(meta: ExperimentMeta, factory: RunnerFactory): void {
    const entry = new ExperimentEntry();
    entry.meta = meta;
    entry.factory = factory;
    ExperimentRegistry.entries.set(meta.id, entry);
  }

  static all(): ExperimentMeta[] {
    const list: ExperimentMeta[] = [];
    ExperimentRegistry.entries.forEach((entry: ExperimentEntry) => {
      list.push(entry.meta);
    });
    return list;
  }

  static find(id: string): ExperimentEntry | null {
    const hit = ExperimentRegistry.entries.get(id);
    return hit === undefined ? null : hit;
  }

  /** 每次调用得到一个全新实例,退出实验即丢弃 */
  static createRunner(id: string): IExperimentRunner | null {
    const entry = ExperimentRegistry.find(id);
    return entry === null ? null : entry.factory();
  }
}
