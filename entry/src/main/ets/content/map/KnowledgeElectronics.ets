import { KnowledgePoint, KnowledgeLevel, makeKnowledge } from './KnowledgeTypes';
import { MapSubject, SchoolStage, UNVERIFIED_PREFIX } from './CurriculumTypes';

/**
 * 电工与电子学知识点(电工技术 + 模拟电子技术 + 数字电子技术)。
 *
 * 与 KnowledgePhysics 同一套标准。`source` 只为覆盖面与顺序作证:按通用教材体系
 * (秦曾煌《电工学》、童诗白《模拟电子技术基础》、阎石《数字电子技术基础》的常见编排)
 * 整理,未逐章核对目录,故第一轮全部 `未核实:`。
 */
const ELE: MapSubject = MapSubject.ELECTRONICS;
const U: SchoolStage = SchoolStage.UNIVERSITY;
const COVERAGE: string = UNVERIFIED_PREFIX + '按通用教材体系整理覆盖面与顺序,未逐章核对目录';

function e(id: string, course: string, chapter: string, title: string, statement: string,
  symbols: string[], level: KnowledgeLevel, prereq: string[]): KnowledgePoint {
  return makeKnowledge(id, ELE, U, course, chapter, title, statement, symbols,
    level, prereq, COVERAGE);
}

export class KnowledgeElectronics {
  static readonly CIRCUITS: string = '电工技术·电路分析';
  static readonly ANALOG: string = '模拟电子技术';
  static readonly DIGITAL: string = '数字电子技术';

  static circuits(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(e('kn-ele-u-001', KnowledgeElectronics.CIRCUITS, '电路基本概念',
      '参考方向与实际方向',
      '电流与电压的参考方向可任意选定,列方程前先标;算出正值即与参考方向一致,负值即相反。关联参考方向下 P = UI 表示元件吸收功率,非关联时它发出功率',
      ['关联方向'], KnowledgeLevel.RECALL, []));
    out.push(e('kn-ele-u-002', KnowledgeElectronics.CIRCUITS, '电路基本概念',
      '欧姆定律与电阻的串并联等效',
      '线性电阻 U = IR;串联同流、总阻相加、电压按阻值分配,并联同压、总阻倒数相加、电流按电导分配。电源等效变换(电压源串阻 ↔ 电流源并阻)保持外特性不变',
      ['U = IR'], KnowledgeLevel.APPLY, ['kn-ele-u-001']));
    out.push(e('kn-ele-u-003', KnowledgeElectronics.CIRCUITS, '基本定律',
      '基尔霍夫电流定律与电压定律',
      '任一节点上电流代数和为零(电荷守恒),任一回路上电压代数和为零(能量守恒)。它们是拓扑约束,与元件性质无关,因而对非线性、时变电路同样成立',
      ['ΣI = 0', 'ΣU = 0'], KnowledgeLevel.APPLY, ['kn-ele-u-002']));
    out.push(e('kn-ele-u-004', KnowledgeElectronics.CIRCUITS, '基本定律',
      '支路电流法与节点电压法的选择',
      '支路法未知量多;节点电压法以节点电位为未知量,方程数 = 节点数 − 1,对节点少、支路多的电路更省。含受控源时先把控制量用节点电压表示再列方程',
      [], KnowledgeLevel.TRANSFER, ['kn-ele-u-003']));
    out.push(e('kn-ele-u-005', KnowledgeElectronics.CIRCUITS, '电路定理',
      '叠加定理及其适用边界',
      '线性电路中多个独立源共同作用等于各源单独作用的代数和(其余电压源短路、电流源开路)。它只适用于线性量(电压电流),不能直接用于功率,因为功率与激励是二次关系',
      [], KnowledgeLevel.TRANSFER, ['kn-ele-u-004']));
    out.push(e('kn-ele-u-006', KnowledgeElectronics.CIRCUITS, '电路定理',
      '戴维南与诺顿等效',
      '任一线性有源二端网络对外可等效为电压源串电阻(Uoc 与 Req)或电流源并电阻(Isc 与 Req),三者满足 Uoc = Isc·Req。求 Req 时把独立源置零,含受控源则用外加电源法',
      ['Uoc', 'Req'], KnowledgeLevel.TRANSFER, ['kn-ele-u-005']));
    out.push(e('kn-ele-u-007', KnowledgeElectronics.CIRCUITS, '电路定理',
      '最大功率传输条件',
      '负载电阻等于网络等效内阻时获得最大功率 P_max = Uoc²/(4Req),但此时效率只有 50%;电力传输追求效率故不满足此条件,信号与功率放大级则常按匹配设计',
      ['R_L = Req'], KnowledgeLevel.APPLY, ['kn-ele-u-006']));
    out.push(e('kn-ele-u-008', KnowledgeElectronics.CIRCUITS, '正弦稳态',
      '相量法:把微分方程变成代数方程',
      '同频率正弦量可用复数相量表示(有效值与初相),电感电压超前电流 90°(Z = jωL)、电容电流超前电压 90°(Z = 1/jωC),于是稳态分析化为复数阻抗运算',
      ['U̇', 'Z = R + jX'], KnowledgeLevel.APPLY, ['kn-ele-u-003']));
    out.push(e('kn-ele-u-009', KnowledgeElectronics.CIRCUITS, '正弦稳态',
      '串联谐振与并联谐振的特征',
      'RLC 串联在 ω₀ = 1/√(LC) 时电抗抵消、阻抗最小、电流最大且与源同相,电感电压可达源的 Q 倍;并联谐振则阻抗最大、总电流最小。品质因数 Q = ω₀L/R 决定选择性锐度',
      ['ω₀ = 1/√(LC)', 'Q'], KnowledgeLevel.TRANSFER, ['kn-ele-u-008']));
    out.push(e('kn-ele-u-010', KnowledgeElectronics.CIRCUITS, '正弦稳态',
      '有功、无功、视在功率与功率因数',
      'P = UI cosφ 是真做功的部分,Q = UI sinφ 是能量往返的幅度,S = UI 为视在;感性负载 cosφ 偏低会使线路电流增大、损耗上升,常并联电容补偿而不改变负载本身',
      ['cosφ', 'S² = P² + Q²'], KnowledgeLevel.APPLY, ['kn-ele-u-008']));
    out.push(e('kn-ele-u-011', KnowledgeElectronics.CIRCUITS, '三相电路',
      '星形与三角形的线量关系',
      '星形接法线电压 = √3 相电压且超前 30°、线电流等于相电流;三角形接法线电流 = √3 相电流、线电压等于相电压。三相总功率 P = √3 U_L I_L cosφ',
      ['√3 倍'], KnowledgeLevel.APPLY, ['kn-ele-u-010']));
    out.push(e('kn-ele-u-012', KnowledgeElectronics.CIRCUITS, '一阶暂态',
      '换路定时间与三要素法',
      '电容电压与电感电流在换路瞬间不能跃变(储能连续),故初始值由换路前状态决定;一阶响应由初始值、稳态值与时间常数 τ(= RC 或 L/R)三要素完全确定',
      ['τ = RC', 'f(∞)', 'f(0+)'], KnowledgeLevel.TRANSFER, ['kn-ele-u-006', 'kn-ele-u-008']));
    return out;
  }

  static analog(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(e('kn-ele-u-021', KnowledgeElectronics.ANALOG, '半导体器件',
      'PN 结的单向导电性与伏安方程',
      'P 与 N 接触形成耗尽层与内建电场;正偏削弱内建电场、扩散电流占优而导通,反偏加宽耗尽层、只有很小的漂移电流,击穿分齐纳与雪崩两种机理',
      ['i = I_S(e^(u/U_T) − 1)', 'U_T ≈ 26 mV'], KnowledgeLevel.APPLY, []));
    out.push(e('kn-ele-u-022', KnowledgeElectronics.ANALOG, '半导体器件',
      '二极管的三种典型应用电路',
      '整流利用单向导电把交流变脉动直流;限幅把输出钳在参考电压附近;稳压管工作在反向击穿区,靠动态电阻小来稳定电压 —— 同一器件的不同工作区',
      [], KnowledgeLevel.TRANSFER, ['kn-ele-u-021']));
    out.push(e('kn-ele-u-023', KnowledgeElectronics.ANALOG, '三极管与放大',
      'BJT 的三种组态与放大条件',
      '发射结正偏、集电结反偏才有放大作用;i_C = βi_B 且 i_E = i_B + i_C;共射既放电流又放电压且反相,共集(射极跟随器)只放电流、输入电阻高输出电阻低,共基只放电压、高频特性好',
      ['i_C = β i_B'], KnowledgeLevel.APPLY, ['kn-ele-u-021']));
    out.push(e('kn-ele-u-024', KnowledgeElectronics.ANALOG, '三极管与放大',
      '静态工作点为什么必须设、设错会怎样',
      'Q 点决定动态范围:偏高进入饱和区产生饱和失真,偏低进入截止区产生截止失真;温度升高使 I_CBO 与 β 增大、U_BE 减小而把 Q 点上移,故需偏置电路稳定',
      ['Q 点', '直流负载线'], KnowledgeLevel.TRANSFER, ['kn-ele-u-023']));
    out.push(e('kn-ele-u-025', KnowledgeElectronics.ANALOG, '三极管与放大',
      '微变等效电路只用于交流小信号',
      '在 Q 点附近把非线性器件线性化(B-E 间为 r_be、受控源 βi_b),据此算电压放大倍数与输入输出电阻;它不含直流信息,必须先做完静态分析',
      ['r_be', 'A_u = −βR_L′/r_be'], KnowledgeLevel.TRANSFER, ['kn-ele-u-024']));
    out.push(e('kn-ele-u-026', KnowledgeElectronics.ANALOG, '集成运放',
      '理想运放的两条分析规则',
      '开环增益无穷大且工作在线性区(有负反馈)时,两输入端电位近似相等(虚短)、流入输入端的电流近似为零(虚断)。这是深度负反馈的结果而非器件本性,输出饱和后即失效',
      ['虚短', '虚断'], KnowledgeLevel.APPLY, ['kn-ele-u-025']));
    out.push(e('kn-ele-u-027', KnowledgeElectronics.ANALOG, '集成运放',
      '负反馈的四种组态与四种影响',
      '按输出取样分电压/电流、按输入比较分串联/并联;负反馈以牺牲增益换取增益稳定、频带展宽、非线性失真减小,并按组态改变输入与输出电阻',
      ['A_f = A/(1+AF)'], KnowledgeLevel.TRANSFER, ['kn-ele-u-026']));
    out.push(e('kn-ele-u-028', KnowledgeElectronics.ANALOG, '集成运放应用',
      '比例、加法、积分与微分电路',
      '反相比例 A_u = −R_f/R_1、同相 A_u = 1 + R_f/R_1;虚地使反相端成为求和点故可构成加法;反馈元件换成电容得积分,放到输入端则得微分(易放大噪声,实际少用)',
      [], KnowledgeLevel.APPLY, ['kn-ele-u-026']));
    out.push(e('kn-ele-u-029', KnowledgeElectronics.ANALOG, '信号产生与电源',
      '正弦波振荡的相位与幅度条件',
      '环路需满足相位平衡(正反馈,相移为 2π 整数倍)与 |AF| ≥ 1 才能起振,再由非线性或自动增益控制把 |AF| 拉回 1 以稳幅;RC 桥式用于低频、LC 与石英晶体用于高频',
      ['AF = 1'], KnowledgeLevel.TRANSFER, ['kn-ele-u-027']));
    out.push(e('kn-ele-u-030', KnowledgeElectronics.ANALOG, '信号产生与电源',
      '直流稳压电源四环节与纹波',
      '变压器降压、整流(半波/全波/桥式)变脉动、滤波(电容滤波 U_o ≈ 1.2U_2)平滑、稳压环节消除电网与负载变化;纹波系数与稳压系数是两项核心指标',
      ['U_o ≈ 1.2U_2'], KnowledgeLevel.APPLY, ['kn-ele-u-022']));
    return out;
  }

  static digital(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(e('kn-ele-u-041', KnowledgeElectronics.DIGITAL, '逻辑代数',
      '二进制、补码与 BCD 编码',
      'n 位二进制表示 2ⁿ 个码字;带符号数用补码,使减法化为加法且零的表示唯一(负数取反加一);8421BCD 用四位二进制表示一位十进制,故 1010~1111 为非法码',
      ['补码'], KnowledgeLevel.RECALL, []));
    out.push(e('kn-ele-u-042', KnowledgeElectronics.DIGITAL, '逻辑代数',
      '基本定律与摩根定律',
      '与或非构成完备集;(A·B)′ = A′ + B′ 是把与式转成或式的关键;反演时要互换 0/1、互换与或并保持原变量不变,运算次序不能改',
      ['摩根定律'], KnowledgeLevel.APPLY, ['kn-ele-u-041']));
    out.push(e('kn-ele-u-043', KnowledgeElectronics.DIGITAL, '逻辑代数',
      '最小项、卡诺图与约束项',
      'n 变量最小项恰在一个取值组合为 1;卡诺图按相邻格只变一个变量排列,合并 2^k 个相邻 1 格消去 k 个变量得最简与或式;无关项可圈 1 也可圈 0 以进一步化简',
      ['最小项 m_i', '无关项 ×'], KnowledgeLevel.TRANSFER, ['kn-ele-u-042']));
    out.push(e('kn-ele-u-044', KnowledgeElectronics.DIGITAL, '组合逻辑',
      '组合电路的分析与设计步骤',
      '分析:由图写表达式 → 化简 → 列真值表 → 说功能;设计:定输入输出与逻辑赋值 → 列真值表 → 化简表达式 → 画图。组合电路无记忆,输出只由当前输入决定',
      [], KnowledgeLevel.TRANSFER, ['kn-ele-u-043']));
    out.push(e('kn-ele-u-045', KnowledgeElectronics.DIGITAL, '组合逻辑',
      '编码器、译码器与数据选择器',
      '优先编码器对同时到来的多个输入按优先级输出编码;译码器把 n 位码展开为 2ⁿ 条输出线,带使能端可作最小项发生器;数据选择器是地址控制的多路开关,用它可实现任意单输出逻辑函数',
      ['MUX', '使能端'], KnowledgeLevel.APPLY, ['kn-ele-u-044']));
    out.push(e('kn-ele-u-046', KnowledgeElectronics.DIGITAL, '组合逻辑',
      '加法器与竞争冒险',
      '半加器只求本位与进位,全加器再加进低位;串行进位延迟随位数累积,超前进位用生成 G = AB 与传播 P = A + B 并行求进位。信号经不同路径到达时间不同会在输出产生尖峰,即竞争冒险',
      ['G = AB', 'P = A + B'], KnowledgeLevel.TRANSFER, ['kn-ele-u-045']));
    out.push(e('kn-ele-u-047', KnowledgeElectronics.DIGITAL, '触发器与时序',
      '锁存器与触发器、四种触发方式',
      'SR 锁存器电平敏感且有约束项 SR = 0;主从结构解决空翻;边沿 D 触发器在跳变瞬间采样一次,JK 消除约束并可翻转,T 触发器实现二分频',
      ['D', 'JK', 'T'], KnowledgeLevel.APPLY, ['kn-ele-u-044']));
    out.push(e('kn-ele-u-048', KnowledgeElectronics.DIGITAL, '触发器与时序',
      '时序电路的分析:状态表与状态图',
      '先写驱动方程与时钟方程,代入特性方程得次态方程,再列状态转换表与状态图判断是几进制、能否自启动;同步电路同一时钟,异步电路需逐个检查触发有效沿',
      ['次态方程', '自启动'], KnowledgeLevel.TRANSFER, ['kn-ele-u-047']));
    out.push(e('kn-ele-u-049', KnowledgeElectronics.DIGITAL, '时序电路应用',
      '计数器与寄存器的构成方式',
      '计数器分异步(结构简单、累积延迟大)与同步(各触发器同沿、速度快);用置数或复位反馈可构成任意模 N;寄存器存代码,移位寄存器兼作串并转换与延迟线',
      ['模 N'], KnowledgeLevel.APPLY, ['kn-ele-u-048']));
    out.push(e('kn-ele-u-050', KnowledgeElectronics.DIGITAL, '脉冲与数模转换',
      '555 定时器与 A/D 转换原理',
      '555 由两个比较器、一个 RS 触发器和放电管构成,可接成单稳(脉宽约 1.1RC)、多谐振荡与施密特触发器;A/D 采样须满足奈奎斯特条件,常见为逐次逼近型(快)与双积分型(抗工频干扰、慢)',
      ['f_s ≥ 2f_max'], KnowledgeLevel.APPLY, ['kn-ele-u-049']));
    return out;
  }

  static all(): KnowledgePoint[] {
    return KnowledgeElectronics.circuits().concat(KnowledgeElectronics.analog())
      .concat(KnowledgeElectronics.digital());
  }
}
