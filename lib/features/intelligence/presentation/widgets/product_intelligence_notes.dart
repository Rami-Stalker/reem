import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/intelligence/domain/entities/intelligence_note.dart';
import 'package:reem/features/intelligence/presentation/providers/intelligence_providers.dart';

/// What Reem has to say about this product, on the product page.
///
/// The whole of phase three's user-facing surface is this strip. That is
/// deliberate: the brief asked for intelligence *inside* the experience rather
/// than an AI screen beside it, and a woman weighing a dress does not want to
/// navigate somewhere to be told she already owns one.
///
/// ── Three rules it keeps ─────────────────────────────────────────────────
///
/// It renders **nothing** when there is nothing to say, which is most of the
/// time. No header, no empty state, no skeleton — the page is simply unchanged
/// for a shopper Reem knows nothing about.
///
/// A **caution comes first and looks different**. If Reem is about to tell her
/// she already owns something close, that sentence is not buried under the
/// reasons to buy.
///
/// Every note **can be checked**. A note about a cheaper alternative opens it;
/// one about her closet says which piece. Advice she cannot verify is advice
/// she has to take on faith, which is the opposite of what this is for.
class ProductIntelligenceNotes extends ConsumerWidget {
  const ProductIntelligenceNotes({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productNotesProvider(productId));

    return async.maybeWhen(
      data: (notes) => notes.isEmpty
          ? const SizedBox.shrink()
          : _Strip(notes: notes),
      // Loading and failure both render nothing. A placeholder would reserve
      // space on every product page for a section most of them will not have.
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.notes});

  final List<IntelligenceNote> notes;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: colors.primary,
              ),
              const SizedBox(width: DsSpacing.xs),
              Text(
                context.l10n.intelligenceNotesForYou,
                style: context.dsText.cardTitle,
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          for (final note in notes) _NoteRow(note: note),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note});

  final IntelligenceNote note;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final (icon, colour) = switch (note.tone) {
      NoteTone.caution => (Icons.info_rounded, colors.warning),
      NoteTone.encourage => (Icons.check_circle_rounded, colors.success),
      NoteTone.inform => (Icons.lightbulb_outline_rounded, colors.primary),
    };

    // Only a note that points somewhere is tappable. A row that looks
    // interactive and does nothing is worse than a plain sentence.
    final target = note.relatedProductId;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colour),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Text(
              note.ar,
              style: note.isCaution
                  ? context.dsText.body.semibold.tint(colors.onSurface)
                  : context.dsText.body.tint(colors.onSurface),
            ),
          ),
          if (target != null)
            Icon(
              Icons.chevron_left_rounded,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
        ],
      ),
    );

    if (target == null) return row;
    return InkWell(
      onTap: () => context.push(RoutePaths.productDetailsOf(target)),
      borderRadius: DsRadius.borderMd,
      child: row,
    );
  }
}
