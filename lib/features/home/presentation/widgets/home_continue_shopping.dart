import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/wedgets/product/product_rail.dart';
import '../../domain/entities/continue_shopping_item.dart';
import '../providers/home_content_provider.dart';

/// "Pick up where you left off" — products from the bag / recent intent, each
/// tagged with a contextual note ("In your bag", "Only 3 left").
class HomeContinueShopping extends ConsumerWidget {
  const HomeContinueShopping({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      homeContentNotifierProvider.select((s) => s.isInitialLoading),
    );
    final items = ref.watch(
      homeContentNotifierProvider.select(
          (s) => s.content?.continueShopping ?? const <ContinueShoppingItem>[]),
    );

    final notes = {for (final e in items) e.product.id: e.note};

    return ProductRail(
      eyebrow: 'Welcome back',
      title: 'Continue shopping',
      products: items.map((e) => e.product).toList(),
      isLoading: isLoading,
      onTapProduct: (p) =>
          context.push('${RoutePaths.productDetails}?id=${p.id}'),
      trailingBuilder: (context, product) =>
          _NoteChip(label: notes[product.id] ?? ''),
    );
  }
}

class _NoteChip extends StatelessWidget {
  const _NoteChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: DsRadius.borderFull,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: DsTypography.bold,
        ),
      ),
    );
  }
}
