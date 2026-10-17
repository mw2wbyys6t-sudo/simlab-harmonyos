/** 学生填数比对的三种结局。0/1/2 是判据读的码,印给学生前必须过枚举标签表 */
export const ANSWER_OK: number = 0;
export const ANSWER_WRONG: number = 1;
export const ANSWER_MISSING: number = 2;

/** 一种典型错法算出来的数。id 由场景的 procedure 定,0 保留给"没命中" */
export class Fingerprint {
  id: number = 0;
  value: number = 0;
}

export class AnswerOutcome {
  code: number = ANSWER_MISSING;
  /** 有符号相对偏差 %;没填时为 NaN */
  relErr: number = Number.NaN;
  /** 命中的错法编号,0 表示只是算错、说不出错在哪 */
  wrongKind: number = 0;
}

/**
 * 把"学生填的数"与"这批数据按正确流程应得的结果"比一次。
 *
 * 纯函数,而且刻意不知道任何物理:场景的 procedure 负责算出 correct 与各种错法值,
 * 这里只做带宽比对。顺序写死 —— 先比正确值,再比指纹,否则一个恰好等于错法值的
 * 正确答案会被点名成犯了那个错。
 */
export class AnswerCheck {
  /** 认"就是这个错法"的带宽。比判分的容差紧得多:点名是断言,不是给分 */
  static readonly MATCH_TOL: number = 0.5;

  /**
   * correct 非有限 = 这道题在这批数据上根本出不来(段数切不满两半、点不够算比值)。
   * 此时返回 null 而不是某个码:调用方据此**一个事实都不写**,判据不响、不扣分。
   * "没交"与"没出题"是两件事,不能共用一个码。
   */
  static match(answer: number, correct: number, prints: Fingerprint[],
    tol: number): AnswerOutcome | null {
    if (!Number.isFinite(correct) || correct === 0) {
      return null;
    }
    const out = new AnswerOutcome();
    if (!Number.isFinite(answer)) {
      out.code = ANSWER_MISSING;
      return out;
    }
    out.relErr = (answer - correct) / Math.abs(correct) * 100;
    if (Math.abs(out.relErr) <= tol) {
      out.code = ANSWER_OK;
      return out;
    }
    out.code = ANSWER_WRONG;
    for (let i = 0; i < prints.length; i++) {
      const f = prints[i];
      if (!Number.isFinite(f.value) || f.value === 0) {
        continue;
      }
      if (Math.abs((answer - f.value) / Math.abs(f.value) * 100) <= AnswerCheck.MATCH_TOL) {
        out.wrongKind = f.id;
        return out;
      }
    }
    return out;
  }
}
