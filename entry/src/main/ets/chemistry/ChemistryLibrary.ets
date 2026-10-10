import { ConditionTokens, Phase, ReactionSpec, ReactionType, Substance, Term } from './ChemistryModel';
import { Formula } from './Formula';

/**
 * 试剂与反应的数据表。
 *
 * 三条约定:
 * 1. 式量一律由化学式算出(见 Formula),数据里不写数字,避免抄错相对分子质量;
 * 2. 气体↑与沉淀↓标记由数据显式声明,引擎不做推断 —— 推断会把「碳酸钠溶液与
 *    氯化钙溶液生成沉淀」这类事实性内容变成算法问题;
 * 3. 每条反应注册时都要通过 ReactionValidator 的元素、质量、电荷三重守恒校验,
 *    不通过就不允许进产品。配不平的方程式比没有方程式更糟。
 */
export class Reagents {
  private static readonly items: Map<string, Substance> = new Map();

  private static add(key: string, name: string, formula: string, phase: Phase, color: string,
    soluble: boolean, hazard: string): void {
    const item = new Substance();
    item.key = key;
    item.name = name;
    item.formula = formula;
    item.phase = phase;
    item.color = color;
    item.soluble = soluble;
    item.hazard = hazard;
    Reagents.items.set(key, item);
  }

  static solid(key: string, name: string, formula: string, color: string, soluble: boolean,
    hazard: string): void {
    Reagents.add(key, name, formula, Phase.SOLID, color, soluble, hazard);
  }

  static liquid(key: string, name: string, formula: string, color: string, hazard: string): void {
    Reagents.add(key, name, formula, Phase.LIQUID, color, false, hazard);
  }

  static gas(key: string, name: string, formula: string, color: string, hazard: string): void {
    Reagents.add(key, name, formula, Phase.GAS, color, false, hazard);
  }

  /** 溶液中的溶质:反应判定按离子进行 */
  static aq(key: string, name: string, formula: string, color: string, hazard: string): void {
    Reagents.add(key, name, formula, Phase.AQUEOUS, color, true, hazard);
  }

  /** 离子物种,化学式里带电荷标记 */
  static ion(key: string, name: string, formula: string, color: string): void {
    Reagents.add(key, name, formula, Phase.AQUEOUS, color, true, '');
  }

  static get(key: string): Substance {
    const hit = Reagents.items.get(key);
    if (hit === undefined) {
      throw new Error('试剂表中没有 ' + key);
    }
    return hit;
  }

  static size(): number {
    return Reagents.items.size;
  }
}

/** 反应项简写:试剂键 × 系数 × 状态标记 */
export function term(key: string, coefficient: number, marker: string): Term {
  const item = new Term();
  item.substance = Reagents.get(key);
  item.coefficient = coefficient;
  item.marker = marker;
  return item;
}

export function reaction(id: string, title: string, type: ReactionType, band: string): ReactionSpec {
  const spec = new ReactionSpec();
  spec.id = id;
  spec.title = title;
  spec.type = type;
  spec.band = band;
  return spec;
}

export class ChemistryLibrary {
  static registerReagents(): void {
    Reagents.solid('kmno4', '高锰酸钾', 'KMnO4', '紫黑色', true, '强氧化剂，勿与还原性有机物混放');
    Reagents.solid('k2mno4', '锰酸钾', 'K2MnO4', '墨绿色', true, '');
    Reagents.solid('mno2', '二氧化锰', 'MnO2', '黑色', false, '粉尘勿吸入');
    Reagents.gas('o2', '氧气', 'O2', '无色', '助燃');
    Reagents.aq('h2o2', '过氧化氢溶液', 'H2O2', '无色', '有腐蚀性，接触皮肤会灼伤发白');
    Reagents.liquid('h2o', '水', 'H2O', '无色', '');
    Reagents.solid('caco3', '大理石(碳酸钙)', 'CaCO3', '白色', false, '');
    Reagents.aq('hcl', '稀盐酸', 'HCl', '无色', '腐蚀性强，沾到皮肤立即用大量水冲洗');
    Reagents.aq('cacl2', '氯化钙溶液', 'CaCl2', '无色', '');
    Reagents.gas('co2', '二氧化碳', 'CO2', '无色', '不支持呼吸');
    Reagents.solid('zn', '锌粒', 'Zn', '灰黑色', false, '');
    Reagents.aq('h2so4', '稀硫酸', 'H2SO4', '无色', '腐蚀性强；稀释时只能把酸加入水中');
    Reagents.aq('znso4', '硫酸锌溶液', 'ZnSO4', '无色', '');
    Reagents.gas('h2', '氢气', 'H2', '无色', '易燃易爆，点燃前必须验纯');
    Reagents.solid('fe', '铁丝', 'Fe', '银白色', false, '');
    Reagents.aq('cuso4', '硫酸铜溶液', 'CuSO4', '蓝色', '重金属盐，废液不得倒入下水道');
    Reagents.aq('feso4', '硫酸亚铁溶液', 'FeSO4', '浅绿色', '');
    Reagents.solid('cu', '铜', 'Cu', '紫红色', false, '');
    Reagents.solid('nahco3', '碳酸氢钠', 'NaHCO3', '白色', true, '');
    Reagents.solid('na2co3', '碳酸钠', 'Na2CO3', '白色', true, '');
    Reagents.aq('naoh', '氢氧化钠溶液', 'NaOH', '无色', '强碱，腐蚀皮肤，不得用手接触');
    Reagents.aq('nacl', '氯化钠溶液', 'NaCl', '无色', '');
    Reagents.aq('bacl2', '氯化钡溶液', 'BaCl2', '无色', '钡盐有毒，废液集中回收');
    Reagents.aq('na2so4', '硫酸钠溶液', 'Na2SO4', '无色', '');
    Reagents.solid('baso4', '硫酸钡', 'BaSO4', '白色', false, '');
    Reagents.gas('ch4', '甲烷', 'CH4', '无色', '易燃易爆，点燃前验纯');
    Reagents.gas('co', '一氧化碳', 'CO', '无色', '有剧毒，必须尾气处理并在通风处操作');
    Reagents.solid('fe2o3', '氧化铁', 'Fe2O3', '红棕色', false, '');
    Reagents.solid('fe3o4', '四氧化三铁', 'Fe3O4', '黑色', false, '');
    Reagents.solid('na', '金属钠', 'Na', '银白色', false, '保存在煤油中，用镊子取用，严禁用手接触');
    Reagents.gas('cl2', '氯气', 'Cl2', '黄绿色', '有毒，须在通风橱中操作，尾气用碱液吸收');
    Reagents.aq('naclo', '次氯酸钠', 'NaClO', '无色', '有漂白性');
    Reagents.gas('nh3', '氨气', 'NH3', '无色', '刺激性气味，易液化');
    Reagents.gas('no', '一氧化氮', 'NO', '无色', '有毒，接触空气即变为红棕色二氧化氮');
    Reagents.liquid('c2h5oh', '乙醇', 'C2H5OH', '无色', '易燃');
    Reagents.liquid('ch3cho', '乙醛', 'CH3CHO', '无色', '易燃，有刺激性');
    Reagents.liquid('ch3cooh', '乙酸', 'CH3COOH', '无色', '有腐蚀性');
    Reagents.liquid('ch3cooc2h5', '乙酸乙酯', 'CH3COOC2H5', '无色', '易燃');
    Reagents.aq('caoh2', '澄清石灰水', 'Ca(OH)2', '无色', '碱性，避免接触眼睛');
    Reagents.aq('agno3', '硝酸银溶液', 'AgNO3', '无色', '见光分解，沾到皮肤留黑斑');
    Reagents.solid('agcl', '氯化银', 'AgCl', '白色', false, '');
    Reagents.aq('nano3', '硝酸钠溶液', 'NaNO3', '无色', '');
    Reagents.solid('cuoh2', '氢氧化铜', 'Cu(OH)2', '蓝色', false, '');
    Reagents.aq('h2c2o4', '草酸溶液', 'H2C2O4', '无色', '有毒');
    Reagents.gas('i2', '碘', 'I2', '紫黑色蒸气', '蒸气刺激呼吸道');
    Reagents.aq('na2s2o3', '硫代硫酸钠溶液', 'Na2S2O3', '无色', '');
    Reagents.ion('hion', '氢离子', 'H^+', '无色');
    Reagents.ion('ohion', '氢氧根离子', 'OH^-', '无色');
    Reagents.ion('ca2', '钙离子', 'Ca^2+', '无色');
    Reagents.ion('ba2', '钡离子', 'Ba^2+', '无色');
    Reagents.ion('so4', '硫酸根离子', 'SO4^2-', '无色');
    Reagents.ion('agion', '银离子', 'Ag^+', '无色');
    Reagents.ion('clion', '氯离子', 'Cl^-', '无色');
    Reagents.ion('cu2', '铜离子', 'Cu^2+', '蓝色');
    Reagents.ion('mnov4', '高锰酸根离子', 'MnO4^-', '紫红色');
    Reagents.ion('mn2', '锰离子', 'Mn^2+', '近无色');
    Reagents.ion('iion', '碘离子', 'I^-', '无色');
    Reagents.ion('s2o3', '硫代硫酸根离子', 'S2O3^2-', '无色');
    Reagents.ion('s4o6', '连四硫酸根离子', 'S4O6^2-', '无色');
  }

  /**
   * 可用「药品柜 + 试管/烧杯 + 酒精灯」完成的反应。
   * 名单集中在这一处,是为了让「哪些能在桌面上做」成为一个可审阅的决定,
   * 而不是散落在二十个方法里 —— 需要通风橱、滴定管、电解槽或铂铑催化剂的
   * 反应留在这里之外,只进速查表。
   */
  private static readonly BENCH_IDS: string[] = ['kmno4-o2', 'h2o2-o2', 'caco3-co2', 'zn-h2',
    'fe-cuso4', 'nahco3-heat', 'hcl-naoh', 'bacl2-na2so4', 'agno3-nacl', 'cuso4-naoh', 'na-h2o'];

  static all(): ReactionSpec[] {
    const list: ReactionSpec[] = [];
    list.push(ChemistryLibrary.oxygenFromPermanganate());
    list.push(ChemistryLibrary.oxygenFromPeroxide());
    list.push(ChemistryLibrary.carbonDioxide());
    list.push(ChemistryLibrary.hydrogenFromZinc());
    list.push(ChemistryLibrary.ironDisplacesCopper());
    list.push(ChemistryLibrary.bicarbonateHeat());
    list.push(ChemistryLibrary.neutralization());
    list.push(ChemistryLibrary.limeWaterTest());
    list.push(ChemistryLibrary.bariumSulfate());
    list.push(ChemistryLibrary.silverChloride());
    list.push(ChemistryLibrary.copperHydroxide());
    list.push(ChemistryLibrary.natriumWater());
    list.push(ChemistryLibrary.methaneBurn());
    list.push(ChemistryLibrary.ironBurnInOxygen());
    list.push(ChemistryLibrary.carbonMonoxideIron());
    list.push(ChemistryLibrary.chlorineScrubber());
    list.push(ChemistryLibrary.ammoniaOxidation());
    list.push(ChemistryLibrary.ethanolOxidation());
    list.push(ChemistryLibrary.esterification());
    list.push(ChemistryLibrary.electrolysisWater());
    list.push(ChemistryLibrary.permanganateTitration());
    list.push(ChemistryLibrary.iodineThiosulfate());
    ChemistryLibrary.configure(list);
    return list;
  }

  /** 把显示用的条件文字翻成引擎可判断的放行条件,并标注哪些反应能在桌面上完成。 */
  private static configure(list: ReactionSpec[]): void {
    for (let i = 0; i < list.length; i++) {
      const spec = list[i];
      spec.needsHeat = ConditionTokens.needsHeat(spec.conditions);
      spec.needsPower = ConditionTokens.needsPower(spec.conditions);
      spec.benchReady = ChemistryLibrary.BENCH_IDS.includes(spec.id);
    }
    const peroxide = ChemistryLibrary.findById(list, 'h2o2-o2');
    if (peroxide !== null) {
      peroxide.catalystKeys = ['mno2'];
    }
  }

  private static findById(list: ReactionSpec[], id: string): ReactionSpec | null {
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        return list[i];
      }
    }
    return null;
  }

  /** 实验台可用的反应。 */
  static bench(): ReactionSpec[] {
    return ChemistryLibrary.all().filter((spec: ReactionSpec) => spec.benchReady);
  }

  /**
   * 药品柜清单由桌面反应用到的试剂推导出来,不手写。
   * 这样「加一个反应 → 药品柜自动补药」成立,也避免出现摆着一瓶永远用不上的药品。
   */
  static shelf(): string[] {
    const seen: Set<string> = new Set();
    const bench = ChemistryLibrary.bench();
    for (let i = 0; i < bench.length; i++) {
      const spec = bench[i];
      for (let j = 0; j < spec.reactants.length; j++) {
        seen.add(spec.reactants[j].substance.key);
      }
      for (let j = 0; j < spec.catalystKeys.length; j++) {
        seen.add(spec.catalystKeys[j]);
      }
    }
    return Array.from(seen).sort();
  }

  // ---- 初中 ----------------------------------------------------------------

  private static oxygenFromPermanganate(): ReactionSpec {
    const spec = reaction('kmno4-o2', '加热高锰酸钾制取氧气', ReactionType.DECOMPOSITION, '初中');
    spec.reactants.push(term('kmno4', 2, ''));
    spec.products.push(term('k2mno4', 1, ''), term('mno2', 1, ''), term('o2', 1, '↑'));
    spec.conditions.push('加热');
    spec.phenomena.push('紫黑色固体逐渐变为黑色', '导管口有气泡冒出', '带火星的木条伸入瓶内复燃');
    spec.safety.push('试管口略向下倾斜，防止冷凝水倒流使试管炸裂',
      '收集完毕先把导管移出水面再熄灭酒精灯，防止水倒吸');
    return spec;
  }

  private static oxygenFromPeroxide(): ReactionSpec {
    const spec = reaction('h2o2-o2', '过氧化氢分解制取氧气', ReactionType.DECOMPOSITION, '初中');
    spec.reactants.push(term('h2o2', 2, ''));
    spec.products.push(term('h2o', 2, ''), term('o2', 1, '↑'));
    spec.conditions.push('MnO₂ 作催化剂');
    spec.phenomena.push('加入二氧化锰后迅速产生大量气泡',
      '反应前后黑色固体的质量和化学性质都不变', '带火星的木条复燃');
    return spec;
  }

  private static carbonDioxide(): ReactionSpec {
    const spec = reaction('caco3-co2', '大理石与稀盐酸制取二氧化碳', ReactionType.METATHESIS, '初中');
    spec.reactants.push(term('caco3', 1, ''), term('hcl', 2, ''));
    spec.products.push(term('cacl2', 1, ''), term('h2o', 1, ''), term('co2', 1, '↑'));
    spec.phenomena.push('固体表面产生大量气泡并逐渐减少', '生成的气体使澄清石灰水变浑浊');
    spec.safety.push('不能用稀硫酸代替盐酸：生成的硫酸钙微溶，覆盖在大理石表面阻止反应继续');
    spec.ionic = ChemistryLibrary.carbonateIonic();
    return spec;
  }

  private static hydrogenFromZinc(): ReactionSpec {
    const spec = reaction('zn-h2', '锌与稀硫酸制取氢气', ReactionType.DISPLACEMENT, '初中');
    spec.reactants.push(term('zn', 1, ''), term('h2so4', 1, ''));
    spec.products.push(term('znso4', 1, ''), term('h2', 1, '↑'));
    spec.phenomena.push('锌粒逐渐溶解，表面产生大量气泡', '试管壁温度升高',
      '收集的气体点燃时产生淡蓝色火焰');
    spec.safety.push('点燃氢气前必须验纯，否则可能爆炸');
    return spec;
  }

  private static ironDisplacesCopper(): ReactionSpec {
    const spec = reaction('fe-cuso4', '铁与硫酸铜溶液反应', ReactionType.DISPLACEMENT, '初中');
    spec.reactants.push(term('fe', 1, ''), term('cuso4', 1, ''));
    spec.products.push(term('feso4', 1, ''), term('cu', 1, ''));
    spec.phenomena.push('银白色铁丝表面覆盖一层紫红色固体', '溶液由蓝色逐渐变为浅绿色');
    spec.safety.push('硫酸铜属重金属盐，废液须集中回收，不得倒入下水道');
    return spec;
  }

  private static bicarbonateHeat(): ReactionSpec {
    const spec = reaction('nahco3-heat', '碳酸氢钠受热分解', ReactionType.DECOMPOSITION, '初中');
    spec.reactants.push(term('nahco3', 2, ''));
    spec.products.push(term('na2co3', 1, ''), term('h2o', 1, ''), term('co2', 1, '↑'));
    spec.conditions.push('加热');
    spec.phenomena.push('试管内壁出现小水滴', '生成的气体使澄清石灰水变浑浊', '残留白色固体');
    return spec;
  }

  private static limeWaterTest(): ReactionSpec {
    const spec = reaction('co2-caoh2', '用澄清石灰水检验二氧化碳', ReactionType.METATHESIS, '初中');
    spec.reactants.push(term('co2', 1, ''), term('caoh2', 1, ''));
    spec.products.push(term('caco3', 1, '↓'), term('h2o', 1, ''));
    spec.phenomena.push('澄清石灰水变浑浊', '继续通入二氧化碳，浑浊又逐渐消失');
    spec.safety.push('浑浊消失是因为生成了可溶的碳酸氢钙，这一节教材只作说明，不要求写方程式');
    return spec;
  }

  private static ironBurnInOxygen(): ReactionSpec {
    const spec = reaction('fe-o2', '铁丝在氧气中燃烧', ReactionType.COMBUSTION, '初中');
    spec.reactants.push(term('fe', 3, ''), term('o2', 2, ''));
    spec.products.push(term('fe3o4', 1, ''));
    spec.conditions.push('点燃');
    spec.phenomena.push('剧烈燃烧、火星四射', '放出大量热', '生成黑色固体');
    spec.safety.push('集气瓶底预先放少量水或铺一层细沙，防止高温熔融物溅落炸裂瓶底');
    return spec;
  }

  private static carbonMonoxideIron(): ReactionSpec {
    const spec = reaction('co-fe2o3', '一氧化碳还原氧化铁', ReactionType.REDOX, '初中');
    spec.reactants.push(term('co', 3, ''), term('fe2o3', 1, ''));
    spec.products.push(term('fe', 2, ''), term('co2', 3, ''));
    spec.conditions.push('高温');
    spec.phenomena.push('红棕色粉末逐渐变为黑色', '生成的气体使澄清石灰水变浑浊');
    spec.safety.push('一氧化碳有剧毒：实验前验纯、装置气密性良好、末端尾气点燃或用气球收集');
    return spec;
  }

  private static electrolysisWater(): ReactionSpec {
    const spec = reaction('water-electrolysis', '电解水', ReactionType.DECOMPOSITION, '初中');
    spec.reactants.push(term('h2o', 2, ''));
    spec.products.push(term('h2', 2, '↑'), term('o2', 1, '↑'));
    spec.conditions.push('通直流电');
    spec.phenomena.push('两个电极上均产生气泡', '正极与负极收集到的气体体积比约为 1:2',
      '正极气体使带火星木条复燃，负极气体可以燃烧');
    return spec;
  }

  // ---- 高中 ----------------------------------------------------------------

  private static neutralization(): ReactionSpec {
    const spec = reaction('hcl-naoh', '盐酸与氢氧化钠的中和反应', ReactionType.NEUTRALIZATION, '高中');
    spec.reactants.push(term('hcl', 1, ''), term('naoh', 1, ''));
    spec.products.push(term('nacl', 1, ''), term('h2o', 1, ''));
    spec.phenomena.push('滴有酚酞的红色溶液，逐滴加入盐酸后红色突然褪去', '溶液温度升高');
    spec.safety.push('氢氧化钠强腐蚀，取用不得用手接触');
    spec.ionic = ChemistryLibrary.waterIonic();
    return spec;
  }

  private static bariumSulfate(): ReactionSpec {
    const spec = reaction('bacl2-na2so4', '氯化钡与硫酸钠反应', ReactionType.METATHESIS, '高中');
    spec.reactants.push(term('bacl2', 1, ''), term('na2so4', 1, ''));
    spec.products.push(term('baso4', 1, '↓'), term('nacl', 2, ''));
    spec.phenomena.push('立即生成白色沉淀', '加入稀硝酸后沉淀不溶解');
    spec.safety.push('钡盐有毒，实验后废液统一回收处理');
    spec.ionic = ChemistryLibrary.bariumIonic();
    return spec;
  }

  private static silverChloride(): ReactionSpec {
    const spec = reaction('agno3-nacl', '硝酸银与氯化钠反应', ReactionType.METATHESIS, '高中');
    spec.reactants.push(term('agno3', 1, ''), term('nacl', 1, ''));
    spec.products.push(term('agcl', 1, '↓'), term('nano3', 1, ''));
    spec.phenomena.push('生成白色沉淀', '加入稀硝酸后沉淀不溶解，据此检验氯离子');
    spec.ionic = ChemistryLibrary.silverIonic();
    return spec;
  }

  private static copperHydroxide(): ReactionSpec {
    const spec = reaction('cuso4-naoh', '硫酸铜与氢氧化钠反应', ReactionType.METATHESIS, '高中');
    spec.reactants.push(term('cuso4', 1, ''), term('naoh', 2, ''));
    spec.products.push(term('cuoh2', 1, '↓'), term('na2so4', 1, ''));
    spec.phenomena.push('生成蓝色絮状沉淀', '上层溶液蓝色变浅');
    spec.safety.push('氢氧化铜属重金属废物，收集后交老师统一处理，不得倒入下水道');
    spec.ionic = ChemistryLibrary.copperIonic();
    return spec;
  }

  private static natriumWater(): ReactionSpec {
    const spec = reaction('na-h2o', '钠与水的反应', ReactionType.DISPLACEMENT, '高中');
    spec.reactants.push(term('na', 2, ''), term('h2o', 2, ''));
    spec.products.push(term('naoh', 2, ''), term('h2', 1, '↑'));
    spec.phenomena.push('浮：钠浮在水面上', '熔：熔成光亮的小球', '游：小球四处游动',
      '响：发出嘶嘶的响声', '红：滴有酚酞的溶液变红');
    spec.safety.push('钠用镊子夹取、滤纸吸干煤油，余粒放回原瓶，严禁丢入废液缸',
      '取用绿豆大小即可，用量过大可能炸裂烧杯');
    return spec;
  }

  private static chlorineScrubber(): ReactionSpec {
    const spec = reaction('cl2-naoh', '氢氧化钠溶液吸收氯气', ReactionType.REDOX, '高中');
    spec.reactants.push(term('cl2', 1, ''), term('naoh', 2, ''));
    spec.products.push(term('nacl', 1, ''), term('naclo', 1, ''), term('h2o', 1, ''));
    spec.phenomena.push('黄绿色气体逐渐被吸收，所得溶液几乎无色');
    spec.safety.push('氯气有毒，制备与性质实验必须在通风橱中进行');
    return spec;
  }

  private static ammoniaOxidation(): ReactionSpec {
    const spec = reaction('nh3-oxidation', '氨的催化氧化', ReactionType.REDOX, '高中');
    spec.reactants.push(term('nh3', 4, ''), term('o2', 5, ''));
    spec.products.push(term('no', 4, ''), term('h2o', 6, ''));
    spec.conditions.push('铂铑催化剂', '加热');
    spec.phenomena.push('催化剂保持红热', '产生无色气体，接触空气后变为红棕色');
    spec.safety.push('生成的一氧化氮有毒，须在密闭装置中进行');
    return spec;
  }

  private static ethanolOxidation(): ReactionSpec {
    const spec = reaction('ethanol-oxidation', '乙醇的催化氧化', ReactionType.REDOX, '高中');
    spec.reactants.push(term('c2h5oh', 2, ''), term('o2', 1, ''));
    spec.products.push(term('ch3cho', 2, ''), term('h2o', 2, ''));
    spec.conditions.push('铜或银作催化剂', '加热');
    spec.phenomena.push('灼热的铜丝由黑色重新变为光亮红色', '闻到刺激性气味');
    spec.safety.push('乙醛易燃，操作远离明火');
    return spec;
  }

  private static esterification(): ReactionSpec {
    const spec = reaction('esterification', '乙酸与乙醇的酯化反应', ReactionType.ESTERIFICATION, '高中');
    spec.reactants.push(term('ch3cooh', 1, ''), term('c2h5oh', 1, ''));
    spec.products.push(term('ch3cooc2h5', 1, ''), term('h2o', 1, ''));
    spec.conditions.push('浓硫酸作催化剂和吸水剂', '加热');
    spec.reversible = true;
    spec.phenomena.push('饱和碳酸钠溶液液面上出现一层不溶于水的无色油状液体', '闻到果香味');
    spec.safety.push('导管口不能插入液面以下，防止倒吸');
    return spec;
  }

  private static methaneBurn(): ReactionSpec {
    const spec = reaction('ch4-burn', '甲烷在空气中燃烧', ReactionType.COMBUSTION, '高中');
    spec.reactants.push(term('ch4', 1, ''), term('o2', 2, ''));
    spec.products.push(term('co2', 1, ''), term('h2o', 2, ''));
    spec.conditions.push('点燃');
    spec.phenomena.push('产生淡蓝色火焰并放出大量热', '干冷烧杯内壁出现水珠',
      '倒入澄清石灰水后石灰水变浑浊');
    spec.safety.push('点燃前必须验纯');
    return spec;
  }

  // ---- 大学分析化学 --------------------------------------------------------

  private static permanganateTitration(): ReactionSpec {
    const spec = reaction('kmno4-oxalic', '高锰酸钾滴定草酸(酸性介质)', ReactionType.TITRATION, '大学');
    spec.reactants.push(term('mnov4', 2, ''), term('h2c2o4', 5, ''), term('hion', 6, ''));
    spec.products.push(term('mn2', 2, ''), term('co2', 10, '↑'), term('h2o', 8, ''));
    spec.conditions.push('硫酸酸化', '滴定');
    spec.phenomena.push('滴入的高锰酸钾紫红色迅速褪去', '接近终点时褪色明显变慢',
      '终点：滴入半滴后溶液呈浅紫红色且 30 秒内不褪');
    spec.safety.push('产物 Mn²⁺ 有自催化作用，滴定速度应先慢后快');
    return spec;
  }

  private static iodineThiosulfate(): ReactionSpec {
    const spec = reaction('iodine-thiosulfate', '硫代硫酸钠滴定碘', ReactionType.TITRATION, '大学');
    spec.reactants.push(term('i2', 1, ''), term('s2o3', 2, ''));
    spec.products.push(term('iion', 2, ''), term('s4o6', 1, ''));
    spec.conditions.push('淀粉作指示剂', '滴定');
    spec.phenomena.push('溶液蓝色逐渐变浅', '终点：蓝色恰好褪去且半分钟内不复色');
    spec.safety.push('临近终点才加入淀粉指示剂，否则碘被淀粉包裹导致终点迟钝');
    return spec;
  }

  // ---- 离子方程式 ----------------------------------------------------------

  private static carbonateIonic(): ReactionSpec {
    const spec = reaction('caco3-co2-ionic', '离子方程式', ReactionType.METATHESIS, '初中');
    spec.reactants.push(term('caco3', 1, ''), term('hion', 2, ''));
    spec.products.push(term('ca2', 1, ''), term('h2o', 1, ''), term('co2', 1, '↑'));
    return spec;
  }

  private static waterIonic(): ReactionSpec {
    const spec = reaction('hcl-naoh-ionic', '离子方程式', ReactionType.NEUTRALIZATION, '高中');
    spec.reactants.push(term('hion', 1, ''), term('ohion', 1, ''));
    spec.products.push(term('h2o', 1, ''));
    return spec;
  }

  private static bariumIonic(): ReactionSpec {
    const spec = reaction('bacl2-na2so4-ionic', '离子方程式', ReactionType.METATHESIS, '高中');
    spec.reactants.push(term('ba2', 1, ''), term('so4', 1, ''));
    spec.products.push(term('baso4', 1, '↓'));
    return spec;
  }

  private static silverIonic(): ReactionSpec {
    const spec = reaction('agno3-nacl-ionic', '离子方程式', ReactionType.METATHESIS, '高中');
    spec.reactants.push(term('agion', 1, ''), term('clion', 1, ''));
    spec.products.push(term('agcl', 1, '↓'));
    return spec;
  }

  private static copperIonic(): ReactionSpec {
    const spec = reaction('cuso4-naoh-ionic', '离子方程式', ReactionType.METATHESIS, '高中');
    spec.reactants.push(term('cu2', 1, ''), term('ohion', 2, ''));
    spec.products.push(term('cuoh2', 1, '↓'));
    return spec;
  }
}

/** 式量查询入口,供界面与限量计算共用。 */
export function massOf(key: string): number {
  return Formula.relativeMass(Reagents.get(key).formula);
}
