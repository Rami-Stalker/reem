// shared/entities/category.dart

import 'package:equatable/equatable.dart';

/// A node in the three-level catalogue tree (root → section → leaf).
///
/// Replaces the free-text `category` string the product used to carry. That
/// string had drifted into three disagreeing lists — the seed's, the trending
/// fallback's, and a `CategoryType` enum in the app — none of which matched.
/// The server is now the single source of truth, and names arrive already
/// translated.
class Category extends Equatable {
  final String id;
  final String slug;
  final String nameAr;
  final String nameEn;

  /// 0 = root, 1 = section, 2 = leaf. Products attach to leaves only.
  final int level;
  final String? parentId;

  final String? iconUrl;
  final String? imageUrl;

  /// Gated categories (lingerie, intimate care) — the platform does not sell
  /// these today, but the flag exists so the UI can hide rather than guess.
  final bool isSensitive;

  /// Whether a change-of-mind return is allowed. Opened cosmetics are excluded.
  final bool returnsAllowed;

  const Category({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.nameEn,
    this.level = 2,
    this.parentId,
    this.iconUrl,
    this.imageUrl,
    this.isSensitive = false,
    this.returnsAllowed = true,
  });

  bool get isLeaf => level >= 2;

  /// The display name. The interface is Arabic-first; English is a fallback
  /// for the (deferred) English UI.
  String name({bool arabic = true}) =>
      arabic ? nameAr : (nameEn.isEmpty ? nameAr : nameEn);

  @override
  List<Object?> get props => [
        id,
        slug,
        nameAr,
        nameEn,
        level,
        parentId,
        iconUrl,
        imageUrl,
        isSensitive,
        returnsAllowed,
      ];
}
