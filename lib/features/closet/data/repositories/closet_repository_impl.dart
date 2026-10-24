import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/closet/data/datasources/closet_remote_datasource.dart';
import 'package:ohara/features/closet/domain/entities/closet_gap.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/entities/closet_look.dart';
import 'package:ohara/features/closet/domain/entities/closet_overview.dart';
import 'package:ohara/features/closet/domain/repositories/closet_repository.dart';

class ClosetRepositoryImpl with RepositoryHandler implements ClosetRepository {
  const ClosetRepositoryImpl(this.remote);

  final ClosetRemoteDataSource remote;

  // ── Overview ──────────────────────────────────────────────────────────

  @override
  Future<Result<ClosetOverview>> overview() => guard(remote.overview);

  @override
  Future<Result<ClosetSettings>> updateSettings({
    bool? autoAddPurchases,
    bool? suggestionsEnabled,
  }) =>
      guard(
        () => remote.updateSettings(
          autoAddPurchases: autoAddPurchases,
          suggestionsEnabled: suggestionsEnabled,
        ),
      );

  @override
  Future<Result<int>> backfill({int? limit}) =>
      guard(() => remote.backfill(limit: limit), operation: 'closet backfill');

  // ── Items ─────────────────────────────────────────────────────────────

  @override
  Future<Result<ClosetItemPage>> items(ClosetItemQuery query) =>
      guard(() => remote.items(query));

  @override
  Future<Result<ClosetItem>> item(String id) => guard(() => remote.item(id));

  @override
  Future<Result<ClosetItem>> addFromCatalog({
    required String productId,
    String? offerId,
    String? variantId,
    String? note,
    DescriptorPatch? descriptor,
  }) =>
      guard(
        () => remote.addFromCatalog(
          productId: productId,
          offerId: offerId,
          variantId: variantId,
          note: note,
          descriptor: descriptor,
        ),
        operation: 'add to closet',
      );

  @override
  Future<Result<ClosetItem>> addPersonal(PersonalItemDraft draft) =>
      guard(() => remote.addPersonal(draft), operation: 'add personal piece');

  @override
  Future<Result<ClosetItem>> updateItem(String id, ClosetItemPatch patch) =>
      guard(() => remote.updateItem(id, patch));

  @override
  Future<Result<ClosetItem>> setItemStatus(String id, ClosetItemStatus status) =>
      guard(() => remote.setItemStatus(id, status));

  @override
  Future<Result<void>> removeItem(String id) => guard(() => remote.removeItem(id));

  @override
  Future<Result<ClosetItem>> logWear(String id, {DateTime? wornOn}) =>
      guard(() => remote.logWear(id, wornOn: wornOn));

  @override
  Future<Result<ClosetItem>> removeWear(String id, {DateTime? wornOn}) =>
      guard(() => remote.removeWear(id, wornOn: wornOn));

  // ── Looks ─────────────────────────────────────────────────────────────

  @override
  Future<Result<List<ClosetLook>>> looks({
    String? occasion,
    bool includeArchived = false,
  }) =>
      guard(
        () => remote.looks(occasion: occasion, includeArchived: includeArchived),
      );

  @override
  Future<Result<ClosetLook>> look(String id) => guard(() => remote.look(id));

  @override
  Future<Result<ClosetLook>> createLook(LookDraft draft) =>
      guard(() => remote.createLook(draft), operation: 'create look');

  @override
  Future<Result<ClosetLook>> updateLook(String id, LookPatch patch) =>
      guard(() => remote.updateLook(id, patch));

  @override
  Future<Result<ClosetLook>> setLookItems(String id, List<LookSlotDraft> items) =>
      guard(() => remote.setLookItems(id, items), operation: 'save look');

  @override
  Future<Result<void>> removeLook(String id) => guard(() => remote.removeLook(id));

  @override
  Future<Result<ClosetLook>> logLookWear(
    String id, {
    DateTime? wornOn,
    String? occasionNote,
  }) =>
      guard(
        () => remote.logLookWear(id, wornOn: wornOn, occasionNote: occasionNote),
      );

  @override
  Future<Result<ClosetLook>> promoteStylistOutfit(String outfitId) => guard(
        () => remote.promoteStylistOutfit(outfitId),
        operation: 'save look from stylist',
      );

  // ── Gaps ──────────────────────────────────────────────────────────────

  @override
  Future<Result<List<ClosetGap>>> gaps() => guard(remote.gaps);

  @override
  Future<Result<List<ClosetGap>>> refreshGaps() => guard(remote.refreshGaps);

  @override
  Future<Result<GapSuggestions>> gapSuggestions(String gapId, {int? limit}) =>
      guard(
        () => remote.gapSuggestions(gapId, limit: limit),
        operation: 'closet suggestions',
      );

  @override
  Future<Result<ClosetGap>> dismissGap(String gapId) =>
      guard(() => remote.dismissGap(gapId));

  @override
  Future<Result<ClosetGap>> restoreGap(String gapId) =>
      guard(() => remote.restoreGap(gapId));

  @override
  Future<Result<ClosetPairing?>> pairing(String productId) =>
      guard(() => remote.pairing(productId));

  // ── Today ─────────────────────────────────────────────────────────────

  @override
  Future<Result<TodayOutfits>> today({String? occasion, int? limit}) =>
      guard(() => remote.today(occasion: occasion, limit: limit));
}
