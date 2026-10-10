/**
 * 稠密线性方程组 Ax = b 的列主元高斯消元。
 *
 * 直流电路的规模很小(节点数 + 电压源支路数,通常 < 20),不需要迭代法或稀疏求解器。
 * 选列主元是因为闭合回路里会出现纯电压源环,系数矩阵可能接近奇异,
 * 不做主元交换会得出错误读数而不是干净地报错。
 */
export class MnaSolver {
  /**
   * @param matrix 系数矩阵,会被就地消元(调用方传入可丢弃的副本)
   * @param rhs 右端向量,同样就地修改
   * @returns 解向量;矩阵奇异或规模不一致时返回 null
   */
  static solve(matrix: number[][], rhs: number[]): number[] | null {
    const n = rhs.length;
    if (matrix.length !== n) {
      return null;
    }
    for (let i = 0; i < n; i++) {
      if (matrix[i].length !== n) {
        return null;
      }
    }

    for (let col = 0; col < n; col++) {
      let pivot = col;
      let best = Math.abs(matrix[col][col]);
      for (let row = col + 1; row < n; row++) {
        const candidate = Math.abs(matrix[row][col]);
        if (candidate > best) {
          best = candidate;
          pivot = row;
        }
      }
      if (best < MnaSolver.EPSILON) {
        return null;
      }
      if (pivot !== col) {
        MnaSolver.swapRows(matrix, col, pivot);
        MnaSolver.swapValues(rhs, col, pivot);
      }

      const diag = matrix[col][col];
      for (let row = col + 1; row < n; row++) {
        const factor = matrix[row][col] / diag;
        if (factor === 0) {
          continue;
        }
        for (let k = col; k < n; k++) {
          matrix[row][k] -= factor * matrix[col][k];
        }
        rhs[row] -= factor * rhs[col];
      }
    }

    const out: number[] = new Array<number>(n);
    for (let row = n - 1; row >= 0; row--) {
      let sum = rhs[row];
      for (let k = row + 1; k < n; k++) {
        sum -= matrix[row][k] * out[k];
      }
      out[row] = sum / matrix[row][row];
    }
    return out;
  }

  private static readonly EPSILON: number = 1e-12;

  private static swapRows(matrix: number[][], a: number, b: number): void {
    const hold = matrix[a];
    matrix[a] = matrix[b];
    matrix[b] = hold;
  }

  private static swapValues(values: number[], a: number, b: number): void {
    const hold = values[a];
    values[a] = values[b];
    values[b] = hold;
  }
}
