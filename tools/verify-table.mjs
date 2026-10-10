/**
 * 单表体检:转译一张 map 表并报告结构不变性与判点率。
 *
 * 为什么要独立成一个脚本而不是给一行式 `node -e '...'`:
 * 一行式里的 `'"'"'` 转义在 Git Bash 下会把替换回调里的右括号吃掉,
 * 生成的 .cjs 报 `missing ) after argument list` —— 那是**仪器自己的错**,
 * 却长得像数据的语法错,极易被误读成"表写坏了"。2026-10-10 一个代理就是这么撞上的。
 * 落成文件就只剩参数,不再有引号嵌套。
 *
 * 用法:
 *   node tools/verify-table.mjs KnowledgePhysics
 *   node tools/verify-table.mjs KnowledgeElectronicsJunior --prefix kn-ele-jr-
 *   node tools/verify-table.mjs KnowledgeBiology --must-have-discriminator
 */
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import os from 'node:os';
import process from 'node:process';

const require = createRequire(import.meta.url);
const ts = require('F:/DevEco/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript');
const SRC = 'F:/DevEcoProjects/SimLab/entry/src/main/ets';

const args = process.argv.slice(2);
const cls = args[0];
if (!cls) {
  console.error('用法: node tools/verify-table.mjs <ClassName> [--prefix <id-前缀>] [--must-have-discriminator]');
  process.exit(2);
}
const prefixIdx = args.indexOf('--prefix');
const prefix = prefixIdx >= 0 ? args[prefixIdx + 1] : null;
const strict = args.includes('--must-have-discriminator');

import { DISCRIMINATOR } from './coverage-metrics.mjs';

const out = join(os.tmpdir(), 'simlab-verify-' + cls);
mkdirSync(join(out, 'content/map'), { recursive: true });

const mods = ['content/map/CurriculumTypes', 'content/map/KnowledgeTypes', 'content/map/MapValidator',
  'content/map/' + cls];
for (const name of mods) {
  const src = readFileSync(join(SRC, name + '.ets'), 'utf8');
  const res = ts.transpileModule(src, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 },
    reportDiagnostics: true,
    fileName: name + '.ts',
  });
  const diags = res.diagnostics || [];
  if (diags.length) {
    // 语法错在这里就地坐实,不留给 require 抛一个看着像数据错误的栈
    for (const d of diags.slice(0, 5)) {
      const p = d.file && d.start != null ? d.file.getLineAndCharacterOfPosition(d.start) : null;
      console.error(`语法错 ${name}.ets:${p ? p.line + 1 : '?'}:${p ? p.character + 1 : '?'}` +
        ` ${ts.flattenDiagnosticMessageText(d.messageText, ' ')}`);
    }
    process.exit(1);
  }
  // 相对 import 不带扩展名,补 .cjs 才能被 node 解析。
  // 用回调而不是 '$1.cjs' 替换串:后者里的 $ 与引号在 shell 一行式里极易被吃掉,
  // 这个脚本存在的理由就是不再依赖那种写法。
  writeFileSync(join(out, name + '.cjs'),
    res.outputText.replace(/require\("(\.[^"]*)"\)/g, (m, p1) => `require("${p1}.cjs")`));
}

const { MapValidator } = require(join(out, 'content/map/MapValidator.cjs'));
const rows = require(join(out, 'content/map/' + cls + '.cjs'))[cls].all();

const usePrefix = prefix || (rows[0] ? rows[0].id.replace(/-\d+$/, '-') : null);
const nums = rows.map((r) => Number(r.id.slice(usePrefix.length)));
const byChapter = new Map();
for (const r of rows) byChapter.set(r.chapter, (byChapter.get(r.chapter) || 0) + 1);
const lone = [...byChapter.values()].filter((c) => c === 1).length;
const pos = new Map(rows.map((r, i) => [r.id, i]));
const prereqBad = rows.flatMap((r, i) => r.prerequisites
  .filter((p) => { const q = pos.get(p); return q === undefined || q >= i; })
  .map((p) => `${r.id}->${p}`));
const noDisc = rows.filter((r) => !DISCRIMINATOR.test(r.statement));
const titles = new Map();
for (const r of rows) titles.set(r.title, (titles.get(r.title) || 0) + 1);
const dupTitles = [...titles].filter(([, n]) => n > 1);

console.log(`${cls}  条数=${rows.length}  id前缀=${usePrefix}  id连续=${nums.every((x, i) => x === i + 1)}`);
console.log(`  章=${byChapter.size}  条/章=${(rows.length / byChapter.size).toFixed(2)}  独苗率=${Math.round(lone / byChapter.size * 100)}%`);
console.log(`  判点率=${Math.round((rows.length - noDisc.length) / rows.length * 100)}%  缺判点=${noDisc.length}`);
console.log(`  平均字数=${Math.round(rows.reduce((a, r) => a + r.statement.length, 0) / rows.length)}  verified=${rows.filter((r) => r.verified).length}`);
console.log(`  前置违规=${prereqBad.length}  校验问题=${MapValidator.validateKnowledge(rows).length}  表内重名=${dupTitles.length}`);
if (prereqBad.length) console.log('  违规: ' + prereqBad.slice(0, 8).join(', '));
if (noDisc.length && !strict) console.log('  缺判点条目: ' + noDisc.slice(0, 12).map((r) => r.id).join(', '));

if (strict && noDisc.length) {
  console.error(`\n--must-have-discriminator 要求每条都带判点,仍缺 ${noDisc.length} 条`);
  process.exit(1);
}
if (prereqBad.length || dupTitles.length) process.exit(1);
