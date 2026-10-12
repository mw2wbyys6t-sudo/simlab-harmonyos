/**
 * 第 12 个实验「测量匀变速直线运动物体的加速度」的设备侧检查。
 *
 * 这条新加的是共用件"打点计时器 + 纸带",所以设备侧要看的不是数字对不对(离线已钉),
 * 而是三件只有屏幕上能判的事:
 * ① 「接通电源」与「释放小车」是两个分开的按钮,顺序反了会留下可量的后果;
 * ② 纸带真的画在画面上,点距是越往后越开(不是等距铺开);
 * ③ 按正确顺序做完,交卷应当是 100 分 —— 细则必须能被满足,这条当场量。
 *
 * 运行:node tools/device/check-tape.mjs [--install <hap 路径>] [--out <截图目录>]
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
const TITLE = '测量匀变速直线运动物体的加速度';
const p = new Probe({ tag: 'tape', outDir: outDir });

function texts() {
  return p.dumpNodes().map((a) => a.text || '').filter((t) => t.length > 0);
}

function readout(label) {
  const list = texts();
  const at = list.indexOf(label);
  return at >= 0 && at + 1 < list.length ? list[at + 1] : '';
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
    // 甩动没停就取坐标 = 点错行;每一下之后多等一拍
    p.sleep(700);
  }
  return false;
}

/** 滚到某个按钮并点它:目标必须落在屏幕中段,且两次 dump 位置一致才按 */
function tapByWalk(label, tries) {
  p.scrollToTop();
  const limit = tries || 12;
  for (let i = 0; i < limit; i++) {
    const hit = p.dumpNodes().find((a) => (a.text || '') === label);
    const m = hit === undefined ? null : hit.bounds.match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);
    const y = m === null ? 0 : Math.round((+m[2] + +m[4]) / 2);
    if (m !== null && y > 1200 && y < 2100) {
      p.sleep(800);
      const again = p.dumpNodes().find((a) => (a.text || '') === label);
      if (again !== undefined && again.bounds === hit.bounds) {
        p.shell(`uitest uiInput click ${Math.round((+m[1] + +m[3]) / 2)} ${y}`);
        p.sleep(1200);
        return true;
      }
      continue;
    }
    p.swipe(EDGE, 1900, EDGE, 1500);
    p.sleep(500);
  }
  p.fail(`滚到并点开「${label}」`, `${limit} 次小步滚动后仍没稳定出现在屏幕中段`);
  return false;
}

/** 在同一次 dump 里连着按两个按钮:中间不重新取树,所以两下之间的真实间隔只有一帧。
    这条实验判的就是这个间隔 —— 隔着一次 dump(约 1 s)按,计时器会打出上百个重叠点,
    默认的计数起点就舍不开了,判"起点太靠前"是对的,不是 bug。 */
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

p.say(`设备:${p.assertDevice()}`);
if (hapPath !== null) p.install(hapPath.replace(/\\/g, '/'));
p.launch();

p.say('== 1. 通电与释放是两个按钮 ==');
p.ensureHome();
if (!p.tapInList(TITLE)) process.exit(1);
p.expectTrue('标题出现在实验页', texts().filter((t) => t === TITLE).length >= 1, texts().slice(0, 3).join(' / '));
scrollToText('接通／断开电源');
p.expectTrue('「接通／断开电源」与「释放小车」都在',
  texts().some((t) => t === '接通／断开电源') && texts().some((t) => t === '释放小车'),
  texts().filter((t) => t.indexOf('电源') >= 0 || t.indexOf('释放') >= 0).join(' / '));

p.say('== 2. 按正确顺序做一遍:先通电,再放车 ==');
p.tap('开始');
tapPairInOneGo('接通／断开电源', '释放小车');
p.sleep(3500);
// 滚到"实时读数"这一格标题不够:八行读数会顶出视口,要滚到具体那一行再读
scrollToText('纸带上的点数');
const dots = readout('纸带上的点数');
p.expectTrue('纸带上打出了一串点', Number.parseInt(dots, 10) > 60, `实得「${dots}」`);
p.expectTrue('逐差法用得起来的段数(≥4 段)',
  Number.parseInt(readout('切出的计数段数'), 10) >= 4, `实得「${readout('切出的计数段数')}」`);
const shortest = readout('最短计数段');
p.expectTrue('最短一段在毫米级读得出来', parseFloat(shortest) >= 2, `实得「${shortest}」`);
scrollToText('头一段漏打的点数');
p.expect('顺序对了就不该漏头', readout('头一段漏打的点数'), '0 个');
p.shot('tape-run');

p.say('== 3. 认真做完交卷:细则必须能被满足 ==');
tapByWalk('交卷评分');
const graded = texts().find((t) => t.indexOf('得分') === 0) || '';
p.expectTrue('判词出现且是满分', graded.indexOf('得分 100') === 0, graded || '没有判词');
p.expectTrue('参考细则来源必须露出(不得伪装成官方标准)',
  texts().some((t) => t.indexOf('参考细则') >= 0), '');
p.shot('tape-graded');

p.say('== 4. 反过来做:先放车再通电,应当被扣且漏打点数变大 ==');
p.tap('重置', 1500);
p.tap('开始');
tapPairInOneGo('释放小车', '接通／断开电源');
p.sleep(3000);
scrollToText('头一段漏打的点数');
const lost = Number.parseInt(readout('头一段漏打的点数'), 10);
p.expectTrue('先放车确实漏了头一段', lost > 5, `实得「${readout('头一段漏打的点数')}」`);
p.shot('tape-lost-head');

const code = p.finish(`截图在 ${outDir}`);
process.exit(code === 0 ? 0 : 1);
