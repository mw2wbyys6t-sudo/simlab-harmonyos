/**
 * 化学式解析与式量计算。
 *
 * 相对原子质量取教材附录常用值(Cl=35.5、Cu=64、Ba=137 等),不取 IUPAC 精确值 ——
 * 学生按这张表手算，仿真给出的质量关系必须与他们的算式一致,
 * 否则「根据方程式计算」类题目会得到对不上的答案。
 *
 * 式量一律由化学式算出,不在数据里手写。这样录入物质时少一类错误,
 * 而且守恒校验有独立依据。
 */
class AtomicMassTable {
  private static readonly entries: string =
    'H1 C12 N14 O16 F19 Na23 Mg24 Al27 P31 S32 Cl35.5 K39 Ca40 Mn55 Fe56 Cu64 Zn65 ' +
    'Br80 Ag108 Ba137 I127 Pb207 Si28 Cr52 Ni59 Sn119 Pt195 Au197 Li7 Rb85 Cs133 Sr88';

  private static table: Map<string, number> | null = null;

  static get(symbol: string): number {
    if (AtomicMassTable.table === null) {
      const built: Map<string, number> = new Map();
      const tokens: string[] = AtomicMassTable.entries.split(' ');
      for (let i = 0; i < tokens.length; i++) {
        const token = tokens[i];
        // 两位元素符号(如 Na、Cl)首字母大写次字母小写,按长度切分符号与数值
        const symbolLength = token.charAt(1) >= 'a' && token.charAt(1) <= 'z' ? 2 : 1;
        built.set(token.substring(0, symbolLength), Number.parseFloat(token.substring(symbolLength)));
      }
      AtomicMassTable.table = built;
    }
    const hit = AtomicMassTable.table.get(symbol);
    return hit === undefined ? Number.NaN : hit;
  }

  static known(symbol: string): boolean {
    return Number.isFinite(AtomicMassTable.get(symbol));
  }
}

export class ParsedFormula {
  /** 元素符号 → 原子个数 */
  counts: Map<string, number> = new Map();
  /** 净电荷:阳离子为正、阴离子为负、中性分子为 0 */
  charge: number = 0;
  /** 解析失败时非空,供数据校验直接报出原因 */
  error: string = '';
}

class Cursor {
  text: string = '';
  pos: number = 0;

  constructor(text: string) {
    this.text = text;
  }

  peek(): string {
    return this.pos < this.text.length ? this.text.charAt(this.pos) : '';
  }

  next(): string {
    const ch = this.peek();
    this.pos++;
    return ch;
  }

  eof(): boolean {
    return this.pos >= this.text.length;
  }
}

export class Formula {
  /** 解析化学式,支持嵌套括号、结晶水(· 或 *)与离子电荷(^n+ / ^n- 或尾部 +/-) */
  static parse(raw: string): ParsedFormula {
    const result = new ParsedFormula();
    const cursor = new Cursor(raw.trim());
    Formula.parseSegments(cursor, result);
    return result;
  }

  /**
   * 一个「段」是被 · 或 * 隔开的部分。段首的计量数作用于整段而不是第一个元素 ——
   * CuSO₄·5H₂O 里的 5 要乘遍 H₂O,只乘 H 会把结晶水算错。
   */
  private static parseSegments(cursor: Cursor, into: ParsedFormula): void {
    while (!cursor.eof()) {
      const ch = cursor.peek();
      if (ch === '·' || ch === '*' || ch === '.') {
        cursor.next();
        continue;
      }
      if (ch === '^') {
        cursor.next();
        Formula.parseCharge(cursor, into);
        continue;
      }
      const leading = Formula.readNumber(cursor);
      const multiplier = leading === 0 ? 1 : leading;
      const run = new ParsedFormula();
      while (!cursor.eof()) {
        const scan = cursor.peek();
        if (scan === '·' || scan === '*' || scan === '.' || scan === '^') {
          break;
        }
        if (!Formula.parseUnit(cursor, run)) {
          into.error = run.error.length > 0 ? run.error : '无法解析的化学式片段';
          return;
        }
      }
      if (run.counts.size === 0) {
        into.error = '无法解析的化学式片段';
        return;
      }
      Formula.merge(into, run, multiplier);
    }
  }

  /** 解析单个元素或原子团(含其后的下标)。返回 false 表示遇到非法字符 */
  private static parseUnit(cursor: Cursor, into: ParsedFormula): boolean {
    const ch = cursor.peek();
    if (ch === '(' || ch === '[') {
      const group = new ParsedFormula();
      cursor.next();
      Formula.parseGroupBody(cursor, group);
      if (group.error.length > 0) {
        into.error = group.error;
        return false;
      }
      if (cursor.peek() !== ')' && cursor.peek() !== ']') {
        into.error = '括号未闭合';
        return false;
      }
      cursor.next();
      const after = Formula.readNumber(cursor);
      Formula.merge(into, group, after === 0 ? 1 : after);
      return true;
    }
    if (ch >= 'A' && ch <= 'Z') {
      const symbol = Formula.readSymbol(cursor);
      if (!AtomicMassTable.known(symbol)) {
        into.error = '未知元素符号 ' + symbol;
        return false;
      }
      const count = Formula.readNumber(cursor);
      Formula.addAtom(into, symbol, count === 0 ? 1 : count);
      return true;
    }
    into.error = '意外的字符 ' + ch;
    return false;
  }

  private static parseGroupBody(cursor: Cursor, into: ParsedFormula): void {
    while (!cursor.eof() && cursor.peek() !== ')' && cursor.peek() !== ']') {
      if (!Formula.parseUnit(cursor, into)) {
        return;
      }
    }
  }

  private static parseCharge(cursor: Cursor, into: ParsedFormula): void {
    const magnitude = Formula.readNumber(cursor);
    const sign = cursor.peek();
    if (sign !== '+' && sign !== '-') {
      into.error = '电荷符号缺失';
      return;
    }
    cursor.next();
    const value = magnitude === 0 ? 1 : magnitude;
    into.charge += sign === '+' ? value : -value;
  }

  private static readSymbol(cursor: Cursor): string {
    let symbol = cursor.next();
    const second = cursor.peek();
    if (second >= 'a' && second <= 'z') {
      symbol += cursor.next();
    }
    return symbol;
  }

  private static readNumber(cursor: Cursor): number {
    let digits = '';
    while (!cursor.eof()) {
      const ch = cursor.peek();
      if (ch >= '0' && ch <= '9') {
        digits += cursor.next();
      } else {
        break;
      }
    }
    return digits.length === 0 ? 0 : Number.parseInt(digits, 10);
  }

  private static addAtom(target: ParsedFormula, symbol: string, count: number): void {
    const hit = target.counts.get(symbol);
    target.counts.set(symbol, hit === undefined ? count : hit + count);
  }

  private static merge(target: ParsedFormula, source: ParsedFormula, scale: number): void {
    source.counts.forEach((count: number, symbol: string) => {
      Formula.addAtom(target, symbol, count * scale);
    });
    target.charge += source.charge * scale;
  }

  /** 式量(相对分子质量)。含未知元素时返回 NaN */
  static relativeMass(raw: string): number {
    const parsed = Formula.parse(raw);
    if (parsed.error.length > 0) {
      return Number.NaN;
    }
    return Formula.massOf(parsed);
  }

  static massOf(parsed: ParsedFormula): number {
    let sum = 0;
    parsed.counts.forEach((count: number, symbol: string) => {
      sum += AtomicMassTable.get(symbol) * count;
    });
    return sum;
  }

  /** 元素清单文本,供报错时直接看到差异,如 "H:2 O:1" */
  static describe(counts: Map<string, number>): string {
    const parts: string[] = [];
    counts.forEach((count: number, symbol: string) => {
      parts.push(symbol + ':' + count);
    });
    return parts.join(' ');
  }
}
