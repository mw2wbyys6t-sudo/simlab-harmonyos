/**
 * 第 16 个实验「描绘简谐运动的图像」的设备侧检查。
 *
 * 这条的判分对象是学生**自己一下一下按出来的那幅图**,所以设备侧要量的是:
 * ① 外壳那张自动 x-t 图确实不在(摆在旁边就等于替学生描);
 * ② 正常手速连按几十下,覆盖到 1.5 个周期以上,「与真实曲线的最大差」应当只有厘米级,
 *    交卷是满分 —— 细则必须能被满足,这条当场量;
 * ③ 故意按到半个周期一下,同一格读数立刻涨过判分线,扣分点名"按得太慢"。
 * 走样在这里不是讲给学生的一句话,是他自己描出来、并且量得出差多少的东西。
 *
 * 运行:node tools/device/check-image.mjs [--install <hap 路径>] [--out <截图目录>]
 */
import { join } from 'node:path';
import os from 'node:os';
import { Probe } from './probe.mjs';

const outArg = process.argv.indexOf('--out');
const outDir = outArg > -1 ? process.argv[outArg + 1] : join(os.tmpdir(), 'simlab-probe');
const installArg = process.argv.indexOf('--install');
const hapPath = installArg > -1 ? process.argv[installArg + 1] : null;

const EDGE = 60;
const TITLE = '描绘简谐运动的图像';
const SAMPLE_LABEL = '记下这一个点';
const p = new Probe({ tag: 'image', outDir: outDir });

function texts() {
  return p.dumpNodes().map((a) => a.text || '').filter((t) => t.length > 0);
}

function rowOf(label) {
  const list = texts();
  const at = list.indexOf(label);
  return at >= 0 && at + 1 < list.length ? list[at + 1] : '';
}

/** 滚到某一格读数再读:一屏只放得下几行 */
function readout(label) {
  p.scrollToTop();
  for (let i = 0; i < 14; i++) {
    if (rowOf(label).length > 0) {
      p.sleep(900);
      return rowOf(label);
    }
    p.swipe(EDGE, 1900, EDGE, 900);
    p.sleep(600);
  }
  p.fail(`读到「${label}」`, '滚到底也没出现这一格读数');
  return '';
}

function numOf(label) {
  return parseFloat(readout(label));
}

/** 找到按钮并返回它屏幕上的中心点:连按之前只定位一次,免得每下都重滚一遍 */
function locate(label) {
  p.scrollToTop();
  for (let i = 0; i < 14; i++) {
    const node = p.dumpNodes().find((a) => (a.text || '') === label);
    if (node !== undefined) {
      return Probe.center(node.bounds);
    }
    p.swipe(EDGE, 1900, EDGE, 1500);
    p.sleep(500);
  }
  p.fail(`找到按钮「${label}」`, '滚到底也没找到');
  return null;
}

/** 连按 times 下,每下之间至少隔 gapMs 毫秒:模拟一个手速稳定的学生 */
function tapMany(center, times, gapMs) {
  for (let i = 0; i < times; i++) {
    p.shell(`uitest uiInput click ${center[0]} ${center[1]}`);
    p.sleep(gapMs);
  }
}

function verdict() {
  p.scrollToTop();
  for (let i = 0; i < 18; i++) {
    const hit = texts().find((t) => t.indexOf('得分') === 0);
    if (hit !== undefined) {
      p.sleep(700);
      return texts().find((t) => t.indexOf('得分') === 0) || '';
    }
    p.swipe(EDGE, 1900, EDGE, 1100);
    p.sleep(500);
  }
  return '';
}

function tapButton(label) {
  const c = locate(label);
  if (c === null) return false;
  p.shell(`uitest uiInput click ${c[0]} ${c[1]}`);
  p.sleep(900);
  return true;
}

p.say(`设备:${p.assertDevice()}`);
if (hapPath !== null) p.install(hapPath.replace(/\\/g, '/'));
p.launch();

p.say('== 1. 这条场景不给自动图线 ==');
p.ensureHome();
if (!p.tapInList(TITLE)) process.exit(1);
p.expectTrue('标题出现在实验页', texts().filter((t) => t === TITLE).length >= 1,
  texts().slice(0, 3).join(' / '));
p.expectTrue('屏幕上没有「展开图线」那颗按钮(描图是学生自己的事)',
  !texts().some((t) => t === '展开图线'), texts().filter((t) => t.indexOf('图线') >= 0).join(' / '));
const btn = locate(SAMPLE_LABEL);
if (btn === null) process.exit(1);

p.say('== 2. 正常手速连按:覆盖两个周期,失真只有厘米级 ==');
// 每次 uitest uiInput click 本身要 1.1 s 左右 —— 直接按等于"半个周期按一下",
// 那是自动化开销不是学生手速。把仿真调到 0.25x 慢放,1.1 s 墙上时间只走 0.29 s 仿真时间,
// 相当于学生每秒按三下:一个周期二十多个点,这才是"正常手速"该量出来的样子。
tapButton('0.25×');
tapMany(btn, 60, 60);
p.expectTrue('按了多少下就有多少个点', numOf('按下的取样点') >= 55,
  `实得「${readout('按下的取样点')}」`);
p.expectTrue('覆盖到 1.5 个周期以上', numOf('覆盖的周期数') > 1.5,
  `实得「${readout('覆盖的周期数')}」`);
const tight = numOf('与真实曲线的最大差');
p.expectTrue('描得够密:与真实曲线最大差不超过 15 cm', tight >= 0 && tight < 15,
  `实得「${readout('与真实曲线的最大差')}」`);
p.expectTrue('点铺开的位置范围接近两倍振幅', numOf('点铺开的位置范围') > 130,
  `实得「${readout('点铺开的位置范围')}」`);
p.shot('image-diligent');

p.say('== 3. 认真描完交卷:细则必须能被满足 ==');
tapButton('交卷评分');
const graded = verdict();
p.expectTrue('判词出现且是满分', graded.indexOf('得分 100') === 0, graded || '没有判词');
p.expectTrue('参考细则来源必须露出(不得伪装成官方标准)',
  texts().some((t) => t.indexOf('参考细则') >= 0), '');
p.shot('image-graded');

p.say('== 4. 重置=换一条纸带:描出来的点清零 ==');
tapButton('重置');
p.expect('纸带空了', readout('按下的取样点'), '0 个');

p.say('== 5. 故意按到半个周期一下:同一格读数立刻涨过判分线 ==');
const again = locate(SAMPLE_LABEL);
if (again === null) process.exit(1);
// 回到 1x:T≈8.9 s → 每 4.6 s 按一下就是半个周期一下,峰谷被错接成一段段直线
tapButton('1×');
tapMany(again, 14, 4600);
const sparse = numOf('与真实曲线的最大差');
p.expectTrue('按得稀:失真涨过 15 cm', sparse > 15, `实得「${readout('与真实曲线的最大差')}」`);
p.expectTrue('点数与覆盖都够,唯独太稀',
  numOf('按下的取样点') >= 12 && numOf('覆盖的周期数') > 1.5,
  `点 ${readout('按下的取样点')} / 覆盖 ${readout('覆盖的周期数')}`);
p.shot('image-aliased');
tapButton('交卷评分');
const sloppy = verdict();
const score = parseInt((sloppy.match(/得分\s+(\d+)/) || [])[1], 10);
p.expectTrue('失真这次真的扣分了', Number.isFinite(score) && score < 100, sloppy || '没有判词');
p.expectTrue('扣分理由点名「按得太慢」', sloppy.indexOf('按得太慢') >= 0, sloppy);
p.shot('image-aliased-graded');

const code = p.finish(`截图在 ${outDir}`);
process.exit(code === 0 ? 0 : 1);
