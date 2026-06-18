import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../permissions_provider.dart';

/// Renders [child] only for sellers/admins; customers get [fallback] (or nothing).
class SellerOnly extends ConsumerWidget {
  const SellerOnly({super.key, required this.child, this.fallback});

  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(permissionsProvider).isSeller;
    return canManage ? child : (fallback ?? const SizedBox.shrink());
  }
}
