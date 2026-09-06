import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/home/domain/entities/continue_shopping_item.dart';
import 'package:reem/features/home/presentation/providers/home_content_provider.dart';

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
        (s) => s.content?.continueShopping ?? const <ContinueShoppingItem>[],
      ),
    );

    final notes = {for (final e in items) e.product.id: e.note};

    return ProductRail(
      eyebrow: context.l10n.homeContinueShoppingEyebrow,
      title: context.l10n.homeContinueShopping,
      products: items.map((e) => e.product).toList(),
      isLoading: isLoading,
      onTapProduct: (p) => context.push(RoutePaths.productDetailsOf(p.id)),
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
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.xs,
        vertical: DsSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: DsColors.black.withValues(alpha: 0.6),
        borderRadius: DsRadius.borderFull,
      ),
      child: Text(
        label,
        style: context.dsText.micro.bold.tint(DsColors.onMedia),
      ),
    );
  }
}
