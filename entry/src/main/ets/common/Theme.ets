import { Subject } from '../model/ExperimentTypes';

/**
 * 配色令牌。
 *
 * **这里不再有任何十六进制字面量** —— 值全部住在
 * `resources/base/element/color.json`(浅色)与 `resources/dark/element/color.json`(深色),
 * 同名同数,由离线断言把两套都按 WCAG AA 算一遍(check.mjs 的「调色板资源」段)。
 *
 * 为什么不用 `sys.color.ohos_id_color_*`:实测(2026-10-11,Pura 90 Pro 模拟器)
 * `ohos_id_color_background` 是纯白 —— 它对应的是卡片底而不是页面底;
 * `ohos_id_divider_color` 只有 3% 黑,拿去当我们未选中 chip 的描边几乎看不见。
 * 加上这台镜像切不到深色(见 spec 8.29),系统令牌在深色下到底是什么值无法验证,
 * 所以两套都自己写、两套都能算。页面底/卡片底仍按实测到的系统值对齐(#F1F3F5 / #FFFFFF)。
 */
export class Theme {
  static readonly BG_CANVAS: Resource = $r('app.color.bg_canvas');
  static readonly BG_PAGE: Resource = $r('app.color.bg_page');
  static readonly BG_CARD: Resource = $r('app.color.bg_card');
  static readonly TEXT_PRIMARY: Resource = $r('app.color.text_primary');
  static readonly TEXT_SECONDARY: Resource = $r('app.color.text_secondary');
  static readonly DIVIDER: Resource = $r('app.color.divider');

  /** 语义色同时用作文字与按钮底色,所以两条路都有断言守着 */
  static readonly ACCENT: Resource = $r('app.color.accent');
  static readonly RUNNING: Resource = $r('app.color.running');
  static readonly DANGER: Resource = $r('app.color.danger');
  /**
   * 品牌色之上的前景。
   *
   * 原来是 `textOn(bg)` 在运行时算对比度挑字色;令牌化之后代码里拿到的是 Resource,
   * 算不了,也**不该**算 —— 浅色下品牌色压白字、深色下压近黑字,这是调色板自己的一对设计值,
   * 写进两套资源里,离线就能把两种模式一起验(算式反而看不到深色)。
   */
  static readonly ON_BRAND: Resource = $r('app.color.on_brand');

  /** 图线配色:画在"实验纸面"上,两套模式共用同一组值(断言守着这条) */
  static readonly SERIES_1: Resource = $r('app.color.series_1');
  static readonly SERIES_2: Resource = $r('app.color.series_2');
  static readonly SERIES_3: Resource = $r('app.color.series_3');
  static readonly SERIES_4: Resource = $r('app.color.series_4');

  // ---- 学科辅色 -------------------------------------------------------------
  static readonly SUBJECT_MECHANICS: Resource = $r('app.color.subject_mechanics');
  static readonly SUBJECT_ELECTRICAL: Resource = $r('app.color.subject_electrical');
  static readonly SUBJECT_CHEMISTRY: Resource = $r('app.color.subject_chemistry');
  static readonly SUBJECT_BIOLOGY: Resource = $r('app.color.subject_biology');
  static readonly SUBJECT_GEOGRAPHY: Resource = $r('app.color.subject_geography');
  static readonly SUBJECT_MATH: Resource = $r('app.color.subject_math');
  static readonly SUBJECT_INSTRUMENT: Resource = $r('app.color.subject_instrument');

  // ---- 页面级表面 -----------------------------------------------------------
  static readonly VERDICT_BG: Resource = $r('app.color.verdict_bg');
  static readonly BAND_BG: Resource = $r('app.color.band_bg');
  static readonly VESSEL_BORDER: Resource = $r('app.color.vessel_border');

  static subjectColor(subject: Subject): Resource {
    if (subject === Subject.PHYSICS_MECHANICS) {
      return Theme.SUBJECT_MECHANICS;
    }
    if (subject === Subject.PHYSICS_ELECTRICAL) {
      return Theme.SUBJECT_ELECTRICAL;
    }
    if (subject === Subject.CHEMISTRY) {
      return Theme.SUBJECT_CHEMISTRY;
    }
    if (subject === Subject.BIOLOGY) {
      return Theme.SUBJECT_BIOLOGY;
    }
    if (subject === Subject.GEOGRAPHY) {
      return Theme.SUBJECT_GEOGRAPHY;
    }
    if (subject === Subject.MATH_VISUAL) {
      return Theme.SUBJECT_MATH;
    }
    return Theme.SUBJECT_INSTRUMENT;
  }
}
