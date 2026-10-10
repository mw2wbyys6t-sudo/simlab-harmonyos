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

/**
 * 第二档深度:这条有没有把**易错处摆出来再驳掉**,而不是只写一句限制条件。
 *
 * 判点率只回答「有一句能判对错的话吗」—— 「必须考虑温度」也算过。可是学生错的地方
 * 往往是「以为 X 而其实是 Y」,所以这一档只认对照/驳误类的确凿写法(而不是、不等于、
 * 易把、常见误、看似、反例),不认裸的限制词(必须/只有/仅当/前提/适用)。
 * 词表刻意取 DISCRIMINATOR 的**子集**:对照若是判点的子集,就不会出现「这条有对照却被
 * 报成缺判点」的仪器互相打脸。同样是粗代理,只做读数、不做地板:方向上它只会低估
 * 「真写了对照」的条目(如「最常犯的错」这类自然写法仍会被漏计)。
 */
export const CONTRAST = /(而不是|不是|不等于|不同于|区别于|而非|误认|易把|易错|常见误|混淆|看似|恰恰|刚好|未必|一般不|通常不|反例|漏掉|漏了|不再)/;

export function hasContrast(text) {
  return CONTRAST.test(text);
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
