import 'package:equatable/equatable.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/ai_stylist/domain/entities/style_brief.dart';

enum StylistOutfitStatus {
  suggested,
  saved,
  dismissed;

  static StylistOutfitStatus fromWire(String? value) => switch (value) {
        'SAVED' => StylistOutfitStatus.saved,
        'DISMISSED' => StylistOutfitStatus.dismissed,
        _ => StylistOutfitStatus.suggested,
      };

  String get wire => switch (this) {
        StylistOutfitStatus.suggested => 'SUGGESTED',
        StylistOutfitStatus.saved => 'SAVED',
        StylistOutfitStatus.dismissed => 'DISMISSED',
      };
}

/// One piece of a look: a slot, and the real product filling it.
///
/// [product] is nullable on purpose. A saved look outlives the catalogue entry
/// it was built from, and a withdrawn piece should render as an empty slot
/// rather than vanish — a three-piece look that silently becomes two is a look
/// she no longer recognises.
class OutfitPiece extends Equatable {
  final String id;
  final String slot;
  final String slotLabel;
  final Product? product;
  final String? offerId;
  final String? variantId;
  final Money? price;
  final String? reason;
  final int position;

  const OutfitPiece({
    required this.id,
    required this.slot,
    required this.slotLabel,
    this.product,
    this.offerId,
    this.variantId,
    this.price,
    this.reason,
    this.position = 0,
  });

  bool get isAvailable => product != null && product!.isAvailable;

  @override
  List<Object?> get props => [id, slot, product, price, position];
}

/// A complete look assembled from separately-sold products.
class StylistOutfit extends Equatable {
  final String id;
  final String? conversationId;
  final String? messageId;

  final String title;
  final String? occasion;
  final String? occasionLabel;
  final String? note;

  /// The colours the look was built around.
  final List<StyleTerm> palette;

  /// Sum of the quoted piece prices. Null when a piece has no price.
  final Money? total;

  final StylistOutfitStatus status;
  final List<OutfitPiece> items;
  final DateTime createdAt;

  const StylistOutfit({
    required this.id,
    required this.title,
    required this.createdAt,
    this.conversationId,
    this.messageId,
    this.occasion,
    this.occasionLabel,
    this.note,
    this.palette = const [],
    this.total,
    this.status = StylistOutfitStatus.suggested,
    this.items = const [],
  });

  bool get isSaved => status == StylistOutfitStatus.saved;

  /// Pieces that can still be bought — what "add the whole look to the cart"
  /// would actually add.
  List<OutfitPiece> get buyablePieces =>
      items.where((piece) => piece.isAvailable).toList(growable: false);

  bool get isComplete => items.every((piece) => piece.isAvailable);

  StylistOutfit copyWith({StylistOutfitStatus? status}) {
    return StylistOutfit(
      id: id,
      title: title,
      createdAt: createdAt,
      conversationId: conversationId,
      messageId: messageId,
      occasion: occasion,
      occasionLabel: occasionLabel,
      note: note,
      palette: palette,
      total: total,
      status: status ?? this.status,
      items: items,
    );
  }

  @override
  List<Object?> get props => [id, title, status, items, total];
}
