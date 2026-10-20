/**
 * 共用件 probe.mjs 自己的检查(I1 与 I7 的证明,不碰设备)。
 *
 * 为什么要有这个文件:修复轮 1 要求证明"两台在线时不许猜设备""认不出键盘时不许报成功"。
 * 这两件事在只有一台模拟器的机器上没法用真设备证明(5557 今天没在监听,内存也不够再起一台),
 * 而"复现不了的测量不许写进报告"是本项目自己的规矩。所以做成合成输入的检查:
 * 输入的形状与字段全部抄自本轮真设备上跑出来的日志(`task10-logs/f1-*.log` 与
 * `task10-logs/stage-*.log`:窗口分布、键帽 bounds、hdc 的告警行都是实测形状),
 * 但**这是合成输入,不是真设备证明** —— 两件事别混着说。
 *
 * 运行:node tools/device/check-probe.mjs
 */
import { writeFileSync, appendFileSync, readFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Probe } from './probe.mjs';

const DIR = join(tmpdir(), 'simlab-probe-selftest');
const LOG = join(DIR, 'argv.log');
mkdirSync(DIR, { recursive: true });
writeFileSync(LOG, '');

/**
 * 假 hdc:按参数回放固定输出,并把整条 argv 记进 argv.log。
 * 回放的每一行都是今天从真 hdc 上抄下来的形状 —— 包括那条**带数字的错误码**
 * `[Fail][E001005] Device not found or connected`(旧版按 /\d/ 挑设备行时,它就被数成一台)。
 *
 * 为什么是一个函数而不是一个假二进制:上一版在这里写了一个 `hdc.cmd`,而 Windows 上
 * `execFileSync` 根本起不了 .cmd(直接 EINVAL,整份自检崩在半路)。所以 probe.mjs 留了
 * `spawn` 这个注入点,默认仍是 execFileSync —— 生产路径一行没变,变的只是这里能看着真 argv 判。
 */
function fakeHdc(bin, args) {
  appendFileSync(LOG, args.join(' ') + '\n');
  if (args[0] === 'list') {
    return '[Fail][E001005] Device not found or connected\r\n127.0.0.1:5555\r\n127.0.0.1:5557\r\n';
  }
  if (args.indexOf('install') >= 0) {
    return 'install bundle successfully\r\n';
  }
  return 'ok\n';
}

/** 每次都造一个 Probe,spawn 一律走假 hdc */
function mkProbe(opts) {
  return new Probe(Object.assign({ hdc: 'fake-hdc', spawn: fakeHdc }, opts));
}

let fails = 0;
function ok(label) {
  console.log('  ok  ' + label);
}
function expectTrue(label, cond, detail) {
  if (cond) {
    ok(label);
  } else {
    fails++;
    console.log('  FAIL ' + label + ' —— ' + detail);
  }
}


console.log('== 1. 两台在线 + 一堆带数字的告警:不许猜,而告警行也不算设备 ==');
delete process.env.SIMLAB_TARGET;
let threw = null;
try {
  mkProbe({ tag: 'selftest-1' }).assertDevice();
} catch (e) {
  threw = e.message;
}
expectTrue('两台在线又没点名 → 大声拒绝(旧版要么挑 lines[0],要么被 hdc 拒成"need connect-key?")',
  threw !== null && threw.indexOf('不许猜') > 0 && threw.indexOf('127.0.0.1:5557') > 0,
  '实得:' + String(threw));

const counted = Probe.deviceLines([
  '[Fail][E001005] Device not found or connected',
  '[F][2026-10-19 19:43:57] open path:x, error:no such file, dir:0, master:1',
  '[Fail]Connect failed',
  '[Empty]',
  '  127.0.0.1:5555  ',
  'FMR0224407000269',
  '127.0.0.1:5557\t\tTCP\tOffline\tlocalhost\thdc'
].join('\r\n'));
expectTrue('告警行不算设备(旧版按 /\\d/ 挑行,把这两条告警也数成了机器)',
  // 5557 那一行在同一份输出里写着 Offline,所以它也不算一台(见下面第 3 段)
  counted.join(',') === '127.0.0.1:5555,FMR0224407000269',
  '实得:' + counted.join(','));
const onlyWarn = Probe.deviceLines('[Fail][E001005] Device not found or connected\r\n[Empty]\r\n');
expectTrue('全是告警时算出 0 台(而不是"有一台在线,就用它")', onlyWarn.length === 0,
  '实得:' + onlyWarn.join(','));

console.log('== 2. install() 也必须带 -t(旧版是全文件唯一一条绕过 shellExec 的调用) ==');
mkProbe({ tag: 'selftest-2', target: '127.0.0.1:5555' }).install(DIR + '/fake.hap');
const argv = readFileSync(LOG, 'utf8');
expectTrue('装包命令行里带着 -t 与点名的那台',
  argv.indexOf('-t 127.0.0.1:5555 install -r fake.hap') > 0, 'argv.log:' + argv.trim());

let noTargetThrew = null;
try {
  mkProbe({ tag: 'selftest-3' }).install(DIR + '/fake.hap');
} catch (e) {
  noTargetThrew = e.message;
}
expectTrue('没先点名就不装(装到另一台上也照样回 install bundle successfully,那测的就不是这个构建)',
  noTargetThrew !== null && noTargetThrew.indexOf('assertDevice') > 0, '实得:' + String(noTargetThrew));

let offlineThrew = null;
try {
  mkProbe({ tag: 'selftest-4', target: '127.0.0.1:4545' }).assertDevice();
} catch (e) {
  offlineThrew = e.message;
}
expectTrue('点名的那台不在清单里 → 报清楚,不静默换一台',
  offlineThrew !== null && offlineThrew.indexOf('不在线') > 0, '实得:' + String(offlineThrew));

console.log('== 3. 带状态的行:Offline 那一台不算在线 ==');
const withOffline = Probe.deviceLines('127.0.0.1:5555\r\n127.0.0.1:5557\t\tTCP\tOffline\tlocalhost\thdc\r\n');
expectTrue('Offline 的那一行不算一台在线设备(否则单台在线会被逼着点名)',
  withOffline.join(',') === '127.0.0.1:5555', '实得:' + withOffline.join(','));
const allOffline = Probe.deviceLines('127.0.0.1:5557\t\tTCP\tOffline\tlocalhost\thdc\r\n');
expectTrue('只剩 Offline 时算出 0 台(报"没有设备在线",而不是拿一台休眠的去测)',
  allOffline.length === 0, '实得:' + allOffline.join(','));

console.log('== 4. 键盘三态(I7):认不出来不许报"已收起" ==');
// 窗口分布抄自 f1-b.log 的实测形状:应用 root=185,状态栏 27 的节点全在 y 0..136,
// 键盘支起来时多一个 228(几十上百个节点压在屏幕下半部)。
const APP = (b) => ({ type: 'Text', hostWindowId: '185', bounds: b });
const root = { type: 'root', hostWindowId: '185', bounds: '[0,0][1260,2760]' };
const scene = { type: 'WindowScene', hostWindowId: '185', bounds: '[0,0][1260,2760]' };
const statusBar = { type: 'Text', hostWindowId: '27', bounds: '[40,60][200,136]' };
const appNodes = [root, scene, statusBar, APP('[98,1468][1052,1608]'), APP('[98,2413][1052,2553]')];
const down = mkProbe({ tag: 'selftest-5' }).imeState(appNodes);
expectTrue('屏幕下半部没有外来节点 → down(真收起了)',
  down.state === 'down', JSON.stringify(down));
const keycaps = [228, 228, 228, 228, 228].map((w, i) => ({
  type: 'Text', hostWindowId: String(w), bounds: `[${60 + i * 200},2620][${200 + i * 200},2700]`
}));
const up = mkProbe({ tag: 'selftest-6' }).imeState(appNodes.concat(keycaps));
expectTrue('压在下半部、键帽数得出 ≥3 颗 → up,top 是键帽上沿',
  up.state === 'up' && up.top === 2620, JSON.stringify(up));
const blob = { type: 'Image', hostWindowId: '228', bounds: '[0,1700][1260,2760]' };
const unknown = mkProbe({ tag: 'selftest-7' }).imeState(appNodes.concat([blob]));
expectTrue('压在下半部却数不出键帽 → unknown(旧版这一档报的是"已收起",那是假绿)',
  unknown.state === 'unknown', JSON.stringify(unknown));
const noRoot = mkProbe({ tag: 'selftest-8' }).imeState([APP('[98,1468][1052,1608]')]);
expectTrue('树里连应用 root 都没有 → unknown,不猜',
  noRoot.state === 'unknown', JSON.stringify(noRoot));

console.log('== 5. hideKeyboard 在认不出键盘时不许报"收好了" ==');
// 只把"读设备树"这一件事桩掉(它要真模拟器),hideKeyboard 自己的判定逻辑一行没换。
const pUnknown = mkProbe({ tag: 'selftest-9' });
pUnknown.dumpNodes = () => appNodes.concat([blob]);
const rUnknown = pUnknown.hideKeyboard();
expectTrue('数不出键帽 → 返回 unknown,不是 down(I7 的整条理由就在这)',
  rUnknown === 'unknown', '实得:' + String(rUnknown));
const pDown = mkProbe({ tag: 'selftest-10' });
pDown.dumpNodes = () => appNodes;
expectTrue('屏幕下半部干净 → 返回 down', pDown.hideKeyboard() === 'down', '实得:非 down');
const pUp = mkProbe({ tag: 'selftest-11' });
let pUpReads = 0;
pUp.dumpNodes = () => (pUpReads++ === 0 ? appNodes.concat(keycaps) : appNodes);
expectTrue('键盘在、Escape 之后干净 → down(它确实会重试,不是一把就放弃)',
  pUp.hideKeyboard() === 'down' && pUpReads >= 2, '实得读树次数:' + pUpReads);

console.log('== 6. 哪个窗口是应用:按输入框认,不按 root 的先后、也不按节点数 ==');
// 本轮实测的窗口分布:`185:48 280:47 27:37` —— 应用与输入法只差一颗节点,而 root 的先后顺序
// 会随键盘支起/收起变。旧版取"第一个 root",取错就把应用的节点全当成外来窗口,
// 键盘状态判 unknown,连带 typeInto 失败(今天真在设备上是这么咬的)。
function many(id, n, yFrom) {
  const out = [];
  for (let i = 0; i < n; i++) {
    out.push({ type: 'Text', hostWindowId: id, bounds: `[40,${yFrom + i * 8}][300,${yFrom + i * 8 + 6}]` });
  }
  return out;
}
const imeFirst = [
  { type: 'root', hostWindowId: '280', bounds: '[0,1700][1260,2760]' },
  { type: 'root', hostWindowId: '185', bounds: '[0,0][1260,2760]' },
  { type: 'WindowScene', hostWindowId: '280', bounds: '[0,1700][1260,2760]' }
].concat(many('280', 46, 1720)).concat(many('185', 47, 200)).concat([
  { type: 'TextInput', hostWindowId: '185', bounds: '[98,1468][1052,1608]' }
]);
const win = mkProbe({ tag: 'selftest-12' });
expectTrue('输入法那一支的 root 排在前面,也不许把应用窗口认错(按 TextInput 归属认)',
  win.appWindow(imeFirst) === '185', '实得:' + String(win.appWindow(imeFirst)));
const imeState6 = win.imeState(imeFirst);
expectTrue('同一份树里键盘判 up,不是 unknown(旧版在这里判 unknown,连带打字失败)',
  imeState6.state === 'up', JSON.stringify(imeState6));
// 退回路径要单独一份树:上面那份去掉 TextInput 之后,输入法那一支节点数真的更多(49 vs 48),
// 拿它验"按节点数退回"验不出东西 —— 换一份应用明显更大、而 root 仍排在后面的。
const noFieldTree = [
  { type: 'root', hostWindowId: '280', bounds: '[0,1700][1260,2760]' },
  { type: 'root', hostWindowId: '185', bounds: '[0,0][1260,2760]' }
].concat(many('280', 20, 1720)).concat(many('185', 40, 200));
const fallbackWin = mkProbe({ tag: 'selftest-13' });
expectTrue('树里没有输入框时退回"节点最多的一支",而不是第一个 root',
  fallbackWin.appWindow(noFieldTree) === '185',
  '实得:' + String(fallbackWin.appWindow(noFieldTree)));
expectTrue('两份树都拿不到输入框、也没有 root 归属时 → null(宁可 unknown,不猜)',
  mkProbe({ tag: 'selftest-14' }).appWindow([{ type: 'Text', bounds: '[0,0][10,10]' }]) === null,
  '实得不为 null');

console.log(fails === 0 ? '\n全部通过' : `\n${fails} 项失败`);
process.exit(fails === 0 ? 0 : 1);
