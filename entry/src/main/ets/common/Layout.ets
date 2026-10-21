/** 三档设备:手机、学生平板、教师大屏。断点取 ArkUI 常规阈值。 */
export enum DeviceClass {
  PHONE = 'phone',
  PAD = 'pad',
  LARGE = 'large'
}

export class Layout {
  static readonly PHONE_MAX: number = 600;
  static readonly PAD_MAX: number = 1100;
  /**
   * 「矮屏」的判定阈值。
   *
   * 手机横屏之后高度只有 330~440vp,而平板横屏最矮也有 600vp(1024x600)——
   * 500 就落在这段空档里,两类设备不会互相误判。
   */
  static readonly COMPACT_HEIGHT_MAX: number = 500;
  /**
   * 阅读列的宽度上限。
   *
   * 横屏手机有 791vp 宽,一行能塞 100 个汉字:那不是阅读,是刻度。
   * 640vp 约合 42 个汉字,是一行长文能读下去的上限。
   */
  static readonly COMPACT_CONTENT_WIDTH: number = 640;

  /**
   * 设备档位。宽度与高度都要看。
   *
   * 只看宽度会出事:手机横屏的宽度是 791vp,落在平板区间(600..1100)里,
   * 于是横着的手机被当成平板 —— 实验页走两栏分支,同时要一块 240vp 的画面
   * 加一整窗图线,而横屏只剩约 250vp 高,画面被挤没、按钮掉到屏外。
   *
   * 高度=0 表示还没量到(首帧),此时退回只看宽度。
   */
  static classify(widthVp: number, heightVp: number): DeviceClass {
    // 宽而矮 = 横着拿的手机。宽度够大屏的(≥1100)不降档:教师大屏哪怕摆成
    // 一条窄带也不该缩成手机字号。
    if (Layout.isCompact(heightVp) && widthVp < Layout.PAD_MAX) {
      return DeviceClass.PHONE;
    }
    if (widthVp < Layout.PHONE_MAX) {
      return DeviceClass.PHONE;
    }
    if (widthVp < Layout.PAD_MAX) {
      return DeviceClass.PAD;
    }
    return DeviceClass.LARGE;
  }

  /**
   * 矮屏判定:视口高度不足以像竖屏那样一屏一栏地铺。
   *
   * 高度=0(还没量到)不算矮屏 —— 那时按竖屏那套走,首帧不会突然换布局。
   */
  static isCompact(heightVp: number): boolean {
    return heightVp > 0 && heightVp < Layout.COMPACT_HEIGHT_MAX;
  }

  /** 参数面板宽度。大屏要更宽,因为教师站在讲台前需要更远的可读性 */
  static panelWidth(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 460;
    }
    return 336;
  }

  // ---- 字号角色阶 -----------------------------------------------------------
  /**
   * 十个角色,三档。收敛前页面里有 18 种 `LARGE ? a : b` 组合和 15 处裸数字,
   * 其中「次要文字」一项就有 17:12 / 16:11 / 16:12 / 15:11 / 14:10 五个同义档。
   *
   * 两档三元是这里真正的 bug 来源:PAD 落到 else 分支拿手机值,
   * 而 Layout 里的三档访问器给 PAD 另一值 —— 同一级文字在不同页面尺寸不一致。
   * 数值本身由 check.mjs 断言三档单调、落在可读区间、角色之间确实分层。
   */
  /** 报告页的大分数:一眼看到总分 */
  static displaySize(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 46;
    }
    return cls === DeviceClass.PAD ? 40 : 34;
  }

  /** 读数字号:大屏 32vp 保证后排学生能看见当前值 */
  static readoutSize(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 32;
    }
    return cls === DeviceClass.PAD ? 24 : 19;
  }

  /** 页面主标题 */
  static pageTitleSize(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 28;
    }
    return cls === DeviceClass.PAD ? 22 : 19;
  }

  /** 段标题:「参数」「实时读数」「关键事实」这类分区标题 */
  static sectionSize(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 22;
    }
    return cls === DeviceClass.PAD ? 18 : 15;
  }

  /** 列表卡片的标题(首页实验卡)。比段标题重,因为它是整张卡的主角 */
  static cardTitleSize(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 22;
    }
    return cls === DeviceClass.PAD ? 18 : 17;
  }

  /** 成段正文 */
  static bodySize(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 20;
    }
    return cls === DeviceClass.PAD ? 18 : 15;
  }

  /** 控件上的文字:标签、按钮、行内数值。页面里出现最多的一档 */
  static labelSize(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 18;
    }
    return cls === DeviceClass.PAD ? 15 : 13;
  }

  /** 说明性文字:学段、时长、单位这类次要信息 */
  static captionSize(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 16;
    }
    return cls === DeviceClass.PAD ? 14 : 12;
  }

  /** 最小档:化学式下标、装饰符号。再小就不满足远距离可读 */
  static microSize(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 14;
    }
    return cls === DeviceClass.PAD ? 12 : 10;
  }

  /** 气泡指示器的圆点。三个点故意同尺寸,收敛前是 20/26/18 三种装饰性大小 */
  static bubbleSize(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 26;
    }
    return cls === DeviceClass.PAD ? 23 : 20;
  }

  /** 触控目标最小尺寸。大屏用远距离触摸,按下限 56vp 处理 */
  static touchMin(cls: DeviceClass): number {
    return cls === DeviceClass.LARGE ? 56 : 44;
  }

  /**
   * 量取页器皿画布高度。
   *
   * 手机档给 180vp 而不是"能多大多大":这一页要一屏装下读数卡、两只器皿、图例、引导、
   * 判定卡、两根滑杆和三个动作按钮。224vp 时按钮整排掉到屏幕下沿之外(实测按一次要滚一次),
   * 而 180vp 仍能把 10 mL 的十分之一格画到可读。
   */
  static gaugeHeight(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 400;
    }
    return cls === DeviceClass.PAD ? 320 : 180;
  }

  /** 量取页器皿画布宽度。回转体加宽后需要留出判读游标的位置 */
  static gaugeWidth(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 196;
    }
    return cls === DeviceClass.PAD ? 160 : 132;
  }

  /**
   * 试剂瓶画布:矮而粗,与量筒并排站着。
   *
   * 它是量取页上唯一会倾斜的那只器皿 —— 倾倒仰角要有看得见的载体,
   * 否则学生拖滑杆时屏幕上什么都不变,界面就等于在说一件没发生的事。
   */
  static bottleWidth(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 168;
    }
    return cls === DeviceClass.PAD ? 140 : 116;
  }

  static bottleHeight(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 210;
    }
    return cls === DeviceClass.PAD ? 176 : 112;
  }

  /** 实验台一张容器卡的宽度 */
  static vesselCardWidth(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 92;
    }
    return cls === DeviceClass.PAD ? 78 : 66;
  }

  /** 容器卡内器皿的绘制高度 */
  static vesselCardHeight(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 210;
    }
    return cls === DeviceClass.PAD ? 180 : 150;
  }

  /** 开关的宽度。高度由 touchMin 定,宽度按外形比例给一档 */
  static toggleWidth(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 62;
    }
    return cls === DeviceClass.PAD ? 52 : 44;
  }

  /** 开关滑轨高度。刻意低于触控下限:它是视觉轨道,可点区域由开关自身宽高决定 */
  static toggleHeight(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 34;
    }
    return cls === DeviceClass.PAD ? 28 : 24;
  }

  /** 文字按钮的高度。手机档必须达到触控下限,否则按钮「看着大实际点不中」 */
  static buttonHeight(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 56;
    }
    return cls === DeviceClass.PAD ? 48 : 44;
  }

  /** 药品柜滚动区的上限高度。再高就把容器卡挤出首屏 */
  static shelfMaxHeight(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 200;
    }
    return cls === DeviceClass.PAD ? 170 : 130;
  }

  /**
   * 单张图线的宿主高度。
   *
   * 这个值不是"看着舒服"的量,是由 view/PlotFrame 的算术反推的下限:扣掉标题行与
   * 底部两行刻度后,绘图区净高还得 ≥ 40vp 才有读图价值。原来手机档把 190vp 平分给
   * 两张图(每张 90vp),净高算出来是负数,于是图线区静默不画。
   */
  static chartHeight(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 190;
    }
    return cls === DeviceClass.PAD ? 170 : 150;
  }

  /** 图线内容总高:按图数给,不再让 N 张图平分一个固定值 */
  static chartAreaHeight(cls: DeviceClass, count: number): number {
    const n = count < 1 ? 1 : count;
    return n * Layout.chartHeight(cls) + (n - 1) * 10;
  }

  /** 图线可视窗:最多露出两张多一点点,其余靠滚动,免得把仿真画面挤出屏幕 */
  static chartViewportHeight(cls: DeviceClass, count: number): number {
    const needed = Layout.chartAreaHeight(cls, count);
    const cap = 2.35 * Layout.chartHeight(cls);
    return needed < cap ? needed : Math.round(cap);
  }

  /**
   * 仿真画面的最小高度。开启图线后画面被 layoutWeight 挤成一条,2D 世界就没有可读性了
   * —— 下限由这里说一次,而不是让布局在运行时碰运气。
   *
   * 矮屏(横屏手机)另给一档:那里只剩约 250vp 高,竖屏的 210vp 下限会把
   * 操作条顶出屏幕,画面反而更小。
   */
  static minSceneHeight(cls: DeviceClass, compact: boolean): number {
    if (compact) {
      return 150;
    }
    if (cls === DeviceClass.LARGE) {
      return 280;
    }
    return cls === DeviceClass.PAD ? 240 : 210;
  }

  /**
   * 周期表单格的边长(正方格)。
   *
   * 手机档取 44,正好是触控下限 —— 18 列硬塞进手机屏宽只有 17vp 一列,元素符号根本看不清,
   * 那种"看得见形状点不中"的表比没有更糟。所以手机档不缩表,改成整表横向滚动,
   * 一屏露出七八列,点哪一格都是 44vp 的目标。
   */
  static periodicCellSize(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 64;
    }
    return cls === DeviceClass.PAD ? 52 : 44;
  }

  /** 周期表左侧那一栏:周期号,以及表下方两行的「镧系」「锕系」标签 */
  static periodicGutter(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 38;
    }
    return cls === DeviceClass.PAD ? 34 : 32;
  }

  /** 族号表头那一行的高 */
  static periodicHeaderHeight(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 32;
    }
    return cls === DeviceClass.PAD ? 28 : 24;
  }

  /** 格子里的元素符号。序数走 microSize,符号要压得住序数,单独给一档 */
  static periodicSymbolSize(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 24;
    }
    return cls === DeviceClass.PAD ? 20 : 16;
  }

  /**
   * 单栏还是两栏。
   *
   * 手机竖屏是单栏(画布在上、控件在下,一屏一件);手机横屏是矮屏,
   * 单栏会把画布压成一条,所以改两栏(画布在左、面板在右)。
   */
  static isStacked(cls: DeviceClass, compact: boolean): boolean {
    return cls === DeviceClass.PHONE && !compact;
  }

  // ---- 阶梯与角色尺寸 -------------------------------------------------------
  /** 8pt 基准间距阶梯,4pt 为微调档。间距型令牌必须是它的成员 */
  static readonly SPACE: number[] = [4, 8, 12, 16, 24, 32, 48, 64];
  static readonly RADII: number[] = [4, 8, 12, 16, 24];
  /** 0 表示「瞬时」:跟随手指的位移不该有动画 */
  static readonly MOTION_MS: number[] = [0, 100, 180, 280, 420];

  /** 页面外边距:手机 16 / 平板 24 / 大屏 32 */
  static pageInset(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 32;
    }
    return cls === DeviceClass.PAD ? 24 : 16;
  }

  /**
   * 左右外边距。与上下分开,因为矮屏要收窄的是**阅读列**,不是高度。
   *
   * 横屏手机有 791vp 宽,一行塞得下 100 个汉字 —— 那不是阅读,是刻度。
   * 所以矮屏把左右边距撑开,让内容列不超过 COMPACT_CONTENT_WIDTH(约 42 个汉字),
   * 多出来的宽度变成左右留白,内容居中。非矮屏时就是原来的页边距,一个数都不改。
   */
  static pageInsetX(widthVp: number, cls: DeviceClass, compact: boolean): number {
    const base = Layout.pageInset(cls);
    if (!compact) {
      return base;
    }
    const side = (widthVp - Layout.COMPACT_CONTENT_WIDTH) / 2;
    return side > base ? side : base;
  }

  /**
   * 上下外边距。矮屏收窄这一档,因为横屏手机的高度是稀缺资源:
   * 上下各 16vp 就是 32vp,差不多是一根滑杆的高度,而操作区正是横屏最挤的地方。
   */
  static pageInsetY(cls: DeviceClass, compact: boolean): number {
    if (!compact) {
      return Layout.pageInset(cls);
    }
    return 8;
  }

  static cardPadding(cls: DeviceClass): number {
    return cls === DeviceClass.PHONE ? 12 : 16;
  }

  /** 列表项间距。卡片密集时靠内边距而不是空隙拉开层次 */
  static listGap(cls: DeviceClass): number {
    return cls === DeviceClass.LARGE ? 12 : 8;
  }

  /** chip 高度等于触控下限,不留「看着能点其实点不准」的目标 */
  static chipHeight(cls: DeviceClass): number {
    return Layout.touchMin(cls);
  }

  /** 胶囊:圆角取半高,因此它刻意不落在 RADII 阶梯上 */
  static chipRadius(cls: DeviceClass): number {
    return Layout.chipHeight(cls) / 2;
  }

  /** 值是否落在间距阶梯上。把「别写魔法数」变成可断言的规则 */
  static onLadder(value: number): boolean {
    return Layout.SPACE.indexOf(value) >= 0;
  }

  /** 卡片圆角。大屏观看距离远,同一圆角看起来更锐,所以放大一档 */
  static cardRadius(cls: DeviceClass): number {
    return cls === DeviceClass.LARGE ? 16 : 12;
  }

  /**
   * 控件圆角:按钮、chip、学科标签。比卡片低一档,因为它们嵌在卡片里,
   * 同值会让"里"和"外"读起来是同一层。
   * 收敛前这里同时存在 8 / 9 / 10 三种值,而 9 和 10 都是动作按钮。
   */
  static controlRadius(cls: DeviceClass): number {
    return cls === DeviceClass.LARGE ? 12 : 8;
  }

  /** 学科色点。圆角一律取它的半高/半宽,所以只这里定尺寸 */
  static dotSize(): number {
    return 8;
  }

  /** 图例里的色标条:12 x 3,圆角是半高,不是又一个阶梯成员 */
  static tickWidth(): number {
    return 12;
  }

  static tickHeight(): number {
    return 3;
  }

  static onRadius(value: number): boolean {
    return Layout.RADII.indexOf(value) >= 0;
  }
}
