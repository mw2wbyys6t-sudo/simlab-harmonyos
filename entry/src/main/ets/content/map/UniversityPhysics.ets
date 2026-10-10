import {
  ExperimentEntry, Feasibility, makeEntry, MapSubject, SchoolStage
} from './CurriculumTypes';

/**
 * 大学物理实验。
 *
 * 项目名与分类来自两份可核查的公开清单:云南大学实验中心的项目表(力学与热学/电磁学/光学/
 * 近代物理等分类)与南京大学物理实验中心「基础物理实验」页。
 *
 * **出处只保证「这个实验确实开课」这一件事**:principle / apparatus / dataHandling 三栏是
 * 编写者按该实验的标准做法概括的,不是从上述页面逐字抄来的。这层区别写在这里,
 * 免得地图看起来比它实际的确切程度更高。排课学期(term)按多数院校的排法给粗位置,
 * 同样不是清单里的信息。
 */
const PHY: MapSubject = MapSubject.PHYSICS;
const U: SchoolStage = SchoolStage.UNIVERSITY;
const YNU: string = '云南大学实验中心·物理实验项目列表 https://lyxywlsn.lyun.edu.cn/zxgk/xmlb.htm';
const NJU: string = '南京大学物理实验中心·基础物理实验 http://phylab.nju.edu.cn/kcsz/jcwlsy/index.html';

function p(id: string, course: string, term: string, title: string, apparatus: string[],
  principle: string, dataHandling: string, knowledge: string[],
  feasibility: Feasibility, source: string): ExperimentEntry {
  return makeEntry(id, PHY, U, course, term, 0, title, apparatus, principle,
    dataHandling, knowledge, feasibility, source);
}

export class UniversityPhysics {
  static readonly MECHANICS: string = '大学物理实验·力学与热学';
  static readonly ELECTROMAGNETISM: string = '大学物理实验·电磁学';
  static readonly OPTICS: string = '大学物理实验·光学';
  static readonly MODERN: string = '大学物理实验·近代物理';

  static mechanics(): ExperimentEntry[] {
    const out: ExperimentEntry[] = [];
    out.push(p('phy-u-001', UniversityPhysics.MECHANICS, '大一上', '固体的长度、体积和密度测量',
      ['游标卡尺', '螺旋测微器', '物理天平', '量筒'],
      '用三种量具分别测规则与不规则固体的尺寸,再由质量除以体积得密度',
      '按量具的仪器误差限算不确定度,与标准值比较并说明偏差来源',
      ['长度测量', '密度', '仪器误差', '有效数字'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-002', UniversityPhysics.MECHANICS, '大一上', '物体密度的测量(流体静力称衡法)',
      ['物理天平', '烧杯', '细线', '待测固体'],
      '称物体在空气中与浸没在水中的质量,由浮力差算体积与密度',
      '给两次称量的误差传递式,讨论水温对水密度取值的影响',
      ['阿基米德原理', '密度', '误差传递'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-003', UniversityPhysics.MECHANICS, '大一上', '精密称衡',
      ['物理天平或分析天平', '标准砝码', '待测物体'],
      '用交换称量法(左右对调再称)消除两臂不等的系统误差',
      '比较直接称量与交换称量的差,说明几何平均值为什么能抵消臂差',
      ['天平', '系统误差', '交换称量'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-004', UniversityPhysics.MECHANICS, '大一上', '单摆的研究',
      ['单摆装置', '米尺', '停表', '光电计时器'],
      '测不同摆长下的周期,验证小角度下周期与摆长的平方根成正比',
      '用作图法或最小二乘拟合 T²-l 直线,由斜率反推重力加速度并给不确定度',
      ['简谐振动', '周期', '线性拟合', '重力加速度'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-005', UniversityPhysics.MECHANICS, '大一上', '测定重力加速度',
      ['自由落体装置', '光电门', '数字计时器'],
      '测物体自由下落的时间与位移,由位移与时间的二次关系求 g',
      '逐差法处理多组数据,比较两种计时方式的差别',
      ['自由落体', '匀加速运动', '逐差法'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-006', UniversityPhysics.MECHANICS, '大一上', '牛顿第二定律的验证',
      ['气垫导轨', '滑块', '光电门', '砝码与细绳'],
      '在近似无摩擦的导轨上用砝码牵引滑块,验证加速度与合外力成正比、与质量成反比',
      '固定质量变拉力、固定拉力变质量,两组数据各拟合一条直线并看截距是否非零',
      ['牛顿第二定律', '气垫导轨', '控制变量', '线性拟合'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-007', UniversityPhysics.MECHANICS, '大一上', '动量守恒定律的验证',
      ['气垫导轨', '两个滑块', '挡光片', '光电计时器'],
      '测碰撞前后两滑块的速度,比较弹性与非弹性碰撞中总动量与总动能的变化',
      '分别算碰撞前后的动量与动能,给相对偏差并说明能量去了哪里',
      ['动量守恒', '碰撞', '能量损失'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-008', UniversityPhysics.MECHANICS, '大一上', '杨氏弹性模量的测量(伸长法)',
      ['杨氏模量仪', '光杠杆', '望远镜与标尺', '砝码', '米尺'],
      '逐增砝码测金属丝的微小伸长,用光杠杆把微小形变放大成标尺读数变化',
      '逐差法求平均伸长并算杨氏模量;分析哪个长度量测得最不准',
      ['弹性形变', '杨氏模量', '光杠杆放大', '逐差法'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-009', UniversityPhysics.MECHANICS, '大一上', '杨氏弹性模量的测量(弯曲法)',
      ['弯曲法模量仪', '待测棒', '百分表或光杠杆', '加载架'],
      '测棒中点在已知载荷下的挠度,由梁的弯曲公式反解杨氏模量',
      '作挠度对载荷的图取斜率,与拉伸法结果比较并解释差别',
      ['弯曲形变', '挠度', '杨氏模量'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-010', UniversityPhysics.MECHANICS, '大一上', '动态杨氏模量的测量',
      ['动态模量仪', '信号发生器', '压电陶瓷换能器', '试样棒'],
      '激励试样棒共振,由基频共振频率与试样尺寸、质量算杨氏模量',
      '与静态法结果比较,说明两种方法测的不是同一件事',
      ['共振', '弯曲振动', '杨氏模量'], Feasibility.NEEDS_MODEL, NJU));
    out.push(p('phy-u-011', UniversityPhysics.MECHANICS, '大一上', '刚体转动惯量的测量',
      ['转动惯量仪', '扭摆', '待测刚体', '光电计时器'],
      '测系统不加与加载物体时的振动周期,由周期差反推待测物体的转动惯量',
      '与平行轴定理算出的理论值比较,讨论支撑杆摩擦造成的偏差方向',
      ['转动惯量', '扭摆', '平行轴定理'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-012', UniversityPhysics.MECHANICS, '大一上', '弦振动的研究',
      ['弦线驻波装置', '电动音叉', '滑轮与砝码', '米尺'],
      '在张紧的弦上激起驻波,数波节测波长,研究波长与张力、线密度的关系',
      '固定频率作波长对张力平方根的关系图,验证弦振动频率公式',
      ['驻波', '波长', '张力', '波速'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-013', UniversityPhysics.MECHANICS, '大一上', '测量弦的特征参量',
      ['弦线', '张力装置', '频率计', '米尺', '天平'],
      '综合测弦的线密度、张力与基频,验证弦的固有频率公式',
      '把三个量的测量不确定度合成,预测频率的不确定度再与实测比较',
      ['驻波', '线密度', '不确定度合成'], Feasibility.NEEDS_MODEL, NJU));
    out.push(p('phy-u-014', UniversityPhysics.MECHANICS, '大一上', '谐振动的研究(弹簧振子)',
      ['弹簧振子', '位移传感器', '数据采集器'],
      '测弹簧振子的位移随时间变化,验证周期与质量、劲度系数的关系',
      '从振动曲线读周期与阻尼衰减,与理论值比较',
      ['简谐振动', '劲度系数', '周期', '阻尼'], Feasibility.RUNNABLE, YNU));
    out.push(p('phy-u-015', UniversityPhysics.MECHANICS, '大一上', '声速测量',
      ['超声声速测定仪', '信号发生器', '示波器', '温度计'],
      '用驻波法与相位法测超声波在空气中的波长,由频率乘波长得声速',
      '把实测声速与含温度修正的理论值比较,反过来由声速算空气的比热比',
      ['声波', '驻波', '相位差', '理想气体'], Feasibility.NEEDS_RENDERER, YNU));
    out.push(p('phy-u-016', UniversityPhysics.MECHANICS, '大一上', '冷却法测金属比热容',
      ['比热容实验仪', '待测金属样品', '量热器', '温度计', '物理天平'],
      '把加热后的金属投入已知质量的水中,由热平衡方程解出金属比热容',
      '作冷却曲线并修正散热损失,与表值比较给百分偏差',
      ['热平衡', '比热容', '散热修正'], Feasibility.NEEDS_MODEL, NJU));
    out.push(p('phy-u-017', UniversityPhysics.MECHANICS, '大一上', '冰的熔解热的测定',
      ['量热器', '冰块', '温度计', '物理天平'],
      '把已知质量的冰投入温水,由水放出的热量算冰熔化吸收的潜热',
      '扣除冰融化后升温吸热与筒壁散热,给不确定度',
      ['潜热', '热平衡', '系统误差修正'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-018', UniversityPhysics.MECHANICS, '大一上', '固体比热的测定',
      ['量热器', '金属颗粒', '温度计', '蒸汽加热器'],
      '加热金属颗粒后投入量热器,由热平衡求固体的比热容',
      '与杜隆-珀蒂定律(摩尔热容约 3R)比较,解释为什么金属符合得好',
      ['比热容', '热平衡', '杜隆-珀蒂定律'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-019', UniversityPhysics.MECHANICS, '大一上', '电热法测量热功当量',
      ['量热器', '电热丝', '电流表与电压表', '停表', '直流电源'],
      '给电热丝通电加热液体,比较电能与热量之比即热功当量',
      '取多组电流与时间,作热量对电功的图,斜率就是结果',
      ['热功当量', '能量守恒', '电功率'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-020', UniversityPhysics.MECHANICS, '大一上', '空气比热容的测定',
      ['比热容测定仪', '压力传感器', '温度传感器'],
      '用绝热膨胀法测空气的比热比,由两次平衡态的压强比算结果',
      '讨论绝热假设在什么条件下不成立,漏气与温度未平衡各造成什么方向的偏差',
      ['绝热过程', '比热比', '理想气体状态方程'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-021', UniversityPhysics.MECHANICS, '大一上', '液体的比汽化热的测量',
      ['汽化热测定仪', '蒸汽发生瓶', '量热器', '温度计', '天平'],
      '把已知质量的干蒸汽通入量热器,由冷凝放热与升温求液体的比汽化热',
      '扣除蒸汽带入的显热,给百分偏差并说明主要损失途径',
      ['汽化热', '热平衡', '相变'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-022', UniversityPhysics.MECHANICS, '大一上', '金属线胀系数的测定',
      ['线胀系数测定仪', '金属杆', '温度计', '千分表或光杠杆'],
      '测金属杆升温前后的长度变化,由相对伸长除以温差算线胀系数',
      '作伸长对温度的图,斜率除以原长即结果;检查是否线性',
      ['热膨胀', '线胀系数', '微小长度测量'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-023', UniversityPhysics.MECHANICS, '大一上', '液体表面张力系数的测定(拉脱法)',
      ['焦利秤或扭秤', '金属吊环', '游标卡尺', '温度计'],
      '测吊环脱离液面时的最大拉力,扣除重力后除以周长得表面张力系数',
      '讨论吊环是否水平、接触角与液体纯净度对结果的影响',
      ['表面张力', '受力分析', '系统误差'], Feasibility.NEEDS_MODEL, NJU));
    out.push(p('phy-u-024', UniversityPhysics.MECHANICS, '大一上', '液体表面张力系数的测定(毛细管法)',
      ['毛细管组', '待测液体', '读数显微镜', '烧杯'],
      '测不同内径毛细管中液面上升高度,由上升高度与管径的反比关系求表面张力',
      '用作图法由斜率求结果,检验接触角近似为零的假设',
      ['毛细现象', '表面张力', '线性拟合'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-025', UniversityPhysics.MECHANICS, '大一上', '液体粘滞系数的测定(落球法)',
      ['长玻璃筒', '待测液体', '小钢球', '停表', '米尺', '螺旋测微器'],
      '测小球在液体中的匀速下落速度,由斯托克斯公式反解粘滞系数',
      '修正筒壁与末端效应(需先判断雷诺数是否足够小),给不确定度',
      ['粘滞系数', '斯托克斯定律', '收尾速度', '雷诺数'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-026', UniversityPhysics.MECHANICS, '大一上', '不良导体的导热系数测量',
      ['稳态法导热系数仪', '橡胶或玻璃样品', '加热盘', '温度计', '物理天平'],
      '建立稳态温度梯度,由传热速率与温度差算不良导体的导热系数',
      '记录散热盘在稳态温度附近的冷却速率并换算散热功率',
      ['热传导', '稳态', '冷却曲线'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-027', UniversityPhysics.MECHANICS, '大一上', '温度传感器的特性测量和标定',
      ['铜电阻或热电偶', '恒温水浴', '标准温度计', '数字电压表'],
      '测传感器输出随温度的变化,拟合出标定曲线与灵敏度',
      '用最小二乘求系数与相关系数,给出标定方程的适用区间',
      ['传感器标定', '线性拟合', '相关系数'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-028', UniversityPhysics.MECHANICS, '大一上', '随机误差的正态分布',
      ['同一物理量的多次独立测量数据', '直方图或统计工具'],
      '把多次独立测量作直方图,与正态分布曲线比较',
      '算平均值、标准偏差与置信区间,检验落在一倍与两倍标准差内的比例',
      ['随机误差', '正态分布', '标准偏差', '置信区间'], Feasibility.NEEDS_MODEL, YNU));
    return out;
  }

  static electromagnetism(): ExperimentEntry[] {
    const out: ExperimentEntry[] = [];
    out.push(p('phy-u-030', UniversityPhysics.ELECTROMAGNETISM, '大一下', '模拟示波器的使用',
      ['示波器', '信号发生器', '待测电压源'],
      '学会用示波器读电压幅值、周期与相位差,并校准扫描因数',
      '用李萨如图形测两信号的频率比,说明图形稳定与频率比为有理数的关系',
      ['示波器', '周期', '相位差', '李萨如图形'], Feasibility.NEEDS_RENDERER, NJU));
    out.push(p('phy-u-031', UniversityPhysics.ELECTROMAGNETISM, '大一下', '万用表的使用',
      ['指针式万用表', '电阻与电源若干'],
      '测电压、电流与电阻,理解各量程档内阻不同带来的负载效应',
      '比较同一电阻在不同量程档的读数,估算表内阻造成的相对误差',
      ['电表内阻', '负载效应', '量程'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-032', UniversityPhysics.ELECTROMAGNETISM, '大一下', '万用电表的组装与校正',
      ['表头', '分流与分压电阻', '标准表', '直流电源'],
      '把一个电流表头改装成多量程电流表与电压表,再与标准表逐点比对',
      '画校正曲线,标出最大引用误差并确定改装表的准确度等级',
      ['电表改装', '分流电阻', '校正曲线', '准确度等级'], Feasibility.NEEDS_MODEL, NJU));
    out.push(p('phy-u-033', UniversityPhysics.ELECTROMAGNETISM, '大一下', '用惠斯通电桥测电阻',
      ['惠斯通电桥', '检流计', '待测电阻', '直流电源'],
      '调平衡使检流计无电流,由桥臂比值算未知电阻',
      '分析灵敏度与桥臂比的选择,给电阻的合成不确定度',
      ['电桥平衡', '灵敏度', '不确定度'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-034', UniversityPhysics.ELECTROMAGNETISM, '大一下', '双臂电桥测量低电阻',
      ['开尔文电桥', '低阻标准与待测电阻', '检流计'],
      '用四端接法消除引线电阻与接触电阻,测毫欧级电阻',
      '比较两端法与四端法的读数差,说明差从哪里来',
      ['四端法', '接触电阻', '低电阻测量'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-035', UniversityPhysics.ELECTROMAGNETISM, '大一下', '用箱式电位差计校正电表',
      ['箱式电位差计', '标准电池', '检流计', '待校电表'],
      '用补偿法测电压(测量时不从被测回路取电流),逐点校正电压表',
      '画校正曲线并给各级误差',
      ['补偿法', '电位差计', '校正曲线'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-036', UniversityPhysics.ELECTROMAGNETISM, '大一下', '伏安特性曲线测量',
      ['直流电源', '电压表与电流表', '滑线变阻器', '线性与非线性元件'],
      '测线性电阻、二极管与小灯泡的电流随电压变化曲线',
      '判断哪些元件满足欧姆定律,从二极管曲线读开启电压,讨论灯丝电阻随温度的变化',
      ['欧姆定律', '非线性元件', '图线斜率'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-037', UniversityPhysics.ELECTROMAGNETISM, '大一下', 'PN 结物理特性测定及弱电流测量',
      ['PN 结温度传感器实验仪', '恒流源', '数字电压表'],
      '测 PN 结正向压降随温度的变化与伏安特性随温度的移动',
      '拟合压降-温度直线求灵敏度,由伏安族拟合出玻尔兹曼常数',
      ['PN 结', '玻尔兹曼常数', '线性拟合'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-038', UniversityPhysics.ELECTROMAGNETISM, '大一下', '二极管伏安特性',
      ['二极管', '微安表与毫安表', '电压表', '滑线变阻器'],
      '分别测正偏与反偏下的小电流,画出完整伏安曲线',
      '用指数拟合求反向饱和电流与理想因子,讨论测反偏时的高阻要求',
      ['PN 结', '指数关系', '反向饱和电流'], Feasibility.NEEDS_MODEL, NJU));
    out.push(p('phy-u-039', UniversityPhysics.ELECTROMAGNETISM, '大一下', '霍尔效应',
      ['霍尔效应实验仪', '电磁铁与励磁电源', '霍尔元件'],
      '测霍尔电压与工作电流、磁感应强度的关系,判断半导体类型并算载流子浓度',
      '用对称测量法(电流与磁场四次换向)消除不等位电势等副效应',
      ['霍尔效应', '载流子浓度', '洛伦兹力', '对称测量'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-040', UniversityPhysics.ELECTROMAGNETISM, '大一下', '磁场的描绘',
      ['霍耳探头或试探线圈', '载流圆线圈', '移动标尺', '测试仪'],
      '沿轴线与径向逐点测磁感应强度,描绘长直导线与圆线圈的磁场分布',
      '与毕奥-萨伐尔定律的理论曲线叠画作图比较,标出亥姆霍兹线圈的均匀区',
      ['毕奥-萨伐尔定律', '磁场叠加', '亥姆霍兹线圈'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-041', UniversityPhysics.ELECTROMAGNETISM, '大一下', '地球磁场水平分量的测量',
      ['亥姆霍兹线圈', '直流电源', '探测线圈或霍尔探头', '支架'],
      '通已知电流产生可控磁场,与地磁场水平分量抵消或比较,求出其大小',
      '给大小与方向,并说明为什么只测得水平分量',
      ['地磁场', '矢量叠加', '磁场补偿'], Feasibility.NEEDS_MODEL, NJU));
    out.push(p('phy-u-042', UniversityPhysics.ELECTROMAGNETISM, '大一下', '磁滞回线的测量',
      ['铁磁样品与磁滞回线实验仪', '示波器', '积分电路'],
      '在示波器上显示 B-H 曲线,观察铁磁材料的磁滞与饱和',
      '读出剩磁与矫顽力,由回线面积估算一周期的损耗',
      ['磁滞回线', '剩磁', '矫顽力', '磁损耗'], Feasibility.NEEDS_RENDERER, YNU));
    out.push(p('phy-u-043', UniversityPhysics.ELECTROMAGNETISM, '大一下', '居里点温度测量',
      ['居里点实验仪', '铁磁样品', '加热线圈', '感应线圈与测试仪'],
      '升温过程中监测感应信号突变,找到铁磁转为顺磁的温度',
      '作信号对温度曲线,取突变中点为居里点并给升降温差(热滞)',
      ['铁磁性', '居里温度', '相变'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-044', UniversityPhysics.ELECTROMAGNETISM, '大一下', '半导体热敏电阻特性的研究',
      ['热敏电阻', '恒温水浴与温度计', '数字欧姆表'],
      '测阻值随温度的变化,验证负温度系数的指数关系',
      '在对数坐标下拟合求材料常数 B 与激活能',
      ['热敏电阻', '指数拟合', '半导体导电'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-045', UniversityPhysics.ELECTROMAGNETISM, '大一下', '非平衡电桥与数字温度计设计',
      ['电桥板', '热敏电阻或铜电阻', '放大器与电压表', '恒温源'],
      '把传感元件接入桥臂,设计桥路使输出电压在测温区间内近似线性',
      '标定输出电压对温度曲线,给出灵敏度、线性区间与最大非线性误差',
      ['非平衡电桥', '传感器线性化', '标定'], Feasibility.NEEDS_MODEL, NJU));
    out.push(p('phy-u-046', UniversityPhysics.ELECTROMAGNETISM, '大一下', '用电流场模拟静电场',
      ['导电纸或水槽', '电极', '稳恒电源', '高阻电压表'],
      '用稳恒电流场模拟难以直接测的静电场分布,逐点描出等势线',
      '画等势线与电力线,检验其与理论图形(同轴、平行)的一致性',
      ['静电场', '模拟法', '等势线'], Feasibility.NEEDS_RENDERER, YNU));
    out.push(p('phy-u-047', UniversityPhysics.ELECTROMAGNETISM, '大一下', 'RLC 串联电路的暂态过程',
      ['方波信号源', '电阻电容电感', '示波器'],
      '观察二阶电路在阶跃激励下的欠阻尼、临界与过阻尼响应',
      '从振荡波形读衰减量算品质因数,与理论值比较',
      ['暂态过程', '二阶电路', '阻尼振荡', '时间常数'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-048', UniversityPhysics.ELECTROMAGNETISM, '大一下', 'RLC 电路的稳态研究',
      ['信号发生器', 'RLC 组合', '示波器或交流毫伏表'],
      '扫频测串联谐振曲线的幅频与相频特性',
      '读谐振频率与半功率带宽,算品质因数并与元件参数理论值比较',
      ['交流电路', '谐振', '幅频特性', '品质因数'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-049', UniversityPhysics.ELECTROMAGNETISM, '大一下', '用冲击电流计测电容和高电阻',
      ['冲击电流计', '标准电容', '待测电容与高阻', '电源与换向开关'],
      '利用电荷量与冲击电流计第一最大偏转成正比,用比较法测电容与高阻',
      '修正回路放电与漏电流的影响,给测量结果的不确定度',
      ['冲击电流计', '电荷测量', '时间常数'], Feasibility.NEEDS_REAL_GEARS, YNU));
    out.push(p('phy-u-050', UniversityPhysics.ELECTROMAGNETISM, '大一下', '非平衡桥测量热敏电阻特性',
      ['直流电桥', '热敏电阻', '检流计', '恒温源'],
      '在偏离平衡的桥路中用输出信号随温度的变化实现高灵敏测温',
      '标定灵敏度随温度与桥臂比的变化,找出最灵敏工作点',
      ['非平衡电桥', '灵敏度', '温度标定'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-051', UniversityPhysics.ELECTROMAGNETISM, '大一下', '用非线性电路研究混沌现象',
      ['蔡氏电路实验箱', '双踪示波器', '信号源'],
      '调节可变电阻使非线性电路从周期运动进入混沌,观察奇怪吸引子',
      '记录分岔序列,说明倍周期分岔与混沌出现的参数区间',
      ['非线性电路', '混沌', '分岔', '相图'], Feasibility.NEEDS_RENDERER, YNU));
    return out;
  }

  static optics(): ExperimentEntry[] {
    const out: ExperimentEntry[] = [];
    out.push(p('phy-u-060', UniversityPhysics.OPTICS, '大二上', '薄透镜焦距的测定',
      ['光具座', '凸透镜与凹透镜', '光源', '屏', '米尺'],
      '用物像距法、自准法与共轭法分别测透镜焦距',
      '比较三种方法的结果与优劣,用作图法求凹透镜的虚物焦距',
      ['薄透镜成像公式', '自准直', '共轭法'], Feasibility.NEEDS_RENDERER, YNU));
    out.push(p('phy-u-061', UniversityPhysics.OPTICS, '大二上', '分光计的调节与使用',
      ['分光计', '平面镜', '三棱镜', '光源与狭缝'],
      '调望远镜对无穷远聚焦、使望远镜与平行光管光轴垂直于仪器主轴,再用最小偏向角测折射率',
      '左右两游标读数取平均以消除偏心差,算折射率并给不确定度',
      ['分光计调节', '折射率', '最小偏向角', '偏心差'], Feasibility.NEEDS_REAL_GEARS, YNU));
    out.push(p('phy-u-062', UniversityPhysics.OPTICS, '大二上', '棱镜玻璃折射率的测定',
      ['分光计', '三棱镜', '汞灯或钠灯'],
      '测三棱镜顶角与各色光的最小偏向角,代入折射率公式',
      '对不同谱线分别求折射率,画出正常色散曲线',
      ['折射率', '色散', '最小偏向角'], Feasibility.NEEDS_REAL_GEARS, YNU));
    out.push(p('phy-u-063', UniversityPhysics.OPTICS, '大二上', '用菲涅耳双棱镜测钠光波长',
      ['光具座', '双棱镜', '钠灯', '测微目镜', '狭缝'],
      '双棱镜产生两个相干虚光源形成干涉条纹,由条纹间距与几何参数算波长',
      '用共轭法测两虚光源间距,并对误差主要来源做定量分析',
      ['分波前干涉', '双棱镜', '波长', '不确定度'], Feasibility.NEEDS_RENDERER, YNU));
    out.push(p('phy-u-064', UniversityPhysics.OPTICS, '大二上', '用牛顿环干涉测量透镜曲率半径',
      ['牛顿环装置', '单色光源', '读数显微镜'],
      '等厚干涉产生明暗同心圆环,由环直径平方与级次的线性关系求曲率半径',
      '用逐差法处理直径平方,避开接触形变与中心不确定带来的系统误差',
      ['等厚干涉', '空气劈尖', '牛顿环', '逐差法'], Feasibility.NEEDS_RENDERER, YNU));
    out.push(p('phy-u-065', UniversityPhysics.OPTICS, '大二上', '用透射光栅测定光波波长',
      ['分光计', '平面透射光栅', '汞灯或激光'],
      '测各级衍射角,由光栅方程求波长与光栅常数',
      '左右对称谱线取平均,讨论缺级与角色散本领',
      ['光栅衍射', '光栅方程', '角色散'], Feasibility.NEEDS_RENDERER, YNU));
    out.push(p('phy-u-066', UniversityPhysics.OPTICS, '大二上', '光栅衍射测汞灯光谱(可见波段)',
      ['分光计', '光栅', '汞灯'],
      '逐级测各谱线衍射角并换算成波长,识别汞灯的特征谱线',
      '给波长测量值与标准值之差,估计光栅常数的不确定度',
      ['光谱', '光栅', '波长标定'], Feasibility.NEEDS_RENDERER, YNU));
    out.push(p('phy-u-067', UniversityPhysics.OPTICS, '大二上', '迈克耳逊干涉仪的调节与使用',
      ['迈克耳逊干涉仪', 'He-Ne 激光器', '扩束与观察屏'],
      '调出等倾圆条纹,移动动镜并数条纹变化,由条纹数与移动距离算激光波长',
      '用逐次测量求波长并给不确定度;进一步测空气折射率或钠光双线波长差',
      ['分振幅干涉', '等倾条纹', '波长测量', '空气折射率'], Feasibility.NEEDS_REAL_GEARS, YNU));
    out.push(p('phy-u-068', UniversityPhysics.OPTICS, '大二上', '光的偏振性研究及马吕斯定律的验证',
      ['偏振片组', '四分之一与二分之一波片', '激光器', '光功率计'],
      '观察自然光、线偏振光与椭圆偏振光通过检偏器的光强变化',
      '测光强对检偏角的关系,验证余弦平方律并判断波片引入的相位差',
      ['偏振', '马吕斯定律', '波片', '椭圆偏振'], Feasibility.NEEDS_RENDERER, YNU));
    out.push(p('phy-u-069', UniversityPhysics.OPTICS, '大二上', '单缝衍射',
      ['光具座', '可调单缝', '激光', '白屏或测微目镜'],
      '测中央明纹宽度与各级暗纹位置,由暗纹条件算缝宽',
      '作暗纹位置对级次的图求缝宽,讨论近轴与远场条件',
      ['夫琅禾费衍射', '单缝', '暗纹条件'], Feasibility.NEEDS_RENDERER, NJU));
    out.push(p('phy-u-070', UniversityPhysics.OPTICS, '大二上', '显微镜的放大率测量',
      ['读数显微镜', '标准刻线尺', '待测透镜'],
      '用显微镜与标准尺比对,测透镜或显微镜系统的放大率',
      '多次读数取平均,给放大率的不确定度',
      ['显微镜', '放大率', '视角'], Feasibility.NEEDS_REAL_GEARS, YNU));
    out.push(p('phy-u-071', UniversityPhysics.OPTICS, '大二上', '测头发丝或细金属丝的直径',
      ['激光', '白屏', '米尺', '待测细丝'],
      '把细丝作为互补屏产生衍射条纹,由条纹间距反算直径',
      '与螺旋测微器直接测量结果比较,讨论巴比涅原理为什么允许这样做',
      ['衍射', '巴比涅原理', '微小长度'], Feasibility.NEEDS_RENDERER, YNU));
    out.push(p('phy-u-072', UniversityPhysics.OPTICS, '大二上', '平行光束在球形界面上的反射和折射',
      ['圆形玻璃砖', '平行光源', '量角器或分光计'],
      '追踪平行光束经球面反射与折射后的出射方向,验证反射与折射定律',
      '作入射角对折射角的图线,检验正弦比是否为常数',
      ['折射定律', '球面折射', '全反射'], Feasibility.NEEDS_RENDERER, NJU));
    return out;
  }

  static modern(): ExperimentEntry[] {
    const out: ExperimentEntry[] = [];
    out.push(p('phy-u-080', UniversityPhysics.MODERN, '大二上', '光电效应实验',
      ['光电效应实验仪', '汞灯与滤光片', '微电流放大器', '直流电源'],
      '测不同频率单色光下的遏止电压,验证爱因斯坦光电方程',
      '作遏止电压对频率图,由斜率求普朗克常数、由截距求逸出功',
      ['光子', '遏止电压', '普朗克常数', '逸出功'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-081', UniversityPhysics.MODERN, '大二上', '密立根油滴实验',
      ['密立根油滴仪', '喷雾器', '显微镜与计时装置'],
      '观察带电油滴在电场与重力场中的运动,测其电荷量',
      '用平衡法或动态法测多个油滴电荷,验证电荷量子化并求基本电荷',
      ['电荷量子化', '基本电荷', '斯托克斯修正'], Feasibility.NEEDS_REAL_GEARS, YNU));
    out.push(p('phy-u-082', UniversityPhysics.MODERN, '大二上', '夫兰克-赫兹实验',
      ['夫兰克-赫兹实验仪', '氩或汞管', '扫描电源与微电流计'],
      '测板极电流随加速电压的周期性变化,找原子的第一激发电位',
      '取相邻峰间距为激发电位,作峰位对序号图并给不确定度',
      ['能级量子化', '非弹性碰撞', '第一激发电位'], Feasibility.NEEDS_MODEL, YNU));
    out.push(p('phy-u-083', UniversityPhysics.MODERN, '大二上', '光速测量',
      ['光速测定仪(调制法或转镜法)', '示波器'],
      '测调制光往返传播的相位差或脉冲时间,反算光速',
      '给测量值与标准值的相对偏差,分析大气折射修正',
      ['光速', '相位差法', '调制波'], Feasibility.NEEDS_REAL_GEARS, YNU));
    out.push(p('phy-u-084', UniversityPhysics.MODERN, '大二上', '原子光谱',
      ['分光计或光栅光谱仪', '氢灯与各类气体放电灯'],
      '观察并测量线状光谱的谱线波长',
      '把氢原子谱线与巴耳末公式比较,拟合出里德伯常量',
      ['原子能级', '巴耳末系', '里德伯常量'], Feasibility.NEEDS_RENDERER, YNU));
    out.push(p('phy-u-085', UniversityPhysics.MODERN, '大二上', '塞曼效应',
      ['电磁铁', '钠灯或汞灯', '法布里-珀罗标准具与成像系统'],
      '观察磁场中谱线分裂成多条偏振分量',
      '测裂距算玻尔磁子,判断跃迁的量子数变化是否符合选择定则',
      ['塞曼效应', '磁矩', '玻尔磁子', '选择定则'], Feasibility.NEEDS_RENDERER, YNU));
    out.push(p('phy-u-086', UniversityPhysics.MODERN, '大二上', '核磁共振',
      ['核磁共振实验仪', '永磁体', '射频线圈与示波器'],
      '在固定射频下调磁场(或反之)找到共振吸收信号,测回旋磁比',
      '由共振条件算磁场或样品的 g 因子,给测量重复性',
      ['核磁共振', '回旋磁比', '共振条件'], Feasibility.NEEDS_REAL_GEARS, YNU));
    out.push(p('phy-u-087', UniversityPhysics.MODERN, '大二上', '顺磁共振',
      ['微波桥路与谐振腔', '电磁铁', '检测晶体', 'DPPH 样品'],
      '在微波波段测样品的共振吸收,求 g 因子',
      '由共振频率与磁场算 g 值并与标准值比较',
      ['电子自旋', '顺磁共振', 'g 因子'], Feasibility.NEEDS_REAL_GEARS, YNU));
    out.push(p('phy-u-088', UniversityPhysics.MODERN, '大二下', '全息照相',
      ['He-Ne 激光器', '分束镜与全反镜', '扩束显微物镜', '干板与冲洗设备'],
      '用物光与参考光干涉同时记录振幅与相位,再现三维像',
      '讨论物参光强比、振动隔离与清洁度对全息图质量的影响',
      ['全息', '干涉记录', '相位信息', '再现'], Feasibility.NEEDS_REAL_GEARS, YNU));
    out.push(p('phy-u-089', UniversityPhysics.MODERN, '大二下', '磁光克尔效应',
      ['磁光效应实验仪', '电磁铁', '起偏与检偏器', '光电探测'],
      '测偏振面在磁化样品表面反射后的旋转角与外磁场的关系',
      '画旋转角对磁场曲线,识别饱和磁化与磁滞特征',
      ['磁光效应', '克尔旋转', '磁滞'], Feasibility.NEEDS_RENDERER, YNU));
    out.push(p('phy-u-090', UniversityPhysics.MODERN, '大二下', '高温超导材料特性的测量',
      ['超导转变实验仪', '液氮', '四端法测电阻装置', '温度计'],
      '用四端法测样品电阻随温度的变化,找超导转变温度与转变宽度',
      '给出起始转变、中点与零电阻三个判据并说明它们的差别',
      ['超导', '转变温度', '四端法', '迈斯纳效应'], Feasibility.NEEDS_REAL_GEARS, YNU));
    out.push(p('phy-u-091', UniversityPhysics.MODERN, '大二下', '光纤数字通讯实验',
      ['光纤通讯实验箱', '激光器与光电探测器', '信号源与示波器'],
      '用数字信号调制激光经光纤传输,在接收端解调并测误码',
      '改变传输速率与光纤长度,找误码率上升的临界条件',
      ['光纤通信', '调制解调', '误码率'], Feasibility.NEEDS_MODEL, YNU));
    return out;
  }

  static all(): ExperimentEntry[] {
    return UniversityPhysics.mechanics().concat(UniversityPhysics.electromagnetism())
      .concat(UniversityPhysics.optics()).concat(UniversityPhysics.modern());
  }
}
