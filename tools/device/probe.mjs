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
    this.shell(`aa force-stop ${BUNDLE}`);
    this.sleep(1000);
    this.shell(`aa start -a ${ABILITY} -b ${BUNDLE}`);
    this.sleep(3500);
  }

  dumpNodes() {
    const remote = `/data/local/tmp/${this.tag}.json`;
    this.shell(`uitest dumpLayout -p ${remote}`);
    // recv 的目标按 hdc 进程 cwd 解析,所以给相对文件名,再按同一个 cwd 读回来
    this.shellExec(['file', 'recv', remote, `${this.tag}-dump.json`]);
    const tree = JSON.parse(readFileSync(`${this.tag}-dump.json`, 'utf8'));
    const list = [];
    (function w(n) {
      if (!n) return;
      if (n.attributes) list.push(n.attributes);
      (n.children || []).forEach(w);
    })(tree);
    return list;
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
    const contains = !!(opts && opts.contains);
    const wait = (opts && opts.wait) || 1600;
    const hit = this.dumpNodes().find((a) => {
      const t = a.text || '';
      return contains ? t.includes(text) : t === text;
    });
    if (hit === undefined) {
      this.fail(`点击「${text}」`, 'dumpLayout 里没有这个节点');
      return false;
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

  /** 回到列表顶部:滚动位置会留着,不滚回去就"找不到"第一张卡(实测踩过) */
  scrollToTop() {
    this.swipe(628, 700, 628, 2100);
    this.swipe(628, 700, 628, 2100);
  }

  back(wait) {
    this.shell('uitest uiInput keyEvent Back');
    this.sleep(wait || 1300);
  }

  /** 回首页:运行中的页面可能吃掉一次 Back(软键盘同理),所以按到看见顶栏为止 */
  ensureHome(menuLabel) {
    const want = menuLabel || '课程地图';
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
