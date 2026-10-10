import { KnowledgePoint, KnowledgeLevel, makeKnowledge } from './KnowledgeTypes';
import { MapSubject, SchoolStage, UNVERIFIED_PREFIX } from './CurriculumTypes';

/**
 * 初中物理知识点(人教版)。
 *
 * 与 KnowledgePhysics 同一套标准:一条 = 能被单独提问、单独判对错的最小单元,
 * 章名用作浏览页的二级分组标题,粒度不超出教材的节。
 *
 * **册次口径:人教版八上、八下各一册,九年级为全一册(不分上下)。** 章节名与先后
 * 顺序参考了电子课本站的目录页(八上=机械运动/声现象/物态变化/光现象/透镜及其应用/
 * 质量与密度;八下=力/运动和力/压强/浮力/功和机械能/简单机械;九年级=内能到能源与
 * 可持续发展),但那两页都没标出版年份,新教材(2024)与旧版的章序未必一致,所以
 * **不据此宣称已核实**,整表仍带 `未核实:` 前缀。
 *
 * 同大学那张表一样,`source` 只为**覆盖面与排列顺序**作证;每条 statement 里的物理
 * 内容本身是可判对错的命题,靠初中物理的专业判断与易错点核,不靠引用。
 */
const PHY: MapSubject = MapSubject.PHYSICS;
const JR: SchoolStage = SchoolStage.JUNIOR;
const COVERAGE: string = UNVERIFIED_PREFIX + '按人教版初中物理教材编排覆盖面与顺序,未逐章核对目录';

function k(id: string, course: string, chapter: string, title: string, statement: string,
  symbols: string[], level: KnowledgeLevel, prereq: string[]): KnowledgePoint {
  return makeKnowledge(id, PHY, JR, course, chapter, title, statement, symbols,
    level, prereq, COVERAGE);
}

export class KnowledgePhysicsJunior {
  static readonly EIGHTH_UPPER: string = '八年级上';
  static readonly EIGHTH_LOWER: string = '八年级下';
  static readonly NINTH: string = '九年级';

  /** 八年级上:机械运动、声现象、物态变化、光现象、透镜及其应用、质量与密度 */
  static eighthUpper(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-phy-jr-001', KnowledgePhysicsJunior.EIGHTH_UPPER, '机械运动', '参照物的选择与运动的相对性',
      '判断一个物体是运动还是静止,必须先选定参照物;同一物体相对不同参照物的结论可以不同,所以不指明参照物就说「物体在运动」是没有意义的,平时说汽车「静止」默认是以地面为参照物',
      ['被选作标准的物体假定不动'], KnowledgeLevel.RECALL, []));
    out.push(k('kn-phy-jr-002', KnowledgePhysicsJunior.EIGHTH_UPPER, '机械运动', '速度的物理意义与平均速度',
      '速度表示物体运动的快慢,大小等于路程与通过这段路程所用时间之比 v=s/t;匀速直线运动中各时刻速度都相同,而变速运动算出的只是这一段路程内的平均速度,它不等于各段速度的算术平均值,也不能表示某一时刻的快慢',
      ['v = s/t', '1 m/s = 3.6 km/h'], KnowledgeLevel.APPLY, ['kn-phy-jr-001']));
    out.push(k('kn-phy-jr-003', KnowledgePhysicsJunior.EIGHTH_UPPER, '声现象', '声音由振动产生且传播需要介质',
      '声音是物体振动产生的,振动停止发声随即停止;传播必须依靠固体、液体或气体作介质,真空不能传声,所以月球上的宇航员要靠无线电交谈;一般固体中声速大于液体、液体大于气体,15 ℃ 空气里约 340 m/s',
      ['v_空气 ≈ 340 m/s（15 ℃）'], KnowledgeLevel.RECALL, []));
    out.push(k('kn-phy-jr-004', KnowledgePhysicsJunior.EIGHTH_UPPER, '声现象', '音调、响度与音色各自的决定因素',
      '音调由发声体振动的频率决定,频率越高音调越高;响度由振幅决定,还与距离发声体的远近和声音的分散程度有关;音色由发声体的材料、结构与发声方式决定,用来分辨不同乐器或不同的人;把音量调大改变的是响度而不是音调',
      ['f (Hz)', '可听声 20 Hz~20 000 Hz'], KnowledgeLevel.APPLY, ['kn-phy-jr-003']));
    out.push(k('kn-phy-jr-005', KnowledgePhysicsJunior.EIGHTH_UPPER, '光现象', '光在同种均匀介质中沿直线传播',
      '光只在同种均匀介质中沿直线传播,介质不均匀时会发生偏折;影子、日食与月食、小孔成像都是这条规律的现象,小孔成的是倒立的实像,像的形状由物体决定而与孔的形状无关;真空中光速 c=3×10⁸ m/s',
      ['c = 3×10⁸ m/s', '影子、日食、小孔成像'], KnowledgeLevel.RECALL, []));
    out.push(k('kn-phy-jr-006', KnowledgePhysicsJunior.EIGHTH_UPPER, '光现象', '光的反射定律与漫反射',
      '反射光线与入射光线、法线在同一平面内,分居法线两侧,反射角等于入射角;入射角增大时反射角跟着增大,垂直入射时反射角是 0° 而不是 90°;镜面反射和漫反射都遵守反射定律,漫反射只是因为表面各点法线方向不同,所以能从各个方向看到本身不发光的物体;反射时光路可逆',
      ['反射角 = 入射角', '光路可逆'], KnowledgeLevel.APPLY, ['kn-phy-jr-005']));
    out.push(k('kn-phy-jr-007', KnowledgePhysicsJunior.EIGHTH_UPPER, '光现象', '平面镜成像的特点',
      '平面镜成的是正立、等大的虚像,像与物到镜面的距离相等、二者连线与镜面垂直并且左右相反;像的大小只由物体本身决定,人靠近或远离镜面时像的大小不变,只是视角变大让人觉得像变大;虚像是反射光线的反向延长线相交而成的,所以不能用光屏承接它',
      ['像距 = 物距', '虚像：光屏接不到'], KnowledgeLevel.APPLY, ['kn-phy-jr-006']));
    out.push(k('kn-phy-jr-008', KnowledgePhysicsJunior.EIGHTH_UPPER, '光现象', '光的折射规律与水中物体看起来变浅',
      '光从一种介质斜射入另一种介质时传播方向发生偏折;从空气斜射入水或玻璃中时折射角小于入射角,从水斜射入空气时折射角大于入射角,入射角增大折射角也增大,而垂直入射时传播方向不变但传播速度改变;看到的水中的鱼比它的实际位置浅,是折射形成的虚像',
      ['空气→水：折射角 < 入射角'], KnowledgeLevel.APPLY, ['kn-phy-jr-006']));
    out.push(k('kn-phy-jr-009', KnowledgePhysicsJunior.EIGHTH_UPPER, '透镜及其应用', '凸透镜的焦点、焦距与成像规律',
      '凸透镜对光有会聚作用,平行于主光轴的光经折射后会过焦点,焦点到光心的距离叫焦距;成像随物距分三段:u>2f 成倒立缩小的实像(照相机),f<u<2f 成倒立放大的实像(投影仪),u<f 成正立放大的虚像(放大镜),即一倍焦距分虚实、二倍焦距分大小;成实像时物距减小则像距增大、像也变大',
      ['f 分虚实', '2f 分大小', '实像都倒立'], KnowledgeLevel.APPLY, ['kn-phy-jr-008']));
    out.push(k('kn-phy-jr-010', KnowledgePhysicsJunior.EIGHTH_UPPER, '物态变化', '温度与晶体熔化、凝固的图像',
      '温度表示物体的冷热程度,常用液体温度计靠液体热胀冷缩制成,读数时玻璃泡要留在被测液体中、视线与液柱的上表面相平;晶体在熔点熔化时继续吸热但温度不变,图像上出现一段平台,非晶体没有确定的熔点;同种晶体的熔点与凝固点相同,凝固过程要放热',
      ['℃', '冰的熔点 0 ℃', '吸热温度不一定升高'], KnowledgeLevel.APPLY, []));
    out.push(k('kn-phy-jr-011', KnowledgePhysicsJunior.EIGHTH_UPPER, '物态变化', '汽化、液化、升华与凝华的方向与吸放热',
      '蒸发和沸腾都属于汽化、都要吸热,蒸发在任何温度下都能进行且只发生在液体表面,沸腾要达到沸点且在继续吸热时温度保持不变;降低温度和压缩体积都能使气体液化,液化放热,日常看到的「白气」是水蒸气液化成的小水珠而不是水蒸气本身;樟脑丸变小、冰冻的衣服变干是升华吸热,霜和窗花是水蒸气凝华放热;液体沸点随气压降低而降低,所以高原上水不到 100 ℃ 就沸腾了',
      ['沸点随气压降低', '升华吸热、凝华放热'], KnowledgeLevel.APPLY, ['kn-phy-jr-010']));
    out.push(k('kn-phy-jr-012', KnowledgePhysicsJunior.EIGHTH_UPPER, '质量与密度', '质量是物体的属性而密度是物质的属性',
      '质量是物体所含物质的多少,不随形状、状态、位置和温度改变,把铁块压成铁片、把冰化成水、把书带到月球质量都不变;密度表示单位体积某种物质的质量,ρ=m/V,同种物质的密度一般不变,不随质量或体积增大而增大——质量加倍时体积也加倍而比值不变,但状态或温度改变时密度会变,水结冰密度变小所以冰浮在水面上',
      ['ρ = m/V', 'ρ_水 = 1.0×10³ kg/m³', '1 g/cm³ = 10³ kg/m³'], KnowledgeLevel.APPLY, []));
    out.push(k('kn-phy-jr-013', KnowledgePhysicsJunior.EIGHTH_UPPER, '质量与密度', '用天平和量筒测固体密度与偏差分析',
      '测不规则小石块的密度要先用托盘天平称质量(水平放置、游码归零后调平,左物右码,不能用手拿砝码),再用量筒排水法测体积 V=V₂−V₁,最后由 ρ=m/V 算出;如果先测体积、把石块从水中取出再称量,石块带的水会使质量偏大、算出的密度偏大;量筒读数时视线要与凹液面的最低处相平',
      ['V_物 = V₂ − V₁', 'ρ = m/V'], KnowledgeLevel.TRANSFER, ['kn-phy-jr-012']));
    return out;
  }

  /** 八年级下:力、运动和力、压强、浮力、功和机械能、简单机械 */
  static eighthLower(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-phy-jr-014', KnowledgePhysicsJunior.EIGHTH_LOWER, '力', '力的作用效果、三要素与弹簧测力计的使用',
      '力是物体对物体的作用,施力物体同时也是受力物体;它能改变物体的形状,也能改变物体运动速度的大小或方向;力的大小、方向和作用点叫三要素,画力的示意图时三点都要画到位;弹簧测力计是根据在弹性限度内弹簧的伸长与所受拉力成正比制成的,使用前要看清量程与分度值、检查指针是否指零,施力时沿弹簧轴线方向且不能超过量程',
      ['F (N)', '在弹性限度内 ΔL ∝ F'], KnowledgeLevel.RECALL, []));
    out.push(k('kn-phy-jr-015', KnowledgePhysicsJunior.EIGHTH_LOWER, '力', '重力 G=mg 与 g=9.8 N/kg 的物理含义',
      '地面附近的物体由于地球吸引而受到重力,其大小与质量成正比 G=mg;g=9.8 N/kg 的物理含义是质量为 1 kg 的物体受到的重力是 9.8 N,初中计算常取 10 N/kg;重力的方向总是竖直向下而不是「垂直向下」,作用点在重心,同一物体在赤道与两极受到的重力略有不同',
      ['G = mg', 'g = 9.8 N/kg'], KnowledgeLevel.APPLY, ['kn-phy-jr-014']));
    out.push(k('kn-phy-jr-016', KnowledgePhysicsJunior.EIGHTH_LOWER, '运动和力', '牛顿第一定律与惯性',
      '一切物体在没有受到力的作用时,总保持静止状态或匀速直线运动状态;这一定律是在斜面实验的基础上推理概括出来的,不能用实验直接验证;惯性是物体保持原来运动状态不变的性质,一切物体在任何时候都有惯性,惯性大小只由质量决定而与速度无关,惯性不是力,不能说「受到惯性作用」',
      ['F_合 = 0 ⇒ v 不变'], KnowledgeLevel.APPLY, ['kn-phy-jr-014']));
    out.push(k('kn-phy-jr-017', KnowledgePhysicsJunior.EIGHTH_LOWER, '运动和力', '二力平衡的条件',
      '作用在同一物体上的两个力大小相等、方向相反并且作用在同一条直线上时二力平衡,物体处于静止或匀速直线运动的平衡状态;四个条件缺一不可,漏掉「同一物体」就会把相互作用力当成平衡力——绳拉物体的力与物体拉绳的力等大反向,但分别作用在两个物体上,不是平衡力',
      ['同物、等大、反向、共线'], KnowledgeLevel.APPLY, ['kn-phy-jr-014']));
    out.push(k('kn-phy-jr-018', KnowledgePhysicsJunior.EIGHTH_LOWER, '运动和力', '滑动摩擦力的大小与方向',
      '滑动摩擦力的大小只由接触面受到的压力和接触面的粗糙程度决定,与接触面积大小、运动速度都无关;它的方向总是与物体相对运动的方向相反,而不一定与物体运动方向相反,人走路时地面给人的静摩擦力就向前、是动力;用弹簧测力计沿水平方向匀速拉动木块,正是靠二力平衡才能把摩擦力读出来',
      ['f 只与压力、粗糙程度有关', '匀速拉动：f = F_拉'], KnowledgeLevel.APPLY, ['kn-phy-jr-017', 'kn-phy-jr-014']));
    out.push(k('kn-phy-jr-019', KnowledgePhysicsJunior.EIGHTH_LOWER, '压强', '固体压强 p=F/S 与改变压强的方法',
      '压强表示压力的作用效果,等于压力除以受力面积 p=F/S,1 Pa=1 N/m²;压力并不总是等于重力,只有物体静止在水平面上且竖直方向没有其他力时二者大小才相等;增大压强可以增大压力或减小受力面积(刀刃磨薄、针尖做尖),减小压强则相反(书包背带做宽、铁轨下垫枕木)',
      ['p = F/S', '1 Pa = 1 N/m²'], KnowledgeLevel.APPLY, ['kn-phy-jr-015']));
    out.push(k('kn-phy-jr-020', KnowledgePhysicsJunior.EIGHTH_LOWER, '压强', '液体压强 p=ρgh 与连通器',
      '液体内部向各个方向都有压强,同一深度各方向的压强相等,压强随深度增大而增大并由液体密度决定;由 p=ρgh 可知液体压强与液体的总重、容器底面积和容器形状都无关,h 是从自由液面向下量的竖直距离;上端开口、下部连通的容器叫连通器,装同种液体且不流动时各容器中的液面总保持相平,茶壶、船闸、下水道存水弯都靠它工作',
      ['p = ρgh', '只由 ρ、h 决定'], KnowledgeLevel.APPLY, ['kn-phy-jr-019']));
    out.push(k('kn-phy-jr-021', KnowledgePhysicsJunior.EIGHTH_LOWER, '压强', '大气压强与流体压强随流速的变化',
      '大气对浸在它里面的物体产生压强,马德堡半球实验证明了它的存在,托里拆利实验首次测出标准大气压约 1.0×10⁵ Pa、能支持约 760 mm 高的水银柱;大气压随高度增加而减小,气压降低时液体沸点随之下降;气体和液体中流速越大的位置压强越小,这是飞机获得升力、火车站台要设安全线的依据',
      ['p₀ ≈ 1.0×10⁵ Pa', '760 mm 水银柱'], KnowledgeLevel.APPLY, ['kn-phy-jr-020']));
    out.push(k('kn-phy-jr-022', KnowledgePhysicsJunior.EIGHTH_LOWER, '浮力', '浮力的产生原因与阿基米德原理',
      '浸在液体或气体中的物体受到竖直向上的浮力,它来源于物体上、下表面所受压力的差,下表面更深、压强更大,所以合力向上;阿基米德原理指出浮力的大小等于它排开的液体所受的重力 F浮=G排=ρ液gV排,因此浮力只由液体密度和排开液体的体积决定,与物体自身的质量、密度、形状以及浸没后的深度都无关',
      ['F_浮 = ρ_液 g V_排', 'F_浮 = G_排'], KnowledgeLevel.APPLY, ['kn-phy-jr-020']));
    out.push(k('kn-phy-jr-023', KnowledgePhysicsJunior.EIGHTH_LOWER, '浮力', '物体的浮沉条件与浮力的应用',
      '浸没时比较浮力与重力:F浮>G 物体上浮、F浮<G 下沉、F浮=G 悬浮,静止漂浮时二力再次相等;用密度比较更直接,ρ物<ρ液 则最终漂浮;轮船把钢板做成空心来增大排水体积,潜水艇靠水舱吸水和排水改变自身重力实现下潜与上浮,气球和飞艇则靠袋内气体密度小于空气密度',
      ['漂浮：F_浮 = G', 'ρ_物 < ρ_液 ⇒ 漂浮'], KnowledgeLevel.APPLY, ['kn-phy-jr-022', 'kn-phy-jr-012']));
    out.push(k('kn-phy-jr-024', KnowledgePhysicsJunior.EIGHTH_LOWER, '功和机械能', '做功的两个必要因素与功率',
      '做功必须同时满足两个必要因素:有力作用在物体上,并且物体在力的方向上移动一段距离;有力无距离(推而未动)、有距离无力(靠惯性滑行)以及力与运动方向垂直(提着水桶水平走)都不做功,功的大小 W=Fs;功率表示做功的快慢,P=W/t,做功多的机械功率不一定大,还要看用了多少时间',
      ['W = Fs (J)', 'P = W/t (W)'], KnowledgeLevel.APPLY, ['kn-phy-jr-014']));
    out.push(k('kn-phy-jr-025', KnowledgePhysicsJunior.EIGHTH_LOWER, '功和机械能', '动能、势能的变化与机械能守恒',
      '动能由质量和速度决定,速度对它的影响更大;重力势能由质量和被举的高度决定;弹性势能由弹性形变的程度决定;动能与势能可以相互转化,如果只有动能和势能相互转化而不计摩擦与空气阻力,机械能的总量就保持不变,滚摆和摆动的小球在最低点动能最大、在最高点势能最大,而现实里的秋千越荡越低是因为有一部分机械能转化成了内能',
      ['E_k：m、v', 'E_p：m、h'], KnowledgeLevel.APPLY, ['kn-phy-jr-024']));
    out.push(k('kn-phy-jr-026', KnowledgePhysicsJunior.EIGHTH_LOWER, '简单机械', '杠杆的平衡条件与三类杠杆',
      '杠杆平衡时满足 F₁L₁=F₂L₂,力臂是支点到力的作用线的垂直距离,而不是支点到力的作用点的距离;动力臂大于阻力臂的是省力杠杆,如撬棒和钢丝钳,它省力但费距离;动力臂小于阻力臂的是费力杠杆,如镊子和钓鱼竿,它费力但省距离;动力臂等于阻力臂的是等臂杠杆,如天平,既不省力也不费力',
      ['F₁L₁ = F₂L₂', '力臂 ⊥ 力的作用线'], KnowledgeLevel.APPLY, ['kn-phy-jr-014']));
    out.push(k('kn-phy-jr-027', KnowledgePhysicsJunior.EIGHTH_LOWER, '简单机械', '滑轮组的省力情况与机械效率',
      '定滑轮不省力但能改变力的方向,动滑轮省一半力却要费一倍距离,滑轮组的省力情况由承担物重的绳子段数 n 决定,不计摩擦与绳重时 F=(G_物+G_动)/n、绳端移动距离 s=nh;使用机械总要做额外功,所以有用功总小于总功,机械效率 η=W_有用/W_总 永远小于 1,它与省力多少、做功快慢都无关,同一滑轮组提升的物体越重机械效率越高',
      ['s = nh', 'η = W_有/W_总 < 1'], KnowledgeLevel.APPLY, ['kn-phy-jr-024', 'kn-phy-jr-026']));
    return out;
  }

  /** 九年级(全一册):内能、电流和电路、电压 电阻、欧姆定律、电功率、生活用电、电与磁、能源 */
  static ninth(): KnowledgePoint[] {
    const out: KnowledgePoint[] = [];
    out.push(k('kn-phy-jr-028', KnowledgePhysicsJunior.NINTH, '内能', '分子动理论与物体内能的改变方式',
      '物质由大量分子、原子构成,分子在不停地做无规则运动,温度越高运动越剧烈所以叫热运动,分子间同时存在引力和斥力;物体内所有分子热运动的动能与分子势能的总和叫内能,一切物体在任何温度下都有内能,0 ℃ 的冰同样有内能;改变内能有做功和热传递两种方式且二者等效,而热量是热传递过程中转移的内能的多少,是过程量,不能说物体「含有热量」',
      ['扩散现象', '内能 ≠ 热量'], KnowledgeLevel.RECALL, []));
    out.push(k('kn-phy-jr-029', KnowledgePhysicsJunior.NINTH, '内能', '比热容与热量计算 Q=cmΔt',
      '比热容是单位质量的某种物质温度升高 1 ℃ 所吸收的热量,它是物质本身的属性,不随质量与温度变化;c_水=4.2×10³ J/(kg·℃) 在常见物质中较大,所以沿海地区昼夜温差小于内陆、汽车用水做冷却剂;吸收或放出的热量由 Q=cmΔt 计算,式中的 Δt 是温度的变化量而不是某个温度值',
      ['Q = cmΔt', 'c_水 = 4.2×10³ J/(kg·℃)'], KnowledgeLevel.APPLY, ['kn-phy-jr-028']));
    out.push(k('kn-phy-jr-030', KnowledgePhysicsJunior.NINTH, '电流和电路', '串联电路与并联电路的识别',
      '把电路元件逐个顺次连接是串联,电流只有一条通路,一处断开整个电路就没有电流、各用电器互相影响;把元件并列地接在两点之间是并联,各支路独立工作、互不影响,家庭中的用电器与插座都是并联的。识别只看电流有几条路径,与元件画在图上的位置无关',
      ['串联:一条通路', '并联:各支路独立'], KnowledgeLevel.APPLY, []));
    out.push(k('kn-phy-jr-031', KnowledgePhysicsJunior.NINTH, '电流和电路', '电流的形成与方向、电压的作用',
      '电荷的定向移动形成电流,物理学规定正电荷定向移动的方向为电流方向,金属导体中自由电子移动的方向与电流方向相反;电压是使电路中形成电流的原因,由电源提供,有电压而电路不闭合时并没有电流 —— 电荷在导体中本来就乱动,形成电流需要的是持续的电压与闭合的回路两个条件',
      ['I (A)', '1 A = 10³ mA', 'U (V)', '一节干电池 1.5 V'], KnowledgeLevel.RECALL, ['kn-phy-jr-030']));
    out.push(k('kn-phy-jr-032', KnowledgePhysicsJunior.NINTH, '电压 电阻', '电阻的决定因素与滑动变阻器的使用',
      '电阻表示导体对电流的阻碍作用,其大小由导体的材料、长度和横截面积决定,还受温度影响,而与它两端的电压和通过的电流无关——导体两端电压为零时电阻仍然存在,R=U/I 只是量度式;滑动变阻器靠改变接入电路中电阻丝的长度来变阻,必须接「一上一下」两个接线柱才调得了电阻,闭合开关前应把阻值调到最大以保护电路',
      ['R (Ω)', '与 U、I 无关'], KnowledgeLevel.APPLY, ['kn-phy-jr-031']));
    out.push(k('kn-phy-jr-033', KnowledgePhysicsJunior.NINTH, '欧姆定律', '欧姆定律 I=U/R 的同体性与同时性',
      '导体中的电流跟它两端的电压成正比、跟它的电阻成反比,I=U/R;应用时三个量必须对应**同一段导体**和**同一时刻**,把甲的电压除以乙的电阻、或用变阻器调节前的电流配调节后的电压,得到的数没有任何物理意义。变形 R=U/I 只是量度式,不能说电阻与电压成正比',
      ['I = U/R', '同体、同时'], KnowledgeLevel.APPLY, ['kn-phy-jr-031', 'kn-phy-jr-032']));
    out.push(k('kn-phy-jr-034', KnowledgePhysicsJunior.NINTH, '欧姆定律', '伏安法测电阻与灯丝电阻随温度的变化',
      '用电压表测出导体两端的电压、用电流表测出通过导体的电流,由 R=U/I 算出电阻,滑动变阻器用来改变待测电阻两端的电压以获得多组数据;测定值电阻时把多组数据取平均能减小误差,但测小灯泡时不能取平均——灯丝电阻随温度升高而增大,不同电压下温度不同、电阻也不同,它的 I-U 图线不是过原点的直线',
      ['R = U/I', 'I-U 图线非线性'], KnowledgeLevel.TRANSFER, ['kn-phy-jr-033']));
    out.push(k('kn-phy-jr-035', KnowledgePhysicsJunior.NINTH, '电功率', '电功、电功率与额定功率、实际功率',
      '电流做功把电能转化为其他形式的能,W=UIt,电能表测量的就是用电器消耗的电能,1 kW·h=3.6×10⁶ J;电功率表示电流做功的快慢,P=UI=W/t;用电器正常工作时的电压是额定电压、对应的功率是额定功率,实际电压低于额定电压时实际功率变小、灯泡变暗,只有实际电压等于额定电压才能正常工作,而灯泡的亮度由实际功率决定',
      ['W = UIt', 'P = UI', '1 kW·h = 3.6×10⁶ J'], KnowledgeLevel.APPLY, ['kn-phy-jr-033']));
    out.push(k('kn-phy-jr-036', KnowledgePhysicsJunior.NINTH, '电功率', '焦耳定律与电热的利用和防止',
      '电流通过导体产生的热量跟电流的二次方成正比、跟导体的电阻和通电时间成正比,Q=I²Rt;电热器要用电阻率大、熔点高的合金做发热体来充分利用电热,而电动机和输电导线则要尽量减少电热,因为此时电能主要转化为机械能;只有在纯电阻电路里才能用 W=UIt 代替 Q=I²Rt,非纯电阻电路中两者并不相等',
      ['Q = I²Rt'], KnowledgeLevel.APPLY, ['kn-phy-jr-035']));
    out.push(k('kn-phy-jr-037', KnowledgePhysicsJunior.NINTH, '生活用电', '家庭电路的组成与安全用电',
      '家庭电路由进户线(火线与零线)、电能表、总开关、保险装置、插座和用电器依次组成,各用电器之间是并联的,火线与零线之间的电压是 220 V;测电笔可以区分火线与零线,三孔插座把用电器的金属外壳接地以防触电;保险丝用电阻率较大、熔点较低的铅锑合金制成且绝对不能用铜丝代替,经验证明只有不高于 36 V 的电压对人体才是安全的',
      ['U_家庭 = 220 V', 'U_安全 ≤ 36 V'], KnowledgeLevel.RECALL, ['kn-phy-jr-031']));
    out.push(k('kn-phy-jr-038', KnowledgePhysicsJunior.NINTH, '电与磁', '磁现象与磁场、磁感线的描述',
      '磁体有两个磁极,同名磁极相互排斥、异名磁极相互吸引;磁体周围存在一种看不见却真实存在的物质叫磁场,它的基本性质是对放入其中的磁体产生力的作用,物理学规定小磁针静止时 N 极所指的方向就是该点的磁场方向,磁体外部的磁感线从 N 极出发回到 S 极;地球本身是个大磁体,地磁南极在地理北极附近,我国宋代学者沈括最早记述了磁偏角',
      ['N 极指向 = 磁场方向', '外部磁感线 N→S'], KnowledgeLevel.RECALL, []));
    out.push(k('kn-phy-jr-039', KnowledgePhysicsJunior.NINTH, '电与磁', '电流的磁效应与电磁铁',
      '奥斯特实验说明通电导线周围存在磁场,这就是电流的磁效应 —— 它第一次把电与磁联系起来;通电螺线管的极性与电流方向的关系用右手螺旋定则判断,四指绕向电流方向时大拇指指向 N 极;电磁铁的磁性强弱由电流大小和线圈匝数共同决定,有电流才有磁性,因此可以靠通断和调节电流来控制磁性的有无与强弱,电磁继电器正是用低压控制电路间接控制高压工作电路',
      ['右手螺旋定则', '磁性强弱:I 与匝数'], KnowledgeLevel.APPLY, ['kn-phy-jr-038', 'kn-phy-jr-031']));
    out.push(k('kn-phy-jr-040', KnowledgePhysicsJunior.NINTH, '能源与可持续发展', '能量守恒定律与能源的分类',
      '能量既不会消灭也不会创生,它只会从一种形式转化为其他形式,或者从一个物体转移到另一个物体,而总量保持不变,这一定律表明永动机不可能制成;能直接从自然界获得的煤、石油、天然气、太阳能是一次能源,由一次能源加工得到的电能是二次能源,水能、风能、太阳能可短期再生属可再生能源,煤、石油、核能属不可再生能源;能量的转化和转移有方向性,所以能量虽然守恒仍然要节约能源',
      [], KnowledgeLevel.RECALL, ['kn-phy-jr-028']));
    /*
     * 041~045 是后补的:第一轮把 40 条当成了硬上限,于是几条各自能单独提问、单独判对错的
     * 内容被挤进了一条(030 里既讲识别又讲规律、039 里电磁感应和磁场对电流的作用混在一起)。
     * 这张表的定义是"最小单元",条数不是 —— 所以拆开而不是维持原样。
     * 编号接在末尾而没插回原位,是为了不动任何已有条目的 id 与它们的先修引用。
     */
    out.push(k('kn-phy-jr-041', KnowledgePhysicsJunior.NINTH, '电流和电路', '串并联电路的电流与电压规律',
      '串联电路中各处电流相等 I=I₁=I₂,总电压等于各部分电压之和 U=U₁+U₂;并联电路中各支路两端电压相等 U=U₁=U₂,干路电流等于各支路电流之和 I=I₁+I₂。这两条正是应用里「串联电路的电压与电阻规律」与「并联电路的电流规律」两个实验直接要检验的对象',
      ['串联 I 处处相等', '并联 U 各支路相等', 'I_干 = ΣI_支'], KnowledgeLevel.APPLY, ['kn-phy-jr-030']));
    out.push(k('kn-phy-jr-042', KnowledgePhysicsJunior.NINTH, '电流和电路', '电流表与电压表的连接规则与读数',
      '电流表必须串联在被测电路里、让电流从正接线柱流入,绝不允许不经用电器直接接到电源两极,那相当于短路;电压表并联在被测用电器两端,它可以直接接在电源两极测电源电压。两者读数都先看量程再认分度值,视线要正对刻度 —— 分度值辨认与读数视差这套要求在量取训练里对量筒提过,在电学里对电表同样成立',
      ['电流表串联', '电压表并联', '先量程后分度值'], KnowledgeLevel.APPLY, ['kn-phy-jr-031']));
    out.push(k('kn-phy-jr-043', KnowledgePhysicsJunior.NINTH, '欧姆定律', '串并联电阻规律与分压分流',
      '串联总电阻等于各电阻之和 R=R₁+R₂,相当于增加了导体的长度,串联电阻起分压作用且电压之比等于电阻之比;并联总电阻的倒数等于各电阻倒数之和,相当于增加了横截面积,所以并联后的总电阻比任何一支路都小,并联电阻起分流作用且电流之比等于电阻的反比',
      ['串联 R = R₁+R₂', '并联 1/R = 1/R₁+1/R₂', 'U₁:U₂=R₁:R₂'], KnowledgeLevel.APPLY,
      ['kn-phy-jr-033', 'kn-phy-jr-041']));
    out.push(k('kn-phy-jr-044', KnowledgePhysicsJunior.NINTH, '电与磁', '电磁感应现象与发电机的能量转化',
      '闭合电路的一部分导体在磁场中做切割磁感线运动时,导体中就产生感应电流,这是电磁感应现象;感应电流的方向同时取决于磁场方向和导体运动方向,只改变其中一个方向电流反向,两个都改则方向不变;发电机就是靠电磁感应把机械能转化为电能 —— 它与电动机正好相反,这两个装置是初中电与磁里最容易记反的一对',
      ['切割磁感线才产生', '机械能→电能'], KnowledgeLevel.APPLY, ['kn-phy-jr-038', 'kn-phy-jr-039']));
    out.push(k('kn-phy-jr-045', KnowledgePhysicsJunior.NINTH, '电与磁', '通电导体在磁场中受力与电动机的能量转化',
      '通电导体在磁场里会受到力的作用,力的方向由磁场方向和电流方向共同决定,只改变其中一个受力方向就反向;这是电动机的原理,它把电能转化为机械能,与发电机把机械能转化为电能的方向正好相反。判断"谁产生电"的窍门是看装置里有没有电源:有电源的是电动机,靠外力转动而产生电的是发电机',
      ['电能→机械能', '有电源是电动机'], KnowledgeLevel.APPLY, ['kn-phy-jr-039']));
    return out;
  }

  static all(): KnowledgePoint[] {
    return KnowledgePhysicsJunior.eighthUpper().concat(KnowledgePhysicsJunior.eighthLower())
      .concat(KnowledgePhysicsJunior.ninth());
  }
}
