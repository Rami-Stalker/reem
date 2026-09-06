import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/cart/presentation/providers/cart_providers.dart';
import 'package:reem/features/visual_search/domain/entities/visual_match.dart';
import 'package:reem/features/visual_search/domain/entities/visual_search_session.dart';
import 'package:reem/features/visual_search/presentation/providers/visual_search_notifier.dart';
import 'package:reem/features/visual_search/presentation/providers/visual_search_providers.dart';
import 'package:reem/features/visual_search/presentation/providers/visual_search_state.dart';
import 'package:reem/features/visual_search/presentation/widgets/visual_match_card.dart';
import 'package:reem/features/visual_search/presentation/widgets/visual_query_header.dart';
import 'package:reem/features/visual_search/presentation/widgets/visual_refine_bar.dart';
import 'package:reem/features/visual_search/presentation/widgets/visual_region_strip.dart';
import 'package:reem/features/visual_search/presentation/widgets/visual_source_sheet.dart';

/// Reem Visual Shopping — البحث بالصورة.
///
/// One screen with two states rather than two screens, because it is one
/// action from her side: she arrives with a picture in mind, hands it over,
/// and gets things she can buy. The upload, the reading and the results all
/// live in the same scroll so the photograph she is comparing against never
/// leaves the frame.
///
/// Nothing here composes a result of its own. Every card, every percentage and
/// every chip is what the server returned, and when the server has nothing it
/// says which kind of nothing it is: a catalogue that has not been described
/// yet is a different problem from a screenshot with no match, and telling
/// them apart is the difference between "come back later" and "try a clearer
/// photo".
class VisualSearchScreen extends ConsumerStatefulWidget {
  const VisualSearchScreen({super.key, this.sessionId});

  /// Null for a new search; set when reopening one from the history.
  final String? sessionId;

  @override
  ConsumerState<VisualSearchScreen> createState() => _VisualSearchScreenState();
}

class _VisualSearchScreenState extends ConsumerState<VisualSearchScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final provider = visualSearchProvider(widget.sessionId);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    ref.listen(provider, (previous, next) {
      final failure = next.failure;
      if (failure != null && previous?.failure != failure) {
        DsSnackbar.error(context, failure.message);
      }
    });

    return Scaffold(
      backgroundColor: colors.background,
      appBar: ReemAppBar(
        title: context.l10n.visualSearchTitle,
        actions: [
          if (state.hasSession)
            IconButton(
              tooltip: 'بحث جديد',
              onPressed: state.isBusy ? null : notifier.reset,
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(child: _Body(state: state, notifier: notifier)),
            if (state.hasSession)
              VisualRefineBar(
                enabled: !state.isBusy,
                suggestions: state.bootstrap.prompts,
                onSubmit: notifier.refine,
              ),
          ],
        ),
      ),
      floatingActionButton: state.hasSession
          ? null
          : FloatingActionButton.extended(
              onPressed: state.isBusy ? null : () => _pick(notifier, state),
              icon: const Icon(Icons.image_search_rounded),
              label: const Text('اختاري صورة'),
            ),
    );
  }

  Future<void> _pick(
    VisualSearchNotifier notifier,
    VisualSearchState state,
  ) async {
    final picked = await VisualSourceSheet.show(
      context,
      maxEdge: state.bootstrap.uploadMaxEdge,
    );
    if (picked == null) return;

    await notifier.searchWithImage(
      bytes: picked.bytes,
      filename: picked.filename,
      source: picked.source,
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state, required this.notifier});

  final VisualSearchState state;
  final VisualSearchNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoadingBootstrap) {
      return const Center(child: DsLoadingIndicator());
    }

    switch (state.phase) {
      case VisualSearchPhase.uploading:
      case VisualSearchPhase.analysing:
        return _Working(state: state);
      case VisualSearchPhase.idle:
        return _Intro(state: state, notifier: notifier);
      case VisualSearchPhase.ready:
      case VisualSearchPhase.refining:
        return _Results(state: state, notifier: notifier);
    }
  }
}

/// The empty screen.
class _Intro extends StatelessWidget {
  const _Intro({required this.state, required this.notifier});

  final VisualSearchState state;
  final VisualSearchNotifier notifier;

  @override
  Widget build(BuildContext context) {
    // The index is empty: nothing has been described yet, so an upload cannot
    // be answered. Saying so beats an upload that returns an empty page.
    if (state.isIndexEmpty) {
      return DsEmptyState(
        icon: Icons.hourglass_top_rounded,
        title: 'لسا عم نجهّز البحث بالصورة',
        message:
            'عم نحلّل صور المنتجات لحتى نقدر نقارنها بصورتك. جرّبي بعد شوي.',
        actionLabel: 'حدّثي',
        onAction: notifier.refreshBootstrap,
      );
    }

    final colors = context.dsColors;

    return ListView(
      padding: const EdgeInsets.all(DsSpacing.md),
      children: [
        const SizedBox(height: DsSpacing.xl),
        Icon(
          Icons.image_search_rounded,
          size: 64,
          color: colors.primary,
        ),
        const SizedBox(height: DsSpacing.md),
        Text(
          'شفتي شي وعجبك؟',
          textAlign: TextAlign.center,
          style: context.dsText.screenTitle,
        ),
        const SizedBox(height: DsSpacing.xs),
        Text(
          'ارفعي صورة القطعة — سكرين شوت من إنستغرام أو تيك توك أو بنترست، '
          'أو صورة من الاستوديو — ومنجيبلك أقرب شي موجود بريم.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: DsSpacing.xl),
        if (state.bootstrap.privacyNote.isNotEmpty)
          _PrivacyNote(note: state.bootstrap.privacyNote),
        if (state.bootstrap.recent.isNotEmpty) ...[
          const SizedBox(height: DsSpacing.xl),
          Text('بحوثك السابقة', style: context.dsText.tileTitle),
          const SizedBox(height: DsSpacing.xs),
          for (final session in state.bootstrap.recent)
            _RecentTile(session: session, notifier: notifier),
        ],
      ],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(DsRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: DsSpacing.xs),
          Expanded(
            child: Text(
              note,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.session, required this.notifier});

  final VisualSearchSession session;
  final VisualSearchNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final chips = session.understanding.chips
        .map((chip) => chip.label)
        .take(3)
        .join('، ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.history_rounded, color: colors.onSurfaceVariant),
      title: Text(
        chips.isEmpty ? 'بحث بصورة' : chips,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        session.queryImageUrl == null
            ? 'الصورة انحذفت — بس النتائج لسا موجودة'
            : 'اضغطي لتفتحيه',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
      ),
      onTap: () => notifier.openSession(session.id),
    );
  }
}

/// Uploading and analysing.
class _Working extends StatelessWidget {
  const _Working({required this.state});

  final VisualSearchState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final uploading = state.phase == VisualSearchPhase.uploading;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              // A determinate ring while bytes are moving; indeterminate once
              // the server has them, because we genuinely do not know how long
              // the search will take and a bar that stalls at 99% is worse
              // than one that spins.
              value: uploading ? state.uploadProgress.clamp(0.05, 1) : null,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            uploading ? 'عم نرفع الصورة…' : 'عم نحلّل الصورة وندوّر…',
            style: context.dsText.tileTitle,
          ),
          const SizedBox(height: DsSpacing.xxs),
          Text(
            'منقارن الصورة بصور المنتجات الموجودة فعليًا بريم.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// The photograph, what was read from it, and what matched.
class _Results extends ConsumerWidget {
  const _Results({required this.state, required this.notifier});

  final VisualSearchState state;
  final VisualSearchNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = state.session;
    if (session == null) return const SizedBox.shrink();

    final region = state.selectedRegion;
    final matches = region?.matches ?? const <VisualMatch>[];

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: VisualQueryHeader(
                session: session,
                onRetake: notifier.reset,
                onForget: () => _confirmForget(context),
              ),
            ),
            if (session.isOutfit)
              SliverToBoxAdapter(
                child: VisualRegionStrip(
                  regions: session.regions,
                  selectedId: state.selectedRegionId,
                  onSelect: notifier.selectRegion,
                ),
              ),
            if (matches.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'ما لقيت شي قريب',
                  message:
                      session.notice ??
                      'جرّبي صورة أوضح، أو اكتبيلي شو بدك بالضبط.',
                  actionLabel: 'صورة تانية',
                  onAction: notifier.reset,
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  DsSpacing.md,
                  DsSpacing.md,
                  DsSpacing.md,
                  DsSpacing.xs,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'أقرب ${matches.length} قطعة',
                    style: context.dsText.tileTitle,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  DsSpacing.md,
                  DsSpacing.xxxs,
                  DsSpacing.md,
                  DsSpacing.xxl,
                ),
                sliver: SliverGrid(
                  // `mainAxisExtent` rather than `childAspectRatio`, computed
                  // from the width a tile will *actually* get.
                  //
                  // A ratio is applied to the real tile width, so deriving one
                  // from the maximum width silently under-sizes every cell on
                  // a narrower screen — which is what clipped the reason line
                  // off the bottom of every card on a phone while looking
                  // correct on a tablet.
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columns(context),
                    mainAxisSpacing: DsSpacing.md,
                    crossAxisSpacing: DsSpacing.md,
                    mainAxisExtent:
                        _tileWidth(context) / visualMatchImageAspect +
                        visualMatchCardChrome,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final match = matches[index];
                    return VisualMatchCard(
                      match: match,
                      onTap: () => context.push(
                        RoutePaths.productDetailsOf(match.product.id),
                      ),
                      onAddToCart: () => _addToCart(context, ref, match),
                      onFeedback: (feedback) =>
                          notifier.sendFeedback(match.id, feedback),
                    );
                  }, childCount: matches.length),
                ),
              ),
            ],
          ],
        ),
        // A refinement leaves the previous results readable and dims them,
        // rather than blanking a page she is still looking at.
        if (state.phase == VisualSearchPhase.refining)
          const Positioned.fill(child: _RefiningVeil()),
      ],
    );
  }

  Future<void> _addToCart(
    BuildContext context,
    WidgetRef ref,
    VisualMatch match,
  ) async {
    final offerId = match.offerId ?? match.product.bestOffer?.id;
    if (offerId == null) {
      DsSnackbar.error(context, 'ما في عرض متوفر لهالقطعة حاليًا.');
      return;
    }

    final added = await ref
        .read(cartNotifierProvider.notifier)
        .add(offerId: offerId);
    if (!context.mounted) return;

    if (added) {
      DsSnackbar.success(context, 'انضافت للسلة');
    } else {
      DsSnackbar.error(context, 'ما قدرت أضيفها للسلة.');
    }
  }

  Future<void> _confirmForget(BuildContext context) async {
    final confirmed = await DsDialog.confirm(
      context,
      title: 'حذف البحث؟',
      message: 'رح تنحذف الصورة والنتائج نهائيًا. ما فينا نرجّعهم بعدين.',
      confirmLabel: 'احذفي',
      cancelLabel: 'رجوع',
      destructive: true,
    );
    if (!confirmed) return;

    final done = await notifier.forgetCurrent();
    if (context.mounted && done) {
      DsSnackbar.success(context, 'انحذفت الصورة والبحث.');
    }
  }
}

/// The widest a result tile is allowed to get. Two columns on a phone, more on
/// a tablet, and the card is designed around roughly this width.
const double _maxTileWidth = 200;

int _columns(BuildContext context) {
  final available = MediaQuery.sizeOf(context).width - DsSpacing.md * 2;
  return (available / _maxTileWidth).ceil().clamp(2, 6);
}

double _tileWidth(BuildContext context) {
  final columns = _columns(context);
  final available = MediaQuery.sizeOf(context).width - DsSpacing.md * 2;
  return (available - DsSpacing.md * (columns - 1)) / columns;
}

class _RefiningVeil extends StatelessWidget {
  const _RefiningVeil();

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return IgnorePointer(
      child: ColoredBox(
        color: colors.background.withValues(alpha: 0.55),
        child: const Center(child: DsLoadingIndicator()),
      ),
    );
  }
}
