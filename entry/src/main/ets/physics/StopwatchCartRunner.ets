import { ExperimentMeta } from '../model/ExperimentTypes';
import { FactSheet } from '../model/FactSheet';
import { InclineRunner } from './InclineRunner';
import { CircleShape, LabelShape, WorldSnapshot } from './World2D';

/** 一次计时:按下与松开时小车各在哪儿、中间过了多久 */
class TimingTrial {
  fromS: number = 0;
  toS: number = 0;
  duration: number = 0;
}

/** 停表画在左上角:表盘 + 读数 */
const WATCH_X = 0.85;
const WATCH_Y = 4.55;
/** 区间归并的精度:两端各差不到 5 cm 就算"量的同一段" */
const SEGMENT_EPS = 0.05;

const C_WATCH = '#2F6FB5';
const C_TEXT = '#1F2A3A';
const C_LATE = '#E2574C';

/**
 * 测量物体运动的速度(初中物理八年级上,地图条目 `phy-jr-007`)。
 *
 * 小车那条动力学直接复用斜面:垫一块木块、让车从顶端由静止下滑。新的是手里那只停表 ——
 * 按下记一次(此刻车在哪儿、表走了多久),松开记一次,两者之差就是这一段用的时间。
 *
 * 于是这条实验可判的东西全是"按"的后果:按了几次、覆盖了几段不同的区间、
 * 最长那一段走得到 1.5 s 吗(再短,手指的反应时间就占进去一大截,这正是教材
 * 说"倾角要取小"的理由 —— 判的是时长这个后果,不是倾角那个参数)。
 *
 * 三次重复要跨"重置"留着:学生是把每次结果抄进表格的人,重置只是让车再走一遍。
 */
export class StopwatchCartRunner extends InclineRunner {
  private trials: TimingTrial[] = [];
  private running: TimingTrial | null = null;
  private startedAt: number = Number.NaN;

  /** 只有第一次进入页面(Setup)才清空记录;学生按「重置」再走一遍不该抹掉已抄下的数 */
  setup(meta: ExperimentMeta): void {
    this.trials = [];
    this.running = null;
    this.startedAt = Number.NaN;
    super.setup(meta);
  }

  protected onAction(key: string): void {
    const s = this.readObservable('distance');
    if (key === 'timeStart') {
      if (this.running === null) {
        this.running = new TimingTrial();
        this.running.fromS = s;
        this.startedAt = this.time;
      }
      return;
    }
    if (key === 'timeStop' && this.running !== null) {
      const trial = this.running;
      trial.toS = s;
      trial.duration = this.time - this.startedAt;
      this.trials.push(trial);
      this.running = null;
      this.startedAt = Number.NaN;
    }
  }

  readObservable(key: string): number {
    switch (key) {
      case 'watchReading':
        return Number.isNaN(this.elapsedNow()) ? 0 : this.elapsedNow();
      case 'speedTrials':
        return this.trials.length;
      case 'speedSegments':
        return this.distinctSegments();
      case 'speedLongestS':
        return this.longest();
      case 'speedShortestS':
        return this.shortest();
      default:
        return super.readObservable(key);
    }
  }

  protected onCollectFacts(sheet: FactSheet): void {
    sheet.set('speedTrials', this.trials.length);
    sheet.set('speedSegments', this.distinctSegments());
    const longest = this.longest();
    if (Number.isFinite(longest)) {
      sheet.set('speedLongestS', longest);
    }
    sheet.mark('timed', this.trials.length > 0 ? this.time : -1);
  }

  snapshot(): WorldSnapshot {
    const snap = super.snapshot();
    const dial = new CircleShape();
    dial.cx = WATCH_X;
    dial.cy = WATCH_Y;
    dial.r = 0.34;
    dial.color = C_WATCH;
    snap.circles.push(dial);
    const reading = new LabelShape();
    reading.x = WATCH_X;
    // 读数放在表盘下面:「2.06 s」一行约 45 px,比直径 0.68 m 的表盘宽,
    // 印在圆心会把蓝圆从中间划断(截图上看得见)
    reading.y = WATCH_Y - 0.56;
    reading.text = this.elapsedNow().toFixed(2) + ' s';
    reading.sizeVp = 14;
    reading.color = this.running === null ? C_TEXT : C_LATE;
    reading.align = 'center';
    snap.labels.push(reading);
    const tag = new LabelShape();
    tag.x = WATCH_X;
    tag.y = WATCH_Y + 0.5;
    tag.text = this.running === null ? '停表已松开' : '停表走着';
    tag.sizeVp = 11;
    tag.color = C_TEXT;
    tag.align = 'center';
    snap.labels.push(tag);
    return snap;
  }

  /** 表上此刻的读数:没在走就显示最后一次的结果 */
  private elapsedNow(): number {
    if (this.running !== null) {
      return this.time - this.startedAt;
    }
    const last = this.trials.length > 0 ? this.trials[this.trials.length - 1] : null;
    return last === null ? 0 : last.duration;
  }

  /** 按下了却没松开的那一次不计入"段数":它还没有终点 */
  private distinctSegments(): number {
    const keys: string[] = [];
    for (const t of this.trials) {
      const key = this.bucket(t.fromS) + '-' + this.bucket(t.toS);
      if (keys.indexOf(key) < 0) {
        keys.push(key);
      }
    }
    return keys.length;
  }

  private bucket(s: number): string {
    return String(Math.round(s / SEGMENT_EPS));
  }

  private longest(): number {
    let best = Number.NaN;
    for (const t of this.trials) {
      if (!Number.isFinite(best) || t.duration > best) {
        best = t.duration;
      }
    }
    return best;
  }

  private shortest(): number {
    let best = Number.NaN;
    for (const t of this.trials) {
      if (!Number.isFinite(best) || t.duration < best) {
        best = t.duration;
      }
    }
    return best;
  }
}
