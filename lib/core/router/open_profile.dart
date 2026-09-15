import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/router/route_paths.dart';

/// Opens somebody's page from inside a bottom sheet.
///
/// Sheets are raised on the root navigator (so they clear the floating bottom
/// bar), which means pushing a route *under* an open sheet leaves the sheet
/// sitting on top of the page she asked for. The router is read first because
/// the sheet's context is gone the moment it pops.
void openProfileFromSheet(BuildContext sheetContext, String userId) {
  if (userId.isEmpty) return;
  final router = GoRouter.of(sheetContext);
  Navigator.of(sheetContext).maybePop();
  router.push(RoutePaths.userProfileOf(userId));
}
