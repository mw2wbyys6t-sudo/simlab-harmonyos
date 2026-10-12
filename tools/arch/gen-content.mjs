/**
 * 从编译期常量生成随包发布的内容 JSON(rawfile 默认值)。
 *
 * 为什么是"生成"而不是"手写 JSON 再删掉 .ets":地图的校验、覆盖度刻度、判点率断言
 * 全都跑在编译期那张表上。如果 JSON 变成唯一副本,这些护栏就同时失去了靶子。
 * 现在的形状是:**内置表仍是事实来源,JSON 是它的一份确定性导出**;
 * 更新通道(沙箱里的同名文件)想改内容,必须过同一个 MapValidator,坏数据整批拒绝。
 *
 * 序列化用的是应用里同一个 `ContentCodec.encodeExperiments` —— 生成器和读取端
 * 不可能对不上格式,因为它们共用一份代码。
 *
 * 运行:node tools/arch/gen-content.mjs
 * 之后 `check.mjs` 里有一条断言守着:rawfile 里那份必须与内置表逐字节相同。
 */
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, mkdirSync, rmSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import os from 'node:os';

const require = createRequire(import.meta.url);
const ts = require('F:/DevEco/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript');
const REPO = join(dirname(fileURLToPath(import.meta.url)), '../..');
const SRC = join(REPO, 'entry', 'src', 'main', 'ets');
const OUT = join(os.tmpdir(), 'simlab-content');

const MODULES = [
  'content/map/CurriculumTypes',
  'content/map/KnowledgeTypes',
  'content/map/MapValidator',
  'content/map/SchoolPhysics',
  'content/map/ContentCodec'
];

rmSync(OUT, { recursive: true, force: true });
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

const { SchoolPhysics } = require(join(OUT, 'content/map/SchoolPhysics.cjs'));
const { ContentCodec } = require(join(OUT, 'content/map/ContentCodec.cjs'));

const TABLES = [
  { key: 'school-physics', rows: SchoolPhysics.all() }
];

const dest = join(REPO, 'entry', 'src', 'main', 'resources', 'rawfile', 'content');
mkdirSync(dest, { recursive: true });
for (const table of TABLES) {
  const json = ContentCodec.encodeExperiments(table.rows);
  const back = ContentCodec.decodeExperiments(json);
  if (back.rows.length !== table.rows.length) {
    console.error(`${table.key} 自检失败:解码后 ${back.rows.length} 行 ≠ 内置 ${table.rows.length} 行`);
    console.error('  ' + back.problems.join('\n  '));
    process.exit(1);
  }
  writeFileSync(join(dest, table.key + '.json'), json + '\n', 'utf8');
  console.log(`写出 ${table.key}.json:${table.rows.length} 行,${json.length} 字符`);
}
console.log('目录:' + dest);
if (readdirSync(dest).length !== TABLES.length) {
  console.log('提示:目录里还有别的 json 文件,可能是手工放进去的更新包副本');
}
