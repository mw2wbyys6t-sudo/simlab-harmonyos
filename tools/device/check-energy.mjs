/**
 * 第 13 个实验「验证机械能守恒定律」的设备侧检查。
 *
 * 纸带那条共用件第二次上机,所以这里只测这条独有的两件事:
 * ① 屏幕上 ΔEp 与 ΔEk 两格必须一个比一个小(阻力那条账看得见);
 * ② 「第一对点约 2 mm」这条教材判据真的能在读数区里读到,反序操作会把它推高。
 *
 * 运行:node tools/device/check-energy.mjs [--install <hap 路径>] [--out <截图目录>]
 */
import { join } from 'node:path';
import os from 'node:os';
import { Probe } from './probe.mjs';

const outArg = process.argv.indexOf('--out');
const outDir = outArg > -1 ? process.argv[outArg + 1] : join(os.tmpdir(), 'simlab-probe');
const installArg = process.argv.indexOf('--install');
const hapPath = installArg > -1 ? process.argv[installArg + 1] : null;

// 走左侧留白滚:参数滑杆占满 98..1158,手势落在轨道上会把值跳到那个 x
const EDGE = 60;
const TITLE = '验证机械能守恒定律';
const p = new Probe({ tag: 'energy', outDir: outDir });

function texts() {
  return p.dumpNodes().map((a) => a.text || '').filter((t) => t.length > 0);
}

function readout(label) {
  const list = texts();
  const at = list.indexOf(label);
  return at >= 0 && at + 1 < list.length ? list[at + 1] : '';
}

/** 读数区里那格的数值(去掉单位);读不到就是 NaN */
function numOf(label) {
  const raw = readout(label).replace(/[^0-9.\-]/g, ' ').trim().split(/\s+/)[0];
  return raw === undefined || raw.length === 0 ? Number.NaN : Number.parseFloat(raw);
}

function scrollToText(label, tries) {
  p.scrollToTop();
  const limit = tries || 10;
  for (let i = 0; i < limit; i++) {
    if (texts().some((t) => t.indexOf(label) === 0)) {
      p.sleep(1200);
      return true;
    }
    p.swipe(EDGE, 1900, EDGE, 900);
    p.sleep(700);
  }
  return false;
}

/** 同一次 dump 里连着按两个按钮:这两个动作的间隔本身就是被判的事实 */
function tapPairInOneGo(first, second) {
  p.scrollToTop();
  for (let i = 0; i < 12; i++) {
    const nodes = p.dumpNodes();
    const a = nodes.find((n) => (n.text || '') === first);
    const b = nodes.find((n) => (n.text || '') === second);
    if (a !== undefined && b !== undefined) {
      const ca = Probe.center(a.bounds);
      const cb = Probe.center(b.bounds);
      p.shell(`uitest uiInput click ${ca[0]} ${ca[1]}`);
      p.shell(`uitest uiInput click ${cb[0]} ${cb[1]}`);
      p.sleep(1200);
      return true;
    }
    p.swipe(EDGE, 1900, EDGE, 1500);
    p.sleep(500);
  }
  p.fail(`连着按下「${first}」与「${second}」`, '两个按钮没能同时出现在一屏里');
  return false;
}

function tapByWalk(label) {
  p.scrollToTop();
  for (let i = 0; i < 12; i++) {
    const hit = p.dumpNodes().find((a) => (a.text || '') === label);
    const m = hit === undefined ? null : hit.bounds.match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);
    const y = m === null ? 0 : Math.round((+m[2] + +m[4]) / 2);
    if (m !== null && y > 1200 && y < 2100) {
      p.sleep(800);
      const again = p.dumpNodes().find((a) => (a.text || '') === label);
      if (again !== undefined && again.bounds === hit.bounds) {
        p.shell(`uitest uiInput click ${Math.round((+m[1] + +m[3]) / 2)} ${y}`);
        p.sleep(2200);
        return true;
      }
      continue;
    }
    p.swipe(EDGE, 1900, EDGE, 1500);
    p.sleep(500);
  }
  p.fail(`滚到并点开「${label}」`, '没能稳定出现在屏幕中段');
  return false;
}

p.say(`设备:${p.assertDevice()}`);
if (hapPath !== null) p.install(hapPath.replace(/\\/g, '/'));
p.launch();

p.say('== 1. 第 13 张卡能滚到、能点开 ==');
p.ensureHome();
if (!p.tapInList(TITLE)) process.exit(1);
p.expectTrue('标题出现在实验页', texts().filter((t) => t === TITLE).length >= 1, texts().slice(0, 3).join(' / '));
scrollToText('接通／断开电源');
p.expectTrue('「接通／断开电源」与「松开纸带」都在',
  texts().some((t) => t === '接通／断开电源') && texts().some((t) => t === '松开纸带'),
  texts().filter((t) => t.indexOf('电源') >= 0 || t.indexOf('松') >= 0).join(' / '));

p.say('== 2. 先通电再松手:纸带与能量两笔账都要看得见 ==');
p.tap('开始');
tapPairInOneGo('接通／断开电源', '松开纸带');
p.sleep(2500);
scrollToText('纸带上的点数');
p.expectTrue('纸带上的点够多', numOf('纸带上的点数') >= 10, `实得「${readout('纸带上的点数')}」`);
const gap = numOf('第一对点的间距');
// 这条判据是单向的:明显大于 2 mm 才说明"打第一个点时已经在下落"。
// 小于 2 mm 只是松手比第一个点晚了几毫秒,初速度依然为零(实测 0.21 mm 就是这么来的)。
p.expectTrue('第一对点没有超过 2 mm(初速度为零)', gap > 0 && gap <= 2.6, `实得「${readout('第一对点的间距')}」`);
p.expectTrue('切得出三段以上', numOf('切出的计数段数') >= 3, `实得「${readout('切出的计数段数')}」`);
scrollToText('减少的重力势能');
const ep = numOf('减少的重力势能 ΔEp');
const ek = numOf('增加的动能 ΔEk');
p.expectTrue('ΔEp 与 ΔEk 都量到了数', Number.isFinite(ep) && Number.isFinite(ek), `ΔEp「${readout('减少的重力势能 ΔEp')}」ΔEk「${readout('增加的动能 ΔEk')}」`);
p.expectTrue('ΔEk 比 ΔEp 小(阻力做负功)', ek < ep && ek > 0, `${ek} vs ${ep}`);
p.shot('energy-run');

p.say('== 3. 认真做完交卷:细则必须能被满足 ==');
tapByWalk('交卷评分');
const graded = texts().find((t) => t.indexOf('得分') === 0) || '';
p.expectTrue('判词出现且是满分', graded.indexOf('得分 100') === 0, graded || '没有判词');
p.expectTrue('参考细则来源必须露出(不得伪装成官方标准)',
  texts().some((t) => t.indexOf('参考细则') >= 0), '');
p.shot('energy-graded');

p.say('== 4. 先松手再通电:第一对点就不是 2 mm 了 ==');
p.tap('重置', 1500);
p.tap('开始');
tapPairInOneGo('松开纸带', '接通／断开电源');
p.sleep(2500);
scrollToText('第一对点的间距');
const late = numOf('第一对点的间距');
p.expectTrue('反序操作把第一对点推离 2 mm', late > 2.6, `实得「${readout('第一对点的间距')}」`);
p.shot('energy-late-power');

const code = p.finish(`截图在 ${outDir}`);
process.exit(code === 0 ? 0 : 1);
