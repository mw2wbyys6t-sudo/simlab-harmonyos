import { CriterionBuilder, CriterionOp, Rubric } from './Rubric';

/**
 * 「探究加速度与物体受力、物体质量的关系」参考细则(高中必修一,配场景 `newton-second-cart`)。
 *
 * 这条实验的分在**有没有把两件事分开做**:一是控制变量 —— 一次只动一个东西,
 * 二是平衡摩擦 —— 挂桶之前先取下桶轻推一次,看纸带上的点均不均匀。
 * 五条判据读的都是学生自己按出来的动作留下的后果:
 * ① 有几组纸带真能量出 a;② 同一辆车上换过几档拉力;③ 同一档拉力下试过几种质量;
 * ④ 做没做那次空载轻推;⑤ 那次轻推的纸带匀不匀。
 *
 * 垫块层数本身不扣分:我们施给它的值不能当学生的选择来判,判的是它造成的后果。
 * a 等于多少、a-F 图在高力端为什么往下弯、a-1/M 怎么化曲为直 —— 这些要学生把
 * 量到的数交进来才判得了(#61 学生填数入口),现在一律不写进细则:宁漏不误。
 *
 * 分值做成**能被满足的**:两层垫块、取下桶轻推一次、六组纸带各切得出六段,
 * 一分不扣(harness 里有这条断言)。
 */
export class RubricNewton {
  /** 这份细则配哪个场景注册表 id,由细则自己声明 */
  static readonly SCENE: string = 'newton-second-cart';
  static readonly ID: string = 'newton-second-rubric';
  static readonly VERSION: string = '2026.10';

  static create(): Rubric {
    const rubric = new Rubric();
    rubric.id = RubricNewton.ID;
    rubric.label = '探究加速度与物体受力、物体质量的关系 · 参考细则';
    rubric.source = '参考细则（非官方标准），依据人教版必修一「探究加速度与物体受力、物体质量的关系」课题的常见扣分点自建';
    rubric.version = RubricNewton.VERSION;
    rubric.totalPoints = 100;

    // 标题与证据是直接印给学生看的，标点一律全角
    const fewRecords = CriterionBuilder.numeric('n2-records-few', '能算出加速度的组数太少，看不出关系',
      CriterionOp.LT, 'n2UsableCount', 6, 0, 20,
      '记了 {n2RecordCount} 组，其中纸带够切出六段、算得出 a 的只有 {n2UsableCount} 组：两条关系各要三组以上才谈得上「随……怎么变」');
    const fewForces = CriterionBuilder.numeric('n2-force-steps-few', '同一辆车上没换过几档拉力',
      CriterionOp.LT, 'n2ForceSteps', 3, 0, 20,
      '同一质量下最多只换过 {n2ForceSteps} 档砝码桶：控制小车质量不变、只改拉力那一半没做出来，a-F 图画不成');
    const fewMasses = CriterionBuilder.numeric('n2-mass-steps-few', '同一档拉力下没试过几种质量',
      CriterionOp.LT, 'n2MassSteps', 3, 0, 20,
      '同一拉力下最多只试过 {n2MassSteps} 种小车质量：控制拉力不变、只改质量那一半没做出来，a-M 图画不成');
    const noCheck = CriterionBuilder.numeric('n2-no-friction-check', '没做那次空载轻推，摩擦抵没抵住不知道',
      CriterionOp.LT, 'n2ChecksDone', 1, 0, 20,
      '取下砝码桶之后轻推小车、看纸带点距这一步做了 {n2ChecksDone} 次：板面摩擦还挂在式子里，后面测到的 a 就不是绳的拉力单独造成的');
    const notUniform = CriterionBuilder.numeric('n2-idle-not-uniform', '轻推那次点距不匀，摩擦力没被抵消',
      CriterionOp.GT, 'n2IdleSpreadMm', 0.4, 0, 20,
      '最近一次空载轻推的纸带上，用到的几段计数段最长与最短差 {n2IdleSpreadMm} mm：匀速才说明板端抬的分量刚好抵住摩擦 —— 越打越密是抬得不够，越打越疏是抬过了');

    rubric.criteria.push(fewRecords);
    rubric.criteria.push(fewForces);
    rubric.criteria.push(fewMasses);
    rubric.criteria.push(noCheck);
    rubric.criteria.push(notUniform);
    return rubric;
  }
}
