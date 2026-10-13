/**
 * 设备侧探针的共用件(hdc + uitest)。
 *
 * 为什么要有这个文件:UI 层的结论只能从屏幕上取,而每次会话现写一份脚本就会漂 ——
 * 上一轮"点了没反应"其实是按子串匹配点到了说明文字,"改了令牌 bounds 没变"其实是
 * 根本没装进去。这些坑已经变成这里的默认行为:按精确文本定位、每次点击前重新 dump、
 * install 必须打印成功才算装上。
 *
 * 用法(给脚本 import):
 *   import { Probe } from './probe.mjs';
 *   const p = new Probe({ tag: 'appearance' });
 *   p.launch(); p.tap('深浅色'); const c = p.selectedColor(['浅色','深色','跟随系统']);
 *
 * 设备路径可用环境变量覆盖:SIMLAB_HDC=<hdc 可执行文件路径>
 */
import { execFileSync } from 'node:child_process';
import { readFileSync, mkdirSync, rmSync, copyFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const DEFAULT_HDC = 'F:/DevEco/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const BUNDLE = 'com.simlab.edu';
const ABILITY = 'EntryAbility';

export class Probe {
  constructor(opts) {
    this.hdc = process.env.SIMLAB_HDC || DEFAULT_HDC;
    this.tag = opts.tag || 'probe';
    this.outDir = opts.outDir || null;
    this.env = { ...process.env, MSYS_NO_PATHCONV: '1' };
    this.lines = [];
    this.failures = 0;
    if (this.outDir) {
      mkdirSync(this.outDir, { recursive: true });
    }
  }

  /** 设备在不在。不在就直接说清楚,别让后面的"找不到节点"冒充 UI 缺陷 */
  assertDevice() {
    const out = this.shellExec(['list', 'targets']);
    if (!/\d/.test(out)) {
      throw new Error(`没有设备在线(hdc list targets = ${out.trim()})。先起模拟器再继续。`);
    }
    return out.trim().split('\n')[0];
  }

  shellExec(args) {
    return execFileSync(this.hdc, args, { env: this.env, encoding: 'utf8' });
  }

  shell(cmd) {
    return this.shellExec(['shell', cmd]);
  }

  sleep(ms) {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
  }

  /** 装包。必须看到 install bundle successfully 才算装上(否则测的是上一个构建) */
  install(hapPath) {
    const dir = hapPath.slice(0, hapPath.lastIndexOf('/'));
    const file = hapPath.slice(hapPath.lastIndexOf('/') + 1);
    const out = execFileSync(this.hdc, ['install', '-r', file], { env: this.env, encoding: 'utf8', cwd: dir });
    if (!out.includes('install bundle successfully')) {
      throw new Error(`安装没成功,后面测的就不是这个构建:\n${out}`);
    }
    return out.trim();
  }

  launch() {
    // 模拟器的屏幕会自己睡。锁屏状态下 `aa start` 报 10106102 而旧代码不看返回值,
    // 于是"dumpLayout 里没有这个节点"其实是在测桌面 —— 先唤醒,再要求真的拉起来了
    this.shell('power-shell wakeup');
    this.sleep(800);
    this.shell(`aa force-stop ${BUNDLE}`);
    this.sleep(1000);
    const out = this.shell(`aa start -a ${ABILITY} -b ${BUNDLE}`);
    if (!out.includes('successfully')) {
      throw new Error(`应用没被拉起来,后面测的都是桌面:\n${out.trim()}`);
    }
    this.sleep(3500);
  }

  dumpNodes() {
    const remote = `/data/local/tmp/${this.tag}.json`;
    const local = join(tmpdir(), `simlab-${this.tag}-dump.json`);
    // 先删掉设备上那份:dumpLayout 失败时它留的是**上一次的布局**,
    // 直接读回来会把过期快照当现状 —— 那是最坏的一种假绿
    this.shell(`rm -f ${remote}`);
    const dumped = this.shell(`uitest dumpLayout -p ${remote}`);
    if (!dumped.includes('DumpLayout saved')) {
      throw new Error(`dumpLayout 没成功,拿不到当前布局:\n${dumped.trim()}`);
    }
    try {
      this.shellExec(['file', 'recv', remote, local]);
      const tree = JSON.parse(readFileSync(local, 'utf8'));
      const list = [];
      (function w(n) {
        if (!n) return;
        if (n.attributes) list.push(n.attributes);
        (n.children || []).forEach(w);
      })(tree);
      return list;
    } finally {
      rmSync(local, { force: true });
    }
  }

  /** 视口右边界(取根节点宽度),用于"有没有被裁掉"的判定 */
  screenWidth() {
    const nodes = this.dumpNodes();
    let max = 0;
    for (const n of nodes) {
      const m = (n.bounds || '').match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);
      if (m && +m[3] > max) max = +m[3];
    }
    return max;
  }

  static center(bounds) {
    const m = bounds.match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);
    return [Math.round((+m[1] + +m[3]) / 2), Math.round((+m[2] + +m[4]) / 2)];
  }

  /** 按精确文本点击。默认精确匹配:子串匹配曾点到引用按钮名的说明文字 */
  tap(text, opts) {
    // 允许直接传一个数字当等待时长,否则 `tap(x, 2400)` 会静默用默认值 —— 调用点已经这么写了
    const o = typeof opts === 'number' ? { wait: opts } : (opts || {});
    const contains = !!o.contains;
    const wait = o.wait || 1600;
    const find = () => this.dumpNodes().find((a) => {
      const t = a.text || '';
      return contains ? t.includes(text) : t === text;
    });
    let hit = find();
    if (hit === undefined) {
      this.fail(`点击「${text}」`, 'dumpLayout 里没有这个节点');
      return false;
    }
    // 甩动动画没停就取坐标,点击会落到滑过来取代它位置的那格上(实测点到了参数滑杆,
    // 把电阻箱拖到 51 Ω —— 看着像"按钮没反应",其实是拖错了控件)。连着两次位置一致才按。
    for (let i = 0; i < 4; i++) {
      this.sleep(500);
      const again = find();
      if (again !== undefined && again.bounds === hit.bounds) {
        break;
      }
      hit = again === undefined ? hit : again;
    }
    const [x, y] = Probe.center(hit.bounds);
    this.shell(`uitest uiInput click ${x} ${y}`);
    this.sleep(wait);
    return true;
  }

  /** 按包含关系点开卡片(标题是长句时用) */
  tapContains(text, wait) {
    return this.tap(text, { contains: true, wait: wait });
  }

  /**
   * 先滚到顶,再一路往下找那张卡。
   * dumpLayout 会剔掉视口外的节点,所以"列表里有"和"现在点得到"是两件事 ——
   * 第一版没做这一步,第 9 张卡被报成了"不存在"。
   */
  tapInList(text, tries) {
    this.scrollToTop();
    const limit = tries || 5;
    for (let i = 0; i < limit; i++) {
      const hit = this.dumpNodes().find((a) => (a.text || '').includes(text));
      if (hit !== undefined) {
        const [x, y] = Probe.center(hit.bounds);
        this.shell(`uitest uiInput click ${x} ${y}`);
        this.sleep(2600);
        return true;
      }
      this.swipe(628, 2000, 628, 800);
    }
    this.fail(`点开「${text}」`, `滚动 ${limit} 次仍没出现在视口里`);
    return false;
  }

  swipe(x1, y1, x2, y2) {
    this.shell(`uitest uiInput swipe ${x1} ${y1} ${x2} ${y2} 600`);
    this.sleep(900);
  }

  /**
   * 回到滚动区顶部:滚动位置会留着,不滚回去就"找不到"第一张卡(实测踩过)。
   *
   * 起讫点都取在屏幕下半部:实验页上半是固定的画布与控制行,手势从 y=700 起
   * 落在画布上,于是"回顶"对实验页完全没作用(实测滚了四次位置纹丝不动)。
   * x 走左侧留白 60:参数滑杆占满 x 98..1158,手势起点落在轨道上时 Slider 会抢下
   * 这次拖拽并把值跳到起点那个 x(实测:滚一下,电阻箱从 20 Ω 变成 51 Ω)。
   */
  scrollToTop() {
    /*
     * 甩到"再甩一下位置不动了"为止,不数固定次数。
     * 写死 4 次时,交卷后判词把页面撑高两屏 → 回不到顶,目标在视口上方而后面只会往下找
     * (实测找不到那两个按钮);改成 6 次之后,短页面每次调用都白滚三下 —— 一轮回归跑到超时不返回。
     * 到顶的信号用整屏文本+位置指纹:标题栏与「开始/重置」那一行是固定的,
     * 所以不能只盯第一个节点,得看整页有没有动。
     */
    let mark = this.screenMark();
    for (let i = 0; i < 12; i++) {
      this.swipe(60, 1600, 60, 2400);
      const next = this.screenMark();
      if (next.length > 0 && next === mark) {
        break;
      }
      mark = next;
    }
    // 最后一甩的惯性还在跑就取坐标,后面那一下点击会落到取代它位置的那一行上
    // (实测:想按「电阻箱减一档」,结果按到了它上面那一挡,值从 20 变成 30)
    this.sleep(1200);
  }

  /**
   * 整页的"位置指纹":有文本的节点各自 bounds 拼起来。
   *
   * 只取位置、不取文本 —— 实验页上「t = 24.00 s」这类每格都在跳的文本一旦进了指纹,
   * 运行中的页面就永远判不到顶(实测:每次回顶都甩满 12 下,一轮 check-ohm 跑到 23 分钟不回)。
   */
  screenMark() {
    const parts = [];
    for (const n of this.dumpNodes()) {
      const t = n.text || '';
      if (t.length === 0) continue;
      parts.push(n.bounds || '');
      if (parts.length >= 24) break;
    }
    return parts.join('|');
  }

  back(wait) {
    this.shell('uitest uiInput keyEvent Back');
    this.sleep(wait || 1300);
  }

  /** 回首页:运行中的页面可能吃掉一次 Back(软键盘同理),所以按到看见顶栏为止 */
  ensureHome(menuLabel) {
    // 认「深浅色」而不是「课程地图」:后者也是课程地图页的标题,拿它当家信号会误判
    const want = menuLabel || '深浅色';
    for (let i = 0; i < 5; i++) {
      if (this.dumpNodes().some((a) => (a.text || '') === want)) return true;
      this.back();
    }
    return false;
  }

  /** 当前被选中那颗 chip 的解析后底色 = 那一档的强调色(深浅色的直接证据) */
  selectedColor(labels) {
    for (const a of this.dumpNodes()) {
      if (labels.includes(a.text || '') && a.selected === 'true') return a.backgroundColor;
    }
    return '';
  }

  shot(name) {
    if (this.outDir === null) return '';
    const remote = `/data/local/tmp/${this.tag}-${name}.jpeg`;
    this.shell(`snapshot_display -f ${remote}`);
    this.sleep(700);
    const local = `${this.tag}-${name}.jpeg`;
    this.shellExec(['file', 'recv', remote, local]);
    copyFileSync(local, `${this.outDir}/${name}.jpeg`);
    rmSync(local, { force: true });
    this.shell(`rm -f ${remote}`);
    return `${this.outDir}/${name}.jpeg`;
  }

  say(s) {
    this.lines.push(s);
    console.log(s);
  }

  ok(label) {
    this.lines.push(`  ok  ${label}`);
    console.log(`  ok  ${label}`);
  }

  fail(label, detail) {
    this.failures++;
    this.lines.push(`  FAIL ${label} —— ${detail}`);
    console.log(`  FAIL ${label} —— ${detail}`);
  }

  expect(label, actual, expected) {
    if (actual === expected) this.ok(`${label}(= ${expected})`);
    else this.fail(label, `实得 ${actual === '' ? '(空)' : actual},期望 ${expected}`);
  }

  expectTrue(label, cond, detail) {
    if (cond) this.ok(label);
    else this.fail(label, detail);
  }

  finish(notes) {
    if (notes) this.say(notes);
    console.log(this.failures === 0 ? '\n全部通过' : `\n${this.failures} 项失败`);
    return this.failures;
  }
}
