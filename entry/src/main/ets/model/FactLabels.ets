/** 一个事实键的显示名与单位 */
export class FactLabel {
  label: string = '';
  unit: string = '';
  /** 0/1 类事实印成数字,学生读到「是否超过弹性限度 = 0」会以为缺数;给 true 就印是/否 */
  boolean: boolean = false;
  /** 结果码这类事实印成裸 0/1/2 学生读不懂;给一张码→人话的表 */
  codes: Map<number, string> | null = null;

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
    // 探究电流与电压、电阻的关系:判的全是学生自己按出来的动作留下的后果
    table.set('ohmRecordCount', new FactLabel('已记录组数', ' 组'));
    table.set('ohmMaxPointsAtOneR', new FactLabel('同一电阻下的电压档数', ' 档'));
    table.set('ohmResistances', new FactLabel('测过的电阻种数', ' 种'));
    table.set('ohmSharedVoltages', new FactLabel('同电压可比较的档数', ' 档'));
    table.set('ohmFirstSlide', new FactLabel('第一组读数时滑片位置', ' Ω'));
    // 测电动势与内阻:判的是读数分布在电流轴上铺开了多大一段
    table.set('emfRecordCount', new FactLabel('已记录组数', ' 组'));
    table.set('emfCurrentSpread', new FactLabel('读数铺开的电流跨度', ' A'));
    table.set('emfMaxCurrent', new FactLabel('读数里最大的电流', ' A'));
    table.set('emfMinCurrent', new FactLabel('读数里最小的电流', ' A'));
    // 纸带:判的是「这条纸带是怎么打出来的」,不是 a 等于多少
    table.set('tapeDotCount', new FactLabel('纸带上的点数', ' 个'));
    table.set('tapeLostHead', new FactLabel('头一段漏打的点数', ' 个'));
    table.set('tapeSegments', new FactLabel('切出的计数段数', ' 段'));
    table.set('tapeShortestMm', new FactLabel('最短计数段', ' mm'));
    table.set('tapeFirstGapMm', new FactLabel('第一对点的间距', ' mm'));
    // Ruling N:应用口径的两个数(有效起点是被夹住之后的、参与段数是截到 2h 整的),
    // 与滑杆位置/总段数可以不同 —— 差在哪必须让学生看见,不然逐差法的"后一半"只能猜。
    table.set('tapeChunkStart', new FactLabel('有效计数起点', ' 个'));
    table.set('tapeChunkSegments', new FactLabel('参与逐差法的段数', ' 段'));
    // 填数通道:判的是"学生自己交上来的数对不上哪一个典型错法"。
    // outcome 这三格读的是结果码(0 算对 / 1 算错 / 2 没交),必须过 codes 表才印得成人话。
    table.set('tapeNumeratorOutcome', FactLabels.coded('逐差法分子判定'));
    table.set('tapeDenFactorOutcome', FactLabels.coded('逐差法分母判定'));
    table.set('ans.tapeNumerator', new FactLabel('你交的逐差法分子', ' mm'));
    table.set('ans.tapeDenFactor', new FactLabel('你交的分母倍数', ''));
    table.set('tapeNumeratorTrue', new FactLabel('逐差法分子应有值', ' mm'));
    table.set('tapeDenFactorTrue', new FactLabel('分母倍数应有值', ''));
    table.set('tapeNumeratorWrongKind', new FactLabel('分子错法', ''));
    table.set('tapeDenFactorWrongKind', new FactLabel('分母错法', ''));
    // 停表:判的是「按了几次、覆盖了几个不同区间、最长一段走得到多久」
    table.set('speedTrials', new FactLabel('按完的次数', ' 次'));
    table.set('speedSegments', new FactLabel('测到的不同区间', ' 段'));
    table.set('speedLongestS', new FactLabel('最长一段用的时间', ' s'));
    // 牛顿第二定律:判的是控制变量与平衡摩擦这两个动作,不是 a 等于多少
    table.set('n2RecordCount', new FactLabel('记下几组', ' 组'));
    table.set('n2UsableCount', new FactLabel('算得出加速度的组数', ' 组'));
    table.set('n2ForceSteps', new FactLabel('同一质量下换过的拉力档', ' 档'));
    table.set('n2MassSteps', new FactLabel('同一拉力下试过质量', ' 种'));
    table.set('n2ChecksDone', new FactLabel('空载轻推检查', ' 次'));
    table.set('n2IdleSpreadMm', new FactLabel('轻推那次的点距跨度', ' mm'));
    // 描图:判的是"这幅图是怎么按出来的",不是它长得好不好看
    table.set('imgSamples', new FactLabel('按下的取样点', ' 个'));
    table.set('imgSpanT', new FactLabel('覆盖的周期数', ' 个'));
    table.set('imgMaxGapT', new FactLabel('最大的取样间隔', ' 个周期'));
    table.set('imgSwingCm', new FactLabel('点铺开的位置范围', ' cm'));
    table.set('imgDistortCm', new FactLabel('与真实曲线的最大差', ' cm'));
    // 平抛:判的是"卡片摆在哪、从第几格释放"这两下留下的后果
    table.set('pjPointCount', new FactLabel('描下的点', ' 个'));
    table.set('pjEarlyMarks', new FactLabel('定原点前描的点', ' 个'));
    table.set('pjSlotSpread', new FactLabel('释放位置最大差', ' 格'));
    table.set('pjXGapRatio', new FactLabel('水平间隔最大/最小', ''));
    table.set('pjRatioErr', new FactLabel('y/x² 的离散度', '%'));
    return table;
  }

  /**
   * 结果码类事实:0 算对 / 1 算错 / 2 没交。
   *
   * 判据标题与证据模板仍在细则里,这里只管读数那一列 —— 判分模块不懂物理,
   * 但它印出来的码必须是人话(裸 2 会被学生读成"量出来是 2")。
   */
  static coded(label: string): FactLabel {
    const entry = new FactLabel(label, '');
    const codes = new Map<number, string>();
    codes.set(0, '算对了');
    codes.set(1, '算错了');
    codes.set(2, '没交');
    entry.codes = codes;
    return entry;
  }

  /**
   * 只有带 codes 表的事实键才走这条路;其余事实照旧由 Judgment 按数字格式化。
   *
   * 为什么开这条窄口(Ruling 1):`fill()` 原本只调 `Judgment.text`,不查这张表,
   * 细则模板里的 {tapeNumeratorOutcome} 会印成裸 2。改成"所有事实都经 FactLabels.valueText"
   * 会连带给每条既有判据的数字追加单位、波及全部细则与设备探针断言,远超这条链路的需要。
   */
  static codedText(key: string, value: number): string | null {
    const hit = FactLabels.of(key);
    if (hit === null || hit.codes === null) {
      return null;
    }
    const text = hit.codes.get(value);
    return text === undefined ? null : text;
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
    if (hit !== null && hit.codes !== null) {
      const text = hit.codes.get(value);
      if (text !== undefined) {
        return text;
      }
    }
    if (hit !== null && hit.boolean) {
      return value >= 0.5 ? '是' : '否';
    }
    // 整数原样印:档数/步数这类计数印成 7.00 会被读成量出来的数
    const text = Number.isInteger(value) ? String(value) : value.toFixed(2);
    return text + (hit === null ? '' : hit.unit);
  }
}
