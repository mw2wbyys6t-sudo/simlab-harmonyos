/** 三档设备:手机、学生平板、教师大屏。断点取 ArkUI 常规阈值。 */
export enum DeviceClass {
  PHONE = 'phone',
  PAD = 'pad',
  LARGE = 'large'
}

export class Layout {
  static readonly PHONE_MAX: number = 600;
  static readonly PAD_MAX: number = 1100;

  static classify(widthVp: number): DeviceClass {
    if (widthVp < Layout.PHONE_MAX) {
      return DeviceClass.PHONE;
    }
    if (widthVp < Layout.PAD_MAX) {
      return DeviceClass.PAD;
    }
    return DeviceClass.LARGE;
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

  /** 量取页器皿画布高度:量筒要的是竖向空间 */
  static gaugeHeight(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 400;
    }
    return cls === DeviceClass.PAD ? 320 : 252;
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
    return cls === DeviceClass.PAD ? 176 : 140;
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

  /** 实验页图表区高度 */
  static chartAreaHeight(cls: DeviceClass): number {
    if (cls === DeviceClass.LARGE) {
      return 300;
    }
    return cls === DeviceClass.PAD ? 240 : 190;
  }

  /** 竖屏堆叠时图表宿主的高度;侧栏布局直接吃满高,不用这个值 */
  static stackedChartHeight(): number {
    return 300;
  }

  static isStacked(cls: DeviceClass): boolean {
    return cls === DeviceClass.PHONE;
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
