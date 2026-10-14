/**
 * 第 15 个实验「探究加速度与物体受力、物体质量的关系」的设备侧检查。
 *
 * 这条比前几条多两样屏幕上才看得见的东西:
 * ① 十一个离散动作按钮排在同一列里(加垫块、加减槽码与砝码、取挂桶、通电、轻推、释放、记录),
 *    要确认它们都在、且按得动;
 * ② 平衡摩擦到位与否读的是**那次空载轻推的纸带点距跨度**:两层垫块时应当在 0.4 mm 以内,
 *    多加一层就应当明显发散。这个数是量出来的,不是我们把层数换算给它的。
 *
 * 探针自己多了一条规矩:toggle 性质的按钮(电源、挂取桶)不许盲按 —— 上一版就是按次数猜状态,
 * 结果六组数据全测成了"没挂桶"、还误读了一次检查。现在切换前后都从读数确认。
 * 最后按认真做完的六组交卷,当场验细则能被满足(得分 100)。
 *
 * 运行:node tools/device/check-newton.mjs [--install <hap 路径>] [--out <截图目录>]
 */
import { join } from 'node:path';
import os from 'node:os';
import { Probe } from './probe.mjs';

const outArg = process.argv.indexOf('--out');
const outDir = outArg > -1 ? process.argv[outArg + 1] : join(os.tmpdir(), 'simlab-probe');
const installArg = process.argv.indexOf('--install');
const hapPath = installArg > -1 ? process.argv[installArg + 1] : null;

// 参数滑杆占满 98..1158,滚动手势落在轨道上会被滑杆吞掉,所以一律走左侧留白
const EDGE = 60;
const TITLE = '探究加速度与物体受力、物体质量的关系';
const p = new Probe({ tag: 'newton', outDir: outDir });

function texts() {
  return p.dumpNodes().map((a) => a.text || '').filter((t) => t.length > 0);
}

function rowOf(label) {
  const list = texts();
  const at = list.indexOf(label);
  return at >= 0 && at + 1 < list.length ? list[at + 1] : '';
}

/** 滚到某一格读数再读:一屏只放得下五六行,不滚就读到空,上一版把"空"当成了数 */
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

/** 判词印在操作列下面,不滚过去就"没有判词" —— 上一版就是这么误判了一次 */
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

/** 按下某个按钮:先在当前这一屏找,找不到才滚动 —— 十一个按钮每次回顶重滚太慢 */
function tapButton(label, times) {
  const hits = times === undefined ? 1 : times;
  for (let n = 0; n < hits; n++) {
    let node = p.dumpNodes().find((a) => (a.text || '') === label);
    if (node === undefined) {
      p.scrollToTop();
      for (let i = 0; i < 14 && node === undefined; i++) {
        p.swipe(EDGE, 1900, EDGE, 1500);
        p.sleep(500);
        node = p.dumpNodes().find((a) => (a.text || '') === label);
      }
    }
    if (node === undefined) {
      p.fail(`按下「${label}」`, '滚到底也没找到这个按钮');
      return false;
    }
    const c = Probe.center(node.bounds);
    p.shell(`uitest uiInput click ${c[0]} ${c[1]}`);
    p.sleep(800);
  }
  return true;
}

/** 一次空载轻推检查:通电、等一会儿、再推一把。手指慢半拍没关系 —— 重叠点不进量窗 */
/** 检查之前也先「重置」:电源是 toggle,上一段还开着的话这一下就把它关了,
    纸带于是沿用上一次的结果 —— 设备实测把"三层该发散"读成了 0.13 mm 匀速。 */
function frictionCheck() {
  tapButton('重置');
  tapButton('接通／断开电源');
  p.sleep(900);
  tapButton('轻推小车');
  p.sleep(2600);
}

/** 一组测量:回起点(电源随之断开、纸带清空)、通电、放车、走一段、记下这一条纸带 */
function measureGroup() {
  if (!tapButton('重置')) return false;
  tapButton('接通／断开电源');
  p.sleep(700);
  tapButton('释放小车');
  p.sleep(2600);
  tapButton('记录这一条纸带');
  return true;
}

p.say(`设备:${p.assertDevice()}`);
if (hapPath !== null) p.install(hapPath.replace(/\\/g, '/'));
p.launch();

p.say('== 1. 十一个动作按钮都在,而且按得动 ==');
p.ensureHome();
if (!p.tapInList(TITLE)) process.exit(1);
p.expectTrue('标题出现在实验页', texts().filter((t) => t === TITLE).length >= 1,
  texts().slice(0, 3).join(' / '));
const labels = ['加一层垫块', '取一层垫块', '小车上加一只槽码', '从小车上取一只槽码',
  '桶里加一只砝码', '从桶里取一只砝码', '挂上／取下砝码桶', '接通／断开电源',
  '轻推小车', '释放小车', '记录这一条纸带'];
const seen = [];
p.scrollToTop();
for (let i = 0; i < 16; i++) {
  const list = texts();
  for (const label of labels) {
    if (list.indexOf(label) >= 0 && seen.indexOf(label) < 0) seen.push(label);
  }
  if (seen.length === labels.length) break;
  p.swipe(EDGE, 1900, EDGE, 1500);
  p.sleep(500);
}
p.expectTrue('十一个动作按钮都数得到', seen.length === labels.length,
  `实得 ${seen.length} 个,缺:${labels.filter((x) => seen.indexOf(x) < 0).join('、')}`);
p.shot('newton-buttons');

p.say('== 2. 加两层垫块,读数跟着变 ==');
p.expect('开始一层都没垫', readout('垫块层数'), '0 层');
tapButton('加一层垫块', 2);
p.expect('按下两下就是两层', readout('垫块层数'), '2 层');
p.expectTrue('倾角读出 4.5° 以上', numOf('板面倾角') > 4.5, '实得「' + readout('板面倾角') + '」');

p.say('== 3. 平衡摩擦靠纸带读出来,不靠层数 ==');
tapButton('挂上／取下砝码桶');
p.expect('桶取下了', readout('砝码桶与砝码 m'), '0.000 kg');
frictionCheck();
const even = numOf('轻推那次的点距跨度');
p.expect('这次检查被记了一次', readout('空载轻推检查'), '1 次');
p.expectTrue('两层垫块时空载点距匀到 0.4 mm 以内', even >= 0 && even < 0.4,
  `实得 ${even} mm —— 手指慢一秒按下不该被读成「不匀」`);
p.shot('newton-idle-balanced');

tapButton('加一层垫块');
frictionCheck();
const loose = numOf('轻推那次的点距跨度');
p.expectTrue('多加一层就量出发散(越打越疏)', loose > 8,
  '实得「' + readout('轻推那次的点距跨度') + '」');
p.expect('两次检查都算次数', readout('空载轻推检查'), '2 次');
p.shot('newton-idle-check');
// 回到两层之后**再验一次**:细则判的是"最近一次检查",改了器材却不重验,
// 那条发散的数就一直算在头上(上一版把这条 80 分当成误判,其实它判得对)
tapButton('取一层垫块');
frictionCheck();
const back = numOf('轻推那次的点距跨度');
p.expectTrue('回到两层再验一次,读回匀速', back >= 0 && back < 0.4,
  '实得「' + readout('轻推那次的点距跨度') + '」');
p.expect('三次检查都算次数', readout('空载轻推检查'), '3 次');
// 挂回桶:后面六组都在这个配置下测,挂没挂从读数确认,不按次数猜
tapButton('挂上／取下砝码桶');
p.expect('桶挂回去了', readout('砝码桶与砝码 m'), '0.005 kg');
p.expect('垫块回到两层', readout('垫块层数'), '2 层');

p.say('== 4. 两半控制变量:同一辆车换三档拉力,同一档拉力加三次槽码 ==');
tapButton('桶里加一只砝码');
if (!measureGroup()) process.exit(1);
p.expect('第一组记进本子', readout('算得出 a 的组数'), '1 组');
const a1 = numOf('本条纸带逐差法求出的 a');
p.expectTrue('逐差法读得出一个正经的 a', a1 > 0.1 && a1 < 3,
  '实得「' + readout('本条纸带逐差法求出的 a') + '」');
tapButton('桶里加一只砝码', 2);
measureGroup();
tapButton('桶里加一只砝码', 2);
measureGroup();
p.expect('同一质量下换过三档拉力', readout('同一质量下换过的拉力档'), '3 档');
tapButton('小车上加一只槽码', 2);
measureGroup();
tapButton('小车上加一只槽码', 2);
measureGroup();
tapButton('小车上加一只槽码', 2);
measureGroup();
p.expect('六组都算得出 a', readout('算得出 a 的组数'), '6 组');
p.expect('同一质量下还是三档拉力', readout('同一质量下换过的拉力档'), '3 档');
p.expect('同一拉力下试过四种质量', readout('同一拉力下试过质量'), '4 种');
p.expectTrue('小车加槽码到 0.500 kg', readout('小车与槽码 M').indexOf('0.500') === 0,
  '实得「' + readout('小车与槽码 M') + '」');
p.shot('newton-six-groups');

p.say('== 5. 认真做完交卷:细则必须能被满足 ==');
tapButton('交卷评分');
const graded = verdict();
p.expectTrue('判词出现且是满分', graded.indexOf('得分 100') === 0, graded || '没有判词');
p.expectTrue('参考细则来源必须露出(不得伪装成官方标准)',
  texts().some((t) => t.indexOf('参考细则') >= 0), '');
p.shot('newton-graded');

p.say('== 6. 反过来做:不检查摩擦就直接测,应当被扣 ==');
// 记录本要清空只能重新进一次页面:「重置」按设计不动已记下的组
p.back(1500);
p.ensureHome();
if (!p.tapInList(TITLE)) process.exit(1);
tapButton('小车上加一只槽码');
tapButton('桶里加一只砝码', 3);
for (let i = 0; i < 6; i++) measureGroup();
tapButton('交卷评分');
const sloppy = verdict();
// 只取「得分 N」那一个数:把整段判词里的非数字删掉,40 / 100 会粘成一个巨数
const score = parseInt((sloppy.match(/得分\s+(\d+)/) || [])[1], 10);
p.expectTrue('没做那次检查就不可能满分', Number.isFinite(score) && score < 100,
  sloppy || '没有判词');
p.expectTrue('扣分理由点名「空载轻推」', sloppy.indexOf('空载轻推') >= 0, sloppy);
p.shot('newton-no-check');

const code = p.finish(`截图在 ${outDir}`);
process.exit(code === 0 ? 0 : 1);
