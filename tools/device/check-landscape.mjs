/**
 * 横竖屏排布的设备验证。
 *
 * 离线闸门只算令牌之间的账,它看不见一屏里还站着状态栏、标题栏和底部手势区。
 * 那三块把横屏的计算推翻过一次:操作条整排掉到系统手势条上(实测多出 126px),
 * 而按屏高算的账是全绿的。所以排布必须在真屏上量。
 *
 * 这一份量两件事,方向不是参数给的,是屏上量的(应用窗口宽大于高就是横屏):
 *   ① 横屏:画面在左、参数栏在右;三颗按钮在左栏,倍速与仿真钟在右栏;
 *     没有一个控件压到系统手势条上。
 *   ② 竖屏(反例):单栏,画面在上、参数栏在下,倍速与仿真钟在画面下面。
 *
 * 两个方向跑同一份脚本。只跑横屏的话,"画面在左"也可能只是"所有东西都在左边";
 * 只跑竖屏的话,两栏排布根本没人验过。
 *
 * 三处"认对象"的地方都踩过坑,写在这里免得下一个人再踩:
 *   · 参数栏 = **面积最大的** Scroll。ChipGroup 内部自己带一个横向 Scroll,
 *     按顺序取第一个会拿到那个只有 98px 高的小滚动条,于是"倍速行在右栏"永远判不过。
 *   · 画面 = **最靠上**的那块 Canvas。图线画布在参数栏的滚动区里,
 *     竖屏时它和画面同宽,按 x 排会碰上同宽并列,按 y 排才唯一。
 *   · 内容区下沿 = 参数栏的下沿。左右两栏都 height('100%'),谁在下面谁就是内容底。
 *
 * 运行:node tools/device/check-landscape.mjs [--install <hap 路径>] [--out <截图目录>]
 */
import { join } from 'node:path';
import os from 'node:os';
import { Probe } from './probe.mjs';

const outArg = process.argv.indexOf('--out');
const outDir = outArg > -1 ? process.argv[outArg + 1] : join(os.tmpdir(), 'simlab-landscape');
const installArg = process.argv.indexOf('--install');
const hapPath = installArg > -1 ? process.argv[installArg + 1] : null;

const EXP = '弹簧振子的简谐振动';
// 布局令牌:脚本靠它们把 px 折回 vp(与 Layout.ets 一一对应)
const BUTTON_H = 44;      // Layout.buttonHeight(PHONE)
const SCENE_MIN = 120;    // Layout.minSceneHeight 的下限(离线闸门钉的数)
const CONTENT_MAX = 220;  // Layout.COMPACT_CONTENT_HEIGHT:紧凑档内容区实得高度
const CONTENT_MIN = 200;  // 下限:太矮说明排布塌了,那样"没溢出"是空话
// 只看叶子节点:容器节点的 bounds 是它自己排版的结果,不是内容
const LEAF = ['Text', 'Button', 'Canvas', 'Slider', 'TextInput', 'Image', 'Toggle'];

const p = new Probe({ tag: 'landscape', outDir: outDir });

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
p.say(bar === null
  ? `没找到系统底部条,内容下沿按窗口底 ${vp.b}px 算`
  : `系统底部条上沿 ${bar.top}px(${bar.raw.slice(0, 60)})`);

// px/vp:屏自己报的缩放。折出来的比值要落在合理区间,否则宁可这条判据不算 ——
// 一台密度不对的机器会把 120vp 折成别的数,那样的数字是假的。
const display = p.display();
const ratio = display.density;
p.expectTrue('屏报了缩放(px/vp)', ratio > 0, `density = ${display.density}`);
p.say(`缩放 ${ratio} px/vp,虚拟尺寸 ${display.virtualWidth}x${display.virtualHeight}vp`);
const vpOf = (px) => px / ratio;

if (!p.tapInList(EXP, 8)) {
  p.finish('没能点开实验页,后面的排布没量上');
  process.exit(1);
}

const nodes = p.dumpNodes();
const rect = (n) => Probe.rect(n.bounds);
const byText = (t) => nodes.find((n) => (n.text || '') === t);

const canvases = nodes.filter((n) => n.type === 'Canvas').map(rect);
const scrolls = nodes.filter((n) => n.type === 'Scroll').map(rect);
p.say(`画布 ${canvases.length} 块、滚动区 ${scrolls.length} 个`);

if (canvases.length === 0 || scrolls.length === 0) {
  p.fail('页面上找得到画面与参数栏', `画布 ${canvases.length} 块、滚动区 ${scrolls.length} 个`);
  p.finish();
  process.exit(1);
}

// 画面 = 最靠上的那块画布(图线画布在参数栏的滚动区里,永远更低)
const scene = canvases.slice().sort((a, b) => (a[1] - b[1]) || (a[0] - b[0]))[0];
// 参数栏 = 面积最大的那个滚动区(ChipGroup 内部那个小的不算)
const panel = scrolls.slice().sort((a, b) =>
  ((b[2] - b[0]) * (b[3] - b[1])) - ((a[2] - a[0]) * (a[3] - a[1])))[0];

const start = byText('开始') || byText('暂停');
const reset = byText('重置');
const chartBtn = byText('收起图线') || byText('展开图线');
const speed = byText('倍速');
const clock = nodes.find((n) => (n.text || '').indexOf('t = ') === 0);
const btnRects = [start, reset, chartBtn].filter((n) => n !== undefined).map(rect);
const speedR = speed === undefined ? null : rect(speed);
const clockR = clock === undefined ? null : rect(clock);
// 图线画布 = 另一块画布(不是画面那块)
const chart = canvases.filter((r) => r !== scene)[0];

p.say(`画面 ${scene} / 参数栏 ${panel}`);
p.say(`按钮 ${btnRects.length} 颗,倍速行 ${speedR === null ? '没有' : speedR}`);

// 传输按钮该有多高:它的高度同时是"按钮确实是 44vp"与"折算没跑偏"的交叉验证。
if (btnRects.length > 0) {
  const btnH = btnRects[0][3] - btnRects[0][1];
  p.expectTrue(`传输按钮高 ${BUTTON_H}vp(与屏的缩放对得上)`,
    Math.abs(btnH / ratio - BUTTON_H) <= 1,
    `按钮高 ${btnH}px → ${(btnH / ratio).toFixed(1)}vp`);
}

// 内容区高度:从页面顶(画面上沿)到内容区底(参数栏下沿)。
const contentH = panel[3] - scene[1];

// 溢出扫描:应用窗口里,凡是下沿越过系统底部条上沿的叶子节点,都是掉出去了。
// 状态栏那一支在窗口上方(y 0..136),不在窗口矩形里,自然不算进来。
const leaves = [];
for (const n of nodes) {
  if (!LEAF.includes(n.type)) {
    continue;
  }
  const r = rect(n);
  if (r[1] < vp.t || r[3] > vp.b || r[0] < vp.l || r[2] > vp.r) {
    continue;
  }
  leaves.push({ type: n.type, text: (n.text || '').replace(/\n/g, ' '), r: r });
}
const overflow = leaves.filter((x) => x.r[3] > sysBottom);
const sideways = leaves.filter((x) => x.r[0] < vp.l || x.r[2] > vp.r);

if (landscape) {
  p.expectTrue('横屏:画面整块在参数栏左边', scene[2] <= panel[0],
    `画面右沿 ${scene[2]} / 参数栏左沿 ${panel[0]}`);
  p.expectTrue('横屏:参数栏在画面右边,两栏并排', panel[2] > scene[2],
    `参数栏 ${panel} / 画面 ${scene}`);
  p.expectTrue('横屏:三颗传输按钮都在左栏', btnRects.length === 3 && btnRects.every((r) => r[0] < panel[0]),
    `按钮 ${JSON.stringify(btnRects)}`);
  p.expectTrue('横屏:倍速那一行在右栏', speedR !== null && speedR[0] >= panel[0],
    `倍速行 ${speedR} / 参数栏左沿 ${panel[0]}`);
  p.expectTrue('横屏:仿真钟在右栏', clockR !== null && clockR[0] >= panel[0],
    `仿真钟 ${clockR} / 参数栏左沿 ${panel[0]}`);
  // 倍速与仿真钟要留在**固定的那一栏**:压在参数栏滚动区之上,往下滚参数时它们还在
  p.expectTrue('横屏:倍速那一行在滚动区之上(往下滑不会跑掉)',
    speedR !== null && speedR[3] <= panel[1] + 1,
    `倍速行下沿 ${speedR === null ? '-' : speedR[3]} / 参数栏顶 ${panel[1]}`);
  p.expectTrue('横屏:仿真钟在滚动区之上(往下滑不会跑掉)',
    clockR !== null && clockR[3] <= panel[1] + 1,
    `仿真钟下沿 ${clockR === null ? '-' : clockR[3]} / 参数栏顶 ${panel[1]}`);
  p.expectTrue('横屏:传输按钮排在画面下面', btnRects.length > 0 && btnRects.every((r) => r[1] >= scene[3]),
    `按钮 ${JSON.stringify(btnRects)} / 画面底 ${scene[3]}`);
  p.expectTrue('横屏:内容区实得高度不超过 220vp', vpOf(contentH) <= CONTENT_MAX + 1,
    `实得 ${vpOf(contentH).toFixed(1)}vp`);
  p.expectTrue('横屏:内容区不是塌的(实得高度在 200vp 以上)', vpOf(contentH) >= CONTENT_MIN,
    `实得 ${vpOf(contentH).toFixed(1)}vp`);
  p.expectTrue('横屏:画面高度不低于 120vp', vpOf(scene[3] - scene[1]) >= SCENE_MIN,
    `实得 ${vpOf(scene[3] - scene[1]).toFixed(1)}vp`);
  p.expectTrue('横屏:图线画布在右栏的滚动区里', chart !== undefined
    && chart[0] >= panel[0] && chart[3] <= panel[3],
    `图线 ${chart === undefined ? '没有' : chart} / 参数栏 ${panel}`);
} else {
  p.expectTrue('竖屏:参数栏在画面下面(单栏)', panel[1] >= scene[3],
    `参数栏顶 ${panel[1]} / 画面底 ${scene[3]}`);
  p.expectTrue('竖屏:画面与参数栏同宽(整列)', Math.abs(panel[0] - scene[0]) <= 8 && panel[2] >= scene[2] - 8,
    `参数栏 ${panel} / 画面 ${scene}`);
  p.expectTrue('竖屏:三颗传输按钮在画面下面', btnRects.length === 3 && btnRects.every((r) => r[1] >= scene[3]),
    `按钮 ${JSON.stringify(btnRects)} / 画面底 ${scene[3]}`);
  p.expectTrue('竖屏:倍速那一行在画面下面', speedR !== null && speedR[1] >= scene[3],
    `倍速行 ${speedR} / 画面底 ${scene[3]}`);
  p.expectTrue('竖屏:仿真钟在画面下面', clockR !== null && clockR[1] >= scene[3],
    `仿真钟 ${clockR} / 画面底 ${scene[3]}`);
  p.expectTrue('竖屏:画面高度不低于 120vp', vpOf(scene[3] - scene[1]) >= SCENE_MIN,
    `实得 ${vpOf(scene[3] - scene[1]).toFixed(1)}vp`);
}

p.expectTrue('没有控件压到系统底部条上', overflow.length === 0,
  overflow.map((x) => `${x.type}「${x.text}」${JSON.stringify(x.r)}`).join(' | '));
p.expectTrue('没有控件横向出界', sideways.length === 0,
  sideways.map((x) => `${x.type}「${x.text}」${JSON.stringify(x.r)}`).join(' | '));

const shot = p.shot(landscape ? 'landscape' : 'portrait');
if (shot !== '') {
  p.say(`截图 ${shot}`);
}

p.finish();
process.exit(p.failures === 0 ? 0 : 1);
