/**
 * 第 10 个实验「探究电流与电压、电阻的关系」的设备侧链路检查。
 *
 * 离线 harness 已经钉住电路与判分,这里只测**只有屏幕能测的东西**:
 * ① 首页那张卡真的能滚到、能点开;
 * ② 「记录」这个动作从按钮一路走到读数格(动作 → runner → observable → Text 这条链);
 * ③ 拖动滑杆改的是电路而不是面板上的数字;
 * ④ 「交卷评分」出现并印出带数字的扣分。
 *
 * 运行:node tools/device/check-ohm.mjs [--install <hap 路径>] [--out <截图目录>]
 */
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import os from 'node:os';
import { Probe } from './probe.mjs';

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const outArg = process.argv.indexOf('--out');
const outDir = outArg > -1 ? process.argv[outArg + 1] : join(os.tmpdir(), 'simlab-probe');
const installArg = process.argv.indexOf('--install');
const hapPath = installArg > -1 ? process.argv[installArg + 1] : null;

const TITLE = '探究电流与电压、电阻的关系';
const p = new Probe({ tag: 'ohm', outDir: outDir });

function texts() {
  return p.dumpNodes().map((a) => a.text || '').filter((t) => t.length > 0);
}

/** 读数卡里标签下面那一格:读数与标签是相邻的两个 Text 节点 */
function readout(label) {
  const list = texts();
  const at = list.indexOf(label);
  return at >= 0 && at + 1 < list.length ? list[at + 1] : '';
}

/** 回到页顶再一路往下找。只朝一个方向滚不行:读数在参数下面,找参数时页面正停在读数那一段 */
function scrollToText(label, tries) {
  p.scrollToTop();
  const limit = tries || 8;
  for (let i = 0; i < limit; i++) {
    if (texts().some((t) => t.indexOf(label) === 0)) return true;
    p.swipe(628, 1900, 628, 900);
  }
  return false;
}

/** 找某个参数标签正下方最近的那根滑杆 */
function sliderUnder(label) {
  const nodes = p.dumpNodes();
  let labelBox = null;
  for (const n of nodes) {
    if ((n.text || '') === label) labelBox = n.bounds;
  }
  if (labelBox === null) return null;
  const top = (b) => +b.match(/\[(\d+),(\d+)\]/)[2];
  const labelTop = top(labelBox);
  let best = null;
  for (const n of nodes) {
    if (n.type !== 'Slider') continue;
    if (top(n.bounds) <= labelTop) continue;
    if (best === null || top(n.bounds) < top(best.bounds)) best = n;
  }
  return best;
}

/** 把滑杆拖到全程的 fraction 处,返回参数值文本是否真的变了 */
function dragSlider(label, fraction) {
  const before = readout(label);
  const slider = sliderUnder(label);
  if (slider === null) {
    p.fail(`找到「${label}」滑杆`, 'dumpLayout 里没有匹配的 Slider');
    return false;
  }
  const m = slider.bounds.match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);
  const x1 = +m[1];
  const x2 = +m[3];
  const y = Math.round((+m[2] + +m[4]) / 2);
  p.shell(`uitest uiInput swipe ${x1 + 20} ${y} ${Math.round(x1 + (x2 - x1) * fraction)} ${y} 500`);
  p.sleep(1200);
  return readout(label) !== before;
}

p.say(`设备:${p.assertDevice()}`);
if (hapPath !== null) p.install(hapPath.replace(/\\/g, '/'));
p.launch();

p.say('== 1. 首页:第 10 张卡能滚到、能点开 ==');
p.ensureHome();
if (!p.tapInList(TITLE)) process.exit(1);
p.expectTrue('标题出现在实验页', texts().filter((t) => t === TITLE).length >= 1, texts().slice(0, 4).join(' / '));
p.expectTrue('说明用的是全角分号(半角会被判成 AI 直出)',
  texts().some((t) => t.indexOf('先保持定值电阻不变') === 0 && t.includes('；')), '没找到说明或说明里是半角');

p.say('== 2. 记录动作要从按钮一路走到读数格 ==');
p.tap('开始');
scrollToText('记录这一组');
p.tap('记录这一组 U 和 I');
scrollToText('实时读数');
p.expect('第一组读数后「已记录组数」', readout('已记录组数'), '1 组');
p.expect('同一电阻下先只有一档', readout('同一电阻下的电压档数'), '1 档');

p.say('== 3. 拖动滑杆改的是电路:电压读数必须跟着变 ==');
const uBefore = readout('定值电阻两端电压 U');
scrollToText('滑动变阻器');
const moved = dragSlider('滑动变阻器 R′', 0.35);
p.expectTrue('拖动确实改动了阻值(仪器自检)', moved, `拖前 U=${uBefore}`);
scrollToText('记录这一组');
p.tap('记录这一组 U 和 I');
scrollToText('实时读数');
const uAfter = readout('定值电阻两端电压 U');
p.expectTrue('换了滑片位置后电压读数变了', uAfter !== uBefore && uAfter.length > 0,
  `拖前「${uBefore}」拖后「${uAfter}」`);
p.expect('同一电阻下变成两档', readout('同一电阻下的电压档数'), '2 档');
p.shot('ohm-two-steps');

p.say('== 4. 交卷评分:细则名与带数字的扣分都要印出来 ==');
scrollToText('交卷评分', 8);
p.tap('交卷评分', 2200);
const verdict = texts().filter((t) => t.indexOf('得分') === 0 || t.indexOf('评分依据') >= 0);
p.expectTrue('判词出现且带分数', verdict.length > 0, texts().slice(0, 6).join(' / '));
p.expectTrue('参考细则来源必须露出(不得伪装成官方标准)',
  texts().some((t) => t.indexOf('参考细则') >= 0), verdict.join(' / '));
p.expectTrue('扣分证据里带着量出来的数',
  texts().some((t) => /档|种|组/.test(t) && /\d/.test(t)), '没有带数字的事实行');
p.shot('ohm-graded');

p.say('== 5. 第三档电压 + 展开图线:I–U 图要按记录描点 ==');
scrollToText('滑动变阻器');
dragSlider('滑动变阻器 R′', 0.7);
scrollToText('记录这一组');
p.tap('记录这一组 U 和 I');
scrollToText('实时读数');
p.expect('同一电阻下凑满三档', readout('同一电阻下的电压档数'), '3 档');
scrollToText('展开图线');
p.tap('展开图线', 1800);
// 图名是画在画布上的,dumpLayout 取不到;能取到的是按钮翻成「收起图线」——
// 说明图区真的展开了(标题与描点由离线断言和截图各自盯一半)
p.expectTrue('图线已展开(按钮翻成「收起图线」)',
  texts().some((t) => t === '收起图线'), texts().slice(2, 8).join(' / '));
p.shot('ohm-chart');

const code = p.finish(`截图在 ${outDir}`);
process.exit(code === 0 ? 0 : 1);
