/**
 * 从 entry/src/main/ets 的真实 import 语句生成 Graphviz 依赖图。
 * 用途:证明跨栈隔离(chemistry 与 bench 之间边数为 0)这类负证据,不靠人眼扫代码。
 * 运行:node tools/arch/gen-deps.mjs
 */
import { readdirSync, statSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, relative, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const ROOT = join(REPO, 'entry/src/main/ets');
const OUT = join(REPO, 'docs/architecture/simlab-deps.dot');

function walk(dir, acc = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, acc);
    else if (name.endsWith('.ets')) acc.push(p);
  }
  return acc;
}

const norm = (p) => p.replace(/\\/g, '/');
const rel = (p) => norm(relative(ROOT, p));
const idOf = (p) => rel(p).replace(/\.ets$/, '').replace(/\//g, '_');
const groupOf = (p) => {
  const r = rel(p);
  const i = r.lastIndexOf('/');
  return i < 0 ? '.' : r.slice(0, i);
};

const files = walk(ROOT).sort();
const byPath = new Map(files.map((f) => [norm(f), f]));
const edges = [];
const unresolved = [];
const importRe = /^import\s+\{[^}]*\}\s+from\s+'([^']+)'/gm;

for (const f of files) {
  const fromId = idOf(f);
  const seen = new Set();
  let m;
  importRe.lastIndex = 0;
  while ((m = importRe.exec(readFileSync(f, 'utf8'))) !== null) {
    const spec = m[1];
    if (!spec.startsWith('.')) continue;
    const key = resolve(dirname(f), spec) + '.ets';
    const target = byPath.get(norm(key));
    if (!target) { unresolved.push(`${fromId} -> ${spec}`); continue; }
    const toId = idOf(target);
    if (fromId === toId || seen.has(toId)) continue;
    seen.add(toId);
    edges.push([fromId, toId]);
  }
}

const COLOR = {
  bench: '#2E9E7A', chemistry: '#8E5BD9', pages: '#2F6FB5',
  'physics/circuit': '#E2574C', physics: '#E2574C', runner: '#1F2A3A',
  scenes: '#6B7A8D', view: '#2F6FB5', common: '#C8A200', model: '#1F2A3A'
};

const groups = new Map();
for (const f of files) {
  const g = groupOf(f);
  if (!groups.has(g)) groups.set(g, []);
  groups.get(g).push(f);
}

const crossStack = edges.filter(([a, b]) =>
  (a.startsWith('chemistry_') && b.startsWith('bench_')) ||
  (a.startsWith('bench_') && b.startsWith('chemistry_')));

let out = 'digraph SimLabImports {\n'
  + '  rankdir=TB\n  splines=true\n'
  + '  node [shape=box, style="rounded,filled", fontname="HarmonyOS Sans", fontsize=11, color="#E1E6ED", fontcolor="#1F2A3A"]\n'
  + '  edge [color="#9AA7B6", arrowsize=0.6, penwidth=0.9]\n'
  + `  label="SimLab entry HAP 全量 .ets 导入图: ${files.length} 文件 / ${edges.length} 条边 / 跨栈边 ${crossStack.length} 条"\n`
  + '  labelloc=t\n\n';

for (const [g, list] of [...groups.entries()].sort()) {
  out += `  subgraph "cluster_${g.replace(/\//g, '_')}" {\n`
    + `    label="${g}"\n    style="rounded,dashed"\n    color="#C9D2DC"\n`
    + '    fontcolor="#6B7A8D"\n    fontsize=12\n';
  for (const f of list) {
    const fill = COLOR[g] ?? COLOR[g.split('/')[0]] ?? '#6B7A8D';
    out += `    ${idOf(f)} [label="${rel(f).replace(/\.ets$/, '')}", fillcolor="${fill}1A", color="${fill}"]\n`;
  }
  out += '  }\n\n';
}

for (const [a, b] of edges) out += `  ${a} -> ${b}\n`;
// 这句话必须算出来,不能写死。上一版把它写成"没有边",M4 合并之后就成了假证据。
out += `\n  // 跨栈边 chemistry/* <-> bench/*:${crossStack.length} 条`
  + (crossStack.length === 0 ? '(M4 合并债务的图形证据)' : ` —— ${crossStack.map(([a, b]) => `${a}→${b}`).join(', ')}`)
  + '\n}\n';

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, out, 'utf8');
console.log(`files=${files.length} edges=${edges.length} unresolved=${unresolved.length} chemistry<->bench=${crossStack.length}`);
for (const u of unresolved) console.log('UNRESOLVED ' + u);
