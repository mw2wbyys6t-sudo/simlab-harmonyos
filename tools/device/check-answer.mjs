/**
 * 学生填数通道的设备侧验收(Task 10)。
 *
 * Task 1~9 全是离线验证,这是这条链路第一次跑在屏幕上。屏幕上要判的这几件事,每一件都是
 * 离线源码守卫明确说自己管不了的(task-7-fix3-report 最后一节 ①~⑤):
 * ① runner 作废**一格**之后,屏上只有那一格空着、另一格留着数字(整框清会把「早交了 g、
 *    还在描点」的人判成没交;走模块级函数或 this.controller 的清空,源码守卫看不见);
 * ② 打字过程中不许有任何回显:文字、**底色**、**图标**三道闸门都要查 —— 计划里那条只认
 *    「算对了/算错了/没交」几个字,漏色与漏图标两道它都是绿的;
 * ③ 框上真正印出来的占位文案,而不是源码里那句字面串;
 * ④ 计数起点那句「开头密着的点会自动舍掉」在屏幕上兑现成什么数;
 * ⑤ 最后一格填空到「交卷评分」那颗按钮隔着多少屏(只量,不动版面 —— 要改是 #67 的决定)。
 * 再加 brief 的断言清单:任务正文第一次上屏、两格问句可见、一条不填→没交→60、
 * 填 F1→点名错法→80、照应有值填→100、ans.* 落盘进历史、键盘弹起时框没被顶出可视区。
 *
 * 打字这一层用 uitest 的 inputText,本轮实测出它两根必须写进代码的脾气:
 *   · **追加而不是替换** —— 同一格不清就再打一次,屏上是 9.809.80(Task 7 报告顾虑 3);
 *   · 坐标必须每次现取 —— 软键盘弹起时整页被顶上去,拿旧坐标点下去就落在键盘上
 *     (实测那样会把一个 '8' 打进框里,看着像应用吞字符,其实是探针按错了地方)。
 *
 * 运行(默认全跑一遍;分段是给自己调试用的,验收要跑不带 --only 的那一条):
 *   SIMLAB_TARGET=127.0.0.1:5555 node tools/device/check-answer.mjs \
 *     --install entry/build/default/outputs/default/entry-default-unsigned.hap
 *   **每台机器在线都必须带 SIMLAB_TARGET**(I1):两台模拟器同时在的时候,不带 target 的调用
 *   要么被 hdc 拒掉,要么落到另一台上 —— 装包尤其危险,它照样回 install bundle successfully。
 *   --only a        只看 T1~T4(渲染、⑤ 距离、打字、回显纪律)
 *   --only b        只看 T5~T9(手上动作 + ④、60、脏框 60、80、分子点名互斥、分母侧换错法、100、断言 8)
 *   --only history  只看 T10,要用 --expect "应有分子,历史印的F1,应有倍数"
 *                   (第二个数按报告页那把尺子 FactLabels.valueText 写,不是判词那把)
 *   --only pj       只看平抛那一段(① 逐格作废)
 *   --out <目录>    截图目录(默认 %TEMP%/simlab-probe)
 */
import { join } from 'node:path';
import os from 'node:os';
import { readFileSync } from 'node:fs';
import { Probe } from './probe.mjs';

const outArg = process.argv.indexOf('--out');
const outDir = outArg > -1 ? process.argv[outArg + 1] : join(os.tmpdir(), 'simlab-probe');
const installArg = process.argv.indexOf('--install');
const hapPath = installArg > -1 ? process.argv[installArg + 1] : null;
const onlyArg = process.argv.indexOf('--only');
const only = onlyArg > -1 ? process.argv[onlyArg + 1] : 'all';

// 走左侧留白滚:参数滑杆占满 98..1158,手势落在轨道上会把值跳到那个 x
const EDGE = 60;
const TAPE_TITLE = '测量匀变速直线运动物体的加速度';
const PJ_TITLE = '探究平抛运动的特点';
const SECTION = '要交的结论';
/**
 * ③ 占位文案钉的是**这一句字面串本身**(I4,照 Task 7 起点文案那条的做法)。
 * 上一版比的是"屏上串 == 源码里 regex 抓出来的串",于是屏上与源码**同时改**时永远绿,
 * 只能抓"框架自己改写了字符串"这一种;而 placeholder 写成变量/模板串时它连比都不比。
 * 改文案的人会把这条弄红,并在失败详情里看到"请同步这一处字面串"—— 这是想要的摩擦。
 */
const PLACEHOLDER = '把你算出的数填进来';
/**
 * ⑤ 甩一下配不上时兜底用的字数面常量(Ruling AA:留着,但必须**单独记账**)。
 * 惯性/动画让某一下配不上是常态,删了它这条断言经常拿不到数;掺进"实测"里不记账才是造假。
 */
const ASSUMED_PX = 1100;
/** 问句按开头认:整句在场景里定义,屏上就是一整行(改问句后半截不用回来改两处) */
const NUM_LABEL = '逐差法的分子';
const DEN_LABEL = '分母里 T² 的倍数';
const PJ_G_LABEL = '由你描的第 1 个点反求';
const PJ_SEG_LABEL = '竖直方向第二段位移';
/** 回显闸门认的词:判定词 + 任何"应有值"类说法 */
const ECHO_WORDS = ['算对了', '算错了', '没交', '得分', '判定', '应有值', '应为', '扣分', '答案'];
/** 占位文案里不许出现的判定/答案影子(③读的是屏上真印出来的字) */
const PLACEHOLDER_BANNED = ['算对', '算错', '没交', '判定', '应有值', '应为', '答案', '标准', '正确', '错误', '得分'];
/**
 * 判词那两族点名文案里**纯静态的尾巴**(没有任何 {占位符}),钉整串而不是子串(C2)。
 *
 * 上一版钉的是"句子里有没有『只用首尾两段』这一族",而 RubricTape.ets:61 那一句
 * 把 F1 与 F3 两族的名字**都写死在里面**(离线 check.mjs:9413 还专门钉着"两族都要说出来"),
 * 所以无论学生犯哪一种它都在屏上,那条断言恒绿 —— 比的根本不是"点名",是那段静态文案。
 * 现在:①整条静态尾巴逐字钉住(改细则那一句 → 这条红,这是评审要的"删掉一半必须红");
 *      ②互斥负对照做在**判词真的会翻的那一轴**上(哪一问的扣分句出现),见 T7 与 T7b。
 */
const NUM_NAME_TAIL = '：只用首尾两段会把中间量出来的数全丢掉，相邻两两相减又退化成逐段平均';
const DEN_NAME_TAIL = '；漏乘段数平方会把加速度放大一大截、段数越多放大得越厉害，'
  + '只乘一个段数照样放大，拿总段数的平方去除又会把它缩小到四分之一';
/** 两族点名的**词头**:互斥负对照按这些词判"另一族不许出现在扣分句里" */
const NUM_FAMILY = ['只用首尾两段', '相邻两两相减'];
const DEN_FAMILY = ['漏乘段数平方', '只乘一个段数', '总段数的平方'];
/** 扣分句的标题前缀(判词一行一条,按标题把两问分开) */
const NUM_LINE = '· 逐差法这一问没算对或没交';
const DEN_LINE = '· 逐差法分母这一问没算对或没交';

const p = new Probe({ tag: 'answer', outDir: outDir });
/** 当前这条实验的两格前缀 */
let firstLabel = NUM_LABEL;
let secondLabel = DEN_LABEL;

function nodes() {
  return p.dumpNodes();
}

function texts() {
  return nodes().map((a) => a.text || '').filter((t) => t.length > 0);
}

function rectOf(b) {
  const m = b.match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);
  return [+m[1], +m[2], +m[3], +m[4]];
}

/**
 * 填空这一层的四件事(定位那一格、读框里的字、清框、打字)都走共用件 probe.mjs:
 * locateField / fieldText / clearField / typeIntoField。三条设备探针(check-answer、
 * check-tape、check-projectile)共用同一份实现,免得清框与收键盘的脾气在三个文件里各漂移一版。
 *
 * I6:这一层的每一个调用都必须把 EDGE 透传下去。旧版 boxText/clearBox 没带 EDGE,
 * 与同文件 locateCell 带的 60 不一致 —— 今天 EDGE 恰好等于实现里的默认值 60 才没出事,
 * 谁把某个文件的留白改成 70,那两条读框就会滚错列。
 */
function locateCell(prefix) {
  return p.locateField(prefix, EDGE, 1900, 900);
}

function boxText(prefix) {
  return p.fieldText(prefix, EDGE);
}

function clearBox(prefix) {
  return p.clearField(prefix, EDGE);
}

/**
 * 往一格填空里打字:先定位那一格,再用 uitest 的 inputText 打进去。
 * brief 给的就是这个形状;多出来的是清框与打完收键盘这两笔 —— uitest 的 inputText 只追加,
 * 而软键盘弹起会把整页顶上去,坐标不现取就点到键盘上(本轮实测,见文件头)。
 * 键盘收不掉(I7 的 unknown)时 typeIntoField 返回 false,这一条就红,不许继续往下测。
 */
function typeInto(label, text) {
  return p.typeIntoField(label, text, EDGE);
}

/** 找一颗按钮/一行文本的中心:当前屏有就用,没有再回顶往下找(每次都重取树) */
function locate(label) {
  let list = nodes();
  // 键盘还支着就先收掉。本轮实测:P2 打完字直接进 P3 找「交卷评分」,那 18 下甩屏全打在输入法上,
  // 面板一格没动,最后报的是「滚到底也没找到」—— 探针的错,不是应用的错(截图上按钮明明在)。
  if (p.imeState(list).state === 'up') {
    if (p.hideKeyboard() !== 'down') {
      p.fail('找到「' + label + '」之前收键盘', '键盘状态认不出来,甩屏会全打在输入法上(本轮实测)');
      return null;
    }
    list = nodes();
  }
  let hit = list.find((a) => (a.text || '') === label);
  if (hit === undefined) {
    hit = list.find((a) => (a.text || '').indexOf(label) === 0);
  }
  if (hit !== undefined) {
    return Probe.center(hit.bounds);
  }
  p.scrollToTop();
  for (let i = 0; i < 18; i++) {
    list = nodes();
    hit = list.find((a) => (a.text || '') === label);
    if (hit === undefined) {
      hit = list.find((a) => (a.text || '').indexOf(label) === 0);
    }
    if (hit !== undefined) {
      return Probe.center(hit.bounds);
    }
    p.swipe(EDGE, 1900, EDGE, 1500);
    p.sleep(400);
  }
  p.fail('找到「' + label + '」', '滚到底也没找到');
  return null;
}

function press(label) {
  const c = locate(label);
  if (c === null) {
    return false;
  }
  p.shell(`uitest uiInput click ${c[0]} ${c[1]}`);
  p.sleep(1400);
  return true;
}

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

/** 读一行:label 下面紧挨着的那条文本就是值。实现收在共用件里(I6),三条探针同一份 */
function rowOf(label, list) {
  return Probe.rowOf(label, list);
}

/**
 * 应用自己那两把数字尺子,逐字抄自源码,探针拿它们算期望字符串:
 *   · 判词走 Judgment.text(Judgment.ets:180)—— 整数原样、|v|>=100 收成整数、否则两位小数;
 *   · 报告页(历史行摘要与事实表)走 FactLabels.valueText(FactLabels.ets:193)—— 整数原样、
 *     否则一律两位小数,**没有 >=100 收成整数那一档**。
 *
 * 为什么要抄两把:同一个数在两个屏上印得不一样。本轮实测学生打 131.7,
 * 判词印「你交的分子是 132 mm」而历史印「你交的逐差法分子 131.70 mm」。
 * 上一版探针只猜了一把(无条件 toFixed(2)),于是把判词那条预测成「131.70」报了假红 ——
 * 错在探针,不在这条断言。这里按各自的尺子各钉各的串,两条都是精确匹配,
 * 哪一侧的格式悄悄漂了都会当场红;两把尺子本身不一致这件事是应用的问题,记进报告。
 */
function verdictNumber(value) {
  if (!Number.isFinite(value)) {
    return '—';
  }
  if (Number.isInteger(value)) {
    return String(value);
  }
  return Math.abs(value) >= 100 ? value.toFixed(0) : value.toFixed(2);
}

/** 报告页那一列的格式(摘要行与事实表同一条路,ReportPage.ets:191 与 :224) */
function historyNumber(value) {
  if (!Number.isFinite(value)) {
    return '—';
  }
  return Number.isInteger(value) ? String(value) : value.toFixed(2);
}

/**
 * 滚到某一格读数再读:读数与它的值在同一个 Row 里,值就是后面那条文本。
 * 实现收在共用件 probe.readRow 里(I6)—— 同一次快照取条件与取值,顺带把那一屏的文本表留下。
 */
function readout2(label) {
  return p.readRow(label, { edgeX: EDGE, tries: 18, settle: 600, swipeWait: 400 });
}

function readout(label) {
  return readout2(label).value;
}

/** 交卷后的判词:可能比一屏长,从头往下把这些句子收齐。实现收在共用件里,三条探针同一份 */
function verdictBlob() {
  return p.verdictBlob(EDGE);
}

/** 按扣分句的标题把整块判词切成"哪一问响了":互斥负对照要的是**这一行在不在**,不是子串在不在 */
function deductionLines(blob, titlePrefix) {
  return blob.split('\n').filter((t) => t.indexOf(titlePrefix) === 0);
}

/** 一串里出现了哪几族的点名词(返回命中的词,没命中返回空数组) */
function familyHits(text, words) {
  return words.filter((w) => text.indexOf(w) >= 0);
}

function scoreOf(text) {
  return parseInt((text.match(/得分\s+(\d+)/) || [])[1], 10);
}

/** 「要交的结论」这一节的节点(从小节标题到最后一格填空的下沿);锚点不在屏上就给 null */
function regionOf(list) {
  const boxes = list.filter((n) => n.type === 'TextInput');
  if (boxes.length === 0) {
    return null;
  }
  const head = list.find((n) => (n.text || '') === SECTION);
  const lbl = list.find((n) => (n.text || '').indexOf(firstLabel) === 0
    || (n.text || '').indexOf(secondLabel) === 0);
  if (head === undefined && lbl === undefined) {
    return null;
  }
  const top = head !== undefined ? rectOf(head.bounds)[1] : rectOf(lbl.bounds)[1] - 40;
  let bottom = 0;
  for (const b of boxes) {
    bottom = Math.max(bottom, rectOf(b.bounds)[3]);
  }
  return list.filter((n) => {
    const bb = rectOf(n.bounds);
    return bb[3] >= top && bb[1] <= bottom;
  });
}

/** 这一节的结构指纹:类型/文本/占位/底色/勾选/选中/透明度/说明/可点/背景图/层级 */
function fingerprint(region) {
  if (region === null) {
    return null;
  }
  return region.map((n) => ({
    type: n.type, text: n.text || '', hint: n.hint || '', bg: n.backgroundColor || '',
    checked: n.checked || '', selected: n.selected || '', opacity: n.opacity || '',
    desc: n.description || '', enabled: n.enabled || '', clickable: n.clickable || '',
    image: n.backgroundImage || '', hier: n.hierarchy || ''
  }));
}

function echoHits(list) {
  const hit = [];
  for (const n of list) {
    const t = (n.text || '') + '|' + (n.hint || '') + '|' + (n.description || '');
    for (const w of ECHO_WORDS) {
      if (t.indexOf(w) >= 0) {
        hit.push(w);
      }
    }
  }
  return [...new Set(hit)].sort().join(',');
}

/** 两次结构快照的差异:只许 TextInput 的 text 变,别的一律不许 */
function echoDiff(before, after) {
  if (before === null || after === null) {
    return '两次快照里有一次的这一节根本不在屏上';
  }
  if (before.length !== after.length) {
    return '这一节的节点数从 ' + before.length + ' 变成 ' + after.length + '(多一个图标、多一行字都在这里露形)';
  }
  for (let i = 0; i < before.length; i++) {
    const a = before[i];
    const b = after[i];
    const changed = [];
    for (const k of Object.keys(a)) {
      if (k === 'text' && a.type === 'TextInput') {
        continue;
      }
      if (a[k] !== b[k]) {
        changed.push(k + ':「' + a[k] + '」→「' + b[k] + '」');
      }
    }
    if (changed.length > 0) {
      return '第 ' + (i + 1) + ' 个节点(' + a.type + ' ' + (a.text || a.hint) + ')变了:' + changed.join(' / ');
    }
  }
  return '';
}

/** 面板(那条真正会滚的 Scroll)在屏幕上占的那一横条;找不到给 null */
function panelBand(list) {
  const scrolls = list.filter((n) => n.type === 'Scroll').map((n) => rectOf(n.bounds));
  scrolls.sort((a, b) => (b[3] - b[1]) - (a[3] - a[1]));
  return scrolls.length === 0 ? null : scrolls[0];
}

/** 节点整条落在面板横条以内(上下各留 2 px 容差);贴着边界被裁的那一半位置不可信 */
function insideBand(r, band) {
  return r[1] >= band[1] - 2 && r[3] <= band[3] + 2;
}

/**
 * 相邻两次快照之间,这条滚动列**真实**挪了多少像素(按 hierarchy 配对,取正位移的中位数)。
 *
 * 只比面板横条以内的节点:画布、开始/重置那一行、倍速 chip 全是固定件,永远原地不动。
 * 本轮实测(勘察日志 task10-logs/fix1-pairing-probe.log 与 fix1-stroke-probe.log):
 * 旧版把固定件也算进配对,连着四下每下都是「配对 18~23 条、正位移 0 条」→ 返回 -1 →
 * 全部落到 1100 兜底上,而 4 × 1100 = 4400 被当成"实测累计位移"写进了报告(那就是 C1)。
 *
 * 另一半病因是甩的行程:一甩 1100 px 比面板视口 1035 px 还长,两屏在面板里压根没有重叠节点,
 * 再怎么配也配不出来。把行程改小之后同一份配对就能数出来(5555 实测):
 *   · 行程 300 px → 配对 5 条,样本 284/344/344/344/344(中位 344,极差 60)
 *   · 行程 500 px → 配对 3 条,样本 465/483/483(中位 483,极差 18)
 *   · 行程 700 px → 只剩 2 条;行程 1100 px → **0 条**(全都滚出视口了)
 * 所以这里要求「≥2 条重叠、且这几条彼此差 ≤120 px」才给数;达不到就返回 med = -1,
 * 由调用方记成"没配上的第 k 下",不许混进实测数。
 */
function shiftBetween(prev, cur, band) {
  if (band === null) {
    return { med: -1, pairs: 0, spread: 0, agree: 0 };
  }
  const at = new Map();
  for (const n of cur) {
    if ((n.text || '').length === 0) {
      continue;
    }
    const r = rectOf(n.bounds);
    if (!insideBand(r, band)) {
      continue;
    }
    at.set(n.hierarchy, r[1]);
  }
  const deltas = [];
  for (const n of prev) {
    if ((n.text || '').length === 0) {
      continue;
    }
    const r = rectOf(n.bounds);
    if (!insideBand(r, band)) {
      continue;
    }
    const y = at.get(n.hierarchy);
    if (y === undefined) {
      continue;
    }
    const d = r[1] - y;
    if (d > 0) {
      deltas.push(d);
    }
  }
  if (deltas.length < 2) {
    return { med: -1, pairs: deltas.length, spread: 0, agree: 0 };
  }
  deltas.sort((a, b) => a - b);
  const spread = deltas[deltas.length - 1] - deltas[0];
  const med = deltas[Math.floor(deltas.length / 2)];
  // 一两个粘顶/被裁的节点就能把极差拉到上百 px,那是**离群点**,不是"这一段整个不能用"。
  // 本轮实测:配到 6~8 条、极差 129~135 的段被旧判据整段否掉,重跑两次都复现 ——
  // 于是一条关于版面的测量变成在赌模拟器的动画。改判**多数一致**:
  // 落在中位数 ±60 px 以内的节点有 ≥3 个,这一段就算量到了。
  let agree = 0;
  for (const d of deltas) {
    if (Math.abs(d - med) <= 60) {
      agree += 1;
    }
  }
  if (agree < 3) {
    return { med: -1, pairs: deltas.length, spread: spread, agree: agree };
  }
  return { med: med, pairs: deltas.length, spread: spread, agree: agree };
}

p.say(`设备:${p.assertDevice()}`);
if (hapPath !== null) {
  p.install(hapPath.replace(/\\/g, '/'));
}

// =====================================================================
// 一、sr-003 逐差法 A 段:渲染、⑤ 距离、打字、回显纪律
// =====================================================================
function tapeA() {
  p.launch();
  p.ensureHome();
  if (!p.tapInList(TAPE_TITLE)) {
    return false;
  }
  firstLabel = NUM_LABEL;
  secondLabel = DEN_LABEL;

  p.say('== T1. 任务正文与两格问句第一次上屏(brief 断言 1、2 与 ③) ==');
  p.expectTrue('「要交的结论」这一节出现在屏幕上',
    locateCell(NUM_LABEL) !== null && texts().some((t) => t === SECTION),
    '这一屏没有那句小节标题');
  p.expectTrue('第一条任务正文的前 8 个字可见(任务文本第一次上屏)',
    texts().some((t) => t.indexOf('用逐差法把各计数') === 0),
    texts().slice(0, 6).join(' / '));
  p.expectTrue('第一格填空的问句「逐差法的分子」可见',
    texts().some((t) => t.indexOf(NUM_LABEL) === 0), '定位不到问句');
  p.expectTrue('第二格填空的问句「分母里 T² 的倍数」可见',
    locateCell(DEN_LABEL) !== null, '滚到底也没有那一格');
  // ③ 占位文案:读屏上真印出来的那几个字,并钉住那一句字面串本身(I4)
  const hints = nodes().filter((n) => n.type === 'TextInput').map((n) => n.hint || '');
  p.say(`  屏上两格的占位文案:${JSON.stringify(hints)}`);
  p.expectTrue('两格都印出了占位提示(不是空着的一格)',
    hints.length >= 2 && hints.every((h) => h.length > 0), JSON.stringify(hints));
  const banned = PLACEHOLDER_BANNED.filter((w) => hints.some((h) => h.indexOf(w) >= 0));
  p.expectTrue('占位文案里没有判定/答案的影子(交卷之前不许透露应有值)',
    banned.length === 0, `${banned.join(',')} / ${JSON.stringify(hints)}`);
  // 旧写法:屏上串与源码 regex 抓出来的串**同时**改就永远绿;抓不到字面串时只 say 一句就跳过。
  // 现在两头都钉成同一个字面串,任何一侧漂了就红,而"改文案的人会把闸门弄红"正是想要的摩擦。
  p.expectTrue('③ 屏上每一格印出来的占位文案都**逐字**等于钉住的那句字面串',
    hints.length >= 2 && hints.every((h) => h === PLACEHOLDER),
    `${JSON.stringify(hints)} / 钉的是「${PLACEHOLDER}」—— 改这句文案请同步本文件里的 PLACEHOLDER`);
  const pageSrc = readFileSync(join('entry', 'src', 'main', 'ets', 'pages', 'ExperimentPage.ets'), 'utf8');
  const ph = pageSrc.match(/placeholder\s*:\s*(["'`])([^"'`]*)\1/);
  if (ph === null) {
    p.fail('③ 源码里的 placeholder 字面串', 'ExperimentPage.ets 里 placeholder 不再是字段字面串'
      + '(写成变量或模板串了)—— 这条不许静默跳过:读屏那条钉的是字面串,'
      + '源码这一头也必须能对得上');
  } else {
    p.expect('③ 源码里的 placeholder 字面串 = 钉住的那句', ph[2], PLACEHOLDER);
  }
  p.shot('answer-empty');

  p.say('== T2. ⑤ 最后一格填空到「交卷评分」隔多远(只量,不动版面) ==');
  p.scrollToTop();
  let prev = nodes();
  /**
   * 面板视口先量出来,而且**每一甩的行程必须比它短**。
   *
   * 本轮实测(勘察 task10-logs/fix1-pairing-probe.log):旧代码一甩 1100 px(1900→800),
   * 而面板视口只有 1035 px —— 一甩就把整屏内容换掉,两次快照在面板里压根没有重叠节点,
   * 位移永远配不出来,每次都掉进 1100 兜底。报告里那句「累计挪 4400 px」= 4 × 1100,
   * 全是兜底字数出来的,不是量出来的(那正是 C1)。
   * 改成 380 px 一小段之后同一份配对就能数出重叠节点:实测 3 段配对给中位 465/483/484,
   * 行程 300 px 给 5 段配对中位 344 —— 所以"量不到"是甩太长,不是这块屏量不了。
   */
  /**
   * ⑤ 的一趟扫描:从当前这一屏往下甩,逐段配对累计位移,直到最后一格填空进屏。
   *
   * 为什么提成函数:一段配不上(动画中途取帧 → 面板里没有重叠节点)是这台机器的常态,
   * 而"掺假计数必须为 0"这条闸门要的是**一个能引用的数**,不是"一次都不许失手"。
   * 所以整趟最多量三遍,任何一遍干净就采用那一遍;三遍都不干净才红 ——
   * 那时报的是"这块屏今天量不出可引用的数",而不是把假设数当实测交给 #67。
   */
  function sweepOnce(startPrev) {
    let prev = startPrev;
    const band = panelBand(prev);
    const viewport = band === null ? 0 : band[3] - band[1];
    p.expectTrue('⑤ 面板可视窗口高度量到了(取不到就 FAIL,不许 Math.max(viewport,1) 把除法兜过去)',
      viewport > 0, `这一屏的树里没有 Scroll 节点(快照 ${prev.length} 个节点)`);
    // 行程取视口的四成(实测 1035 × 0.4 ≈ 414):300 px 那档能配 5 条、500 px 只配 3 条、
    // 700 px 掉到 2 条、1100 px 一条都配不上 —— 留 414 是既配得多、又不把趟数拖太长
    const stroke = viewport > 0 ? Math.round(viewport * 0.4) : 400;
    const strokeFrom = band === null ? 1900 : band[3] - 40;
    const strokeTo = strokeFrom - stroke;
    p.say(`  ⑤ 面板横条 y ${band === null ? '(没量到)' : band[1] + '..' + band[3]},视口高 ${viewport} px;`
      + `每一甩按 ${stroke} px(${strokeFrom}→${strokeTo}),必须小于视口才配得上`);
    let acc = 0;
    let measuredPx = 0;
    let measuredSegs = 0;
    let assumedSegs = 0;
    let settledSegs = 0;
    const assumedAt = [];
    const segLog = [];
    let btnBottom = -1;
    let btnTop = -1;
    let boxTop = -1;
    let boxBottom = -1;
    let swipes = 0;
    let sameScreen = false;
    for (let i = 0; i < 32; i++) {
      const btn = prev.find((n) => (n.text || '') === '交卷评分');
      if (btn !== undefined && btnBottom < 0) {
        btnBottom = rectOf(btn.bounds)[3] + acc;
        btnTop = rectOf(btn.bounds)[1] + acc;
      }
      const bs = prev.filter((n) => n.type === 'TextInput');
      if (bs.length >= 2) {
        let last = bs[0];
        for (const b of bs) {
          if (rectOf(b.bounds)[3] > rectOf(last.bounds)[3]) {
            last = b;
          }
        }
        boxTop = rectOf(last.bounds)[1] + acc;
        boxBottom = rectOf(last.bounds)[3] + acc;
        sameScreen = btn !== undefined;
        break;
      }
      p.swipe(EDGE, strokeFrom, EDGE, strokeTo);
      swipes += 1;
      let cur = nodes();
      let s = shiftBetween(prev, cur, band);
      // 配不上对绝大多数不是"没挪",是惯性/动画还没停就取了第二帧(本轮实测:第 6 下配到 7 条、
      // 极差 128 > 120 就被判没配上)。多等一拍重取一帧再判 —— 但**等过才配上也要记进出处**,
      // 不然读日志的人以为这是一次干净的配对。
      let settled = 0;
      while (s.med <= 0 && settled < 2) {
        settled += 1;
        p.sleep(900);
        cur = nodes();
        const again = shiftBetween(prev, cur, band);
        if (again.med > 0) {
          s = again;
        }
      }
      if (s.med > 0) {
        acc += s.med;
        measuredPx += s.med;
        measuredSegs += 1;
        if (settled > 0) {
          settledSegs += 1;
        }
        segLog.push(`${swipes}:${s.med}(配${s.pairs}条/一致${s.agree}条/极差${s.spread}${settled > 0 ? `/等${settled}拍` : ''})`);
      } else {
        // Ruling AA:兜底留着(惯性/动画让某一下配不上是常态),但这一段**单独记账**,
        // 不许混进"实测"那一行 —— 屏幕上那一行必须写成「实测 X px + 假设 Y 段(不算数)」
        acc += ASSUMED_PX;
        assumedSegs += 1;
        assumedAt.push(swipes);
        segLog.push(`${swipes}:假设(配${s.pairs}条/一致${s.agree}条/极差${s.spread}/等${settled}拍仍没配上)`);
      }
      prev = cur;
    }
    return { band: band, viewport: viewport, acc: acc, measuredPx: measuredPx,
      measuredSegs: measuredSegs, assumedSegs: assumedSegs, settledSegs: settledSegs,
      assumedAt: assumedAt, segLog: segLog, btnBottom: btnBottom, btnTop: btnTop,
      boxTop: boxTop, boxBottom: boxBottom, swipes: swipes, sameScreen: sameScreen };
  }

  let sweep = null;
  for (let attempt = 1; attempt <= 3; attempt++) {
    sweep = sweepOnce(prev);
    if (sweep.assumedSegs === 0) {
      break;
    }
    if (attempt < 3) {
      p.say(`  ⑤ 第 ${attempt} 趟有 ${sweep.assumedSegs} 段没配上,回到页顶重量一遍(不采用这一趟的数)`);
      p.scrollToTop();
      p.sleep(600);
      prev = nodes();
    }
  }
  const { band, viewport, acc, measuredPx, measuredSegs, assumedSegs, settledSegs, assumedAt,
    segLog, btnBottom, btnTop, boxTop, boxBottom, swipes, sameScreen } = sweep;
  p.expectTrue('⑤ 量到了:交卷按钮与最后一格填空的内容坐标都取到',
    btnBottom > 0 && boxTop > 0, `按钮下沿 ${btnBottom} / 框上沿 ${boxTop}`);
  const gap = boxTop - btnBottom;
  p.say(`  ⑤ 从页顶甩到最后一格共 ${swipes} 下:配对成功 ${measuredSegs} 段(实测累计 ${measuredPx} px,`
    + `其中 ${settledSegs} 段是多等一拍才配上的)、`
    + `没配上 ${assumedSegs} 段(第 ${assumedAt.join(',') || '—'} 下,每段按 ${ASSUMED_PX} px 记账,不算数)`);
  p.say(`  ⑤ 逐段账:${segLog.join(' / ')}`);
  if (assumedSegs === 0) {
    p.say(`  ⑤ 实测:累计挪 ${measuredPx} px`);
  } else {
    p.say(`  ⑤ 实测 ${measuredPx} px + 假设 ${assumedSegs} 段(不算数)—— 这一趟的累计数不能当实测引用`);
  }
  p.say(`  ⑤「交卷评分」内容 y ${btnTop}..${btnBottom};最后一格填空内容 y ${boxTop}..${boxBottom}`);
  p.expectTrue('⑤ 掺假计数为 0:每一段位移都是两次快照配出来的,才允许把总数当"实测"引用',
    assumedSegs === 0, `没配上 ${assumedSegs} 段(第 ${assumedAt.join(',')} 下),累计数 ${acc} px 里有假设`);
  p.expectTrue('⑤ 交卷按钮与最后一格填空不在同一屏(这条就是要记的那个数字)',
    !sameScreen, '竟然同屏可见,量到的距离不成立');
  if (assumedSegs === 0 && viewport > 0) {
    p.say(`  ⑤ 两者之间 ${gap} px = ${(gap / viewport).toFixed(2)} 屏(视口 ${viewport} px);`
      + `打完字要看得见交卷按钮得往回滚;同一屏同时可见:${sameScreen ? '是' : '否'}`);
  } else {
    p.say(`  ⑤ 两者之间 ${gap} px —— **含假设段,不换算成屏数**(旧版拿 Math.max(viewport,1) 除出来的`
      + '「3.91 屏」就是这种没有出处的数)');
  }
  p.shot('answer-last-box-screen');

  p.say('== T3. 学生打的字进得了框;框里就是打的那几个字 ==');
  p.expectTrue('打字 9.80 进分子那一格', typeInto(NUM_LABEL, '9.80'), 'typeInto 失败');
  p.expect('框里就是打进去的 9.80(小数点没被吞)', boxText(NUM_LABEL), '9.80');
  const again = locateCell(NUM_LABEL);
  if (again !== null) {
    const c = Probe.center(again.bounds);
    p.shell(`uitest uiInput inputText ${c[0]} ${c[1]} 9.80`);
    p.sleep(1200);
    p.say(`  inputText 追加实测:不清再打一次 9.80 → 框里是「${boxText(NUM_LABEL)}」`
      + '(所以 typeInto 必须先清框)');
  }
  p.expectTrue('退格能把一整格清干净', clearBox(NUM_LABEL), '清不掉');
  p.expect('清完之后框是空的', boxText(NUM_LABEL), '');
  // 脏输入:SDK 文档承诺 NUMBER_DECIMAL「digits and only one decimal point」,屏上验这句
  p.expectTrue('往空格打 9.8.0', typeInto(NUM_LABEL, '9.8.0'), 'typeInto 失败');
  const dirty = boxText(NUM_LABEL);
  p.say(`  脏输入实测:打 9.8.0 → 框里留下「${dirty}」(Number() = ${Number(dirty)})`);
  p.expectTrue('组件自己就把第二个小数点滤掉了(框里不会留着解析不出的脏字串)',
    dirty.indexOf('.') === dirty.lastIndexOf('.'), `框里是「${dirty}」`);
  p.expectTrue('滤完之后不是 0,也不是空', dirty !== '0' && dirty.length > 0, `框里是「${dirty}」`);
  clearBox(NUM_LABEL);

  p.say('== T4. 回显纪律:打字时不许有字、不许有底色、不许有图标(brief 断言 6 + ②) ==');
  // 每一次快照之前都把软键盘收掉。实测原因:往空框打字那一下,键盘弹起会把面板重新定位,
  // 下面那一格的问句因此滚进量窗(整屏对照实测:TextInput 只有 text 从空变「9.80」,新增的两个
  // 节点是下一条填空的 label 与它的容器,应用什么都没加)。拿「空」与「填了」直接比节点数,
  // 量到的是键盘而不是回显;键盘收干净之后同一个量窗才比得出东西。
  // 比两组:空 → 填值(抓「一有字就冒出来的对勾」),换一个值(抓「值一变底色就变」)。
  p.expectTrue('两格都是空的(基线)', boxText(NUM_LABEL) === '' && boxText(DEN_LABEL) === '',
    `${boxText(NUM_LABEL)} / ${boxText(DEN_LABEL)}`);
  // I7:这三道闸门要的是「键盘确实收起了」这个**结论**。旧版 hideKeyboard() 返回布尔,
  // 而 imeTop 认不出键盘时也返回 -1 —— 于是"看不见键盘"被当成"已收起",下面这两组结构闸门
  // 可能在键盘还支着的时候比(键盘会把面板顶偏),绿了也不作数。现在三态:只有 'down' 算过。
  p.expectTrue('基线快照前键盘已收起(认不出键盘也算不过)', p.hideKeyboard() === 'down',
    '键盘收不掉或认不出状态,这一节的量窗不稳');
  const baseList = nodes();
  const baseRegion = regionOf(baseList);
  const base = fingerprint(baseRegion);
  const baseRegionHits = echoHits(baseRegion === null ? [] : baseRegion);
  const basePageHits = echoHits(baseList);
  p.say(`  基线:这一节 ${base === null ? '不在屏上' : base.length + ' 个节点'};`
    + `这一节里回显词命中「${baseRegionHits === '' ? '无' : baseRegionHits}」;`
    + `整屏命中「${basePageHits === '' ? '无' : basePageHits}」`);
  p.expectTrue('打一个明显错的数进分子格(3.14)', typeInto(NUM_LABEL, '3.14'), 'typeInto 失败');
  p.expectTrue('打一个明显错的数进分母格(77)', typeInto(DEN_LABEL, '77'), 'typeInto 失败');
  p.expectTrue('甲快照前键盘已收起(I7:unknown 也算不过)', p.hideKeyboard() === 'down', '键盘收不掉或认不出状态');
  const midList = nodes();
  const midDiff = echoDiff(base, fingerprint(regionOf(midList)));
  p.expectTrue('② 空框填上值之后,这一节的结构一个字都没变(多一个图标、多一行字都在这里露形)',
    midDiff === '', midDiff);
  p.expectTrue('换一个值:分子 2.71、倍数 44',
    typeInto(NUM_LABEL, '2.71') && typeInto(DEN_LABEL, '44'), 'typeInto 失败');
  p.expectTrue('乙快照前键盘已收起(I7:unknown 也算不过)', p.hideKeyboard() === 'down',
    '键盘收不掉或认不出状态');
  const afterList = nodes();
  // 空转闸门:甲乙必须是两组不同的数,否则这条比的同一张快照,绿了也不算验过
  const midFilled = (regionOf(midList) || []).filter((n) => n.type === 'TextInput').map((n) => n.text).join(',');
  const afterFilled = (regionOf(afterList) || []).filter((n) => n.type === 'TextInput').map((n) => n.text).join(',');
  p.expectTrue('甲乙取的确实不是同一组数(否则下面那条比的是自己)',
    midFilled !== afterFilled && midFilled.length > 0, `甲「${midFilled}」 乙「${afterFilled}」`);
  const diff = echoDiff(fingerprint(regionOf(midList)), fingerprint(regionOf(afterList)));
  p.expectTrue('② 换一个值,这一节的结构一个字都没变(文本、底色、图标、层级全比)',
    diff === '', diff);
  const colored = (regionOf(afterList) || []).filter((n) => (n.backgroundColor || '') !== ''
    && n.backgroundColor !== '#00000000').map((n) => n.type + '=' + n.backgroundColor);
  p.say(`  这一节里带底色的节点:${JSON.stringify(colored)}`);
  p.expectTrue('② 这一节里不许出现新的判定词',
    echoHits(regionOf(afterList) || []) === baseRegionHits,
    `${baseRegionHits} → ${echoHits(regionOf(afterList) || [])}`);
  p.expectTrue('② 整屏也不许出现新的判定词(交卷之前)',
    echoHits(afterList) === basePageHits, `${basePageHits} → ${echoHits(afterList)}`);
  p.shot('answer-typing-no-echo');
  p.say('  这一条抓不到的:纯 fontColor 变化。本轮实测 dumpLayout 加 -a 也不输出字色字段,'
    + '树里只有 backgroundColor —— 字色那一半只能看下面两张截图,报告里如实写明。');
  return true;
}

// =====================================================================
// 一b、sr-003 逐差法 B 段:手上动作 + ④ 起点、60 / 60(脏框) / 80 / 100、断言 8
// =====================================================================
function tapeB() {
  p.launch();
  p.ensureHome();
  if (!p.tapInList(TAPE_TITLE)) {
    return false;
  }
  firstLabel = NUM_LABEL;
  secondLabel = DEN_LABEL;

  p.say('== T5. 手上动作做完(不碰滑杆)与 ④ 计数起点的承诺 ==');
  press('开始');
  press('接通／断开电源');
  p.sleep(1600);
  press('释放小车');
  p.sleep(3200);
  const dots = readout('纸带上的点数');
  p.expectTrue('纸带打出了一串点', parseInt(dots, 10) > 60, `实得「${dots}」`);
  const sld = readout2('计数起点：从第几个点量起（开头密着的点会自动舍掉）');
  const slider = sld.value;
  const eff = readout('有效计数起点');
  p.say(`  ④ 滑杆那一格印「${slider}」,应用真用的起点印「${eff}」`);
  p.expectTrue('④ 头上密着点时,有效起点确实不等于滑杆给的值', slider !== eff && eff.length > 0,
    `滑杆 ${slider} vs 有效 ${eff}`);
  /**
   * I3:谎话检查必须先**匹配到句子**才有资格判"每句都诚实"。
   *
   * 旧版写的是 `claims.every(...)`,而 claims 的正则只认「从第 **数字** 个点量起」——
   * 交卷前那一屏压根没有这种句子(滑杆 label 写的是"从第几个点量起",不带数字),
   * 于是 `every([])` 恒真,这条从上线那天起就没判过任何东西。
   * 现在:① 匹配口径放宽到「从第几 / 从第 N 个点量起」这一族说法;
   *      ② 一条都没匹配到 = 这条断言自己没出题 → FAIL。
   * (兜它的是离线 findDishonestStartLabels,但探针不能靠"另一处有钉"给自己发绿。)
   */
  const START_CLAIM = /从第\s*(?:\d+|几)\s*个点量起/;
  const claims = sld.screen.filter((t) => START_CLAIM.test(t));
  p.say(`  ④ 那一屏里匹配到「从第…个点量起」的句子(${claims.length} 句):${claims.join(' / ') || '(无)'}`);
  p.expectTrue('④ 谎话检查至少匹配到一句(匹配到 0 句就是这条断言自己没出题,必须红)',
    claims.length > 0, `那一屏 ${sld.screen.length} 条文本里没有一句「从第…个点量起」`);
  p.expectTrue('④ 屏幕上没有任何一句把滑杆那个值说成"就从这里量起"(谎话检查)',
    claims.length > 0 && claims.every((t) => t.indexOf('舍掉') >= 0), claims.join(' / '));
  p.expectTrue('④ 那句问话确实写了会自动舍掉',
    sld.screen.some((t) => t.indexOf('计数起点') === 0 && t.indexOf('开头密着的点会自动舍掉') > 0),
    '滑杆 label 不在那一屏,或那句承诺不见了');
  const short = readout('最短计数段');
  p.expectTrue('最短一段量得出来(否则 60 分的账就不止两格没交)', parseFloat(short) >= 2, `实得「${short}」`);

  p.say('== T6. 一条都不填、手上动作做完后交卷 → 判词含"没交",得分 60(brief 断言 3) ==');
  clearBox(NUM_LABEL);
  clearBox(DEN_LABEL);
  press('交卷评分');
  const none = verdictBlob();
  p.say('  判词:' + none.replace(/\n/g, ' ⏎ ').slice(0, 800));
  p.expect('一条不填 → 60 分', scoreOf(none), 60);
  p.expectTrue('判词里两格都写着"没交"', (none.match(/判定：没交/g) || []).length === 2,
    none.slice(0, 300));
  p.expectTrue('没交那一格印的是破折号而不是 0(空框不许被吞成 0)',
    none.indexOf('你交的分子是 —') >= 0 && none.indexOf('你交的分子是 0') < 0, none.slice(0, 300));
  p.shot('answer-none-60');
  const mNum = none.match(/按逐差法应为\s*([\d.]+)\s*mm/);
  const mSeg = none.match(/参与逐差的共\s*(\d+)\s*段/);
  const mDen = none.match(/这条纸带该是\s*(\d+)/);
  p.expectTrue('判词把应有分子/参与段数/应有倍数都报了(后面两格照着填)',
    mNum !== null && mSeg !== null && mDen !== null, none.slice(0, 400));
  if (mNum === null || mSeg === null || mDen === null) {
    p.say('判词读不出应有值,后面的 80/100 两步无法进行');
    return false;
  }
  const numTrue = parseFloat(mNum[1]);
  const twoH = parseInt(mSeg[1], 10);
  const denTrue = parseInt(mDen[1], 10);

  p.say('== T6b. 打一个 Number() 认不出的字串:通道要读作没交,不许当成 0 ==');
  p.expectTrue('往分子格只打一个小数点 .', typeInto(NUM_LABEL, '.'), 'typeInto 失败');
  const lone = boxText(NUM_LABEL);
  p.say(`  只打一个小数点 → 框里留下「${lone}」;Number('${lone}') = ${Number(lone)}`);
  /**
   * I5:先钉住"框里真的是那个字",再判交卷后果。
   *
   * 旧版没有这一条:标签写着"打一个 Number() 认不出的字串",可要是 `.` 被 NUMBER_DECIMAL
   * 的 inputFilter 吃掉,交上去的是**空框** —— 空框照样判 60 / 没交 / 印破折号,三条断言全绿,
   * 而这一趟压根没测到"脏框不许被吞成 0"。所以这里既钉读到的那一次,也钉交卷前的那一次
   * (中间隔着滚动,再读一次才算真的把 `.` 交了上去)。
   */
  p.expect('T6b 先钉住框里就是单独一个小数点(不是被滤空的空框)', lone, '.');
  const loneBeforeSubmit = boxText(NUM_LABEL);
  p.expect('T6b 交卷前再读一次:框里还是那一个小数点', loneBeforeSubmit, '.');
  press('交卷评分');
  const dirtyRun = verdictBlob();
  p.expect('脏框照样 60 分,不是判成 0(这一趟框里确实带着 .)', scoreOf(dirtyRun), 60);
  p.expectTrue('这一格的判词是"没交"而不是"算错了"',
    dirtyRun.indexOf('判定：没交') >= 0, dirtyRun.slice(0, 300));
  p.expectTrue('屏上不出现「你交的分子是 0」这种把脏值当零的说法',
    dirtyRun.indexOf('你交的分子是 0') < 0 && dirtyRun.indexOf('你交的分子是 —') >= 0,
    dirtyRun.slice(0, 400));
  p.shot('answer-dirty-60');

  /**
   * ④ 补的那一半:判词里那句「这条纸带从第 N 个点量起」到底说的是哪个数。
   * 交卷前那一屏只匹配得到滑杆 label(不带数字),真带数字的是判词这一句 ——
   * 它必须等于屏上「有效计数起点」,不是滑杆那格;否则应用就是在判词里对学生撒谎。
   */
  const effNum = ((eff.match(/\d+/) || [])[0] || '');
  const sliderNum = ((slider.match(/\d+/) || [])[0] || '');
  const verdictClaims = dirtyRun.split('\n').filter((t) => /从第\s*\d+\s*个点量起/.test(t));
  p.expectTrue('④ 判词里也给出了起点(至少一句带数字的「从第 N 个点量起」)',
    verdictClaims.length > 0 && effNum.length > 0, `判词匹配 ${verdictClaims.length} 句 / 有效起点「${eff}」`);
  p.expectTrue(`④ 判词里的起点就是屏上那个有效计数起点 ${effNum}(不是滑杆那格 ${sliderNum})`,
    verdictClaims.length > 0 && verdictClaims.every((t) => {
      const n = (t.match(/从第\s*(\d+)\s*个点量起/) || [])[1];
      return n === effNum;
    }), verdictClaims.join(' ⏎ '));

  // F1(只用首尾两段)= 末段 减 首段。窗口是等加速打出来的等差数列:
  // 应有分子 = h²·d、倍数 = h²、参与段数 = 2h ⇒ F1 = (2h−1)·应有分子 ÷ 倍数。
  // 离线用真 runner 试过 15 条窗口(通电 0.17~2.5 s × 放车 1~7 s),这条恒等式偏差 0.000000%。
  const f1 = (twoH - 1) * numTrue / denTrue;
  const f1Typed = f1.toFixed(1);
  // 同一个数在两个屏上各按各的尺子印:判词 132、历史 131.70(两把尺子见上面注释)
  const f1Shown = verdictNumber(parseFloat(f1Typed));
  const f1Fact = historyNumber(parseFloat(f1Typed));
  p.say(`  从判词推 F1:(${twoH}−1)×${numTrue}÷${denTrue} = ${f1Typed} mm`
    + `(判词按 Judgment.text 会印成 ${f1Shown} mm,历史按 FactLabels.valueText 会印成 ${f1Fact} mm)`);

  p.say('== T7. 分子填 F1(只吃首尾那个数)→ 判词点名,得分 80(brief 断言 4) ==');
  // 这一轮的基线就地取:上一次交卷留下的判词本来就在屏上,闸门比的是"打字有没有新增东西"。
  // 先把最后一格滚进视野,让基线快照与打字后的快照落在同一个滚动位置上。
  locateCell(DEN_LABEL);
  const preList = nodes();
  const preRegion = regionOf(preList);
  const preFp = fingerprint(preRegion);
  const preRegionHits = echoHits(preRegion === null ? [] : preRegion);
  const prePageHits = echoHits(preList);
  p.expectTrue('分子格填 F1', typeInto(NUM_LABEL, f1Typed), 'typeInto 失败');
  p.expect('分子格读回 F1', boxText(NUM_LABEL), f1Typed);
  p.expectTrue('分母格照应有值填', typeInto(DEN_LABEL, String(denTrue)), 'typeInto 失败');
  p.expect('分母格读回应有倍数', boxText(DEN_LABEL), String(denTrue));
  const midList = nodes();
  const midRegion = regionOf(midList);
  p.expectTrue('交卷之前仍然没有回显:这一节结构原样(填数这一轮再查一次)',
    echoDiff(preFp, fingerprint(midRegion)) === '', echoDiff(preFp, fingerprint(midRegion)));
  p.expectTrue('交卷之前仍然没有回显:这一节没有新增判定词',
    echoHits(midRegion === null ? [] : midRegion) === preRegionHits,
    `${preRegionHits} → ${echoHits(midRegion === null ? [] : midRegion)}`);
  p.expectTrue('交卷之前仍然没有回显:整屏判定词集合不比打字前多',
    echoHits(midList) === prePageHits, `${prePageHits} → ${echoHits(midList)}`);
  press('交卷评分');
  const named = verdictBlob();
  p.expect('只吃首尾那一种 → 80 分', scoreOf(named), 80);
  p.expectTrue('判词点名"算错了"而不是"没交"',
    named.indexOf('判定：算错了') >= 0 && named.indexOf('判定：没交') < 0, named.slice(0, 400));
  /**
   * C2:判词侧的"点名"要能红,而且比的是**互斥**,不是"这句话在不在"。
   *
   * 上一版这里写 `named.indexOf('只用首尾两段会把中间量出来的数全丢掉') >= 0` ——
   * 而 RubricTape.ets:61 那一句**两族分子错法的名字都写死在里面**(离线 check.mjs:9413
   * 还专门钉着"分子那条说出两族"),所以无论学生犯哪一种它都在屏上,那条恒绿:
   * 比的根本不是点名,是一段静态文案。本轮改成三件事:
   *   ① 整条静态尾巴逐字钉住(细则那句删掉半句 → 这条红,不重建构建也能红 —— 源码那一头也钉);
   *   ② 互斥负对照:他**没犯**的那一族(分母那一问)的扣分句与点名词,一个字都不许出现在判词里;
   *   ③ 换一种错法(T7b:分子交对、分母填 1)再交一次,被点名的那一族必须**跟着翻**。
   * 剩下的那条差异如实写明:分子题内部 F1 与 F3 两族的名字是同一句静态文案里的,
   * 判词并不按他犯的那一条动态挑字 —— 那是应用的账,见报告 §残余。
   */
  const numLines = deductionLines(named, NUM_LINE);
  const denLines = deductionLines(named, DEN_LINE);
  p.expect('C2 分子那一问的扣分句恰好一条', numLines.length, 1);
  p.expect('C2 分母那一问的扣分句 0 条(他这一问照应有值交了)', denLines.length, 0);
  const numLine = numLines.length > 0 ? numLines[0] : '';
  p.expectTrue('C2 分子那句点名的**整条静态尾巴**逐字钉在屏上(细则改半句这条必须红)',
    numLine.indexOf(NUM_NAME_TAIL) >= 0, `屏上:「${numLine.slice(0, 300)}」`);
  p.expectTrue('C2 互斥负对照:他没犯分母那一族 → 分母族的点名词不许出现在整块判词里',
    familyHits(named, DEN_FAMILY).length === 0,
    `命中「${familyHits(named, DEN_FAMILY).join(',')}」/ ${named.slice(0, 300)}`);
  p.expectTrue('C2 分子族的词确实在判词里(点名要说得出他错的那一种)',
    familyHits(named, NUM_FAMILY).length >= 1, named.slice(0, 300));
  const rubricSrc = readFileSync(join('entry', 'src', 'main', 'ets', 'bench', 'RubricTape.ets'), 'utf8');
  p.expectTrue('C2 钉住的那两句静态文案确实逐字出自 RubricTape.ets(改细则不重建也会红)',
    rubricSrc.indexOf(NUM_NAME_TAIL) >= 0 && rubricSrc.indexOf(DEN_NAME_TAIL) >= 0,
    'RubricTape.ets 里找不到钉住的尾巴 —— 细则文案漂了,请同步本文件的 NUM_NAME_TAIL / DEN_NAME_TAIL');
  p.say('  C2 记账(不是通过):分子那一问的句子把 F1『只用首尾两段』与 F3『相邻两两相减』两族'
    + '都写死在同一条静态文案里,所以判词**没有**按他犯的那一条挑字;'
    + '两次交卷(F1 与 F3)那两族的出现情况不会跟着换 —— 这是应用的账,交 Task 11 裁定。');
  p.expectTrue('判词里印着他填的那个数(ans 进判词,按判词那把尺子的格式精确匹配)',
    named.indexOf('你交的分子是 ' + f1Shown + ' mm') >= 0, named.slice(0, 500));
  // 加严:印的必须是他自己那个数,不能是把应有值原样回显(两者不同字才说明是两条不同的量)
  p.expectTrue('判词印的是他填的数而不是应有值的回显(两个数必须不同)',
    f1Shown !== mNum[1] && named.indexOf('你交的分子是 ' + mNum[1] + ' mm') < 0,
    `他填的印成 ${f1Shown} / 应有值 ${mNum[1]} / ${named.slice(0, 300)}`);
  p.shot('answer-f1-80');

  p.say('== T7b. 换一种错法再交一次:分子照应有值、分母填 1(漏乘平方那一族)→ 点名的族必须跟着翻 ==');
  // C2 的第三件事:上一条钉的是"分子那一问响、分母那一问不响",这一条把它翻过来。
  // 翻不过来的实现(比如两条扣分句永远都印)在这条就红了 —— 那正是评审要的"跟着换"。
  p.expectTrue('分子格改回应有值(这一问不再犯错)', typeInto(NUM_LABEL, mNum[1]), 'typeInto 失败');
  p.expect('分子格读回应有的数', boxText(NUM_LABEL), mNum[1]);
  p.expectTrue('分母格填 1(该是 ' + denTrue + ':漏乘段数平方那一族)',
    typeInto(DEN_LABEL, '1'), 'typeInto 失败');
  p.expect('分母格读回 1', boxText(DEN_LABEL), '1');
  press('交卷评分');
  const flipped = verdictBlob();
  p.say('  换错法之后的判词:' + flipped.replace(/\n/g, ' ⏎ ').slice(0, 600));
  p.expect('换一种错法 → 仍是 80(只扣分母那一问的 20)', scoreOf(flipped), 80);
  p.expect('C2 翻面:分子那一问的扣分句 0 条', deductionLines(flipped, NUM_LINE).length, 0);
  const fdenLines = deductionLines(flipped, DEN_LINE);
  p.expect('C2 翻面:分母那一问的扣分句恰好一条', fdenLines.length, 1);
  const fdenLine = fdenLines.length > 0 ? fdenLines[0] : '';
  p.expectTrue('C2 翻面:分母那句点名的整条静态尾巴逐字钉在屏上',
    fdenLine.indexOf(DEN_NAME_TAIL) >= 0, `屏上:「${fdenLine.slice(0, 300)}」`);
  p.expectTrue('C2 翻面的互斥负对照:分子族的名字这次一个字都不许出现',
    familyHits(flipped, NUM_FAMILY).length === 0,
    `命中「${familyHits(flipped, NUM_FAMILY).join(',')}」/ ${flipped.slice(0, 300)}`);
  p.expectTrue('C2 判词印的是他填的分母 1,不是应有值 ' + denTrue + ' 的回显',
    fdenLine.indexOf('你交的分母倍数是 1') >= 0 && fdenLine.indexOf('你交的分母倍数是 ' + denTrue) < 0,
    fdenLine.slice(0, 300));
  p.expectTrue('C2 两次交卷点名的那一族确实换了(上一条比的是分子句,这一条比的是分母句)',
    numLines.length === 1 && fdenLines.length === 1 && deductionLines(named, DEN_LINE).length === 0,
    `分子犯错那趟:${numLines.length}/${deductionLines(named, DEN_LINE).length} 条,`
    + `分母犯错那趟:${deductionLines(flipped, NUM_LINE).length}/${fdenLines.length} 条`);
  p.shot('answer-den-80');

  p.say('== T8. 两格都照应有值填 → 得分 100(brief 断言 5) ==');
  p.expectTrue('分子格填应有值', typeInto(NUM_LABEL, mNum[1]), 'typeInto 失败');
  p.expect('分子格读回应有值', boxText(NUM_LABEL), mNum[1]);
  p.expectTrue('分母格改回应有倍数(上一趟故意填错,这一趟必须翻回来)',
    typeInto(DEN_LABEL, String(denTrue)), 'typeInto 失败');
  p.expect('分母格读回应有倍数', boxText(DEN_LABEL), String(denTrue));
  press('交卷评分');
  const full = verdictBlob();
  p.expect('照应有值交满 → 100 分', scoreOf(full), 100);
  p.expectTrue('满分之上没有扣分句', full.indexOf('没算对或没交') < 0, full.slice(0, 500));
  p.expectTrue('满分那句照样把来源说清(参考细则不伪装成官方标准)',
    full.indexOf('没有扣分项') >= 0 && full.indexOf('参考细则') >= 0, full.slice(0, 500));
  p.shot('answer-full-100');

  p.say('== T9. 键盘弹起时那一格还在不在可视区(brief 断言 8 + I7) ==');
  const kb = locateCell(NUM_LABEL);
  if (kb === null) {
    p.fail('断言 8:键盘弹起时那一格还在可视区', '定位不到分子那一格,这一条没法出题');
  } else {
    const kc = Probe.center(kb.bounds);
    // 先点一下交焦点,再 inputText:本轮实测**光点击不弹键盘**(hostWindowId 还是那三个),
    // 而只发 inputText 有时也不弹 —— 两个都要,才把"键盘真的支起来了"这个前提做出来。
    p.shell(`uitest uiInput click ${kc[0]} ${kc[1]}`);
    p.sleep(1200);
    p.shell(`uitest uiInput inputText ${kc[0]} ${kc[1]} 5`);
    p.sleep(1500);
    const upList = nodes();
    const ime = p.imeState(upList);
    const screenNode = upList.find((n) => n.type === 'root');
    const screenBottom = screenNode === undefined ? 2760 : rectOf(screenNode.bounds)[3];
    const focusables = upList.filter((n) => n.type === 'TextInput');
    let r = null;
    for (const n of focusables) {
      if ((n.text || '').length > 0) {
        r = rectOf(n.bounds);
      }
    }
    p.say(`  键盘实测:${ime.state}(${ime.why})${ime.state === 'up' ? ',键帽上沿 y=' + ime.top : ''};`
      + `屏幕下沿 ${screenBottom};带着字的框 bounds=${JSON.stringify(r)};窗口分布 ${p.winHist(upList)}`);
    p.expectTrue('打字之后框里有他打的字(这一格还没被清)', r !== null, '找不到带字的输入框');
    /**
     * I7:这一条以前在"看不见键盘"时会退化成"框在屏内"这一半照样绿(报告 §七.2 说的就是它)。
     * 现在前提必须自己站得住:**键盘确实支着**(state === 'up')才允许判"没被顶出可视区";
     * 认不出状态(unknown)或压根没弹起来(down)都算这条没出题 → 红,不许拿半个测量充数。
     */
    p.expectTrue('断言 8 的前提:键盘真的支起来了(unknown / down 都算这条没出题)',
      ime.state === 'up', `imeState=${ime.state}(${ime.why})—— 窗口分布 ${p.winHist(upList)}`);
    p.expectTrue('断言 8:键盘弹起时那一格完整在屏幕内,且没被键盘盖住',
      ime.state === 'up' && r !== null && r[1] >= 0 && r[3] <= screenBottom && r[3] <= ime.top,
      `框 ${JSON.stringify(r)} / 键盘上沿 ${ime.top} / 屏幕下沿 ${screenBottom}`);
    p.shot('answer-keyboard');
    if (p.hideKeyboard() !== 'down') {
      p.fail('断言 8 收尾:把键盘收回', '认不出键盘状态,后面的读框会被键盘位移污染');
    }
  }
  clearBox(NUM_LABEL);
  return {
    numShown: mNum[1], f1Typed: f1Typed, f1Shown: f1Shown, f1Fact: f1Fact, denTrue: String(denTrue)
  };
}

// =====================================================================
// 二、历史回看:ans.* 落盘(brief 断言 7)
// =====================================================================
function historyPart(info) {
  p.say('== T10. 历史回看:报告页选这条记录,看得见他填的分子数值 ==');
  p.launch();
  p.ensureHome();
  if (!p.tap('报告')) {
    return false;
  }
  /**
   * 逐行点开历史列表,找主段**每一格都**印成 wants 的记录,返回那一屏的文本表。
   *
   * 三处本轮实测出来的形状,少知道一条这步就找不到记录:
   *   · 列表不在主段旁边 —— 它在主段下面好几屏远,scrollToTop 之后就地找一条也没有
   *     (上一版就是这么找的,报「连着点开 0 行」);
   *   · 认行用时刻那一格(HH:MM):一行一个、跨滚动稳定。摘要那一格认不了行 ——
   *     ReportPage.factLineOf(ReportPage.ets:187)只印前三条事实(循环写死 `i < 3`),
   *     分子那条不保证在前三里(本轮实测就不在),上一版拿摘要子串找,找不到时
   *     Array.find 给的是 undefined 而守卫写的是 `=== null`,探针当场 TypeError 崩掉;
   *   · 不许假设"最新那条一定排在最前"—— 单独跑 --only history 时最新的一条常常是
   *     别的实验刚交的(本轮就被平抛那条占了),所以一律点开逐条读主段。
   *
   * 本轮 T7b 又加了一条"分母填 1、分子交对"的记录,它的**分子**与那条 100 分的记录一模一样。
   * 所以认记录不能再只比一格:wants 是一串 {label, value},**每一格都对上**才算找到那一条,
   * 否则 100 分那一步会把 T7b 那条当成自己(而它印的是 80 分),整段判错。
   */
  function pickRecord(wants, cap) {
    // 上限按"这台机器上历史已经攒了多少条"给:模拟器上跑过好几轮之后,
    // 纸带那两条会排在平抛/别轮记录后面好几行,6 行不够走到(实测)。
    const limit = cap === undefined ? 14 : cap;
    const tried = new Set();
    p.scrollToTop();
    for (let step = 0; step < 90; step++) {
      const rows = nodes().filter((n) => /^\d{2}:\d{2}$/.test(n.text || ''));
      const row = rows.find((n) => !tried.has(n.text));
      if (row === undefined) {
        p.swipe(EDGE, 1900, EDGE, 1100);
        continue;
      }
      if (tried.size >= limit) {
        return null;
      }
      tried.add(row.text);
      const c = Probe.center(row.bounds);
      p.shell(`uitest uiInput click ${c[0]} ${c[1]}`);
      p.sleep(1800);
      p.scrollToTop();
      const view = texts();
      p.say(`  点开第 ${tried.size} 行(${row.text}):主段分子印「${rowOf('你交的逐差法分子', view)}」`
        + `、分母印「${rowOf('你交的分母倍数', view)}」`);
      // 每一格都对上才算找到那一条(T7b 那条与 100 分那条的**分子**一模一样)
      if (wants.every((w) => rowOf(w[0], view) === w[1])) {
        return view;
      }
    }
    return null;
  }

  p.say('  逐行点开历史列表找那条 100 分(分子=应有值 且 分母=应有倍数 且 判定=算对了)');
  const full = pickRecord([
    ['你交的逐差法分子', info.numShown + ' mm'],
    ['你交的分母倍数', info.denTrue],
    ['逐差法分子判定', '算对了']
  ]);
  if (full === null) {
    p.fail('历史里点开 100 分那条记录',
      `连着点开了几行,主段没有一行同时印成「分子 ${info.numShown} mm / 分母 ${info.denTrue} / 算对了」`);
    return false;
  }
  p.expectTrue('报告页主段印得出「你交的逐差法分子」(ans.* 落盘)',
    full.indexOf('你交的逐差法分子') >= 0, full.slice(0, 8).join(' / '));
  p.expect('照应有值交满那条:他填的分子 = 应有值', rowOf('你交的逐差法分子', full), info.numShown + ' mm');
  p.expect('同一条记录里他填的分母倍数', rowOf('你交的分母倍数', full), info.denTrue);
  p.expect('分子判定印成人话', rowOf('逐差法分子判定', full), '算对了');
  p.shot('answer-history-100');
  /**
   * 一条都没交的那次(60 分)在历史里必须还写"没交"那一格的破折号。
   * 这一条是本轮应用缺陷的现场证据:SessionLedger 把事实里的 NaN 反序列化塌成 0,
   * 于是实验页判词写着「你交的分子是 —」而历史行印着「你交的逐差法分子 0 mm」
   * —— 同一个数两处不是一个说法,而"把没交读成 0"是本项目自己列的最不能有的错法。
   * 修在 SessionLedger.factNumber(与 awardedText 同一条规矩),这里读屏。
   */
  p.say('  再找一条都没交那次(60 分):那一格在历史里不许塌成 0');
  const none = pickRecord([['你交的逐差法分子', '—'], ['逐差法分子判定', '没交']]);
  if (none === null) {
    p.fail('历史里点开一条不填那次', '主段没有一行的分子是破折号(没交)且判定印成没交');
  } else {
    p.expect('一条不填那次:历史里分子印破折号而不是 0', rowOf('你交的逐差法分子', none), '—');
    p.expectTrue('一条不填那次:屏上不出现「你交的逐差法分子 0 mm」',
      none.indexOf('你交的逐差法分子 0 mm') < 0, none.slice(0, 10).join(' / '));
    p.expect('一条不填那次:判定仍印成没交', rowOf('逐差法分子判定', none), '没交');
  }
  p.shot('answer-history-none-dash');
  p.say('  再找 F1 那一条(80 分;分子是他填的 F1、分母判定算对了 —— T7b 那条分母是算错了,不会混进来)');
  const sel = pickRecord([
    ['你交的逐差法分子', info.f1Fact + ' mm'],
    ['逐差法分母判定', '算对了']
  ]);
  if (sel === null) {
    p.fail('历史里点开 F1 那一条记录',
      `连着点开了几行,主段没有一行同时印成「分子 ${info.f1Fact} mm / 分母算对了」`);
    return false;
  }
  p.ok('历史里点开这一行,主段分子正是他填的那个数');
  // 单独跑 --only history 时 --expect 只给历史那侧的串,判词那侧按应用自己的尺子折出来
  const f1ShownHere = info.f1Shown === undefined ? verdictNumber(parseFloat(info.f1Fact)) : info.f1Shown;
  p.say(`  同一个数在两个屏上印成两样:判词「${f1ShownHere} mm」(Judgment.text) vs`
    + ` 历史「${info.f1Fact} mm」(FactLabels.valueText)—— 这条差异是应用的账,记进报告`);
  p.expectTrue('点开那条记录后主段换成了它的数据(不是停在上一条)',
    sel.indexOf('你交的逐差法分子') >= 0
    && rowOf('你交的逐差法分子', sel) === info.f1Fact + ' mm',
    `值=「${rowOf('你交的逐差法分子', sel)}」,期望「${info.f1Fact} mm」`);
  p.expect('那条记录的分子判定印成"算错了"', rowOf('逐差法分子判定', sel), '算错了');
  p.expect('落盘的错法码 = 1(只用首尾那一种)', rowOf('分子错法', sel), '1');
  p.expect('分母那格判对', rowOf('逐差法分母判定', sel), '算对了');
  /**
   * 应有值这一格是 D2(两把尺子)的现场:判词把 562.35 收成「562 mm」(Judgment.text 的
   * |v|>=100 → 整数),历史那一列印「562.35 mm」(FactLabels.valueText 一律两位小数)。
   * 上一版拿判词那侧的串去比历史这一格,报了一条假红。
   * 这里不降格成"有个数就行":读回历史那一格的精确串,按**判词那把尺子**折回来必须逐字等于
   * 判词给的数 —— 两侧仍是精确匹配,只是把它们各自的格式算清楚了。
   */
  const trueOnScreen = rowOf('逐差法分子应有值', sel);
  p.expectTrue('应有分子与他自己那条一起落盘(历史印到分位,折回判词那把尺子必须就是判词那个数)',
    /^\d+(\.\d+)? mm$/.test(trueOnScreen) && verdictNumber(parseFloat(trueOnScreen)) === info.numShown,
    `历史「${trueOnScreen}」/ 判词「${info.numShown} mm」`);
  p.shot('answer-history-f1');
  /**
   * C2 的第三条腿:换过错法之后(本轮 T7b 交的那一条:分子照应有值、分母填 1),
   * **落盘的错法码必须跟着翻** —— 分子那一格不再是错法 1 而是 0,分母那一格才是 1。
   * 判词那句点名是静态文案(两族名字都写死在里面),而错法码是唯一跟着他交的那个数走的字段,
   * 所以"点名真的在点名"这件事只有在这里才证得实;这一条红了就说明码没跟着换。
   */
  p.say('  再找分母填 1 那一条(T7b):错法码必须翻到分母那一格上');
  const denWrong = pickRecord([
    ['你交的逐差法分子', info.numShown + ' mm'],
    ['逐差法分母判定', '算错了']
  ]);
  if (denWrong === null) {
    p.fail('历史里点开分母填 1 那一条(T7b)', '主段没有一行是「分子=应有值 且 分母判定=算错了」');
  } else {
    p.expect('T7b 那条:分子错法翻回 0(这一问他交对了)', rowOf('分子错法', denWrong), '0');
    p.expect('T7b 那条:分母错法是 1(漏乘段数平方那一族)', rowOf('分母错法', denWrong), '1');
    p.expect('T7b 那条:分子判定算对了', rowOf('逐差法分子判定', denWrong), '算对了');
    p.expect('T7b 那条:他填的分母就是 1', rowOf('你交的分母倍数', denWrong), '1');
    p.expectTrue('同一条记录里两格错法码**不是**都写着 1(错法码确实按他交的那一格走,不是恒码)',
      rowOf('分子错法', denWrong) !== rowOf('分母错法', denWrong),
      `分子错法 ${rowOf('分子错法', denWrong)} / 分母错法 ${rowOf('分母错法', denWrong)}`);
  }
  p.shot('answer-history-den');
  p.ensureHome();
  return true;
}

// =====================================================================
// 三、sr-007 平抛:按 key 逐格作废两个方向 —— 远点不作废(P2a)/近点换窗才作废(P2b),
//      以及"早交了 g 的人不被判没交"
// =====================================================================
function pjPart() {
  p.say('== P1. 打开平抛,做满手上动作 ==');
  p.launch();
  p.ensureHome();
  if (!p.tapInList(PJ_TITLE)) {
    return false;
  }
  firstLabel = PJ_G_LABEL;
  secondLabel = PJ_SEG_LABEL;
  p.expectTrue('两格问句都在(①要用的那两格)',
    locateCell(PJ_G_LABEL) !== null && locateCell(PJ_SEG_LABEL) !== null, '定位不到');
  press('挂重垂线定抛出点');
  // 从第 2 格描到第 5 格(起点刻意留开第 1 格:P2b 的"近点换窗口"要有更近的格子可描)。
  // 上一版把四点描满 1..4、第五点落在第 5 格 —— 那正是**不动窗口**的远点情形,
  // 旧断言却管它叫"作废才真的该判没交"(最终评审 C1③:它一直在把一个假扣分当成功验收)。
  press('卡片往里挪一格');
  for (let i = 0; i < 4; i++) {
    press('静止释放钢球');
    press('卡片往外挪一格');
  }
  p.expect('四个点描上了(第 2/3/4/5 格)', readout('描下的点'), '4 个');

  p.say('== P2a. 两格填上数,再描一个**更远**的点:窗口没换,答案必须原样留着(C1 修复后的方向) ==');
  p.expectTrue('g 那格填 9.80', typeInto(PJ_G_LABEL, '9.80'), 'typeInto 失败');
  p.expect('g 那格读回 9.80', boxText(PJ_G_LABEL), '9.80');
  // 段比窗口 = 离槽口最近的那两个点:此刻是第 2、3 格,等间隔下应有值 (3²−2²)/2² = 1.25。
  p.expectTrue('段比那格填 1.25(窗口 2、3 格的应有值)', typeInto(PJ_SEG_LABEL, '1.25'), 'typeInto 失败');
  p.expect('段比那格读回 1.25', boxText(PJ_SEG_LABEL), '1.25');
  // 卡片此刻停在第 6 格,比窗口里那两个点都远 —— 这一笔不改变这一格问的那个数。
  press('静止释放钢球');
  p.sleep(2500);
  p.expect('纸上又多了一个点(mark() 确实走过作废判据)', readout('描下的点'), '5 个');
  p.expect('远点不作废:段比那格的 1.25 原样留着(runner 没收回,页面也就不该清)',
    boxText(PJ_SEG_LABEL), '1.25');
  p.expect('远点不作废:g 那格同样留着 9.80', boxText(PJ_G_LABEL), '9.80');

  p.say('== P2b. 再描一个**更近**的点:窗口真被换成第 1、2 格,这才该作废(按 key 作废的真覆盖) ==');
  pressMany('卡片往里挪一格', 5);   // 第 6 格 → 第 1 格(CARD_MIN=1)
  press('静止释放钢球');
  p.sleep(2500);
  p.expect('纸上又多了一个点(共 6 个,间隔仍然等距)', readout('描下的点'), '6 个');
  const kept = boxText(PJ_G_LABEL);
  const voided = boxText(PJ_SEG_LABEL);
  p.say(`  ① 落笔之后屏上:g 那格「${kept}」/ 段比那格「${voided}」`);
  p.expectTrue('① 只有被作废的那一格空了(按 key 逐格镜像清)', voided === '',
    `段比那格还留着「${voided}」`);
  p.expect('① 另一格(g)的数字原样留着 —— 没有整框清', kept, '9.80');

  p.say('== P3. 早交了 g、后来还在描点的人不该被判没交 ==');
  press('交卷评分');
  const pj = verdictBlob();
  p.say('  判词:' + pj.replace(/\n/g, ' ⏎ ').slice(0, 800));
  p.expectTrue('g 那一格没被读成没交(屏上不出现「你交的 g 是 —」)',
    pj.indexOf('你交的 g 是 —') < 0, pj.slice(0, 500));
  p.expectTrue('被作废的段比那一格老实写着没交',
    pj.indexOf('你交的第二段与第一段之比是 —') >= 0 && pj.indexOf('判定：没交') >= 0,
    pj.slice(0, 500));
  p.expectTrue('g 那一格连"算错了"都没扣(9.80 在带宽内 → 判据不响)',
    pj.indexOf('你交的 g 是') < 0, pj.slice(0, 500));
  p.say('  这一趟得分:' + (pj.match(/得分\s+\d+/) || ['(没读到)'])[0]);
  // 分数是这条的落点:段比那一格作废之后没交 → 只扣那 20 分,g 与四条手上功夫都不该响
  p.expect('作废一格只扣那一格的 20 分(手上四条 + g 全过 → 80)', scoreOf(pj), 80);
  p.expectTrue('扣分的正是段比那一条(不是 g、也不是手上四条)',
    pj.indexOf('竖直方向相邻两段的比没算对或没交') >= 0
    && pj.indexOf('反求的 g 没算对或没交') < 0 && pj.indexOf('忽近忽远') < 0,
    pj.slice(0, 600));
  p.shot('answer-pj-cell-void');
  p.ensureHome();
  return true;
}

/** --only history 单独跑时,要比对的那三个数从 --expect "应有分子,历史印的F1,应有倍数" 传进来 */
function expectFromArgs() {
  const i = process.argv.indexOf('--expect');
  if (i < 0) {
    return null;
  }
  const parts = String(process.argv[i + 1]).split(',');
  if (parts.length !== 3) {
    return null;
  }
  return { numShown: parts[0], f1Fact: parts[1], denTrue: parts[2] };
}

if (only === 'all' || only === 'a') {
  if (!tapeA()) {
    p.fail('纸带 A 段', '打不开这条实验');
  }
}
if (only === 'all' || only === 'b') {
  const info = tapeB();
  if (info !== false) {
    if (only !== 'all') {
      p.say('把下面这行传给 --only history 就能单独跑落盘那一步:--expect '
        + `${info.numShown},${info.f1Fact},${info.denTrue}(第二个是历史那一侧的格式)`);
    }
    if (only === 'all') {
      historyPart(info);
    }
  } else {
    p.fail('纸带 B 段', '没能跑到 100 分这一步');
  }
}
if (only === 'history') {
  const info = expectFromArgs();
  if (info === null) {
    p.fail('--only history', '要用 --expect "应有分子,屏上F1,应有倍数" 给出比对的三个数');
  } else {
    historyPart(info);
  }
}
if (only === 'all' || only === 'pj') {
  if (!pjPart()) {
    p.fail('平抛段', '没能跑完逐格作废这一条');
  }
}
p.back();
const code = p.finish(`截图在 ${outDir}`);
process.exit(code === 0 ? 0 : 1);
