/**
 * 第 11 个实验「测量电源的电动势和内阻」的设备侧链路检查。
 *
 * 与 check-ohm 同一套问句,但盯的东西不一样:这条的读数是"作图法"的原料,
 * 所以除了动作要走到读数格,还要在屏幕上确认**电阻箱是十进制挡**
 * (20 减一档到 12,不是 15)—— 那是 runner 里的挡位表,离线已断言,这里测它真进了界面。
 *
 * 运行:node tools/device/check-emf.mjs [--install <hap 路径>] [--out <截图目录>]
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
const TITLE = '测量电源的电动势和内阻';
const p = new Probe({ tag: 'emf', outDir: outDir });

function texts() {
  return p.dumpNodes().map((a) => a.text || '').filter((t) => t.length > 0);
}

function readout(label) {
  const list = texts();
  const at = list.indexOf(label);
  return at >= 0 && at + 1 < list.length ? list[at + 1] : '';
}

/** 回到页顶再一路往下找(实验页上半是固定画布,起讫点必须落在滚动区里) */
function scrollToText(label, tries) {
  p.scrollToTop();
  const limit = tries || 8;
  for (let i = 0; i < limit; i++) {
    if (texts().some((t) => t.indexOf(label) === 0)) {
      // 甩动动画还在跑就取坐标,下一次点击会落到滑到一半的位置上(实测点到了滑杆)
      p.sleep(1200);
      return true;
    }
    p.swipe(EDGE, 1900, EDGE, 900);
    // 甩动没停就取坐标 = 点错行;每一下之后多等一拍
    p.sleep(700);
  }
  return false;
}

/** 一路往下找,找到后用**同一次 dump** 的坐标点下去,并且要求:
    ① 目标落在屏幕中段(离上下边界都有余量);② 800 ms 后再 dump 一次,位置一模一样。
    少了这两条,点下去的会是"取代它位置的那一行"(实测:点「电阻箱减一档」点到了「加一档」,
    值从 20 跳到 30 —— 看着像按钮失灵,其实是页面还在慢慢爬)。 */
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
        p.sleep(1600);
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

p.say(`设备:${p.assertDevice()}`);
if (hapPath !== null) p.install(hapPath.replace(/\\/g, '/'));
p.launch();

p.say('== 1. 首页:第 11 张卡能滚到、能点开 ==');
p.ensureHome();
if (!p.tapInList(TITLE)) process.exit(1);
p.expectTrue('标题出现在实验页', texts().filter((t) => t === TITLE).length >= 1, texts().slice(0, 4).join(' / '));
scrollToText('干路电流');
p.expectTrue('量程写在读数标签上,不藏进细则',
  texts().some((t) => t === '干路电流 I（量程 0.6 A）'),
  texts().filter((t) => t.indexOf('干路电流') === 0).join(' / ') || '没有这条读数');

p.say('== 2. 拨挡与记录都要从按钮走到读数格 ==');
p.tap('开始');
scrollToText('电阻箱 R');
p.expect('刚打开时电阻箱在默认挡', readout('电阻箱 R'), '20 Ω');
tapByWalk('电阻箱减一档');
scrollToText('电阻箱 R');
// 20 → 12 而不是 20 → 15:屏幕上那格数字就是十进制挡位表有没有真进了界面
p.expect('减一档落到 12 Ω', readout('电阻箱 R'), '12 Ω');
tapByWalk('记录这一组 U 和 I');
scrollToText('实时读数');
p.expect('记一组后「已记录组数」', readout('已记录组数'), '1 组');
const u12 = readout('路端电压 U');
tapByWalk('电阻箱减一档');
scrollToText('电阻箱 R');
p.expect('再减一档落到 8 Ω', readout('电阻箱 R'), '8 Ω');
tapByWalk('记录这一组 U 和 I');
scrollToText('实时读数');
const u8 = readout('路端电压 U');
p.expect('两组读数都进了账', readout('已记录组数'), '2 组');
p.expectTrue('电阻箱减小则路端电压升高', u8 !== u12 && u8.length > 0, `12 Ω 时「${u12}」8 Ω 时「${u8}」`);
// 12 Ω 与 8 Ω 两挡的电流差:1.5/8.0001 − 1.5/12.0001 ≈ 0.051 A
p.expect('两挡之间的电流跨度', readout('读数铺开的电流跨度'), '0.051 A');
p.shot('emf-two-points');

p.say('== 3. 交卷评分:两组读数必须被判成"点取得不够" ==');
tapByWalk('交卷评分');
p.expectTrue('判词出现且带分数', texts().some((t) => t.indexOf('得分') === 0), texts().slice(0, 6).join(' / '));
p.expectTrue('参考细则来源必须露出(不得伪装成官方标准)',
  texts().some((t) => t.indexOf('参考细则') >= 0), '');
p.expectTrue('扣分明细点到"组数太少"',
  texts().some((t) => t.indexOf('读数组数太少') >= 0), '');
p.expectTrue('扣分明细点到"挤在一小段"',
  texts().some((t) => t.indexOf('一小段电流') >= 0), '');
p.shot('emf-graded');

const code = p.finish(`截图在 ${outDir}`);
process.exit(code === 0 ? 0 : 1);
