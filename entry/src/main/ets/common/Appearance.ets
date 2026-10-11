/**
 * 深浅色偏好的纯逻辑。
 *
 * 落盘(`@kit.ArkData`)与 `setColorMode`(`@kit.AbilityKit`)都在 `platform/AppearanceStore`,
 * 离线跑不了;这里只放能被断言算清楚的那部分:三档的取值、顺序、脏数据回落、以及给学生看的标签。
 *
 * 顺序是有意义的:`CHOICES[0]` 是"用户什么都没选"时的落点,首页 chip 的 0 也指向它。
 * 之所以 `normalize` 不 trim、不分大小写:写进盘里的值只可能是我们自己写的那三个,
 * 出现别的形态就说明盘被改坏了 —— 那种情况悄悄回落默认档,比按一个猜出来的档更安全。
 */
export class Appearance {
  static readonly SYSTEM: string = 'system';
  static readonly LIGHT: string = 'light';
  static readonly DARK: string = 'dark';
  static readonly CHOICES: string[] = [Appearance.SYSTEM, Appearance.LIGHT, Appearance.DARK];

  /** 与 CHOICES 同序的学生可见标签(chip 直接吃这个数组,不再各自拼一份) */
  static readonly LABELS: string[] = ['跟随系统', '浅色', '深色'];

  /** 落点永远是三档之一:脏值不会把界面推进一个不存在的档 */
  static normalize(raw: string): string {
    for (const choice of Appearance.CHOICES) {
      if (choice === raw) {
        return choice;
      }
    }
    return Appearance.SYSTEM;
  }

  /** 越界与负下标都回落到默认档,而不是 undefined */
  static at(index: number): string {
    if (index < 0 || index >= Appearance.CHOICES.length) {
      return Appearance.SYSTEM;
    }
    return Appearance.CHOICES[index];
  }

  static indexOf(choice: string): number {
    const normalized: string = Appearance.normalize(choice);
    for (let i = 0; i < Appearance.CHOICES.length; i++) {
      if (Appearance.CHOICES[i] === normalized) {
        return i;
      }
    }
    return 0;
  }

  /** 学生看到的三个词 —— 内部标识不出现在这里(④ 的规矩) */
  static label(choice: string): string {
    return Appearance.LABELS[Appearance.indexOf(choice)];
  }
}
