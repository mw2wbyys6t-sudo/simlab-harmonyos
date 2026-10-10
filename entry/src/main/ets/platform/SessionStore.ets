import { preferences } from '@kit.ArkData';
import { SessionLedger } from '../runner/SessionLedger';

const STORE_NAME: string = 'simlab_sessions';
const KEY_RECORDS: string = 'records';

/**
 * 操作记录的落盘绑定。
 *
 * 整个工程里唯一 import @kit.ArkData 的文件。排序、上限、序列化、统计全在
 * `runner/SessionLedger` 里并可离线断言;这里只负责"读写一对键值",
 * 所以它不需要测试覆盖也不该有逻辑可测。
 */
export class SessionStore {
  /** 读不出来或脏数据一律返回空账本:启动失败比丢历史严重得多 */
  static load(context: Context): SessionLedger {
    try {
      const node: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
      const raw: string = String(node.getSync(KEY_RECORDS, ''));
      return SessionLedger.fromJson(raw);
    } catch (error) {
      return new SessionLedger();
    }
  }

  static save(context: Context, ledger: SessionLedger): boolean {
    try {
      const node: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE_NAME });
      node.putSync(KEY_RECORDS, ledger.toJson());
      node.flushSync();
      return true;
    } catch (error) {
      return false;
    }
  }
}
