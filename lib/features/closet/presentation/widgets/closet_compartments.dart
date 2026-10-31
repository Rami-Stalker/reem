import 'package:flutter/material.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/entities/closet_overview.dart';
import 'package:ohara/features/closet/domain/repositories/closet_repository.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_visuals.dart';

/// How a compartment keeps what is in it — which decides how it is drawn,
/// both closed on the front of the wardrobe and open on its own page.
enum ClosetCompartmentStyle {
  /// A brass rod with pieces on hangers: dresses, abayas, coats.
  rail,

  /// An open shelf with pieces folded on it: tops, bottoms.
  shelf,

  /// Brass pegs: bags and accessories hang by a strap.
  hooks,

  /// A drawer lined in velvet: jewellery, perfume, beauty.
  drawer,

  /// A slanted rack: shoes.
  rack,

  /// A storage box on top of the wardrobe: favourites, the season box.
  box,
}

/// One part of her wardrobe she can open.
///
/// Nearly always a slot — the server's closed vocabulary — and then the
/// compartment *is* that slot: it lists what the server files there, and its
/// "+" files a new piece there. Three are not slots: the whole wardrobe at
/// once, the favourites box and the season box, which hold pieces of every
/// slot and are reached by a filter instead.
@immutable
class ClosetCompartment {
  const ClosetCompartment._(this.key, this.slot, this.style);

  /// What the route carries: the slot key, or one of the three names below.
  final String key;

  /// The slot this compartment holds, or null for the three that hold every
  /// slot.
  final String? slot;
  final ClosetCompartmentStyle style;

  static const allKey = 'all'; // l10n-ignore: a route segment, not copy
  static const favouritesKey = 'favourites'; // l10n-ignore: a route segment, not copy
  static const storedKey = 'stored'; // l10n-ignore: a route segment, not copy

  static const all = ClosetCompartment._(allKey, null, ClosetCompartmentStyle.shelf);
  static const favourites = ClosetCompartment._(
    favouritesKey,
    null,
    ClosetCompartmentStyle.box,
  );
  static const stored = ClosetCompartment._(storedKey, null, ClosetCompartmentStyle.box);

  factory ClosetCompartment.forSlot(String slot) =>
      ClosetCompartment._(slot, slot, styleOf(slot));

  factory ClosetCompartment.fromKey(String key) => switch (key) {
    allKey => all,
    favouritesKey => favourites,
    storedKey => stored,
    _ => ClosetCompartment.forSlot(key),
  };

  /// `GIFT` is a purchase intent, not something kept in a wardrobe.
  static bool isWardrobeSlot(String slot) => slot != 'GIFT';

  static ClosetCompartmentStyle styleOf(String slot) => switch (slot) {
    'DRESS' || 'ABAYA' || 'OUTERWEAR' => ClosetCompartmentStyle.rail,
    'TOP' || 'BOTTOM' => ClosetCompartmentStyle.shelf,
    'BAG' || 'ACCESSORY' => ClosetCompartmentStyle.hooks,
    'SHOES' => ClosetCompartmentStyle.rack,
    // A slot the app has not met yet gets a drawer: the one compartment that
    // suits anything.
    _ => ClosetCompartmentStyle.drawer,
  };

  bool get isSlot => slot != null;
  bool get isStored => key == storedKey;
  bool get isFavourites => key == favouritesKey;

  /// Whether a piece can be added straight into it. The two boxes are filled
  /// from a piece's own page — a heart, a "put away for the season" — and
  /// never by a new piece arriving in them.
  bool get acceptsNew => key != favouritesKey && key != storedKey;

  /// The query that lists what is in it.
  ClosetItemQuery query({String? search, bool favouritesOnly = false, int limit = 48}) =>
      ClosetItemQuery(
        slot: slot,
        status: isStored ? ClosetItemStatus.archived : null,
        favouritesOnly: isFavourites || favouritesOnly ? true : null,
        search: search == null || search.isEmpty ? null : search,
        limit: limit,
      );

  IconData get icon => switch (key) {
    allKey => Icons.checkroom_rounded,
    favouritesKey => Icons.favorite_rounded,
    storedKey => Icons.inventory_2_rounded,
    _ => ClosetSlotStyle.icon(key),
  };

  /// The name on its plate: a plural that reads like a wardrobe label —
  /// «المجوهرات», not the singular slot label «مجوهرات». A slot the app has no
  /// name for takes the label the server sent with the vocabulary.
  String name(BuildContext context, [ClosetVocabulary? vocabulary]) {
    final l10n = context.l10n;
    return switch (key) {
      allKey => l10n.closetDrawerAll,
      favouritesKey => l10n.closetDrawerFavourites,
      storedKey => l10n.closetDrawerStored,
      'DRESS' => l10n.closetDrawerDress,
      'ABAYA' => l10n.closetDrawerAbaya,
      'OUTERWEAR' => l10n.closetDrawerOuterwear,
      'TOP' => l10n.closetDrawerTop,
      'BOTTOM' => l10n.closetDrawerBottom,
      'SHOES' => l10n.closetDrawerShoes,
      'BAG' => l10n.closetDrawerBag,
      'JEWELRY' => l10n.closetDrawerJewelry,
      'ACCESSORY' => l10n.closetDrawerAccessory,
      'PERFUME' => l10n.closetDrawerPerfume,
      'BEAUTY' => l10n.closetDrawerBeauty,
      _ => vocabulary?.labelForSlot(key) ?? key,
    };
  }

  @override
  bool operator ==(Object other) => other is ClosetCompartment && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// The wardrobe's floor plan: which compartments sit side by side, top to
/// bottom.
///
/// Long things hang at the top, where there is height for them; folded things
/// sit on shelves at eye level; bags hang from pegs; small precious things
/// are in drawers within reach; shoes are on the rack at the floor. It is the
/// order a wardrobe is actually arranged in, so she finds things where her
/// hand already expects them.
///
/// Only slots in [vocabulary] are placed — the "+" on a compartment files a
/// piece under its slot, and a slot the server does not know would be
/// refused. Slots the server knows and the plan does not are given drawers,
/// two to a row, above the shoe rack.
List<List<ClosetCompartment>> closetFloorPlan(ClosetVocabulary vocabulary) {
  const plan = [
    ['DRESS', 'ABAYA', 'OUTERWEAR'],
    ['TOP', 'BOTTOM'],
    ['BAG', 'ACCESSORY'],
    ['JEWELRY'],
    ['PERFUME', 'BEAUTY'],
    ['SHOES'],
  ];
  final known = {
    for (final term in vocabulary.slots)
      if (ClosetCompartment.isWardrobeSlot(term.key)) term.key,
  };
  // An overview without a vocabulary is a server that predates it; the plan
  // is the vocabulary the app was built against.
  final accept = known.isEmpty ? null : known;
  final placed = {for (final row in plan) ...row};
  final extras = [
    for (final slot in known)
      if (!placed.contains(slot)) slot,
  ];

  final rows = <List<ClosetCompartment>>[];
  for (final row in plan) {
    if (row.first == 'SHOES') {
      for (var i = 0; i < extras.length; i += 2) {
        rows.add([
          for (final slot in extras.skip(i).take(2)) ClosetCompartment.forSlot(slot),
        ]);
      }
    }
    final kept = [
      for (final slot in row)
        if (accept == null || accept.contains(slot)) ClosetCompartment.forSlot(slot),
    ];
    if (kept.isNotEmpty) rows.add(kept);
  }
  return rows;
}
