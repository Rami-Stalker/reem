import 'package:reem/features/market/domain/entities/market.dart';

/// The wire, decoded.
///
/// One rule throughout: a missing field becomes an absence, never a zero. A
/// bundle whose price did not arrive must not render as free, and a wardrobe
/// piece with no purchase price must show no cost-per-wear rather than an
/// invented one — the server is careful to send `null` for what it does not
/// know, and throwing that away here would undo the care.

double? _num(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _int(Object? value, [int fallback = 0]) =>
    _num(value)?.round() ?? fallback;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];

List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value.whereType<Map<String, dynamic>>().toList(growable: false)
    : const [];

// ── Drops ───────────────────────────────────────────────────────────────

Drop dropFromJson(Map<String, dynamic> json) {
  final invite = json['invitation'];
  return Drop(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    note: json['note'] as String?,
    status: json['status'] as String? ?? 'DRAFT',
    audience: json['audience'] as String? ?? 'EVERYONE',
    startsAt: _date(json['starts_at']) ?? DateTime.now(),
    earlyAccessAt: _date(json['early_access_at']),
    endsAt: _date(json['ends_at']),
    earlyAccessOnly: json['early_access_only'] == true,
    invitation: invite is Map<String, dynamic>
        ? DropInvitation(
            affinity: _num(invite['affinity']) ?? 0,
            reasons: _rows(invite['reasons'])
                .map((row) => row['code'] as String? ?? '')
                .where((code) => code.isNotEmpty)
                .toList(growable: false),
            seen: invite['seen'] == true,
          )
        : null,
    products: _rows(json['products'])
        .map(
          (row) => DropProduct(
            productId: row['product_id'] as String? ?? '',
            title: row['title'] as String? ?? '',
            minPriceSyp: _num(row['min_price_syp']),
            imageUrl: row['image_url'] as String?,
            blurHash: row['blur_hash'] as String?,
          ),
        )
        .toList(growable: false),
  );
}

// ── Bundles ─────────────────────────────────────────────────────────────

Bundle bundleFromJson(Map<String, dynamic> json) => Bundle(
  id: json['id'] as String? ?? '',
  title: json['title'] as String? ?? '',
  occasion: json['occasion'] as String?,
  occasionLabel: json['occasion_label'] as String?,
  totalSyp: _num(json['total_syp']) ?? 0,
  sellerCount: _int(json['seller_count'], 1),
  score: _int(json['score']),
  slots: _strings(json['slots']),
  items: _rows(json['items']).map((row) {
    final seller = row['seller'];
    return BundleItem(
      productId: row['product_id'] as String? ?? '',
      offerId: row['offer_id'] as String?,
      title: row['title'] as String? ?? '',
      imageUrl: row['image_url'] as String?,
      slot: row['slot'] as String?,
      slotLabel: row['slot_label'] as String?,
      priceSyp: _num(row['price_syp']),
      sellerName: seller is Map<String, dynamic>
          ? seller['name'] as String?
          : null,
      reason: row['reason'] as String?,
    );
  }).toList(growable: false),
);

BundleAlternative bundleAlternativeFromJson(Map<String, dynamic> json) {
  final current = json['current'] as Map<String, dynamic>? ?? const {};
  final alternative = json['alternative'] as Map<String, dynamic>? ?? const {};
  return BundleAlternative(
    slotLabel: json['slot_label'] as String?,
    currentTitle: current['title'] as String? ?? '',
    currentPriceSyp: _num(current['price_syp']) ?? 0,
    alternativeTitle: alternative['title'] as String? ?? '',
    alternativeProductId: alternative['product_id'] as String? ?? '',
    alternativePriceSyp: _num(alternative['price_syp']) ?? 0,
    savingSyp: _num(json['saving_syp']) ?? 0,
  );
}

// ── Wardrobe ────────────────────────────────────────────────────────────

LifeReading lifeReadingFromJson(Map<String, dynamic> json) => LifeReading(
  rotation: Rotation.parse(json['rotation'] as String?),
  disposition: Disposition.parse(json['disposition'] as String?),
  reason: json['reason'] as String? ?? '',
  confidence: _num(json['confidence']) ?? 0,
  costPerWearSyp: _num(json['cost_per_wear_syp']),
  care: _rows(json['care'])
      .map(
        (row) => CareNote(
          code: row['code'] as String? ?? '',
          text: row['text'] as String? ?? '',
        ),
      )
      .where((note) => note.text.isNotEmpty)
      .toList(growable: false),
);

WardrobePiece wardrobePieceFromJson(Map<String, dynamic> json) {
  final listing = json['listing'];
  return WardrobePiece(
    closetItemId: json['closet_item_id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    slot: json['slot'] as String? ?? '',
    slotLabel: json['slot_label'] as String?,
    imageUrl: json['image_url'] as String?,
    blurHash: json['blur_hash'] as String?,
    wearCount: _int(json['wear_count']),
    lastWornAt: _date(json['last_worn_at']),
    purchasePriceSyp: _num(json['purchase_price_syp']),
    productId: json['product_id'] as String?,
    reading: lifeReadingFromJson(
      json['reading'] as Map<String, dynamic>? ?? const {},
    ),
    styleWith: _rows(json['style_with'])
        .map(
          (row) => (
            productId: row['product_id'] as String? ?? '',
            title: row['title'] as String? ?? '',
          ),
        )
        .toList(growable: false),
    suggestedPriceSyp: _num(json['suggested_price_syp']),
    listingId: listing is Map<String, dynamic> ? listing['id'] as String? : null,
    listingStatus: listing is Map<String, dynamic>
        ? listing['status'] as String?
        : null,
  );
}

WardrobeSummary wardrobeSummaryFromJson(Map<String, dynamic> json) =>
    WardrobeSummary(
      items: _int(json['items']),
      inRotation: _int(json['in_rotation']),
      needsAttention: _int(json['needs_attention']),
      wornShare: _int(json['worn_share']),
      medianCostPerWearSyp: _num(json['median_cost_per_wear_syp']),
    );

// ── Resale ──────────────────────────────────────────────────────────────

ResaleListing resaleListingFromJson(Map<String, dynamic> json) {
  final seller = json['seller'];
  final savingBps = _num(json['saving_bps']);
  return ResaleListing(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    note: json['note'] as String?,
    condition: json['condition'] as String? ?? 'GOOD',
    status: json['status'] as String? ?? 'DRAFT',
    priceSyp: _num(json['price_syp']) ?? 0,
    originalPriceSyp: _num(json['original_price_syp']),
    savingBps: savingBps?.round(),
    imageUrl: json['image_url'] as String?,
    blurHash: json['blur_hash'] as String?,
    slotLabel: json['slot_label'] as String?,
    colours: _strings(json['colours']),
    size: json['size'] as String?,
    brandName: json['brand_name'] as String?,
    wearCount: _num(json['wear_count'])?.round(),
    sellerName: seller is Map<String, dynamic> ? seller['name'] as String? : null,
    listedAt: _date(json['listed_at']),
  );
}

// ── Missions ────────────────────────────────────────────────────────────

Mission missionFromJson(Map<String, dynamic> json) => Mission(
  key: json['key'] as String? ?? '',
  kind: json['kind'] as String? ?? '',
  title: json['title'] as String? ?? '',
  body: json['body'] as String? ?? '',
  status: json['status'] as String? ?? 'OFFERED',
  progress: (_num(json['progress']) ?? 0).clamp(0, 1).toDouble(),
  done: _int(json['done']),
  target: _int(json['target'], 1),
  remaining: _int(json['remaining']),
  possible: _int(json['possible']),
  expiresAt: _date(json['expires_at']),
  completedAt: _date(json['completed_at']),
);

// ── Seller ──────────────────────────────────────────────────────────────

MarketOpportunity opportunityFromJson(Map<String, dynamic> json) =>
    MarketOpportunity(
      code: json['code'] as String? ?? '',
      subjectType: json['subject_type'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      strength: _int(json['strength']),
      confidence: _num(json['confidence']) ?? 0,
      headline: json['headline'] as String? ?? '',
      action: json['action'] as String? ?? '',
    );

DropCandidate dropCandidateFromJson(Map<String, dynamic> json) => DropCandidate(
  productId: json['product_id'] as String? ?? '',
  title: json['title'] as String? ?? '',
  potential: _int(json['potential']),
  demandScore: _num(json['demand_score']) ?? 0,
  stockUnits: _int(json['stock_units']),
  findings: _strings(json['findings']),
);
