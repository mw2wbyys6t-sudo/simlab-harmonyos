/**
 * 量取页回归:空筒抬高视线后,读数卡不许凭空出现体积(#66 的 F3)。
 *
 * 离线断言已经钉住了模型(空筒读数恒为 0),这条测的是**屏幕上**那一格:
 * 读数卡走的是 observable → @State → Text 这条链,链路断了模型对也没用。
 *
 * 自带仪器自检:拖完滑杆必须先看到「视线高度」的数字真的变了,
 * 否则"读数仍是 0.00"只是因为根本没拖到 —— 那是假绿。
 *
 * 运行:node tools/device/check-measure-reset.mjs
 */
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import os from 'node:os';
import { Probe } from './probe.mjs';

const outArg = process.argv.indexOf('--out');
const outDir = outArg > -1 ? process.argv[outArg + 1] : join(os.tmpdir(), 'simlab-probe');

const p = new Probe({ tag: 'measure', outDir: outDir });

/** 读数卡上「你的读数」下面那格的文本 */
function readingValue() {
  const nodes = p.dumpNodes();
  const texts = nodes.map((a) => a.text || '').filter((t) => t.length > 0);
  const at = texts.indexOf('你的读数');
  return at >= 0 && at + 1 < texts.length ? texts[at + 1] : '';
}

function eyeLabel() {
  const nodes = p.dumpNodes();
  const texts = nodes.map((a) => a.text || '').filter((t) => t.length > 0);
  const at = texts.indexOf('视线高度');
  return at >= 0 && at + 1 < texts.length ? texts[at + 1] : '';
}

/** 找"视线高度"这一组里的滑杆:取标签下方最近的那个 Slider 节点 */
function eyeSlider() {
  const nodes = p.dumpNodes();
  let label = null;
  for (const n of nodes) {
    if ((n.text || '') === '视线高度') label = n.bounds;
  }
  if (label === null) return null;
  const labelTop = +label.match(/\[(\d+),(\d+)\]/)[2];
  const top = (b) => +b.match(/\[(\d+),(\d+)\]/)[2];
  let best = null;
  for (const n of nodes) {
    if (n.type !== 'Slider') continue;
    if (top(n.bounds) <= labelTop) continue;
    if (best === null || top(n.bounds) < top(best.bounds)) best = n;
  }
  return best;
}

p.say(`设备:${p.assertDevice()}`);
p.launch();
p.ensureHome();
if (!p.tapInList('量取训练')) process.exit(1);

p.say('== 1. 初始态:读数卡两格都该是 0.00 mL ==');
p.expect('初始读数', readingValue(), '0.00 mL');

p.say('== 2. 抬高视线:仪器自检 + 断言 ==');
const before = eyeLabel();
const slider = eyeSlider();
if (slider === undefined || slider === null) {
  p.fail('找到「视线高度」滑杆', 'dumpLayout 里没有匹配的节点');
} else {
  const b = { x1: 0, y1: 0, x2: 0, y2: 0 };
  const m = slider.bounds.match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);
  b.x1 = +m[1]; b.y1 = +m[2]; b.x2 = +m[3]; b.y2 = +m[4];
  const y = Math.round((b.y1 + b.y2) / 2);
  p.shell(`uitest uiInput swipe ${b.x1 + 20} ${y} ${Math.round(b.x1 + (b.x2 - b.x1) * 0.7)} ${y} 500`);
  p.sleep(1600);
  const after = eyeLabel();
  // 自检:数字没变就是根本没拖到,后面的"仍是 0.00"不算证据
  p.expectTrue('拖动确实改变了视线高度(仪器自检)', after !== before, `拖前「${before}」拖后「${after}」`);
  p.shot('measure-eye-raised');
  p.expect('空筒抬高视线后读数仍是 0.00 mL', readingValue(), '0.00 mL');
}

p.say('== 3. 收手判定后重来:两格必须一起归零 ==');
p.tap('开始倾倒');
p.tap('停止并判定', 2000);
p.shot('measure-judged');
p.tap('重来', 2000);
p.shot('measure-reset');
p.expect('重来后读数归零', readingValue(), '0.00 mL');
p.expectTrue('重来后判定卡已收起',
  !p.dumpNodes().some((a) => (a.text || '').startsWith('实际 0.00 mL，读数')), '判词还留在屏幕上');

const code = p.finish(`截图在 ${outDir}`);
process.exit(code === 0 ? 0 : 1);
