import { CriterionBuilder, CriterionOp, Rubric } from './Rubric';

/**
 * 「探究电流与电压、电阻的关系」参考细则(初中,配场景 `ohm-law`)。
 *
 * 这个实验的分不在"算对 I=U/R" —— 电路是求解器算的,学生算不出错。
 * 分在**控制变量有没有真做**:
 * ① 保持 R 不变、改 U 多取几档(否则画不出 I-U 图);
 * ② 换 R 之后把电压调回同一档(否则 I 与 R 的关系无从比较);
 * ③ 至少用过两种电阻(只有一种就得不出"与电阻的关系"这半段);
 * ④ 第一组读数前把滑片放在阻值最大处(操作规范,也是保护电表)。
 *
 * 四条读的都是学生按下的动作留下的后果,没有一条读我们施予的参数值本身。
 * 分值做成**能被满足的**:认真做满 ①②③ 应当一分不扣(harness 里有这条断言)。
 */
export class RubricOhm {
  static readonly SCENE: string = 'ohm-law';
  static readonly ID: string = 'ohm-law-rubric';
  static readonly VERSION: string = '2026.10';

  static create(): Rubric {
    const rubric = new Rubric();
    rubric.id = RubricOhm.ID;
    rubric.label = '探究电流与电压、电阻的关系 · 参考细则';
    rubric.source = '参考细则（非官方标准），依据人教版九年级「探究电流与电压、电阻的关系」课题的常见扣分点自建';
    rubric.version = RubricOhm.VERSION;
    rubric.totalPoints = 100;

    // 标题与证据是直接印给学生看的,标点一律全角
    const nothing = CriterionBuilder.numeric('ohm-no-record', '一组读数都没记录',
      CriterionOp.LT, 'ohmRecordCount', 1, 0, 40,
      '共记录 {ohmRecordCount} 组：这个实验的结论只能从多组 U、I 读数里看出来，一组都没有就无从判起');
    const fewSteps = CriterionBuilder.numeric('ohm-few-voltage-steps', '同一电阻下电压档数太少，画不出 I-U 图',
      CriterionOp.LT, 'ohmMaxPointsAtOneR', 3, 0, 20,
      '同一只定值电阻上最多只有 {ohmMaxPointsAtOneR} 档互不相同的电压读数，描一条过原点的直线至少需要 3 档');
    const oneR = CriterionBuilder.numeric('ohm-single-resistance', '只用了一种电阻，得不出 I 与 R 的关系',
      CriterionOp.LT, 'ohmResistances', 2, 0, 20,
      '测过的电阻共 {ohmResistances} 种：只有一种电阻，只能说明 I 与 U 的关系，说明不了 I 与 R 的关系');
    const notHeld = CriterionBuilder.numeric('ohm-no-held-voltage', '换电阻后没把电压调回同一档',
      CriterionOp.LT, 'ohmSharedVoltages', 1, 0, 12,
      '在同一个电压档上比较过的电阻种数：{ohmSharedVoltages}。换电阻后必须把滑片调回去，让两次读数处在同一电压下');
    // 16 Ω = 这只变阻器最大阻值(场景里 slide 参数上限 20)的八成。
    // 事实缺失(一组都没记)时判定层直接放过,不会伪报「读数时滑片在哪」
    const slideLow = CriterionBuilder.numeric('ohm-slide-not-max', '第一组读数前没把滑片放到阻值最大处',
      CriterionOp.LT, 'ohmFirstSlide', 16, 0, 8,
      '第一组读数时滑片停在 {ohmFirstSlide} Ω：限流接法要先把滑片放到最大处，让回路从最小电流起，保护电流表与电源');

    rubric.criteria.push(nothing);
    rubric.criteria.push(fewSteps);
    rubric.criteria.push(oneR);
    rubric.criteria.push(notHeld);
    rubric.criteria.push(slideLow);
    return rubric;
  }
}
