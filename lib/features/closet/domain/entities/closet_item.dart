import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/value_objects/money.dart';

/// A keyed label from the server's closed vocabulary.
///
/// Every enumerated value in the closet travels as `{key, label}`: the key is
/// what the client sends back, the label is Arabic the server rendered. The
/// client never translates a key itself — the lexicon lives in one place, and
/// a second copy of it here would drift the first time a colour was added.
class ClosetTerm extends Equatable {
  final String key;
  final String label;

  const ClosetTerm({required this.key, required this.label});

  @override
  List<Object?> get props => [key, label];
}

/// Where a piece came from.
///
/// Presentation only. The engines treat all three identically, and any client
/// behaviour that branches on this — beyond a badge — is reintroducing the
/// distinction the feature exists to remove.
enum ClosetItemSource {
  catalog,
  purchase,
  personal;

  static ClosetItemSource fromWire(String? value) => switch (value) {
        'PURCHASE' => ClosetItemSource.purchase,
        'PERSONAL' => ClosetItemSource.personal,
        _ => ClosetItemSource.catalog,
      };

  String get wire => switch (this) {
        ClosetItemSource.catalog => 'CATALOG',
        ClosetItemSource.purchase => 'PURCHASE',
        ClosetItemSource.personal => 'PERSONAL',
      };

  /// Whether the piece points at something still on sale.
  bool get isFromOhara => this != ClosetItemSource.personal;
}

enum ClosetItemStatus {
  active,
  archived,
  released;

  static ClosetItemStatus fromWire(String? value) => switch (value) {
        'ARCHIVED' => ClosetItemStatus.archived,
        'RELEASED' => ClosetItemStatus.released,
        _ => ClosetItemStatus.active,
      };

  String get wire => switch (this) {
        ClosetItemStatus.active => 'ACTIVE',
        ClosetItemStatus.archived => 'ARCHIVED',
        ClosetItemStatus.released => 'RELEASED',
      };
}

/// A garment she owns.
class ClosetItem extends Equatable {
  final String id;
  final ClosetItemSource source;
  final String sourceLabel;
  final ClosetItemStatus status;

  final String title;
  final String? imageUrl;
  final String? blurHash;

  // ── Descriptor ────────────────────────────────────────────────────────
  final String slot;
  final String slotLabel;
  final List<ClosetTerm> colours;
  final List<String> materials;
  final String modesty;
  final String modestyLabel;
  final List<ClosetTerm> seasons;
  final List<ClosetTerm> occasions;
  final String? size;

  final String? brandName;
  final String? productId;
  final String? offerId;
  final String? variantId;

  final Money? purchasePrice;

  /// Null until she has actually worn it — see the serializer for why dividing
  /// by zero wears would read as an accusation rather than a fact.
  final Money? costPerWear;

  final int wearCount;
  final DateTime? lastWornAt;
  final bool isFavourite;
  final String? note;
  final DateTime? acquiredAt;

  const ClosetItem({
    required this.id,
    required this.source,
    required this.sourceLabel,
    required this.status,
    required this.title,
    required this.slot,
    required this.slotLabel,
    this.imageUrl,
    this.blurHash,
    this.colours = const [],
    this.materials = const [],
    this.modesty = 'UNSPECIFIED',
    this.modestyLabel = '',
    this.seasons = const [],
    this.occasions = const [],
    this.size,
    this.brandName,
    this.productId,
    this.offerId,
    this.variantId,
    this.purchasePrice,
    this.costPerWear,
    this.wearCount = 0,
    this.lastWornAt,
    this.isFavourite = false,
    this.note,
    this.acquiredAt,
  });

  bool get hasBeenWorn => wearCount > 0;

  /// Days since she last wore it. Null when she never has — a different state
  /// from "a long time ago", and one the UI says differently.
  int? get daysSinceWorn {
    final worn = lastWornAt;
    if (worn == null) return null;
    return DateTime.now().difference(worn).inDays;
  }

  /// Owned, photographed, and never once worn. The quietest thing a wardrobe
  /// can tell someone about her own spending.
  bool get isNeglected => !hasBeenWorn || (daysSinceWorn ?? 0) >= 90;

  @override
  List<Object?> get props => [id, status, title, slot, wearCount, lastWornAt];
}
