import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Appearance } from '../common/Appearance';
import { Palette } from '../view/Palette';

const STORE_NAME: string = 'simlab_settings';
const KEY_APPEARANCE: string = 'appearance';

/**
 * 深浅色开关的落盘与生效。
 *
 * 三档的取值、顺序、脏值回落全是纯逻辑,住在 `common/Appearance`(离线断言覆盖);
 * 这里只碰两个系统 API:preferences 和 setColorMode。
 *
 * `apply` 末尾必须 `Palette.reset()`:setColorMode 之后系统会换掉 resource manager,
 * 而画布只吃字符串,缓存里存的还是旧模式的 hex —— 不清掉就是一半新一半旧。
 * 这条依赖(view 层)刻意留在生效函数里而不是让调用方各自记得调,漏一次就是一个看不到的小 bug。
 */
export class AppearanceStore {
  static load(context: common.Context): string {
    try {
      const node: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
      return Appearance.normalize(String(node.getSync(KEY_APPEARANCE, '')));
    } catch (error) {
      return Appearance.SYSTEM;
    }
  }

  static save(context: common.Context, choice: string): boolean {
    try {
      const node: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
      node.putSync(KEY_APPEARANCE, Appearance.normalize(choice));
      node.flushSync();
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * 立刻生效。
   *
   * 用 UIAbilityContext 而不是 ApplicationContext:优先级是「UIAbility > Application > 系统」,
   * 设在 ability 上才是这个应用自己说了算。
   */
  static apply(context: common.UIAbilityContext, choice: string): void {
    const normalized: string = Appearance.normalize(choice);
    try {
      context.setColorMode(AppearanceStore.toColorMode(normalized));
    } catch (error) {
      // 切不动就维持现状:深浅色是偏好,不是能让应用起不来的东西
    }
    Palette.reset();
  }

  /** 档位到系统枚举。写错这一格(浅色/深色互换)不会报错,只会整个界面反着来 */
  static toColorMode(choice: string): ConfigurationConstant.ColorMode {
    if (choice === Appearance.LIGHT) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
    if (choice === Appearance.DARK) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  }
}
