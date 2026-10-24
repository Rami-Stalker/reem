import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/ai_stylist/presentation/providers/ai_stylist_providers.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/closet/domain/entities/closet_gap.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/home/presentation/widgets/home_categories_showcase.dart';
import 'package:ohara/features/home/presentation/widgets/home_section_header.dart';
import 'package:ohara/features/rooms/presentation/providers/rooms_providers.dart';
import 'package:ohara/features/search/presentation/discover_waiting.dart';
import 'package:ohara/features/search/presentation/providers/search_providers.dart';

/// The Discover tab: it starts from what she needs, not from the catalogue.
///
/// It used to be a search box over a product grid — a page that asks her to
/// already know the name of the thing she wants. Most of the time she knows
/// the occasion instead. So the tab opens on a question, «ماذا تحتاجين؟»,
/// and the question goes to the stylist, which reads it into the chips of
/// what she meant and answers with complete looks. Below it, what her life
/// already says she needs: the rooms she has a date for, and the one gap in
/// her closet worth filling. The aisles are still here, last, for the days
/// she only wants to browse — and search by name is one tap from the top.
///
/// A guest has no stylist, rooms or closet, so for her the question runs a
/// plain search and the suggestions are what everyone is searching.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      authNotifierProvider.select((s) => s.isAuthenticated),
    );

    return OharaScrollPage(
      onRefresh: () async {
        if (signedIn) {
          ref
            ..invalidate(roomsProvider)
            ..invalidate(closetOverviewProvider)
            ..invalidate(stylistBootstrapProvider);
        } else {
          ref.invalidate(trendingSearchesProvider);
        }
      },
      slivers: [
        const SliverToBoxAdapter(child: _Header()),
        const SliverToBoxAdapter(child: _AskCard()),
        if (signedIn) ...[
          const SliverToBoxAdapter(child: _Waiting()),
          const SliverToBoxAdapter(child: _Prompts()),
        ] else
          const SliverToBoxAdapter(child: _Trending()),
        // The aisles carry their own heading and "see all", and draw nothing
        // at all when there are no featured categories.
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: DsSpacing.xl),
            child: HomeCategoriesShowcase(),
          ),
        ),
        // Clearance for the floating bottom bar, which sits above the
        // device's own bottom inset.
        SliverToBoxAdapter(
          child: SizedBox(
            height:
                DsSizes.bottomSafeGap + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.lg,
          DsSpacing.md,
          DsSpacing.lg,
          DsSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.discoverEyebrow,
              style: DsTypography.overline(c.secondary),
            ),
            DsGaps.vXxs,
            Text(l10n.navDiscover, style: context.dsText.pageTitle.bold),
          ],
        ),
      ),
    );
  }
}

/// «اسألي أوهارا» — one field, and the answer is a set of looks.
class _AskCard extends ConsumerStatefulWidget {
  const _AskCard();

  @override
  ConsumerState<_AskCard> createState() => _AskCardState();
}

class _AskCardState extends ConsumerState<_AskCard> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _ask() {
    final question = _controller.text.trim();
    if (question.isEmpty) {
      _focus.requestFocus();
      return;
    }
    final signedIn = ref.read(authNotifierProvider).isAuthenticated;
    // The field is left as she typed it: coming back to Discover she sees
    // the question she asked, and can change a word rather than retype it.
    context.push(
      signedIn
          ? RoutePaths.stylistAsking(question)
          : RoutePaths.keywordSearchFor(question),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;

    return Padding(
      padding: DsSpacing.screenHorizontal,
      child: CustomerPanel(
        padding: DsSpacing.cardPaddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: DsSizes.iconSm,
                  color: c.secondary,
                ),
                DsGaps.hXs,
                Text(
                  l10n.discoverAskLabel,
                  style: context.dsText.labelStrong.tint(c.secondary),
                ),
              ],
            ),
            DsGaps.vXs,
            Row(
              children: [
                Expanded(
                  child: DsInputField(
                    controller: _controller,
                    focusNode: _focus,
                    hint: l10n.discoverAskHint,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _ask(),
                  ),
                ),
                DsGaps.hXs,
                GradientIconButton(
                  icon: Icons.arrow_upward_rounded,
                  tooltip: l10n.discoverAskSend,
                  onTap: _ask,
                ),
              ],
            ),
            DsGaps.vXs,
            Text(
              l10n.discoverAskHelper,
              style: context.dsText.caption,
            ),
            DsGaps.vSm,
            Wrap(
              spacing: DsSpacing.xs,
              runSpacing: DsSpacing.xs,
              children: [
                DsChip(
                  label: l10n.discoverPhotoSearch,
                  icon: Icons.center_focus_strong_rounded,
                  onTap: () => context.push(RoutePaths.visualSearch),
                ),
                DsChip(
                  label: l10n.discoverByName,
                  icon: Icons.search_rounded,
                  onTap: () => context.push(RoutePaths.keywordSearch),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «ما ينتظركِ» — what her rooms and her closet already say she needs.
///
/// Draws nothing until there is something: a shopper with no dated room and
/// a closet that is short of nothing gets the question and the aisles, not
/// an empty heading.
class _Waiting extends ConsumerWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    final rooms = upcomingRooms(ref.watch(roomsProvider).value ?? const []);
    final gaps = [...?ref.watch(closetOverviewProvider).value?.gaps]
      ..sort((a, b) => b.priority.compareTo(a.priority));
    final gap = gaps.isEmpty ? null : gaps.first;

    if (rooms.isEmpty && gap == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: DsSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(
            eyebrow: l10n.discoverWaitingSubtitle,
            title: l10n.discoverWaitingTitle,
          ),
          for (final upcoming in rooms)
            _RoomCard(upcoming: upcoming),
          if (gap != null) _GapCard(gap: gap),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.upcoming});

  final UpcomingRoom upcoming;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;
    final room = upcoming.room;
    final ink = c.onInverseSurface;

    return _WaitingCard(
      ground: c.inverseSurface,
      onTap: () => context.push(RoutePaths.roomOf(room.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsBadge(
                label: l10n.discoverRoomDays(upcoming.daysLeft),
                tone: DsBadgeTone.accent,
              ),
              if (room.occasionLabel case final occasion?) ...[
                DsGaps.hXs,
                Flexible(
                  child: Text(
                    occasion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.caption.tint(ink),
                  ),
                ),
              ],
            ],
          ),
          DsGaps.vXs,
          Text(
            room.title,
            style: context.dsText.sectionTitle.uiFamily.bold.tint(ink),
          ),
          DsGaps.vXs,
          // In the card's own ink: the ground is the inverse surface, light
          // in the dark theme, and accent gold on it would barely show.
          Text(l10n.discoverRoomCta, style: context.dsText.labelStrong.tint(ink)),
        ],
      ),
    );
  }
}

class _GapCard extends StatelessWidget {
  const _GapCard({required this.gap});

  final ClosetGap gap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;
    final ink = c.onSecondaryContainer;

    return _WaitingCard(
      ground: c.secondaryContainer,
      onTap: () => context.push(RoutePaths.closetGapOf(gap.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.discoverGapEyebrow,
            style: DsTypography.overline(ink),
          ),
          DsGaps.vXs,
          // Headline and rationale arrive written by the server, from the
          // same arithmetic that ranked the gap; nothing here rephrases them.
          Text(
            gap.headline,
            style: context.dsText.sectionTitle.uiFamily.bold.tint(ink),
          ),
          DsGaps.vXxs,
          Text(gap.rationale, style: context.dsText.body.tint(ink)),
          if (gap.suggestedColours.isNotEmpty) ...[
            DsGaps.vXs,
            Wrap(
              spacing: DsSpacing.xxs,
              runSpacing: DsSpacing.xxs,
              children: [
                for (final colour in gap.suggestedColours)
                  DsBadge(label: colour.label, tone: DsBadgeTone.neutral),
              ],
            ),
          ],
          DsGaps.vXs,
          Text(
            l10n.discoverGapCta,
            style: context.dsText.labelStrong.tint(ink),
          ),
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
    required this.ground,
    required this.onTap,
    required this.child,
  });

  final Color ground;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        0,
        DsSpacing.lg,
        DsSpacing.sm,
      ),
      child: Material(
        color: ground,
        borderRadius: DsRadius.borderCard,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: DsSpacing.cardPaddingLg,
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    );
  }
}

/// The stylist's opening questions, tuned server-side to what it knows of
/// her. Each one is asked as if she had typed it.
class _Prompts extends ConsumerWidget {
  const _Prompts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompts = ref.watch(stylistBootstrapProvider).value?.prompts;
    if (prompts == null || prompts.isEmpty) return const SizedBox.shrink();

    return _ChipSection(
      title: context.l10n.discoverPromptsTitle,
      labels: prompts.take(4).toList(growable: false),
      onTap: (prompt) => context.push(RoutePaths.stylistAsking(prompt)),
    );
  }
}

/// What everyone is searching — the guest's stand-in for the prompts.
class _Trending extends ConsumerWidget {
  const _Trending();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terms = ref.watch(trendingSearchesProvider).value;
    if (terms == null || terms.isEmpty) return const SizedBox.shrink();

    return _ChipSection(
      title: context.l10n.discoverTrendingTitle,
      labels: terms.take(8).toList(growable: false),
      onTap: (term) => context.push(RoutePaths.keywordSearchFor(term)),
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({
    required this.title,
    required this.labels,
    required this.onTap,
  });

  final String title;
  final List<String> labels;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: DsSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(title: title),
          Padding(
            padding: DsSpacing.screenHorizontal,
            child: Wrap(
              spacing: DsSpacing.xs,
              runSpacing: DsSpacing.xs,
              children: [
                for (final label in labels)
                  DsChip(label: label, onTap: () => onTap(label)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
