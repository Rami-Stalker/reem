import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/design_system/design_system.dart';

/// Which shape the catalogue is currently wearing.
///
/// Session-scoped on purpose — she picks a mood for this visit, not a setting
/// to manage. Shared by every surface that lists products (home's "new in",
/// a department, a "see all"), so choosing the mosaic once is not undone by
/// walking into the next page.
final productShapeProvider = StateProvider<DsProductShape>(
  (ref) => DsProductShape.posts,
);
