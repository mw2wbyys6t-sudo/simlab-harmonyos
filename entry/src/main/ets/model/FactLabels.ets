/** 一个事实键的显示名与单位 */
export class FactLabel {
  label: string = '';
  unit: string = '';
  /** 0/1 类事实印成数字,学生读到「是否超过弹性限度 = 0」会以为缺数;给 true 就印是/否 */
  boolean: boolean = false;

  constructor(label: string, unit: string, isBoolean: boolean = false) {
    this.label = label;
    this.unit = unit;
    this.boolean = isBoolean;
  }
}

/**
 * 事实键到「人话」的集中表。
 *
 * 报告页原来把提纯的 12 个键硬编码在页面里,换成另一条链路(量取)时整张表会静默变空。
 * 集中成一张表之后,「新增事实却忘了配标签」由断言抓出来并指名是哪个键,而不是等截图。
 *
 * 单位里的前导空格是刻意的:`88.50%` 不加空格,`4.00 g` 要加。
 */
export class FactLabels {
  private static readonly TABLE: Map<string, FactLabel> = FactLabels.buildTable();
  private static readonly MOMENTS: Map<string, string> = FactLabels.buildMoments();

  private static buildTable(): Map<string, FactLabel> {
    const table = new Map<string, FactLabel>();
    // 粗盐提纯
    table.set('saltAddedG', new FactLabel('投入粗盐中 NaCl', ' g'));
    table.set('saltRecoveredG', new FactLabel('回收精盐', ' g'));
    table.set('yieldPct', new FactLabel('产率', '%'));
    table.set('waterAddedMl', new FactLabel('加水量', ' mL'));
    table.set('dissolveSec', new FactLabel('溶解用时', ' s'));
    table.set('undissolvedAtFilterG', new FactLabel('过滤时未溶盐', ' g'));
    table.set('spilledMl', new FactLabel('倾倒洒失', ' mL'));
    table.set('pourSpillSaltG', new FactLabel('洒失带走的盐', ' g'));
    table.set('paperOverRimCm', new FactLabel('液面高过滤纸(峰值)', ' cm'));
    table.set('bypassedMl', new FactLabel('未经滤纸直灌', ' mL'));
    table.set('filtrateTurbidity', new FactLabel('滤液浊度', ' NTU'));
    table.set('splashSaltG', new FactLabel('蒸发飞溅损失盐', ' g'));
    table.set('powderStuckSaltG', new FactLabel('沾壁损失的盐', ' g'));
    table.set('rodUsed', new FactLabel('玻璃棒引流', '', true));
    table.set('evapStirred', new FactLabel('蒸发时搅拌', '', true));
    table.set('aimOffsetCm', new FactLabel('对准偏差', ' cm'));
    table.set('elapsedSec', new FactLabel('总用时', ' s'));
    // 量取
    table.set('goalMl', new FactLabel('目标体积', ' mL'));
    table.set('actualMl', new FactLabel('实际量取', ' mL'));
    table.set('readMl', new FactLabel('你的读数', ' mL'));
    table.set('tiltDeg', new FactLabel('倾倒仰角', '°'));
    table.set('eyeCm', new FactLabel('视线高度', ' cm'));
    table.set('deviationMl', new FactLabel('量取偏差', ' mL'));
    table.set('readErrorMl', new FactLabel('读数与实际的差', ' mL'));
    // 弹簧:弹力与形变量(计数类单位留空,值由 valueText 原样印成整数)
    table.set('recordCount', new FactLabel('记录读数次数', ' 条'));
    table.set('distinctLoads', new FactLabel('测过的载荷档数', ' 档'));
    table.set('maxRecordSpeed', new FactLabel('记录瞬间指针速度', ' m/s'));
    table.set('maxExtension', new FactLabel('到过的最大伸长', ' m'));
    table.set('beyondLimit', new FactLabel('是否超过弹性限度', '', true));
    table.set('unloadSteps', new FactLabel('卸载步数', ' 次'));
    table.set('residual', new FactLabel('撤去载荷后的残余形变', ' m'));
    return table;
  }

  private static buildMoments(): Map<string, string> {
    const moments = new Map<string, string>();
    moments.set('dissolve', '溶解完成');
    moments.set('filter', '开始过滤');
    moments.set('evaporate', '开始蒸发');
    moments.set('pourStart', '开始倾倒');
    moments.set('pourStop', '收手停倒');
    moments.set('recorded', '第一次记录读数');
    return moments;
  }

  /** 查不到返回 null。调用方据此退回键名,而不是我们替它猜一个显示名 */
  static of(key: string): FactLabel | null {
    const hit = FactLabels.TABLE.get(key);
    return hit === undefined ? null : hit;
  }

  static momentLabel(event: string): string {
    const hit = FactLabels.MOMENTS.get(event);
    return hit === undefined ? event : hit;
  }

  /** 标签列。查不到退回键名本身:宁可难看,也不要静默变空 */
  static labelOf(key: string): string {
    const hit = FactLabels.of(key);
    return hit === null ? key : hit.label;
  }

  /** 数值列。缺值显示破折号而不是 NaN */
  static valueText(key: string, value: number): string {
    if (!Number.isFinite(value)) {
      return '—';
    }
    const hit = FactLabels.of(key);
    if (hit !== null && hit.boolean) {
      return value >= 0.5 ? '是' : '否';
    }
    // 整数原样印:档数/步数这类计数印成 7.00 会被读成量出来的数
    const text = Number.isInteger(value) ? String(value) : value.toFixed(2);
    return text + (hit === null ? '' : hit.unit);
  }
}
