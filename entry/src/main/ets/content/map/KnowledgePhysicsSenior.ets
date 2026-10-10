import { KnowledgePoint, KnowledgeLevel, makeKnowledge } from './KnowledgeTypes';
import { MapSubject, SchoolStage, UNVERIFIED_PREFIX } from './CurriculumTypes';

/**
 * 高中物理知识点。
 *
 * **`source` 只为覆盖面与顺序作证,不为物理内容作证。** 一条 statement 是否成立靠专业判断和
 * 离线断言核,不靠引用;这里要说清的是「高中物理确实教这些、按这个册次与章序排」。
 *
 * 章名照人教版(2019)六册的目录取:必修一 = 运动的描述 / 匀变速直线运动的研究 /
 * 相互作用——力 / 运动和力的关系,必修二 = 抛体运动 / 圆周运动 / 万有引力与宇宙航行 /
 * 机械能守恒定律,必修三 = 静电场 / 电路及其应用 / 电能 能量守恒定律,
 * 选择性必修一 = 动量守恒定律 / 机械振动 / 机械波 / 光,
 * 选择性必修二 = 安培力与洛伦兹力 / 电磁感应 / 交变电流 / 电磁振荡与电磁波,
 * 选择性必修三 = 分子动理论 / 气体、固体和液体 / 热力学定律 / 原子结构 / 原子核。
 * 这些章名参考了网上的人教版教材目录页,**没有核对过教材纸质目录与《课程标准》原文**,
 * 所以仍然全部带 `未核实:` 前缀 —— 二手清单不足以让一条数据对外声称已核实。
 *
 * 一条原则:前置只引用**本文件内序号更小的 id**(001–053)。大学表里那些 `kn-phy-u-*`
 * 讲的是同一件事的更一般版本(如 kn-phy-u-023 简谐振动判据),但跨文件引用会被
 * MapValidator.validateKnowledge 判成悬挂引用 —— 两张表各自成链,不做跨表跳转。
 *
 * 有意没写的:传感器(选必二第五章,依赖实物敏感元件,更适合当实验条目而不是知识点)、
 * 多用电表的读数与使用(它是一门操作技能,判不了对错)。
 */
const PHY: MapSubject = MapSubject.PHYSICS;
const SR: SchoolStage = SchoolStage.SENIOR;
const COVERAGE: string = UNVERIFIED_PREFIX + '章名与顺序按人教版高中物理教材编排,参考网络教材目录页,未逐条核对教材与课标原文';

function k(id: string, course: string, chapter: string, title: string, statement: string,
  symbols: string[], level: KnowledgeLevel, prereq: string[]): KnowledgePoint {
  return makeKnowledge(id, PHY, SR, course, chapter, title, statement, symbols,
    level, prereq, COVERAGE);
}

export class KnowledgePhysicsSenior {
  static readonly REQUIRED_ONE: string = '必修一';
  static readonly REQUIRED_TWO: string = '必修二';
  static readonly REQUIRED_THREE: string = '必修三';
  static readonly ELECTIVE_ONE: string = '选择性必修一';
  static readonly ELECTIVE_TWO: string = '选择性必修二';
  static readonly ELECTIVE_THREE: string = '选择性必修三';

  /** 必修一:运动学 + 相互作用力 + 牛顿运动定律 */
  static kinematicsAndDynamics(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-phy-sr-001', KnowledgePhysicsSenior.REQUIRED_ONE, '运动的描述', '质点模型与参考系的选取',
      '能否把物体看成质点取决于所研究的问题而不是物体自身大小:研究地球公转可以,研究自转和姿态就不行。必须先选定参考系才能谈运动,同一运动相对不同参考系的描述不同',
      ['理想模型'], KnowledgeLevel.RECALL, []));
    out.push(k('kn-phy-sr-002', KnowledgePhysicsSenior.REQUIRED_ONE, '运动的描述', '位移与路程、平均速度与平均速率',
      '位移由初位置指向末位置,是矢量;路程是轨迹长度,是标量,只有单向直线运动中两者大小才相等。平均速度是位移比时间,平均速率是路程比时间,沿跑道跑一圈的平均速度为零而平均速率不为零',
      ['v̄ = Δx/Δt', 's ≥ |Δx|'], KnowledgeLevel.RECALL, ['kn-phy-sr-001']));
    out.push(k('kn-phy-sr-003', KnowledgePhysicsSenior.REQUIRED_ONE, '运动的描述', '加速度的方向由速度变化量决定',
      'a = Δv/Δt 是速度的变化率,与速度大小没有必然联系:高速匀速的物体 a = 0,刚点火启动的火箭 v = 0 而 a ≠ 0。a 的方向与 Δv 一致,当 a 与 v 反向时速率就减小,与 a 本身是增大还是减小无关',
      ['a = Δv/Δt', 'a ∥ Δv'], KnowledgeLevel.APPLY, ['kn-phy-sr-002']));
    out.push(k('kn-phy-sr-004', KnowledgePhysicsSenior.REQUIRED_ONE, '运动的描述', 'v-t 图像的斜率与面积',
      'v-t 图线的斜率表示加速度,图线与时间轴围成的面积表示位移,位于时间轴下方的面积计为负位移。x-t 图的斜率才表示速度,两图形状可能相同而含义完全不同,也不能把 v-t 图线当成运动轨迹',
      ['斜率 → a', '面积 → x'], KnowledgeLevel.APPLY, ['kn-phy-sr-003']));
    out.push(k('kn-phy-sr-005', KnowledgePhysicsSenior.REQUIRED_ONE, '匀变速直线运动', '基本公式与适用条件',
      'v = v₀ + at、x = v₀t + ½at²、v² − v₀² = 2ax 只对加速度恒定的直线运动成立,五个量中已知三个即可求另外两个。用位移公式前要先判断物体何时停下,刹车问题里停下之后不再反向加速,不能直接把过大的 t 代入',
      ['a = 常量'], KnowledgeLevel.APPLY, ['kn-phy-sr-003']));
    out.push(k('kn-phy-sr-006', KnowledgePhysicsSenior.REQUIRED_ONE, '匀变速直线运动', '自由落体与竖直上抛的对称性',
      '自由落体是初速度为零、加速度为 g 的匀变速直线运动,忽略空气阻力时下落快慢与质量无关。竖直上抛的上升与下落经过同一位置时速率相等、时间对称,全程可统一按 a = −g 求解而不必分段',
      ['h = ½gt²', 'g ≈ 9.8 m/s²'], KnowledgeLevel.APPLY, ['kn-phy-sr-005']));
    out.push(k('kn-phy-sr-007', KnowledgePhysicsSenior.REQUIRED_ONE, '相互作用力', '弹力的方向与胡克定律',
      '弹力方向与施力物体恢复形变的方向一致:绳的拉力沿绳而背离被拉物体,接触面的支持力垂直于面。弹簧在弹性限度内 F = kx,其中 x 是形变量而不是弹簧的长度,k 由弹簧自身决定,不随 F 或 x 变化',
      ['F = kx'], KnowledgeLevel.APPLY, []));
    out.push(k('kn-phy-sr-008', KnowledgePhysicsSenior.REQUIRED_ONE, '相互作用力', '静摩擦力与滑动摩擦力的判断',
      '摩擦力方向与相对运动或相对运动趋势相反,而不是与运动方向相反,所以摩擦力可以做正功、可以使物体加速(传送带)。滑动摩擦力 f = μN 只由动摩擦因数和正压力决定,与接触面积、相对速度大小均无关;静摩擦力是被动力,大小由平衡条件或牛顿第二定律求出,取值范围 0 ≤ f ≤ f_max,一般不等于 μN',
      ['f_滑 = μN', '0 ≤ f_静 ≤ f_max', '与接触面积无关'], KnowledgeLevel.APPLY, ['kn-phy-sr-007']));
    out.push(k('kn-phy-sr-009', KnowledgePhysicsSenior.REQUIRED_ONE, '相互作用力', '力的合成与分解是等效替代',
      '共点力的合成与分解都遵循平行四边形定则,合力大小介于 |F₁ − F₂| 与 F₁ + F₂ 之间、随两力夹角增大而减小,因此合力可以小于任一分力。分力与合力是等效替代关系,受力图上不能同时画出;分解要按力的实际作用效果进行,而不是随意建轴',
      ['平行四边形定则', '|F₁−F₂| ≤ F ≤ F₁+F₂'], KnowledgeLevel.APPLY, ['kn-phy-sr-007']));
    out.push(k('kn-phy-sr-010', KnowledgePhysicsSenior.REQUIRED_ONE, '相互作用力', '共点力平衡与斜面上的力分解',
      '物体处于平衡态时合外力为零,任意方向上的分力和都为零;三个共点力平衡时必共面且可拼成封闭三角形。倾角 θ 的斜面上静止的物块受重力、支持力和静摩擦,支持力 N = mgcosθ 并不等于重力,沿斜面向下的 mg sinθ 只是重力的分力而不是新受到的一个力',
      ['N = mgcosθ', 'ΣF = 0'], KnowledgeLevel.APPLY, ['kn-phy-sr-009']));
    out.push(k('kn-phy-sr-011', KnowledgePhysicsSenior.REQUIRED_ONE, '牛顿运动定律', '牛顿第一定律与惯性',
      '惯性是物体保持原有运动状态的性质,质量是惯性大小的唯一量度,与速度、受力和所在位置都无关。牛顿第一定律给出了不受力时的运动规律并由此定义了惯性参考系,它不是第二定律在 ΣF = 0 时的简单特例',
      ['惯性只由 m 决定'], KnowledgeLevel.RECALL, ['kn-phy-sr-008']));
    out.push(k('kn-phy-sr-012', KnowledgePhysicsSenior.REQUIRED_ONE, '牛顿运动定律', '牛顿第二定律的矢量性与瞬时性',
      '加速度方向始终与合外力方向相同,二者同时产生、同时变化、同时消失:合力突变的瞬间 a 立即改变而速度还来不及改变,所以 F = ma 是瞬时对应关系,不能理解成力消失后物体才慢慢停下。速度大的物体加速度不一定大,合外力与速度大小没有直接关系',
      ['ΣF = ma', 'a ∥ ΣF'], KnowledgeLevel.APPLY, ['kn-phy-sr-011']));
    out.push(k('kn-phy-sr-013', KnowledgePhysicsSenior.REQUIRED_ONE, '牛顿运动定律', '作用力与反作用力不是平衡力',
      '作用力与反作用力等大、反向、共线、同性质、同时产生同时消失,但分别作用在两个不同物体上,不能求合力、不能相互抵消。一对平衡力作用在同一物体上,性质可以不同,其中一个消失时另一个仍可存在',
      ['F₁₂ = −F₂₁'], KnowledgeLevel.APPLY, ['kn-phy-sr-012']));
    out.push(k('kn-phy-sr-014', KnowledgePhysicsSenior.REQUIRED_ONE, '牛顿运动定律', '受力分析与整体法、隔离法',
      '按重力—弹力—摩擦力—已知外力的顺序只画性质力,每个力都必须能找到施力物体,不重复画效果力。求系统共同的加速度可把系统当整体,求绳或接触面之间的内力必须隔离;轻绳的张力处处相等,而轻杆的弹力方向不一定沿杆',
      ['先整体后隔离'], KnowledgeLevel.TRANSFER, ['kn-phy-sr-010', 'kn-phy-sr-012']));
    out.push(k('kn-phy-sr-015', KnowledgePhysicsSenior.REQUIRED_ONE, '牛顿运动定律', '恰好下滑的临界角 μ = tanθ',
      '物块沿斜面匀速下滑时 mg sinθ = μmg cosθ,消去 m 得 μ = tanθ,所以恰好能自动下滑的临界倾角只由动摩擦因数决定,与滑块质量、斜面长度和初速度都无关。倾角小于临界角时静摩擦足以维持静止,大于临界角则加速下滑且 a = g(sinθ − μcosθ)',
      ['μ = tanθ_c', 'a = g(sinθ − μcosθ)'], KnowledgeLevel.APPLY, ['kn-phy-sr-010', 'kn-phy-sr-012']));
    return out;
  }

  /** 必修二:曲线运动、万有引力与机械能 */
  static curvilinearAndEnergy(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-phy-sr-016', KnowledgePhysicsSenior.REQUIRED_TWO, '抛体运动', '曲线运动的条件与分运动独立性',
      '合外力方向与速度方向不在同一直线上时物体做曲线运动,速度沿轨迹切线方向、合力总指向轨迹凹侧。几个分运动各自独立、互不影响,且与合运动同时开始同时结束,位移与速度按平行四边形定则合成',
      ['v 沿切线', '等时性'], KnowledgeLevel.APPLY, ['kn-phy-sr-003']));
    out.push(k('kn-phy-sr-017', KnowledgePhysicsSenior.REQUIRED_TWO, '抛体运动', '平抛运动的时间只由高度决定',
      '平抛可分解为水平方向的匀速直线运动和竖直方向的自由落体,落地时间 t = √(2h/g) 只由下落高度决定而与初速度无关,水平射程 x = v₀t 才同时取决于两者。落地时速度方向与水平夹角 tanθ_v 是位移夹角 tanθ_x 的两倍,且末速度方向与初速度大小无关',
      ['t = √(2h/g)', 'tanθ_v = 2tanθ_x'], KnowledgeLevel.APPLY, ['kn-phy-sr-016', 'kn-phy-sr-006']));
    out.push(k('kn-phy-sr-018', KnowledgePhysicsSenior.REQUIRED_TWO, '圆周运动', '向心加速度与向心力的来源',
      '匀速圆周运动的加速度 a_n = v²/r = ω²r = 4π²r/T² 指向圆心,只改变速度方向而不改变速率,故向心力对物体不做功。向心力是按作用效果命名的,必须由某个或某几个实际力(拉力、静摩擦、重力分量或它们的合力)提供,受力分析时不能再另外加上一个向心力',
      ['a_n = v²/r = ω²r'], KnowledgeLevel.APPLY, ['kn-phy-sr-012']));
    out.push(k('kn-phy-sr-019', KnowledgePhysicsSenior.REQUIRED_TWO, '圆周运动', '竖直圆轨道的临界速度与传动关系',
      '绳或内侧轨道模型在最高点的最小速度满足 mg = mv²/r,即 v = √(gr),小于它物块就脱离轨道;而杆或圆管模型最高点速度可以为零,因为支撑物既能拉也能推。同轴转动各点 ω 相同、a_n 与 r 成正比,皮带不打滑传动时边缘线速度大小相同、a_n 与 r 成反比,两者用的公式不同',
      ['v_临 = √(gr)', '同轴 ω 相同'], KnowledgeLevel.APPLY, ['kn-phy-sr-018']));
    out.push(k('kn-phy-sr-020', KnowledgePhysicsSenior.REQUIRED_TWO, '万有引力与宇宙航行', '万有引力定律与 G 的测定',
      'F = GMm/r² 适用于质点或均匀球体,r 取球心距,不能把贴近表面的物体距离当成零;G = 6.67×10⁻¹¹ N·m²/kg² 由卡文迪什扭秤实验测出而不是理论推导。开普勒第三定律 a³/T² = k 中的 k 只由中心天体决定,与行星质量无关;牛顿力学只在宏观、低速、弱引力情形成立',
      ['F = GMm/r²', 'a³/T² = k'], KnowledgeLevel.APPLY, ['kn-phy-sr-013']));
    out.push(k('kn-phy-sr-021', KnowledgePhysicsSenior.REQUIRED_TWO, '万有引力与宇宙航行', '环绕速度与同步卫星',
      '由 GMm/r² = mv²/r 得 v = √(GM/r)、T = 2π√(r³/GM),轨道半径越大线速度越小、周期越大,所以第一宇宙速度 7.9 km/s 既是最大的环绕速度又是最小的发射速度。地球同步卫星的周期、高度和轨道平面(必须位于赤道正上方)都是唯一确定的,不可能定点在北京上空',
      ['v = √(GM/r)', 'T ∝ √(r³)'], KnowledgeLevel.APPLY, ['kn-phy-sr-018', 'kn-phy-sr-020']));
    out.push(k('kn-phy-sr-022', KnowledgePhysicsSenior.REQUIRED_TWO, '机械能守恒定律', '功与功率;摩擦力做功与路径有关',
      '恒力功 W = Fl cosα,α 是力与位移的夹角,功是标量而正负由夹角决定,所以摩擦力既可做负功也可做正功。重力与弹力做功与路径无关,而摩擦力做功与路径有关:一对滑动摩擦力的总功为负,大小等于 μN 乘以相对路程,故摩擦生热 Q = f·s_相对而不是 f·s_位移。功率 P = Fv 说明功率一定时牵引力与速度成反比',
      ['W = Flcosα', 'Q = f·s_相对'], KnowledgeLevel.APPLY, ['kn-phy-sr-008']));
    out.push(k('kn-phy-sr-023', KnowledgePhysicsSenior.REQUIRED_TWO, '机械能守恒定律', '动能定理',
      '合外力做的总功等于动能的变化 W_合 = ½mv₂² − ½mv₁²,它是标量式,不涉及方向与过程细节,因此变力做功、曲线运动都能用;求总功可先算各力功的代数和,也可先求合力再算功,两种算法结果相同',
      ['W_合 = ΔE_k'], KnowledgeLevel.APPLY, ['kn-phy-sr-022']));
    out.push(k('kn-phy-sr-024', KnowledgePhysicsSenior.REQUIRED_TWO, '机械能守恒定律', '机械能守恒的条件与摩擦生热',
      '只有重力或系统内弹力做功时 E_k + E_p 守恒,判据是「其他力不做功或做功之和为零」而不是「物体不受其他力」——支持力常不做功。有摩擦时机械能减少量等于产生的内能,即 Q = μN·s_相对,所以沿斜面上滑再滑回出发点的速率必小于初速率,即使回到同一高度',
      ['½mv² + mgh = 常量', 'ΔE = −Q'], KnowledgeLevel.TRANSFER, ['kn-phy-sr-023', 'kn-phy-sr-010']));
    return out;
  }

  /** 必修三:静电场与电路 */
  static electricFieldAndCircuit(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-phy-sr-025', KnowledgePhysicsSenior.REQUIRED_THREE, '静电场', '电荷守恒与库仑定律',
      '摩擦起电和静电感应都不创造电荷,只是电荷的转移,系统总电荷量守恒;元电荷 e = 1.6×10⁻¹⁹ C 是电荷量的最小单元,任何带电体的电荷量都是它的整数倍。真空中两个静止点电荷之间的作用力 F = kq₁q₂/r² 沿连线方向,库仑定律只适用于点电荷,带电体尺寸不可忽略时不能直接代公式',
      ['F = kq₁q₂/r²', 'e = 1.6×10⁻¹⁹ C'], KnowledgeLevel.APPLY, []));
    out.push(k('kn-phy-sr-026', KnowledgePhysicsSenior.REQUIRED_THREE, '静电场', '电场强度与电场线',
      'E = F/q 用比值定义法描述电场本身,与试探电荷的电量无关,方向规定为正电荷受力的方向;点电荷场强 E = kQ/r²,多个电荷的场强按矢量叠加而非代数相加。电场线不相交、不闭合、疏密表示强弱,它是形象化的描述工具,一般不是电荷的运动轨迹',
      ['E = F/q', 'E = kQ/r²'], KnowledgeLevel.APPLY, ['kn-phy-sr-025']));
    out.push(k('kn-phy-sr-027', KnowledgePhysicsSenior.REQUIRED_THREE, '静电场', '静电力做功、电势能与电势',
      '静电力做功与路径无关,只由初末位置的电势差决定 W = qU,故静电场是保守场;电势能的正负与电荷正负有关,负电荷在电势越低处电势能反而越大。沿电场线方向电势降低,但场强大的地方电势不一定高,等势面上移动电荷静电力不做功;匀强电场中才有 U = Ed,d 必须沿电场方向取',
      ['W_ab = qU_ab', 'E = U/d'], KnowledgeLevel.APPLY, ['kn-phy-sr-026']));
    out.push(k('kn-phy-sr-028', KnowledgePhysicsSenior.REQUIRED_THREE, '静电场', '电容与平行板电容器的动态分析',
      'C = Q/U 是比值定义,C 与 Q、U 无关,而由平行板几何与介质决定 C = ε_r S/(4πkd)。分析动态问题第一步是分清保持不变的量:始终接电源则 U 不变,充电后断开电源则 Q 不变;Q 不变时增大板间距,场强 E = 4πkQ/(ε_r S) 与 d 无关因而保持不变,这一点与直觉相反',
      ['C = Q/U', 'C ∝ ε_r S/d'], KnowledgeLevel.APPLY, ['kn-phy-sr-026']));
    out.push(k('kn-phy-sr-029', KnowledgePhysicsSenior.REQUIRED_THREE, '静电场', '带电粒子在电场中的加速与偏转',
      '加速问题用动能定理 qU = ½mv²,末速度与极板间距无关;垂直射入匀强电场则做类平抛,偏转量 y = qUL²/(2mdv₀²),速度偏转角正切是位移偏转角正切的两倍。若粒子先经加速电压 U₁ 再进入偏转电压 U₂ 的极板,则 y = U₂L²/(4U₁d) 与粒子的质量、电荷量都无关,同位素离子轨迹重合',
      ['qU = ½mv²', '类平抛'], KnowledgeLevel.TRANSFER, ['kn-phy-sr-017', 'kn-phy-sr-027']));
    out.push(k('kn-phy-sr-030', KnowledgePhysicsSenior.REQUIRED_THREE, '电路与电能', '电阻定律与串并联电路',
      'R = ρL/S 由导体的材料、长度和横截面积决定,与所加电压、通过的电流无关,R = U/I 只是电阻的量度式;金属电阻率随温度升高而增大。串联电路电流相同、电压按电阻正比分配,并联电路电压相同、电流按电阻反比分配,并联总电阻小于任一支路电阻且增加支路只会使总电阻更小',
      ['R = ρL/S', '并联 1/R = Σ1/R_i'], KnowledgeLevel.APPLY, []));
    out.push(k('kn-phy-sr-031', KnowledgePhysicsSenior.REQUIRED_THREE, '电路与电能', '电动势不等于路端电压',
      '电动势 E 表征电源把其他形式的能转化为电能的本领,由电源本身决定;闭合电路欧姆定律 I = E/(R + r),路端电压 U = E − Ir 随外电阻增大而增大,只有断路时二者才相等。电源输出功率在 R = r 时取最大值 E²/(4r),而效率 η = R/(R + r) 随 R 增大单调升高,两者不可混为一谈',
      ['E = U_外 + U_内', 'I = E/(R+r)'], KnowledgeLevel.APPLY, ['kn-phy-sr-030']));
    out.push(k('kn-phy-sr-032', KnowledgePhysicsSenior.REQUIRED_THREE, '电路与电能', '焦耳定律与非纯电阻电路',
      '电功 W = UIt 与电流产生的热量 Q = I²Rt 只在纯电阻电路中相等;电动机、蓄电池充电等非纯电阻电路里 UIt = E_机械 + I²Rt,此时用 W = U²t/R 会算出偏大的错误结果,且 I ≠ U/R。焦耳定律对任何情形下电流产生的热都成立',
      ['Q = I²Rt', 'W = UIt'], KnowledgeLevel.APPLY, ['kn-phy-sr-031']));
    return out;
  }

  /** 选择性必修一:动量、机械振动与机械波、光 */
  static momentumAndVibration(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-phy-sr-033', KnowledgePhysicsSenior.ELECTIVE_ONE, '动量守恒定律', '冲量与动量定理',
      '力对时间的累积 I = Ft 叫冲量,是矢量,方向与力的方向相同;物体动量的变化等于合外力的冲量 Ft = mv′ − mv。由它可知动量变化一定时作用时间越长平均作用力越小,这是缓冲垫、安全气囊的原理,而不是因为冲量变小了',
      ['I = Ft = Δp'], KnowledgeLevel.APPLY, ['kn-phy-sr-012']));
    out.push(k('kn-phy-sr-034', KnowledgePhysicsSenior.ELECTIVE_ONE, '动量守恒定律', '动量守恒的判断条件与矢量性',
      '系统不受外力或所受合外力为零时总动量守恒;碰撞、爆炸这类内力远大于外力的短暂过程可近似用动量守恒,某方向合外力为零则该方向动量单独守恒。动量守恒是矢量式,列方程前必须规定正方向,解出负值即表示与正方向相反;它比机械能守恒适用更广,能量不守恒时动量仍可守恒',
      ['Σp = 常量', '先定正方向'], KnowledgeLevel.APPLY, ['kn-phy-sr-033', 'kn-phy-sr-013']));
    out.push(k('kn-phy-sr-035', KnowledgePhysicsSenior.ELECTIVE_ONE, '动量守恒定律', '弹性碰撞与完全非弹性碰撞',
      '碰撞过程动量守恒而动能不一定守恒:弹性碰撞动能也守恒,两球质量相等时交换速度;完全非弹性碰撞(碰后共速)动能损失最大,但动量依然守恒。检验解是否合理还要看碰后两物体不相互穿透、后面物体的速度不大于前面物体,且总动能不会凭空增大',
      ['m₁v₁ + m₂v₂ = (m₁+m₂)v_共'], KnowledgeLevel.TRANSFER, ['kn-phy-sr-034', 'kn-phy-sr-023']));
    out.push(k('kn-phy-sr-036', KnowledgePhysicsSenior.ELECTIVE_ONE, '机械振动', '简谐运动的判据 F = −kx',
      '只有当回复力大小与偏离平衡位置的位移成正比、方向总指向平衡位置(F = −kx,等价于 a = −(k/m)x)时,物体的运动才是简谐运动;单摆只在摆角很小时近似满足。位移、回复力与加速度三者始终同号变化,最大位移处速度为零而加速度最大,平衡位置处速度最大而加速度为零、回复力为零',
      ['F = −kx', 'a = −(k/m)x'], KnowledgeLevel.APPLY, ['kn-phy-sr-012']));
    out.push(k('kn-phy-sr-037', KnowledgePhysicsSenior.ELECTIVE_ONE, '机械振动', '弹簧振子的周期与振幅无关',
      '弹簧振子的周期 T = 2π√(m/k) 只由振子质量与弹簧劲度系数决定,与振幅、初相位和弹簧的朝向都无关;把它带到月球上或水平、竖直放置,周期不变。单摆的周期 T = 2π√(L/g) 只与摆长和当地重力加速度有关,与摆球质量和振幅无关,但只在摆角小于约 5° 时才成立',
      ['T = 2π√(m/k)', 'T = 2π√(L/g)'], KnowledgeLevel.APPLY, ['kn-phy-sr-036']));
    out.push(k('kn-phy-sr-038', KnowledgePhysicsSenior.ELECTIVE_ONE, '机械振动', '振动的能量、阻尼与共振',
      '简谐运动中动能与势能不断相互转化、总机械能守恒,且 E = ½kA² 正比于振幅的平方。有阻尼时振幅按指数衰减,而振动频率仍近似等于系统的固有频率,故弱阻尼下周期几乎不随阻尼改变,阻尼很大时周期明显变大;驱动力频率等于固有频率时振幅出现峰值即共振,与驱动力的大小无关',
      ['E = ½kA²', 'f_驱动 = f_固有 时共振'], KnowledgeLevel.APPLY, ['kn-phy-sr-037']));
    out.push(k('kn-phy-sr-039', KnowledgePhysicsSenior.ELECTIVE_ONE, '机械波', '波速、波长与频率的决定因素',
      '机械波的频率由波源决定、波速由介质的性质决定、波长则由两者共同决定(v = λf);波从一种介质进入另一种介质时频率不变而波速和波长都变。介质中的质点只在各自平衡位置附近振动、不随波迁移,后一质点总落后于前一质点,波传播的是振动形式与能量而非物质',
      ['v = λf', '质点不随波迁移'], KnowledgeLevel.APPLY, ['kn-phy-sr-036']));
    out.push(k('kn-phy-sr-040', KnowledgePhysicsSenior.ELECTIVE_ONE, '机械波', '波的干涉、衍射与多普勒效应',
      '两列波产生稳定干涉的条件是频率相同、相位差恒定且振动方向一致,波程差为波长整数倍处振动加强、半整数倍处减弱,加强处的位移并非永远最大而是振幅最大。一切波都能发生衍射,只有障碍物或孔的尺寸跟波长相差不多或更小时衍射才明显;波源与观察者相互靠近时接收到的频率升高,而波源自身频率不变',
      ['Δr = kλ 加强', 'Δr = (2k+1)λ/2 减弱'], KnowledgeLevel.APPLY, ['kn-phy-sr-039']));
    out.push(k('kn-phy-sr-041', KnowledgePhysicsSenior.ELECTIVE_ONE, '光', '折射率、全反射与光的波动性',
      '折射率 n = c/v = sini/sinr,由介质与光的频率共同决定,同一种介质对频率高的光折射率大。光从光密介质射向光疏介质且入射角大于临界角(sinC = 1/n)时发生全反射,这是光纤与全反射棱镜的原理。双缝干涉相邻亮条纹间距 Δx = lλ/d;干涉、衍射、偏振都说明光有波动性,而偏振现象进一步说明光是横波',
      ['n = c/v', 'sinC = 1/n', 'Δx = lλ/d'], KnowledgeLevel.APPLY, ['kn-phy-sr-039']));
    return out;
  }

  /** 选择性必修二:磁场、电磁感应与交变电流 */
  static electromagnetismSenior(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-phy-sr-042', KnowledgePhysicsSenior.ELECTIVE_TWO, '磁场', '磁感应强度、磁通量与安培力',
      'B = F/(IL) 只在通电导线与磁场垂直时成立,是用比值定义法描述磁场强弱与方向的量;磁通量 Φ = BS 是标量但有正负,线圈平面与磁场平行时 Φ = 0 而 B 不为零。通电导线受到的安培力 F = BIL 同样要求导线与 B 垂直,方向由左手定则判定且垂直于 B 与 I 所决定的平面',
      ['B = F/(IL)', 'Φ = BS', 'F = BIL'], KnowledgeLevel.APPLY, []));
    out.push(k('kn-phy-sr-043', KnowledgePhysicsSenior.ELECTIVE_TWO, '磁场', '洛伦兹力不做功与带电粒子的圆周运动',
      '运动电荷在磁场中受洛伦兹力 F = qvB,方向总与速度垂直,因此它只改变速度方向、不做功、不改变动能,这与安培力可以对导线做功并不矛盾。垂直射入匀强磁场的带电粒子做匀速圆周,r = mv/(qB)、T = 2πm/(qB),周期与速率和半径无关,这是质谱仪与回旋加速器能按比荷区分粒子的前提',
      ['F = qvB', 'r = mv/(qB)', 'T = 2πm/(qB)'], KnowledgeLevel.APPLY, ['kn-phy-sr-018', 'kn-phy-sr-042']));
    out.push(k('kn-phy-sr-044', KnowledgePhysicsSenior.ELECTIVE_TWO, '电磁感应', '楞次定律与感应电流的方向',
      '感应电流的磁场总是阻碍引起它的磁通量变化,而不是阻碍原磁通量本身:磁通增大时感应磁场与原场反向,减小时同向(增反减同);相对运动表现为来拒去留。若感应电流帮助磁通变化,系统就能凭空产生能量,所以楞次定律是能量守恒在电磁感应中的体现',
      ['增反减同', '来拒去留'], KnowledgeLevel.APPLY, ['kn-phy-sr-042']));
    out.push(k('kn-phy-sr-045', KnowledgePhysicsSenior.ELECTIVE_TWO, '电磁感应', '法拉第电磁感应定律与动生电动势',
      '感应电动势的大小由磁通量的变化率决定 E = nΔΦ/Δt:磁通量大、磁通变化量大都不代表电动势大,关键在变化快慢,Φ = 0 的瞬间电动势可以最大。导体棒垂直切割磁感线时 E = BLv 是它的特例,此时棒相当于有内阻的电源,速度越大感应电流与安培力越大,最终合力为零而达到收尾速度',
      ['E = nΔΦ/Δt', 'E = BLv'], KnowledgeLevel.TRANSFER, ['kn-phy-sr-044', 'kn-phy-sr-031']));
    out.push(k('kn-phy-sr-046', KnowledgePhysicsSenior.ELECTIVE_TWO, '交变电流', '有效值、变压器与远距离输电',
      '正弦交变电流的有效值等于峰值的 1/√2,它是按热效应等效定义的量,计算电功、电功率、保险丝熔断和交流电表读数都必须用有效值而不是峰值。理想变压器满足 U₁/U₂ = n₁/n₂、I₁/I₂ = n₂/n₁ 且不改变频率;输送功率一定时升高电压可减小线路电流,使损耗 P_损 = I²R 大幅下降',
      ['I_有 = I_m/√2', 'U₁/U₂ = n₁/n₂'], KnowledgeLevel.APPLY, ['kn-phy-sr-031', 'kn-phy-sr-045']));
    out.push(k('kn-phy-sr-047', KnowledgePhysicsSenior.ELECTIVE_TWO, '电磁波', '电磁振荡与电磁波谱',
      'LC 振荡回路中电场能与磁场能周期性转化,T = 2π√(LC);变化的电场与变化的磁场互相激发并由近及远传播成电磁波,它在真空中速度等于光速且不需要介质,这是麦克斯韦的预言、由赫兹用实验证实。按频率增大依次是无线电波、红外线、可见光、紫外线、X 射线与 γ 射线,一切电磁波在真空中速度相同',
      ['c = 3×10⁸ m/s', 'T = 2π√(LC)'], KnowledgeLevel.RECALL, ['kn-phy-sr-045']));
    return out;
  }

  /** 选择性必修三:热学与原子物理 */
  static thermalAndAtomic(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-phy-sr-048', KnowledgePhysicsSenior.ELECTIVE_THREE, '分子动理论', '扩散、布朗运动与分子间作用力',
      '扩散和布朗运动都证明分子在做无规则运动,但布朗运动的对象是悬浮的固体微粒、反映的是液体分子撞击的不平衡性,不是分子本身的运动,温度越高越明显。分子间同时存在引力和斥力且都随距离增大而减小,斥力变化更快;r = r₀ 时合力为零,小于 r₀ 表现为斥力、大于 r₀ 表现为引力',
      ['r₀ ≈ 10⁻¹⁰ m', '温度越高越剧烈'], KnowledgeLevel.RECALL, []));
    out.push(k('kn-phy-sr-049', KnowledgePhysicsSenior.ELECTIVE_THREE, '气体固体和液体', '气体实验定律与压强的微观解释',
      '一定质量的理想气体满足 pV/T = 常量,分析状态变化要先明确哪一个量不变,不能只看温度就断言压强增大:温度升高的同时体积增大,压强可能不变甚至减小。从微观上看,气体压强由分子数密度和分子平均动能共同决定,单个分子撞击器壁的力是间断的,压强是大量分子的统计平均效果',
      ['pV/T = 常量'], KnowledgeLevel.APPLY, ['kn-phy-sr-048']));
    out.push(k('kn-phy-sr-050', KnowledgePhysicsSenior.ELECTIVE_THREE, '热力学定律', '热力学第一定律的符号规定',
      '物体内能的改变等于外界对它做的功与它吸收的热量之和 ΔU = W + Q,做功与热传递改变内能是等效的但本质不同。气体膨胀时对外做功 W 取负、绝热过程 Q = 0,故绝热膨胀内能必减少、温度下降;内能是状态量,而功和热量是过程量,不能说物体「含有多少热量」',
      ['ΔU = W + Q'], KnowledgeLevel.APPLY, ['kn-phy-sr-049']));
    out.push(k('kn-phy-sr-051', KnowledgePhysicsSenior.ELECTIVE_THREE, '热力学定律', '热力学第二定律与能量守恒的方向性',
      '能量守恒只约束数量而不管方向,热力学第二定律给出方向性:热量不能自发地从低温物体传到高温物体,也不可能从单一热库吸收热量并全部用来做功而不产生其他影响。所以能量虽然守恒、可利用的能量却在减少,摩擦耗散的内能无法自动重新收集,第二类永动机不可能制成',
      ['方向性', '能量耗散'], KnowledgeLevel.RECALL, ['kn-phy-sr-050']));
    out.push(k('kn-phy-sr-052', KnowledgePhysicsSenior.ELECTIVE_THREE, '原子结构', '光电效应与氢原子能级跃迁',
      '光电效应存在截止频率,低于它再强的光也打不出光电子;光电子的最大初动能只随入射频率线性增大 E_k = hν − W₀,与光强无关,而光强只决定单位时间逸出的光电子数 —— 这说明光的能量按一份 hν 交付。原子能级是量子化的,跃迁时吸收或辐射的光子能量等于能级差 hν = E₂ − E₁,一群处于 n 能级的氢原子最多辐射 n(n−1)/2 种频率的光',
      ['E_k = hν − W₀', 'hν = ΔE', 'E₁ = −13.6 eV'], KnowledgeLevel.APPLY, []));
    out.push(k('kn-phy-sr-053', KnowledgePhysicsSenior.ELECTIVE_THREE, '原子核', '衰变、半衰期与结合能',
      'α 衰变使质量数减少 4、电荷数减少 2,β 衰变是核内中子转变为质子、电荷数加一而质量数不变,衰变过程中质量数与电荷数都守恒。半衰期是大量原子核的统计规律,对少数几个核没有意义,也不受温度、压强和化学状态的影响。核子结合成核时有质量亏损并放出能量 ΔE = Δmc²,比结合能越大原子核越稳定,重核裂变与轻核聚变都因产物比结合能增大而释放能量',
      ['N = N₀(1/2)^(t/T)', 'ΔE = Δmc²'], KnowledgeLevel.APPLY, ['kn-phy-sr-052']));
    return out;
  }

  static all(): KnowledgePoint[] {
    return KnowledgePhysicsSenior.kinematicsAndDynamics().concat(KnowledgePhysicsSenior.curvilinearAndEnergy())
      .concat(KnowledgePhysicsSenior.electricFieldAndCircuit())
      .concat(KnowledgePhysicsSenior.momentumAndVibration())
      .concat(KnowledgePhysicsSenior.electromagnetismSenior())
      .concat(KnowledgePhysicsSenior.thermalAndAtomic());
  }
}
