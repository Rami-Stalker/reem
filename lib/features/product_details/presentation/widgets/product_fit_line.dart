import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/entities/product_variant.dart';
import 'package:ohara/features/intelligence/domain/entities/size_fit.dart';
import 'package:ohara/features/intelligence/presentation/providers/intelligence_providers.dart';

/// «M: أبقته 92% ممّن وصلهنّ بهذا المقاس» — under the size row.
///
/// What a fitting room tells her and a listing never does: whether this size,
/// on women who actually received it, stayed. It follows the size she has
/// selected, so changing M to L changes the sentence.
///
/// Two voices. Most sizes are kept, and that is said plainly. A size that is
/// often sent back is said as a caution, because it is the one sentence on
/// the page that can save her a return — and it is the one no seller has a
/// reason to volunteer.
///
/// Says nothing at all when the variant has no size, or the size has sold
/// too few times for the server to give a rate.
class ProductFitLine extends ConsumerWidget {
  const ProductFitLine({
    super.key,
    required this.productId,
    required this.variant,
  });

  final String productId;
  final OfferVariant? variant;

  /// Below this share kept, the size is spoken about as a caution.
  static const double cautionBelow = 0.8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = variant?.attributes['size'];
    if (size == null) return const SizedBox.shrink();

    final fits = ref.watch(productSizeFitProvider(productId)).value;
    final fit = fits == null ? null : fitForSize(fits, size);
    final percent = fit?.keptPercent;
    if (fit == null || percent == null) return const SizedBox.shrink();

    final c = context.dsColors;
    final l10n = context.l10n;
    final caution = fit.keptRate! < cautionBelow;
    final label = '$size'.trim();

    return Padding(
      padding: const EdgeInsets.only(top: DsSpacing.sm),
      child: Container(
        padding: DsSpacing.listRowPadding,
        decoration: BoxDecoration(
          color: caution ? c.warningContainer : c.successContainer,
          borderRadius: DsRadius.borderLg,
        ),
        child: Row(
          children: [
            Icon(
              caution
                  ? Icons.info_outline_rounded
                  : Icons.verified_outlined,
              size: DsSizes.iconSm,
              color: caution ? c.warning : c.success,
            ),
            DsGaps.hXs,
            Expanded(
              child: Text(
                caution
                    ? l10n.productFitOftenReturned(label, percent)
                    : l10n.productFitKept(label, percent),
                // Body ink on both grounds: warning and success hues are too
                // light on their own containers to carry a sentence.
                style: context.dsText.labelStrong.tint(c.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
