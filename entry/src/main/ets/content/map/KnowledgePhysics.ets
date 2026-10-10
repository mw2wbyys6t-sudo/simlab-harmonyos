import { KnowledgePoint, KnowledgeLevel, makeKnowledge } from './KnowledgeTypes';
import { MapSubject, SchoolStage, UNVERIFIED_PREFIX } from './CurriculumTypes';

/**
 * 大学物理知识点。
 *
 * **两张表的 `verified` 含义不同,别混着引用。** 实验表的出处为「这个实验确实开课」作证;
 * 这里的 `source` 只能为**覆盖面与排列顺序**作证(即「大学物理确实教这些、按这个次序」)。
 * 每条 statement 里的物理内容本身是可判对错的命题,它成立与否不依赖出处 ——
 * 靠离线断言和人的专业判断核,不靠引用。
 *
 * 覆盖面按通用教材体系(马文蔚《物理学》、张三慧《大学物理学》的常见编排)整理,
 * **未逐章核对过任何一本的目录**,所以第一轮全部标 `未核实:`。
 */
const PHY: MapSubject = MapSubject.PHYSICS;
const U: SchoolStage = SchoolStage.UNIVERSITY;
const COVERAGE: string = UNVERIFIED_PREFIX + '按通用教材体系整理覆盖面与顺序,未逐章核对目录';

function k(id: string, course: string, chapter: string, title: string, statement: string,
  symbols: string[], level: KnowledgeLevel, prereq: string[]): KnowledgePoint {
  return makeKnowledge(id, PHY, U, course, chapter, title, statement, symbols,
    level, prereq, COVERAGE);
}

export class KnowledgePhysics {
  static readonly MECHANICS: string = '力学';
  static readonly THERMODYNAMICS: string = '热学';
  static readonly ELECTROMAGNETISM: string = '电磁学';
  static readonly OPTICS: string = '光学';
  static readonly MODERN: string = '近代物理';

  static mechanics(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-phy-u-001', KnowledgePhysics.MECHANICS, '质点运动学', '位置矢量与位移',
      '位置矢量 r 从原点指向质点;位移 Δr = r(t+Δt) − r(t) 是矢量差,大小一般不等于路程,只有单向直线运动才相等',
      ['r = xi + yj + zk', '|Δr| ≤ s'], KnowledgeLevel.RECALL, []));
    out.push(k('kn-phy-u-002', KnowledgePhysics.MECHANICS, '质点运动学', '速度与速率的区分',
      '平均速度是位移除以时间(矢量),瞬时速度是 dr/dt;速率是瞬时速度的大小 |v|,不等于 |平均速度| 也不等于平均速率',
      ['v = dr/dt', '|v| = ds/dt'], KnowledgeLevel.APPLY, ['kn-phy-u-001']));
    out.push(k('kn-phy-u-003', KnowledgePhysics.MECHANICS, '质点运动学', '加速度及其切法向分解',
      'a = dv/dt;沿轨迹可分解为切向(改变速率)a_t = dv/dt 与法向(改变方向)a_n = v²/ρ,ρ 为该点曲率半径',
      ['a_t', 'a_n = v²/ρ'], KnowledgeLevel.APPLY, ['kn-phy-u-002']));
    out.push(k('kn-phy-u-004', KnowledgePhysics.MECHANICS, '质点运动学', '匀变速直线运动三式',
      'v = v0 + at、x = x0 + v0t + ½at²、v² = v0² + 2a(x − x0),三个量知二可求第三;自由落体是 a = g 的特例',
      ['a = 常量'], KnowledgeLevel.APPLY, ['kn-phy-u-003']));
    out.push(k('kn-phy-u-005', KnowledgePhysics.MECHANICS, '质点运动学', '抛体运动的独立性',
      '忽略空气阻力时水平方向匀速、竖直方向匀加速,两者互不影响;轨迹是抛物线,射程在 45° 时最大且与 90°−θ 对称',
      ['x = v0cosθ·t', 'y = v0sinθ·t − ½gt²'], KnowledgeLevel.APPLY, ['kn-phy-u-004']));
    out.push(k('kn-phy-u-006', KnowledgePhysics.MECHANICS, '质点运动学', '圆周运动的角量描述',
      '角位置 θ、角速度 ω = dθ/dt、角加速度 β = dω/dt;与线量关系 v = ωρ、a_t = βρ、a_n = ω²ρ',
      ['ω (rad/s)', 'v = ωr'], KnowledgeLevel.APPLY, ['kn-phy-u-003']));
    out.push(k('kn-phy-u-007', KnowledgePhysics.MECHANICS, '质点运动学', '相对运动与伽利略变换',
      '同一事件在两个相对匀速平动的参考系中坐标满足 x′ = x − ut、t′ = t;速度按 v = v′ + u 矢量相加,加速度在两系中相同',
      ['v = v′ + u'], KnowledgeLevel.APPLY, ['kn-phy-u-002']));
    out.push(k('kn-phy-u-008', KnowledgePhysics.MECHANICS, '牛顿运动定律', '牛顿第一定律与惯性系',
      '物体在不受外力时保持静止或匀速直线运动;它定义了惯性参考系,而第二定律只在惯性系中成立',
      ['ΣF = 0 ⇒ a = 0'], KnowledgeLevel.RECALL, ['kn-phy-u-007']));
    out.push(k('kn-phy-u-009', KnowledgePhysics.MECHANICS, '牛顿运动定律', '牛顿第二定律的矢量与瞬时性',
      'ΣF = dp/dt,质量不变时 = ma;力与加速度同向且同时存在同时消失,分量式各自独立成立。动量形式才普遍(变质量、高速情形)',
      ['F = dp/dt', 'F = ma'], KnowledgeLevel.APPLY, ['kn-phy-u-008']));
    out.push(k('kn-phy-u-010', KnowledgePhysics.MECHANICS, '牛顿运动定律', '牛顿第三定律与作用反作用',
      '两物体间的作用力与反作用力等大、反向、共线、同时产生,且必为同种性质的力 —— 因为作用在两个不同物体上,不能相互抵消',
      ['F₁₂ = −F₂₁'], KnowledgeLevel.APPLY, ['kn-phy-u-009']));
    out.push(k('kn-phy-u-011', KnowledgePhysics.MECHANICS, '常见的力', '重力、弹力与摩擦力',
      '重力 mg 竖直向下;弹簧弹力 F = −kx 沿轴线;摩擦力分静摩擦(0 ≤ f ≤ μsN,由平衡条件定值)与滑动摩擦(f = μkN,与相对滑动方向相反)',
      ['f_k = μk·N'], KnowledgeLevel.APPLY, ['kn-phy-u-009']));
    out.push(k('kn-phy-u-012', KnowledgePhysics.MECHANICS, '常见的力', '隔离体法与连接体问题',
      '把每个物体单独取出画受力图,列 ΣF = ma 分量式,再用绳或接触面的约束关系(加速度关联、轻绳张力处处相等)联立求解',
      [], KnowledgeLevel.TRANSFER, ['kn-phy-u-011', 'kn-phy-u-009']));
    out.push(k('kn-phy-u-013', KnowledgePhysics.MECHANICS, '功与能', '功与功率',
      '恒力功 W = F·s·cosθ;变力功是线积分 W = ∫F·dr;功率 P = F·v。功是标量,正负由力与位移的夹角决定',
      ['W (J)', 'P = F·v'], KnowledgeLevel.APPLY, ['kn-phy-u-011']));
    out.push(k('kn-phy-u-014', KnowledgePhysics.MECHANICS, '功与能', '动能定理',
      '合外力对质点做的功等于动能增量 W = ½mv₂² − ½mv₁²。它把过程量(功)与状态量(动能)联系起来,不必管中间的加速度细节',
      ['W_合 = ΔEk'], KnowledgeLevel.APPLY, ['kn-phy-u-013']));
    out.push(k('kn-phy-u-015', KnowledgePhysics.MECHANICS, '功与能', '保守力与势能',
      '做功与路径无关(沿闭合路径为零)的力是保守力,可引入势能:重力 mgh、弹性势能 ½kx²、万有引力 −GMm/r。势能零点可任选,差值才有意义',
      ['Ep = mgh', 'Ep = ½kx²'], KnowledgeLevel.APPLY, ['kn-phy-u-013']));
    out.push(k('kn-phy-u-016', KnowledgePhysics.MECHANICS, '功与能', '功能原理与机械能守恒',
      '除保守力外其他力做的功等于机械能增量 W_非保守 = Δ(Ek + Ep);当 W_非保守 = 0 时机械能守恒。有摩擦时机械能减少量等于产生的内能',
      ['E = Ek + Ep = 常量'], KnowledgeLevel.TRANSFER, ['kn-phy-u-015', 'kn-phy-u-014']));
    out.push(k('kn-phy-u-017', KnowledgePhysics.MECHANICS, '动量与冲量', '动量定理',
      '合外力的冲量等于动量增量 ∫F dt = Δp;它解释了缓冲、作用时间与力的反比关系,分量式可独立使用',
      ['I = Δp'], KnowledgeLevel.APPLY, ['kn-phy-u-009']));
    out.push(k('kn-phy-u-018', KnowledgePhysics.MECHANICS, '动量与冲量', '动量守恒定律',
      '系统所受合外力为零(或某方向分量为零则该方向守恒)时总动量不变。它比机械能守恒适用更广:碰撞、爆炸、反冲中即使能量不守恒,动量仍守恒',
      ['Σp = 常量'], KnowledgeLevel.TRANSFER, ['kn-phy-u-017', 'kn-phy-u-010']));
    out.push(k('kn-phy-u-019', KnowledgePhysics.MECHANICS, '动量与冲量', '质心与质心运动定理',
      '质心位置 r_C = Σmir_i / Σmi;系统总外力等于总质量乘质心加速度 ΣF_外 = M·a_C,内力不改变质心运动',
      ['ΣF_外 = M a_C'], KnowledgeLevel.APPLY, ['kn-phy-u-018']));
    out.push(k('kn-phy-u-020', KnowledgePhysics.MECHANICS, '刚体力学', '力矩与转动定律',
      '力对轴的矩 M = Fd(d 为力臂);刚体绕定轴转动时 ΣM = Iβ,与牛顿第二定律对应,转动惯量 I = Σmr² 是转动惯性的量度',
      ['M = Fd', 'ΣM = Iβ'], KnowledgeLevel.APPLY, ['kn-phy-u-009', 'kn-phy-u-006']));
    out.push(k('kn-phy-u-021', KnowledgePhysics.MECHANICS, '刚体力学', '角动量与角动量守恒',
      '质点对轴的角动量 L = r × p;刚体绕定轴 L = Iω。合外力矩为零时角动量守恒 —— 花样滑冰收臂、行星近日点加速都是它,I 减小则 ω 增大',
      ['L = Iω = 常量'], KnowledgeLevel.TRANSFER, ['kn-phy-u-020']));
    out.push(k('kn-phy-u-022', KnowledgePhysics.MECHANICS, '刚体力学', '刚体转动的动能与力的功',
      '转动动能 Ek = ½Iω²;力矩做功 W = ∫M dθ,动能定理对转动同样成立。 rolling 时总动能是平动加转动 ½mv² + ½Iω²',
      ['Ek = ½Iω²'], KnowledgeLevel.APPLY, ['kn-phy-u-020', 'kn-phy-u-014']));
    out.push(k('kn-phy-u-023', KnowledgePhysics.MECHANICS, '机械振动', '简谐振动的判据与三要素',
      '满足 d²x/dt² = −ω²x 的运动即简谐振动;x = A cos(ωt + φ),三要素是振幅 A、角频率 ω(由系统本身决定,如弹簧 √(k/m))、初相 φ(由初始条件决定)',
      ['x = A cos(ωt+φ)', 'ω = √(k/m)'], KnowledgeLevel.APPLY, ['kn-phy-u-006']));
    out.push(k('kn-phy-u-024', KnowledgePhysics.MECHANICS, '机械振动', '旋转矢量法与相位',
      '用长度为 A、以 ω 匀速转动的矢量在轴上的投影表示振动;相位 ωt+φ 决定运动状态,两振动的相位差决定它们是同相、反相还是超前落后',
      ['Δφ = 0 同相', 'Δφ = π 反相'], KnowledgeLevel.APPLY, ['kn-phy-u-023']));
    out.push(k('kn-phy-u-025', KnowledgePhysics.MECHANICS, '机械振动', '振动的能量与阻尼、共振',
      '简谐振动中动能与势能互相转化但总能量守恒,平均值正比于 A²;阻尼使振幅指数衰减;驱动力频率接近固有频率时发生共振,振幅出现峰值',
      ['E = ½kA²'], KnowledgeLevel.APPLY, ['kn-phy-u-023']));
    out.push(k('kn-phy-u-026', KnowledgePhysics.MECHANICS, '机械波', '波的产生与波速由介质决定',
      '机械波是振动在介质中的传播,质点不随波迁移;波速由介质的弹性与惯性决定(弦上 √(T/μ)、固体中取决于杨氏模量与密度),频率由波源决定,波长由两者共同决定 λ = u/f',
      ['u = λf', 'u = √(T/μ)'], KnowledgeLevel.APPLY, ['kn-phy-u-024']));
    out.push(k('kn-phy-u-027', KnowledgePhysics.MECHANICS, '机械波', '相干条件与干涉',
      '两列波要产生稳定干涉必须频率相同、振动方向一致、相位差恒定;波程差为波长整数倍处加强、半整数倍处减弱',
      ['δ = r₂ − r₁ = kλ 加强'], KnowledgeLevel.TRANSFER, ['kn-phy-u-026', 'kn-phy-u-024']));
    out.push(k('kn-phy-u-028', KnowledgePhysics.MECHANICS, '机械波', '驻波与多普勒效应',
      '两列同向相反、振幅相同的相干波叠加成驻波,波节间距 λ/2 且不传能;观察者与波源相对靠近时接收频率升高 f′ = f(u ± v_o)/(u ∓ v_s)',
      ['波节间距 = λ/2'], KnowledgeLevel.APPLY, ['kn-phy-u-027']));
    return out;
  }

  static thermodynamics(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-phy-u-041', KnowledgePhysics.THERMODYNAMICS, '气体动理论', '物质的量与理想气体模型',
      '1 mol 含阿伏加德罗常数 NA ≈ 6.022×10²³ 个分子;理想气体忽略分子体积与分子间作用力(除弹性碰撞外),是低压高温下的近似',
      ['NA', 'n = N/NA'], KnowledgeLevel.RECALL, []));
    out.push(k('kn-phy-u-042', KnowledgePhysics.THERMODYNAMICS, '气体动理论', '理想气体状态方程',
      'pV = nRT = NkT,平衡态下四个量满足此式;R = 8.31 J/(mol·K),k = R/NA。道尔顿分压定律是它的推论',
      ['pV = nRT'], KnowledgeLevel.APPLY, ['kn-phy-u-041']));
    out.push(k('kn-phy-u-043', KnowledgePhysics.THERMODYNAMICS, '气体动理论', '压强的微观解释',
      '压强是大量分子撞击器壁的平均效果 p = ⅓nmv²(方均根),把宏观量与分子平均平动动能联系起来,单个分子谈压强无意义',
      ['p = ⅓nm⟨v²⟩'], KnowledgeLevel.APPLY, ['kn-phy-u-042']));
    out.push(k('kn-phy-u-044', KnowledgePhysics.THERMODYNAMICS, '气体动理论', '温度是分子平均平动能的量度',
      '½m⟨v²⟩ = ⅓kT 的平均结果是 ⟨ε_k⟩ = (3/2)kT;温度是统计概念,对单个分子无温度可言。方均根速率 v_rms = √(3RT/M)',
      ['⟨ε⟩ = (3/2)kT'], KnowledgeLevel.APPLY, ['kn-phy-u-043']));
    out.push(k('kn-phy-u-045', KnowledgePhysics.THERMODYNAMICS, '气体动理论', '自由度与能量按自由度均分',
      '分子自由度 i:单原子 3、双原子 5(常温)、多原子 6;每个自由度的平均动能都是 ½kT,故分子平均总动能 = (i/2)kT',
      ['⟨E⟩ = (i/2)kT'], KnowledgeLevel.APPLY, ['kn-phy-u-044']));
    out.push(k('kn-phy-u-046', KnowledgePhysics.THERMODYNAMICS, '气体动理论', '理想气体的内能',
      '理想气体忽略分子势能,内能只含动能,故 U = (i/2)nRT 仅是温度的函数 —— 这是判断等温过程内能不变的依据',
      ['U = (i/2)nRT'], KnowledgeLevel.APPLY, ['kn-phy-u-045']));
    out.push(k('kn-phy-u-047', KnowledgePhysics.THERMODYNAMICS, '热力学第一定律', '内能、功与热量的关系',
      'Q = ΔU + W(系统吸热等于内能增量加对外做功);功是过程量、内能是状态量,所以同样初末态之间路径不同则 Q 与 W 不同',
      ['Q = ΔU + W'], KnowledgeLevel.APPLY, ['kn-phy-u-046']));
    out.push(k('kn-phy-u-048', KnowledgePhysics.THERMODYNAMICS, '热力学第一定律', '四个等值过程的功与吸热',
      '等容 W = 0;等压 W = pΔV、Q = nCp,mΔT;等温 Q = W = nRT ln(V₂/V₁);绝热 Q = 0、pV^γ = 常量、W = −ΔU = nCv,m(T₁ − T₂)',
      ['γ = Cp/Cv', 'pV^γ = 常量'], KnowledgeLevel.TRANSFER, ['kn-phy-u-047']));
    out.push(k('kn-phy-u-049', KnowledgePhysics.THERMODYNAMICS, '热力学第二定律', '循环效率与卡诺定理',
      '热机效率 η = W/Q₁ = 1 − Q₂/Q₁;工作在 T₁、T₂ 两恒温源之间的卡诺机效率 η = 1 − T₂/T₁,是同温限下一切热机效率的上限,与工作物质无关',
      ['η_carnot = 1 − T₂/T₁'], KnowledgeLevel.TRANSFER, ['kn-phy-u-048']));
    out.push(k('kn-phy-u-050', KnowledgePhysics.THERMODYNAMICS, '热力学第二定律', '熵与不可逆性',
      '可逆过程 dS = δQ/T,孤立系统的熵永不减少 ΔS ≥ 0;它给出过程方向性的判据,也说明第二类永动机不可能(热二律的开尔文与克劳修斯表述等价)',
      ['dS = δQ_rev/T'], KnowledgeLevel.APPLY, ['kn-phy-u-049']));
    return out;
  }

  static electromagnetism(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-phy-u-066', KnowledgePhysics.ELECTROMAGNETISM, '静电场', '库仑定律与叠加原理',
      '真空中两点电荷作用力 F = kq₁q₂/r²,沿连线,同号相斥;k = 1/(4πε₀) ≈ 9.0×10⁹;多个电荷的合力按矢量叠加,这是实验事实而非推导',
      ['F = q₁q₂/(4πε₀r²)'], KnowledgeLevel.APPLY, []));
    out.push(k('kn-phy-u-067', KnowledgePhysics.ELECTROMAGNETISM, '静电场', '电场强度及其计算',
      'E = F/q₀ 描述场本身(与试探电荷无关);点电荷 E = q/(4πε₀r²),连续分布用积分叠加。电场线不闭合、不相交,疏密表示大小',
      ['E (N/C 或 V/m)'], KnowledgeLevel.APPLY, ['kn-phy-u-066']));
    out.push(k('kn-phy-u-068', KnowledgePhysics.ELECTROMAGNETISM, '静电场', '高斯定理',
      '通过任意闭合面的电通量 Φ = ∮E·dS = Σq_内/ε₀,只由内部电荷决定;它普遍成立,但只有电荷分布具有对称性(球、无限长柱、无限大面)时才能直接求 E',
      ['∮E·dS = Σq/ε₀'], KnowledgeLevel.TRANSFER, ['kn-phy-u-067']));
    out.push(k('kn-phy-u-069', KnowledgePhysics.ELECTROMAGNETISM, '静电场', '电势与电势差',
      '静电场是保守场,环路积分为零,故可定义电势;U = qV 是电势能,电势差 V_ab = ∫E·dl。等势面与电场线正交,沿电场线电势降低',
      ['V (J/C = V)'], KnowledgeLevel.APPLY, ['kn-phy-u-068']));
    out.push(k('kn-phy-u-070', KnowledgePhysics.ELECTROMAGNETISM, '静电场', '静电平衡与导体上的电荷分布',
      '导体达到静电平衡时内部场强为零、整个导体是等势体、表面是等势面,净电荷只分布在表面且尖端处面密度最大;表面外侧场强垂直表面,大小 σ/ε₀',
      ['E_表面 = σ/ε₀'], KnowledgeLevel.APPLY, ['kn-phy-u-069']));
    out.push(k('kn-phy-u-071', KnowledgePhysics.ELECTROMAGNETISM, '静电场', '电容与电场能量',
      'C = Q/U 只由几何与介质决定(平行板 εS/d、球形 4πε₀R₁R₂/(R₂−R₁));电容器储能 W = ½CU² = Q²/(2C),能量密度 w = ½εE² 说明能量储在场中',
      ['C = εS/d', 'W = ½CU²'], KnowledgeLevel.APPLY, ['kn-phy-u-069']));
    out.push(k('kn-phy-u-072', KnowledgePhysics.ELECTROMAGNETISM, '静电场', '电介质的极化',
      '外场使介质分子取向或畸变,表面出现束缚电荷,削弱内部场;用相对介电常数 εr 描述,有介质时高斯定理改写为 ∮D·dS = q_自由',
      ['D = ε₀εr E'], KnowledgeLevel.APPLY, ['kn-phy-u-071']));
    out.push(k('kn-phy-u-073', KnowledgePhysics.ELECTROMAGNETISM, '恒定磁场', '电流、电动势与非静电力',
      '电流 I = dq/dt = nqSv_d(漂移速度);电动势描述电源内非静电力移送单位正电荷做的功 ε = ∫F_k·dl/q,它维持住导体两端的电势差',
      ['ε = W_非静/q'], KnowledgeLevel.APPLY, ['kn-phy-u-066']));
    out.push(k('kn-phy-u-074', KnowledgePhysics.ELECTROMAGNETISM, '恒定磁场', '毕奥-萨伐尔定律与典型电流的磁场',
      '电流元 Idl 在场点产生 dB = μ₀I dl × r̂ /(4πr²);叠加得长直导线 B = μ₀I/(2πr)、圆心 B = μ₀I/(2R)、螺线管内部 B = μ₀nI',
      ['B (T)', 'μ₀ = 4π×10⁻⁷'], KnowledgeLevel.APPLY, ['kn-phy-u-073']));
    out.push(k('kn-phy-u-075', KnowledgePhysics.ELECTROMAGNETISM, '恒定磁场', '安培环路定理与磁高斯定理',
      '∮B·dl = μ₀ΣI_穿(电流与路径满足右手关系),只在稳恒电流下成立,同样只有对称分布才能直接求 B;而 ∮B·dS = 0 说明磁感线闭合、不存在磁单极',
      ['∮B·dl = μ₀ΣI'], KnowledgeLevel.TRANSFER, ['kn-phy-u-074', 'kn-phy-u-068']));
    out.push(k('kn-phy-u-076', KnowledgePhysics.ELECTROMAGNETISM, '磁场对电流与电荷的作用', '洛伦兹力与安培力',
      '运动电荷受力 F = qv × B,恒与速度垂直故不做功,导致匀速圆周(r = mv/qB)或等距螺旋;载流导线受力是大量电荷受力的宏观表现 F = IL × B',
      ['F = qv × B', 'r = mv/(qB)'], KnowledgeLevel.APPLY, ['kn-phy-u-074']));
    out.push(k('kn-phy-u-077', KnowledgePhysics.ELECTROMAGNETISM, '电磁感应', '法拉第电磁感应定律与楞次定律',
      '穿过回路的磁通变化时产生感应电动势 ε = −dΦ/dt,负号即楞次定律:感应电流的效果总是反抗引起它的那份磁通变化 —— 它是能量守恒在电磁感应中的体现',
      ['ε = −dΦ_B/dt'], KnowledgeLevel.TRANSFER, ['kn-phy-u-075']));
    out.push(k('kn-phy-u-078', KnowledgePhysics.ELECTROMAGNETISM, '电磁感应', '动生与感生电动势',
      '导体在恒定场中运动切割磁感线是动生电动势,非静电力是洛伦兹力;磁场本身变化产生涡旋电场,驱动静止导体中的电荷是感生电动势 —— 两者来源不同而结果同由 ε = −dΦ/dt 统一',
      [], KnowledgeLevel.TRANSFER, ['kn-phy-u-077']));
    out.push(k('kn-phy-u-079', KnowledgePhysics.ELECTROMAGNETISM, '电磁感应', '自感、互感与磁场能量',
      '回路自身电流变化引起本回路电动势为自感 ε_L = −L dI/dt,两回路间为互感;线圈储能 W = ½LI²,磁场能量密度 w = B²/(2μ)',
      ['L (H)', 'W = ½LI²'], KnowledgeLevel.APPLY, ['kn-phy-u-078']));
    out.push(k('kn-phy-u-080', KnowledgePhysics.ELECTROMAGNETISM, '麦克斯韦方程组', '位移电流',
      '变化的电场等效于一种电流 I_d = ε₀dΦ_E/dt,把它补进安培环路定理后 ∮B·dl = μ₀(I + ε₀dΦ_E/dt) 才对非稳恒情形成立,电荷守恒才不被破坏',
      ['I_d = ε₀dΦ_E/dt'], KnowledgeLevel.APPLY, ['kn-phy-u-075']));
    out.push(k('kn-phy-u-081', KnowledgePhysics.ELECTROMAGNETISM, '麦克斯韦方程组', '麦克斯韦方程组与电磁波',
      '四个积分式(电高斯、磁高斯、法拉第、全电流)概括经典电磁学;由它推出变化的 E 与 B 互相激发并以 c = 1/√(μ₀ε₀) 传播,光即电磁波',
      ['c = 1/√(μ₀ε₀)'], KnowledgeLevel.TRANSFER, ['kn-phy-u-080', 'kn-phy-u-077']));
    return out;
  }

  static optics(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-phy-u-091', KnowledgePhysics.OPTICS, '几何光学', '折射定律与全反射',
      'n₁sin i = n₂sin r,折射率 n = c/v 描述介质中光速变慢;光从光密到光疏且入射角大于临界角 arcsin(n₂/n₁) 时发生全反射,这是光纤导光的原理',
      ['n = c/v', 'sin C = n₂/n₁'], KnowledgeLevel.APPLY, []));
    out.push(k('kn-phy-u-092', KnowledgePhysics.OPTICS, '几何光学', '球面折射与薄透镜成像',
      '单球面 n₁/s + n₂/s′ = (n₂ − n₁)/R;薄透镜 1/u + 1/v = 1/f,符号约定(实物为正、实像为正)决定公式能否用对,放大率 m = −v/u',
      ['1/u + 1/v = 1/f'], KnowledgeLevel.TRANSFER, ['kn-phy-u-091']));
    out.push(k('kn-phy-u-093', KnowledgePhysics.OPTICS, '几何光学', '光心的概念与费马原理',
      '光在两点间沿光程取极值(通常最小)的路径传播 n·s 的极值;由它可推出反射与折射定律,是几何光学的统一原理',
      ['δ∫n ds = 0'], KnowledgeLevel.RECALL, ['kn-phy-u-091']));
    out.push(k('kn-phy-u-094', KnowledgePhysics.OPTICS, '光的干涉', '相干条件与光程',
      '两束光频率相同、振动方向一致、相位差恒定才能产生稳定干涉;光程 ns 把介质中的路径折算成真空等价路径,干涉级由光程差决定 δ = kλ 加强、(2k+1)λ/2 减弱',
      ['δ = kλ 明纹'], KnowledgeLevel.APPLY, ['kn-phy-u-091']));
    out.push(k('kn-phy-u-095', KnowledgePhysics.OPTICS, '光的干涉', '分波前与分振幅两类获得相干光的方法',
      '杨氏双缝、菲涅耳双棱镜把同一波面分成两份(分波前);薄膜、牛顿环、迈克尔逊把一束光的振幅分成反射与透射两份(分振幅),后者条纹更亮但光程差小',
      [], KnowledgeLevel.APPLY, ['kn-phy-u-094']));
    out.push(k('kn-phy-u-096', KnowledgePhysics.OPTICS, '光的干涉', '薄膜干涉与增透膜',
      '厚度均匀的薄膜在同一倾角下给出同级条纹(等倾);反射时若从光疏射向光密要附加半波损失 λ/2,故增透膜取厚度 λ/(4n) 使两反射面相消',
      ['2nd + λ/2 = kλ'], KnowledgeLevel.TRANSFER, ['kn-phy-u-095']));
    out.push(k('kn-phy-u-097', KnowledgePhysics.OPTICS, '光的干涉', '牛顿环与劈尖',
      '透镜与平面玻璃间的空气楔产生等厚干涉环,第 k 环半径 r = √(kRλ),中心为暗斑;劈尖相邻明纹对应厚度差 λ/(2n),可用来测微小厚度与检验表面平整度',
      ['r_k = √(kRλ)'], KnowledgeLevel.APPLY, ['kn-phy-u-096']));
    out.push(k('kn-phy-u-098', KnowledgePhysics.OPTICS, '光的干涉', '迈克尔逊干涉仪与波长测量',
      '分振幅的两臂光程差 2d cos i,动镜移动 λ/2 条纹吞或吐一条,故数条纹变化即可测微小位移或反算波长;钠光双线可用相干长度差测波长差',
      ['Δd = Nλ/2'], KnowledgeLevel.TRANSFER, ['kn-phy-u-097']));
    out.push(k('kn-phy-u-099', KnowledgePhysics.OPTICS, '光的衍射', '惠更斯-菲涅耳原理与菲涅耳半波带',
      '波面上每点都是次波源,其包络是新的波面;把波面按半波带划分,相邻带贡献反相,故带数奇偶决定中心明暗 —— 它解释了障碍几何阴影边缘的明暗条纹',
      [], KnowledgeLevel.APPLY, ['kn-phy-u-094']));
    out.push(k('kn-phy-u-100', KnowledgePhysics.OPTICS, '光的衍射', '单缝夫琅禾费衍射',
      '暗纹条件 a sinθ = kλ(k = ±1,±2…),中央明纹角宽度是其他级的两倍;缝越窄或波长越长衍射越明显,分辨率受此限制',
      ['a sinθ = kλ 暗纹'], KnowledgeLevel.APPLY, ['kn-phy-u-099']));
    out.push(k('kn-phy-u-101', KnowledgePhysics.OPTICS, '光的衍射', '圆孔衍射与瑞利判据',
      '圆孔衍射形成爱里斑,半角宽 1.22λ/D;两点对透镜张角不小于爱里斑半径时恰能分辨,这就是光学仪器与望远镜的分辨极限',
      ['θ = 1.22λ/D'], KnowledgeLevel.APPLY, ['kn-phy-u-100']));
    out.push(k('kn-phy-u-102', KnowledgePhysics.OPTICS, '光的衍射', '光栅方程与色散本领',
      'd sinθ = kλ 决定主极大位置,光栅常数越小、级次越高则角色散越大;缺级发生在缝宽与间距成整数比处,分辨率 R = kN 随总缝数增大',
      ['d sinθ = kλ', 'R = kN'], KnowledgeLevel.TRANSFER, ['kn-phy-u-101']));
    out.push(k('kn-phy-u-103', KnowledgePhysics.OPTICS, '光的偏振', '偏振态、马吕斯定律与布儒斯特角',
      '自然光通过偏振片强度减半;线偏振光过检偏器 I = I₀cos²θ;反射光在入射角满足 tan i_B = n₂/n₁ 时完全偏振,偏振方向垂直入射面',
      ['I = I₀cos²θ', 'tan i_B = n₂/n₁'], KnowledgeLevel.APPLY, ['kn-phy-u-091']));
    out.push(k('kn-phy-u-104', KnowledgePhysics.OPTICS, '光的偏振', '双折射与波片',
      '各向异性晶体中 o 光与 e 光折射率不同而分开;λ/4 波片把线偏振变圆偏振(或反之),λ/2 波片把偏振面旋转两倍角度,这是偏振态变换的基本元件',
      ['δ = 2π(n_o − n_e)d/λ'], KnowledgeLevel.APPLY, ['kn-phy-u-103']));
    return out;
  }

  static modern(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-phy-u-111', KnowledgePhysics.MODERN, '量子概念的引入', '黑体辐射与普朗克能量子',
      '绝对黑体的单色辐出度只依赖温度与波长;维恩位移定律 λ_m T = 常量说明峰值随温度蓝移,斯特藩-玻尔兹曼定律 M = σT⁴;普朗克假设能量按 hν 一份份发射吸收才解释全谱',
      ['E = hν', 'λ_m T = b'], KnowledgeLevel.RECALL, []));
    out.push(k('kn-phy-u-112', KnowledgePhysics.MODERN, '量子概念的引入', '光电效应与光子',
      '存在红限频率,遏止电压只随频率线性变化而与光强无关,发射瞬时发生 —— 经典波动说解释不了。爱因斯坦用光子 E = hν 给出 hν = A + ½mv²_max',
      ['hν = A + E_k'], KnowledgeLevel.APPLY, ['kn-phy-u-111']));
    out.push(k('kn-phy-u-113', KnowledgePhysics.MODERN, '量子概念的引入', '康普顿效应',
      'X 射线被自由电子散射后波长变长 Δλ = (h/mc)(1 − cosθ),且与散射物质无关;它证明光子不仅带能量还带动量 p = h/λ',
      ['Δλ = λ_C(1 − cosθ)'], KnowledgeLevel.APPLY, ['kn-phy-u-112']));
    out.push(k('kn-phy-u-114', KnowledgePhysics.MODERN, '原子的量子理论', '玻尔氢原子模型',
      '定态假设(角动量量子化 L = nħ)+ 频率条件 hν = E₂ − E₁,给出 E_n = −13.6/n² eV 与半径 a₀n²;巴耳末系等谱线系由能级差直接算出',
      ['E_n = −13.6/n² eV'], KnowledgeLevel.APPLY, ['kn-phy-u-112']));
    out.push(k('kn-phy-u-115', KnowledgePhysics.MODERN, '原子的量子理论', '德布罗意波与波粒二象性',
      '实物粒子也有波动性,λ = h/p;电子衍射(戴维孙-革末)证实之。宏观物体波长极短故波动性不可见 —— 这不是假设而是与光电、康普顿共同构成的对称图景',
      ['λ = h/p'], KnowledgeLevel.APPLY, ['kn-phy-u-113']));
    out.push(k('kn-phy-u-116', KnowledgePhysics.MODERN, '原子的量子理论', '不确定性原理',
      '位置与动量不能同时确定,Δx·Δp ≥ ħ/2(能量与时间同理)。它不是测量技术的缺陷,而是波粒二象性的必然结果,并解释了原子基态不坍缩',
      ['Δx Δp ≥ ħ/2'], KnowledgeLevel.RECALL, ['kn-phy-u-115']));
    out.push(k('kn-phy-u-117', KnowledgePhysics.MODERN, '原子的量子理论', '波函数与玻恩统计解释',
      '微观状态由波函数 Ψ(r,t) 描述,|Ψ|² 是概率密度(不是实在的物质密度);波函数须单值、有限、连续并归一化 ∫||²dV = 1',
      ['∫|Ψ|² dV = 1'], KnowledgeLevel.APPLY, ['kn-phy-u-115']));
    out.push(k('kn-phy-u-118', KnowledgePhysics.MODERN, '原子的量子理论', '定态薛定谔方程与一维无限深势阱',
      '−(ħ²/2m)∇²ψ + Uψ = Eψ;势阱宽度 L 内解得 E_n = n²π²ħ²/(2mL²),能量量子化与零点能都由边界条件自然出现,不需额外假设',
      ['E_n ∝ n²'], KnowledgeLevel.TRANSFER, ['kn-phy-u-117']));
    out.push(k('kn-phy-u-119', KnowledgePhysics.MODERN, '原子的量子理论', '氢原子的四个量子数',
      '主量子数 n 定能量、角量子数 l 定轨道角动量大小、磁量子数 m 定空间取向、自旋磁量子数 m_s 定自旋投影;l 取 0…n−1,m 取 −l…+l,这是泡利不相容原理的前提',
      ['L = √(l(l+1))ħ'], KnowledgeLevel.APPLY, ['kn-phy-u-118']));
    out.push(k('kn-phy-u-120', KnowledgePhysics.MODERN, '原子核与粒子', '核的组成、放射性衰变与半衰期',
      '原子核由质子与中子组成,质量数 A = Z + N;α、β、γ 三种射线分别对应氦核、电子(或正电子)与光子,衰变服从 N = N₀e^(−λt),半衰期 T₁/₂ = ln2/λ',
      ['T_½ = ln2/λ'], KnowledgeLevel.APPLY, ['kn-phy-u-114']));
    out.push(k('kn-phy-u-121', KnowledgePhysics.MODERN, '原子核与粒子', '质量亏损与结合能',
      '核质量小于其核子质量之和,亏损 Δm 对应结合能 ΔE = Δmc²;比结合能曲线在铁附近最高,故重核裂变与轻核聚变都放能',
      ['E = mc²'], KnowledgeLevel.APPLY, ['kn-phy-u-120']));
    out.push(k('kn-phy-u-122', KnowledgePhysics.MODERN, '激光与固体', '受激辐射与激光的特性',
      '粒子数反转下受激辐射超过自发辐射,谐振腔选模放大后得到方向性好、单色性与相干性高、亮度大的激光;它需要亚稳态能级才能维持反转',
      [], KnowledgeLevel.RECALL, ['kn-phy-u-114']));
    return out;
  }

  static all(): KnowledgePoint[] {
    return KnowledgePhysics.mechanics().concat(KnowledgePhysics.thermodynamics())
      .concat(KnowledgePhysics.electromagnetism()).concat(KnowledgePhysics.optics())
      .concat(KnowledgePhysics.modern());
  }
}
