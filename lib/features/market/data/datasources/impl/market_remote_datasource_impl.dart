import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/market/data/datasources/market_remote_datasource.dart';
import 'package:ohara/features/market/data/models/market_mappers.dart';
import 'package:ohara/features/market/domain/entities/market.dart';

final class MarketRemoteDataSourceImpl extends BaseRemoteDataSource
    implements MarketRemoteDataSource {
  const MarketRemoteDataSourceImpl(super.dio);

  List<Map<String, dynamic>> _rows(Map<String, dynamic> json, String key) {
    final rows = json[key];
    return rows is List
        ? rows.whereType<Map<String, dynamic>>().toList(growable: false)
        : const [];
  }

  // ── Drops ─────────────────────────────────────────────────────────────

  @override
  Future<List<Drop>> openDrops() async {
    final json = await getJson(ApiEndpoints.marketDrops);
    return _rows(json, 'drops').map(dropFromJson).toList(growable: false);
  }

  @override
  Future<void> markDropOpened(String dropId) =>
      postJson(ApiEndpoints.marketDropOpened(dropId));

  // ── Bundles ───────────────────────────────────────────────────────────

  @override
  Future<List<Bundle>> bundles({String? occasion, int? limit}) async {
    final json = await getJson(
      ApiEndpoints.marketBundles,
      query: {
        'occasion': ?occasion,
        'limit': ?limit,
      },
    );
    return _rows(json, 'bundles').map(bundleFromJson).toList(growable: false);
  }

  @override
  Future<Bundle> bundle(String bundleId) async {
    final json = await getJson(ApiEndpoints.marketBundle(bundleId));
    return bundleFromJson(json['bundle'] as Map<String, dynamic>? ?? const {});
  }

  @override
  Future<List<BundleAlternative>> bundleAlternatives(String bundleId) async {
    final json = await getJson(ApiEndpoints.marketBundleAlternatives(bundleId));
    return _rows(json, 'alternatives')
        .map(bundleAlternativeFromJson)
        .toList(growable: false);
  }

  @override
  Future<
    ({List<({String offerId, int quantity})> lines, List<String> unavailable})
  >
  bundleCheckoutLines(String bundleId) async {
    final json = await getJson(
      ApiEndpoints.marketBundleCheckoutLines(bundleId),
    );
    final unavailable = json['unavailable_product_ids'];
    return (
      lines: _rows(json, 'lines')
          .map(
            (row) => (
              offerId: row['offer_id'] as String? ?? '',
              quantity: (row['quantity'] as num?)?.round() ?? 1,
            ),
          )
          .where((line) => line.offerId.isNotEmpty)
          .toList(growable: false),
      unavailable: unavailable is List
          ? unavailable.whereType<String>().toList(growable: false)
          : const <String>[],
    );
  }

  // ── Wardrobe ──────────────────────────────────────────────────────────

  @override
  Future<WardrobeSummary> wardrobeSummary() async =>
      wardrobeSummaryFromJson(await getJson(ApiEndpoints.marketWardrobeSummary));

  @override
  Future<List<WardrobePiece>> wardrobeAttention({int? limit}) async {
    final json = await getJson(
      ApiEndpoints.marketWardrobeAttention,
      query: {'limit': ?limit},
    );
    return _rows(json, 'items')
        .map(wardrobePieceFromJson)
        .toList(growable: false);
  }

  @override
  Future<WardrobePiece> wardrobeItem(String closetItemId) async {
    final json = await getJson(ApiEndpoints.marketWardrobeItem(closetItemId));
    return wardrobePieceFromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  // ── Resale ────────────────────────────────────────────────────────────

  @override
  Future<ResaleListing> draftListing(
    String closetItemId, {
    required String condition,
    double? priceSyp,
    String? title,
    String? note,
  }) async {
    final json = await postJson(
      ApiEndpoints.marketWardrobeResale(closetItemId),
      body: {
        'condition': condition,
        if (priceSyp != null) 'price_syp': priceSyp.round(),
        if (title != null && title.isNotEmpty) 'title': title,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return resaleListingFromJson(
      json['listing'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  Future<ResaleListing> setListingStatus(String listingId, String status) async {
    final json = await patchJson(
      ApiEndpoints.marketResaleStatus(listingId),
      body: {'status': status},
    );
    return resaleListingFromJson(
      json['listing'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  Future<List<ResaleListing>> myListings() async {
    final json = await getJson(ApiEndpoints.marketResaleMine);
    return _rows(json, 'listings')
        .map(resaleListingFromJson)
        .toList(growable: false);
  }

  @override
  Future<List<ResaleListing>> resaleMarket({String? slot, int? limit}) async {
    final json = await getJson(
      ApiEndpoints.marketResale,
      query: {
        'slot': ?slot,
        'limit': ?limit,
      },
    );
    return _rows(json, 'listings')
        .map(resaleListingFromJson)
        .toList(growable: false);
  }

  // ── Missions ──────────────────────────────────────────────────────────

  @override
  Future<List<Mission>> missions() async {
    final json = await getJson(ApiEndpoints.marketMissions);
    return _rows(json, 'missions').map(missionFromJson).toList(growable: false);
  }

  @override
  Future<void> declineMission(String key) =>
      postJson(ApiEndpoints.marketMissionDecline(key));

  // ── Seller ────────────────────────────────────────────────────────────

  @override
  Future<List<MarketOpportunity>> sellerOpportunities({int? limit}) async {
    final json = await getJson(
      ApiEndpoints.sellerMarketOpportunities,
      query: {'limit': ?limit},
    );
    return _rows(json, 'opportunities')
        .map(opportunityFromJson)
        .toList(growable: false);
  }

  @override
  Future<List<DropCandidate>> dropCandidates({int? limit}) async {
    final json = await getJson(
      ApiEndpoints.sellerMarketDropCandidates,
      query: {'limit': ?limit},
    );
    return _rows(json, 'candidates')
        .map(dropCandidateFromJson)
        .toList(growable: false);
  }

  @override
  Future<List<Drop>> sellerDrops() async {
    final json = await getJson(ApiEndpoints.sellerMarketDrops);
    return _rows(json, 'drops').map(dropFromJson).toList(growable: false);
  }

  @override
  Future<Drop> createDrop({
    required String title,
    required String audience,
    required DateTime startsAt,
    required List<String> productIds,
    DateTime? earlyAccessAt,
    DateTime? endsAt,
    String? note,
  }) async {
    final json = await postJson(
      ApiEndpoints.sellerMarketDrops,
      body: {
        'title': title,
        'audience': audience,
        'starts_at': startsAt.toUtc().toIso8601String(),
        if (earlyAccessAt != null)
          'early_access_at': earlyAccessAt.toUtc().toIso8601String(),
        if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
        if (note != null && note.isNotEmpty) 'note': note,
        'product_ids': productIds,
      },
    );
    return dropFromJson(json['drop'] as Map<String, dynamic>? ?? const {});
  }

  @override
  Future<int> buildDropAudience(String dropId, {int? limit}) async {
    final json = await postJson(
      ApiEndpoints.sellerMarketDropAudience(dropId),
      body: {'limit': ?limit},
    );
    return (json['invited'] as num?)?.round() ?? 0;
  }

  @override
  Future<Drop> setDropStatus(String dropId, String status) async {
    final json = await patchJson(
      ApiEndpoints.sellerMarketDropStatus(dropId),
      body: {'status': status},
    );
    return dropFromJson(json['drop'] as Map<String, dynamic>? ?? const {});
  }
}
