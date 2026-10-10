import { ExperimentMeta } from '../model/ExperimentTypes';
import { IExperimentRunner } from './IExperimentRunner';

/** 定步长离散步进频率。240Hz 足够让弹簧振子与碰撞在 60fps 下稳定。 */
const FIXED_DT: number = 1 / 240;
/** 单帧最多补算的步数,防止低端设备掉帧时陷入追帧死循环 */
const MAX_SUBSTEPS: number = 40;
/** 单帧可吸收的最大真实时间差(秒),超出按丢帧处理 */
const MAX_FRAME_DELTA: number = 0.25;
/** 采样最小间隔(仿真秒)。逐帧 60Hz 采样对画线没必要,20Hz 已能表现完整波形。 */
const SAMPLE_INTERVAL: number = 1 / 20;
/**
 * 单条序列的点数上限。一节课 40 分钟按 20Hz 采样是 4.8 万个点,
 * 既吃内存又让图线每次重绘都全量扫描;超限后整体减半抽稀。
 */
const MAX_SAMPLES: number = 2400;

/**
 * 时间推进与采样的唯一驱动者。渲染循环每帧调用一次 advance(),
 * 它把不等间隔的墙钟时间切成等间隔的仿真步,保证结果与设备帧率无关 ——
 * 这是仿真实验能被复现、能被当作「实验数据」的前提。
 */
export class RunController {
  private runner: IExperimentRunner | null = null;
  private meta: ExperimentMeta | null = null;
  private accumulator: number = 0;
  private lastSampleAt: number = -1;
  /** 可观测量的时间序列,times[i] 对应 series.get(key)[i] */
  times: number[] = [];
  series: Map<string, number[]> = new Map();
  /**
   * 各序列的历史极值 [low, high]。极值在写入时就记下,所以抽稀丢掉样本
   * 也不会让图线量程突变,更不必每次重绘回来扫全量数据。
   */
  extents: Map<string, number[]> = new Map();

  running: boolean = false;
  /** 慢放倍速。讲台上演示关键瞬间时用 0.25 */
  timeScale: number = 1;

  bind(runner: IExperimentRunner, meta: ExperimentMeta): void {
    this.runner = runner;
    this.meta = meta;
    this.resetSampling();
    runner.setup(meta);
    this.running = false;
    this.captureSample(false);
  }

  start(): void {
    this.running = true;
  }

  pause(): void {
    this.running = false;
  }

  /** 清空已采集的数据并重跑。参数保持用户当前设定 */
  restart(): void {
    if (this.runner !== null) {
      this.runner.reset();
    }
    this.accumulator = 0;
    this.resetSampling();
    this.captureSample(false);
  }

  /**
   * @param realDelta 距上一帧的真实秒数
   * @returns 本帧实际推进的仿真步数,0 表示未运行或没有可推进的步
   */
  advance(realDelta: number): number {
    if (!this.running || this.runner === null) {
      return 0;
    }
    let scaled = realDelta * this.timeScale;
    if (scaled > MAX_FRAME_DELTA) {
      scaled = MAX_FRAME_DELTA;
    }
    this.accumulator += scaled;
    let steps = 0;
    while (this.accumulator >= FIXED_DT && steps < MAX_SUBSTEPS) {
      this.runner.step(FIXED_DT);
      this.accumulator -= FIXED_DT;
      steps++;
    }
    if (steps >= MAX_SUBSTEPS) {
      this.accumulator = 0;
    }
    if (steps > 0) {
      this.captureSample(false);
    }
    if (this.runner.finished()) {
      this.pause();
    }
    return steps;
  }

  /**
   * 参数被拖动时补一个点:暂停状态下改阻值,U-I 图上也应当立刻出现新的坐标。
   * 若距上一个采样点还不够间隔,则覆盖末尾那个点而不是继续加点。
   */
  sampleNow(): void {
    this.captureSample(true);
  }

  /** 序列的历史量程,图线据此定标 */
  extentOf(key: string): number[] {
    const hit = this.extents.get(key);
    return hit === undefined ? [0, 1] : hit;
  }

  private resetSampling(): void {
    this.times = [];
    this.series = new Map();
    this.extents = new Map();
    this.lastSampleAt = -1;
    if (this.meta !== null) {
      for (let i = 0; i < this.meta.observables.length; i++) {
        const def = this.meta.observables[i];
        // 只给参与采样的观测量建序列,否则非采样项会留下永远为空的数组
        if (def.sampled) {
          this.series.set(def.key, []);
          this.extents.set(def.key, [Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY]);
        }
      }
    }
  }

  private captureSample(canReplace: boolean): void {
    if (this.runner === null || this.meta === null) {
      return;
    }
    const t = this.runner.elapsedTime();
    const tooSoon = this.lastSampleAt >= 0 && t - this.lastSampleAt < SAMPLE_INTERVAL;
    if (tooSoon) {
      if (canReplace && this.times.length > 0) {
        this.writeSample(t, true);
      }
      return;
    }
    this.writeSample(t, false);
    this.lastSampleAt = t;
    if (this.times.length > MAX_SAMPLES) {
      this.decimate();
    }
  }

  private writeSample(t: number, replaceLast: boolean): void {
    if (this.meta === null || this.runner === null) {
      return;
    }
    for (let i = 0; i < this.meta.observables.length; i++) {
      const def = this.meta.observables[i];
      if (!def.sampled) {
        continue;
      }
      const bucket = this.series.get(def.key);
      const extent = this.extents.get(def.key);
      if (bucket === undefined || extent === undefined) {
        continue;
      }
      const value = this.runner.readObservable(def.key);
      if (replaceLast) {
        if (bucket.length > 0) {
          bucket[bucket.length - 1] = value;
        }
        continue;
      }
      bucket.push(value);
      if (Number.isFinite(value)) {
        if (value < extent[0]) {
          extent[0] = value;
        }
        if (value > extent[1]) {
          extent[1] = value;
        }
      }
    }
    if (replaceLast) {
      this.times[this.times.length - 1] = t;
      return;
    }
    this.times.push(t);
  }

  /** 隔点抽稀:保留一半样本,覆盖全程形状而不是只留最近一段 */
  private decimate(): void {
    const keptTimes: number[] = [];
    for (let i = 0; i < this.times.length; i += 2) {
      keptTimes.push(this.times[i]);
    }
    this.times = keptTimes;
    this.series.forEach((bucket: number[], key: string) => {
      const kept: number[] = [];
      for (let i = 0; i < bucket.length; i += 2) {
        kept.push(bucket[i]);
      }
      this.series.set(key, kept);
    });
  }
}
