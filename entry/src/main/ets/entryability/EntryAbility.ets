import { AbilityConstant, Configuration, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppearanceStore } from '../platform/AppearanceStore';
import { ContentStore } from '../platform/ContentStore';
import { Palette } from '../view/Palette';

const DOMAIN = 0x0000;
const TAG = 'SimLab';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 深浅色是用户偏好,不再硬钉浅色:启动时把盘里的那档打回去,没存过就是「跟随系统」。
    // 放在 onCreate 而不是 loadContent 之后 —— 资源在首帧就按这一档解析,晚一步就闪一次底色。
    AppearanceStore.apply(this.context, AppearanceStore.load(this.context));
    // 画布只吃字符串,而 ability 比任何组件都先活:在这里绑上解析器,
    // 组件构造期取的色就不会拿到"还没绑"的占位值。
    Palette.bind(this.context);
    // 内容更新通道:沙箱 JSON > rawfile > 编译期那张表。
    // 解码不过就整批拒绝,所以这里只把原因写进日志,不需要任何错误分支。
    const rejected = ContentStore.load(this.context);
    for (const problem of rejected) {
      hilog.warn(DOMAIN, TAG, 'content refused: %{public}s', problem);
    }
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  /**
   * 跟随系统时,深浅色由系统翻。组件层的 Resource 会自己重解,
   * 但画布吃的是 Palette 缓存下来的 hex —— 不重解就会停在旧模式的颜色上。
   */
  onConfigurationUpdate(newConfig: Configuration): void {
    Palette.reset();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}