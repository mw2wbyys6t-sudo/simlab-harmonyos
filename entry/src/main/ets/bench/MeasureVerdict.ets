/**
 * 量取任务的判词。
 *
 * 从 `MeasurePage` 里搬出来,原因有两条:
 * ① 页面里的句子离线测不到,而它出过一次自相矛盾 —— 同一句里既说「正好到目标量」
 *    又说「实际倒多了」(spec 8.26 的 F5)。搬成纯函数之后那条矛盾变成会红的断言。
 * ② 判词是**结论**,结论只能由判据与观测量算出,不该散在渲染代码里。
 *
 * 一句话的分工是这里唯一的规矩:
 * - 「多倒了 / 少倒了 / 正好」只由 `error`(实际与目标之差)决定;
 * - 「读数偏小 / 偏大」只由 `eyeOffset`(视线与液面之差)决定;
 * - 因果链只在两者方向确实对上时才补那半句。
 * 两个各说各的维度,才不会互相打脸。
 */
export class MeasureVerdict {
  /** |error| 小于它就是"正好",不印 0.00 这种假精度 */
  private static readonly EXACT: number = 0.005;
  /** 视线偏差小于这个值就按齐平处理,不硬套视差 */
  private static readonly LEVEL: number = 0.2;

  static of(actual: number, apparent: number, error: number, eyeOffset: number, spilledMl: number): string {
    let signed: string = '正好到目标量';
    if (Math.abs(error) >= MeasureVerdict.EXACT) {
      signed = error > 0 ? `多倒了 ${error.toFixed(2)} mL` : `少倒了 ${(-error).toFixed(2)} mL`;
    }

    let cause: string = '视线与凹液面齐平，读数可信';
    if (eyeOffset < -MeasureVerdict.LEVEL) {
      cause = '仰视（眼睛低于液面）→ 读数偏小';
      if (error > MeasureVerdict.EXACT) {
        cause += '，这就是多倒的原因';
      }
    } else if (eyeOffset > MeasureVerdict.LEVEL) {
      cause = '俯视（眼睛高于液面）→ 读数偏大';
      if (error < -MeasureVerdict.EXACT) {
        cause += '，这就是少倒的原因';
      }
    }

    const head = `实际 ${actual.toFixed(2)} mL，读数 ${apparent.toFixed(2)} mL；${signed}。${cause}`;
    return spilledMl > 0.01 ? `${head}；另有 ${spilledMl.toFixed(2)} mL 溅失。` : `${head}。`;
  }
}
