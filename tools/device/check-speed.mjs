/**
 * 第 14 个实验「测量物体运动的速度」的设备侧检查。
 *
 * 这条手里是机械停表,不是打点计时器。所以设备侧要量的是:
 * ① 按下与松开真的成对留下一次测量(次数、区间、时长三格都在动);
 * ② 「重置」只让车重来 —— 已经抄下的三次不能被抹掉(学生是抄表的那个人);
 * ③ 认真测完交卷是 100 分。
 *
 * 两个按钮的坐标一次抓好后连着用:走一次 dump 要点七八秒,车早到底了,
 * 那样测出来的"上半程"根本不是上半程。按下停表放在放车之前,否则起点已经不是 0。
 *
 * 运行:node tools/device/check-speed.mjs [--install <hap 路径>] [--out <截图目录>]
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
const TITLE = '测量物体运动的速度';
const p = new Probe({ tag: 'speed', outDir: outDir });

function texts() {
  return p.dumpNodes().map((a) => a.text || '').filter((t) => t.length > 0);
}

function readout(label) {
  const list = texts();
  const at = list.indexOf(label);
  return at >= 0 && at + 1 < list.length ? list[at + 1] : '';
}

function numOf(label) {
  const raw = readout(label).replace(/[^0-9.\-]/g, ' ').trim().split(/\s+/)[0];
  return raw === undefined || raw.length === 0 ? Number.NaN : Number.parseFloat(raw);
}

function scrollToText(label) {
  p.scrollToTop();
  for (let i = 0; i < 10; i++) {
    if (texts().some((t) => t.indexOf(label) === 0)) {
      p.sleep(1200);
      return true;
    }
    p.swipe(EDGE, 1900, EDGE, 900);
    p.sleep(700);
  }
  return false;
}

/** 一次 dump 里同时看到两个按钮就抓下坐标,后面按时间点点它们,不再重新取树 */
function capturePair(first, second) {
  p.scrollToTop();
  for (let i = 0; i < 12; i++) {
    const nodes = p.dumpNodes();
    const a = nodes.find((n) => (n.text || '') === first);
    const b = nodes.find((n) => (n.text || '') === second);
    if (a !== undefined && b !== undefined) {
      return { a: Probe.center(a.bounds), b: Probe.center(b.bounds) };
    }
    p.swipe(EDGE, 1900, EDGE, 1500);
    p.sleep(500);
  }
  p.fail(`同时看到「${first}」与「${second}」`, '两个按钮没能同时出现在一屏里');
  return null;
}

function fire(at) {
  p.shell(`uitest uiInput click ${at[0]} ${at[1]}`);
  p.sleep(400);
}

/** 控制行那颗按钮:运行中印「暂停」,停下印「开始」 */
function runButtonLabel() {
  const list = texts();
  if (list.includes('暂停')) return '暂停';
  return list.includes('开始') ? '开始' : '';
}

/** 让车停在起点:还在跑就按一次暂停 */
function ensureStopped() {
  if (runButtonLabel() === '暂停') p.tap('暂停', 800);
}

/**
 * 测一段:按下停表 → 等 waitMs → 松开 → 重置让车回来。
 *
 * 没有"再按一下开始"这一步 —— 按下停表这个动作本身就会放车
 * (外壳的 pressAction 写着"按了就跑",免得学生看到"数字在动、车不动")。
 * 所以按下停表的那一刻既是计时起点也是释放点,正好是这条实验要的理想操作。
 */
function trial(pair, waitMs) {
  ensureStopped();
  fire(pair.a);
  p.sleep(waitMs);
  fire(pair.b);
  p.tap('重置', 1200);
}

p.say(`设备:${p.assertDevice()}`);
if (hapPath !== null) p.install(hapPath.replace(/\\/g, '/'));
p.launch();

p.say('== 1. 第 14 张卡能滚到、能点开 ==');
p.ensureHome();
if (!p.tapInList(TITLE)) process.exit(1);
p.expectTrue('标题出现在实验页', texts().filter((t) => t === TITLE).length >= 1, texts().slice(0, 3).join(' / '));
scrollToText('按下停表');
p.expectTrue('「按下停表」与「松开停表」都在',
  texts().some((t) => t === '按下停表') && texts().some((t) => t === '松开停表'),
  texts().filter((t) => t.indexOf('停表') >= 0).join(' / '));

p.say('== 2. 三次测量:上半程一次、全程两次(重置不该抹掉记录)==');
const pair = capturePair('按下停表', '松开停表');
if (pair === null) process.exit(1);
trial(pair, 700);
trial(pair, 2600);
trial(pair, 2600);
scrollToText('按完的次数');
p.expect('按完三次', readout('按完的次数'), '3 次');
p.expect('覆盖两段不同区间', readout('测到的不同区间'), '2 段');
scrollToText('最长一段用的时间');
const longest = numOf('最长一段用的时间');
p.expectTrue('最长一段走得到 1.5 s 以上', longest >= 1.5 && longest < 2.4,
  `实得「${readout('最长一段用的时间')}」`);
p.shot('speed-three-trials');

p.say('== 3. 认真测完交卷:细则必须能被满足 ==');
scrollToText('交卷评分');
const submit = p.dumpNodes().find((n) => (n.text || '') === '交卷评分');
if (submit === undefined) {
  p.fail('找到「交卷评分」', '屏幕上没有这个按钮');
} else {
  fire(Probe.center(submit.bounds));
  p.sleep(1800);
  const graded = texts().find((t) => t.indexOf('得分') === 0) || '';
  p.expectTrue('判词出现且是满分', graded.indexOf('得分 100') === 0, graded || '没有判词');
  p.expectTrue('参考细则来源必须露出(不得伪装成官方标准)',
    texts().some((t) => t.indexOf('参考细则') >= 0), '');
}
p.shot('speed-graded');

const code = p.finish(`截图在 ${outDir}`);
process.exit(code === 0 ? 0 : 1);
