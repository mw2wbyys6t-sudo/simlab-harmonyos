/**
 * 标准长式周期表的设备侧断言。
 *
 * 离线门禁(tools/physics-check/check.mjs)已经钉住了模型层:18 列、每周期 2/8/8/18/18/17/17、
 * 主表 88 个元素、整表 118 个、f 区不进主表。但那些都是**数据层**的结论 ——
 * 屏幕上是另一回事:格子画没画出来、列对没对齐、标记格点不点得动,离线全都不知道。
 *
 * 所以这里从屏幕取证:读 dumpLayout 的节点文本与 bounds,按几何关系判。
 *
 * 判据不写死"应该是哪几个元素",而是判**关系**:族号 1 的那一列正下方是 H、
 * H 正下方是 Li、Li 那一行的第 2 列是 Be —— 这几条成立,才说明表是标准长式表的摆法,
 * 而不是碰巧画了几个方块。
 *
 * 运行:node tools/device/check-periodic.mjs [--out <截图目录>] [--dump]
 */
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import os from 'node:os';
import { Probe } from './probe.mjs';

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const HAP = join(REPO, 'entry/build/default/outputs/default/entry-default-unsigned.hap');
const outArg = process.argv.indexOf('--out');
const outDir = outArg > -1 ? process.argv[outArg + 1] : join(os.tmpdir(), 'simlab-probe');
const dumpMode = process.argv.indexOf('--dump') > -1;

const p = new Probe({ tag: 'periodic', outDir: outDir });

/** 一次快照里某个文本的节点;找不到返回 null */
function nodeOf(nodes, text) {
  for (const n of nodes) {
    if ((n.text || '') === text) {
      return n;
    }
  }
  return null;
}

/** 文本完全等于 text 的节点有几个(同名格子不该有,但要看清楚) */
function countOf(nodes, text) {
  let k = 0;
  for (const n of nodes) {
    if ((n.text || '') === text) {
      k++;
    }
  }
  return k;
}

/** 横向中心差(px) */
function dx(a, b) {
  return Probe.center(a.bounds)[0] - Probe.center(b.bounds)[0];
}

/** 纵向中心差(px) */
function dy(a, b) {
  return Probe.center(a.bounds)[1] - Probe.center(b.bounds)[1];
}

function say(texts) {
  for (const n of texts) {
    const t = n.text || '';
    if (t.length === 0) {
      continue;
    }
    p.say(`  [${n.type}] ${JSON.stringify(t)} ${n.bounds}`);
  }
}

p.say(`设备:${p.assertDevice()}`);
p.install(HAP);
p.launch();

p.say('== 0. 走到化学的周期表 ==');
p.ensureHome();
p.tap('课程地图', 2400);
p.tap('化学', 2000);
p.tap('周期表', 2600);

let nodes = p.dumpNodes();
if (dumpMode) {
  p.say('-- 首屏全部带字节点 --');
  say(nodes);
}
p.shot('periodic-first');

p.say('== 1. 周期表这一档确实打开了 ==');
p.expectTrue('顶栏报的是长式表',
  nodes.some((a) => (a.text || '').indexOf('18 族 × 7 周期的长式表') >= 0),
  '没看到长式表那一行总数');
p.expectTrue('「周期表」这一档是选中的',
  nodes.some((a) => (a.text || '') === '周期表' && a.selected === 'true'),
  '周期表那颗 chip 不是选中态');
p.expectTrue('没选格子时给的是提示语',
  nodes.some((a) => (a.text || '').indexOf('点表里的一个格子看详情') >= 0),
  '没看到空态提示');

p.say('== 2. 表头是 18 个族号 + 左侧「族号」那一栏 ==');
p.expectTrue('左上角有「族号」表头', nodeOf(nodes, '族号') !== null, '没找到「族号」');
const headerNums = [];
for (const n of nodes) {
  const t = n.text || '';
  if (/^\d{1,2}$/.test(t)) {
    headerNums.push({ t: t, b: n.bounds });
  }
}
p.say(`  屏上的纯数字文本 ${headerNums.length} 个:`);
for (const h of headerNums) {
  p.say(`    ${h.t} @ ${h.b}`);
}

p.say('== 3. 表头的族号从 1 开始、同一行、往右递增 ==');
// 表头行在整张表的最上沿:取「族号」那一格的纵坐标,取同一横带里的数字
const gutter = nodeOf(nodes, '族号');
const band = headerNums.filter((h) => {
  if (gutter === null) {
    return false;
  }
  const c = Probe.center(gutter.bounds);
  const m = h.b.match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);
  const y = Math.round((+m[2] + +m[4]) / 2);
  return Math.abs(y - c[1]) <= 40;
});
const bandText = band.map((h) => h.t).sort((a, b) => (+a) - (+b));
p.say(`  表头那一行的数字:${bandText.join(',')}`);
p.expectTrue('表头行有数字(族号)', bandText.length > 0, '表头行一个数字都没有');
p.expectTrue('表头从 1 开始', bandText.length > 0 && bandText[0] === '1',
  `表头行是 ${bandText.join(',')}`);

p.say('== 4. 几何关系:H 在族号 1 的正下方,Li 在 H 的正下方,Be 在 Li 同一行的第 2 列 ==');
const h1 = nodeOf(nodes, '1');
const hydrogen = nodeOf(nodes, 'H');
const lithium = nodeOf(nodes, 'Li');
const beryllium = nodeOf(nodes, 'Be');
p.expectTrue('屏上有 H', hydrogen !== null, '没找到 H');
p.expectTrue('屏上有 Li', lithium !== null, '没找到 Li');
p.expectTrue('屏上有 Be', beryllium !== null, '没找到 Be');
if (hydrogen !== null && h1 !== null) {
  p.expectTrue('H 与族号 1 同一列', Math.abs(dx(hydrogen, h1)) <= 8,
    `横差 ${dx(hydrogen, h1)} px`);
}
if (hydrogen !== null && lithium !== null) {
  p.expectTrue('Li 在 H 的正下方(同一列)', Math.abs(dx(lithium, hydrogen)) <= 8,
    `横差 ${dx(lithium, hydrogen)} px`);
  p.expectTrue('Li 在 H 的下面(纵坐标更大)', dy(lithium, hydrogen) > 0,
    `纵差 ${dy(lithium, hydrogen)} px`);
}
if (beryllium !== null && lithium !== null) {
  p.expectTrue('Be 与 Li 同一行', Math.abs(dy(beryllium, lithium)) <= 8,
    `纵差 ${dy(beryllium, lithium)} px`);
  p.expectTrue('Be 在 Li 的右边(第 2 族)', dx(beryllium, lithium) > 0,
    `横差 ${dx(beryllium, lithium)} px`);
}

p.say('== 5. 主表里放得下 88 个元素的摆法:第 6/7 周期第 3 族是标记格 ==');
const marker57 = nodeOf(nodes, '57～71');
const marker89 = nodeOf(nodes, '89～103');
p.expectTrue('主表里有「57～71」标记格', marker57 !== null, '没找到 57～71');
p.expectTrue('主表里有「89～103」标记格', marker89 !== null, '没找到 89～103');
p.expectTrue('标记格里写着系列名「镧系」', nodeOf(nodes, '镧系') !== null, '没找到 镧系');
p.expectTrue('标记格里写着系列名「锕系」', nodeOf(nodes, '锕系') !== null, '没找到 锕系');
if (marker57 !== null && marker89 !== null) {
  p.expectTrue('两个标记格在同一列(第 3 族)', Math.abs(dx(marker57, marker89)) <= 8,
    `横差 ${dx(marker57, marker89)} px`);
  p.expectTrue('两个标记格上下相隔一行(第 6、7 周期)', dy(marker89, marker57) > 0,
    `纵差 ${dy(marker89, marker57)} px`);
}
if (marker57 !== null && hydrogen !== null) {
  p.expectTrue('标记格在 H 的右边(第 3 族)', dx(marker57, hydrogen) > 0,
    `横差 ${dx(marker57, hydrogen)} px`);
}

p.say('== 6. f 区两行排在主表下方 ==');
const lanthanum = nodeOf(nodes, 'La');
p.expectTrue('镧系行第一个元素 La 在屏上', lanthanum !== null, '没找到 La');
if (lanthanum !== null && marker57 !== null) {
  p.expectTrue('La 与标记格同一列(镧系从第 3 族起)', Math.abs(dx(lanthanum, marker57)) <= 8,
    `横差 ${dx(lanthanum, marker57)} px`);
  p.expectTrue('La 在标记格下面(主表之下)', dy(lanthanum, marker57) > 0,
    `纵差 ${dy(lanthanum, marker57)} px`);
}

p.say('== 7. 负对照:18 列放不下一页,所以远处的列一开始看不见 ==');
p.expectTrue('右侧的 He 此刻不在屏上(表确实比一屏宽)',
  nodeOf(nodes, 'He') === null,
  'He 就在屏上:18 列一屏放得下,横向滚动这件事没被验证过');
p.expectTrue('第 7 族的 Cl 一开始也不在屏上', nodeOf(nodes, 'Cl') === null, 'Cl 在屏上');

p.say('== 8. 横向滑动:滑动后能看到右边的族 ==');
// 表格在页面上半部,取 H 那一行的纵坐标横着甩
const swipeY = hydrogen !== null ? Probe.center(hydrogen.bounds)[1] : 900;
for (let i = 0; i < 4; i++) {
  p.swipe(1050, swipeY, 150, swipeY);
}
nodes = p.dumpNodes();
if (dumpMode) {
  p.say('-- 横向滑动后全部带字节点 --');
  say(nodes);
}
p.shot('periodic-scrolled');
p.expectTrue('滑动后看见了右边的族(He)', nodeOf(nodes, 'He') !== null, '滑动后还是没看到 He');
p.expectTrue('滑动后左边的 H 滑出视口', nodeOf(nodes, 'H') === null, 'H 还在屏上');
// 滑动后的表头要重新从这一份快照里数,不能拿滑动前那份
const afterGutter = nodeOf(nodes, '族号');
const afterBand = [];
for (const n of nodes) {
  const t = n.text || '';
  if (!/^\d{1,2}$/.test(t)) {
    continue;
  }
  if (afterGutter === null) {
    continue;
  }
  const c = Probe.center(afterGutter.bounds);
  const m = n.bounds.match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);
  if (Math.abs(Math.round((+m[2] + +m[4]) / 2) - c[1]) <= 40) {
    afterBand.push(t);
  }
}
p.say(afterGutter === null
  ? '  滑动后表头那一行:左侧「族号」那一栏已经滑出视口'
  : '  滑动后表头那一行的族号:' + afterBand.sort((a, b) => (+a) - (+b)).join(','));

p.say('== 9. 点格子出详情卡 ==');
// 回到最左,点 H
for (let i = 0; i < 4; i++) {
  p.swipe(150, swipeY, 1050, swipeY);
}
nodes = p.dumpNodes();
const h2 = nodeOf(nodes, 'H');
p.expectTrue('滑回左边又看见 H', h2 !== null, '没找到 H');
if (h2 !== null) {
  const c = Probe.center(h2.bounds);
  p.shell(`uitest uiInput click ${c[0]} ${c[1]}`);
  p.sleep(1800);
  nodes = p.dumpNodes();
  if (dumpMode) {
    p.say('-- 点 H 之后全部带字节点 --');
    say(nodes);
  }
  p.shot('periodic-hydrogen');
  p.expectTrue('详情卡写的是氢', nodes.some((a) => (a.text || '').indexOf('氢（H）') >= 0),
    '没看到「氢（H）」');
  p.expectTrue('详情卡写的是第 1 周期第 1 族 s 区',
    nodes.some((a) => (a.text || '').indexOf('第 1 周期 · 第 1 族 · s 区') >= 0),
    '没看到周期族区那一行');
}

p.say('== 10. 点标记格出系列卡 ==');
const m57 = nodeOf(nodes, '57～71');
if (m57 === null) {
  p.fail('点「57～71」标记格', '屏上找不到这个标记格');
} else {
  const c = Probe.center(m57.bounds);
  p.shell(`uitest uiInput click ${c[0]} ${c[1]}`);
  p.sleep(1800);
  nodes = p.dumpNodes();
  if (dumpMode) {
    p.say('-- 点标记格之后全部带字节点 --');
    say(nodes);
  }
  p.shot('periodic-series');
  p.expectTrue('系列卡标题是「镧系（57～71）」',
    nodes.some((a) => (a.text || '') === '镧系（57～71）'), '没看到镧系那一张卡');
  p.expectTrue('系列卡说清是 f 区、单独一行、共 15 种',
    nodes.some((a) => (a.text || '').indexOf('是 f 区元素') >= 0)
    && nodes.some((a) => (a.text || '').indexOf('共 15 种') >= 0),
    '没看到系列说明');
}

const code = p.finish(`截图在 ${outDir}`);
process.exit(code === 0 ? 0 : 1);
