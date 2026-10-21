/**
 * Turning numbers into decisions.
 *
 * The admin console could already show what happened. What it could not do was
 * say what to do about it — and a dashboard that reports a churn rate without
 * naming which customers, worth how much, and what would plausibly help, is a
 * dashboard people check on Monday and stop checking by March.
 *
 * Three rules hold this together, and all three are about restraint:
 *
 * **A finding must name its evidence.** Not "retention is down" but "eleven
 * customers worth 4.2m between them have gone past twice their own buying
 * rhythm". The first is an opinion; the second can be acted on or dismissed on
 * its merits.
 *
 * **A finding must name an action somebody can actually take.** If the honest
 * answer is "look at this", the action is "look at this" — not a fabricated
 * remedy. An engine that invents plausible-sounding advice teaches the reader
 * to distrust the advice that was real.
 *
 * **Silence is a valid report.** A quiet week should produce an empty list, and
 * the console should say so. Padding it with findings nobody needs is how a
 * queue stops being read, which costs more than the week it papered over.
 */

export type FindingSeverity = 'critical' | 'warning' | 'opportunity';

export interface Finding {
  /** Stable identifier — screens and tests key on this, never on the wording. */
  code: string;
  severity: FindingSeverity;
  /** What is happening, in Arabic. */
  ar: string;
  /** What the numbers behind it are, so the claim can be checked. */
  evidence: Record<string, number | string | null>;
  /** What to do, in Arabic. Never invented — see the rules above. */
  actionAr: string;
  /** Where in the console the action is taken, when there is such a place. */
  href: string | null;
  /**
   * 0–100. Not a severity: this is how much attention it deserves *relative to
   * everything else on the screen today*, so a critical finding about two
   * customers can rank below a warning about two hundred.
   */
  weight: number;
}

/** Everything the engine reads, already counted. */
export interface MarketplaceFacts {
  /** Trust queue, unresolved. */
  openTrustSignals: number;
  suspectTrustSignals: number;

  /** Customers past their own rhythm, and what their leaving would cost. */
  churningCustomers: number;
  churningValue: number;

  /** Boutiques that used to sell and have stopped. */
  quietSellers: number;
  quietSellerLifetimeOrders: number;

  /** Platform economics over the window. */
  contributionMargin: number;
  platformRevenue: number;
  gmv: number;
  takeRate: number | null;

  /** Listings that answer a search nobody could answer. */
  unmetDemandTerms: number;
  topUnmetTerm: string | null;
  topUnmetSearches: number;

  /** Catalogue hygiene. */
  duplicateCandidates: number;

  /** Listings climbing fast enough to be worth stocking more of. */
  risingProducts: number;
  topRisingTitle: string | null;

  /** Stock that will run out before it can be replaced. */
  stockoutRisks: number;

  /** How long the window was. */
  windowDays: number;
  currencyLabel: string;
}

const money = (value: number, label: string) =>
  `${Math.round(value).toLocaleString('en-US')} ${label}`;

/**
 * Reads the marketplace and returns what a person should look at today.
 *
 * Ordered by weight, and empty when there is nothing worth saying.
 */
export function findingsFor(facts: MarketplaceFacts): Finding[] {
  const out: Finding[] = [];

  // ── Money first. Everything else is downstream of whether the orders the
  //    platform carries are worth carrying.
  if (facts.contributionMargin < 0) {
    out.push({
      code: 'negative_contribution',
      severity: 'critical',
      ar: `المنصة تخسر على كل طلب: هامش المساهمة ${money(facts.contributionMargin, facts.currencyLabel)} خلال ${facts.windowDays} يوماً`,
      evidence: {
        contribution_margin: facts.contributionMargin,
        platform_revenue: facts.platformRevenue,
        gmv: facts.gmv,
      },
      actionAr:
        'راجعي رسوم التوصيل والقسائم المموّلة من المنصة — النمو في هذه الحالة يوسّع الخسارة لا يغطّيها',
      href: '/admin/economics',
      weight: 100,
    });
  } else if (
    facts.takeRate !== null &&
    facts.takeRate < 0.03 &&
    facts.gmv > 0
  ) {
    out.push({
      code: 'take_rate_thin',
      severity: 'warning',
      ar: `المنصة تحتفظ بـ${(facts.takeRate * 100).toFixed(1)}% فقط ممّا يمرّ عبرها`,
      evidence: { take_rate: facts.takeRate, gmv: facts.gmv },
      actionAr: 'راجعي قواعد العمولة حسب الفئة — بعضها قد يكون أقلّ من تكلفة خدمتها',
      href: '/admin/commissions',
      weight: 70,
    });
  }

  // ── Customers leaving, weighted by what they are worth rather than by how
  //    many they are. Two hundred customers worth nothing is not the story.
  if (facts.churningCustomers > 0 && facts.churningValue > 0) {
    out.push({
      code: 'value_at_risk',
      severity: facts.churningValue > facts.gmv * 0.15 ? 'critical' : 'warning',
      ar: `${facts.churningCustomers} عميلة تجاوزن وتيرتهنّ المعتادة، وقيمتهنّ المتوقّعة ${money(facts.churningValue, facts.currencyLabel)}`,
      evidence: {
        customers: facts.churningCustomers,
        projected_value: facts.churningValue,
      },
      actionAr:
        'شغّلي حملة استعادة موجَّهة للأعلى قيمة منهنّ — لا للجميع، فالميزانية الموزّعة بالتساوي تُنفَق على من لا يستحقّها',
      href: '/admin/lifecycle',
      weight: Math.min(
        95,
        60 + Math.round((facts.churningValue / Math.max(facts.gmv, 1)) * 100),
      ),
    });
  }

  // ── Trust. A suspect signal sitting unread is worse than no queue.
  if (facts.suspectTrustSignals > 0) {
    out.push({
      code: 'trust_suspects_waiting',
      severity: 'critical',
      ar: `${facts.suspectTrustSignals} إشارة ثقة عالية الخطورة تنتظر مراجعة`,
      evidence: {
        suspect: facts.suspectTrustSignals,
        open_total: facts.openTrustSignals,
      },
      actionAr: 'راجعي الطابور — كل إشارة تحمل أدلّتها، والقرار لشخص لا للنظام',
      href: '/admin/trust',
      weight: 90,
    });
  } else if (facts.openTrustSignals > 20) {
    out.push({
      code: 'trust_backlog',
      severity: 'warning',
      ar: `${facts.openTrustSignals} إشارة ثقة مفتوحة تراكمت`,
      evidence: { open_total: facts.openTrustSignals },
      actionAr: 'طابور لا يُقرأ يعلّم قارئه تجاهله — خصّصي وقتاً أسبوعياً له',
      href: '/admin/trust',
      weight: 45,
    });
  }

  // ── Sellers going quiet. The mirror of customer churn, and the one nobody
  //    counts until the catalogue has visibly thinned.
  if (facts.quietSellers > 0) {
    out.push({
      code: 'sellers_going_quiet',
      severity: facts.quietSellerLifetimeOrders > 50 ? 'warning' : 'opportunity',
      ar: `${facts.quietSellers} بوتيك توقّفن عن البيع بعد ${facts.quietSellerLifetimeOrders} طلباً بينهنّ`,
      evidence: {
        sellers: facts.quietSellers,
        lifetime_orders: facts.quietSellerLifetimeOrders,
      },
      actionAr:
        'اتّصلي بالأكثر مبيعاً منهنّ أولاً — سوق يفقد بائعاته يفقد بعدها عميلاته',
      href: '/admin/sellers/retention',
      weight: 55 + Math.min(25, facts.quietSellers * 3),
    });
  }

  // ── Demand nobody could answer. The clearest buying instruction a
  //    marketplace ever gets, and it arrives free.
  if (facts.unmetDemandTerms > 0 && facts.topUnmetTerm) {
    out.push({
      code: 'unmet_demand',
      severity: 'opportunity',
      ar: `${facts.unmetDemandTerms} كلمة بحث بلا نتائج — أكثرها «${facts.topUnmetTerm}» بـ${facts.topUnmetSearches} بحثاً`,
      evidence: {
        terms: facts.unmetDemandTerms,
        top_term: facts.topUnmetTerm,
        top_searches: facts.topUnmetSearches,
      },
      actionAr:
        'إمّا أن المتجر لا يبيعها — وهذه فرصة شراء — أو يبيعها باسم آخر، وعندها أضيفي مرادفاً',
      href: '/admin/search/synonyms/unanswered',
      weight: 40 + Math.min(30, facts.topUnmetSearches),
    });
  }

  // ── Things going right, said out loud. A console that only ever reports
  //    problems is a console that gets read as noise.
  if (facts.risingProducts > 0 && facts.topRisingTitle) {
    out.push({
      code: 'rising_products',
      severity: 'opportunity',
      ar: `${facts.risingProducts} قطعة تتصدّر التحويل هذا الأسبوع — أعلاها «${facts.topRisingTitle}»`,
      evidence: {
        products: facts.risingProducts,
        top: facts.topRisingTitle,
      },
      actionAr: 'اقترحي على بائعاتها زيادة المخزون قبل نفاده',
      href: '/admin/ranking',
      weight: 35,
    });
  }

  if (facts.stockoutRisks > 0) {
    out.push({
      code: 'stockout_risk',
      severity: 'warning',
      ar: `${facts.stockoutRisks} قطعة ستنفد قبل أن يمكن تعويضها`,
      evidence: { products: facts.stockoutRisks },
      actionAr: 'نبّهي البائعات — قطعة تنفد وهي تبيع جيداً خسارة مضاعفة',
      href: '/admin/products',
      weight: 50,
    });
  }

  if (facts.duplicateCandidates > 0) {
    out.push({
      code: 'duplicate_listings',
      severity: 'opportunity',
      ar: `${facts.duplicateCandidates} زوجاً من الإعلانات تبدو لنفس القطعة`,
      evidence: { pairs: facts.duplicateCandidates },
      actionAr:
        'دمجها يجمع العروض على صفحة واحدة — وهذا هو سبب فصل المنتج عن عرض البائعة أصلاً',
      href: '/admin/catalog/duplicates',
      weight: 25,
    });
  }

  return out.sort((a, b) => b.weight - a.weight);
}
