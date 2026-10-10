/**
 * 记录型画布:把 LathePainter.draw 的每一次落笔按路径记下来。
 *
 * 测试工装,不是产品代码,所以放在 tools/ 下,不进 check.mjs 的 MODULES 白名单。
 * 它能证的不是"好不好看",而是四件会悄悄坏掉的事:路径闭合、落点不出画布、
 * 空路径上没有 fill/stroke、同输入必得同输出(不变量 I2 在渲染侧的对应物)。
 */
export function makeRecorder(width, height) {
  const calls = [];
  const points = [];
  const paths = [];
  let current = null;

  const touch = () => {
    if (current === null) {
      current = { ops: 0, lineTos: 0, closed: false, filled: false, stroked: false };
      paths.push(current);
    }
    return current;
  };

  const gradient = {
    addColorStop: (offset, color) => {
      calls.push('stop:' + offset.toFixed(3) + ':' + color);
    }
  };

  const raw = {
    clearRect: (x, y, w, h) => { calls.push('clearRect:' + x + ':' + y + ':' + w + ':' + h); },
    save: () => { calls.push('save'); },
    restore: () => { calls.push('restore'); },
    beginPath: () => {
      current = { ops: 0, lineTos: 0, closed: false, filled: false, stroked: false };
      paths.push(current);
      calls.push('beginPath');
    },
    moveTo: (x, y) => {
      touch().ops++;
      points.push([x, y]);
      calls.push('moveTo:' + x.toFixed(2) + ',' + y.toFixed(2));
    },
    lineTo: (x, y) => {
      const p = touch();
      p.ops++;
      p.lineTos++;
      points.push([x, y]);
      calls.push('lineTo:' + x.toFixed(2) + ',' + y.toFixed(2));
    },
    ellipse: (cx, cy, rx, ry, rot, a0, a1) => {
      const p = touch();
      p.ops += 2;
      points.push([cx - rx, cy]);
      points.push([cx + rx, cy]);
      calls.push('ellipse:' + cx.toFixed(2) + ',' + cy.toFixed(2) + ',' +
        rx.toFixed(2) + ',' + ry.toFixed(2) + ',' + a0 + ',' + a1);
    },
    closePath: () => {
      touch().closed = true;
      calls.push('closePath');
    },
    fill: () => {
      if (current !== null) {
        current.filled = true;
      }
      calls.push('fill');
    },
    stroke: () => {
      if (current !== null) {
        current.stroked = true;
      }
      calls.push('stroke');
    },
    fillText: (text, x, y) => {
      touch().ops++;
      points.push([x, y]);
      calls.push('fillText:' + text + ':' + x.toFixed(2) + ',' + y.toFixed(2));
    },
    createLinearGradient: () => gradient
  };

  const ctx = new Proxy(raw, {
    get(target, prop) {
      const key = String(prop);
      if (key === 'width') {
        return width;
      }
      if (key === 'height') {
        return height;
      }
      if (target[key] !== undefined) {
        return target[key];
      }
      calls.push('READ:' + key);
      return undefined;
    },
    set(target, prop, value) {
      calls.push('SET:' + String(prop));
      target[String(prop)] = () => value;
      return true;
    }
  });

  return { ctx, calls, points, paths };
}
