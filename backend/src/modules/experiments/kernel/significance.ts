/**
 * Whether a difference between two arms is worth believing.
 *
 * **What this is not.** It is not permission to stop the test. A two-proportion
 * z-test answers "how surprising would this gap be if the two arms were really
 * the same", and it answers it for *one* look at the data. Checking every
 * morning until it says yes will make it say yes to noise — that is not a flaw
 * in the maths, it is what repeatedly sampling does, and no amount of care in
 * this file prevents it. The honest use is to fix a sample size in advance,
 * wait for it, and look once.
 *
 * So the result carries the interval and the sample alongside the verdict, and
 * `readable` is false until both arms have enough subjects for the
 * normal approximation to mean anything. A screen that shows only "significant
 * ✓" teaches people to peek.
 */

export interface Arm {
  key: string;
  subjects: number;
  conversions: number;
}

export interface Comparison {
  /** Conversions ÷ exposures, or null when nobody was exposed. */
  rate: number | null;
  /** Difference from control, in percentage points. Null without both rates. */
  liftPoints: number | null;
  /**
   * Two-sided p-value against control, or null when the sample is too thin
   * for the approximation to be worth printing.
   */
  pValue: number | null;
  /** 95% interval on the difference, same units as `liftPoints`. */
  intervalPoints: [number, number] | null;
  /**
   * False until both arms clear `MIN_SUBJECTS` *and* the expected counts are
   * large enough. Everything above is null when this is false.
   */
  readable: boolean;
}

/**
 * Below this, the normal approximation is not describing anything.
 *
 * Deliberately high enough to be inconvenient. A test read at fifty subjects
 * an arm is a test that will report whatever happened first.
 */
export const MIN_SUBJECTS = 200;

/** The conventional bar, named so a screen can say what it is. */
export const ALPHA = 0.05;

export function compare(control: Arm, arm: Arm): Comparison {
  const controlRate = rateOf(control);
  const armRate = rateOf(arm);

  if (controlRate === null || armRate === null) {
    return {
      rate: armRate,
      liftPoints: null,
      pValue: null,
      intervalPoints: null,
      readable: false,
    };
  }

  const liftPoints = Number(((armRate - controlRate) * 100).toFixed(2));

  const thin =
    control.subjects < MIN_SUBJECTS ||
    arm.subjects < MIN_SUBJECTS ||
    // The usual rule of thumb for the approximation: at least five expected
    // in each cell. A 0.1%-conversion test needs far more than 200 a side.
    Math.min(
      control.conversions,
      control.subjects - control.conversions,
      arm.conversions,
      arm.subjects - arm.conversions,
    ) < 5;

  if (thin) {
    return {
      rate: armRate,
      liftPoints,
      pValue: null,
      intervalPoints: null,
      readable: false,
    };
  }

  // Pooled proportion for the test statistic; unpooled for the interval,
  // which is the standard pairing — the null hypothesis assumes one rate, the
  // interval does not.
  const pooled =
    (control.conversions + arm.conversions) / (control.subjects + arm.subjects);
  const seNull = Math.sqrt(
    pooled * (1 - pooled) * (1 / control.subjects + 1 / arm.subjects),
  );
  const z = seNull > 0 ? (armRate - controlRate) / seNull : 0;
  const pValue = Number(twoSided(z).toFixed(5));

  const seDiff = Math.sqrt(
    (controlRate * (1 - controlRate)) / control.subjects +
      (armRate * (1 - armRate)) / arm.subjects,
  );
  const margin = 1.959_963_985 * seDiff;

  return {
    rate: armRate,
    liftPoints,
    pValue,
    intervalPoints: [
      Number(((armRate - controlRate - margin) * 100).toFixed(2)),
      Number(((armRate - controlRate + margin) * 100).toFixed(2)),
    ],
    readable: true,
  };
}

function rateOf(arm: Arm): number | null {
  if (arm.subjects <= 0) return null;
  return arm.conversions / arm.subjects;
}

/** Two-sided p-value for a z statistic. */
function twoSided(z: number): number {
  return 2 * (1 - standardNormalCdf(Math.abs(z)));
}

/**
 * Φ(x), via the Abramowitz–Stegun 7.1.26 approximation of erf.
 *
 * Accurate to about 1.5e-7, which is several orders of magnitude better than
 * the precision anybody should be claiming from an A/B test.
 */
function standardNormalCdf(x: number): number {
  return 0.5 * (1 + erf(x / Math.SQRT2));
}

function erf(x: number): number {
  const sign = x < 0 ? -1 : 1;
  const absolute = Math.abs(x);

  const t = 1 / (1 + 0.3275911 * absolute);
  const y =
    1 -
    ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) *
      t +
      0.254829592) *
      t *
      Math.exp(-absolute * absolute);

  return sign * y;
}
