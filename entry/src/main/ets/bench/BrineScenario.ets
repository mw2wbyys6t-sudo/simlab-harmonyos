import { Brine, Separations } from './Brine';
import { Container, PourModel } from './Container';
import { FilterAssembly } from './Filtration';
import { Glassware, Profile } from '../geometry/Profile';
import { Support } from './Pose';
import { FactSheet } from '../model/FactSheet';
import { RubricBrine } from './RubricBrine';
import { Spatula } from './Spatula';

/**
 * 一次完整的粗盐提纯。
 *
 * 关键设计:**没有一条判据是"设定"出来的**。`pourTiltDeg` 只是「倒得多猛」,
 * 至于会不会让漏斗液面漫过滤纸边缘、漫过多少、滤液浊度多高,全部由
 * `FilterAssembly` 的几何与 draining 过程算出来。所以「滤液浑浊」是学生倒出来的,
 * 不是我们标出来的。
 */
export class BrineScenario {
  saltG: number = 4.0;
  sandG: number = 1.0;
  /**
   * 粉末取用姿态:「一斜二送三直立」。默认横放 + 送到底,即规范动作,沾壁为零。
   *
   * 改成直立(reach 小、tilt 大)会让一部分粗盐沾在烧杯壁上,那部分**不参与溶解**,
   * 于是产率下降 —— 由既有的产率判据 B06 命中,不需要为这个失误另设判据。
   */
  powderTiltDeg: number = 0;
  powderReachCm: number = 7;
  /**
   * 加水量。20 ℃ 下 10 mL 水只能溶 3.6 g NaCl,而 5 g 粗盐里约含 4 g ——
   * 水加不够,盐就溶不完,未溶的那部分会被当作滤渣丢掉、产率白白低一截。
   * 所以「量取约 12 mL 水并加至恰好全部溶解」才是这个实验的规范操作。
   */
  waterMl: number = 12;
  /**
   * 倾倒仰角:越大倒得越猛。默认 30° 是「规范操作」的流速 ——
   * 慢于滤纸透过速度,所以液面不会涨过滤纸边缘。要触发旁通得真的倒太猛,
   * 而不是我们把结论设进去。
   */
  pourTiltDeg: number = 26;
  /** 是否用玻璃棒引流 */
  rodUsed: boolean = true;
  /** 蒸发时是否用玻璃棒搅拌 */
  evapStirred: boolean = true;
  /** 倾倒时瓶口相对漏斗口的水平偏移(cm),超出容差就洒在桌面上 */
  aimOffsetCm: number = 0;
  facts: FactSheet = new FactSheet();
}

export class BrineRun {
  beaker: Container = Container.of('beaker', '烧杯', Glassware.beaker100());
  assembly: FilterAssembly = FilterAssembly.of();
  dish: Container = Container.of('dish', '蒸发皿', Glassware.evaporatingDish());
  facts: FactSheet = new FactSheet();
  /**
   * 滤液浊度必须在**收集时**取。滤液随后要转入蒸发皿,那时接收烧杯已经空了 ——
   * 事后再读等于永远读不到浑浊,这个测量点错法会让「滤液浑浊」变成不可判定。
   */
  filtrateTurbidityAtCollection: number = 0;
}

export class BrineScenarioRunner {
  private static readonly DT: number = 1 / 60;

  static run(input: BrineScenario): BrineRun {
    const run = new BrineRun();
    const assembly = run.assembly;
    assembly.rodUsed = input.rodUsed;
    assembly.funnel.support = Support.CLAMPED;
    run.beaker.support = Support.HELD;
    run.beaker.pose.x = input.aimOffsetCm;
    assembly.funnel.pose.x = 0;

    // ① 溶解
    Spatula.deliver(run.beaker, input.saltG, input.sandG, input.powderTiltDeg, input.powderReachCm);
    Separations.addWater(run.beaker.brine, input.waterMl);
    // ① 溶解:规范操作是「搅拌至完全溶解」。这里必须按到达终点来循环,
    // 而不是固定跑若干秒 —— 固定秒数会让一部分盐以固体形式被留在烧杯里,
    // 表现为"产率极低",而那不是分离过程的真实损失,是我们没让溶解跑完。
    let t = 0;
    for (let i = 0; i < 20000; i++) {
      Separations.dissolve(run.beaker.brine, BrineScenarioRunner.DT, true);
      t += BrineScenarioRunner.DT;
      if (run.beaker.brine.saltSolidG <= 1e-9) {
        break;
      }
    }
    run.facts.mark(RubricBrine.ID_DISSOLVE, t);
    run.facts.set('dissolveSec', t);

    // ② 过滤:边倒边滤。倒得猛 → 漏斗液位涨过边缘 → 超出部分旁通
    run.facts.set('undissolvedAtFilterG', run.beaker.brine.saltSolidG);
    run.beaker.pose.tiltDeg = input.pourTiltDeg;
    for (let i = 0; i < 30000; i++) {
      const stillInBeaker = run.beaker.brine.waterMl > 1e-9;
      if (stillInBeaker) {
        PourModel.step(run.beaker, assembly.funnel, BrineScenarioRunner.DT, input.rodUsed);
      }
      assembly.settle(BrineScenarioRunner.DT);
      const drained = assembly.drain(BrineScenarioRunner.DT);
      t += BrineScenarioRunner.DT;
      if (drained > 0) {
        run.facts.mark(RubricBrine.ID_FILTER, t);
      }
      if (!stillInBeaker && assembly.funnel.brine.waterMl <= 1e-9) {
        break;
      }
    }
    // 把漏斗里残留的滤液一并转入蒸发皿(实际操作中靠洗涤与倾尽完成)
    run.filtrateTurbidityAtCollection = assembly.filtrateTurbidity();
    Separations.pour(assembly.funnel.brine, assembly.filtrate.brine,
      assembly.funnel.brine.waterMl, 0);

    // ③ 蒸发结晶
    Separations.pour(assembly.filtrate.brine, run.dish.brine,
      assembly.filtrate.brine.waterMl, 0);
    for (let i = 0; i < 6000; i++) {
      const area = run.dish.surfaceArea();
      if (run.dish.brine.waterMl <= 1e-9) {
        break;
      }
      Separations.evaporate(run.dish.brine, BrineScenarioRunner.DT, area, input.evapStirred);
      t += BrineScenarioRunner.DT;
      run.facts.mark(RubricBrine.ID_EVAPORATE, t);
    }

    BrineScenarioRunner.emitFacts(run, input, t);
    return run;
  }

  private static emitFacts(run: BrineRun, input: BrineScenario, endTime: number): void {
    const facts = run.facts;
    const spilled = BrineScenarioRunner.spillOf([run.beaker.brine, run.assembly.funnel.brine,
      run.assembly.filtrate.brine, run.dish.brine]);
    const recovered = run.dish.brine.saltSolidG + run.dish.brine.saltDissolvedG;

    facts.set('rodUsed', input.rodUsed ? 1 : 0);
    facts.set('evapStirred', input.evapStirred ? 1 : 0);
    facts.set('spilledMl', spilled);
    // 蒸发飞溅单独取蒸发皿自己的溅失,不能混入倾倒阶段的洒落 ——
    // 否则 B04 的证据会把「倒得太猛」也算成「没搅拌」,两个考点被合并成一条假扣分
    facts.set('splashSaltG', run.dish.brine.losses.spilledSaltG);
    facts.set('pourSpillSaltG', BrineScenarioRunner.splashSaltOf([run.beaker.brine,
      run.assembly.funnel.brine, run.assembly.filtrate.brine]));
    facts.set('bypassedMl', run.assembly.bypassedMl);
    facts.set('paperOverRimCm', run.assembly.maxLevelOverRimCm);
    facts.set('filtrateTurbidity', run.filtrateTurbidityAtCollection);
    facts.set('waterAddedMl', input.waterMl);
    facts.set('saltAddedG', input.saltG);
    // 沾壁的盐:它没进溶液,所以从产率里消失。判据读得到它的来源,不必另设一条扣分项
    facts.set('powderStuckSaltG', run.beaker.brine.saltStuckG);
    facts.set('saltRecoveredG', recovered);
    facts.set('yieldPct', input.saltG <= 0 ? Number.NaN : recovered / input.saltG * 100);
    facts.set('aimOffsetCm', Math.abs(input.aimOffsetCm));
    facts.set('elapsedSec', endTime);
  }

  /** 各容器累计洒失体积 */
  private static spillOf(items: Brine[]): number {
    let sum = 0;
    for (let i = 0; i < items.length; i++) {
      sum += items[i].losses.spilledWaterMl;
    }
    return sum;
  }

  private static splashSaltOf(items: Brine[]): number {
    let sum = 0;
    for (let i = 0; i < items.length; i++) {
      sum += items[i].losses.spilledSaltG;
    }
    return sum;
  }
}

/** 用一个剖面构造容器的便捷入口,供场景与测试复用。 */
export function containerWith(label: string, profile: Profile): Container {
  return Container.of(label, label, profile);
}
