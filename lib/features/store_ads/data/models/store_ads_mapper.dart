import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';

/// Parses `/ads/*`.
abstract final class StoreAdsMapper {
  static int _int(Object? value) => switch (value) {
    final num n => n.round(),
    final String s => (num.tryParse(s) ?? 0).round(),
    _ => 0,
  };

  static double? _double(Object? value) => switch (value) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };

  /// `{amount: "22400.0000", currency}` or a bare number.
  static int _money(Object? value) =>
      value is Map ? _int(value['amount']) : _int(value);

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : const {};

  static List<Map<String, dynamic>> _rows(Object? value) => [
    for (final row in (value is List ? value : const []).whereType<Map>())
      row.cast<String, dynamic>(),
  ];

  static AdPlansView plans(Map<String, dynamic> json) {
    final current = _map(json['current']);
    final queued = json['queued'] is Map ? _map(json['queued']) : null;
    final rec = json['recommendation'] is Map
        ? _map(json['recommendation'])
        : null;
    return AdPlansView(
      current: AdCurrentPlan(
        tier: AdTier.fromWire(current['tier'] as String?),
        endsAt: _date(current['ends_at']),
        creditGranted: _int(current['credit_granted']),
        creditUsed: _int(current['credit_used']),
        creditRemaining: _int(current['credit_remaining']),
        activeCampaigns: _int(current['active_campaigns']),
        maxActiveCampaigns: _int(current['max_active_campaigns']),
      ),
      plans: [for (final row in _rows(json['plans'])) plan(row)],
      queuedTier: queued == null
          ? null
          : AdTier.fromWire(queued['tier'] as String?),
      queuedStartsAt: queued == null ? null : _date(queued['starts_at']),
      spendLast30Days: _int(json['spend_last_30_days']),
      earningsBalance: _int(json['earnings_balance']),
      storeVerified: json['store_verified'] != false,
      pendingPurchase: json['pending_purchase'] is Map
          ? purchase(_map(json['pending_purchase']))
          : null,
      recommendation: rec == null
          ? null
          : AdPlanRecommendation(
              tier: AdTier.fromWire(rec['tier'] as String?),
              saving: _int(rec['saving']),
              reason: rec['reason'] == 'would_have_saved'
                  ? AdRecommendationReason.wouldHaveSaved
                  : AdRecommendationReason.start,
            ),
    );
  }

  static AdPlan plan(Map<String, dynamic> json) => AdPlan(
    tier: AdTier.fromWire(json['tier'] as String?),
    price: _int(json['price']),
    credit: _int(json['credit']),
    discountPercent: _double(json['discount_percent']) ?? 0,
    maxActiveCampaigns: _int(json['max_active_campaigns']),
    placements: [
      for (final p in (json['placements'] as List? ?? const []))
        AdPlacement.fromWire(p as String?),
    ],
    targeting: AdTargeting.fromWire(json['targeting'] as String?),
    servingWeight: _int(json['serving_weight']),
    notifiesFollowers: json['notifies_followers'] == true,
    featuredStore: json['featured_store'] == true,
  );

  static AdAudience audience(Map<String, dynamic> json) => AdAudience(
    targeted: json['type'] == 'targeted',
    governorates: [
      for (final g in (json['governorates'] as List? ?? const [])) '$g',
    ],
    followers: json['followers'] == true,
    pastBuyers: json['past_buyers'] == true,
    interested: json['interested'] == true,
    newShoppers: json['new_shoppers'] == true,
  );

  static Map<String, dynamic> audienceToJson(AdAudience a) =>
      a.isEffectivelyTargeted
      ? {
          'type': 'targeted',
          'governorates': a.governorates,
          'followers': a.followers,
          'past_buyers': a.pastBuyers,
          'interested': a.interested,
          'new_shoppers': a.newShoppers,
        }
      : {'type': 'everyone'};

  static Map<String, dynamic> draftToJson(AdCampaignDraft d) => {
    'offer_id': d.offerId,
    'placement': d.placement.wire,
    'days': d.days,
    'audience': audienceToJson(d.audience),
  };

  static AdQuote quote(Map<String, dynamic> json) {
    final price = _map(json['price']);
    final reach = _map(json['reach']);
    final hasFeedKey = json.containsKey('feed_post');
    final post = json['feed_post'] is Map ? _map(json['feed_post']) : null;
    return AdQuote(
      tier: AdTier.fromWire(json['tier'] as String?),
      allowed: json['allowed'] == true,
      refusal: AdRefusal.fromWire(json['refusal'] as String?),
      requiredTier: json['required_tier'] == null
          ? null
          : AdTier.fromWire(json['required_tier'] as String?),
      price: AdPriceBreakdown(
        days: _int(price['days']),
        dailyRate: _int(price['daily_rate']),
        listPrice: _int(price['list_price']),
        discount: _int(price['discount']),
        total: _int(price['total']),
        creditApplied: _int(price['credit_applied']),
        toPay: _int(price['to_pay']),
      ),
      reach: _int(reach['shoppers']),
      totalShoppers: _int(reach['total_shoppers']),
      shareOfVoice: _double(json['share_of_voice']) ?? 0,
      competingCampaigns: _int(json['competing_campaigns']),
      feedPost: post == null
          ? null
          : AdFeedPost(
              id: post['id'] as String,
              title: post['title'] as String?,
              imageUrl: post['image_url'] as String?,
            ),
      needsFeedPost: hasFeedKey && post == null,
    );
  }

  static AdCampaign campaign(Map<String, dynamic> json) {
    final product = _map(json['product']);
    return AdCampaign(
      id: json['id'] as String,
      placement: AdPlacement.fromWire(json['placement'] as String?),
      status: AdCampaignStatus.fromWire(json['status'] as String?),
      isLive: json['is_live'] == true,
      fee: _money(json['fee']),
      creditApplied: _money(json['credit_applied']),
      startsAt: _date(json['starts_at']) ?? DateTime.now(),
      endsAt: _date(json['ends_at']) ?? DateTime.now(),
      audience: audience(_map(json['audience'])),
      productTitle: product['title'] as String? ?? '',
      productImage: product['image_url'] as String?,
      impressions: _int(json['impressions']),
      clicks: _int(json['clicks']),
      clickThroughRate: _double(json['click_through_rate']),
      reach: _int(json['reach']),
      attributedOrders: _int(json['attributed_orders']),
      attributedRevenue: _money(json['attributed_revenue']),
    );
  }

  static AdSuggestion suggestion(Map<String, dynamic> json) {
    final product = _map(json['product']);
    final stats = _map(json['stats']);
    final suggested = _map(json['suggested']);
    return AdSuggestion(
      offerId: json['offer_id'] as String,
      productId: product['id'] as String? ?? '',
      title: product['title'] as String? ?? '',
      imageUrl: product['image_url'] as String?,
      reason: AdSuggestionReason.fromWire(json['reason'] as String?),
      views: _int(stats['views_30d']),
      favorites: _int(stats['favorites']),
      sold: _int(stats['sold_30d']),
      hasPost: json['has_post'] == true,
      placement: AdPlacement.fromWire(suggested['placement'] as String?),
      days: _int(suggested['days']).clamp(1, 30),
      targetInterested: suggested['audience'] == 'interested',
    );
  }

  static AdsOverview overview(Map<String, dynamic> json) => AdsOverview(
    activeCampaigns: _int(json['active_campaigns']),
    totalCampaigns: _int(json['total_campaigns']),
    spend: _int(json['spend']),
    creditUsed: _int(json['credit_used']),
    impressions: _int(json['impressions']),
    clicks: _int(json['clicks']),
    reach: _int(json['reach']),
    clickThroughRate: _double(json['click_through_rate']),
    attributedOrders: _int(json['attributed_orders']),
    attributedRevenue: _int(json['attributed_revenue']),
    returnOnAdSpend: _double(json['return_on_ad_spend']),
    benchmarkCtr: _double(json['benchmark_ctr']),
    insight: switch (json['insight']) {
      'above_average' => AdInsight.aboveAverage,
      'below_average' => AdInsight.belowAverage,
      'average' => AdInsight.average,
      _ => AdInsight.notEnoughData,
    },
  );

  static List<AdGovernorate> governorates(List<dynamic> rows) => [
    for (final row in rows.whereType<Map>())
      AdGovernorate(name: '${row['name']}', shoppers: _int(row['shoppers'])),
  ];

  static AdPlanPurchase purchase(Map<String, dynamic> json) => AdPlanPurchase(
    id: json['id'] as String,
    tier: AdTier.fromWire(json['tier'] as String?),
    method: json['method'] as String? ?? '',
    amount: _int(json['amount']),
    status: AdPurchaseStatus.fromWire(json['status'] as String?),
    instructions: json['instructions'] as String?,
    reference: json['reference'] as String?,
    rejectionReason: json['rejection_reason'] as String?,
  );

  static AdPaymentOptions paymentOptions(Map<String, dynamic> json) =>
      AdPaymentOptions(
        earningsBalance: _int(json['earnings_balance']),
        transferMethods: [
          for (final row in _rows(json['transfer_methods']))
            AdTransferMethod(
              method: row['method'] as String? ?? '',
              instructions: row['instructions'] as String? ?? '',
            ),
        ],
      );

  static AdPurchaseResult purchaseResult(Map<String, dynamic> json) =>
      AdPurchaseResult(
        plans: json['plans'] is Map ? plans(_map(json['plans'])) : null,
        purchase: json['purchase'] is Map
            ? purchase(_map(json['purchase']))
            : null,
      );

  static List<AdPendingPayment> pendingPayments(List<dynamic> rows) => [
    for (final row in rows.whereType<Map>())
      AdPendingPayment(
        purchase: purchase(row.cast()),
        sellerName: _map(row['seller'])['name'] as String? ?? '',
        sellerPhone: _map(row['seller'])['phone'] as String?,
      ),
  ];

  static AdAdminSummary adminSummary(Map<String, dynamic> json) =>
      AdAdminSummary(
        activePlans: {
          for (final e in _map(json['active_plans']).entries)
            AdTier.fromWire(e.key): _int(e.value),
        },
        awaitingReview: _int(json['awaiting_review']),
        revenueThisMonth: _int(json['revenue_this_month']),
      );

  static List<AdCampaign> campaigns(List<dynamic> rows) => [
    for (final row in rows.whereType<Map>()) campaign(row.cast()),
  ];

  static List<AdSuggestion> suggestions(List<dynamic> rows) => [
    for (final row in rows.whereType<Map>()) suggestion(row.cast()),
  ];
}
