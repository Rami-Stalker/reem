import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/market/domain/entities/market.dart';

/// The market layer, wrapped in `Result`.
///
/// Same discipline as everywhere else in Ohara: the data source throws, the
/// repository turns that into a value, and no screen ever sees an exception it
/// did not ask for.
abstract interface class MarketRepository {
  Future<Result<List<Drop>>> openDrops();
  Future<Result<void>> markDropOpened(String dropId);

  Future<Result<List<Bundle>>> bundles({String? occasion, int? limit});
  Future<Result<Bundle>> bundle(String bundleId);
  Future<Result<List<BundleAlternative>>> bundleAlternatives(String bundleId);
  Future<
    Result<
      ({List<({String offerId, int quantity})> lines, List<String> unavailable})
    >
  >
  bundleCheckoutLines(String bundleId);

  Future<Result<WardrobeSummary>> wardrobeSummary();
  Future<Result<List<WardrobePiece>>> wardrobeAttention({int? limit});
  Future<Result<WardrobePiece>> wardrobeItem(String closetItemId);

  Future<Result<ResaleListing>> draftListing(
    String closetItemId, {
    required String condition,
    double? priceSyp,
    String? title,
    String? note,
  });
  Future<Result<ResaleListing>> setListingStatus(
    String listingId,
    String status,
  );
  Future<Result<List<ResaleListing>>> myListings();
  Future<Result<List<ResaleListing>>> resaleMarket({String? slot, int? limit});

  Future<Result<List<Mission>>> missions();
  Future<Result<void>> declineMission(String key);

  Future<Result<List<MarketOpportunity>>> sellerOpportunities({int? limit});
  Future<Result<List<DropCandidate>>> dropCandidates({int? limit});
  Future<Result<List<Drop>>> sellerDrops();
  Future<Result<Drop>> createDrop({
    required String title,
    required String audience,
    required DateTime startsAt,
    required List<String> productIds,
    DateTime? earlyAccessAt,
    DateTime? endsAt,
    String? note,
  });
  Future<Result<int>> buildDropAudience(String dropId, {int? limit});
  Future<Result<Drop>> setDropStatus(String dropId, String status);
}
