import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/closet/domain/entities/closet_item.dart';
import 'package:reem/features/closet/domain/entities/closet_look.dart';
import 'package:reem/features/closet/domain/entities/closet_overview.dart';
import 'package:reem/features/closet/domain/repositories/closet_repository.dart';
import 'package:reem/features/closet/presentation/providers/closet_providers.dart';
import 'package:reem/features/closet/presentation/widgets/today_outfit_card.dart';

/// شو بقدر ألبس اليوم؟
///
/// Answers from her own clothes. Nothing on this screen is for sale, and the
/// only mention of the shop is when an outfit is genuinely one piece short —
/// which is the difference between a wardrobe assistant and an advert wearing
/// one's clothes.
class ClosetTodayScreen extends ConsumerStatefulWidget {
  const ClosetTodayScreen({super.key});

  @override
  ConsumerState<ClosetTodayScreen> createState() => _ClosetTodayScreenState();
}

class _ClosetTodayScreenState extends ConsumerState<ClosetTodayScreen> {
  String? _occasion;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final todayAsync = ref.watch(todayOutfitsProvider(_occasion));
    final overviewAsync = ref.watch(closetOverviewProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: const ReemAppBar(title: 'شو ألبس اليوم؟'),
      body: Column(
        children: [
          overviewAsync.maybeWhen(
            data: (overview) => _OccasionFilter(
              occasions: overview.vocabulary.occasions,
              selected: _occasion,
              onSelected: (value) => setState(() => _occasion = value),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: todayAsync.when(
              loading: () => const Center(child: DsLoadingIndicator()),
              error: (_, _) => DsErrorState(
                message: 'ما قدرنا نقترح عليكِ شي هلق.',
                onRetry: () => ref.invalidate(todayOutfitsProvider),
              ),
              data: (today) => today.outfits.isEmpty
                  ? _NothingToWear(occasion: _occasion)
                  : ListView.separated(
                      padding: const EdgeInsets.all(DsSpacing.md),
                      itemCount: today.outfits.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: DsSpacing.sm),
                      itemBuilder: (context, index) {
                        final outfit = today.outfits[index];
                        return TodayOutfitCard(
                          outfit: outfit,
                          onWear: () => _wear(outfit),
                          onOpenLook: outfit.lookId == null
                              ? null
                              : () => context
                                  .push(RoutePaths.closetLookOf(outfit.lookId!)),
                          onSaveAsLook:
                              outfit.isSaved ? null : () => _saveAsLook(outfit),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Logging a wear from here is worth more than from the grid: this is the
  /// moment she is actually deciding what to put on, so it is the one moment
  /// the log costs her nothing to keep.
  Future<void> _wear(TodayOutfit outfit) async {
    final actions = ref.read(closetActionsProvider);

    if (outfit.lookId != null) {
      await actions.logLookWear(outfit.lookId!);
    } else {
      // A composition has no look row, so each piece is logged individually —
      // which is exactly what a look wear fans out to anyway.
      for (final piece in outfit.pieces) {
        await actions.logWear(piece.id);
      }
    }
    if (!mounted) return;
    DsSnackbar.show(
      context,
      message: 'تم — سجّلناها لليوم.',
      type: DsSnackbarType.success,
    );
  }

  /// Turn a composition into a look she owns.
  ///
  /// The bridge from "the app arranged this" to "this is mine": the pieces are
  /// already hers, so saving is a title and a set of slots.
  Future<void> _saveAsLook(TodayOutfit outfit) async {
    final result = await ref.read(closetActionsProvider).createLook(
          LookDraft(
            title: outfit.title,
            occasion: null,
            items: outfit.pieces
                .map((piece) =>
                    LookSlotDraft(slot: piece.slot, closetItemId: piece.id))
                .toList(growable: false),
          ),
        );
    if (!mounted) return;

    result.when(
      success: (_) => DsSnackbar.show(context, message: 'حفظناها بإطلالاتك.'),
      error: (_) =>
          DsSnackbar.show(context, message: 'ما قدرنا نحفظ الإطلالة.'),
    );
  }
}

class _OccasionFilter extends StatelessWidget {
  const _OccasionFilter({
    required this.occasions,
    required this.selected,
    required this.onSelected,
  });

  final List<ClosetTerm> occasions;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
        children: [
          // A `SizedBox(height: 36)` sat here. In a horizontal list the sliver
          // hands every child a tight cross-axis constraint, so the 36 was
          // discarded and what remained was a zero-width box painting nothing
          // — the rail's height is the `SizedBox(height: 52)` above.
          DsChip(
            label: 'أي شي',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final occasion in occasions) ...[
            const SizedBox(width: DsSpacing.xs),
            DsChip(
              label: occasion.label,
              selected: selected == occasion.key,
              onTap: () => onSelected(occasion.key),
            ),
          ],
        ],
      ),
    );
  }
}

class _NothingToWear extends StatelessWidget {
  const _NothingToWear({required this.occasion});

  final String? occasion;

  @override
  Widget build(BuildContext context) {
    return DsEmptyState(
      icon: Icons.checkroom_rounded,
      title: occasion == null ? 'ما قدرنا نركّب إطلالة' : 'ما في شي لهالمناسبة',
      // Says which shortage caused it rather than "no results": the picker only
      // fails when a whole slot is empty, and naming it is the difference
      // between advice and a shrug.
      message: occasion == null
          ? 'غالبًا ناقصك خانة كاملة — جرّبي تضيفي حذاء أو قطعة سفلية لخزانتك.'
          : 'جرّبي تشيلي فلتر المناسبة، أو ضيفي قطعة مناسبة إلها.',
    );
  }
}
