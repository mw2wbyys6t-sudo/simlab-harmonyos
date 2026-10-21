/**
 * 横竖屏那组断言的变异证明。
 *
 * 断言写在 check.mjs 里,但"断言存在"不等于"断言会红"。这个脚本把 Layout.ets
 * 在**临时副本**上改坏(不动工作区),再跑一遍闸门,看对应的那条断言是不是真的抓住了。
 *
 * 七个变异对应七组断言:
 *   1. 矮屏上下边距不收窄 → 边距那组
 *   2. isCompact 恒假 → 紧凑判定 + 档位
 *   3. 紧凑阈值 500 改 700 → 阈值那条
 *   4. isStacked 忽略紧凑档 → 单栏/两栏那条
 *   5. classify 不看高度 → 档位那条(横屏手机掉回平板)
 *   6. 阅读列不收窄 → 阅读列上限那组
 *   7. 矮屏画布抬到 210 → 画布下限那组
 *
 * 用法: node tools/physics-check/mut-landscape.mjs
 */
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const scratch = mkdtempSync(join(tmpdir(), 'simlab-mut-'));

cpSync(join(root, 'entry'), join(scratch, 'entry'), { recursive: true });
cpSync(join(root, 'tools'), join(scratch, 'tools'), { recursive: true });

const layoutPath = join(scratch, 'entry', 'src', 'main', 'ets', 'common', 'Layout.ets');
// 源文件是 CRLF,变异点按 LF 写,匹配前先统一换行
const pristine = readFileSync(layoutPath, 'utf8').replace(/\r\n/g, '\n');

/** 每一项:改什么、指望哪条断言抓住 */
const MUTATIONS = [
  {
    name: 'pageInsetY compact not narrowed (8 -> 16)',
    from: '    return 8;\n  }\n\n  static cardPadding',
    to: '    return 16;\n  }\n\n  static cardPadding'
  },
  {
    name: 'isCompact always false',
    from: 'return heightVp > 0 && heightVp < Layout.COMPACT_HEIGHT_MAX;',
    to: 'return false;'
  },
  {
    name: 'compact height threshold 500 -> 700',
    from: 'static readonly COMPACT_HEIGHT_MAX: number = 500;',
    to: 'static readonly COMPACT_HEIGHT_MAX: number = 700;'
  },
  {
    name: 'isStacked ignores the compact axis',
    from: 'return cls === DeviceClass.PHONE && !compact;',
    to: 'return cls === DeviceClass.PHONE;'
  },
  {
    name: 'classify ignores the height axis',
    from: 'if (Layout.isCompact(heightVp) && widthVp < Layout.PAD_MAX) {',
    to: 'if (false) {'
  },
  {
    name: 'pageInsetX compact not widened',
    from: 'return side > base ? side : base;',
    to: 'return base;'
  },
  {
    name: 'minSceneHeight compact raised to 210',
    from: '    if (compact) {\n      return 150;\n    }',
    to: '    if (compact) {\n      return 210;\n    }'
  }
];

let caught = 0;
for (const m of MUTATIONS) {
  if (pristine.indexOf(m.from) < 0) {
    console.log(`=== MUTATION: ${m.name} ===`);
    console.log('  ! 变异点没在 Layout.ets 里找到 —— 源码改了,这个变异作废');
    console.log();
    continue;
  }
  writeFileSync(layoutPath, pristine.split(m.from).join(m.to));
  const run = spawnSync(process.execPath, ['tools/physics-check/check.mjs'], {
    cwd: scratch,
    encoding: 'utf8'
  });
  const out = (run.stdout || '') + (run.stderr || '');
  const lines = out.split('\n').filter((l) => l.trim().length > 0);
  const tail = lines.slice(-16);
  const red = run.status !== 0;
  if (red) {
    caught++;
  }
  console.log(`=== MUTATION: ${m.name} ===`);
  console.log(red ? tail.join('\n') : '  ! 闸门仍然全绿 —— 这条变异没被抓住');
  console.log();
}

rmSync(scratch, { recursive: true, force: true });
console.log(`${caught}/${MUTATIONS.length} 处变异被断言抓住`);
if (caught < MUTATIONS.length) {
  process.exit(1);
}
