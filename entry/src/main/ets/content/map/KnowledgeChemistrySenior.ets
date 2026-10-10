import { KnowledgePoint, KnowledgeLevel, makeKnowledge } from './KnowledgeTypes';
import { MapSubject, SchoolStage } from './CurriculumTypes';

/**
 * 高中化学知识点(人教版)。
 *
 * **`course` 用册次而不是大学那种「无机化学/有机化学」口径**,因为高中课程地图的分组轴就是册次:
 * 必修第一册 / 必修第二册 / 选择性必修一(化学反应原理) / 选择性必修二(物质结构与性质) /
 * 选择性必修三(有机化学基础)。`chapter` 用各册的章名。
 *
 * **`source` 只为覆盖面与顺序作证,不为化学内容作证。** 一条 statement 是否成立靠专业判断和
 * 离线断言核,不靠引用;这里要说清的是「高中化学确实教这些、按这个册次与章序排」。
 *
 * 章名照人教版(2019)五册的目录取:必修一 = 物质及其变化 / 海水中的重要元素(全名带「——钠和氯」)/
 * 铁 金属材料 / 物质结构 元素周期律,必修二 = 化工生产中的重要非金属元素 / 化学反应与能量 /
 * 有机化合物 / 化学与可持续发展,选必一 = 化学反应的热效应 / 化学反应速率与化学平衡 /
 * 水溶液中的离子反应与平衡 / 化学反应与电能,选必二 = 原子结构与性质 / 分子结构与性质 /
 * 晶体结构与性质,选必三 = 有机化合物的结构特点与研究方法 / 烃 / 烃的衍生物 / 生物大分子 /
 * 合成高分子。两处与旧教材不同名、值得接线时逐条判:①选必一第一章 2019 版叫「化学反应的热效应」,
 * 旧选修4 与《课标》主题名都作「化学反应与能量」(后者现在落在必修二第六章);②选必一第四章叫
 * 「化学反应与电能」,旧选修4 叫「电化学基础」。另外「物质的量」在必修一第二章第三节,
 * 「原子结构与元素周期表」在必修一第四章而不是选必二 —— 选必二讲的是能层能级、排布式这一层。
 * 这些章名经在线教材目录页(haoduoyun.cc、keben1.com)核实,**但未核对纸质教材目录与《课程标准》原文》。
 *
 * 一条原则:前置只引用**本文件内序号更小的 id**(001–053)。初中化学 `kn-chem-jr-*` 与大学化学
 * `kn-chem-u-*` 讲的是同一件事的更浅或更深版本,但跨文件引用会被 MapValidator 判成悬挂引用 ——
 * 各张表各自成链,不做跨表跳转。
 *
 * 有意没写的:过滤、蒸发、气密性检查、试纸的完整操作流程(它们是操作技能,判不了对错)、
 * 元素推断与「守恒法」解题技巧(是题法而不是知识点)、研究有机化合物的一般方法中的
 * 蒸馏/重结晶/质谱操作(同样偏流程,只把命名与同分异构留作知识点)、化学电源的电池型号细节
 * (并入原电池那条的迁移情境)。
 */
const CHEM: MapSubject = MapSubject.CHEMISTRY;
const SR: SchoolStage = SchoolStage.SENIOR;
const COVERAGE: string = '章名与顺序按人教版(2019)高中化学教材编排,经在线教材目录页核实,未核对纸质教材与课标原文';

function k(id: string, course: string, chapter: string, title: string, statement: string,
  symbols: string[], level: KnowledgeLevel, prereq: string[]): KnowledgePoint {
  return makeKnowledge(id, CHEM, SR, course, chapter, title, statement, symbols,
    level, prereq, COVERAGE);
}

export class KnowledgeChemistrySenior {
  static readonly REQUIRED_ONE: string = '必修第一册';
  static readonly REQUIRED_TWO: string = '必修第二册';
  static readonly ELECTIVE_ONE: string = '选择性必修一';
  static readonly ELECTIVE_TWO: string = '选择性必修二';
  static readonly ELECTIVE_THREE: string = '选择性必修三';

  /** 必修一 第一章:物质的分类、离子反应与氧化还原反应 */
  static matterAndChanges(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-chem-sr-001', KnowledgeChemistrySenior.REQUIRED_ONE, '物质及其变化', '分散系的分类依据与胶体的丁达尔效应',
      '溶液、胶体与浊液的本质区别是分散质粒子直径的大小(溶液小于 1 nm、胶体 1~100 nm、浊液大于 100 nm),而不是能否透过滤纸;丁达尔效应只是区分胶体与溶液的常用方法,不能当作分类依据。胶体粒子能透过滤纸却透不过半透膜,故可用渗析提纯胶体;向 Fe(OH)3 胶体加电解质会聚沉,这是明矾净水与豆浆点卤的共同原理',
      ['1~100 nm', '丁达尔效应'], KnowledgeLevel.RECALL, []));
    out.push(k('kn-chem-sr-002', KnowledgeChemistrySenior.REQUIRED_ONE, '物质及其变化', '电解质看自身能否电离,导电能力看离子浓度',
      '电解质与非电解质研究的都是化合物:铜、氯气、石墨属单质,既不是电解质也不是非电解质;CO2、SO2、NH3 的水溶液能导电,但电离出离子的是它们与水反应的产物,它们本身仍是非电解质;BaSO4 虽难溶,溶解的部分却完全电离且熔融态导电,仍是电解质。溶液导电能力强弱取决于自由移动离子的浓度和离子所带电荷数,与电解质强弱没有必然联系,所以极稀盐酸的导电性可能弱于较浓的醋酸,不能由导电性强弱反推电解质强弱',
      ['自由移动的离子', '导电性 ∝ c(离子)·电荷数'], KnowledgeLevel.APPLY, ['kn-chem-sr-001']));
    out.push(k('kn-chem-sr-003', KnowledgeChemistrySenior.REQUIRED_ONE, '物质及其变化', '离子方程式的拆分规则与守恒检查',
      '强酸、强碱、可溶性盐拆成离子,单质、氧化物、气体、难溶物和弱电解质(水、醋酸、一水合氨)必须保留化学式;浓硫酸主要以分子存在不拆,石灰乳是悬浊液不拆而澄清石灰水要拆。检查正误要依次核对原子守恒、电荷守恒、得失电子守恒,还要看是否符合物质的组成配比,把 Ba(OH)2 与 H2SO4 写成只生成 BaSO4 或只生成 H2O 都是漏掉了另一半',
      ['原子守恒', '电荷守恒'], KnowledgeLevel.APPLY, ['kn-chem-sr-002']));
    out.push(k('kn-chem-sr-004', KnowledgeChemistrySenior.REQUIRED_ONE, '物质及其变化', '离子共存判断的是能否反应而不是溶液颜色',
      '能否共存只看离子之间是否发生反应(生成沉淀、气体、弱电解质,或发生氧化还原、络合),溶液有没有颜色本身不是判据,只有题面加了「无色透明」才排除 Cu2+、Fe3+、MnO4- 等。隐含条件要双向验证:与铝反应放出氢气的溶液既可能是强酸也可能是强碱;NO3- 只有在酸性条件下才显强氧化性,故它与 Fe2+ 能否共存取决于酸碱性;Fe3+ 与 I-、S2- 是因氧化还原而不共存,漏想这一类是最大失分点',
      ['隐含条件', '氧化还原型不共存'], KnowledgeLevel.TRANSFER, ['kn-chem-sr-003']));
    out.push(k('kn-chem-sr-005', KnowledgeChemistrySenior.REQUIRED_ONE, '物质及其变化', '氧化还原反应的概念对应与强弱规律',
      '化合价升降是特征、电子转移是本质;化合价升高的一极失电子、被氧化、作还原剂、得到氧化产物,四者必须一一对应不能记反。由反应方向可比强弱:氧化剂的氧化性强于氧化产物,还原剂的还原性强于还原产物。氧化性强弱取决于得到电子的难易而不是数目,同种元素价态高也不一定氧化性强,例如 Cl(+7) 的 HClO4 在稀溶液中氧化性远弱于 HClO',
      ['升—失—氧化—还原剂', 'n(失电子) = n(得电子)'], KnowledgeLevel.APPLY, ['kn-chem-sr-002']));
    return out;
  }

  /** 必修一 第二章:钠、氯与物质的量(含溶液配制) */
  static seawaterElementsAndAmount(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-chem-sr-006', KnowledgeChemistrySenior.REQUIRED_ONE, '海水中的重要元素', '钠与水的反应及过氧化钠的供氧',
      '钠与水反应的现象与性质一一对应:浮(密度小于水)、熔(熔点低且反应放热)、游、响、红(生成 NaOH 使酚酞变红),所以钠只能保存在煤油里隔绝空气和水;钠投入盐溶液时先与水反应,置换不出盐中的金属,投入 CuSO4 溶液得到的是 Cu(OH)2 沉淀和氢气。Na2O2 中氧为 −1 价,与 H2O、CO2 反应时自身歧化为 0 价与 −2 价,每生成 1 mol O2 转移 2 mol 电子;因为产物除盐之外还有氧气,它不属于碱性氧化物',
      ['2Na2O2 + 2CO2 = 2Na2CO3 + O2', '保存于煤油'], KnowledgeLevel.APPLY, ['kn-chem-sr-005']));
    out.push(k('kn-chem-sr-007', KnowledgeChemistrySenior.REQUIRED_ONE, '海水中的重要元素', '碳酸钠与碳酸氢钠的鉴别、转化与焰色试验',
      'NaHCO3 受热易分解、与酸反应更快,Na2CO3 与盐酸反应要先生成 NaHCO3 才放出 CO2,所以逐滴加入盐酸时立即冒气泡的是 NaHCO3;加 CaCl2 或 BaCl2 溶液产生沉淀的是 Na2CO3,而两者都能使澄清石灰水变浑浊,故不能用 Ca(OH)2 鉴别。除杂时向 Na2CO3 溶液通入过量 CO2 可得 NaHCO3,加热固体则反向转化;钠盐与钾盐靠焰色试验区分,观察钾的紫色必须透过蓝色钴玻璃以滤去钠的黄光',
      ['2NaHCO3 →(△) Na2CO3 + CO2↑ + H2O', '钾:透过蓝色钴玻璃'], KnowledgeLevel.APPLY, ['kn-chem-sr-003']));
    out.push(k('kn-chem-sr-008', KnowledgeChemistrySenior.REQUIRED_ONE, '海水中的重要元素', '氯水的成分与干燥氯气没有漂白性',
      '氯气是强氧化剂,与变价金属反应一般生成高价氯化物(Fe 生成 FeCl3 而不是 FeCl2),据此可判断 Cl2 的氧化性强于 S 与 H+。新制氯水中同时存在 Cl2、HClO、H2O 三种分子与 H+、Cl-、ClO-、OH- 四种离子,因而兼具酸性、强氧化性与漂白性,但漂白与杀菌来自 HClO 而不是 Cl2,所以干燥氯气不能使干燥的有色布条褪色、却能漂白湿润布条;久置氯水因 HClO 见光分解而变成稀盐酸,故氯水须避光保存',
      ['Cl2 + H2O ⇌ HCl + HClO', '2HClO →(光照) 2HCl + O2↑'], KnowledgeLevel.APPLY, ['kn-chem-sr-005']));
    out.push(k('kn-chem-sr-009', KnowledgeChemistrySenior.REQUIRED_ONE, '海水中的重要元素', '物质的量换算与 22.4 L/mol 的两个前提',
      '物质的量把微观粒子数与宏观可称量物质连成一线:n = m/M = V/Vm = c·V,用 mol 必须指明基本单元,1 mol O 与 1 mol O2 含义不同。摩尔质量在数值上等于该粒子的相对原子(分子)质量,但单位是 g/mol 而不是 1,两者数值相等而意义不同。22.4 L/mol 必须同时满足「标准状况」与「气体」两个前提,标况下的水、SO3、CCl4 不能代它计算;NA 类判断还常设可逆反应电子转移数、盐类水解、胶体粒子数等陷阱',
      ['n = m/M = V/Vm = c·V', 'Vm = 22.4 L/mol(标况)'], KnowledgeLevel.APPLY, []));
    out.push(k('kn-chem-sr-010', KnowledgeChemistrySenior.REQUIRED_ONE, '海水中的重要元素', '容量瓶配制溶液的步骤与误差分析',
      '容量瓶只用于定容:不能用来溶解或稀释、不能加热、不能长期存放溶液,使用前必须检漏;溶解在烧杯中进行并冷却到室温,转移后要洗涤烧杯和玻璃棒 2~3 次并把洗涤液一并转移,加水至距刻度线 1~2 cm 时改用胶头滴管定容。误差分析的统一办法是看错误操作改变的是 n 还是 V,再由 c = n/V 定方向:俯视刻度线使体积偏小而浓度偏高,仰视偏低;未洗涤、砝码生锈、转移时溅出各有不同方向;摇匀后液面下降再加水则浓度偏低',
      ['c = n/V', '俯视 → V 偏小 → c 偏高'], KnowledgeLevel.TRANSFER, ['kn-chem-sr-009']));
    return out;
  }

  /** 必修一 第三章 + 第四章:金属材料与物质结构 */
  static metalsAndAtomicStructure(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-chem-sr-011', KnowledgeChemistrySenior.REQUIRED_ONE, '铁 金属材料', '氧化剂强弱决定铁显二价还是三价',
      '铁与强氧化剂(Cl2、硝酸、热的浓硫酸)反应生成 +3 价,与弱氧化剂(S、H+、Cu2+)反应只生成 +2 价,所以变价金属的产物价态是氧化剂强弱的证据。常温下铁、铝遇浓硫酸、浓硝酸发生钝化,是表面生成致密氧化膜的电化学与化学变化而不是不反应,因此可用铝槽车运输浓硫酸;铁在纯氧中燃烧的产物是 Fe3O4 而不是 Fe2O3,与水蒸气反应也生成 Fe3O4 并放出 H2',
      ['3Fe + 4H2O(g) →(高温) Fe3O4 + 4H2', '钝化 ≠ 不反应'], KnowledgeLevel.APPLY, ['kn-chem-sr-005', 'kn-chem-sr-008']));
    out.push(k('kn-chem-sr-012', KnowledgeChemistrySenior.REQUIRED_ONE, '铁 金属材料', 'Fe2+ 与 Fe3+ 的检验与相互转化',
      'KSCN 只能直接检验 Fe3+(溶液变血红),检验 Fe2+ 要么先加 KSCN 无现象再滴氯水变红,要么用酸性 KMnO4 褪色证明其还原性;加 NaOH 时白色絮状沉淀迅速变灰绿、最终变红褐色,是 Fe2+ 的特征现象。Fe2+ 有还原性,其溶液要加稀酸抑制水解并放铁钉防止被氧化;Fe3+ 有氧化性,能氧化 I-、腐蚀铜制印刷线路板,向含 Fe3+ 的溶液加铁粉可把 Fe3+ 转回 Fe2+,这一步除杂不能改用铜片因为会引入 Cu2+',
      ['Fe3+ + 3SCN- → 血红色', '2Fe3+ + Cu = 2Fe2+ + Cu2+'], KnowledgeLevel.TRANSFER, ['kn-chem-sr-011', 'kn-chem-sr-005']));
    out.push(k('kn-chem-sr-013', KnowledgeChemistrySenior.REQUIRED_ONE, '铁 金属材料', '铝与氧化铝、氢氧化铝的两性',
      'Al、Al2O3、Al(OH)3 都能同时与强酸和强碱反应,属两性;但铝在常温下遇浓硝酸、浓硫酸只是钝化而不是溶解。铝与强碱溶液反应时氧化剂是 H2O 而不是 OH-,等质量的铝分别与足量盐酸、足量 NaOH 溶液反应放出的氢气一样多。制 Al(OH)3 宜用铝盐加氨水而不能用过量 NaOH,否则会溶解;铝热反应利用铝的强还原性和反应放出的高温冶炼高熔点金属、焊接钢轨;铝合金密度小而强度高,表面致密氧化膜使铝耐蚀,也因此不宜长时间盛放酸性或碱性食物',
      ['2Al + 2OH- + 2H2O = 2AlO2- + 3H2↑'], KnowledgeLevel.APPLY, ['kn-chem-sr-003', 'kn-chem-sr-011']));
    out.push(k('kn-chem-sr-014', KnowledgeChemistrySenior.REQUIRED_ONE, '物质结构 元素周期律', '元素、核素与同位素的从属关系',
      '质子数决定元素种类,质子数与中子数共同决定核素种类:质子数相同而中子数不同的同一类原子互为同位素,同位素的化学性质几乎相同(核外电子排布相同)而质量、放射性等物理性质不同,同位素之间的转化属核变化而不是化学变化。质量数 A = 质子数 Z + 中子数 N,它不是相对原子质量。H、D、T 是三种核素,16O、17O、18O 互为同位素,而 O2 与 O3 是同素异形体,不能混称同位素',
      ['A = Z + N', '1H、2H、3H 互称同位素'], KnowledgeLevel.RECALL, []));
    out.push(k('kn-chem-sr-015', KnowledgeChemistrySenior.REQUIRED_ONE, '物质结构 元素周期律', '元素周期律的递变与金属性强弱判据',
      '同周期主族元素从左到右核电荷数递增、半径减小、得电子能力增强,金属性减弱而非金属性增强;同主族从上到下电子层数增多、半径增大、失电子能力增强。判金属性强弱要看与水或酸置换氢的难易、最高价氧化物对应水化物的碱性强弱、能否发生金属间的置换;判非金属性要看与 H2 化合的难易、气态氢化物的稳定性、最高价含氧酸的酸性。元素最高正价一般等于主族序数,但 O 无最高正价、F 无正价,不能套公式',
      ['同周期左→右金属性减弱', '同主族上→下金属性增强'], KnowledgeLevel.TRANSFER, ['kn-chem-sr-014']));
    out.push(k('kn-chem-sr-016', KnowledgeChemistrySenior.REQUIRED_ONE, '物质结构 元素周期律', '含共价键的离子化合物与化学键断裂不等于化学变化',
      '离子键是阴、阳离子间的静电作用,共价键靠共用电子对形成:含离子键的一定是离子化合物,而离子化合物也可以含共价键(NaOH、Na2O2、NH4Cl),共价化合物中一定不含离子键。活泼金属与活泼非金属之间也不一定就是离子键,AlCl3 是共价化合物。化学键断裂不一定发生化学变化:NaCl 熔化只破坏离子键、HCl 溶于水只破坏共价键,而碘升华或干冰气化只克服分子间作用力,不涉及化学键',
      ['离子键/共价键/金属键', 'NH4Cl 既含共价键又含离子键'], KnowledgeLevel.APPLY, ['kn-chem-sr-015']));
    return out;
  }

  /** 必修二 第五章:硫、氮、硅及其化合物 */
  static nonmetalElements(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-chem-sr-017', KnowledgeChemistrySenior.REQUIRED_TWO, '化工生产中的重要非金属元素', '二氧化硫的漂白有选择性且可逆',
      'SO2 中硫为 +4 价,既能被氧化到 +6 又能被还原到 0,故既有还原性又有氧化性:使溴水、酸性 KMnO4 褪色是还原性的体现,与 H2S 反应析出单质硫是氧化性的体现。它使品红溶液褪色是化合成不稳定的无色物质,加热后颜色复原,这种漂白有选择性且可逆,不同于 HClO、Na2O2 靠强氧化性的永久漂白,也不同于活性炭的吸附漂白;SO2 是酸性氧化物,能使石蕊变红但不能使其褪色',
      ['SO2 + H2O ⇌ H2SO3', '褪色—加热复原'], KnowledgeLevel.APPLY, ['kn-chem-sr-008']));
    out.push(k('kn-chem-sr-018', KnowledgeChemistrySenior.REQUIRED_TWO, '化工生产中的重要非金属元素', '浓硫酸的吸水、脱水与 SO42- 的检验',
      '浓硫酸使胆矾失去结晶水是吸水性、使蔗糖按水的组成脱去氢氧而炭化是脱水性,两者对象不同;常温下使铁、铝钝化则体现强氧化性。干燥气体时它不能干燥碱性的 NH3 也不能干燥还原性的 H2S、HBr、HI。检验 SO42- 要先加足量稀盐酸无明显现象(排除 Ag+、CO32-、SO32- 的干扰),再加 BaCl2 溶液出现白色沉淀;不能用稀硝酸酸化,否则会把 SO32- 氧化成 SO42- 而误判,也不能改用 Ba(NO3)2',
      ['Ba2+ + SO42- = BaSO4↓', '先酸化再加 BaCl2'], KnowledgeLevel.APPLY, ['kn-chem-sr-017', 'kn-chem-sr-004']));
    out.push(k('kn-chem-sr-019', KnowledgeChemistrySenior.REQUIRED_TWO, '化工生产中的重要非金属元素', '氮的固定、NO 与 NO2 及硝酸的强氧化性',
      '把游离态的 N2 转变化合态氮的过程叫氮的固定:闪电使 N2 与 O2 化合为 NO、豆科根瘤菌属自然固氮,工业合成氨属人工固氮。NO 无色、难溶于水、只能用排水法收集,遇空气立即变为红棕色 NO2;3NO2 + H2O = 2HNO3 + NO 中 NO2 既是氧化剂又是还原剂。硝酸有强氧化性,与金属反应时不放出氢气,浓硝酸一般被还原为 NO2、稀硝酸为 NO,常温下同样使铁、铝钝化;冷的稀硝酸与很活泼的金属反应可生成 NH4+',
      ['N2 + O2 →(放电) 2NO', '3NO2 + H2O = 2HNO3 + NO'], KnowledgeLevel.APPLY, ['kn-chem-sr-005']));
    out.push(k('kn-chem-sr-020', KnowledgeChemistrySenior.REQUIRED_TWO, '化工生产中的重要非金属元素', '氨的极易溶解性与铵盐、NH4+ 的检验',
      '氨约 1:700 的极易溶解性是喷泉实验的原理,但使酚酞变红的是 NH3·H2O 电离出的 OH- 而不是 NH3 分子本身。氨中氮为 −3 价而有还原性,催化氧化生成 NO 是工业制硝酸的第一步。铵盐都易溶于水且受热易分解,NH4Cl 受热分解、遇冷又化合,表现为「假升华」,不能靠加热 NH4Cl 制氨;实验室用 NH4Cl 与 Ca(OH)2 固体共热制氨,用碱石灰干燥、向下排空气法收集。检验 NH4+ 要加浓 NaOH 共热,再用湿润的红色石蕊试纸靠近管口',
      ['4NH3 + 5O2 →(催化剂△) 4NO + 6H2O'], KnowledgeLevel.APPLY, ['kn-chem-sr-019']));
    out.push(k('kn-chem-sr-021', KnowledgeChemistrySenior.REQUIRED_TWO, '化工生产中的重要非金属元素', '硅、二氧化硅与无机非金属材料',
      '硅是半导体,高纯硅用于芯片与光电池,SiO2 用于光导纤维。SiO2 熔点高、硬度大,是酸性氧化物却不与水反应,只与氢氟酸这一种酸反应,故 HF 能腐蚀玻璃;它能与 NaOH 反应生成有黏性的 Na2SiO3,所以盛碱液的试剂瓶要用橡胶塞而不是玻璃塞。玻璃、水泥、陶瓷是传统硅酸盐材料,陶瓷、玻璃、水泥的生产都要用到石灰石或黏土;碳纳米管、石墨烯、氮化硅陶瓷属新型无机非金属材料',
      ['SiO2 + 2NaOH = Na2SiO3 + H2O', 'SiO2 + 4HF = SiF4↑ + 2H2O'], KnowledgeLevel.RECALL, []));
    return out;
  }

  /** 必修二 第六、七、八章:反应与能量、有机初识、化学与资源 */
  static energyRateAndOrganicIntro(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-chem-sr-022', KnowledgeChemistrySenior.REQUIRED_TWO, '化学反应与能量', '放热还是吸热只由始末态总能量决定',
      '反应放热还是吸热只取决于反应物总能量与生成物总能量之差,与是否需要加热无关:燃烧要点火引发仍是放热反应,Ba(OH)2·8H2O 与 NH4Cl 常温搅拌就能反应却是吸热反应,所以「加热才发生」不等于吸热。从键能角度看,断裂反应物化学键吸收的能量大于生成产物化学键放出的能量时反应吸热,反之放热,不能凭「断键要吸热」就断言所有反应都吸热',
      ['ΔE = E(断键吸) − E(成键放)', '常见放热:燃烧、中和、金属与酸、铝热'], KnowledgeLevel.APPLY, []));
    out.push(k('kn-chem-sr-023', KnowledgeChemistrySenior.REQUIRED_TWO, '化学反应与能量', '速率的定量表示与可逆反应的限度',
      '反应速率用单位时间内浓度的变化表示 v = Δc/Δt,同一反应用不同物质表示的数值之比等于化学计量数之比,而固体和纯液体的浓度视为常数、不能用来表示速率。可逆反应进行到正、逆反应速率相等时达到该条件下的限度,此时各组分浓度不再改变但反应仍在进行;改变条件可以打破限度,而速率大并不等于转化率高,快慢与限度是两个必须分开回答的问题',
      ['v = Δc/Δt', '速率比 = 化学计量数比'], KnowledgeLevel.APPLY, ['kn-chem-sr-009']));
    out.push(k('kn-chem-sr-024', KnowledgeChemistrySenior.REQUIRED_TWO, '有机化合物', '甲烷、乙烯、苯的结构与三类有机反应',
      '甲烷是正四面体结构、只有 σ 键,不能使酸性 KMnO4 或溴水褪色,与氯气在光照下发生取代并生成多种氯代物(其中 HCl 的量最多)。乙烯含碳碳双键、所有原子共平面,能与溴加成而使溴水褪色,并能加聚成聚乙烯;乙烯与 SO2 都能使溴水褪色但原理不同,一是加成一是氧化还原。苯是平面正六边形、碳碳键介于单键与双键之间,不能使酸性 KMnO4 褪色、不与溴水反应(只发生萃取分层),却能在 Fe 催化下与液溴取代、在浓硫酸作用下与浓硝酸硝化',
      ['取代/加成/加聚', '苯:6 个碳碳键完全相同'], KnowledgeLevel.APPLY, []));
    out.push(k('kn-chem-sr-025', KnowledgeChemistrySenior.REQUIRED_TWO, '有机化合物', '乙醇的催化氧化与乙酸的酯化脱水方式',
      '乙醇与钠反应放出氢气说明羟基上的氢能被动置换,但乙醇不电离、不能使指示剂变色。催化氧化时铜丝先变黑后又变红、反复交替,说明 Cu 是催化剂而真正被氧化的是乙醇;只有与羟基相连的碳上有氢才能被催化氧化,故乙醇氧化成乙醛、2-丙醇氧化成丙酮、2-甲基-2-丙醇不能被催化氧化。乙酸的酸性弱于盐酸但强于碳酸,能与 NaHCO3 放出 CO2。酯化反应是羧酸脱羟基、醇脱羟基上的氢,用含 18O 的乙醇可证明生成的水中不含 18O 而酯中含 18O;浓硫酸既作催化剂又作吸水剂使平衡正向移动,收集产物用饱和 Na2CO3 溶液而不是 NaOH',
      ['CH3COOH + C2H5OH ⇌ CH3COOC2H5 + H2O', '酸脱羟基、醇脱氢'], KnowledgeLevel.APPLY, ['kn-chem-sr-024']));
    out.push(k('kn-chem-sr-026', KnowledgeChemistrySenior.REQUIRED_TWO, '有机化合物', '糖类、油脂、蛋白质的特征反应与鉴别',
      '葡萄糖含醛基,能与银氨溶液水浴加热产生银镜或与新制 Cu(OH)2 共热生成砖红色沉淀;蔗糖是非还原性二糖,水解得葡萄糖与果糖;淀粉遇碘变蓝、最终水解为葡萄糖。糖类不一定有甜味也不一定符合 Cn(H2O)m 通式,纤维素在人体内不能水解是因为缺乏相应的酶。油脂是高级脂肪酸甘油酯、相对分子质量只有几百,不属于高分子化合物,碱性条件下的水解就是皂化反应。蛋白质遇浓硝酸变黄、灼烧有焦羽毛气味,可用于鉴别真伪羊毛;盐析可逆而变性不可逆',
      ['银镜反应', '碘—淀粉变蓝'], KnowledgeLevel.RECALL, ['kn-chem-sr-024']));
    out.push(k('kn-chem-sr-027', KnowledgeChemistrySenior.REQUIRED_TWO, '化学与可持续发展', '自然资源的开发利用与绿色化学的原子经济性',
      '石油的分馏是物理变化,裂化与裂解是化学变化:裂化为提高轻质油特别是汽油的产量,裂解为获得乙烯、丙烯等短链烯烃,所以「分馏得汽油、裂解得乙烯」不能颠倒。煤的干馏是化学变化,产物焦炭、煤焦油、焦炉气都是新原料,而煤的气化与液化也属化学变化。海水提溴、提镁靠氧化还原与沉淀分离。绿色化学的核心是从源头上减少和消除污染,理想反应的原子利用率为 100%,化合反应与加聚反应能满足,取代反应和酯化反应因生成小分子副产物而不能',
      ['原子利用率 = 期望产物质量/反应物总质量', '分馏物理、裂化裂解化学'], KnowledgeLevel.RECALL, ['kn-chem-sr-021', 'kn-chem-sr-024']));
    return out;
  }

  /** 选必一 第一章 + 第二章:反应热、速率与化学平衡 */
  static reactionHeatAndEquilibrium(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-chem-sr-028', KnowledgeChemistrySenior.ELECTIVE_ONE, '化学反应的热效应', 'ΔH 的符号、热化学方程式与燃烧热中和热',
      'ΔH = 生成物总焓 − 反应物总焓,放热为负、吸热为正,比较 ΔH 大小时必须带符号:−180 kJ/mol 比 −100 kJ/mol 小而不是「放热更多」。热化学方程式必须注明聚集状态,ΔH 与化学计量数成正比,系数加倍数值也加倍;用 K 与 ΔH 判断方向时两者都要随方程式写法同步换算。燃烧热以 1 mol 纯可燃物完全燃烧、生成稳定氧化物(H 的产物必须是液态水)为准;中和热指稀溶液中强酸强碱生成 1 mol 液态水约放热 57.3 kJ,弱酸弱碱电离吸热使测得值偏小,而生成沉淀或使用浓硫酸则偏大',
      ['ΔH < 0 为放热', 'H+(aq) + OH-(aq) = H2O(l) ΔH = -57.3 kJ/mol'], KnowledgeLevel.APPLY, ['kn-chem-sr-022']));
    out.push(k('kn-chem-sr-029', KnowledgeChemistrySenior.ELECTIVE_ONE, '化学反应的热效应', '盖斯定律使难以测定的反应热可间接求出',
      '反应热只与体系的始态和终态有关、与途径无关,所以 C 不完全燃烧生成 CO 的 ΔH 无法直接量热测得,却能由 C 与 CO 的燃烧热相减求出。运用时把目标方程式写成若干已知方程式的线性组合:同向相加、反向相减,ΔH 做同样的运算并在逆向时改变符号;方程式叠加时消去的不只是中间物质,也是那条途径上的能量。由此还能比较物质的相对能量高低,能量越低越稳定',
      ['ΔH(总) = ΣΔH(分步)'], KnowledgeLevel.TRANSFER, ['kn-chem-sr-028']));
    out.push(k('kn-chem-sr-030', KnowledgeChemistrySenior.ELECTIVE_ONE, '化学反应的热效应', '中和热测定中保温与快倒快盖的作用',
      '测定成败的关键是热量损失,所以用保温杯式量热器、内外杯之间填满碎纸条、盖板只留搅拌与测温的小孔、用环形玻璃棒上下抽动而不用金属搅拌器,这些做法都在减少向环境散热;混合时必须一次快速倒入并立即盖紧,缓缓倒入或敞口混合会让热量在反应过程中散失而使结果偏低。酸、碱溶液要预先配好并恢复到同一室温,测过酸的温度计必须洗净擦干再测碱否则提前中和;碱稍过量是为了保证酸完全反应,而不是提高反应热本身',
      ['Q = cmΔt', '偏低 ← 热量散失'], KnowledgeLevel.APPLY, ['kn-chem-sr-028']));
    out.push(k('kn-chem-sr-031', KnowledgeChemistrySenior.ELECTIVE_ONE, '化学反应速率与化学平衡', '浓度、温度、催化剂改变速率的微观原因不同',
      '增大反应物浓度只增加单位体积内活化分子的数目而不改变活化分子百分数;升高温度提高的是活化分子百分数,故升温对速率的影响远大于增大浓度;催化剂通过降低活化能同时加快正、逆反应速率,因而不改变反应热、不改变平衡位置、不提高转化率。压强只对气体反应有意义,恒容下充入不参与反应的惰性气体时各组分浓度不变、速率就不变,这是「加压一定加速」的典型反例;而恒压充惰性气体体积增大,速率反而减小',
      ['活化能 Ea', '催化剂同等程度加快正逆'], KnowledgeLevel.APPLY, ['kn-chem-sr-023']));
    out.push(k('kn-chem-sr-032', KnowledgeChemistrySenior.ELECTIVE_ONE, '化学反应速率与化学平衡', '判断平衡状态要用同一物质比较正逆速率',
      '平衡的本质是同一物质的生成速率与消耗速率相等,表观是各组分浓度、质量分数、物质的量分数保持不变。判断某个量能否作标志,要看它在反应过程中本来是否变化:恒容且全为气体的反应里混合气体密度始终不变,不能作标志;而有固体参与或气体分子数改变时,密度、平均摩尔质量、压强的不变就可以作标志。NO2 体系颜色不再改变是有效标志,而「v正(A) = 2v逆(B)」这类不同物质的速率要按计量数换算后才能比较',
      ['v正 = v逆(同一物质)', '变量不变即平衡'], KnowledgeLevel.TRANSFER, ['kn-chem-sr-023', 'kn-chem-sr-031']));
    out.push(k('kn-chem-sr-033', KnowledgeChemistrySenior.ELECTIVE_ONE, '化学反应速率与化学平衡', '勒夏特列原理只能减弱改变而不能抵消',
      '平衡移动只能减弱外界引起的改变,不能抵消更不能消除它:压缩体积使浓度增大,新平衡下该组分浓度仍比原平衡大,只是比不移动时小;升温使平衡向吸热方向移动,却不会把温度拉回原值。增大一种反应物的浓度会提高另一种反应物的转化率而自身的转化率降低;催化剂与恒容充入惰性气体都不引起平衡移动,不能用它们提高产率;对反应前后气体分子数相等的反应,加压不移动平衡但会增大浓度与速率',
      ['只减弱、不抵消'], KnowledgeLevel.TRANSFER, ['kn-chem-sr-032']));
    out.push(k('kn-chem-sr-034', KnowledgeChemistrySenior.ELECTIVE_ONE, '化学反应速率与化学平衡', '平衡常数只随温度变化并能判断反应方向',
      'K 只由温度决定,与起始浓度、压强、催化剂无关,所以判断温度对平衡的影响要看 K 是否改变:升温使放热反应的 K 减小。K 与方程式的书写形式一一对应,系数扩大一倍则新 K 是原 K 的平方,逆反应的 K 与原反应互为倒数;表达式中不出现固体和纯液体。用浓度商 Q 与 K 比较可判断方向:Q 大于 K 逆向进行、小于 K 正向进行。转化率与 K 说明的是不同问题,K 大只表示正反应进行的趋势大,不代表某一具体投料下的转化率大',
      ['K = Σ生成物浓度幂/Σ反应物浓度幂', 'Q > K 逆向'], KnowledgeLevel.APPLY, ['kn-chem-sr-033']));
    return out;
  }

  /** 选必一 第三章:电离、水解、滴定与沉淀溶解 */
  static solutionEquilibrium(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-chem-sr-035', KnowledgeChemistrySenior.ELECTIVE_ONE, '水溶液中的离子反应与平衡', '电离平衡常数只随温度变,pH=7 不一定是中性',
      '弱电解质部分电离、存在电离平衡,加水稀释时电离程度增大,而溶液中除水以外的各种微粒浓度都减小;Ka 只与温度有关而与浓度无关,所以判断稀释后各量的走向要靠「Ka 不变」这条约束而不是直觉。pH 相同的盐酸与醋酸,醋酸的物质的量浓度反而更大,等体积时中和碱的能力更强、稀释相同倍数后 pH 变化更小。水的电离同样是平衡,Kw = c(H+)·c(OH-) 在 25 ℃ 时等于 1×10^-14,升温 Kw 增大,pH = 7 就不再代表中性;酸、碱抑制水的电离而能水解的盐促进它,故由水电离出的 c(H+) = 1×10^-13 mol/L 的溶液既可能是酸也可能是碱。pH 试纸不能预先润湿,否则酸性溶液测得值偏大,且它只能读到整数',
      ['Ka 只随温度', 'Kw = 1e-14 (25℃)'], KnowledgeLevel.APPLY, ['kn-chem-sr-002', 'kn-chem-sr-032']));
    out.push(k('kn-chem-sr-036', KnowledgeChemistrySenior.ELECTIVE_ONE, '水溶液中的离子反应与平衡', '盐类水解的规律、双水解与离子浓度大小比较',
      '水解遵循「有弱才水解、无弱不水解、越弱越水解、谁强显谁性」,水解吸热故升温和加水都促进它,加酸加碱则按抑制相应离子的方向移动:Na2CO3 溶液加热后去油污能力增强、配 FeCl3 溶液要加盐酸抑制水解、蒸干 AlCl3 溶液得到的是氢氧化物或氧化物而不是无水 AlCl3。Al3+ 与 CO32-、HCO3-、S2-、AlO2- 因相互促进而彻底双水解,不能共存,泡沫灭火器与明矾净水都靠这一性质。比较离子浓度要联立电荷守恒、物料守恒与质子守恒,如 0.1 mol/L Na2CO3 溶液中 c(Na+) > c(CO32-) > c(OH-) > c(HCO3-) > c(H+),而 NaHSO3、NH4Cl 之类还要先判断电离与水解谁占主导',
      ['电荷守恒 + 物料守恒 + 质子守恒', '越弱越水解'], KnowledgeLevel.APPLY, ['kn-chem-sr-035', 'kn-chem-sr-004']));
    out.push(k('kn-chem-sr-037', KnowledgeChemistrySenior.ELECTIVE_ONE, '水溶液中的离子反应与平衡', '中和滴定的 pH 突跃与指示剂、误差判断',
      '强碱滴定强酸时临近终点多加半滴就能使 pH 从约 4 跳到约 10,指示剂只要变色范围落在突跃范围内即可选用:强碱滴弱酸生成碱性盐,应选酚酞而不能选甲基橙;终点判据是滴入最后半滴后颜色突变且半分钟内不恢复。误差要回到 c(待测) = c(标准)·V(标准)/V(待测) 判断:标准液滴定管未用标准液润洗使 V(标准)偏大而结果偏高,锥形瓶用待测液润洗使结果偏高,尖嘴气泡滴定后消失使读数偏大,而锥形瓶内有少量蒸馏水不影响结果。酸式滴定管不能装碱液,碱液会腐蚀玻璃活塞',
      ['c(待) = c(标)·V(标)/V(待)', '读至 0.01 mL'], KnowledgeLevel.TRANSFER, ['kn-chem-sr-035', 'kn-chem-sr-036']));
    out.push(k('kn-chem-sr-038', KnowledgeChemistrySenior.ELECTIVE_ONE, '水溶液中的离子反应与平衡', '溶度积 Ksp 只随温度变与沉淀的转化',
      '难溶电解质在水中存在沉淀溶解平衡,Ksp 只是温度的函数,与溶液中离子浓度无关,表达式中不出现固体。只有同类型的难溶物才能用 Ksp 直接比较溶解度大小,AgCl 与 Ag2CrO4 类型不同必须换算后才知道谁先沉淀。判断是否生成沉淀要看浓度商 Q 与 Ksp 的关系:Q 大于 Ksp 析出沉淀、小于 Ksp 沉淀溶解,所以「Ksp 小」本身不决定沉淀与否,离子浓度幂之积才决定。溶解度更小的沉淀容易由大的转化而来:AgCl 加 I- 变 AgI、再加 S2- 变 Ag2S,锅炉水垢中的 CaSO4 先用 Na2CO3 转成 CaCO3 再用酸溶掉',
      ['Ksp(AgCl) = c(Ag+)·c(Cl-)', 'Q > Ksp 析出沉淀'], KnowledgeLevel.APPLY, ['kn-chem-sr-034']));
    return out;
  }

  /** 选必一 第四章:原电池、电解池与金属防护 */
  static electrochemistry(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-chem-sr-039', KnowledgeChemistrySenior.ELECTIVE_ONE, '化学反应与电能', '原电池的构成条件与电极反应式的书写',
      '原电池把化学能转化为电能,须同时满足自发氧化还原反应、两个活泼性不同的电极、电解质溶液和闭合回路;负极失电子发生氧化、正极得电子发生还原,电子只经外电路由负极流向正极而不进入溶液,溶液里靠离子迁移导电,阳离子移向正极、阴离子移向负极。负极不一定是较活泼的金属:Mg—Al—NaOH 电池中 Al 能与碱反应而作负极,铁与铜在浓硝酸中因铁钝化而铜作负极。书写燃料电池电极反应式要先按介质酸碱选择能大量存在的微粒,酸性介质中不出现 OH-、碱性介质中不出现 H+,酸性条件下 H2 的负极反应是 H2 - 2e- = 2H+',
      ['负极氧化、正极还原', '盐桥平衡电荷'], KnowledgeLevel.APPLY, ['kn-chem-sr-005', 'kn-chem-sr-011']));
    out.push(k('kn-chem-sr-040', KnowledgeChemistrySenior.ELECTIVE_ONE, '化学反应与电能', '电解的放电顺序与氯碱工业、电镀、精炼铜',
      '电解把电能转化为化学能,阳极发生氧化、阴极发生还原,判断产物先看电极材料:活性金属电极本身先溶解,惰性电极时阳极按 S2- 大于 I- 大于 Br- 大于 Cl- 大于 OH- 的顺序放电,阴极按氧化性 Ag+ 大于 Fe3+ 大于 Cu2+ 大于 H+ 的顺序放电,而 Na+、Al3+ 等活泼金属离子在水溶液中不放电。电解饱和食盐水时阴极区生成 NaOH、pH 增大,阳极的 Cl2 用湿润的淀粉 KI 试纸检验,阳离子交换膜用来阻止 Cl2 与 NaOH、H2 接触。电镀时镀层金属作阳极、镀件作阴极,电镀液浓度不变;电解精炼铜时粗铜作阳极,比铜活泼的杂质溶入溶液而 Ag、Au 沉为阳极泥,溶液中 Cu2+ 浓度略有减小',
      ['阳极氧化、阴极还原', 'Cu(粗) 作阳极'], KnowledgeLevel.APPLY, ['kn-chem-sr-039']));
    out.push(k('kn-chem-sr-041', KnowledgeChemistrySenior.ELECTIVE_ONE, '化学反应与电能', '钢铁的吸氧腐蚀与两种阴极保护法',
      '钢铁在中性或弱酸性的潮湿空气中主要发生吸氧腐蚀,负极 Fe - 2e- = Fe2+、正极 O2 + 2H2O + 4e- = 4OH-,只有酸性较强时才发生析氢腐蚀,所以海水(电解质浓)中腐蚀快于纯水而铁锈疏松不能保护内层。防护有两条电化学路线:把更活泼的金属如锌块连在被保护金属上,让锌作负极被消耗,是牺牲阳极的阴极保护法;把被保护金属接到电源负极作电解池阴极,是外加电流的阴极保护法,后者更适合大型管道且需要持续供电。镀锌铁镀层破损后铁仍被保护,镀锡铁破损后铁腐蚀反而加快',
      ['吸氧腐蚀', '牺牲阳极 / 外加电流阴极保护'], KnowledgeLevel.APPLY, ['kn-chem-sr-039']));
    return out;
  }

  /** 选必二:原子结构、分子结构与晶体 */
  static structureAndProperties(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-chem-sr-042', KnowledgeChemistrySenior.ELECTIVE_TWO, '原子结构与性质', '能层能级、核外电子排布式与半满全满特例',
      '能层(K、L、M、N)对应主量子数,能级按 s、p、d、f 划分,s 能级 1 个轨道、p 能级 3 个、d 能级 5 个;一个原子轨道最多容纳两个自旋相反的电子(泡利原理),简并轨道上电子优先单独占据且自旋平行(洪特规则),填充顺序按能量最低走 1s、2s、2p、3s、3p、4s、3d。写排布式要记住 Cr 是 3d5 4s1、Cu 是 3d10 4s1 的半满全满特例;失电子生成阳离子时先失去最外层的 4s 电子而不是 3d,所以 Fe2+ 是 3d6 而不是 3d4 4s2,基态与原子的能量最低状态对应,激发态光谱才是霓虹灯发光的来源',
      ['1s2 2s2 2p6 3s2 3p6 4s1 3d5(Cr)', '泡利原理、洪特规则'], KnowledgeLevel.APPLY, ['kn-chem-sr-014']));
    out.push(k('kn-chem-sr-043', KnowledgeChemistrySenior.ELECTIVE_TWO, '原子结构与性质', '电离能与电负性的递变及其异常',
      '第一电离能是气态电中性基态原子失去一个电子所需的能量,同周期从左到右总体增大,但 Be 高于 B、N 高于 O,因为 2s 全满与 2p 半满更稳定,所以由 I1 的特例位置能反推价电子构型;当某元素的 I2 远大于 I1 时说明它只有一个最外层电子。电负性描述原子在化合物中吸引电子的能力,F 最大,金属一般小于 1.8,两元素电负性差越大共价键极性越强、差值超过约 1.7 时多形成离子键。电离能看的是失电子的难易、电负性看的是对共用电子对的吸引,两者不能互换使用;同主族从上到下 I1 与电负性都减小',
      ['I1 < I2 < I3', '电负性 F 最大'], KnowledgeLevel.APPLY, ['kn-chem-sr-042', 'kn-chem-sr-015']));
    out.push(k('kn-chem-sr-044', KnowledgeChemistrySenior.ELECTIVE_TWO, '分子结构与性质', 'σ 键与 π 键、键参数和配位键',
      '共价键按重叠方式分为「头碰头」的 σ 键与「肩并肩」的 π 键:单键一定是 σ 键,双键含一个 σ 键和一个 π 键,三键含一个 σ 键和两个 π 键;π 键电子云不沿键轴对称、不能绕键轴旋转,所以含 π 键的分子存在顺反异构且更活泼、易发生加成。键能越大、键长越短则共价键越牢固、物质的化学性质越稳定,但分子晶体的熔沸点由分子间作用力决定而不是由键能决定,这两个「强弱」常被混为一谈。由一方提供孤电子对、另一方提供空轨道形成的共价键是配位键,如 NH4+ 中第四个 N—H 键与 [Cu(NH3)4]2+',
      ['σ 键 / π 键', '键能、键长、键角'], KnowledgeLevel.APPLY, ['kn-chem-sr-016']));
    out.push(k('kn-chem-sr-045', KnowledgeChemistrySenior.ELECTIVE_TWO, '分子结构与性质', '杂化轨道与分子构型、极性及氢键',
      '价层电子对互斥模型先数中心原子的 σ 键电子对与孤电子对:价层电子对数 2、3、4 对应 sp、sp2、sp3 杂化和直线、平面三角形、四面形的电子对构型,再扣掉孤电子对才得到分子的空间构型,所以 CH4 是正四面体而 NH3 是三角锥、H2O 是 V 形,键角依次小于 109°28′。分子是否有极性取决于结构是否对称、正负电荷中心是否重合:CO2 非极性而 SO2 极性,CCl4 非极性而 CH3Cl 极性。范德华力只影响熔沸点与溶解度;氢键比范德华力强却仍远弱于共价键,它使 H2O、NH3、HF 的沸点在同族氢化物中反常地高,使冰的密度小于水,也决定 NH3 极易溶于水,而 CH4 之类不能形成氢键',
      ['sp/sp2/sp3', '氢键不是化学键'], KnowledgeLevel.TRANSFER, ['kn-chem-sr-044']));
    out.push(k('kn-chem-sr-046', KnowledgeChemistrySenior.ELECTIVE_TWO, '晶体结构与性质', '四类晶体的作用力差异与晶胞的均摊计算',
      '晶体与非晶体的本质区别是内部微粒是否在三维空间作周期性有序排列,最可靠的区分方法是 X 射线衍射。分子晶体靠分子间作用力(可能含氢键)、共价晶体(旧称原子晶体)靠共价键、离子晶体靠离子键、金属晶体靠金属键,故熔沸点一般按共价晶体、离子晶体、分子晶体的顺序降低,但含氢键的分子晶体反常偏高,金属晶体的熔点跨度极大(汞常温为液态、钨很高)。用均摊法数晶胞:顶点占 1/8、棱上 1/4、面上 1/2、体内算 1,故 NaCl 晶胞中 Na+ 与 Cl- 各 4 个、配位数 6∶6;石墨是混合型晶体,层内共价键层间范德华力,故能导电又能作润滑剂',
      ['均摊法:顶点 1/8、棱 1/4、面 1/2', 'NaCl 配位数 6'], KnowledgeLevel.APPLY, ['kn-chem-sr-016', 'kn-chem-sr-044']));
    return out;
  }

  /** 选必三:有机物的结构、烃与衍生物、大分子与高分子 */
  static organicFoundation(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-chem-sr-047', KnowledgeChemistrySenior.ELECTIVE_THREE, '有机化合物的结构特点与研究方法', '官能团决定性质、同分异构体与系统命名',
      '碳原子四价、可成单键双键三键与碳链碳环,是有机物数目庞大的原因;把官能团(碳碳双键、卤原子、羟基、醛基、羧基、酯基、氨基)当作预测性质的入口,同类官能团性质相似。分子式相同而结构不同互为同分异构体,书写时按碳链异构、位置异构、官能团异构(乙醇与二甲醚、丙烯与环丙烷)有序排查,用等效氢可判断一取代物的种类数。系统命名要先选含官能团的最长碳链作主链,编号让官能团位次最小而不是让取代基位次最小;同系物必须结构相似、组成相差若干个 CH2,故乙烯与环丙烷不是同系物',
      ['官能团决定性质', '同分异构:碳链—位置—官能团'], KnowledgeLevel.APPLY, ['kn-chem-sr-024']));
    out.push(k('kn-chem-sr-048', KnowledgeChemistrySenior.ELECTIVE_THREE, '烃', '烷烯炔与芳香烃的性质差异和鉴别',
      '烷烃只含 σ 键、性质稳定,光照下与卤素单质发生取代;烯烃、炔烃含不饱和键,既能与溴加成使溴水褪色又能被酸性 KMnO4 氧化而褪色,两种褪色原理不同。苯只能与液溴在 Fe 催化下取代、不能使酸性 KMnO4 褪色,而苯的同系物如甲苯因侧链被氧化能使 KMnO4 褪色,据此可区分苯与甲苯。乙炔由电石与水反应制得,反应剧烈且放热、不能用启普发生器,气体须先经 CuSO4 溶液除去 H2S、PH3。鉴别甲烷与乙烯用溴水或酸性 KMnO4 而不用点燃;含碳量越高火焰越明亮并带浓烟,苯与乙炔燃烧冒黑烟',
      ['CnH2n+2 / CnH2n / CnH2n-2', '加成褪色 vs 氧化褪色'], KnowledgeLevel.APPLY, ['kn-chem-sr-024', 'kn-chem-sr-047']));
    out.push(k('kn-chem-sr-049', KnowledgeChemistrySenior.ELECTIVE_THREE, '烃的衍生物', '卤代烃的水解与消去取决于反应介质',
      '卤代烃在 NaOH 水溶液中加热发生水解(取代)生成醇,在 NaOH 的醇溶液中加热则发生消去生成烯烃:消去要求与卤原子相连碳的邻位碳上有氢,所以 CH3Br 与 (CH3)3CCH2Br 都不能消去,而 2-溴丁烷消去可得两种烯烃且以取代基较多的为主。检验卤素原子的顺序不能乱:先加 NaOH 溶液共热、再加稀硝酸中和过量的碱、最后加 AgNO3,否则 Ag+ 与 OH- 生成的沉淀会干扰判断,这是本类实验最常见的错。由卤代烃引入羟基、由消去引入双键,是有机合成中改变官能团位置的两步常用套路',
      ['水解:NaOH 水溶液 / 消去:NaOH 醇溶液', '-CX2 型需邻碳有氢'], KnowledgeLevel.APPLY, ['kn-chem-sr-048']));
    out.push(k('kn-chem-sr-050', KnowledgeChemistrySenior.ELECTIVE_THREE, '烃的衍生物', '醇与苯酚:催化氧化规律和酚的弱酸性',
      '醇的沸点远高于相对分子质量相近的烷烃是因为分子间氢键;催化氧化要求与羟基相连的碳上有氢,故伯醇得醛、仲醇得酮、叔醇不被催化氧化,而消去反应要求邻位碳上有氢,乙醇在 170 ℃ 生成乙烯、140 ℃ 则分子间脱水生成乙醚。苯酚中羟基受苯环影响而显弱酸性(石炭酸),酸性弱于碳酸但强于 HCO3- 的电离,所以向苯酚钠溶液通入 CO2 只生成 NaHCO3 而得不到 Na2CO3;苯酚与浓溴水立即生成 2,4,6-三溴苯酚白色沉淀、遇 FeCl3 溶液显紫色,这两个反应都可用于检验。乙醇与苯酚虽都含羟基,化学性质却因羟基所连基团不同而差别明显',
      ['酚酸性:H2CO3 > 苯酚 > HCO3-', 'FeCl3 显紫色'], KnowledgeLevel.APPLY, ['kn-chem-sr-049', 'kn-chem-sr-025']));
    out.push(k('kn-chem-sr-051', KnowledgeChemistrySenior.ELECTIVE_THREE, '烃的衍生物', '醛、羧酸与酯的性质及官能团检验',
      '醛基既有还原性又能被氧化:银氨溶液须水浴加热、产生银镜,新制 Cu(OH)2 悬浊液须共热、产生砖红色 Cu2O,两个检验都必须在碱性条件下进行,若水解液未先用碱中和就直接加试剂则不会成功。甲醛含两个可被氧化的位置,氧化产物为甲酸;甲酸分子中同时含羧基与醛基,既能与 NaHCO3 放出 CO2 又能发生银镜反应,这是最常见的例外。酮如丙酮不能发生银镜反应。羧酸的酸性随烃基给电子能力减弱而增强,酯的水解在碱性条件下更彻底(皂化),酸性条件下可逆,写可逆符号与产物小分子时不能漏',
      ['R—CHO 银镜/菲林反应', '甲酸:既有 -COOH 又有 -CHO'], KnowledgeLevel.APPLY, ['kn-chem-sr-050']));
    out.push(k('kn-chem-sr-052', KnowledgeChemistrySenior.ELECTIVE_THREE, '生物大分子', '糖类、氨基酸与蛋白质的结构和检验',
      '葡萄糖是单糖不能水解,果糖是多羟基酮却也能在碱性条件下异构化为醛糖而发生银镜反应;蔗糖水解得葡萄糖与果糖,麦芽糖水解得两分子葡萄糖,淀粉与纤维素的通式同为 (C6H10O5)n 但 n 值不同,故两者不互为同分异构体,最终水解产物却都是葡萄糖。氨基酸同时含氨基与羧基而有两性,分子间脱水形成肽键 —CONH— 构成多肽与蛋白质,天然蛋白质水解的最终产物是 α-氨基酸;蛋白质遇浓硝酸变黄、灼烧有焦羽毛气味,盐析可逆而变性不可逆。核酸也是天然高分子,由核苷酸聚合而成,DNA 与 RNA 的差别在五碳糖和碱基种类',
      ['肽键 —CONH—', '(C6H10O5)n 不互为同分异构体'], KnowledgeLevel.APPLY, ['kn-chem-sr-047', 'kn-chem-sr-026']));
    out.push(k('kn-chem-sr-053', KnowledgeChemistrySenior.ELECTIVE_THREE, '合成高分子', '加聚与缩聚的区别及由高聚物推单体',
      '加聚反应由含不饱和键的单体相互加成而成,只生成一种产物且链节组成与单体相同;由链节推单体时,主链上只有两个碳原子的对应一种单体、把两个半键闭合即得,含四个碳原子且无其他原子的对应两种单体、从正中间断开再闭合,链节中含碳碳双键的通常来自二烯烃。缩聚反应在生成高分子的同时脱去 H2O、HCl 等小分子,产物如涤纶(聚酯)与尼龙-66(聚酰胺),书写时必须标出端基并把小分子写全,单体的种类数也不等于链节数。淀粉、纤维素、蛋白质是天然有机高分子,而油脂相对分子质量只有几百,不属于高分子化合物',
      ['加聚无副产物 / 缩聚脱小分子'], KnowledgeLevel.APPLY, ['kn-chem-sr-047', 'kn-chem-sr-052']));
    return out;
  }

  static all(): KnowledgePoint[] {
    return KnowledgeChemistrySenior.matterAndChanges()
      .concat(KnowledgeChemistrySenior.seawaterElementsAndAmount())
      .concat(KnowledgeChemistrySenior.metalsAndAtomicStructure())
      .concat(KnowledgeChemistrySenior.nonmetalElements())
      .concat(KnowledgeChemistrySenior.energyRateAndOrganicIntro())
      .concat(KnowledgeChemistrySenior.reactionHeatAndEquilibrium())
      .concat(KnowledgeChemistrySenior.solutionEquilibrium())
      .concat(KnowledgeChemistrySenior.electrochemistry())
      .concat(KnowledgeChemistrySenior.structureAndProperties())
      .concat(KnowledgeChemistrySenior.organicFoundation());
  }
}