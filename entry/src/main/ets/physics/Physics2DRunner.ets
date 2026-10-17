import { ExperimentMeta } from '../model/ExperimentTypes';
import { IExperimentRunner } from '../runner/IExperimentRunner';
import { FactSheet } from '../model/FactSheet';
import { WorldSnapshot } from './World2D';

/**
 * 2D 仿真实验的公共基类:参数表、仿真时间、场景图取数口。
 * 子类只需实现 step(如何演化)与 snapshot(画成什么)。
 */
export abstract class Physics2DRunner implements IExperimentRunner {
  protected params: Map<string, number> = new Map();
  protected meta: ExperimentMeta = new ExperimentMeta();
  protected time: number = 0;
  /**
   * 学生填过的答案;没填一律 NaN。dispose() 刻意不清这张表:答案随 runner 实例走,
   * 而 ExperimentPage 每次打开都新建 runner、退出即丢弃 —— 页面每次都是全新实例。
   * Task 7 若改成复用 runner,先回到这一行再决定要不要在 dispose() 里补一次 clear(Controller Ruling E)。
   */
  protected answers: Map<string, number> = new Map();

  setup(meta: ExperimentMeta): void {
    this.meta = meta;
    this.params.clear();
    for (let i = 0; i < meta.params.length; i++) {
      this.params.set(meta.params[i].key, meta.params[i].defaultValue);
    }
    this.time = 0;
    this.answers.clear();
    this.onSetup();
  }

  reset(): void {
    this.time = 0;
    this.answers.clear();
    this.onSetup();
  }

  setParam(key: string, value: number): void {
    this.params.set(key, value);
    // Controller Ruling D:改了施给世界的条件(计数起点/间隔这类滑杆决定应有值从哪几段算出),
    // 上一次交上来的结论就属于另一批数据,一并作废。不扩到 doAction —— 那由各场景在 Task 5/9 自行声明。
    this.answers.clear();
    this.onParamChanged(key, value);
  }

  getParam(key: string): number {
    const hit = this.params.get(key);
    return hit === undefined ? 0 : hit;
  }

  setAnswer(key: string, value: number): void {
    this.answers.set(key, value);
  }

  answer(key: string): number {
    const hit = this.answers.get(key);
    return hit === undefined ? Number.NaN : hit;
  }

  /**
   * 学生动作。默认实现转给 onAction;不认识这个 key 时什么都不做 ——
   * 外壳的按钮由元数据渲染,老实验没声明动作时不该因为多按一次而崩。
   */
  doAction(key: string): void {
    this.onAction(key);
  }

  collectFacts(sheet: FactSheet): void {
    this.onCollectFacts(sheet);
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

  /** 学生按下某个动作。默认无操作:只有声明了 actions 的场景才需要实现 */
  protected onAction(key: string): void {
  }

  /** 子类把本次操作产生的事实写进来 */
  protected onCollectFacts(sheet: FactSheet): void {
  }
}
