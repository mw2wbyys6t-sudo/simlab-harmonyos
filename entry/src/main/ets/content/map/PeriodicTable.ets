import { UNVERIFIED_PREFIX } from './CurriculumTypes';

/**
 * 化学元素周期表。
 *
 * 为什么单独建一张表而不是复用 `Formula.ets` 里的 `AtomicMassTable`:那张表只有
 * 32 种元素的**取整**原子量,是给式量计算用的工作表,不是元素知识;而周期表要回答的是
 * 「它在第几周期第几族、常温什么状态、常见几价」——那是学生要查的东西。
 *
 * 两张表**必须互相校准**,这是本模块最有价值的一条断言:同一个元素的相对原子质量
 * 若在两处不一致,说明有一处录错了元素或点错小数点。`AtomicMassTable` 按整数取整,
 * 所以允许的差是 0.6(四舍五入的半 + 余量);任何小于 0.6 的差都不算录错。
 *
 * 覆盖面:118 种全收(含人造超重元素)。相对原子质量取教学常用值(4~5 位有效数字),
 * 排布与族位按长式周期表。**未逐项对照 IUPAC 最新表**,故 `verified` 为假。
 */
export class ChemicalElement {
  /** 原子序数,1..118,唯一 */
  number: number = 0;
  /** 元素符号,首字母大写;唯一 */
  symbol: string = '';
  /** 中文名 */
  name: string = '';
  /** 相对原子质量(教学常用值) */
  mass: number = 0;
  /** 周期 1..7 */
  period: number = 0;
  /** 族,长式表按 IUPAC 1..18;镧系系统一记 3 */
  group: number = 0;
  /** 区:s / p / d / f */
  block: string = '';
  /** 常温常压状态:气 / 液 / 固 */
  state: string = '';
  /** 金属 / 非金属 / 类金属 */
  kind: string = '';
  /** 常见化合价;0 表示无稳定化合价(稀有气体与放射性人造元素) */
  valences: number[] = [];
  /** 教学提示,可为空 */
  note: string = '';
  source: string = '';
  verified: boolean = false;

  /**
   * 化合价的显示串。正负号必须写出来 ——「+2」和「2」在化学里不是同一个意思,
   * 裸数字会被读成"有 2 个价态"。空数组按数据层的约定是"无稳定化合价"(稀有气体与人造元素)。
   */
  valenceLabel(): string {
    if (this.valences.length === 0) {
      return '无稳定化合价';
    }
    const parts: string[] = [];
    for (let i = 0; i < this.valences.length; i++) {
      const v = this.valences[i];
      parts.push(v > 0 ? '+' + String(v) : String(v));
    }
    return parts.join('、');
  }
}

const COVERAGE: string = UNVERIFIED_PREFIX + '教学常用值与长式周期表编排,未逐项对照 IUPAC';

function el(n: number, symbol: string, name: string, mass: number, period: number,
  group: number, block: string, state: string, kind: string, valences: number[],
  note: string): ChemicalElement {
  const e = new ChemicalElement();
  e.number = n;
  e.symbol = symbol;
  e.name = name;
  e.mass = mass;
  e.period = period;
  e.group = group;
  e.block = block;
  e.state = state;
  e.kind = kind;
  e.valences = valences;
  e.note = note;
  e.source = COVERAGE;
  e.verified = false;
  return e;
}

const NONE: number[] = [];
const GAS = '气';
const LIQ = '液';
const SOL = '固';
const METAL = '金属';
const NONMETAL = '非金属';
const METALLOID = '类金属';

export class PeriodicTable {
  /** 第 1–3 周期:主族骨架,也是初中到高一最常引用的部分 */
  static lightElements(): ChemicalElement[] {
    return [
      el(1, 'H', '氢', 1.008, 1, 1, 's', GAS, NONMETAL, [-1, 1], '唯一没有中子的常见核素是氕'),
      el(2, 'He', '氦', 4.003, 1, 18, 's', GAS, NONMETAL, NONE, '只有 1s²,放在 18 族按稀有气体'),
      el(3, 'Li', '锂', 6.941, 2, 1, 's', SOL, METAL, [1], '密度最小的金属'),
      el(4, 'Be', '铍', 9.012, 2, 2, 's', SOL, METAL, [2], '化合物有毒'),
      el(5, 'B', '硼', 10.81, 2, 13, 'p', SOL, METALLOID, [3], ''),
      el(6, 'C', '碳', 12.011, 2, 14, 'p', SOL, NONMETAL, [-4, 2, 4], '相对原子质量的定义基准(12C = 12)'),
      el(7, 'N', '氮', 14.007, 2, 15, 'p', GAS, NONMETAL, [-3, 2, 4, 5], 'N≡N 键能大,故 N₂ 惰性'),
      el(8, 'O', '氧', 15.999, 2, 16, 'p', GAS, NONMETAL, [-2], '除氟外与多数元素成负价'),
      el(9, 'F', '氟', 18.998, 2, 17, 'p', GAS, NONMETAL, [-1], '无正价,电负性最大'),
      el(10, 'Ne', '氖', 20.180, 2, 18, 'p', GAS, NONMETAL, NONE, ''),
      el(11, 'Na', '钠', 22.990, 3, 1, 's', SOL, METAL, [1], '保存在煤油中'),
      el(12, 'Mg', '镁', 24.305, 3, 2, 's', SOL, METAL, [2], '燃烧不能用 CO₂ 灭'),
      el(13, 'Al', '铝', 26.982, 3, 13, 'p', SOL, METAL, [3], '表面氧化膜致密而耐蚀'),
      el(14, 'Si', '硅', 28.085, 3, 14, 'p', SOL, METALLOID, [4], ''),
      el(15, 'P', '磷', 30.974, 3, 15, 'p', SOL, NONMETAL, [-3, 3, 5], '白磷保存在水中'),
      el(16, 'S', '硫', 32.06, 3, 16, 'p', SOL, NONMETAL, [-2, 4, 6], ''),
      el(17, 'Cl', '氯', 35.45, 3, 17, 'p', GAS, NONMETAL, [-1, 1, 5, 7], '教学式量常取 35.5'),
      el(18, 'Ar', '氩', 39.948, 3, 18, 'p', GAS, NONMETAL, NONE, '')
    ];
  }

  /** 第 4 周期:第一次出现 d 区,也是变价最密集的一段 */
  static firstTransitionRow(): ChemicalElement[] {
    return [
      el(19, 'K', '钾', 39.098, 4, 1, 's', SOL, METAL, [1], ''),
      el(20, 'Ca', '钙', 40.078, 4, 2, 's', SOL, METAL, [2], ''),
      el(21, 'Sc', '钪', 44.956, 4, 3, 'd', SOL, METAL, [3], ''),
      el(22, 'Ti', '钛', 47.867, 4, 4, 'd', SOL, METAL, [4], '耐蚀、轻,用于航空'),
      el(23, 'V', '钒', 50.942, 4, 5, 'd', SOL, METAL, [2, 3, 4, 5], ''),
      el(24, 'Cr', '铬', 51.996, 4, 6, 'd', SOL, METAL, [2, 3, 6], '价电子排布 3d⁵4s¹ 是半满特例'),
      el(25, 'Mn', '锰', 54.938, 4, 7, 'd', SOL, METAL, [2, 4, 6, 7], 'KMnO₄ 中为 +7'),
      el(26, 'Fe', '铁', 55.845, 4, 8, 'd', SOL, METAL, [2, 3], 'Fe³⁺ 比 Fe²⁺ 稳定(3d⁵ 半满)'),
      el(27, 'Co', '钴', 58.933, 4, 9, 'd', SOL, METAL, [2, 3], ''),
      el(28, 'Ni', '镍', 58.693, 4, 10, 'd', SOL, METAL, [2, 3], ''),
      el(29, 'Cu', '铜', 63.546, 4, 11, 'd', SOL, METAL, [1, 2], '价电子 3d¹⁰4s¹ 是全满特例'),
      el(30, 'Zn', '锌', 65.38, 4, 12, 'd', SOL, METAL, [2], 'd 全满,不算过渡金属的严格定义成员'),
      el(31, 'Ga', '镓', 69.723, 4, 13, 'p', SOL, METAL, [3], '熔点约 30 ℃,手心可熔'),
      el(32, 'Ge', '锗', 72.64, 4, 14, 'p', SOL, METALLOID, [4], ''),
      el(33, 'As', '砷', 74.922, 4, 15, 'p', SOL, METALLOID, [3, 5], '单质与化合物有毒'),
      el(34, 'Se', '硒', 78.96, 4, 16, 'p', SOL, NONMETAL, [-2, 4, 6], ''),
      el(35, 'Br', '溴', 79.904, 4, 17, 'p', LIQ, NONMETAL, [-1, 1, 5], '常温唯一液态非金属'),
      el(36, 'Kr', '氪', 83.798, 4, 18, 'p', GAS, NONMETAL, NONE, '')
    ];
  }

  /** 第 5 周期 */
  static secondTransitionRow(): ChemicalElement[] {
    return [
      el(37, 'Rb', '铷', 85.468, 5, 1, 's', SOL, METAL, [1], ''),
      el(38, 'Sr', '锶', 87.62, 5, 2, 's', SOL, METAL, [2], '焰色砖红'),
      el(39, 'Y', '钇', 88.906, 5, 3, 'd', SOL, METAL, [3], ''),
      el(40, 'Zr', '锆', 91.224, 5, 4, 'd', SOL, METAL, [4], ''),
      el(41, 'Nb', '铌', 92.906, 5, 5, 'd', SOL, METAL, [5], ''),
      el(42, 'Mo', '钼', 95.96, 5, 6, 'd', SOL, METAL, [6], ''),
      el(43, 'Tc', '锝', 98, 5, 7, 'd', SOL, METAL, [4, 6, 7], '第一个人造元素,无稳定同位素'),
      el(44, 'Ru', '钌', 101.07, 5, 8, 'd', SOL, METAL, [3, 4], ''),
      el(45, 'Rh', '铑', 102.906, 5, 9, 'd', SOL, METAL, [3, 4], ''),
      el(46, 'Pd', '钯', 106.42, 5, 10, 'd', SOL, METAL, [2, 4], '吸氢能力最强'),
      el(47, 'Ag', '银', 107.868, 5, 11, 'd', SOL, METAL, [1], '导电性最好的金属'),
      el(48, 'Cd', '镉', 112.414, 5, 12, 'd', SOL, METAL, [2], '剧毒,电池污染重点'),
      el(49, 'In', '铟', 114.818, 5, 13, 'p', SOL, METAL, [3], ''),
      el(50, 'Sn', '锡', 118.710, 5, 14, 'p', SOL, METAL, [2, 4], '低温下粉化即"锡疫"'),
      el(51, 'Sb', '锑', 121.760, 5, 15, 'p', SOL, METALLOID, [3, 5], ''),
      el(52, 'Te', '碲', 127.60, 5, 16, 'p', SOL, METALLOID, [-2, 4, 6], ''),
      el(53, 'I', '碘', 126.904, 5, 17, 'p', SOL, NONMETAL, [-1, 1, 5, 7], '易升华,淀粉遇碘变蓝'),
      el(54, 'Xe', '氙', 131.293, 5, 18, 'p', GAS, NONMETAL, [2, 4, 6], '稀有气体中较早被化合的一族')
    ];
  }

  /** 第 6 周期:含镧系(57–71 统一记 3 族、f 区) */
  static sixthRow(): ChemicalElement[] {
    return [
      el(55, 'Cs', '铯', 132.905, 6, 1, 's', SOL, METAL, [1], '金属性最强的稳定元素'),
      el(56, 'Ba', '钡', 137.327, 6, 2, 's', SOL, METAL, [2], 'Ba²⁺ 有毒,BaSO₄ 不溶故可造影'),
      el(57, 'La', '镧', 138.905, 6, 3, 'f', SOL, METAL, [3], ''),
      el(58, 'Ce', '铈', 140.116, 6, 3, 'f', SOL, METAL, [3, 4], ''),
      el(59, 'Pr', '镨', 140.908, 6, 3, 'f', SOL, METAL, [3], ''),
      el(60, 'Nd', '钕', 144.242, 6, 3, 'f', SOL, METAL, [3], '强磁 NdFeB'),
      el(61, 'Pm', '钷', 145, 6, 3, 'f', SOL, METAL, [3], '无稳定同位素'),
      el(62, 'Sm', '钐', 150.36, 6, 3, 'f', SOL, METAL, [3], ''),
      el(63, 'Eu', '铕', 151.964, 6, 3, 'f', SOL, METAL, [2, 3], ''),
      el(64, 'Gd', '钆', 157.25, 6, 3, 'f', SOL, METAL, [3], ''),
      el(65, 'Tb', '铽', 158.925, 6, 3, 'f', SOL, METAL, [3], ''),
      el(66, 'Dy', '镝', 162.500, 6, 3, 'f', SOL, METAL, [3], ''),
      el(67, 'Ho', '钬', 164.930, 6, 3, 'f', SOL, METAL, [3], ''),
      el(68, 'Er', '铒', 167.259, 6, 3, 'f', SOL, METAL, [3], ''),
      el(69, 'Tm', '铥', 168.934, 6, 3, 'f', SOL, METAL, [3], ''),
      el(70, 'Yb', '镱', 173.054, 6, 3, 'f', SOL, METAL, [2, 3], ''),
      el(71, 'Lu', '镥', 174.967, 6, 3, 'f', SOL, METAL, [3], ''),
      el(72, 'Hf', '铪', 178.49, 6, 4, 'd', SOL, METAL, [4], ''),
      el(73, 'Ta', '钽', 180.948, 6, 5, 'd', SOL, METAL, [5], ''),
      el(74, 'W', '钨', 183.84, 6, 6, 'd', SOL, METAL, [6], '熔点最高的金属'),
      el(75, 'Re', '铼', 186.207, 6, 7, 'd', SOL, METAL, [7], ''),
      el(76, 'Os', '锇', 190.23, 6, 8, 'd', SOL, METAL, [4], '密度最大的一类'),
      el(77, 'Ir', '铱', 192.217, 6, 9, 'd', SOL, METAL, [3, 4], ''),
      el(78, 'Pt', '铂', 195.084, 6, 10, 'd', SOL, METAL, [2, 4], ''),
      el(79, 'Au', '金', 196.967, 6, 11, 'd', SOL, METAL, [1, 3], '只溶于王水等少数体系'),
      el(80, 'Hg', '汞', 200.592, 6, 12, 'd', LIQ, METAL, [1, 2], '常温唯一液态金属'),
      el(81, 'Tl', '铊', 204.383, 6, 13, 'p', SOL, METAL, [1, 3], '剧毒'),
      el(82, 'Pb', '铅', 207.2, 6, 14, 'p', SOL, METAL, [2, 4], '＋2 比 ＋4 稳定(惰性电子对)'),
      el(83, 'Bi', '铋', 208.980, 6, 15, 'p', SOL, METAL, [3, 5], ''),
      el(84, 'Po', '钋', 209, 6, 16, 'p', SOL, METAL, [-2, 4, 6], '放射性'),
      el(85, 'At', '砹', 210, 6, 17, 'p', SOL, METALLOID, [-1, 1], '放射性,最稀有的天然元素之一'),
      el(86, 'Rn', '氡', 222, 6, 18, 'p', GAS, NONMETAL, NONE, '放射性,室内氡是主要来源之一')
    ];
  }

  /**
   * 第 7 周期(87–118,含锕系)。
   *
   * 这一段有两处要交代清楚:**质量数取最长寿命同位素**(没有稳定核素,不存在"相对原子质量"
   * 的常规意义);**104–118 的中文名按中国化学会 2017 年公布的命名,未逐字核对**,
   * 且这些字多在 CJK 扩展区,字体缺字时会显示成方框 —— 浏览页要做字体回退,不能假定一定能渲染。
   */
  static seventhRow(): ChemicalElement[] {
    const RADIO = '放射性元素,无稳定同位素';
    return [
      el(87, 'Fr', '钫', 223, 7, 1, 's', SOL, METAL, [1], RADIO),
      el(88, 'Ra', '镭', 226, 7, 2, 's', SOL, METAL, [2], RADIO),
      el(89, 'Ac', '锕', 227, 7, 3, 'f', SOL, METAL, [3], RADIO),
      el(90, 'Th', '钍', 232.038, 7, 3, 'f', SOL, METAL, [4], '有天然长寿命同位素'),
      el(91, 'Pa', '镤', 231.036, 7, 3, 'f', SOL, METAL, [5], ''),
      el(92, 'U', '铀', 238.029, 7, 3, 'f', SOL, METAL, [3, 4, 5, 6], '天然存在的最重元素'),
      el(93, 'Np', '镎', 237, 7, 3, 'f', SOL, METAL, [4, 5, 6], RADIO),
      el(94, 'Pu', '钚', 244, 7, 3, 'f', SOL, METAL, [4, 5, 6], RADIO),
      el(95, 'Am', '镅', 243, 7, 3, 'f', SOL, METAL, [3, 5, 6], RADIO),
      el(96, 'Cm', '锔', 247, 7, 3, 'f', SOL, METAL, [3], RADIO),
      el(97, 'Bk', '锫', 247, 7, 3, 'f', SOL, METAL, [3, 4], RADIO),
      el(98, 'Cf', '锎', 251, 7, 3, 'f', SOL, METAL, [3], RADIO),
      el(99, 'Es', '锿', 252, 7, 3, 'f', SOL, METAL, [3], RADIO),
      el(100, 'Fm', '镄', 257, 7, 3, 'f', SOL, METAL, [3], RADIO),
      el(101, 'Md', '钔', 258, 7, 3, 'f', SOL, METAL, [3], RADIO),
      el(102, 'No', '锘', 259, 7, 3, 'f', SOL, METAL, [2, 3], RADIO),
      el(103, 'Lr', '铹', 266, 7, 3, 'f', SOL, METAL, [3], RADIO),
      el(104, 'Rf', '', 267, 7, 4, 'd', SOL, METAL, [4], RADIO),
      el(105, 'Db', '𬭊', 268, 7, 5, 'd', SOL, METAL, [5], RADIO),
      el(106, 'Sg', '𬭳', 269, 7, 6, 'd', SOL, METAL, [6], RADIO),
      el(107, 'Bh', '𬭛', 270, 7, 7, 'd', SOL, METAL, [7], RADIO),
      el(108, 'Hs', '𬭶', 277, 7, 8, 'd', SOL, METAL, NONE, RADIO),
      el(109, 'Mt', '鿏', 278, 7, 9, 'd', SOL, METAL, NONE, RADIO),
      el(110, 'Ds', '𫟼', 281, 7, 10, 'd', SOL, METAL, NONE, RADIO),
      el(111, 'Rg', '𬬭', 282, 7, 11, 'd', SOL, METAL, NONE, RADIO),
      el(112, 'Cn', '鿔', 285, 7, 12, 'd', SOL, METAL, [2], RADIO),
      el(113, 'Nh', '鿭', 286, 7, 13, 'p', SOL, METAL, [1], RADIO),
      el(114, 'Fl', '𫓧', 289, 7, 14, 'p', SOL, METAL, [2], RADIO),
      el(115, 'Mc', '镆', 290, 7, 15, 'p', SOL, METAL, [1], RADIO),
      el(116, 'Lv', '𫟷', 293, 7, 16, 'p', SOL, METAL, [2], RADIO),
      el(117, 'Ts', '鿬', 294, 7, 17, 'p', SOL, METAL, [-1], RADIO),
      el(118, 'Og', '鿫', 294, 7, 18, 'p', SOL, NONMETAL, NONE, RADIO)
    ];
  }

  static all(): ChemicalElement[] {
    return PeriodicTable.lightElements().concat(PeriodicTable.firstTransitionRow())
      .concat(PeriodicTable.secondTransitionRow()).concat(PeriodicTable.sixthRow())
      .concat(PeriodicTable.seventhRow());
  }
}
