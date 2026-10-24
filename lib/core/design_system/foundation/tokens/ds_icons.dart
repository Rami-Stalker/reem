import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/tokens/ds_sizes.dart';

/// The app's icon vocabulary: one glyph per concept, plus the size aliases.
///
/// Sizes forward to [DsSizes] so an icon and the control around it cannot
/// disagree about what "small" means.
abstract final class DsIcons {
  static const double sizeXxs = DsSizes.iconXxs;
  static const double sizeXs = DsSizes.iconXs;
  static const double sizeSm = DsSizes.iconSm;
  static const double sizeMd = DsSizes.iconMd;
  static const double sizeLg = DsSizes.iconLg;
  static const double sizeXl = DsSizes.iconXl;
  static const double sizeXxl = DsSizes.iconXxl;

  // Navigation
  static const IconData home = Icons.home_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData profile = Icons.person_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData cart = Icons.shopping_bag_rounded;
  static const IconData favorites = Icons.favorite_rounded;
  static const IconData notifications = Icons.notifications_rounded;

  // Actions
  static const IconData back = Icons.arrow_back_ios_new_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData share = Icons.share_rounded;
  static const IconData more = Icons.more_horiz_rounded;

  // Commerce
  static const IconData like = Icons.favorite_border_rounded;
  static const IconData likeFilled = Icons.favorite_rounded;
  static const IconData star = Icons.star_rounded;
  static const IconData starOutline = Icons.star_outline_rounded;
}
