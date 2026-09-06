import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/market/data/datasources/market_remote_datasource.dart';
import 'package:reem/features/market/domain/entities/market.dart';
import 'package:reem/features/market/domain/repositories/market_repository.dart';

class MarketRepositoryImpl with RepositoryHandler implements MarketRepository {
  const MarketRepositoryImpl(this.remote);

  final MarketRemoteDataSource remote;

  @override
  Future<Result<List<Drop>>> openDrops() =>
      guard(remote.openDrops, operation: 'open drops');

  @override
  Future<Result<void>> markDropOpened(String dropId) =>
      guard(() => remote.markDropOpened(dropId), operation: 'drop opened');

  @override
  Future<Result<List<Bundle>>> bundles({String? occasion, int? limit}) => guard(
    () => remote.bundles(occasion: occasion, limit: limit),
    operation: 'bundles',
  );

  @override
  Future<Result<Bundle>> bundle(String bundleId) =>
      guard(() => remote.bundle(bundleId), operation: 'bundle');

  @override
  Future<Result<List<BundleAlternative>>> bundleAlternatives(String bundleId) =>
      guard(
        () => remote.bundleAlternatives(bundleId),
        operation: 'bundle alternatives',
      );

  @override
  Future<
    Result<
      ({List<({String offerId, int quantity})> lines, List<String> unavailable})
    >
  >
  bundleCheckoutLines(String bundleId) => guard(
    () => remote.bundleCheckoutLines(bundleId),
    operation: 'bundle checkout lines',
  );

  @override
  Future<Result<WardrobeSummary>> wardrobeSummary() =>
      guard(remote.wardrobeSummary, operation: 'wardrobe summary');

  @override
  Future<Result<List<WardrobePiece>>> wardrobeAttention({int? limit}) => guard(
    () => remote.wardrobeAttention(limit: limit),
    operation: 'wardrobe attention',
  );

  @override
  Future<Result<WardrobePiece>> wardrobeItem(String closetItemId) =>
      guard(() => remote.wardrobeItem(closetItemId), operation: 'wardrobe item');

  @override
  Future<Result<ResaleListing>> draftListing(
    String closetItemId, {
    required String condition,
    double? priceSyp,
    String? title,
    String? note,
  }) => guard(
    () => remote.draftListing(
      closetItemId,
      condition: condition,
      priceSyp: priceSyp,
      title: title,
      note: note,
    ),
    operation: 'draft resale listing',
  );

  @override
  Future<Result<ResaleListing>> setListingStatus(
    String listingId,
    String status,
  ) => guard(
    () => remote.setListingStatus(listingId, status),
    operation: 'resale listing status',
  );

  @override
  Future<Result<List<ResaleListing>>> myListings() =>
      guard(remote.myListings, operation: 'my resale listings');

  @override
  Future<Result<List<ResaleListing>>> resaleMarket({String? slot, int? limit}) =>
      guard(
        () => remote.resaleMarket(slot: slot, limit: limit),
        operation: 'resale market',
      );

  @override
  Future<Result<List<Mission>>> missions() =>
      guard(remote.missions, operation: 'missions');

  @override
  Future<Result<void>> declineMission(String key) =>
      guard(() => remote.declineMission(key), operation: 'decline mission');

  @override
  Future<Result<List<MarketOpportunity>>> sellerOpportunities({int? limit}) =>
      guard(
        () => remote.sellerOpportunities(limit: limit),
        operation: 'seller market opportunities',
      );

  @override
  Future<Result<List<DropCandidate>>> dropCandidates({int? limit}) => guard(
    () => remote.dropCandidates(limit: limit),
    operation: 'drop candidates',
  );

  @override
  Future<Result<List<Drop>>> sellerDrops() =>
      guard(remote.sellerDrops, operation: 'seller drops');

  @override
  Future<Result<Drop>> createDrop({
    required String title,
    required String audience,
    required DateTime startsAt,
    required List<String> productIds,
    DateTime? earlyAccessAt,
    DateTime? endsAt,
    String? note,
  }) => guard(
    () => remote.createDrop(
      title: title,
      audience: audience,
      startsAt: startsAt,
      productIds: productIds,
      earlyAccessAt: earlyAccessAt,
      endsAt: endsAt,
      note: note,
    ),
    operation: 'create drop',
  );

  @override
  Future<Result<int>> buildDropAudience(String dropId, {int? limit}) => guard(
    () => remote.buildDropAudience(dropId, limit: limit),
    operation: 'build drop audience',
  );

  @override
  Future<Result<Drop>> setDropStatus(String dropId, String status) => guard(
    () => remote.setDropStatus(dropId, status),
    operation: 'drop status',
  );
}
