/**
 * 教学演示标定值。
 *
 * 这一层是本设计里**已知不精确**的部分:滤纸截留率、蒸发速率、沉降速率都没有实测依据,
 * 只取「数量级与单调行为正确」的值。所以离线断言只测守恒与单调性,绝不声称绝对数值真实。
 * 全部系数集中在此,便于将来用实测数据或细则覆盖 —— 不允许散落到各处计算里。
 */
export class Calibration {
  static readonly WATER_DENSITY: number = 1.0;
  /** NaCl 在 20 ℃ 的溶解度约 36 g/100 mL */
  static readonly NACL_SOLUBILITY: number = 0.36;
  /** 搅拌下每秒可溶解的 NaCl(g) */
  static readonly DISSOLVE_RATE: number = 0.08;
  /** 不搅拌时的溶解速率打折 */
  static readonly DISSOLVE_QUIET: number = 0.35;
  /** 悬浮泥沙每秒沉降比例 */
  static readonly SETTLE_RATE: number = 0.12;
  /** 单位表面积单位时间蒸发的水(mL/(s·cm²)),需处于加热中 */
  static readonly EVAPORATE_RATE: number = 0.004;
  /** 液稀且持续加热时视为易飞溅 */
  static readonly SPLASH_MAX_WATER: number = 1.5;
  /** 未搅拌时每秒溅出的 NaCl(g) */
  static readonly SPLASH_SALT_RATE: number = 0.01;
  /** 未搅拌时每秒溅出的水(mL) */
  static readonly SPLASH_WATER_RATE: number = 0.03;
  /** 浊度换算:每 mL 液体含 1 g 悬浮泥沙记为 1000 NTU */
  static readonly TURBIDITY_SCALE: number = 1000;
  /** 判定「滤液合格」的浊度上限(参考细则用,非官方标准) */
  static readonly TURBIDITY_PASS: number = 20;

  /** 倾倒:瓶身仰角超过此值(度)才开始有液流 */
  static readonly POUR_ONSET_DEG: number = 12;
  /**
   * 粉末取用:每厘米自由下落路程沾在壁上的质量占比。
   *
   * 教学演示标定值(R2 同类),没有实测依据。可信的是**单调关系**:
   * 送得越深、容器越接近横放,沾壁越少。
   */
  static readonly POWDER_STICK_PER_CM: number = 0.06;
  /** 粉末取用:每厘米下落路程撒落在容器外的占比 */
  static readonly POWDER_SPILL_PER_CM: number = 0.02;
  /** 撒落占比上限。再高的下落也不该把半份样品撒掉 */
  static readonly POWDER_SPILL_MAX: number = 0.5;
  /**
   * 滴加:落差超过此值(cm)液滴冲击才开始飞溅。
   *
   * 规范动作是「垂直悬空在容器口上方约 0.5–1 cm」,连容器口到液面的深度一起算,
   * 落差仍在阈值以内,所以规范滴加必须精确地不损失任何一滴 —— 否则「失误」没有对照基线。
   * 以下四个系数都是教学演示标定值(R2 同类),可信的是守恒与单调关系。
   */
  static readonly DROP_SPLASH_ONSET_CM: number = 3;
  /** 滴加:超出阈值的落差每厘米溅出的占比 */
  static readonly DROP_SPLASH_PER_CM: number = 0.02;
  /** 滴加:溅出占比上限 */
  static readonly DROP_SPLASH_MAX: number = 0.25;
  /** 滴加:尖端伸入容器后每厘米挂在器壁上的占比 */
  static readonly DROP_STICK_PER_CM: number = 0.03;
  /** 滴加:尖端接触内壁额外挂住的占比 */
  static readonly DROP_STICK_WALL: number = 0.02;
  /** 滴加:伸入每厘米,尖端从容器里带出的液体(mL) —— 交叉污染的量 */
  static readonly DROP_CARRY_PER_CM: number = 0.05;
  /** 滴加:接触内壁一次带出的液体(mL) */
  static readonly DROP_CARRY_CONTACT: number = 0.04;
  /** 滴加:胶头朝下时倒流进胶头的占比(腐蚀胶头 + 试剂被橡胶污染) */
  static readonly DROP_REFLUX_FRACTION: number = 0.15;
  /**
   * 块状固体:落差超过此值(cm)才开始损伤器底。
   *
   * 「一横二放三慢竖」的正确做法让块体沿壁滑下,竖直落差只有一个管半径,远在阈值之内;
   * 直立着从管口丢下则是整个管长。以下系数为教学演示标定值(R2 同类),
   * 可信的是守恒与单调关系,不声称与真实玻璃抗冲击强度相符。
   */
  static readonly CHUNK_BREAK_ONSET_CM: number = 4;
  /** 块状固体:超出阈值的落差每厘米造成的管底损伤占比 */
  static readonly CHUNK_BREAK_PER_CM: number = 0.08;
  /** 块状固体:完全直立时撞挂在壁上的占比(按 sin 倾角缩放) */
  static readonly CHUNK_STICK_FRACTION: number = 0.12;
  /** 块状固体:砸击后崩出容器的占比,随超出阈值的落差增长 */
  static readonly CHUNK_ESCAPE_PER_CM: number = 0.01;
  /** 崩出占比上限 */
  static readonly CHUNK_ESCAPE_MAX: number = 0.2;
  /** 滤纸每秒可透过的液体体积(mL)。取 0.35 是为了让「倒太猛」真的会积溢:
   *  透过滤纸比倾倒慢是这个实验的物理前提,滤液来不及走才会涨过滤纸边缘 */
  static readonly FILTER_DRAIN_RATE: number = 0.35;
  /** 满仰角、1 cm 液柱下的流量(mL/s)。乘 √液柱高近似托里拆利,体现「液越多流越快」 */
  static readonly POUR_COEFF: number = 1.6;
  /** 用玻璃棒引流时的溅失比例 */
  static readonly GUIDED_SPILL: number = 0.005;
  /** 不用玻璃棒、直接对倒的溅失比例 —— 「引流」这条扣分点的物理后果 */
  static readonly UNGUIDED_SPILL: number = 0.09;
  /** 引流/粗暴倾倒对沉底泥沙的扰动比例 */
  static readonly GUIDED_DISTURB: number = 0.01;
  static readonly UNGUIDED_DISTURB: number = 0.18;
  /** 俯视/仰视读量筒时的视差系数(与量筒粗细和眼距相关,取演示值) */
  static readonly PARALLAX_RATIO: number = 0.22;
  /**
   * 空间关系容差(cm):"紧靠""抵住""对准口部"在真实实验室里本来就允许几毫米偏差。
   * 用像素对齐当判据会把正确操作判成错误,这是不可接受的误判来源之一。
   */
  /** 接触类判据用容差(mm 级)而非像素对齐 */
  static readonly CONTACT_TOLERANCE_CM: number = 0.25;
  /** 倾倒时源容器口需对准目标口部的最大偏移(cm),超出即洒在桌面上 */
  static readonly AIM_TOLERANCE_CM: number = 1.2;
}

/**
 * 已离开体系的质量。单独记账是守恒断言 I1 能成立的前提。
 *
 * 分成「蒸发」与「溅失」两类:前者是实验目的(把水赶走拿到盐),
 * 后者是操作失误(洒在桌面上)。诊断报告必须能区分这两笔账,
 * 否则「产率低」就说不清是蒸过了头还是倒得太猛。
 */
export class Losses {
  evaporatedWaterMl: number = 0;
  spilledWaterMl: number = 0;
  spilledSaltG: number = 0;
  spilledSandG: number = 0;
  /**
   * 从破损处漏走的部分。第三笔账,不并进溅失:
   * 报告要能分清「产率低是因为砸破了底」还是「因为倒得太猛」,两笔混记就永远说不清。
   */
  leakedWaterMl: number = 0;
  leakedSaltG: number = 0;
  leakedSandG: number = 0;

  addEvaporated(waterMl: number): void {
    this.evaporatedWaterMl += waterMl;
  }

  /** 蒸发之外被溅出的部分 */
  addSpilled(waterMl: number, saltG: number, sandG: number): void {
    this.spilledWaterMl += waterMl;
    this.spilledSaltG += saltG;
    this.spilledSandG += sandG;
  }

  /** 器底破损漏走的部分 */
  addLeaked(waterMl: number, saltG: number, sandG: number): void {
    this.leakedWaterMl += waterMl;
    this.leakedSaltG += saltG;
    this.leakedSandG += sandG;
  }

  /** 溅失合计(不含蒸发与漏失),用于「操作是否规范」的证据 */
  spillMass(): number {
    return this.spilledWaterMl * Calibration.WATER_DENSITY + this.spilledSaltG + this.spilledSandG;
  }

  /** 漏失合计,用于「容器是否被砸坏」的证据 */
  leakMass(): number {
    return this.leakedWaterMl * Calibration.WATER_DENSITY + this.leakedSaltG + this.leakedSandG;
  }

  mass(): number {
    return (this.evaporatedWaterMl + this.spilledWaterMl + this.leakedWaterMl)
      * Calibration.WATER_DENSITY + this.spilledSaltG + this.spilledSandG
      + this.leakedSaltG + this.leakedSandG;
  }
}

/**
 * 一份粗盐混合物的物质账本。
 *
 * 七个存量互斥且完备:水、已溶 NaCl、未溶 NaCl、沾壁盐、沾壁砂、悬浮泥沙、沉底泥沙。
 * 任何操作只能在这五项之间搬运,或搬进 `Losses`,不许凭空产生或消失 ——
 * 这是断言 I1(现存 + 逸出 + 损失 = 初始)的检查点。
 *
 * 忽略溶质引起的体积变化(水体积即液体积),该简化已记入标定说明。
 */
export class Brine {
  waterMl: number = 0;
  saltDissolvedG: number = 0;
  saltSolidG: number = 0;
  /**
   * 沾在容器口与内壁上的固体。
   *
   * 单独一项而不是并进 `saltSolidG`,是因为它**不参与溶解** —— 粉末取用时送不到底,
   * 那部分盐就退出了这一轮的产率。合并进去等于把操作失误从账本上抹掉。
   */
  saltStuckG: number = 0;
  /** 沾壁的砂。与盐对称:同一份粉末里谁沾壁不取决于它是盐还是砂,取决于送得够不够深 */
  sandStuckG: number = 0;
  sandSuspendedG: number = 0;
  sandSettledG: number = 0;
  losses: Losses = new Losses();

  liquidMl(): number {
    return this.waterMl;
  }

  /** 体系内现存总质量(不含损失) */
  mass(): number {
    return this.waterMl * Calibration.WATER_DENSITY + this.saltDissolvedG + this.saltSolidG
      + this.saltStuckG + this.sandStuckG + this.sandSuspendedG + this.sandSettledG;
  }

  /** 含损失的总质量,应当恒等于加入量 —— 守恒断言用它 */
  totalAccounted(): number {
    return this.mass() + this.losses.mass();
  }

  /** 已溶 NaCl 的浓度(g/mL)。无液体时为 0 */
  concentration(): number {
    return this.waterMl <= 0 ? 0 : this.saltDissolvedG / this.waterMl;
  }

  /** 饱和所能溶解的上限 */
  saturationCapacity(): number {
    return this.waterMl * Calibration.NACL_SOLUBILITY;
  }

  /**
   * 浊度(NTU):单位液体里悬浮着多少泥沙。
   * 这是判定的关键量 —— 「滤液浑浊」不是一句提示文字,而是一个可测量的数。
   */
  turbidity(): number {
    if (this.waterMl <= 0) {
      return this.sandSuspendedG > 0 ? Calibration.TURBIDITY_SCALE : 0;
    }
    return this.sandSuspendedG / this.waterMl * Calibration.TURBIDITY_SCALE;
  }

  isEmpty(): boolean {
    return this.mass() <= 1e-9;
  }
}

/** 分离原语。每个方法只搬运质量,不做任何教学判定。 */
export class Separations {
  static addCrudeSalt(target: Brine, saltG: number, sandG: number): void {
    target.saltSolidG += saltG;
    target.sandSettledG += sandG;
  }

  static addWater(target: Brine, waterMl: number): void {
    const amount = waterMl < 0 ? 0 : waterMl;
    target.waterMl += amount;
  }

  /** 把 source 中已溶解的溶质与悬浮物并入 target(同一容器内的转移) */
  static dissolve(target: Brine, dt: number, stirred: boolean): void {
    const capacity = target.saturationCapacity() - target.saltDissolvedG;
    if (capacity <= 0 || target.saltSolidG <= 0) {
      Separations.stirSand(target, dt, stirred);
      return;
    }
    const rate = Calibration.DISSOLVE_RATE * (stirred ? 1 : Calibration.DISSOLVE_QUIET);
    const moved = Math.min(capacity, target.saltSolidG, rate * dt);
    target.saltDissolvedG += moved;
    target.saltSolidG -= moved;
    Separations.stirSand(target, dt, stirred);
  }

  /** 搅拌会把沉底泥沙重新扬起;静置则让悬浮泥沙沉降 */
  static stirSand(target: Brine, dt: number, stirred: boolean): void {
    if (stirred) {
      const risen = Math.min(target.sandSettledG, target.sandSettledG * Calibration.SETTLE_RATE * dt * 2);
      target.sandSettledG -= risen;
      target.sandSuspendedG += risen;
      return;
    }
    Separations.settle(target, dt);
  }

  static settle(target: Brine, dt: number): void {
    const fallen = target.sandSuspendedG * Math.min(1, Calibration.SETTLE_RATE * dt);
    target.sandSuspendedG -= fallen;
    target.sandSettledG += fallen;
  }

  /**
   * 倾倒:转移 liquidMl 的液体及其携带的溶质与悬浮物。
   * `disturbedSandRatio` 表示沉底泥沙被晃起来跟着走的比例(倒得粗暴就高)。
   * 返回实际转移的液体体积 —— requested 超过存量时只搬得走这么多。
   */
  static pour(source: Brine, target: Brine, requestedMl: number,
    disturbedSandRatio: number): number {
    const moved = Math.min(requestedMl, source.waterMl);
    if (moved <= 0) {
      return 0;
    }
    const fraction = moved / source.waterMl;

    source.waterMl -= moved;
    target.waterMl += moved;

    const salt = source.saltDissolvedG * fraction;
    source.saltDissolvedG -= salt;
    target.saltDissolvedG += salt;

    const suspended = source.sandSuspendedG * fraction;
    source.sandSuspendedG -= suspended;
    target.sandSuspendedG += suspended;

    const dragged = source.sandSettledG * Math.min(1, Math.max(0, disturbedSandRatio)) * fraction;
    source.sandSettledG -= dragged;
    target.sandSettledG += dragged;

    return moved;
  }

  /**
   * 过滤:液体与已溶 NaCl 透过滤纸,截留悬浮与沉底泥沙。
   * `sandCarryFraction` 是悬浮泥沙的穿透比例 —— 正常滤纸为 0,
   * 「液面高过滤纸边缘、混合液从间隙直灌」时由几何层传一个大于 0 的值进来。
   * 于是滤液浊度是算出来的,不是被标记出来的。
   */
  static filter(source: Brine, filtrate: Brine, requestedMl: number,
    sandCarryFraction: number): number {
    const moved = Math.min(requestedMl, source.waterMl);
    if (moved <= 0) {
      return 0;
    }
    const fraction = moved / source.waterMl;

    source.waterMl -= moved;
    filtrate.waterMl += moved;

    const salt = source.saltDissolvedG * fraction;
    source.saltDissolvedG -= salt;
    filtrate.saltDissolvedG += salt;

    const carry = Math.min(1, Math.max(0, sandCarryFraction));
    const passed = source.sandSuspendedG * fraction * carry;
    source.sandSuspendedG -= passed;
    filtrate.sandSuspendedG += passed;

    return moved;
  }

  /**
   * 蒸发。水离开体系计入损失;未搅拌且液体已少时,NaCl 与水一起飞溅出来 ——
   * 这就是产率损失的来源,也是「必须用玻璃棒搅拌」这条扣分点的物理依据。
   *
   * 水量下降后饱和容量随之下降,多出来的溶质必须析出为晶体(`crystallize`)。
   * 少了这一步,「蒸干得到精盐」这个最终产物根本不会存在。
   *
   * @param surfaceArea 液面表面积(cm²),决定蒸发快慢,来自容器几何
   */
  static evaporate(target: Brine, dt: number, surfaceArea: number,
    stirred: boolean): void {
    if (target.waterMl <= 0) {
      Separations.crystallize(target);
      return;
    }
    const evaporated = Math.min(target.waterMl,
      Calibration.EVAPORATE_RATE * surfaceArea * dt);
    target.waterMl -= evaporated;
    target.losses.addEvaporated(evaporated);

    if (!stirred && target.waterMl < Calibration.SPLASH_MAX_WATER) {
      const splashWater = Math.min(target.waterMl, Calibration.SPLASH_WATER_RATE * dt);
      target.waterMl -= splashWater;
      const splashSalt = Math.min(target.saltDissolvedG + target.saltSolidG,
        Calibration.SPLASH_SALT_RATE * dt);
      // 先从溶液中溅,不足再溅未溶的
      const fromDissolved = Math.min(target.saltDissolvedG, splashSalt);
      target.saltDissolvedG -= fromDissolved;
      target.saltSolidG -= (splashSalt - fromDissolved);
      target.losses.addSpilled(splashWater, splashSalt, 0);
    }
    Separations.crystallize(target);
  }

  /**
   * 结晶:已溶量超过当前水量的饱和容量时,超出部分析为固体。
   * 只在液量减少后需要调用(倾倒与过滤按比例搬运,不会改变浓度,故无需触发)。
   */
  static crystallize(target: Brine): void {
    const excess = target.saltDissolvedG - target.saturationCapacity();
    if (excess <= 0) {
      return;
    }
    target.saltDissolvedG -= excess;
    target.saltSolidG += excess;
  }

  /**
   * 从体系中取走一部分液体并计入溅失(洒在桌面上、或超出容器容量漫出来)。
   * 按比例带走已溶 NaCl 与悬浮泥沙,沉底泥沙不参与 —— 溅的是液滴,不是沉渣。
   * 记进 `losses` 而不是直接删掉,是守恒断言 I1 成立的前提。
   */
  static withdraw(target: Brine, volumeMl: number): number {
    const taken = Math.min(volumeMl, target.waterMl);
    if (taken <= 0) {
      return 0;
    }
    const fraction = taken / target.waterMl;
    const salt = target.saltDissolvedG * fraction;
    const sand = target.sandSuspendedG * fraction;
    target.waterMl -= taken;
    target.saltDissolvedG -= salt;
    target.sandSuspendedG -= sand;
    target.losses.addSpilled(taken, salt, sand);
    return taken;
  }

  /**
   * 器底破损:按比例把**可流动**的内容物漏出去,返回漏走的质量(g)。
   *
   * 沾在器壁与容器口上的 `saltStuckG` / `sandStuckG` 不参与 —— 它们在裂缝上方,
   * 不会顺着外壁流进裂缝。把它们一起漏走,「沾壁」这个后果就被漏失冲淡了,
   * 两条失误在账上再也分不开。
   */
  static leak(target: Brine, fraction: number): number {
    const f = Math.min(1, Math.max(0, fraction));
    if (f <= 0) {
      return 0;
    }
    const water = target.waterMl * f;
    const salt = (target.saltDissolvedG + target.saltSolidG) * f;
    const sand = (target.sandSuspendedG + target.sandSettledG) * f;
    target.waterMl -= water;
    target.saltDissolvedG -= target.saltDissolvedG * f;
    target.saltSolidG -= target.saltSolidG * f;
    target.sandSuspendedG -= target.sandSuspendedG * f;
    target.sandSettledG -= target.sandSettledG * f;
    target.losses.addLeaked(water, salt, sand);
    return water * Calibration.WATER_DENSITY + salt + sand;
  }

  /** 汇总一组账本的现存质量与已损失质量,供守恒断言使用 */
  static totalMass(items: Brine[]): number {
    let sum = 0;
    for (let i = 0; i < items.length; i++) {
      sum += items[i].mass();
    }
    return sum;
  }

  static totalLosses(items: Brine[]): number {
    let sum = 0;
    for (let i = 0; i < items.length; i++) {
      sum += items[i].losses.mass();
    }
    return sum;
  }
}
