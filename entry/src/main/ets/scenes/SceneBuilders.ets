import { ChartDef, ChartSeries, ActionDef, ObservableDef, ParamControl, ParamDef, TaskDef } from '../model/ExperimentTypes';
import { Theme } from '../common/Theme';

/** 场景元数据的简写构造器,避免每个实验重复写赋值样板。 */
export class SceneBuilders {
  static param(key: string, label: string, unit: string, min: number, max: number,
    step: number, defaultValue: number, group: string): ParamDef {
    const def = new ParamDef();
    def.key = key;
    def.label = label;
    def.unit = unit;
    def.min = min;
    def.max = max;
    def.step = step;
    def.defaultValue = defaultValue;
    def.group = group;
    return def;
  }

  static switchParam(key: string, label: string, closed: boolean, group: string): ParamDef {
    const def = SceneBuilders.param(key, label, '', 0, 1, 1, closed ? 1 : 0, group);
    def.control = ParamControl.SWITCH;
    return def;
  }

  static observable(key: string, label: string, unit: string, precision: number, sampled: boolean): ObservableDef {
    const def = new ObservableDef();
    def.key = key;
    def.label = label;
    def.unit = unit;
    def.precision = precision;
    def.sampled = sampled;
    return def;
  }

  /** 学生主动按下的动作按钮。判定层读的是它留下的后果,不是按钮本身 */
  static action(key: string, label: string, group: string): ActionDef {
    const def = new ActionDef();
    def.key = key;
    def.label = label;
    def.group = group;
    return def;
  }

  static task(key: string, prompt: string, expected: number, tolerance: number): TaskDef {    const task = new TaskDef();
    task.key = key;
    task.prompt = prompt;
    task.expected = expected;
    task.tolerance = tolerance;
    return task;
  }

  static trace(observableKey: string, label: string, color: string): ChartSeries {
    const series = new ChartSeries();
    series.observableKey = observableKey;
    series.label = label;
    series.color = color;
    return series;
  }

  /** 纵轴对采样时间的图 */
  static timeChart(title: string, yLabel: string, yUnit: string, series: ChartSeries[]): ChartDef {
    const chart = new ChartDef();
    chart.title = title;
    chart.xKey = 't';
    chart.xLabel = 't';
    chart.xUnit = 's';
    chart.yLabel = yLabel;
    chart.yUnit = yUnit;
    chart.includeOrigin = true;
    chart.series = series;
    return chart;
  }

  /** 两个观测量互图的图,如伏安特性 U-I */
  static xyChart(title: string, xKey: string, xLabel: string, xUnit: string,
    yLabel: string, yUnit: string, series: ChartSeries[]): ChartDef {
    const chart = SceneBuilders.timeChart(title, yLabel, yUnit, series);
    chart.xKey = xKey;
    chart.xLabel = xLabel;
    chart.xUnit = xUnit;
    return chart;
  }

  static palette(index: number): string {
    if (index === 0) {
      return Theme.SERIES_1;
    }
    if (index === 1) {
      return Theme.SERIES_2;
    }
    return index === 2 ? Theme.SERIES_3 : Theme.SERIES_4;
  }
}
