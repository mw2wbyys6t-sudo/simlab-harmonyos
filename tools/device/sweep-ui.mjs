/**
 * 逐屏 UI 巡检:屏幕上真的渲染出来的文字过一遍术语黑名单,再查有没有被右边缘裁掉。
 *
 * 为什么必须有一台设备上的巡检:离线断言只能扫数据层与细则文案(`check.mjs` 那一节),
 * 而页面里现写的字符串、拼接出来的句子、被容器裁掉的控件,只有 dumpLayout 看得见。
 * 两条性质都来自抓到的真缺陷:
 * ① 术语黑名单(spec 8.27)—— 屏幕上有"判据/落盘/可打开"这类词就是漏翻;
 * ② 右边缘裁切(spec 8.28)—— 定宽容器里"可点节点贴死右边界 + 后续兄弟缺失"= 溢出,
 *    那种节点不是看不见,是点不着。
 *
 * 运行:node tools/device/sweep-ui.mjs [--out <截图目录>] [--deep]
 *   --deep 连 9 个实验页一起走一遍(慢,但那是唯一能验"界面不撒谎"的路径)
 */
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import os from 'node:os';
import { Probe } from './probe.mjs';
import { BLOCKED_TERMS } from '../visible-copy-blocklist.mjs';

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const argv = process.argv;
const outArg = argv.indexOf('--out');
const outDir = outArg > -1 ? argv[outArg + 1] : join(os.tmpdir(), 'simlab-probe');
const deep = argv.includes('--deep');

const CARDS = ['量取训练', '化学实验台', '弹簧振子', '含摩擦的斜面', '探究弹簧弹力',
  '串联电路', '并联电路', '基尔霍夫', '最大功率'];
const MENUS = ['课程地图', '速查表', '报告', '深浅色'];

const p = new Probe({ tag: 'sweep', outDir: outDir });
const seenTexts = new Set();
let clipped = [];

/** 扫当前屏:收文字 + 找贴死右边界的可点节点 */
function scanScreen(name) {
  const width = p.screenWidth();
  const nodes = p.dumpNodes();
  let hit = 0;
  for (const n of nodes) {
    const t = n.text || '';
    if (t.length > 0) {
      hit++;
      seenTexts.add(t);
    }
    const m = (n.bounds || '').match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);
    // 只认"带标签的控件被推出右边界":从 x=0 开始的整幅容器(标题栏、列表本身)
    // 右边界本来就等于屏宽,把它们算进来会把真信号埋掉(第一版就是这么误报的)
    if (m && n.clickable === 'true' && t.length > 0 && +m[1] > 0 && +m[3] >= width - 1) {
      clipped.push(`${name}:${t} bounds=${n.bounds}`);
    }
  }
  p.shot(name);
  p.say(`  ${name}:节点带文字 ${hit} 个,屏宽 ${width}`);
}

p.say(`设备:${p.assertDevice()}`);
p.launch();

p.say('== 首页(含滚动两屏) ==');
scanScreen('home-1');
p.swipe(628, 2000, 628, 800);
scanScreen('home-2');

if (deep) {
  p.say('== 九个实验/实操页 ==');
  for (const card of CARDS) {
    p.ensureHome();
    if (!p.tapInList(card)) continue;
    const go = p.dumpNodes().find((a) => (a.text || '') === '开始' || (a.text || '') === '开始倾倒');
    if (go !== undefined) {
      const [x, y] = Probe.center(go.bounds);
      p.shell(`uitest uiInput click ${x} ${y}`);
      p.sleep(1800);
    }
    scanScreen(card.slice(0, 6));
    p.back();
  }
}

p.say('== 四个顶栏入口 ==');
for (const menu of MENUS) {
  p.ensureHome();
  if (!p.tap(menu, 2200)) continue;
  scanScreen(menu);
  p.back();
}

p.say('== 术语黑名单(屏幕上实际渲染的文字) ==');
const leaks = [];
for (const t of seenTexts) {
  for (const w of BLOCKED_TERMS) {
    if (t.includes(w)) leaks.push(`${w}「${t}」`);
  }
}
p.expectTrue(`可见文字里没有内部术语(共扫 ${seenTexts.size} 条)`, leaks.length === 0, leaks.slice(0, 8).join(' / '));

p.say('== 右边缘裁切 ==');
p.expectTrue('没有可点控件贴死屏幕右边界', clipped.length === 0, clipped.slice(0, 6).join(' / '));

const code = p.finish(`截图与 dump 在 ${outDir}`);
process.exit(code === 0 ? 0 : 1);
