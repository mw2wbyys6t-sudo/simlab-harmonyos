/**
 * 覆盖度探针:量课程地图现在到底有多「多 / 广 / 细 / 深」。
 *
 * 为什么需要它:「点越多越广越好且越细越好」是一句没有刻度的话。不先把它变成能区分的数,
 * 加完 200 条也不知道是补住了空洞还是把已经很厚的格更堆厚了。
 *
 * 四个刻度分别对准:
 *   多 —— 每个 学科×学段 格子的知识条数
 *   广 —— 该格子铺开了多少个 chapter(单元/章),以及有没有整块没碰
 *   细 —— 平均每条章被拆成几条 + 「独苗章」占比(只有一条的章 = 那一块还没拆开)
 *   深 —— statement 字数、判据符号数、前置密度、TRANSFER 占比(迁移层级才是深度)
 *
 * 负对照(必带):把一份故意做薄的表喂进去,探针必须给出显著更低的分。
 * 没有这一步,「471 条」这种数字可能只是脚本自己在数自己的输出。
 *
 * 用法: node tools/coverage-probe.mjs
 */
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import os from 'node:os';

const require = createRequire(import.meta.url);
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const ts = require('F:/DevEco/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript');

const SRC = join(root, 'entry', 'src', 'main', 'ets');
const OUT = join(os.tmpdir(), 'simlab-coverage');
rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });

const MODULES = [
  'content/map/CurriculumTypes',
  'content/map/KnowledgeTypes',
  'content/map/KnowledgePhysics', 'content/map/KnowledgePhysicsJunior', 'content/map/KnowledgePhysicsSenior',
  'content/map/KnowledgeChemistry', 'content/map/KnowledgeChemistryJunior', 'content/map/KnowledgeChemistrySenior',
  'content/map/KnowledgeBiology', 'content/map/KnowledgeBiologyJunior', 'content/map/KnowledgeBiologySenior',
  'content/map/KnowledgeElectronics', 'content/map/KnowledgeElectronicsJunior',
  'content/map/KnowledgeElectronicsSenior', 'content/map/PeriodicTable',
  'content/map/SchoolPhysics', 'content/map/SchoolChemistry', 'content/map/SchoolBiology',
  'content/map/UniversityPhysics', 'content/map/UniversityChemistry', 'content/map/UniversityBiology',
  'content/map/UniversityElectronics',
  'content/map/MapValidator', 'content/map/CurriculumIndex',
];

for (const name of MODULES) {
  const source = readFileSync(join(SRC, name + '.ets'), 'utf8');
  const js = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 },
    fileName: name + '.ts'
  }).outputText;
  const target = join(OUT, name + '.cjs');
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, js.replace(/require\("(\.[^"]*)"\)/g, 'require("$1.cjs")'));
}

const { CurriculumIndex } = require(join(OUT, 'content/map/CurriculumIndex.cjs'));
const { KnowledgeLevel } = require(join(OUT, 'content/map/KnowledgeTypes.cjs'));

/** CurriculumIndex 没有 subjectName,探针自带一份显示名(不参与计算) */
const SUBJECT_NAME = { physics: '物理', chemistry: '化学', biology: '生物', electronics: '电子学' };
const subjectName = (s) => SUBJECT_NAME[s] || s;

/**
 * 刻度(clauses / hasDiscriminator)一律从 coverage-metrics.mjs 取,本文件不自带一份。
 * 探针、单表体检、地板断言必须用同一把尺子,否则「探针说达标而断言说没有」会退化成查仪器。
 */
import { clauses, hasDiscriminator } from './coverage-metrics.mjs';

function score(rows) {
  const n = rows.length;
  if (n === 0) return { n: 0, chapters: 0, perChapter: 0, loneRatio: 0, chars: 0, symbols: 0, prereq: 0, transfer: 0, clauses: 0, disc: 0 };
  const byChapter = new Map();
  for (const e of rows) byChapter.set(e.chapter, (byChapter.get(e.chapter) || 0) + 1);
  const chapters = byChapter.size;
  const lone = [...byChapter.values()].filter((c) => c === 1).length;
  const chars = rows.reduce((a, e) => a + e.statement.length, 0) / n;
  const symbols = rows.reduce((a, e) => a + e.symbols.length, 0) / n;
  const prereq = rows.reduce((a, e) => a + e.prerequisites.length, 0) / n;
  const transfer = rows.filter((e) => e.level === KnowledgeLevel.TRANSFER).length / n;
  const cl = rows.reduce((a, e) => a + clauses(e.statement), 0) / n;
  const disc = rows.filter((e) => hasDiscriminator(e.statement)).length / n;
  return {
    n, chapters,
    perChapter: n / chapters,
    loneRatio: lone / chapters,
    chars: Math.round(chars),
    symbols: +symbols.toFixed(2),
    prereq: +prereq.toFixed(2),
    transfer: +((transfer) * 100).toFixed(0),
    clauses: +cl.toFixed(1),
    disc: +((disc) * 100).toFixed(0),
  };
}

const pad = (s, w) => String(s).padEnd(w);
const padL = (s, w) => String(s).padStart(w);

function header() {
  console.log(pad('学科/学段', 16), padL('条数', 6), padL('章数', 6), padL('条/章', 7),
    padL('独苗%', 7), padL('字数', 6), padL('判据', 6), padL('前置', 6), padL('迁移%', 7), padL('分句', 6), padL('辨析%', 7));
  console.log('-'.repeat(108));
}

function row(label, s) {
  console.log(pad(label, 16), padL(s.n, 6), padL(s.chapters, 6), padL(s.perChapter.toFixed(1), 7),
    padL((s.loneRatio * 100).toFixed(0), 7), padL(s.chars, 6), padL(s.symbols, 6), padL(s.prereq, 6),
    padL(s.transfer, 7), padL(s.clauses, 6), padL(s.disc, 7));
}

console.log('=== 知识覆盖度(按 学科 × 学段) ===\n');
header();
const cells = [];
for (const subj of CurriculumIndex.subjects()) {
  for (const stage of CurriculumIndex.STAGE_ORDER) {
    const rows = CurriculumIndex.knowledgeOfStage(subj, stage);
    if (rows.length === 0) { cells.push([`${subjectName(subj)}·${CurriculumIndex.stageName(stage)}`, score([]), 0]); continue; }
    const s = score(rows);
    cells.push([`${subjectName(subj)}·${CurriculumIndex.stageName(stage)}`, s, rows.length]);
    row(`${subjectName(subj)}·${CurriculumIndex.stageName(stage)}`, s);
  }
}

console.log('\n=== 实验条目(按 学科 × 学段) ===\n');
header();
for (const subj of CurriculumIndex.subjects()) {
  for (const stage of CurriculumIndex.STAGE_ORDER) {
    const rows = CurriculumIndex.experimentsOfStage(subj, stage);
    if (rows.length === 0) continue;
    const s = score(rows.map((r) => ({
      chapter: r.course, statement: r.principle || '', symbols: r.equipment || [],
      prerequisites: [], level: KnowledgeLevel.APPLY,
    })));
    row(`${subjectName(subj)}·${CurriculumIndex.stageName(stage)}`, s);
  }
}

// ---- 找出最薄的格子:条数少、或独苗章占比高(说明那一块没拆开) ----
console.log('\n=== 最需补的格子(按 条数 × 独苗率 排) ===\n');
const thin = cells.filter(([, s]) => s.n > 0)
  .map(([name, s]) => ({ name, n: s.n, chapters: s.chapters, lone: +(s.loneRatio * 100).toFixed(0), chars: s.chars, transfer: s.transfer }))
  .sort((a, b) => (a.n - b.n) || (b.lone - a.lone));
console.log(pad('格子', 16), padL('条数', 6), padL('章数', 6), padL('独苗%', 8), padL('字数', 6), padL('迁移%', 8));
console.log('-'.repeat(62));
for (const t of thin) console.log(pad(t.name, 16), padL(t.n, 6), padL(t.chapters, 6), padL(t.lone, 8), padL(t.chars, 6), padL(t.transfer, 8));

const empty = cells.filter(([, s]) => s.n === 0).map(([name]) => name);
console.log('\n完全没知识的格子:', empty.length ? empty.join('、') : '无');

// ---- 缺辨析的条目:这些是「写得长但没有判点」的,加字不解决问题,要补的是分界 ----
console.log('\n=== 缺判点的条目(前 30 条,按学科汇总) ===\n');
const lacking = { total: 0 };
for (const subj of CurriculumIndex.subjects()) {
  for (const stage of CurriculumIndex.STAGE_ORDER) {
    const rows = CurriculumIndex.knowledgeOfStage(subj, stage);
    const miss = rows.filter((e) => !hasDiscriminator(e.statement));
    if (miss.length) {
      const key = `${subjectName(subj)}·${CurriculumIndex.stageName(stage)}`;
      lacking[key] = miss.length;
      lacking.total += miss.length;
    }
  }
}
for (const [k, v] of Object.entries(lacking)) {
  if (k === 'total') continue;
  console.log(`  ${pad(k, 16)} 缺 ${padL(v, 3)} 条`);
}
console.log(`  ${pad('合计', 16)} 缺 ${padL(lacking.total, 3)} 条`);
console.log('\n样例(确实没有判点的):');
for (const subj of CurriculumIndex.subjects()) {
  const rows = CurriculumIndex.knowledgeOfStage(subj, 'university');
  const m = rows.filter((e) => !hasDiscriminator(e.statement)).slice(0, 2);
  for (const e of m) console.log(`  ${e.id} 「${e.title}」→ ${e.statement.slice(0, 60)}…`);
}

// ---- 负对照:探针必须能把「故意做薄」的表评为显著更差 ----
// 没有这一段,上面所有数字可能只是脚本在数自己的输出,而不是在数数据。
console.log('\n=== 负对照(探针自己得能区分) ===\n');
const real = score(CurriculumIndex.knowledgeOfStage('physics', 'junior'));
const degenerate = score([
  { chapter: '力学', statement: '力是改变物体运动状态的原因', symbols: [], prerequisites: [], level: KnowledgeLevel.RECALL },
  { chapter: '电学', statement: '欧姆定律', symbols: [], prerequisites: [], level: KnowledgeLevel.RECALL },
  { chapter: '光学', statement: '光沿直线传播', symbols: [], prerequisites: [], level: KnowledgeLevel.RECALL },
]);
const verdicts = [];
const mustLower = (label, a, b) => verdicts.push([label, a < b, `薄表=${a} 真表=${b}`]);
const mustHigher = (label, a, b) => verdicts.push([label, a > b, `薄表=${a} 真表=${b}`]);
mustLower('条/章 更低', degenerate.perChapter, real.perChapter);
mustHigher('独苗率 更高', degenerate.loneRatio, real.loneRatio);
mustLower('字数 更少', degenerate.chars, real.chars);
mustLower('判据 更少', degenerate.symbols, real.symbols);
mustLower('迁移% 更低', degenerate.transfer, real.transfer);
mustLower('辨析% 更低', degenerate.disc, real.disc);
for (const [label, ok, detail] of verdicts) console.log(`${ok ? '✓' : '✗'} ${label}  ${detail}`);
const bad = verdicts.filter(([, ok]) => !ok);
if (bad.length) {
  console.log('\n探针不可信:以下刻度没能把薄表区分出来 →', bad.map(([l]) => l).join('、'));
  process.exit(1);
}
console.log('\n✓ 探针能区分「薄」与「厚」,上面的数字可用。');
