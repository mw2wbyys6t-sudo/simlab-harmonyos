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
import { readFileSync, mkdirSync, rmSync, copyFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const DEFAULT_HDC = 'F:/DevEco/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const BUNDLE = 'com.simlab.edu';
const ABILITY = 'EntryAbility';

/** 设备 token 的形状:IP:端口(模拟器走 TCP)或一段序列号(真机走 USB) */
const IP_PORT = /^(\d{1,3}\.){3}\d{1,3}:\d{2,5}$/;
const SERIAL = /^[A-Za-z0-9][A-Za-z0-9._-]{4,}$/;

export class Probe {
  constructor(opts) {
    this.hdc = process.env.SIMLAB_HDC || DEFAULT_HDC;
    this.tag = opts.tag || 'probe';
    this.outDir = opts.outDir || null;
    this.target = opts.target || process.env.SIMLAB_TARGET || null;
    this.env = { ...process.env, MSYS_NO_PATHCONV: '1' };
    // 自检用的注入点(check-probe.mjs 要看真 argv 判"带没带 -t")。默认 null → 走 execFileSync。
    this.spawn = opts.spawn || null;
    this.lines = [];
    this.failures = 0;
    if (this.outDir) {
      mkdirSync(this.outDir, { recursive: true });
    }
  }

  /**
   * 设备在不在。
   *
   * 多台在线时**必须点名**,不许挑第一台:本轮实测第二台模拟器一起来,不带 -t 的 hdc 调用
   * 全部变成"need connect-key?",探针当场抛异常退出 —— 那既不是应用缺陷也不是判据判得对,
   * 是一台没人看着的机器把另一台挡住了。自动取 lines[0] 更糟:它会把探针安到错的模拟器上,
   * 测出来的一切都是假的。
   *
   * 「在线几台」这个数本轮才真的算得出来。旧版按 `/\d/` 挑行,而 hdc 的告警行自己就带数字
   * (实测 `[Fail][E001005] Device not found or connected`、`[F][2026-10-19 19:43:57] open path...`),
   * 一条失败调用能把"设备数"抬成 2 台 —— 于是"两台在线不许猜"这条闸门数的是告警而不是机器。
   * 现在只认 token 形状:IP:端口 或序列号,`[` 开头的行(告警/错误码/时间戳)一律不算设备。
   */
  assertDevice() {
    const out = this.shellExec(['list', 'targets']);
    const lines = Probe.deviceLines(out);
    if (lines.length === 0) {
      throw new Error(`没有设备在线(hdc list targets = ${out.trim()})。先起模拟器再继续。`);
    }
    if (this.target === null) {
      if (lines.length > 1) {
        throw new Error(`有 ${lines.length} 台设备在线(${lines.join('、')}),探针不许猜是哪台 —— `
          + '装包、dumpLayout、点击全都会落到第一台匹配上的机器上,那测的就不是你看着的这一台。'
          + '设 SIMLAB_TARGET=127.0.0.1:5555(或构造参数 target)再跑。');
      }
      this.target = lines[0];
    } else if (lines.indexOf(this.target) < 0) {
      throw new Error(`点名的设备 ${this.target} 不在线(在线:${lines.join('、')})。`);
    }
    return this.target;
  }

  /**
   * 从 `hdc list targets` 的原始输出里挑出真设备。
   *
   * 单独成一个静态口,是因为"什么算一台设备"这件事必须有能被合成输入验一遍的地方:
   * 拿真机没法当场造出"两台在线",而这条判据一旦数错,后面所有"点名设备"的闸门都白设。
   */
  static deviceLines(out) {
    const hit = [];
    for (const raw of String(out).split(/\r?\n/)) {
      const token = raw.trim().split(/\s+/)[0];
      if (token === '' || token.charAt(0) === '[') {
        continue;
      }
      if (!/\d/.test(token)) {
        continue;
      }
      // 带状态列的输出(`hdc list targets -v` 那一形:序列号 TCP Offline ...)里,Offline 那一台
      // 不算在线:数成一台会把单设备的路径逼成"必须点名",而拿一台休眠的机器去测更是假结果。
      if (/\boffline\b/i.test(raw.slice(raw.indexOf(token) + token.length))) {
        continue;
      }
      if (IP_PORT.test(token) || SERIAL.test(token)) {
        hit.push(token);
      }
    }
    return hit;
  }

  shellExec(args, opts) {
    // 除了 list targets,每一条 hdc 都得带着 -t:没有它,两台在线时命令会被拒或落到错的机器上
    const full = (this.target !== null && args[0] !== 'list' && args[0] !== '-t')
      ? ['-t', this.target].concat(args) : args;
    const o = opts || {};
    const cwd = o.cwd === undefined ? process.cwd() : o.cwd;
    // Windows 上 execFileSync 起不了 .cmd 假二进制(EINVAL),所以自检用 spawn 注入点看真 argv;
    // 生产路径默认仍是 execFileSync,一行没变。
    if (this.spawn !== null) {
      return this.spawn(this.hdc, full, { env: this.env, encoding: 'utf8', cwd });
    }
    return execFileSync(this.hdc, full, { env: this.env, encoding: 'utf8', cwd });
  }

  shell(cmd) {
    return this.shellExec(['shell', cmd]);
  }

  sleep(ms) {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
  }

  /**
   * 装包。必须看到 install bundle successfully 才算装上(否则测的是上一个构建)。
   *
   * 本轮 I1:旧版这里是全文件**唯一一条绕过 shellExec 的 hdc 调用** —— 它自己 execFileSync,
   * 于是 `install` 不带 -t。两台在线时它能把包装到另一台模拟器上而照样回
   * "install bundle successfully",那测的就不是这个构建,正是 :66 那条注释自己要避免的事
   * (9 条带 --install 的脚本都受影响)。现在走同一条 target 逻辑,并且没点名就拒装。
   */
  install(hapPath) {
    if (this.target === null) {
      throw new Error('装包之前必须先 assertDevice():不带 -t 的 `hdc install` 在两台在线时可能装到另一台机器,'
        + '而它的回显一模一样。设 SIMLAB_TARGET 或先调 assertDevice()。');
    }
    const dir = hapPath.slice(0, hapPath.lastIndexOf('/'));
    const file = hapPath.slice(hapPath.lastIndexOf('/') + 1);
    const out = this.shellExec(['install', '-r', file], { cwd: dir });
    if (!out.includes('install bundle successfully')) {
      throw new Error(`安装没成功,后面测的就不是这个构建:\n${out}`);
    }
    return out.trim();
  }

  /**
   * 拉起应用。
   *
   * 两条实测脾气都写在这里:
   *   · 模拟器的屏幕会自己睡。锁屏状态下 `aa start` 报 10106102 而旧代码不看返回值,
   *     于是"dumpLayout 里没有这个节点"其实是在测桌面 —— 先唤醒,再要求真的拉起来了。
   *   · wakeup 之后键控锁屏还要再解一会儿(实测固定 sleep 800 ms 就发 aa start,
   *     报的正是 10106102,而那一刻屏幕已经点亮、桌面也截得到)。所以这里按错误码重试,
   *     而不是把 sleep 猜得更长:只有 aa start 真说 successfully 才算数。
   */
  launch() {
    this.shell('power-shell wakeup');
    this.sleep(800);
    this.shell(`aa force-stop ${BUNDLE}`);
    this.sleep(1000);
    for (let attempt = 0; attempt < 5; attempt++) {
      const out = this.shell(`aa start -a ${ABILITY} -b ${BUNDLE}`);
      if (out.includes('successfully')) {
        this.sleep(3500);
        return;
      }
      if (out.includes('10106102')) {
        // 还在锁屏:再唤醒一次,等它把锁解掉
        this.shell('power-shell wakeup');
        this.sleep(2500);
        continue;
      }
      throw new Error(`应用没被拉起来,后面测的都是桌面:\n${out.trim()}`);
    }
    throw new Error('应用没被拉起来:连着五次 aa start 都停在锁屏(10106102)。'
      + '先手动点亮/解锁模拟器再跑,别让它拿桌面当被测对象。');
  }

  dumpNodes() {
    // 路径里带 pid:两个探针同时跑(哪怕 tag 相同)也不会互相删对方那份快照。
    // 先删掉设备上那份:dumpLayout 失败时它留的是**上一次的布局**,
    // 直接读回来会把过期快照当现状 —— 那是最坏的一种假绿
    const remote = `/data/local/tmp/${this.tag}.${process.pid}.json`;
    const local = join(tmpdir(), `simlab-${this.tag}.${process.pid}-dump.json`);
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

  static rect(bounds) {
    const m = bounds.match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);
    return [+m[1], +m[2], +m[3], +m[4]];
  }

  /**
   * 键盘弹起时屏幕下半部"另一窗口、尺寸像一颗键"的节点上沿;认不出来给 -1。
   *
   * 实测:uitest 的 dumpLayout 默认合窗口,软键盘是单独一个窗口(47 个节点,键帽是 Image),
   * 但那个窗口的 root 顶到 y=137(整屏容器),所以只能按键帽尺寸筛,不能直接取窗口上沿。
   *
   * 这个口只回答"上沿在哪",答不了"键盘到底在不在" —— 后者是 imeState 的三态。
   */
  imeTop(nodes) {
    const s = this.imeState(nodes);
    return s.top;
  }

  /**
   * 应用自己那个窗口的 hostWindowId。
   *
   * 旧版取"树里第一个 root",而 root 的先后顺序会随键盘支起/收起变 —— 本轮实测就是这么咬的:
   * 打完字之后第一遍判成 unknown,连带 typeInto 失败。退一步取"节点最多的 root"也不够稳:
   * 实测那一屏的分布是 `185:48 280:47 27:37`,应用与输入法只差一颗节点。
   * 所以按**谁持有输入框**认:填空框一定在应用窗口里,键盘窗口里不会有 TextInput。
   * 两条都不成立时返回 null,让调用方判 unknown —— 猜错窗口比承认看不见坏得多。
   */
  appWindow(nodes) {
    for (const n of nodes) {
      if (n.type === 'TextInput') {
        const id = n.hostWindowId === undefined || n.hostWindowId === '' ? null : String(n.hostWindowId);
        if (id !== null) {
          return id;
        }
      }
    }
    const counts = new Map();
    for (const n of nodes) {
      if (n.hostWindowId === undefined || n.hostWindowId === '') {
        continue;
      }
      const k = String(n.hostWindowId);
      counts.set(k, (counts.get(k) || 0) + 1);
    }
    let best = null;
    let bestN = 0;
    for (const n of nodes) {
      if (n.type !== 'root' || n.hostWindowId === undefined || n.hostWindowId === '') {
        continue;
      }
      const c = counts.get(String(n.hostWindowId)) || 0;
      if (c > bestN) {
        best = String(n.hostWindowId);
        bestN = c;
      }
    }
    return best;
  }

  /**
   * 键盘在不在,三态:`up` / `down` / `unknown`。
   *
   * 旧版只有一个 `imeTop() < 0`,于是"键盘收好了"和"键盘在不在我看不出来"是同一种说法。
   * 本轮实测这台机器的树里常驻**三个**窗口(空 hostWindowId 一个、应用 root=185、
   * 状态栏 27 的 37 个节点全在 y 0..136),再叠上键盘时多出 228(47 个节点)与 29(12 个)
   * —— 所以"树里有没有第二个窗口"根本不能当键盘信号(状态栏自己就是一个)。
   * 认键盘只看一件事:**有没有别的窗口的节点压在屏幕下半部**。
   *   · 一个都没有                     → `down`(键盘确实没支起来)
   *   · 压在下半部、键帽数得出 ≥3 颗   → `up`,top 就是键帽上沿
   *   · 压在下半部、键帽数不出来       → `unknown` —— 这一档旧版报的是"已收起",那是假绿:
   *     依赖"快照前键盘已收起"的断言(②的回显结构闸门、⑤ 的量窗)会被键盘位移污染而没人喊。
   */
  imeState(nodes) {
    const app = this.appWindow(nodes);
    if (app === null) {
      return { state: 'unknown', top: -1, why: '树里没有带 hostWindowId 的 root,认不出哪个窗口是应用' };
    }
    const overlay = [];
    for (const n of nodes) {
      if (n.type === 'root' || n.type === 'WindowScene') {
        continue;
      }
      if (n.hostWindowId === undefined || n.hostWindowId === '' || String(n.hostWindowId) === app) {
        continue;
      }
      const r = Probe.rect(n.bounds);
      // 只算**压在屏幕下半部**的外来节点:状态栏/导航条那类常驻窗口(实测 hostWindowId 27,
      // 37 个节点全在 y 0..136)也在别的窗口里,拿"有没有第二个窗口"当键盘信号会永远判不出 down
      if (r[1] > 600) {
        overlay.push(r);
      }
    }
    if (overlay.length === 0) {
      return { state: 'down', top: -1, why: '屏幕下半部没有外来窗口的节点(状态栏那类常驻在上沿)' };
    }
    const keys = [];
    for (const r of overlay) {
      if (r[3] - r[1] <= 600 && r[2] - r[0] <= 700) {
        keys.push(r[1]);
      }
    }
    if (keys.length < 3) {
      return { state: 'unknown', top: -1, why: '屏幕下半部有 ' + overlay.length + ' 个外来节点,却数不出 ≥3 颗键帽' };
    }
    return { state: 'up', top: Math.min(...keys), why: '键帽 ' + keys.length + ' 颗' };
  }

  /** 窗口分布(失败详情里要说清"树里有几个窗口",否则 unknown 没法三分) */
  winHist(nodes) {
    const at = new Map();
    for (const n of nodes) {
      const k = (n.hostWindowId === undefined || n.hostWindowId === '') ? '(空)' : String(n.hostWindowId);
      at.set(k, (at.get(k) || 0) + 1);
    }
    return [...at].map(([k, v]) => k + ':' + v).join(' ');
  }

  /**
   * 收起软键盘:keyEvent 2(Escape)。
   *
   * 实测点问句、点画布都收不掉(那个键盘窗口原样留着),Escape 才干净;
   * 而 keyEvent Back 在键盘已经收起的那一次会把实验页整个弹出栈(实测页面没了),所以不用它。
   *
   * 返回值本轮从布尔改成三态字串:`down` 才算收好了,`unknown` 表示**看不见键盘所以没法确认**。
   * 调用方拿到不是 `down` 的结果必须红,不许当"已收起"继续往下测(I7)。
   */
  hideKeyboard() {
    for (let round = 0; round < 3; round++) {
      const s = this.imeState(this.dumpNodes());
      if (s.state !== 'up') {
        return s.state === 'down' ? 'down' : 'unknown';
      }
      this.shell('uitest uiInput keyEvent 2');
      this.sleep(900);
    }
    const left = this.imeState(this.dumpNodes());
    return left.state === 'down' ? 'down' : 'unknown';
  }

  /**
   * 填空那一格本身没有 text,只能靠它上面那句问句定位:问句下面最近的 TextInput。
   * 先看当前这一屏,再往下找,最后才回顶往下找 —— 每次都先 scrollToTop 的话,
   * 一轮打字探针要白甩十几下(实测跑到超时不返回)。
   */
  locateField(prefix, edgeX, swipeFrom, swipeTo) {
    const x = edgeX === undefined ? 60 : edgeX;
    const from = swipeFrom === undefined ? 1900 : swipeFrom;
    const to = swipeTo === undefined ? 900 : swipeTo;
    const pick = (list) => {
      const label = list.find((n) => (n.text || '').indexOf(prefix) === 0);
      if (label === undefined) {
        return null;
      }
      const lb = Probe.rect(label.bounds);
      let best = null;
      let bestD = 1e9;
      for (const n of list) {
        if (n.type !== 'TextInput') {
          continue;
        }
        const r = Probe.rect(n.bounds);
        const d = r[1] - lb[3];
        if (r[1] >= lb[1] && d >= -20 && d < bestD) {
          bestD = d;
          best = n;
        }
      }
      return best;
    };
    let hit = pick(this.dumpNodes());
    if (hit !== null) {
      return hit;
    }
    for (let i = 0; i < 8; i++) {
      this.swipe(x, from, x, to);
      hit = pick(this.dumpNodes());
      if (hit !== null) {
        return hit;
      }
    }
    this.scrollToTop();
    for (let i = 0; i < 18; i++) {
      hit = pick(this.dumpNodes());
      if (hit !== null) {
        return hit;
      }
      this.swipe(x, from, x, to);
    }
    this.fail(`定位填空「${prefix}」`, '滚到底也没把问句与输入框凑进同一屏');
    return null;
  }

  /** 框里现在是什么字(屏上读,不是内存里读) */
  fieldText(prefix, edgeX) {
    const f = this.locateField(prefix, edgeX);
    return f === null ? null : (f.text || '');
  }

  /**
   * 清框:uitest 的 inputText 只会往后追加,不清就是把两次内容叠进同一条断言
   * (实测:同一格连打两次 9.80 → 屏上 9.809.80)。退格用 keyEvent 2055,先点那一格交焦点。
   *
   * 收键盘那一步现在要结果:I7 —— 认不出键盘时不许当"已收起"接着往下测,
   * 否则调用方拿到的快照可能被键盘位移污染,而 ②/⑤ 那两条闸门会静悄悄地在比两屏不同的东西。
   */
  clearField(prefix, edgeX) {
    for (let round = 0; round < 6; round++) {
      const f = this.locateField(prefix, edgeX);
      if (f === null) {
        return false;
      }
      const len = (f.text || '').length;
      if (len === 0) {
        const st = this.hideKeyboard();
        if (st !== 'down') {
          this.fail(`收键盘(清完「${prefix}」之后)`, `键盘状态认不出来(${st}),不许当已收起继续测`);
          return false;
        }
        return true;
      }
      const c = Probe.center(f.bounds);
      this.shell(`uitest uiInput click ${c[0]} ${c[1]}`);
      this.sleep(900);
      for (let i = 0; i < len; i++) {
        this.shell('uitest uiInput keyEvent 2055');
      }
      this.sleep(600);
    }
    this.fail(`清掉填空「${prefix}」`, '连着退格之后框里还有字');
    return false;
  }

  /**
   * 往一格填空里打字:先清框,再定位那一格(坐标必须现取),然后用 inputText 打进去。
   * edgeX 一路透传给 locateField —— 三条探针都把自己的滚动留白 x 传进来,
   * 少了这一笔就是「调用点写了 EDGE、实现里静默用默认 60」(tap 的注释里记过同一形状的坑)。
   * 打完必须确认键盘真的收掉了(I7):认不出状态就返回 false,让调用方那条断言红。
   */
  typeIntoField(prefix, text, edgeX) {
    if (!this.clearField(prefix, edgeX)) {
      return false;
    }
    const f = this.locateField(prefix, edgeX);
    if (f === null) {
      return false;
    }
    const c = Probe.center(f.bounds);
    this.shell(`uitest uiInput inputText ${c[0]} ${c[1]} ${text}`);
    this.sleep(1200);
    const st = this.hideKeyboard();
    if (st !== 'down') {
      this.fail(`收键盘(往「${prefix}」打完字之后)`, `键盘状态认不出来(${st}),这一格的快照会被键盘位移污染`);
      return false;
    }
    return true;
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

  /** 同一次快照里的带字文本表(读行的前提:表必须来自一次 dumpLayout,不许每读一格重取一次) */
  textList(nodes) {
    return (nodes === undefined ? this.dumpNodes() : nodes)
      .map((a) => a.text || '').filter((t) => t.length > 0);
  }

  /**
   * 一次快照读一行:label 下面紧挨着的那条文本就是它的值。
   *
   * 三条探针原来各写了一份读法,而 check-projectile 那份每判一轮要 dump **两次** ——
   * `rowOf(label).length > 0` 与 `return rowOf(label)` 取自不同快照,中间那一屏可能已经滚了
   * (读到空 → 再滚一下 → 拿回来的可能是另一格)。check-answer 的 readout2 本轮之前已经修掉
   * 这一点,但修好的那份没共享出去,这就是共用件漂移。现在把它下沉到这里,三条探针同一份。
   * 接的是**文本表**而不是自己去 dump:调用方必须把同一份表传给条件与详情串,
   * 否则 `p.expectTrue(..., readout(x) === y, \`实得「${readout(x)}」\`)` 又会变成两次快照。
   */
  static rowOf(label, list) {
    const at = list.indexOf(label);
    return at >= 0 && at + 1 < list.length ? list[at + 1] : '';
  }

  /**
   * 滚到某一格读数再读:九格读数一屏放不下。
   *
   * 一次尝试 = 一次快照(值与"值非空"这个条件取自同一份表)。edgeX 一路透传 ——
   * 每条探针的滚动留白 x 不一样,少了这一笔就是「调用点写了 EDGE、实现里静默用默认 60」
   * (tap 的注释里记过同一形状的坑,probe.mjs:299-302 自己立的规矩)。
   */
  readRow(label, opts) {
    const o = opts || {};
    const x = o.edgeX === undefined ? 60 : o.edgeX;
    const tries = o.tries === undefined ? 18 : o.tries;
    const settle = o.settle === undefined ? 600 : o.settle;
    const from = o.swipeFrom === undefined ? 1900 : o.swipeFrom;
    const to = o.swipeTo === undefined ? 900 : o.swipeTo;
    const swipeWait = o.swipeWait === undefined ? 400 : o.swipeWait;
    this.scrollToTop();
    for (let i = 0; i < tries; i++) {
      const list = this.textList();
      const value = Probe.rowOf(label, list);
      if (list.indexOf(label) >= 0 && value.length > 0) {
        this.sleep(settle);
        return { value: value, screen: list };
      }
      this.swipe(x, from, x, to);
      this.sleep(swipeWait);
    }
    this.fail(`读到「${label}」`, '滚到底也没出现这一格读数');
    return { value: '', screen: [] };
  }

  /** 只要值本身(readRow 的薄口);详情串要复用同一个值时请直接用 readRow 的返回 */
  readout(label, opts) {
    return this.readRow(label, opts).value;
  }

  /**
   * 交卷之后的判词收成一整块文本。
   *
   * 「得分 60 / 100」与每一条扣分句是**各一个节点**:ExperimentPage.ets:278-285 把 summaryLine
   * 和每条 `'· 标题（扣 N 分）证据'` 分行 push 出去,而判词常常比一屏长。所以只取一次
   * dumpLayout 就只能看见得分那一行 —— 「两条 判定：没交」「忽近忽远被点名」这类跨节点的账
   * 永远对不上(本轮把 check-tape / check-projectile 从单个 60 恢复成两个实测数之后,
   * 它们原来那版"找到得分那一行就返回"的读法必须先换成这一份,否则判的是探针自己没滚到)。
   *
   * 三条探针共用这里一份,免得收词表在三个文件里各漂一版。
   */
  verdictBlob(edgeX) {
    const x = edgeX === undefined ? 60 : edgeX;
    const wanted = (t) => t.indexOf('得分') === 0 || t.indexOf('你交的') >= 0
      || t.indexOf('（扣 ') >= 0 || t.indexOf('没有扣分项') >= 0 || t.indexOf('本次记录') >= 0;
    this.scrollToTop();
    const seen = new Set();
    for (let i = 0; i < 16; i++) {
      for (const n of this.dumpNodes()) {
        const t = n.text || '';
        if (wanted(t)) {
          seen.add(t);
        }
      }
      const blob = [...seen].join('\n');
      // 得分行 + 至少一句判词才收工:只有得分那一行 = 扣分句还在视口外
      if (blob.indexOf('得分') === 0 && (blob.indexOf('你交的') >= 0
        || blob.indexOf('（扣 ') >= 0 || blob.indexOf('没有扣分项') >= 0)) {
        return blob;
      }
      this.swipe(x, 1900, x, 1000);
      this.sleep(500);
    }
    return [...seen].join('\n');
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

  /**
   * 截一张屏。
   *
   * 两条路都留着,因为本轮实测到 `snapshot_display` 会**报成功却不落盘**
   * (它先打 "process: display 0, ... width 1256, height 2760",随后补一句
   * "error: snapshot display 0, write to ... failed",而旧代码两句都不看,直接把一个
   * 不存在的本地文件交给 copyFileSync —— 探针当场崩,后面全没测)。
   * 首选 `uitest screenCap -p *.png`,同一次调用里它落的盘;拿不到就退到 snapshot_display,
   * 再拿不到就如实说"这一张没截成",而不是让调用方以为有图。
   */
  shot(name) {
    if (this.outDir === null) {
      return '';
    }
    const attempts = [
      ['uitest screenCap -p', `/data/local/tmp/${this.tag}-${name}.png`, `${this.tag}-${name}.png`, '.png'],
      ['snapshot_display -f', `/data/local/tmp/${this.tag}-${name}.jpeg`, `${this.tag}-${name}.jpeg`, '.jpeg']
    ];
    for (const [cmd, remote, local, suffix] of attempts) {
      for (let attempt = 0; attempt < 2; attempt++) {
        this.shell(`rm -f ${remote}`);
        this.shell(`${cmd} ${remote}`);
        this.sleep(700);
        if (!this.remoteFileExists(remote)) {
          continue;
        }
        this.shellExec(['file', 'recv', remote, local]);
        if (!existsSync(local)) {
          this.say(`  (截图 recv 没落地:${local})`);
          break;
        }
        copyFileSync(local, `${this.outDir}/${name}${suffix}`);
        rmSync(local, { force: true });
        this.shell(`rm -f ${remote}`);
        return `${this.outDir}/${name}${suffix}`;
      }
    }
    this.say(`  这一张没截成(${name}):screenCap 与 snapshot_display 都没在设备上留下文件`);
    return '';
  }

  /** 设备上这个文件真在吗:ls 的输出里有它自己的名字才算 */
  remoteFileExists(path) {
    const out = this.shell(`ls -l ${path}`);
    const base = path.slice(path.lastIndexOf('/') + 1);
    return out.indexOf(base) >= 0 && out.indexOf('No such file') < 0;
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
