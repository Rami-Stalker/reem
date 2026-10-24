import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';

/// One slot of a look.
///
/// The two-sided shape from the schema, kept two-sided all the way to the
/// widget: [owned] is a piece from her closet, [product] is one she does not
/// have yet. Exactly one is non-null, and the difference is the whole point —
/// the second renders as the gap it is rather than as another tile.
class LookPiece extends Equatable {
  final String id;
  final String slot;
  final String slotLabel;
  final int position;
  final String? note;

  final ClosetItem? owned;
  final Product? product;
  final String? offerId;
  final String? variantId;

  const LookPiece({
    required this.id,
    required this.slot,
    required this.slotLabel,
    this.position = 0,
    this.note,
    this.owned,
    this.product,
    this.offerId,
    this.variantId,
  });

  bool get isOwned => owned != null;

  /// A slot she has chosen a piece for but does not own. This is what turns
  /// browsing into a wardrobe decision: the product is attached to a specific
  /// outfit rather than floating in a list of things she liked.
  bool get isWanted => owned == null && product != null;

  @override
  List<Object?> get props => [id, slot, owned?.id, product?.id];
}

/// An outfit she composed.
class ClosetLook extends Equatable {
  final String id;
  final String title;
  final String? note;
  final String? occasion;
  final String? occasionLabel;
  final List<ClosetTerm> seasons;
  final List<ClosetTerm> palette;

  /// Every slot is filled by something she owns.
  final bool isComplete;
  final bool isFavourite;
  final bool isArchived;

  /// The slots standing between her and wearing this.
  final List<ClosetTerm> missingSlots;

  final int wearCount;
  final DateTime? lastWornAt;

  /// Set when this look was promoted from a stylist suggestion.
  final String? sourceOutfitId;

  final List<LookPiece> pieces;

  const ClosetLook({
    required this.id,
    required this.title,
    this.note,
    this.occasion,
    this.occasionLabel,
    this.seasons = const [],
    this.palette = const [],
    this.isComplete = false,
    this.isFavourite = false,
    this.isArchived = false,
    this.missingSlots = const [],
    this.wearCount = 0,
    this.lastWornAt,
    this.sourceOutfitId,
    this.pieces = const [],
  });

  List<LookPiece> get ownedPieces =>
      pieces.where((piece) => piece.isOwned).toList(growable: false);

  List<LookPiece> get wantedPieces =>
      pieces.where((piece) => piece.isWanted).toList(growable: false);

  /// One purchase away from wearable — the state worth putting a button on.
  bool get isOnePieceShort => wantedPieces.length == 1;

  @override
  List<Object?> get props => [id, title, isComplete, pieces.length, wearCount];
}

/// One slot as the client sends it back when saving a look.
class LookSlotDraft {
  final String slot;
  final String? closetItemId;
  final String? productId;
  final String? offerId;
  final String? variantId;
  final String? note;

  const LookSlotDraft({
    required this.slot,
    this.closetItemId,
    this.productId,
    this.offerId,
    this.variantId,
    this.note,
  });

  /// Mirrors the server's invariant so a malformed look is caught before the
  /// round trip rather than after it.
  bool get isValid => (closetItemId != null) != (productId != null);

  Map<String, dynamic> toJson() => {
        'slot': slot,
        if (closetItemId != null) 'closet_item_id': closetItemId,
        if (productId != null) 'product_id': productId,
        if (offerId != null) 'offer_id': offerId,
        if (variantId != null) 'variant_id': variantId,
        if (note != null) 'note': note,
      };
}
