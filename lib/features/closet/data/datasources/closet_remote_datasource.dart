import 'package:reem/features/closet/domain/entities/closet_gap.dart';
import 'package:reem/features/closet/domain/entities/closet_item.dart';
import 'package:reem/features/closet/domain/entities/closet_look.dart';
import 'package:reem/features/closet/domain/entities/closet_overview.dart';
import 'package:reem/features/closet/domain/repositories/closet_repository.dart';

abstract interface class ClosetRemoteDataSource {
  Future<ClosetOverview> overview();

  Future<ClosetSettings> updateSettings({
    bool? autoAddPurchases,
    bool? suggestionsEnabled,
  });

  Future<int> backfill({int? limit});

  Future<ClosetItemPage> items(ClosetItemQuery query);

  Future<ClosetItem> item(String id);

  Future<ClosetItem> addFromCatalog({
    required String productId,
    String? offerId,
    String? variantId,
    String? note,
    DescriptorPatch? descriptor,
  });

  Future<ClosetItem> addPersonal(PersonalItemDraft draft);

  Future<ClosetItem> updateItem(String id, ClosetItemPatch patch);

  Future<ClosetItem> setItemStatus(String id, ClosetItemStatus status);

  Future<void> removeItem(String id);

  Future<ClosetItem> logWear(String id, {DateTime? wornOn});

  Future<ClosetItem> removeWear(String id, {DateTime? wornOn});

  Future<List<ClosetLook>> looks({String? occasion, bool includeArchived});

  Future<ClosetLook> look(String id);

  Future<ClosetLook> createLook(LookDraft draft);

  Future<ClosetLook> updateLook(String id, LookPatch patch);

  Future<ClosetLook> setLookItems(String id, List<LookSlotDraft> items);

  Future<void> removeLook(String id);

  Future<ClosetLook> logLookWear(
    String id, {
    DateTime? wornOn,
    String? occasionNote,
  });

  Future<ClosetLook> promoteStylistOutfit(String outfitId);

  Future<List<ClosetGap>> gaps();

  Future<List<ClosetGap>> refreshGaps();

  Future<GapSuggestions> gapSuggestions(String gapId, {int? limit});

  Future<ClosetGap> dismissGap(String gapId);

  Future<ClosetGap> restoreGap(String gapId);

  Future<ClosetPairing?> pairing(String productId);

  Future<TodayOutfits> today({String? occasion, int? limit});
}
