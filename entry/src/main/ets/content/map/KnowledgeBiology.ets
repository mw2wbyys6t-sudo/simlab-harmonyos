import { KnowledgePoint, KnowledgeLevel, makeKnowledge } from './KnowledgeTypes';
import { MapSubject, SchoolStage, UNVERIFIED_PREFIX } from './CurriculumTypes';

/**
 * 普通生物学知识点。
 *
 * 与 KnowledgePhysics 同一套标准:一条 = 能被单独提问、单独判对错的最小单元,
 * 带术语、认知层次与前置链。
 *
 * `source` 只为**覆盖面与顺序**作证:按通用教材体系(陈阅增《普通生物学》的常见编排)
 * 整理,未逐章核对目录,故第一轮全部 `未核实:`。每条 statement 的生物学内容本身
 * 是可判对错的命题,靠专业判断核,不靠引用。
 */
const BIO: MapSubject = MapSubject.BIOLOGY;
const U: SchoolStage = SchoolStage.UNIVERSITY;
const COVERAGE: string = UNVERIFIED_PREFIX + '按通用教材体系整理覆盖面与顺序,未逐章核对目录';

function b(id: string, course: string, chapter: string, title: string, statement: string,
  symbols: string[], level: KnowledgeLevel, prereq: string[]): KnowledgePoint {
  return makeKnowledge(id, BIO, U, course, chapter, title, statement, symbols,
    level, prereq, COVERAGE);
}

export class KnowledgeBiology {
  static readonly CHEMISTRY_OF_LIFE: string = '生命的化学基础';
  static readonly CELL: string = '细胞与代谢';
  static readonly GENETICS: string = '遗传与变异';
  static readonly EVOLUTION: string = '进化与生物多样性';
  static readonly STRUCTURE_FUNCTION: string = '动植物结构与功能';
  static readonly ECOLOGY: string = '生态与生物圈';

  static chemistryOfLife(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(b('kn-bio-u-001', KnowledgeBiology.CHEMISTRY_OF_LIFE, '元素与水',
      '组成生命的元素与大量/微量元素',
      'C、H、O、N 占细胞质量约 96%,此外 P、S、K、Ca、Mg 为大量元素,Fe、Zn、Cu、B、Mo 等为微量元素;碳的四价与自链能力使有机物种类远多于无机物',
      ['CHONPS'], KnowledgeLevel.RECALL, []));
    out.push(b('kn-bio-u-002', KnowledgeBiology.CHEMISTRY_OF_LIFE, '元素与水',
      '水的极性与其四种生物学意义',
      '水分子氧端带部分负电、氢端带部分正电,因而能形成氢键:这带来高比热(缓冲温度)、高蒸发热(散热)、良好的溶剂能力(代谢介质)与内聚力(导管水柱上升)',
      ['氢键', '比热'], KnowledgeLevel.APPLY, ['kn-bio-u-001']));
    out.push(b('kn-bio-u-003', KnowledgeBiology.CHEMISTRY_OF_LIFE, '元素与水',
      'pH、缓冲体系与内环境稳态',
      'pH = −lg[H⁺];弱酸及其盐构成的缓冲对能抵抗 pH 突变。血浆中 HCO₃⁻/H₂CO₃ 是最重要的一对,酶只在窄的 pH 区间内有活性',
      ['HCO₃⁻/H₂CO₃'], KnowledgeLevel.APPLY, ['kn-bio-u-002']));
    out.push(b('kn-bio-u-004', KnowledgeBiology.CHEMISTRY_OF_LIFE, '生物大分子',
      '单体与多聚体:脱水缩合与水解',
      '蛋白质、核酸、多糖都由单体经脱水缩合成多聚体,消化则是水解;方向相反的两类反应共同维持大分子的更新',
      [], KnowledgeLevel.RECALL, ['kn-bio-u-001']));
    out.push(b('kn-bio-u-005', KnowledgeBiology.CHEMISTRY_OF_LIFE, '生物大分子',
      '蛋白质的四级结构与变性',
      '一级是氨基酸序列(肽键),二、三级靠氢键、二硫键、疏水作用与离子键维持,四级靠亚基间相互作用;结构决定功能,高温、强酸碱使空间结构破坏即变性,通常不可逆',
      ['肽键', '二硫键'], KnowledgeLevel.APPLY, ['kn-bio-u-004']));
    out.push(b('kn-bio-u-006', KnowledgeBiology.CHEMISTRY_OF_LIFE, '生物大分子',
      '酶是生物催化剂:降低活化能而不改变平衡',
      '酶通过活性中心与底物诱导契合降低反应活化能,因而加快正逆反应到达平衡的速度,但不改平衡点;特性是高效、专一,并受温度、pH、抑制剂与激活剂调节',
      ['活化能', 'Km', 'Vmax'], KnowledgeLevel.TRANSFER, ['kn-bio-u-005', 'kn-bio-u-003']));
    out.push(b('kn-bio-u-007', KnowledgeBiology.CHEMISTRY_OF_LIFE, '生物大分子',
      '核酸:DNA 与 RNA 的三点结构差异',
      '五碳糖(脱氧核糖对核糖)、碱基(T 对 U)、通常双链对单链;磷酸-核糖骨架在外、碱基在内,配对遵循 A-T/U、G-C 且 A-T 两键、G-C 三键',
      ['A-T/U', 'G-C'], KnowledgeLevel.RECALL, ['kn-bio-u-004']));
    out.push(b('kn-bio-u-008', KnowledgeBiology.CHEMISTRY_OF_LIFE, '生物大分子',
      '脂质的疏水性与三类功能',
      '脂肪储能并保温缓冲,磷脂双分子层构成膜的基本骨架(亲水头朝外),固醇类如胆固醇调节膜流动性、性激素作为信号分子;共同点是都不溶于水',
      ['磷脂双分子层'], KnowledgeLevel.APPLY, ['kn-bio-u-002']));
    return out;
  }

  static cell(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(b('kn-bio-u-011', KnowledgeBiology.CELL, '细胞是生命的基本单位',
      '细胞学说及其两点要义',
      '一切生物由细胞及其产物构成,细胞来自已存在的细胞;它把动植物的结构统一起来,并否定了自然发生说',
      [], KnowledgeLevel.RECALL, []));
    out.push(b('kn-bio-u-012', KnowledgeBiology.CELL, '细胞是生命的基本单位',
      '原核与真核细胞的根本区别',
      '有无以核膜包被的核只是表象,更根本的是:原核无膜性细胞器、DNA 为环状裸露且常一个操纵子、核糖体 70S、以二分裂增殖;真核有内膜系统、核糖体 80S(细胞器内仍为 70S)',
      ['70S/80S'], KnowledgeLevel.APPLY, ['kn-bio-u-011']));
    out.push(b('kn-bio-u-013', KnowledgeBiology.CELL, '细胞是生命的基本单位',
      '内共生学说解释线粒体与叶绿体的起源',
      '二者有双层膜、环状 DNA、70S 核糖体、能自行分裂且膜蛋白与细菌同源,提示它们源于被原始真核细胞吞噬的需氧细菌与光合细菌',
      [], KnowledgeLevel.TRANSFER, ['kn-bio-u-012']));
    out.push(b('kn-bio-u-014', KnowledgeBiology.CELL, '细胞膜与物质运输',
      '流动镶嵌模型',
      '磷脂双分子层是流动的二维液体,蛋白质像冰山镶嵌其中并可侧向移动;膜不对称(糖被只在外侧),其流动性受胆固醇与脂肪酸饱和度调节',
      ['流动性', '不对称性'], KnowledgeLevel.RECALL, ['kn-bio-u-008']));
    out.push(b('kn-bio-u-015', KnowledgeBiology.CELL, '细胞膜与物质运输',
      '被动运输与主动运输的分界',
      '顺电化学梯度、不耗能的是被动(自由扩散、协助扩散经通道或载体);逆梯度、需 ATP 与泵蛋白的是主动,典型是钠钾泵每循环泵出 3 个 Na⁺ 泵入 2 个 K⁺',
      ['Na⁺/K⁺-ATPase'], KnowledgeLevel.APPLY, ['kn-bio-u-014']));
    out.push(b('kn-bio-u-016', KnowledgeBiology.CELL, '细胞膜与物质运输',
      '渗透、质壁分离与膨压',
      '水经半透膜向溶质浓度高的一侧净移动;植物细胞因有壁而不会涨破,失水时原生质体收缩与壁分离即质壁分离,吸水产生的膨压支撑草本植物直立',
      ['水势 ψ'], KnowledgeLevel.TRANSFER, ['kn-bio-u-015']));
    out.push(b('kn-bio-u-017', KnowledgeBiology.CELL, '细胞膜与物质运输',
      '胞吞与胞吐依赖膜的流动性',
      '大分子与颗粒不能穿膜,由膜内陷或外排形成囊泡完成;分泌蛋白经内质网→高尔基体→囊泡→细胞膜这条途径出细胞,是膜流动的体现',
      [], KnowledgeLevel.APPLY, ['kn-bio-u-014']));
    out.push(b('kn-bio-u-018', KnowledgeBiology.CELL, '细胞器与内膜系统',
      '内膜系统按方向分工:合成、加工、分拣',
      '粗面内质网合成并折叠分泌蛋白与膜蛋白,高尔基体做糖基化加工与分拣包装,溶酶体携水解酶消化,囊泡负责转运 —— 一条从合成到分泌的流水线',
      [], KnowledgeLevel.TRANSFER, ['kn-bio-u-017']));
    return out;
  }

  static genetics(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(b('kn-bio-u-021', KnowledgeBiology.GENETICS, '孟德尔遗传',
      '分离定律的细胞学基础',
      '一对等位基因在减数分裂 I 后期随同源染色体分开而分离,各入一个配子,故杂合自交后代出现 3:1 的表型比;它要求配子存活与结合机会均等、完全显性',
      ['3:1'], KnowledgeLevel.APPLY, ['kn-bio-u-012']));
    out.push(b('kn-bio-u-022', KnowledgeBiology.GENETICS, '孟德尔遗传',
      '自由组合定律及其适用条件',
      '位于非同源染色体上的非等位基因在减数分裂 I 中期随机组合,双杂合自交得 9:3:3:1;同一条染色体上的基因不遵循它 —— 这是判断连锁的起点',
      ['9:3:3:1'], KnowledgeLevel.TRANSFER, ['kn-bio-u-021']));
    out.push(b('kn-bio-u-023', KnowledgeBiology.GENETICS, '孟德尔遗传',
      '测交、回交与自交在遗传分析中的作用',
      '测交(与隐性纯合交)用来读出待测个体产生的配子种类与比例,因而可检基因型、也可测交换值;回交把目标性状转回 recurrent 亲本背景,自交则使杂合度逐代减半',
      [], KnowledgeLevel.TRANSFER, ['kn-bio-u-021']));
    out.push(b('kn-bio-u-024', KnowledgeBiology.GENETICS, '染色体与连锁',
      '连锁与交换、重组率的上限',
      '同染色体上的基因倾向一起遗传;减数分裂 I 前期非姐妹染色单体交叉互换产生重组型,重组率正比于图距,但因双交换与多交换存在,观测重组率不超过 50%',
      ['cM', 'RF ≤ 50%'], KnowledgeLevel.TRANSFER, ['kn-bio-u-022']));
    out.push(b('kn-bio-u-025', KnowledgeBiology.GENETICS, '染色体与连锁',
      '伴性遗传与交叉遗传',
      '基因位于性染色体上时正反交结果不同;X 连锁隐性性状(红绿色盲、血友病)在异配性别中发病率远高于同配性别,并呈现外祖父→母亲→外孙的交叉传递',
      [], KnowledgeLevel.APPLY, ['kn-bio-u-021']));
    out.push(b('kn-bio-u-026', KnowledgeBiology.GENETICS, '分子遗传',
      'DNA 是遗传物质的三个经典证据',
      '格里菲斯与艾弗里(肺炎链球菌转化,只有 DNA 能转化)、赫尔希-蔡斯(³²P 标记 DNA 进入细菌而 ³⁵S 标记蛋白不进入)、以及后续对 RNA 病毒的重建实验共同确立核酸而非蛋白携带遗传信息',
      ['³²P/³⁵S'], KnowledgeLevel.RECALL, ['kn-bio-u-007']));
    out.push(b('kn-bio-u-027', KnowledgeBiology.GENETICS, '分子遗传',
      'DNA 半保留复制的机制与方向限制',
      '解旋酶打开复制叉,两条母链各作模板;聚合酶只能 5′→3′ 合成,故前导链连续、后随链以冈崎片段不连续合成,最后由连接酶封口;真核多起点、端粒解决末端缩短问题',
      ['5′→3′', '冈崎片段'], KnowledgeLevel.APPLY, ['kn-bio-u-026']));
    out.push(b('kn-bio-u-028', KnowledgeBiology.GENETICS, '分子遗传',
      '中心法则:转录与翻译',
      '遗传信息 DNA→mRNA(转录,RNA 聚合酶,真核需剪接去内含子)→蛋白质(翻译,核糖体读密码子,tRNA 反密码子配对);逆转录与 RNA 复制是补充,而信息不能从蛋白流回核酸',
      ['密码子 64', '简并性'], KnowledgeLevel.TRANSFER, ['kn-bio-u-027']));
    out.push(b('kn-bio-u-029', KnowledgeBiology.GENETICS, '变异',
      '基因突变的类型与后果',
      '碱基替换(同义、错义、无义)、插入或缺失;非三的倍数的插入缺失造成移码,后果通常最严重。突变是产生新等位基因的唯一途径,多数中性或有害,少数在特定环境下有利',
      ['移码'], KnowledgeLevel.APPLY, ['kn-bio-u-028']));
    out.push(b('kn-bio-u-030', KnowledgeBiology.GENETICS, '变异',
      '染色体变异:结构四类与数目两类',
      '结构变异为缺失、重复、倒位、易位(果蝇棒眼、人类慢性粒细胞白血病);数目变异分非整倍体(21 三体)与多倍体(四倍体小麦),后者在植物中常见且可立即造成生殖隔离',
      [], KnowledgeLevel.APPLY, ['kn-bio-u-029']));
    return out;
  }

  static evolution(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(b('kn-bio-u-031', KnowledgeBiology.EVOLUTION, '进化论的建立',
      '拉马克用进废退与达尔文自然选择的分界',
      '前者认为后天获得的性状可以遗传、变化有方向性;后者以「变异可遗传 + 生存斗争 + 适者留存」解释适应,不需要获得性遗传 —— 现代遗传学支持后者,表观遗传只在有限范围内补充',
      [], KnowledgeLevel.RECALL, ['kn-bio-u-029']));
    out.push(b('kn-bio-u-032', KnowledgeBiology.EVOLUTION, '进化论的建立',
      '自然选择的三个前提与它不产生"目的"',
      '个体间存在性状差异、差异部分可遗传、差异影响存活与繁殖 —— 三条成立则基因频率必然改变。选择没有预见性,"适应"是事后的统计结果而非目标',
      [], KnowledgeLevel.TRANSFER, ['kn-bio-u-031']));
    out.push(b('kn-bio-u-033', KnowledgeBiology.EVOLUTION, '现代综合',
      '种群是进化的单位、基因库与基因频率',
      '进化在个体层面不发生:个体基因型终生不变,变化的是种群一代代基因频率的分布;基因库是一个种群全部个体携带的基因总和',
      ['基因频率 p, q'], KnowledgeLevel.APPLY, ['kn-bio-u-032']));
    out.push(b('kn-bio-u-034', KnowledgeBiology.EVOLUTION, '现代综合',
      '哈代-温伯格平衡与它的五个前提',
      '在极大种群、随机交配、无突变、无迁移、无选择时,p² + 2pq + q² 恒定。它的作用是当零假设:实测偏离即提示某种力量在起作用,而杂合子频率 2pq 可用来估算隐性基因携带者',
      ['p² + 2pq + q² = 1'], KnowledgeLevel.TRANSFER, ['kn-bio-u-033']));
    out.push(b('kn-bio-u-035', KnowledgeBiology.EVOLUTION, '物种与隔离',
      '隔离是物种形成的必要条件',
      '地理隔离阻断基因交流后,各自积累突变、选择与漂变,一旦发展出生殖隔离(交配前或合子后)即成为两个物种;多倍体可在一次事件中立即成种,这是植物成种的重要捷径',
      [], KnowledgeLevel.APPLY, ['kn-bio-u-034', 'kn-bio-u-030']));
    out.push(b('kn-bio-u-036', KnowledgeBiology.EVOLUTION, '进化与多样性',
      '系统发育树怎么读:看分叉顺序而非横向位置',
      '树的每个节点是共同祖先,亲缘远近由最近共同祖先的先后决定,与末端分类单元的左右排列无关;长枝可能意味着快速演化或取样不足,不能直接当"高级"',
      [], KnowledgeLevel.TRANSFER, ['kn-bio-u-035']));
    return out;
  }

  static structureFunction(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(b('kn-bio-u-041', KnowledgeBiology.STRUCTURE_FUNCTION, '植物组织与器官',
      '植物五大组织的分工',
      '分生组织(顶生与侧生)负责生长,保护组织(表皮与周皮)防止失水与伤害,薄壁组织做光合、贮藏与通气,机械组织(厚角与厚壁)支撑,输导组织(导管筛管)运输',
      ['导管', '筛管'], KnowledgeLevel.RECALL, ['kn-bio-u-011']));
    out.push(b('kn-bio-u-042', KnowledgeBiology.STRUCTURE_FUNCTION, '植物组织与器官',
      '导管与筛管:死细胞运输与活细胞运输',
      '导管由死亡的原生质体消失后串成的空管组成,靠蒸腾拉力与根压向上运水与无机盐;筛管是活细胞但无核,靠伴胞供给代谢,以压力流机制双向运输光合产物',
      ['蒸腾拉力', '压力流'], KnowledgeLevel.APPLY, ['kn-bio-u-041', 'kn-bio-u-016']));
    out.push(b('kn-bio-u-043', KnowledgeBiology.STRUCTURE_FUNCTION, '植物代谢',
      '光合作用的两个阶段与物质能量流向',
      '光反应在类囊体膜上进行:水光解放氧、生成 ATP 与 NADPH;暗反应(卡尔文循环)在基质中由 Rubisco 固定 CO₂,消耗 ATP 与 NADPH 合成三碳糖。光反应供能、暗反应固碳',
      ['Rubisco', 'C3/C4'], KnowledgeLevel.TRANSFER, ['kn-bio-u-006']));
    out.push(b('kn-bio-u-044', KnowledgeBiology.STRUCTURE_FUNCTION, '植物代谢',
      '细胞呼吸三阶段与产能账',
      '糖酵解在细胞质把葡萄糖分解为丙酮酸净产 2 ATP 与 2 NADH;丙酮酸进线粒体氧化脱羧成乙酰 CoA;三羧酸循环彻底氧化底物并给出大量还原当量,电子传递链与化学渗透偶联才是 ATP 的主要来源',
      ['糖酵解', '三羧酸循环', '化学渗透'], KnowledgeLevel.TRANSFER, ['kn-bio-u-013', 'kn-bio-u-043']));
    out.push(b('kn-bio-u-045', KnowledgeBiology.STRUCTURE_FUNCTION, '植物激素',
      '五类主要激素的作用与两重性',
      '生长素促伸长与顶端优势、高浓度抑制侧芽(两重性)并诱导生根;赤霉素促茎伸长与种子萌发;细胞分裂素延缓衰老、解除顶端优势;脱落酸促气孔关闭与休眠;乙烯促果实成熟',
      ['两重性'], KnowledgeLevel.APPLY, ['kn-bio-u-041']));
    out.push(b('kn-bio-u-046', KnowledgeBiology.STRUCTURE_FUNCTION, '动物组织与内环境',
      '动物四大组织与内环境稳态',
      '上皮(保护吸收分泌)、结缔(支持连接运输)、肌肉(收缩)、神经(接受刺激与传导);细胞外液构成内环境,其温度、pH、渗透压与成分由神经-体液-免疫网络维持在窄区间',
      [], KnowledgeLevel.RECALL, ['kn-bio-u-014']));
    out.push(b('kn-bio-u-047', KnowledgeBiology.STRUCTURE_FUNCTION, '动物生理',
      '神经冲动的产生与传导机制',
      '静息电位约 −70 mV 由 K⁺ 外流维持;去极化达阈电位后 Na⁺ 通道正反馈开放形成动作电位(全或无),随后 Na⁺ 通道失活与 K⁺ 外流复极,不应期保证单向传导;髓鞘化使冲动跳跃式传导加快',
      ['静息电位', '全或无', '不应期'], KnowledgeLevel.TRANSFER, ['kn-bio-u-015']));
    out.push(b('kn-bio-u-048', KnowledgeBiology.STRUCTURE_FUNCTION, '动物生理',
      '突触传递与体液调节的区别',
      '电信号到突触前膜引起 Ca²⁺ 内流、囊泡释放递质、作用于突触后膜受体产生兴奋或抑制,单向且有延搁;神经调节快而精确、作用短,体液(激素)调节慢而广泛、持续久,二者常配合',
      [], KnowledgeLevel.APPLY, ['kn-bio-u-047']));
    return out;
  }

  static ecology(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(b('kn-bio-u-051', KnowledgeBiology.ECOLOGY, '种群',
      '种群的数量特征与两种增长模型',
      '密度、出生死亡、迁入迁出与年龄结构决定数量变动;无限环境下指数增长 dN/dt = rN,资源有限时逻辑斯蒂增长 dN/dt = rN(K−N)/K,在 K/2 时增速最大 —— 渔业与害控的阈值由此而来',
      ['r', 'K'], KnowledgeLevel.APPLY, ['kn-bio-u-033']));
    out.push(b('kn-bio-u-052', KnowledgeBiology.ECOLOGY, '群落',
      '生态位、竞争排斥与资源分区',
      '一个物种在群落中的位置与资源利用方式即生态位;两个物种生态位完全重叠则不能长期共存(高斯原理),实际通过时间、空间或食性分区实现共存',
      [], KnowledgeLevel.TRANSFER, ['kn-bio-u-051']));
    out.push(b('kn-bio-u-053', KnowledgeBiology.ECOLOGY, '生态系统',
      '能量流动单向递减,物质循环往返',
      '能量经食物链传递效率约 10%~20%,故营养级一般不超过四到五级,能量最终以热散失、必须不断输入;而 C、N、P 等元素在生物与非环境间循环,不增不减',
      ['10% 律'], KnowledgeLevel.APPLY, ['kn-bio-u-052']));
    out.push(b('kn-bio-u-054', KnowledgeBiology.ECOLOGY, '生态系统',
      '生物多样性及其三层含义与价值分层',
      '基因多样性、物种多样性与生态系统多样性三个层次;直接价值(食用药用)之外,间接价值(调节气候、保持水土、传粉)远大于直接价值,而潜在价值一旦物种灭绝即永久丧失',
      [], KnowledgeLevel.RECALL, ['kn-bio-u-053']));
    out.push(b('kn-bio-u-055', KnowledgeBiology.ECOLOGY, '生物圈与环境',
      '碳循环失衡与温室效应的机理',
      '光合固碳与呼吸、分解、燃烧释碳本近乎平衡;化石燃料开采与森林减少使大气 CO₂ 与 CH₄ 上升,它们透过可见光而吸收地表红外辐射,削弱了向太空散热',
      [], KnowledgeLevel.TRANSFER, ['kn-bio-u-053', 'kn-bio-u-043']));
    return out;
  }

  static all(): KnowledgePoint[] {
    return KnowledgeBiology.chemistryOfLife().concat(KnowledgeBiology.cell())
      .concat(KnowledgeBiology.genetics()).concat(KnowledgeBiology.evolution())
      .concat(KnowledgeBiology.structureFunction()).concat(KnowledgeBiology.ecology());
  }
}
