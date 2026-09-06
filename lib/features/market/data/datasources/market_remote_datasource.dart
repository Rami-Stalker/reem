import 'package:reem/features/market/domain/entities/market.dart';

/// Everything Reem Market Evolution exposes to the client.
///
/// One interface for six systems, because from the client's side they are one
/// surface: things to look at, things she owns, and things worth doing. The
/// separation that matters is on the server, where each has its own kernel.
abstract interface class MarketRemoteDataSource {
  // ── Drops ─────────────────────────────────────────────────────────────
  Future<List<Drop>> openDrops();

  /// She looked. Recorded once, which is what makes the seller's precision
  /// figure a real rate rather than an impression count.
  Future<void> markDropOpened(String dropId);

  // ── Bundles ───────────────────────────────────────────────────────────
  Future<List<Bundle>> bundles({String? occasion, int? limit});
  Future<Bundle> bundle(String bundleId);
  Future<List<BundleAlternative>> bundleAlternatives(String bundleId);

  /// The offer lines this bundle would put through checkout, plus anything in
  /// it that has since gone out of stock.
  Future<({List<({String offerId, int quantity})> lines, List<String> unavailable})>
  bundleCheckoutLines(String bundleId);

  // ── Wardrobe ──────────────────────────────────────────────────────────
  Future<WardrobeSummary> wardrobeSummary();
  Future<List<WardrobePiece>> wardrobeAttention({int? limit});
  Future<WardrobePiece> wardrobeItem(String closetItemId);

  // ── Resale ────────────────────────────────────────────────────────────
  Future<ResaleListing> draftListing(
    String closetItemId, {
    required String condition,
    double? priceSyp,
    String? title,
    String? note,
  });
  Future<ResaleListing> setListingStatus(String listingId, String status);
  Future<List<ResaleListing>> myListings();
  Future<List<ResaleListing>> resaleMarket({String? slot, int? limit});

  // ── Missions ──────────────────────────────────────────────────────────
  Future<List<Mission>> missions();
  Future<void> declineMission(String key);

  // ── Seller ────────────────────────────────────────────────────────────
  Future<List<MarketOpportunity>> sellerOpportunities({int? limit});
  Future<List<DropCandidate>> dropCandidates({int? limit});
  Future<List<Drop>> sellerDrops();
  Future<Drop> createDrop({
    required String title,
    required String audience,
    required DateTime startsAt,
    required List<String> productIds,
    DateTime? earlyAccessAt,
    DateTime? endsAt,
    String? note,
  });
  Future<int> buildDropAudience(String dropId, {int? limit});
  Future<Drop> setDropStatus(String dropId, String status);
}
