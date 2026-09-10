import 'package:meta/meta.dart';

/// The shapes Reem Market Evolution puts on a screen.
///
/// Deliberately plain. Every judgement behind these values was made on the
/// server beside the arithmetic that produced it — which slot a bundle piece
/// fills, why a woman was invited to a drop, whether a garment should be sold
/// or restyled — so nothing here re-decides anything. A widget that started
/// computing its own verdict would be a second opinion nobody could audit.

// ── Drops ───────────────────────────────────────────────────────────────

@immutable
class DropInvitation {
  const DropInvitation({
    required this.affinity,
    required this.reasons,
    required this.seen,
  });

  /// 0-100 — how strongly the graph matched her to this launch.
  final double affinity;

  /// The reason codes behind that number, strongest first.
  final List<String> reasons;
  final bool seen;

  /// Her reason, in her language.
  ///
  /// Rendered from the code rather than sent as prose because the codes are
  /// the contract and a sentence is a presentation choice — the same code
  /// reads differently on a card and in a notification.
  String get headline => switch (reasons.isEmpty ? '' : reasons.first) {
    'OPEN_NEED' => 'لأنو ناقصك شي من هالنوع',
    'SEARCHED_FOR' => 'لأنك كنتي عم تدوّري على شي متلو',
    'OCCASION_MATCH' => 'لأنو بيناسب المناسبة اللي عم تحضّري إلها',
    'TASTE_MATCH' => 'لأنو قريب من ذوقك',
    'SELLER_CUSTOMER' => 'من محل بتشتري منّو',
    _ => '',
  };
}

@immutable
class DropProduct {
  const DropProduct({
    required this.productId,
    required this.title,
    this.minPriceSyp,
    this.imageUrl,
    this.blurHash,
  });

  final String productId;
  final String title;
  final double? minPriceSyp;
  final String? imageUrl;
  final String? blurHash;
}

@immutable
class Drop {
  const Drop({
    required this.id,
    required this.title,
    required this.status,
    required this.audience,
    required this.startsAt,
    required this.products,
    this.note,
    this.earlyAccessAt,
    this.endsAt,
    this.earlyAccessOnly = false,
    this.invitation,
  });

  final String id;
  final String title;
  final String? note;
  final String status;
  final String audience;
  final DateTime startsAt;
  final DateTime? earlyAccessAt;
  final DateTime? endsAt;

  /// She is seeing it before it opens to everybody.
  final bool earlyAccessOnly;

  final DropInvitation? invitation;
  final List<DropProduct> products;

  bool get isLive => status == 'LIVE';

  double? get totalFromSyp {
    final prices = products
        .map((product) => product.minPriceSyp)
        .whereType<double>()
        .toList();
    if (prices.isEmpty) return null;
    return prices.reduce((a, b) => a < b ? a : b);
  }
}

// ── Bundles ─────────────────────────────────────────────────────────────

@immutable
class BundleItem {
  const BundleItem({
    required this.productId,
    required this.title,
    this.offerId,
    this.imageUrl,
    this.slot,
    this.slotLabel,
    this.priceSyp,
    this.sellerName,
    this.reason,
  });

  final String productId;
  final String? offerId;
  final String title;
  final String? imageUrl;
  final String? slot;
  final String? slotLabel;
  final double? priceSyp;
  final String? sellerName;

  /// Why this piece is in the set. Never rendered as optional decoration —
  /// a bundle whose members cannot explain themselves is a gift basket.
  final String? reason;
}

@immutable
class BundleAlternative {
  const BundleAlternative({
    required this.slotLabel,
    required this.currentTitle,
    required this.currentPriceSyp,
    required this.alternativeTitle,
    required this.alternativeProductId,
    required this.alternativePriceSyp,
    required this.savingSyp,
  });

  final String? slotLabel;
  final String currentTitle;
  final double currentPriceSyp;
  final String alternativeTitle;
  final String alternativeProductId;
  final double alternativePriceSyp;
  final double savingSyp;
}

@immutable
class Bundle {
  const Bundle({
    required this.id,
    required this.title,
    required this.totalSyp,
    required this.sellerCount,
    required this.score,
    required this.slots,
    required this.items,
    this.occasion,
    this.occasionLabel,
  });

  final String id;
  final String title;
  final String? occasion;
  final String? occasionLabel;
  final double totalSyp;

  /// How many different shops it draws on — the number that makes a bundle a
  /// marketplace feature rather than one seller's upsell.
  final int sellerCount;
  final int score;
  final List<String> slots;
  final List<BundleItem> items;

  bool get crossesShops => sellerCount > 1;
}

// ── Wardrobe life cycle ─────────────────────────────────────────────────

enum Rotation {
  active,
  slowing,
  dormant,
  unworn;

  static Rotation parse(String? raw) => switch (raw) {
    'SLOWING' => Rotation.slowing,
    'DORMANT' => Rotation.dormant,
    'UNWORN' => Rotation.unworn,
    _ => Rotation.active,
  };

  String get ar => switch (this) {
    Rotation.active => 'قيد الاستعمال',
    Rotation.slowing => 'قلّ لبسها',
    Rotation.dormant => 'واقفة بالخزانة',
    Rotation.unworn => 'ما انلبست ولا مرة',
  };
}

enum Disposition {
  keep,
  restyle,
  resell,
  donate;

  static Disposition parse(String? raw) => switch (raw) {
    'RESTYLE' => Disposition.restyle,
    'RESELL' => Disposition.resell,
    'DONATE' => Disposition.donate,
    _ => Disposition.keep,
  };

  String get ar => switch (this) {
    Disposition.keep => '',
    Disposition.restyle => 'جرّبيها بشكل تاني',
    Disposition.resell => 'تنباع',
    Disposition.donate => 'تنعطى',
  };
}

@immutable
class CareNote {
  const CareNote({required this.code, required this.text});
  final String code;
  final String text;
}

@immutable
class LifeReading {
  const LifeReading({
    required this.rotation,
    required this.disposition,
    required this.reason,
    required this.confidence,
    required this.care,
    this.costPerWearSyp,
  });

  final Rotation rotation;
  final Disposition disposition;

  /// Empty when the advice is to leave her alone — and silence is rendered as
  /// silence, not as a card saying "no action needed".
  final String reason;
  final double confidence;
  final double? costPerWearSyp;
  final List<CareNote> care;

  bool get needsAttention => disposition != Disposition.keep;
}

@immutable
class WardrobePiece {
  const WardrobePiece({
    required this.closetItemId,
    required this.title,
    required this.slot,
    required this.reading,
    required this.wearCount,
    this.slotLabel,
    this.imageUrl,
    this.blurHash,
    this.lastWornAt,
    this.purchasePriceSyp,
    this.productId,
    this.styleWith = const [],
    this.suggestedPriceSyp,
    this.listingId,
    this.listingStatus,
  });

  final String closetItemId;
  final String title;
  final String slot;
  final String? slotLabel;
  final String? imageUrl;
  final String? blurHash;
  final int wearCount;
  final DateTime? lastWornAt;
  final double? purchasePriceSyp;
  final String? productId;
  final LifeReading reading;

  /// What the graph says goes with it — shown only where the advice is to
  /// restyle, because a styling note beside "sell this" is a mixed message.
  final List<({String productId, String title})> styleWith;
  final double? suggestedPriceSyp;
  final String? listingId;
  final String? listingStatus;
}

@immutable
class WardrobeSummary {
  const WardrobeSummary({
    required this.items,
    required this.inRotation,
    required this.needsAttention,
    required this.wornShare,
    this.medianCostPerWearSyp,
  });

  final int items;
  final int inRotation;
  final int needsAttention;
  final int wornShare;
  final double? medianCostPerWearSyp;

  bool get isEmpty => items == 0;
}

// ── Resale ──────────────────────────────────────────────────────────────

@immutable
class ResaleListing {
  const ResaleListing({
    required this.id,
    required this.title,
    required this.condition,
    required this.status,
    required this.priceSyp,
    this.note,
    this.originalPriceSyp,
    this.savingBps,
    this.imageUrl,
    this.blurHash,
    this.slotLabel,
    this.colours = const [],
    this.size,
    this.brandName,
    this.wearCount,
    this.sellerName,
    this.listedAt,
  });

  final String id;
  final String title;
  final String? note;
  final String condition;
  final String status;
  final double priceSyp;
  final double? originalPriceSyp;
  final int? savingBps;
  final String? imageUrl;
  final String? blurHash;
  final String? slotLabel;
  final List<String> colours;
  final String? size;
  final String? brandName;

  /// How many times it was worn. The fact a second-hand marketplace normally
  /// hides and the one a buyer most wants.
  final int? wearCount;
  final String? sellerName;
  final DateTime? listedAt;

  int? get savingPercent => savingBps == null ? null : (savingBps! / 100).round();

  String get conditionAr => switch (condition) {
    'NEW_WITH_TAGS' => 'جديدة بالتيكيت',
    'EXCELLENT' => 'ممتازة',
    'GOOD' => 'منيحة',
    'FAIR' => 'مستعملة',
    _ => condition,
  };
}

// ── Missions ────────────────────────────────────────────────────────────

@immutable
class Mission {
  const Mission({
    required this.key,
    required this.kind,
    required this.title,
    required this.body,
    required this.status,
    required this.progress,
    required this.done,
    required this.target,
    required this.remaining,
    required this.possible,
    this.expiresAt,
    this.completedAt,
  });

  final String key;
  final String kind;
  final String title;
  final String body;
  final String status;

  /// 0-1, recomputed on the server from evidence it did not write.
  final double progress;

  /// What she has done *since being asked* — not her lifetime total.
  final int done;
  final int target;
  final int remaining;
  final int possible;
  final DateTime? expiresAt;
  final DateTime? completedAt;

  bool get isComplete => status == 'COMPLETED';
}

// ── Seller market ───────────────────────────────────────────────────────

@immutable
class MarketOpportunity {
  const MarketOpportunity({
    required this.code,
    required this.subjectType,
    required this.subjectId,
    required this.subjectName,
    required this.strength,
    required this.confidence,
    required this.headline,
    required this.action,
  });

  final String code;
  final String subjectType;
  final String subjectId;
  final String subjectName;
  final int strength;
  final double confidence;
  final String headline;

  /// What to do about it. Never empty — the server drops any finding it has
  /// no action for, because an opportunity you cannot act on is a statistic.
  final String action;
}

@immutable
class DropCandidate {
  const DropCandidate({
    required this.productId,
    required this.title,
    required this.potential,
    required this.demandScore,
    required this.stockUnits,
    required this.findings,
  });

  final String productId;
  final String title;

  /// 0-100 — how much of an event this product is worth making.
  final int potential;
  final double demandScore;
  final int stockUnits;
  final List<String> findings;
}
