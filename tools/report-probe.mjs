/** 从 dumpLayout 的 JSON 里把报告页的关键读数抽出来,便于机械比对而不是靠肉眼。 */
import { readFileSync } from 'node:fs';

const d = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const texts = [];
(function walk(n) {
  if (!n) { return; }
  const a = n.attributes || {};
  if (a.bounds && a.type === 'Text') {
    const m = /\[(\d+),(\d+)\]/.exec(a.bounds);
    texts.push({ text: a.text || '', y: m ? Number(m[2]) : -1 });
  }
  (n.children || []).forEach(walk);
})(d.root || d);

const byLabel = (label) => {
  for (let i = 0; i < texts.length; i++) {
    if (texts[i].text === label) {
      for (let j = i + 1; j < texts.length; j++) {
        if (Math.abs(texts[j].y - texts[i].y) < 40 && texts[j].text !== label) {
          return texts[j].text;
        }
      }
    }
  }
  return '(缺)';
};
const find = (re) => (texts.find((t) => re.test(t.text)) || { text: '(缺)' }).text;

console.log(JSON.stringify({
  shown: find(/你的操作|规范示例/),
  evidence: find(/^证据:/),
  实际量取: byLabel('实际量取'),
  倾倒洒失: byLabel('倾倒洒失'),
  倾倒仰角: byLabel('倾倒仰角'),
  时序: texts.filter((t) => /于第 .* s$/.test(t.text)).map((t) => t.text).join(' | ') || find(/没有分步时刻/)
}, null, 1));
