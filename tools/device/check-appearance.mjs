/**
 * 深浅色档的设备侧断言。
 *
 * 期望值不写死在这里 —— 直接从两套调色板里读 `accent`,所以改了色板不用改脚本
 * (改了脚本不改色板那种"把期望值改成实得值"的做法,等于把断言删掉)。
 *
 * 判据取的是 dumpLayout 里"当前选中那颗 chip 的 backgroundColor":那是系统解析后的 ARGB,
 * 也就是"资源有没有按深浅档重解"的直接证据。未选中的 chip 报 #00000000(底由内部节点画),
 * 所以不能拿它当探针。
 *
 * 运行:node tools/device/check-appearance.mjs [--out <截图目录>]
 */
import { readFileSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import os from 'node:os';
import { Probe } from './probe.mjs';

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const outArg = process.argv.indexOf('--out');
const outDir = outArg > -1 ? process.argv[outArg + 1] : join(os.tmpdir(), 'simlab-probe');

const accentOf = (mode) => {
  const raw = JSON.parse(readFileSync(join(REPO, 'entry/src/main/resources', mode, 'element/color.json'), 'utf8'));
  const hit = raw.color.find((c) => c.name === 'accent');
  if (hit === undefined) throw new Error(`${mode} 调色板里没有 accent`);
  // dumpLayout 报的是解析后的 ARGB(带 #、8 位),所以期望值也按同一形状拼
  return hit.value.length === 7 ? '#FF' + hit.value.slice(1) : hit.value.toUpperCase();
};

const LIGHT = accentOf('base');
const DARK = accentOf('dark');
const CHIPS = ['跟随系统', '浅色', '深色'];

const p = new Probe({ tag: 'appearance', outDir: outDir });
p.say(`调色板 accent:浅色 ${LIGHT} / 深色 ${DARK}`);
p.say(`设备:${p.assertDevice()}`);

function openSettings() {
  p.ensureHome();
  p.tap('深浅色');
}

p.say('== 1. 三档都在,默认说明是「跟随系统」 ==');
p.launch();
openSettings();
for (const c of CHIPS) {
  p.expectTrue(`chip「${c}」在屏幕上`, p.dumpNodes().some((a) => (a.text || '') === c), 'dumpLayout 里没有');
}
p.expectTrue('说明文案是中文而不是标识符',
  p.dumpNodes().some((a) => (a.text || '').startsWith('跟随系统：')), '没找到默认档说明');

p.say('== 2. 切浅色 / 切深色:底色必须按档重解 ==');
p.tap('浅色');
const light = p.selectedColor(CHIPS);
p.shot('appearance-light');
p.tap('深色');
const dark = p.selectedColor(CHIPS);
p.shot('appearance-dark');
p.expect('浅色档 accent', light, LIGHT);
p.expect('深色档 accent', dark, DARK);
p.expectTrue('两档确实不一样', light !== dark, `两档同为 ${light}:resources/dark 没被用上`);

p.say('== 3. 存盘与冷启动:盘上的档要在首帧就生效 ==');
p.launch();
openSettings();
p.expectTrue('重开后仍是深色(读到了盘上的值)',
  p.dumpNodes().some((a) => (a.text || '').startsWith('深色底：')), '档位没存住或没回放');
p.ensureHome();
p.expect('冷启动首帧 accent', p.selectedColor(['全部']), DARK);

p.say('== 4. 收尾:恢复跟随系统 ==');
openSettings();
p.tap('跟随系统');
p.expect('恢复后 accent(这台设备系统是浅色)', p.selectedColor(CHIPS), LIGHT);

const code = p.finish(`截图在 ${outDir}`);
process.exit(code === 0 ? 0 : 1);
