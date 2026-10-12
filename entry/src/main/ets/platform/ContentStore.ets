import { common } from '@kit.AbilityKit';
import { buffer, util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { ContentCodec, ContentOverride } from '../content/map/ContentCodec';
import { ExperimentEntry } from '../content/map/CurriculumTypes';
import { SchoolPhysics } from '../content/map/SchoolPhysics';

/** 一张可被更新的表:键名(也是文件名)、沙箱路径、编译期兜底 */
class ContentTable {
  key: string = '';
  builtIn: ExperimentEntry[] = [];

  constructor(key: string, builtIn: ExperimentEntry[]) {
    this.key = key;
    this.builtIn = builtIn;
  }
}

const TABLES: ContentTable[] = [new ContentTable('school-physics', SchoolPhysics.all())];

/**
 * 内容更新通道的读取端。三层优先级,任何一层坏了就落到下一层:
 *
 * 1. 沙箱 `files/content/<key>.json` —— 这一层才是"不重装改一条知识点"的地方;
 * 2. rawfile `content/<key>.json` —— 随包发布的默认值,由 `tools/arch/gen-content.mjs`
 *    从内置表生成,离线断言守着它与内置表逐字节相同;
 * 3. 编译期那张表 —— 前两层都不存在或都过不了校验时用它。
 *
 * **这张列表的存在本身就是一条规矩:更新失败的表现必须是"内容没变",
 * 而不是"地图空了"。** 解码与校验都在 `ContentCodec` 里,离线可测;
 * 这里只做"读字节"这一件没法离线测的事。
 */
export class ContentStore {
  /** 返回每一条被拒绝的原因,给调用方写日志用;空数组表示一切按内置或覆盖生效 */
  static load(context: common.UIAbilityContext): string[] {
    const problems: string[] = [];
    for (const table of TABLES) {
      const sandbox = context.filesDir + '/content/' + table.key + '.json';
      let text: string = ContentStore.readSandbox(sandbox);
      let origin = '沙箱';
      if (text.length === 0) {
        text = ContentStore.readRawfile(context, 'content/' + table.key + '.json');
        origin = 'rawfile';
      }
      if (text.length === 0) {
        continue;   // 两层都没有文件:用内置表,不算问题
      }
      const decoded = ContentCodec.decodeExperiments(text);
      if (decoded.rows.length === 0) {
        problems.push(`${table.key}(${origin}):${decoded.problems.join(';')}`);
        continue;   // 坏数据整批拒绝,内置表继续生效
      }
      if (!ContentOverride.set(table.key, decoded.rows)) {
        problems.push(`${table.key}(${origin}):解出 0 行,拒绝覆盖`);
      }
    }
    return problems;
  }

  private static readSandbox(path: string): string {
    try {
      const stat = fileIo.statSync(path);
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const bytes = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, bytes);
      fileIo.closeSync(file);
      return ContentStore.decode(bytes);
    } catch (error) {
      return '';
    }
  }

  private static readRawfile(context: common.UIAbilityContext, name: string): string {
    try {
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(name);
      const buf = new ArrayBuffer(bytes.byteLength);
      new Uint8Array(buf).set(bytes);
      return ContentStore.decode(buf);
    } catch (error) {
      return '';
    }
  }

  private static decode(bytes: ArrayBuffer): string {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(bytes));
  }
}
