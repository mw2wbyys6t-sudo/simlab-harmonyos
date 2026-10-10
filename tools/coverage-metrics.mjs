/**
 * 覆盖度刻度的单一定义处。
 *
 * 为什么单独一个文件而不是各脚本各写一份正则:判点率同时被三个地方用
 * (coverage-probe 报数、verify-table 单表体检、physics-check 的地板断言)。
 * 三份拷贝迟早会漂,一漂「探针说 100% 而断言说没达标」就变成仪器互相打脸,
 * 排查起来比改代码还费时间。
 *
 * 词表是**粗代理**,不做语义分析:
 *  - 漏判:「最常犯的错」这类自然写法不在词表内,会被报成缺判点;
 *  - 误判:松到单字「误」「易」会把「误差」「简易」当判点,方向性地低估缺失。
 * 两向都试过,取确凿短语这一版。输出的「缺判点」是**值得人工再看一眼**的线索,不是自动定罪。
 */

/** statement 里是否含一个能判对错的分界(易错处/适用条件/概念分界/反例)。 */
export const DISCRIMINATOR = /(不等于|不是|不同于|区别于|而不是|而非|不能|不可|必须|只有|只在|仅当|仅仅|前提|适用|条件是|因此只有|注意|未必|不再|区别在于|反例|成立|易错|易把|误认|错误|常见误|漏掉|漏了|恰恰|刚好|一般不|通常不|看似|混淆)/;

export function hasDiscriminator(text) {
  return DISCRIMINATOR.test(text);
}

/** 一条 statement 里可判对错的分句数(按分号粗切,不做语义分析)。 */
export function clauses(text) {
  return text.split(/[;；]/).filter((s) => s.trim().length > 6).length;
}

/** 判点率(%),四舍五入到整数。 */
export function discriminatorRate(rows) {
  if (rows.length === 0) return 0;
  return Math.round(rows.filter((r) => hasDiscriminator(r.statement)).length / rows.length * 100);
}
