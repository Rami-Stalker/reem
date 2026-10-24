import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/closet/data/datasources/closet_remote_datasource.dart';
import 'package:ohara/features/closet/data/models/closet_models.dart';
import 'package:ohara/features/closet/domain/entities/closet_gap.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/entities/closet_look.dart';
import 'package:ohara/features/closet/domain/entities/closet_overview.dart';
import 'package:ohara/features/closet/domain/repositories/closet_repository.dart';

final class ClosetRemoteDataSourceImpl extends BaseRemoteDataSource
    implements ClosetRemoteDataSource {
  const ClosetRemoteDataSourceImpl(super.dio);

  // ── Overview ──────────────────────────────────────────────────────────

  @override
  Future<ClosetOverview> overview() async =>
      closetOverviewFromJson(await getJson(ApiEndpoints.closet));

  @override
  Future<ClosetSettings> updateSettings({
    bool? autoAddPurchases,
    bool? suggestionsEnabled,
  }) async {
    final json = await patchJson(
      ApiEndpoints.closetSettings,
      body: {
        'auto_add_purchases': ?autoAddPurchases,
        'suggestions_enabled': ?suggestionsEnabled,
      },
    );
    return closetSettingsFromJson(json);
  }

  @override
  Future<int> backfill({int? limit}) async {
    final json = await postJson(
      ApiEndpoints.closetBackfill,
      body: {'limit': ?limit},
    );
    final added = json['added'];
    return added is num ? added.toInt() : 0;
  }

  // ── Items ─────────────────────────────────────────────────────────────

  @override
  Future<ClosetItemPage> items(ClosetItemQuery query) async =>
      closetItemPageFromJson(
        await getJson(ApiEndpoints.closetItems, query: query.toQuery()),
      );

  @override
  Future<ClosetItem> item(String id) async =>
      closetItemFromJson(await getJson(ApiEndpoints.closetItem(id)));

  @override
  Future<ClosetItem> addFromCatalog({
    required String productId,
    String? offerId,
    String? variantId,
    String? note,
    DescriptorPatch? descriptor,
  }) async {
    final json = await postJson(
      ApiEndpoints.closetItemsCatalog,
      body: {
        'product_id': productId,
        'offer_id': ?offerId,
        'variant_id': ?variantId,
        if (note != null && note.isNotEmpty) 'note': note,
        if (descriptor != null && !descriptor.isEmpty)
          'descriptor': descriptor.toJson(),
      },
    );
    return closetItemFromJson(json);
  }

  @override
  Future<ClosetItem> addPersonal(PersonalItemDraft draft) async =>
      closetItemFromJson(
        await postJson(ApiEndpoints.closetItemsPersonal, body: draft.toJson()),
      );

  @override
  Future<ClosetItem> updateItem(String id, ClosetItemPatch patch) async =>
      closetItemFromJson(
        await patchJson(ApiEndpoints.closetItem(id), body: patch.toJson()),
      );

  @override
  Future<ClosetItem> setItemStatus(String id, ClosetItemStatus status) async =>
      closetItemFromJson(
        await patchJson(
          ApiEndpoints.closetItemStatus(id),
          body: {'status': status.wire},
        ),
      );

  @override
  Future<void> removeItem(String id) =>
      deleteRequest(ApiEndpoints.closetItem(id));

  @override
  Future<ClosetItem> logWear(String id, {DateTime? wornOn}) async =>
      closetItemFromJson(
        await postJson(
          ApiEndpoints.closetItemWear(id),
          body: {if (wornOn != null) 'worn_on': _day(wornOn)},
        ),
      );

  @override
  Future<ClosetItem> removeWear(String id, {DateTime? wornOn}) async =>
      closetItemFromJson(
        await deleteJson(
          ApiEndpoints.closetItemWear(id),
          body: {if (wornOn != null) 'worn_on': _day(wornOn)},
        ),
      );

  // ── Looks ─────────────────────────────────────────────────────────────

  @override
  Future<List<ClosetLook>> looks({
    String? occasion,
    bool includeArchived = false,
  }) async {
    final list = await getList(
      ApiEndpoints.closetLooks,
      query: {
        'occasion': ?occasion,
        if (includeArchived) 'include_archived': true,
      },
    );
    return closetLooksFromJson(list);
  }

  @override
  Future<ClosetLook> look(String id) async =>
      closetLookFromJson(await getJson(ApiEndpoints.closetLook(id)));

  @override
  Future<ClosetLook> createLook(LookDraft draft) async => closetLookFromJson(
        await postJson(ApiEndpoints.closetLooks, body: draft.toJson()),
      );

  @override
  Future<ClosetLook> updateLook(String id, LookPatch patch) async =>
      closetLookFromJson(
        await patchJson(ApiEndpoints.closetLook(id), body: patch.toJson()),
      );

  @override
  Future<ClosetLook> setLookItems(String id, List<LookSlotDraft> items) async =>
      closetLookFromJson(
        await patchJson(
          ApiEndpoints.closetLookItems(id),
          body: {
            'items': items.map((item) => item.toJson()).toList(growable: false),
          },
        ),
      );

  @override
  Future<void> removeLook(String id) =>
      deleteRequest(ApiEndpoints.closetLook(id));

  @override
  Future<ClosetLook> logLookWear(
    String id, {
    DateTime? wornOn,
    String? occasionNote,
  }) async =>
      closetLookFromJson(
        await postJson(
          ApiEndpoints.closetLookWear(id),
          body: {
            if (wornOn != null) 'worn_on': _day(wornOn),
            if (occasionNote != null && occasionNote.isNotEmpty)
              'occasion_note': occasionNote,
          },
        ),
      );

  @override
  Future<ClosetLook> promoteStylistOutfit(String outfitId) async =>
      closetLookFromJson(
        await postJson(ApiEndpoints.closetLookFromStylist(outfitId)),
      );

  // ── Gaps ──────────────────────────────────────────────────────────────

  @override
  Future<List<ClosetGap>> gaps() async =>
      closetGapsFromJson(await getList(ApiEndpoints.closetGaps));

  @override
  Future<List<ClosetGap>> refreshGaps() async {
    // The recomputed list comes back from the POST, so a refresh is one round
    // trip rather than a write followed by a read. Wrapped in an object because
    // the shared POST helper decodes one — see the route's comment.
    final response = await postJson(ApiEndpoints.closetGapsRefresh);
    return closetGapsFromJson(response['gaps']);
  }

  @override
  Future<GapSuggestions> gapSuggestions(String gapId, {int? limit}) async =>
      gapSuggestionsFromJson(
        await getJson(
          ApiEndpoints.closetGapSuggestions(gapId),
          query: {'limit': ?limit},
        ),
      );

  @override
  Future<ClosetGap> dismissGap(String gapId) async =>
      closetGapFromJson(await postJson(ApiEndpoints.closetGapDismiss(gapId)));

  @override
  Future<ClosetGap> restoreGap(String gapId) async =>
      closetGapFromJson(await postJson(ApiEndpoints.closetGapRestore(gapId)));

  @override
  Future<ClosetPairing?> pairing(String productId) async {
    final json = await getJson(ApiEndpoints.closetPairing(productId));
    // The endpoint answers null for a product that no longer exists; an empty
    // body must read as "no answer" rather than as a pairing of zero.
    if (json.isEmpty || json['slot'] == null) return null;
    return closetPairingFromJson(json);
  }

  // ── Today ─────────────────────────────────────────────────────────────

  @override
  Future<TodayOutfits> today({String? occasion, int? limit}) async =>
      todayOutfitsFromJson(
        await getJson(
          ApiEndpoints.closetToday,
          query: {
            'occasion': ?occasion,
            'limit': ?limit,
          },
        ),
      );
}

/// A wear is a date, not an instant. Sending the day alone keeps the client's
/// clock out of the unique index the server keys wears on.
String _day(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
