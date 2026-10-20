/**
 * 「探究平抛运动的特点」的设备侧检查。
 *
 * 这条从头到尾没有一根滑杆:卡片摆在第几格、球从第几格释放,都是要一下一下按的档位。
 * 设备侧要量的就是这几下按下去之后留下的后果对不对 ——
 * ① 外壳不给自动图线,也不给一根滑杆(抛物线的形状是学生自己检验的东西);
 * ② 释放四次只描四个点(一次释放连描一串是这条最容易犯的引擎错);
 * ③ 槽口速度真的按 √格数 涨;认真描完交卷能拿的分要一分不少。两格填空(反求 g、竖直段比)
 *    在 Task 7 之前没有输入口,这台机器上只能读作"没交",所以当年这条钉的是 60;
 *    Task 10 打通填空框之后按实测钉成两个数:**空着交 60、照判词里的应有值交上去 100**
 *    (那才是"细则能被满足"的正证;手上四条也从 25 重排成了 15,别按旧分值判这道题);
 * ④ 卡片摆到球飞不到的那一格,这一次什么都不该留下;
 * ⑤ 卡片忽近忽远时,扣分点名的是"忽近忽远"(两格交上数之后,这条走法只剩这 15 分 = 85)。
 *
 * 运行:node tools/device/check-projectile.mjs [--install <hap 路径>] [--out <截图目录>]
 */
import { join } from 'node:path';
import os from 'node:os';
import { Probe } from './probe.mjs';

const outArg = process.argv.indexOf('--out');
const outDir = outArg > -1 ? process.argv[outArg + 1] : join(os.tmpdir(), 'simlab-probe');
const installArg = process.argv.indexOf('--install');
const hapPath = installArg > -1 ? process.argv[installArg + 1] : null;

const EDGE = 60;
const TITLE = '探究平抛运动的特点';
const ORIGIN_BTN = '挂重垂线定抛出点';
const UP_BTN = '释放位置往上一格';
const DOWN_BTN = '释放位置往下一格';
const FAR_BTN = '卡片往外挪一格';
const NEAR_BTN = '卡片往里挪一格';
const RELEASE_BTN = '静止释放钢球';
// 两格填空的问句前缀:整句在 MechanicsScenes.projectileFrame 里定义,这里只认开头,
// 改问句后半截不用回来改两处(填空框自己没有 text,只能靠上面那句问句定位)
const PJ_G_LABEL = '由你描的第 1 个点反求';
const PJ_RATIO_LABEL = '竖直方向第二段位移';

const p = new Probe({ tag: 'projectile', outDir: outDir });

function texts() {
  return p.textList();
}

/**
 * 读一行统一走共用件(I6):旧版这里自己写了一份 `rowOf(label)`,每次调用都 dump 一遍,
 * 而 readout() 的判断条件调一次、返回值再调一次 —— 每判一轮要 dump **两次**,
 * 两下取自**不同快照**,中间那一屏可能已经滚了(读到空 → 再甩一下 → 拿回来的可能是另一格)。
 * check-answer 早就修掉了这一点,但那份没共享出来,于是三条探针里两份是对的、一份是漂的。
 */
function readout(label) {
  return p.readout(label, { edgeX: EDGE, tries: 16, settle: 900, swipeWait: 600 });
}

function numOf(label) {
  return parseFloat(readout(label));
}

function locate(label) {
  p.scrollToTop();
  for (let i = 0; i < 16; i++) {
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

/**
 * 按一下:每次都重新定位,再等 1.4 s(球本身只飞 0.69 s)。
 * 按钮和读数在同一条可滚列里,中间任何一次 readout()/locate() 都会把它滚走 ——
 * 复用上一次拿到的坐标就会点到"滚上来取代它的那颗"。
 */
function press(label) {
  const c = locate(label);
  if (c === null) return false;
  p.shell(`uitest uiInput click ${c[0]} ${c[1]}`);
  p.sleep(1400);
  return true;
}

/**
 * 连按几下同一颗按钮:定位一次,连着按。
 * 中间没有任何会滚这条列的动作,所以坐标不会失效 —— 失效只发生在"按完别的按钮/读过数"之后。
 */
function pressMany(label, times) {
  const center = locate(label);
  if (center === null) {
    return;
  }
  for (let i = 0; i < times; i++) {
    p.shell(`uitest uiInput click ${center[0]} ${center[1]}`);
    p.sleep(1400);
  }
}

/**
 * 判词收成一整块。旧版这里"找到得分那一行就返回",可得分那一行和每条扣分句
 * 是各一个节点(ExperimentPage.ets:278-285),而这一条探针现在要判的是跨节点的事:
 * 「两条 判定：没交」「扣分点名叫忽近忽远」都不在得分那一行里。
 * 收词的实现统一收在共用件 probe.verdictBlob,三条探针同一份。
 */
function verdict() {
  return p.verdictBlob(EDGE);
}

function scoreOf(text) {
  return parseInt((text.match(/得分\s+(\d+)/) || [])[1], 10);
}

p.say(`设备:${p.assertDevice()}`);
if (hapPath !== null) p.install(hapPath.replace(/\\/g, '/'));
p.launch();

p.say('== 1. 这条场景不给自动图线,也不给滑杆 ==');
p.ensureHome();
if (!p.tapInList(TITLE)) process.exit(1);
p.expectTrue('标题出现在实验页', texts().filter((t) => t === TITLE).length >= 1,
  texts().slice(0, 3).join(' / '));
p.expectTrue('屏幕上没有「展开图线」那颗按钮(轨迹是学生自己描的)',
  !texts().some((t) => t === '展开图线'), texts().filter((t) => t.indexOf('图线') >= 0).join(' / '));
// 六颗按钮不单独走一遍:后面每一段都要按它们,少一颗 locate() 会当场报"滚到底也没找到"。
// 一次全量探针要十几分钟,省掉这次重复滚动。
p.expect('释放位置默认在第 2 格', readout('释放位置'), '2 格');

p.say('== 2. 档位是按下不是拖动:格数一格一格走 ==');
press(UP_BTN);
p.expect('往上一格变成 3 格', readout('释放位置'), '3 格');
press(DOWN_BTN);
p.expect('往下一格回到 2 格', readout('释放位置'), '2 格');
p.expect('槽口速度跟着格数走:2 格是 1.40 m/s', readout('槽口速度 v0'), '1.40 m/s');
press(UP_BTN);
press(UP_BTN);
p.expect('升到第 4 格后槽口速度 1.98 m/s(√2 关系)', readout('槽口速度 v0'), '1.98 m/s');

p.say('== 3. 认真描完:四次释放四个点 ==');
press(ORIGIN_BTN);
pressMany(NEAR_BTN, 2);
p.expect('卡片挪到第 1 格', readout('卡片离槽口'), '0.15 m');
for (let i = 0; i < 4; i++) {
  press(RELEASE_BTN);
  press(FAR_BTN);
}
p.expect('按了四次释放就正好四个点', readout('描下的点'), '4 个');
p.expect('定原点之前一个点也没描', readout('定原点前描的点'), '0 个');
p.expect('四次用的是同一格释放', readout('释放位置最大差'), '0 格');
p.expect('卡片等间隔:间隔最大/最小是 1.00', readout('水平间隔最大/最小'), '1.00');
p.expect('原点定对了、高度也没变:y/x² 的离散度 0.0 %', readout('y/x² 的离散度'), '0.0 %');
p.shot('projectile-diligent');

p.say('== 4. 交卷:空着交 60 → 照应有值交上去 100(细则能被满足的正证) ==');
// 这一条当年钉的是 60,因为反求 g 与竖直段比两格没有输入口,在这台机器上永远读作"没交"。
// Task 10 打通填空框之后按实测钉成两个数(模拟器 127.0.0.1:5555):
// 空交「得分 60 / 100」两条判定：没交;照着判词里那两个应有值交上去 → 「得分 100 / 100」零扣分。
press('交卷评分');
const blank = verdict();
p.expectTrue('判词出现,两格都没交 → 60',
  blank.indexOf('得分 60') === 0 && (blank.match(/判定：没交/g) || []).length === 2,
  blank || '没有判词');
p.expectTrue('参考细则来源必须露出(不得伪装成官方标准)',
  blank.indexOf('参考细则') >= 0, blank.slice(0, 200) || '没有判词');
p.shot('projectile-blank-60');
const mG = blank.match(/按你描的第 1 个点应为\s*([\d.]+)\s*m\/s²/);
const mRatio = blank.match(/按你描的最近那两个点应为\s*([\d.]+)/);
if (mG === null || mRatio === null) {
  p.fail('判词里读出两格的应有值', blank.slice(0, 400));
} else {
  p.ok(`判词给的应有值:g ${mG[1]} m/s²、段比 ${mRatio[1]}`);
  p.expectTrue('g 那一格打得上字(填空框收得到键盘输入)',
    p.typeIntoField(PJ_G_LABEL, mG[1], EDGE), 'typeIntoField 失败');
  p.expect('框里就是打进去的 g', p.fieldText(PJ_G_LABEL, EDGE), mG[1]);
  p.expectTrue('段比那一格打得上字',
    p.typeIntoField(PJ_RATIO_LABEL, mRatio[1], EDGE), 'typeIntoField 失败');
  p.expect('框里就是打进去的段比', p.fieldText(PJ_RATIO_LABEL, EDGE), mRatio[1]);
  press('交卷评分');
  const graded = verdict();
  p.expectTrue('两格照应有值交上去 → 得分 100 一分不少',
    graded.indexOf('得分 100') === 0, graded || '没有判词');
  p.expectTrue('满分之上没有扣分句,来源照样露出',
    graded.indexOf('没算对或没交') < 0 && graded.indexOf('参考细则') >= 0, graded.slice(0, 300));
  p.shot('projectile-graded');
}

p.say('== 5. 卡片摆到球飞不到的那一格:这一次什么都不该留下 ==');
press('重置');
p.expect('重置=换一张白纸:点清零', readout('描下的点'), '0 个');
// 读数目没有值时那格仍带着单位:实测印出「— %」(单位是面板按参数定义拼上去的,不是模型给的数)
p.expect('没量过的检验读数退回没有值', readout('y/x² 的离散度'), '— %');
press(DOWN_BTN);
p.expect('降回第 1 格释放', readout('释放位置'), '1 格');
p.expect('第 1 格只能飞 0.69 m', readout('这一次能飞多远'), '0.69 m');
pressMany(FAR_BTN, 5);
p.expect('卡片摆到第 8 格:离槽口 1.20 m', readout('卡片离槽口'), '1.20 m');
press(RELEASE_BTN);
p.expect('球先落地,这一格没描上点', readout('描下的点'), '0 个');
pressMany(NEAR_BTN, 4);
p.expect('挪回第 4 格就接得住球', readout('卡片离槽口'), '0.60 m');
press(RELEASE_BTN);
p.expect('接得住时就描下一个点', readout('描下的点'), '1 个');

p.say('== 6. 卡片忽近忽远:扣分点名的是"忽近忽远" ==');
press('重置');
press(ORIGIN_BTN);
pressMany(UP_BTN, 2);
pressMany(NEAR_BTN, 2);
for (let i = 0; i < 3; i++) {
  press(RELEASE_BTN);
  press(FAR_BTN);
}
pressMany(FAR_BTN, 4);
press(RELEASE_BTN);
p.expect('前三格连着描,第四下突然挪到第 8 格:共四个点', readout('描下的点'), '4 个');
p.expect('间隔最大/最小读成 5.00', readout('水平间隔最大/最小'), '5.00');
p.shot('projectile-uneven');
press('交卷评分');
const sloppy = verdict();
const score = scoreOf(sloppy);
p.expectTrue('这次真的扣分了', Number.isFinite(score) && score < 100, sloppy || '没有判词');
p.expectTrue('扣分理由点名「忽近忽远」', sloppy.indexOf('忽近忽远') >= 0, sloppy);
// 今天是 45 而不是 75:忽近忽远那条从 25 重排成 15,再叠上两格没交的 2×20。
// Task 7/10 两格交上数之后,这一趟应当回到 85(只扣忽近忽远那 15 分)。
p.expectTrue('手上只扣"忽近忽远"这一条,再加两格没交(空着交是 45 分)',
  score === 45, sloppy);
p.shot('projectile-uneven-graded');
// 两格能交数之后,这条走法真正的账是"只扣忽近忽远那 15 分"(旧注释里写的 85 就是这个)。
// 本轮实测:照判词里的应有值把两格填上再交 → 「得分 85 / 100」,扣分句只剩忽近忽远那一条。
const mG2 = sloppy.match(/按你描的第 1 个点应为\s*([\d.]+)\s*m\/s²/);
const mR2 = sloppy.match(/按你描的最近那两个点应为\s*([\d.]+)/);
if (mG2 === null || mR2 === null) {
  p.fail('判词里读出两格的应有值', sloppy.slice(0, 400));
} else {
  p.expectTrue('g 那一格打得上字', p.typeIntoField(PJ_G_LABEL, mG2[1], EDGE), 'typeIntoField 失败');
  p.expectTrue('段比那一格打得上字', p.typeIntoField(PJ_RATIO_LABEL, mR2[1], EDGE), 'typeIntoField 失败');
  press('交卷评分');
  const fixed = verdict();
  const fixedScore = scoreOf(fixed);
  p.expectTrue('两格交上之后只扣忽近忽远 → 得分 85', fixed.indexOf('得分 85') === 0, fixed || '没有判词');
  p.expectTrue('剩下的那一条扣分点名的还是"忽近忽远"',
    fixed.indexOf('忽近忽远') >= 0 && fixedScore === 85, fixed.slice(0, 300));
  p.expectTrue('两格都不再是"没交"', (fixed.match(/判定：没交/g) || []).length === 0,
    fixed.slice(0, 300));
  p.shot('projectile-uneven-85');
}

const code = p.finish(`截图在 ${outDir}`);
p.back();
process.exit(code === 0 ? 0 : 1);
