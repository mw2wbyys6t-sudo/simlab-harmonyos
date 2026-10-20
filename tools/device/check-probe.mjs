/**
 * 共用件 probe.mjs 自己的检查(I1 与 I7 的证明,不碰设备)。
 *
 * 为什么要有这个文件:修复轮 1 要求证明"两台在线时不许猜设备""认不出键盘时不许报成功"。
 * 这两件事在只有一台模拟器的机器上没法用真设备证明(5557 今天没在监听,内存也不够再起一台),
 * 而"复现不了的测量不许写进报告"是本项目自己的规矩。所以做成合成输入的检查:
 * 输入的形状与字段全部抄自本轮实测的 hdc/uitest 输出(见 task10-logs/fix1-*.log)。
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
  counted.join(',') === '127.0.0.1:5555,FMR0224407000269,127.0.0.1:5557',
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
