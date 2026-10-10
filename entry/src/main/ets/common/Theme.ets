import { Contrast } from './Contrast';
import { Subject } from '../model/ExperimentTypes';

/** 全局配色。教学大屏在强光下观看,底色与文字对比度按高对比取值。 */
export class Theme {
  static readonly BG_CANVAS: string = '#F7F9FC';
  static readonly BG_PAGE: string = '#F2F4F7';
  static readonly BG_CARD: string = '#FFFFFF';
  static readonly TEXT_PRIMARY: string = '#1F2A3A';
  // 以下四色同时用作文字与按钮底色,因此必须过 WCAG AA(4.5:1)。
  // 亮度上限由断言算出,不是审美判断:改深或改浅都会被 check.mjs 拦下。
  static readonly TEXT_SECONDARY: string = '#5A6878';
  static readonly ACCENT: string = '#2C6AAE';
  static readonly RUNNING: string = '#1F7A5C';
  static readonly DANGER: string = '#C0392B';
  static readonly DIVIDER: string = '#E1E6ED';

  /** 图线配色:同图内相邻曲线色差要大,便于后排辨认 */
  static readonly SERIES_1: string = '#2F6FB5';
  static readonly SERIES_2: string = '#E2574C';
  static readonly SERIES_3: string = '#2E9E7A';
  static readonly SERIES_4: string = '#8E5BD9';

  /** 前景兜底色:深色学科辅色上唯一可读的文字色 */
  static readonly WHITE: string = '#FFFFFF';

  // ---- 学科辅色 -------------------------------------------------------------
  // 七枚色相必须彼此分得开,且亮度足够低:断言要求它们作色点压页面底 ≥ 3.0,
  // 同时在其上放白字 ≥ 4.5。落在中间亮度带会让两种前景都不达标。
  static readonly SUBJECT_MECHANICS: string = '#2F6FB5';
  static readonly SUBJECT_ELECTRICAL: string = '#7C3AED';
  static readonly SUBJECT_CHEMISTRY: string = '#BE185D';
  static readonly SUBJECT_BIOLOGY: string = '#15803D';
  static readonly SUBJECT_GEOGRAPHY: string = '#0E7490';
  static readonly SUBJECT_MATH: string = '#B45309';
  static readonly SUBJECT_INSTRUMENT: string = '#475569';

  static subjectColor(subject: Subject): string {
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

  /**
   * 给定底色,返回在其上可读的前景色。
   *
   * 只返回正文色或白两种,不引入第三种:这样任何底色都必然落在既有文字层级里,
   * 不会出现一堆临时灰。
   */
  static textOn(background: string): string {
    const withBody = Contrast.ratio(Theme.TEXT_PRIMARY, background);
    const withWhite = Contrast.ratio(Theme.WHITE, background);
    if (withWhite > withBody) {
      return Theme.WHITE;
    }
    return Theme.TEXT_PRIMARY;
  }
}
