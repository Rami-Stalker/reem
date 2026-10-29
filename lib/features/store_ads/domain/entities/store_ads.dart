/// «إعلانات المتاجر» — a boutique's plan, the campaigns it buys, and what
/// they did.
///
/// Money is whole Syrian pounds throughout: the API prices advertising in SYP
/// and rounds every figure a seller sees to the lira, so an `int` is exact.
library;

/// A boutique's advertising plan, lowest first.
enum AdTier {
  free,
  silver,
  gold,
  diamond;

  static AdTier fromWire(String? value) => AdTier.values.firstWhere(
    (tier) => tier.name == value?.toLowerCase(),
    orElse: () => AdTier.free,
  );

  String get wire => name;

  bool operator >(AdTier other) => index > other.index;
  bool get isPaid => this != AdTier.free;
}

/// Where a campaign appears.
enum AdPlacement {
  search,
  category,
  feedTop,
  homeSpotlight;

  static AdPlacement fromWire(String? value) => switch (value?.toLowerCase()) {
    'category' => AdPlacement.category,
    'feed_top' => AdPlacement.feedTop,
    'home_spotlight' => AdPlacement.homeSpotlight,
    _ => AdPlacement.search,
  };

  String get wire => switch (this) {
    AdPlacement.search => 'search',
    AdPlacement.category => 'category',
    AdPlacement.feedTop => 'feed_top',
    AdPlacement.homeSpotlight => 'home_spotlight',
  };

  /// The lowest plan that may buy this placement for everyone.
  AdTier get minimumTier => switch (this) {
    AdPlacement.search || AdPlacement.category => AdTier.free,
    AdPlacement.feedTop => AdTier.silver,
    AdPlacement.homeSpotlight => AdTier.gold,
  };
}

/// How far a plan may narrow its audience.
enum AdTargeting {
  none,
  location,
  full;

  static AdTargeting fromWire(String? value) => AdTargeting.values.firstWhere(
    (t) => t.name == value,
    orElse: () => AdTargeting.none,
  );
}

class AdPlan {
  const AdPlan({
    required this.tier,
    required this.price,
    required this.credit,
    required this.discountPercent,
    required this.maxActiveCampaigns,
    required this.placements,
    required this.targeting,
    required this.servingWeight,
    required this.notifiesFollowers,
    required this.featuredStore,
  });

  final AdTier tier;
  final int price;
  final int credit;
  final double discountPercent;
  final int maxActiveCampaigns;
  final List<AdPlacement> placements;
  final AdTargeting targeting;

  /// How many times more often than a free boutique her adverts are picked,
  /// for the same daily price.
  final int servingWeight;
  final bool notifiesFollowers;
  final bool featuredStore;

  /// Credit worth more than the price — the plan pays for itself.
  int get bonusCredit => credit - price;
}

class AdCurrentPlan {
  const AdCurrentPlan({
    this.tier = AdTier.free,
    this.endsAt,
    this.creditGranted = 0,
    this.creditUsed = 0,
    this.creditRemaining = 0,
    this.activeCampaigns = 0,
    this.maxActiveCampaigns = 1,
  });

  final AdTier tier;
  final DateTime? endsAt;
  final int creditGranted;
  final int creditUsed;
  final int creditRemaining;
  final int activeCampaigns;
  final int maxActiveCampaigns;

  double get creditProgress =>
      creditGranted <= 0 ? 0 : (creditRemaining / creditGranted).clamp(0, 1);

  int? daysLeft(DateTime now) =>
      endsAt == null ? null : endsAt!.difference(now).inHours ~/ 24;
}

enum AdRecommendationReason { wouldHaveSaved, start }

class AdPlanRecommendation {
  const AdPlanRecommendation({
    required this.tier,
    required this.saving,
    required this.reason,
  });

  final AdTier tier;
  final int saving;
  final AdRecommendationReason reason;
}

class AdPlansView {
  const AdPlansView({
    this.current = const AdCurrentPlan(),
    this.plans = const [],
    this.queuedTier,
    this.queuedStartsAt,
    this.spendLast30Days = 0,
    this.recommendation,
  });

  final AdCurrentPlan current;
  final List<AdPlan> plans;
  final AdTier? queuedTier;
  final DateTime? queuedStartsAt;
  final int spendLast30Days;
  final AdPlanRecommendation? recommendation;

  AdPlan? planFor(AdTier tier) {
    for (final plan in plans) {
      if (plan.tier == tier) return plan;
    }
    return null;
  }

  AdPlan? get currentPlan => planFor(current.tier);

  bool allows(AdPlacement placement) =>
      currentPlan?.placements.contains(placement) ??
      placement.minimumTier == AdTier.free;
}

/// Who a campaign is for.
class AdAudience {
  const AdAudience({
    this.targeted = false,
    this.governorates = const [],
    this.followers = false,
    this.pastBuyers = false,
    this.interested = false,
    this.newShoppers = false,
  });

  static const everyone = AdAudience();

  final bool targeted;
  final List<String> governorates;
  final bool followers;
  final bool pastBuyers;
  final bool interested;
  final bool newShoppers;

  bool get hasInterestGroups =>
      followers || pastBuyers || interested || newShoppers;

  /// A targeted audience that names nobody is everyone.
  bool get isEffectivelyTargeted =>
      targeted && (governorates.isNotEmpty || hasInterestGroups);

  /// The plan this audience needs, given the placement's own minimum.
  AdTier requiredTier(AdPlacement placement) {
    var tier = placement.minimumTier;
    if (isEffectivelyTargeted) {
      final needed = hasInterestGroups ? AdTier.gold : AdTier.silver;
      if (needed > tier) tier = needed;
    }
    return tier;
  }

  AdAudience copyWith({
    bool? targeted,
    List<String>? governorates,
    bool? followers,
    bool? pastBuyers,
    bool? interested,
    bool? newShoppers,
  }) => AdAudience(
    targeted: targeted ?? this.targeted,
    governorates: governorates ?? this.governorates,
    followers: followers ?? this.followers,
    pastBuyers: pastBuyers ?? this.pastBuyers,
    interested: interested ?? this.interested,
    newShoppers: newShoppers ?? this.newShoppers,
  );
}

/// What she is about to buy.
class AdCampaignDraft {
  const AdCampaignDraft({
    required this.offerId,
    this.placement = AdPlacement.search,
    this.days = 7,
    this.audience = AdAudience.everyone,
  });

  final String offerId;
  final AdPlacement placement;
  final int days;
  final AdAudience audience;

  AdCampaignDraft copyWith({
    String? offerId,
    AdPlacement? placement,
    int? days,
    AdAudience? audience,
  }) => AdCampaignDraft(
    offerId: offerId ?? this.offerId,
    placement: placement ?? this.placement,
    days: days ?? this.days,
    audience: audience ?? this.audience,
  );
}

class AdPriceBreakdown {
  const AdPriceBreakdown({
    required this.days,
    required this.dailyRate,
    required this.listPrice,
    required this.discount,
    required this.total,
    required this.creditApplied,
    required this.toPay,
  });

  final int days;
  final int dailyRate;
  final int listPrice;
  final int discount;
  final int total;
  final int creditApplied;
  final int toPay;
}

/// Why a plan cannot buy a campaign — an offer to upgrade, not an error.
enum AdRefusal {
  placementLocked,
  targetingLocked,
  interestTargetingLocked;

  static AdRefusal? fromWire(String? value) => switch (value) {
    'placement_locked' => AdRefusal.placementLocked,
    'targeting_locked' => AdRefusal.targetingLocked,
    'interest_targeting_locked' => AdRefusal.interestTargetingLocked,
    _ => null,
  };
}

class AdFeedPost {
  const AdFeedPost({required this.id, this.title, this.imageUrl});

  final String id;
  final String? title;
  final String? imageUrl;
}

class AdQuote {
  const AdQuote({
    required this.tier,
    required this.allowed,
    required this.price,
    required this.reach,
    required this.totalShoppers,
    required this.shareOfVoice,
    required this.competingCampaigns,
    this.refusal,
    this.requiredTier,
    this.feedPost,
    this.needsFeedPost = false,
  });

  /// Her plan now — the one whose discount the price carries.
  final AdTier tier;
  final bool allowed;
  final AdRefusal? refusal;
  final AdTier? requiredTier;
  final AdPriceBreakdown price;

  /// Shoppers the audience holds, out of every shopper on the platform.
  final int reach;
  final int totalShoppers;

  /// Her expected share of the slot against what is live today, 0–1.
  final double shareOfVoice;
  final int competingCampaigns;

  /// FEED_TOP: the post that would be pinned.
  final AdFeedPost? feedPost;

  /// FEED_TOP with no public post of hers showing the product.
  final bool needsFeedPost;

  bool get canLaunch => allowed && !needsFeedPost;

  double get reachShare => totalShoppers <= 0 ? 0 : reach / totalShoppers;
}

enum AdCampaignStatus {
  pending,
  active,
  paused,
  ended,
  unpaid;

  static AdCampaignStatus fromWire(String? value) =>
      AdCampaignStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => AdCampaignStatus.pending,
      );

  String get wire => name;
}

class AdCampaign {
  const AdCampaign({
    required this.id,
    required this.placement,
    required this.status,
    required this.isLive,
    required this.fee,
    required this.creditApplied,
    required this.startsAt,
    required this.endsAt,
    required this.audience,
    required this.productTitle,
    this.productImage,
    this.impressions = 0,
    this.clicks = 0,
    this.clickThroughRate,
    this.reach = 0,
    this.attributedOrders = 0,
    this.attributedRevenue = 0,
  });

  final String id;
  final AdPlacement placement;
  final AdCampaignStatus status;
  final bool isLive;
  final int fee;
  final int creditApplied;
  final DateTime startsAt;
  final DateTime endsAt;
  final AdAudience audience;
  final String productTitle;
  final String? productImage;
  final int impressions;
  final int clicks;
  final double? clickThroughRate;
  final int reach;
  final int attributedOrders;
  final int attributedRevenue;

  bool get hasEnded => DateTime.now().isAfter(endsAt);

  bool get canPause => status == AdCampaignStatus.active && !hasEnded;

  bool get canResume =>
      (status == AdCampaignStatus.paused ||
          status == AdCampaignStatus.pending ||
          status == AdCampaignStatus.unpaid) &&
      !hasEnded;

  /// 0–1 through its window.
  double progress(DateTime now) {
    final total = endsAt.difference(startsAt).inSeconds;
    if (total <= 0) return 1;
    return (now.difference(startsAt).inSeconds / total).clamp(0, 1);
  }
}

enum AdSuggestionReason {
  lovedNotBought,
  bestSeller,
  hiddenGem,
  freshPick;

  static AdSuggestionReason fromWire(String? value) => switch (value) {
    'loved_not_bought' => AdSuggestionReason.lovedNotBought,
    'best_seller' => AdSuggestionReason.bestSeller,
    'hidden_gem' => AdSuggestionReason.hiddenGem,
    _ => AdSuggestionReason.freshPick,
  };
}

class AdSuggestion {
  const AdSuggestion({
    required this.offerId,
    required this.productId,
    required this.title,
    required this.reason,
    required this.placement,
    required this.days,
    required this.targetInterested,
    this.imageUrl,
    this.views = 0,
    this.favorites = 0,
    this.sold = 0,
    this.hasPost = false,
  });

  final String offerId;
  final String productId;
  final String title;
  final String? imageUrl;
  final AdSuggestionReason reason;
  final int views;
  final int favorites;
  final int sold;
  final bool hasPost;
  final AdPlacement placement;
  final int days;
  final bool targetInterested;

  AdCampaignDraft toDraft() => AdCampaignDraft(
    offerId: offerId,
    placement: placement,
    days: days,
    audience: targetInterested
        ? const AdAudience(targeted: true, interested: true)
        : AdAudience.everyone,
  );
}

enum AdInsight { aboveAverage, average, belowAverage, notEnoughData }

class AdsOverview {
  const AdsOverview({
    this.activeCampaigns = 0,
    this.totalCampaigns = 0,
    this.spend = 0,
    this.creditUsed = 0,
    this.impressions = 0,
    this.clicks = 0,
    this.reach = 0,
    this.clickThroughRate,
    this.attributedOrders = 0,
    this.attributedRevenue = 0,
    this.returnOnAdSpend,
    this.benchmarkCtr,
    this.insight = AdInsight.notEnoughData,
  });

  final int activeCampaigns;
  final int totalCampaigns;
  final int spend;
  final int creditUsed;
  final int impressions;
  final int clicks;
  final int reach;
  final double? clickThroughRate;
  final int attributedOrders;
  final int attributedRevenue;
  final double? returnOnAdSpend;
  final double? benchmarkCtr;
  final AdInsight insight;
}

class AdGovernorate {
  const AdGovernorate({required this.name, required this.shoppers});

  final String name;
  final int shoppers;
}

/// Why the server refused, in a form the screen can word.
enum AdFailureKind {
  insufficientBalance,
  campaignLimit,
  feedPostRequired,
  planLocked,
  other,
}
