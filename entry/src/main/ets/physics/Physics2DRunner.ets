import { ExperimentMeta } from '../model/ExperimentTypes';
import { IExperimentRunner } from '../runner/IExperimentRunner';
import { WorldSnapshot } from './World2D';

/**
 * 2D 仿真实验的公共基类:参数表、仿真时间、场景图取数口。
 * 子类只需实现 step(如何演化)与 snapshot(画成什么)。
 */
export abstract class Physics2DRunner implements IExperimentRunner {
  protected params: Map<string, number> = new Map();
  protected meta: ExperimentMeta = new ExperimentMeta();
  protected time: number = 0;

  setup(meta: ExperimentMeta): void {
    this.meta = meta;
    this.params.clear();
    for (let i = 0; i < meta.params.length; i++) {
      this.params.set(meta.params[i].key, meta.params[i].defaultValue);
    }
    this.time = 0;
    this.onSetup();
  }

  reset(): void {
    this.time = 0;
    this.onSetup();
  }

  setParam(key: string, value: number): void {
    this.params.set(key, value);
    this.onParamChanged(key, value);
  }

  getParam(key: string): number {
    const hit = this.params.get(key);
    return hit === undefined ? 0 : hit;
  }

  elapsedTime(): number {
    return this.time;
  }

  finished(): boolean {
    return false;
  }

  dispose(): void {
    this.params.clear();
  }

  abstract step(dt: number): void;

  abstract readObservable(key: string): number;

  abstract snapshot(): WorldSnapshot;

  /** 回到初始构型。参数已就位,子类在此重置状态量 */
  protected onSetup(): void {
  }

  /** 参数中途被改变时的补偿逻辑,如实时改质量要保留当前动量 */
  protected onParamChanged(key: string, value: number): void {
  }
}
