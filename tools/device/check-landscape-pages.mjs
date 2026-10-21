/**
 * 横屏下每一页的排布体检。
 *
 * 实验页那一轮已经量出过一个真缺陷:操作条整排掉到系统手势条上(多出 126px)。
 * 那个缺陷不是实验页独有的毛病,是"矮屏那一档算错了高度"这一类 ——
 * 别的页也会踩,所以这里把每一页都走一遍,量同两件事:
 *
 *   ① 溢出:没有控件压到系统底部条(手势区)上,也没有控件横向出界。
 *      判据取自 WindowManagerService 的窗口矩形,不用应用自己的布局反推 ——
 *      用被测者给自己判卷,判出来的绿不算数。
 *   ② 阅读列:列表类页面在矮屏下应当收窄到 COMPACT_CONTENT_WIDTH(640vp)并居中。
 *      横屏手机有 791vp 宽,一行塞得下 100 个汉字 —— 那不是阅读,是刻度。
 *
 * 两栏页(实验页/量取页/台架页)不适用 ②:它们的宽度是画面与侧栏分掉的。
 *
 * 方向不是参数给的,是屏上量的(应用窗口宽大于高就是横屏),竖屏跑这份脚本也能用。
 *
 * 运行:node tools/device/check-landscape-pages.mjs [--out <截图目录>]
 */
import { join } from 'node:path';
import os from 'node:os';
import { Probe } from './probe.mjs';

const outArg = process.argv.indexOf('--out');
const outDir = outArg > -1 ? process.argv[outArg + 1] : join(os.tmpdir(), 'simlab-landscape-pages');
const installArg = process.argv.indexOf('--install');
const hapPath = installArg > -1 ? process.argv[installArg + 1] : null;

const COLUMN_MAX = 640;   // Layout.COMPACT_CONTENT_WIDTH
const COLUMN_SLACK = 6;   // 折算与取整的余量
const CENTER_SLACK = 10;  // 左右留白差多少算没居中
const LEAF = ['Text', 'Button', 'Canvas', 'Slider', 'TextInput', 'Image', 'Toggle'];

const PAGES = [
  { name: '首页实验库', nav: null, column: true },
  { name: '量取训练', nav: { list: '量取训练' }, column: false },
  { name: '化学实验台', nav: { list: '化学实验台' }, column: false },
  { name: '实验页(弹簧振子)', nav: { list: '弹簧振子的简谐振动' }, column: false },
  { name: '课程地图', nav: { menu: '课程地图' }, column: true },
  { name: '速查表', nav: { menu: '速查表' }, column: true },
  { name: '报告', nav: { menu: '报告' }, column: true },
  { name: '深浅色', nav: { menu: '深浅色' }, column: true }
];

const p = new Probe({ tag: 'pages', outDir: outDir });

p.assertDevice();
if (hapPath !== null) {
  p.install(hapPath);
}
p.launch();

const vp = p.viewport();
const landscape = vp.w > vp.h;
p.say(`应用窗口 ${vp.w}x${vp.h}px → ${landscape ? '横屏' : '竖屏'}`);

const bar = p.systemBottom();
const sysBottom = bar === null ? vp.b : bar.top;
p.say(`系统底部条上沿 ${sysBottom}px`);

// px/vp:屏自己报的缩放。反推的做法(找一颗按钮除以它该有几 vp 高)要事先知道
// 页面自己的令牌,页面一改布局折算就错 —— 本轮就因此把 640vp 的阅读列判成 965vp。
const display = p.display();
const ratio = display.density;
p.expectTrue('屏报了缩放(px/vp)', ratio > 0, `density = ${display.density}`);
p.say(`缩放 ${ratio} px/vp,虚拟尺寸 ${display.virtualWidth}x${display.virtualHeight}vp`);

function leavesOf(nodes) {
  const titleBars = nodes.filter((n) => n.type === 'TitleBar').map((n) => Probe.rect(n.bounds));
  const out = [];
  for (const n of nodes) {
    if (!LEAF.includes(n.type)) {
      continue;
    }
    const r = Probe.rect(n.bounds);
    if (r[1] < vp.t || r[3] > vp.b || r[0] < vp.l || r[2] > vp.r) {
      continue;
    }
    const inTitle = titleBars.some((t) => r[1] >= t[1] && r[3] <= t[3]);
    out.push({ type: n.type, text: (n.text || '').replace(/\n/g, ' '), r: r, inTitle: inTitle });
  }
  return out;
}

let failuresBefore = p.failures;

for (const page of PAGES) {
  // 每页都从首页重新进:上一页留下的滚动位置与展开状态不该影响这一页
  if (page.nav !== null) {
    if (page.nav.list !== undefined) {
      if (!p.tapInList(page.nav.list, 8)) {
        p.fail(`进「${page.name}」`, `列表里点不到「${page.nav.list}」`);
        continue;
      }
    } else if (!p.tap(page.nav.menu)) {
      p.fail(`进「${page.name}」`, `点不到「${page.nav.menu}」`);
      continue;
    }
  }

  const nodes = p.dumpNodes();
  const leaves = leavesOf(nodes);

  const overflow = leaves.filter((x) => x.r[3] > sysBottom);
  const sideways = leaves.filter((x) => x.r[0] < vp.l || x.r[2] > vp.r);
  const body = leaves.filter((x) => !x.inTitle);

  p.expectTrue(`${page.name}:没有控件压到系统底部条上`, overflow.length === 0,
    overflow.map((x) => `${x.type}「${x.text}」${JSON.stringify(x.r)}`).join(' | '));
  p.expectTrue(`${page.name}:没有控件横向出界`, sideways.length === 0,
    sideways.map((x) => `${x.type}「${x.text}」${JSON.stringify(x.r)}`).join(' | '));

  if (body.length > 0) {
    const minLeft = Math.min(...body.map((x) => x.r[0]));
    const maxRight = Math.max(...body.map((x) => x.r[2]));
    const wVp = (maxRight - minLeft) / ratio;
    const leftGap = (minLeft - vp.l) / ratio;
    const rightGap = (vp.r - maxRight) / ratio;
    p.say(`  ${page.name}:内容列 ${wVp.toFixed(0)}vp(左留白 ${leftGap.toFixed(0)}vp / 右留白 ${rightGap.toFixed(0)}vp)`);
    if (page.column) {
      p.expectTrue(`${page.name}:阅读列不宽于 ${COLUMN_MAX}vp`, wVp <= COLUMN_MAX + COLUMN_SLACK,
        `实得 ${wVp.toFixed(0)}vp`);
      p.expectTrue(`${page.name}:阅读列居中`, Math.abs(leftGap - rightGap) <= CENTER_SLACK,
        `左 ${leftGap.toFixed(0)}vp / 右 ${rightGap.toFixed(0)}vp`);
    }
  }

  const shot = p.shot(`page-${page.name}`);
  if (shot !== '') {
    p.say(`  截图 ${shot}`);
  }

  // 回首页:从 NavDestination 退栈,退不回首页就整个重启
  if (page.nav !== null) {
    p.back(1200);
    const after = p.dumpNodes();
    const home = after.some((n) => (n.text || '') === '仿真实验室');
    if (!home) {
      p.launch();
    }
  }
}

// ---- 化学实验台的最坏情况:器皿卡多出一行「加热中」 ------------------------
// 这一页的缺陷就是从这儿长出来的:卡里那几行字(标题/加热中/沉底/质量)在矮屏
// 是刚性开销,多一行卡就长一截,而右栏只有 220vp,长出来的那截把两颗动作按钮
// 顶到系统手势条上(实测按钮被画在 [1401,1130,1782,1256])。
// 所以这里真的点一下「点燃酒精灯」,让卡多出一行,再量一次。
{
  if (!p.tapInList('化学实验台', 8)) {
    p.fail('进「化学实验台」(最坏情况)', '列表里点不到「化学实验台」');
  } else {
    const heat = p.dumpNodes().find((n) => (n.text || '') === '点燃酒精灯');
    if (heat === undefined) {
      p.fail('找到「点燃酒精灯」', '页面上没有这颗按钮');
    } else {
      p.tap('点燃酒精灯');
      const after = p.dumpNodes();
      p.expectTrue('点得着「点燃酒精灯」,卡里多出「加热中」那一行',
        after.some((n) => (n.text || '') === '加热中'), '没看到「加热中」');
      // 不只是"没压在系统条上":还得在应用内容区里(矮屏的上下页边距各 8vp)
      const contentBottom = sysBottom - 8 * ratio;
      const lowest = leavesOf(after).reduce((a, x) => (x.r[3] > a ? x.r[3] : a), 0);
      p.expectTrue('加热之后内容仍在应用内容区内', lowest <= contentBottom,
        `最低 ${lowest} > ${contentBottom}`);
      const shot = p.shot('page-化学实验台-加热中');
      if (shot !== '') {
        p.say(`  截图 ${shot}`);
      }
    }
  }
  p.back(1200);
}

p.say(`这一轮 ${p.failures - failuresBefore} 项失败`);
p.finish();
process.exit(p.failures === 0 ? 0 : 1);
