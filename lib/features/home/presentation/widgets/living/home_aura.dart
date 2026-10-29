import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/utils/damascus_time.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/cart/presentation/providers/cart_providers.dart';
import 'package:ohara/features/discovery/domain/entities/product_collection.dart';
import 'package:ohara/features/home/presentation/providers/home_content_provider.dart';
import 'package:ohara/features/home/presentation/providers/home_provider.dart';
import 'package:ohara/features/home/presentation/widgets/home_greeting.dart';
import 'package:ohara/features/home/presentation/widgets/living/aura_palette.dart';
import 'package:ohara/features/home/presentation/widgets/living/live_countdown.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// The top of the home: a sky that knows what time it is, and what is
/// waiting for her.
///
/// It replaces four stacked pieces — a top bar, a greeting, a search box and
/// a stylist banner — with one canvas. The sky follows the Damascus hour
/// ([AuraPalette]); her name and a question sized like a magazine cover
/// stand on it; under them a row of live chips says what changed since she
/// last looked (a deal ticking down, boutiques that posted, a bag waiting);
/// and the field at the bottom asks rather than searches — «اسألي أوهارا» opens
/// the stylist, with an example that changes every few seconds so she knows
/// she can speak to it in sentences.
///
/// Scrolling folds the sky into a glass bar that keeps the wordmark, the bag
/// and the bell, because the bag lives nowhere else in the app.
class HomeAura extends ConsumerWidget {
  const HomeAura({super.key, this.onStoriesTap});

  /// Where the «posted today» chip takes her — the stories rail below.
  final VoidCallback? onStoriesTap;

  /// The sky's height under the status bar.
  static const double expandedHeight = 452;
  static const double _toolbarHeight = DsSizes.appBarHeight + DsSpacing.xs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = HomeGreetingSlot.at(damascusNow());
    final palette = AuraPalette.of(slot, isDark: context.isDarkMode);
    final colors = context.dsColors;
    final topInset = MediaQuery.paddingOf(context).top;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      automaticallyImplyLeading: false,
      expandedHeight: expandedHeight,
      toolbarHeight: _toolbarHeight,
      backgroundColor: DsColors.transparent,
      surfaceTintColor: DsColors.transparent,
      elevation: 0,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final minExtent = _toolbarHeight + topInset;
          final maxExtent = expandedHeight + topInset;
          // 1 when fully open, 0 when folded into the bar.
          final open =
              ((constraints.maxHeight - minExtent) / (maxExtent - minExtent))
                  .clamp(0.0, 1.0);
          final barInk = Color.lerp(colors.onBackground, palette.ink, open)!;

          return Stack(
            fit: StackFit.expand,
            children: [
              AuraCanvas(palette: palette),
              // The sky fades into the page instead of ending on a line.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: DsSpacing.huge,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.background.withValues(alpha: 0),
                          colors.background,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // The folded bar: frosted, fading in as the sky folds away.
              if (open < 1)
                Opacity(
                  opacity: 1 - open,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: DsBlur.medium,
                        sigmaY: DsBlur.medium,
                      ),
                      child: ColoredBox(
                        color: colors.background.withValues(alpha: 0.86),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                top: topInset + _toolbarHeight,
                child: ClipRect(
                  child: Opacity(
                    opacity: Curves.easeIn.transform(open),
                    child: OverflowBox(
                      alignment: Alignment.bottomCenter,
                      minHeight: 0,
                      maxHeight: expandedHeight - _toolbarHeight,
                      child: _AuraContent(
                        palette: palette,
                        slot: slot,
                        onStoriesTap: onStoriesTap,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: topInset,
                height: _toolbarHeight,
                child: _AuraBar(
                  ink: barInk,
                  glass: open > 0.5 ? palette : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Wordmark, bag, bell and her avatar.
class _AuraBar extends ConsumerWidget {
  const _AuraBar({required this.ink, required this.glass});

  final Color ink;

  /// The sky's palette while the bar sits on the sky; `null` once folded.
  final AuraPalette? glass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider.select((s) => s.user));
    final bag = ref.watch(cartCountProvider);
    final unread = ref.watch(
      homeContentNotifierProvider.select(
        (s) => s.content?.notifications.unreadCount ?? 0,
      ),
    );
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Row(
        children: [
          Text(l10n.appTitle, style: context.dsText.pageTitle.bold.tint(ink)),
          const Spacer(),
          _GlassIcon(
            icon: Icons.shopping_bag_outlined,
            count: bag,
            ink: ink,
            palette: glass,
            label: l10n.cart,
            onTap: () => context.push(RoutePaths.cart),
          ),
          DsGaps.hXs,
          _GlassIcon(
            icon: Icons.notifications_none_rounded,
            count: unread,
            ink: ink,
            palette: glass,
            label: l10n.notifications,
            onTap: () => context.push(RoutePaths.notifications),
          ),
          DsGaps.hXs,
          DsAvatar(
            imageUrl: user?.imageUrl,
            name: user?.name,
            size: DsSizes.avatarSm,
            onTap: () => context.push(RoutePaths.profile),
          ),
        ],
      ),
    );
  }
}

class _GlassIcon extends StatelessWidget {
  const _GlassIcon({
    required this.icon,
    required this.count,
    required this.ink,
    required this.palette,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final Color ink;
  final AuraPalette? palette;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: DsSizes.avatarSm,
              height: DsSizes.avatarSm,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette?.glass ?? colors.surfaceVariant,
                border: Border.all(
                  color: palette?.glassBorder ?? colors.border,
                ),
              ),
              child: Icon(icon, size: DsSizes.iconSm, color: ink),
            ),
            if (count > 0)
              PositionedDirectional(
                top: -DsSpacing.xxxs,
                end: -DsSpacing.xxxs,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: DsSizes.iconXs,
                    minHeight: DsSizes.iconXs,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DsSpacing.xxs,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: DsRadius.borderFull,
                    border: Border.all(color: colors.background),
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: context.dsText.micro.bold.tint(colors.onPrimary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The words on the sky: hello, the question, what is live, and the ask.
class _AuraContent extends ConsumerWidget {
  const _AuraContent({
    required this.palette,
    required this.slot,
    required this.onStoriesTap,
  });

  final AuraPalette palette;
  final HomeGreetingSlot slot;
  final VoidCallback? onStoriesTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(authNotifierProvider.select((s) => s.user));
    final firstName = _firstName(user?.name);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.md,
        DsSpacing.lg,
        DsSpacing.xl,
      ),
      child: Stack(
        children: [
          // The newest pieces, pinned to the sky like polaroids — the cover
          // of today's issue rather than a banner to scroll past.
          PositionedDirectional(
            top: 0,
            end: 0,
            child: _FloatingCollage(palette: palette),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DsSparkle(size: DsSizes.iconXxs, color: palette.ink),
                  DsGaps.hXxs,
                  Text(
                    HomeGreetingCopy.of(l10n),
                    style: context.dsText.labelStrong.tint(palette.inkMuted),
                  ),
                ],
              ),
              DsGaps.vXs,
              Text(
                firstName == null
                    ? l10n.homeAuraGuest
                    : l10n.homeAuraAddress(firstName),
                style: context.dsText.screenTitle.displayFamily.tint(
                  palette.ink,
                ),
              ),
              Text(
                _question(l10n),
                maxLines: 2,
                style: context.dsText.hero.displayFamily.bold
                    .tint(palette.ink)
                    .copyWith(height: 1.15),
              ),
              DsGaps.vLg,
              _BriefChips(palette: palette, onStoriesTap: onStoriesTap),
              DsGaps.vMd,
              _AskOhara(palette: palette),
            ],
          ),
        ],
      ),
    );
  }

  String _question(AppLocalizations l10n) => switch (slot) {
    HomeGreetingSlot.morning => l10n.homeAuraQuestionMorning,
    HomeGreetingSlot.midday => l10n.homeAuraQuestionMidday,
    HomeGreetingSlot.evening => l10n.homeAuraQuestionEvening,
    HomeGreetingSlot.night => l10n.homeAuraQuestionNight,
  };

  static String? _firstName(String? fullName) {
    final trimmed = fullName?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

/// What changed since she last looked — only the chips that have something
/// true to say. A new shopper with an empty bag sees fewer, not zeros.
class _BriefChips extends ConsumerWidget {
  const _BriefChips({required this.palette, required this.onStoriesTap});

  final AuraPalette palette;
  final VoidCallback? onStoriesTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(authNotifierProvider.select((s) => s.user?.id));
    final boutiques = ref.watch(
      homeNotifierProvider.select(
        (s) => {
          for (final story in s.stories)
            if (story.user.id != me) story.user.id,
        }.length,
      ),
    );
    final content = ref.watch(
      homeContentNotifierProvider.select((s) => s.content),
    );
    final bag = ref.watch(cartCountProvider);

    final now = DateTime.now();
    final ending = (content?.flashDeals ?? const [])
        .where((d) => d.endsAt != null && d.endsAt!.isAfter(now))
        .map((d) => d.endsAt!)
        .fold<DateTime?>(
          null,
          (soonest, at) =>
              soonest == null || at.isBefore(soonest) ? at : soonest,
        );
    final unread = content?.notifications.unreadCount ?? 0;

    final chips = <Widget>[
      if (ending != null)
        LiveCountdown(
          endsAt: ending,
          builder: (context, left) => _Chip(
            palette: palette,
            icon: Icons.bolt_rounded,
            label: l10n.homeBriefDealEnds(left),
            live: true,
            onTap: () => context.push(
              RoutePaths.collectionOf(ProductCollection.deals.key),
            ),
          ),
        ),
      if (boutiques > 0)
        _Chip(
          palette: palette,
          icon: Icons.auto_awesome_rounded,
          label: l10n.homeBriefStories(boutiques),
          onTap: onStoriesTap,
        ),
      if (bag > 0)
        _Chip(
          palette: palette,
          icon: Icons.shopping_bag_outlined,
          label: l10n.homeBriefBag(bag),
          onTap: () => context.push(RoutePaths.cart),
        ),
      if (unread > 0)
        _Chip(
          palette: palette,
          icon: Icons.notifications_none_rounded,
          label: l10n.homeBriefUnread(unread),
          onTap: () => context.push(RoutePaths.notifications),
        ),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: DsSizes.chipHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: chips.length,
        separatorBuilder: (_, _) => DsGaps.hXs,
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.palette,
    required this.icon,
    required this.label,
    this.onTap,
    this.live = false,
  });

  final AuraPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// A deal ticking down gets a warm dot, the one moving thing in the row.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: DsRadius.borderFull,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: DsBlur.subtle,
            sigmaY: DsBlur.subtle,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
            decoration: BoxDecoration(
              color: palette.glass,
              borderRadius: DsRadius.borderFull,
              border: Border.all(color: palette.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (live)
                  _PulseDot(color: colors.discount)
                else
                  Icon(icon, size: DsSizes.iconXs, color: palette.ink),
                DsGaps.hXs,
                Text(
                  label,
                  style: context.dsText.captionStrong.tabular.tint(palette.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A dot that breathes — the universal sign for "this is happening now".
class PulseDotIndicator extends StatefulWidget {
  const PulseDotIndicator({super.key, required this.color});

  final Color color;

  @override
  State<PulseDotIndicator> createState() => _PulseDotIndicatorState();
}

class _PulseDotIndicatorState extends State<PulseDotIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: DsMotion.slowest + DsMotion.normal,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
      _beat.repeat();
    });
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const core = DsSpacing.xs;
    return SizedBox.square(
      dimension: DsSizes.iconXs,
      child: AnimatedBuilder(
        animation: _beat,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: core + DsSpacing.xs * _beat.value,
              height: core + DsSpacing.xs * _beat.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.45 * (1 - _beat.value)),
              ),
            ),
            Container(
              width: core,
              height: core,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => PulseDotIndicator(color: color);
}

/// «اسألي أوهارا» — a field that asks rather than searches.
///
/// The example inside it changes every few seconds. A plain "search" hint
/// teaches keywords; a sentence teaches that she can describe what she wants
/// the way she would to a friend in a shop, which is what the stylist reads.
class _AskOhara extends StatefulWidget {
  const _AskOhara({required this.palette});

  final AuraPalette palette;

  @override
  State<_AskOhara> createState() => _AskOharaState();
}

class _AskOharaState extends State<_AskOhara> {
  Timer? _timer;
  int _example = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (mounted) setState(() => _example = (_example + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final palette = widget.palette;
    final examples = [
      l10n.homeAskExample1,
      l10n.homeAskExample2,
      l10n.homeAskExample3,
      l10n.homeAskExample4,
    ];
    final example = examples[_example];

    return Semantics(
      button: true,
      label: l10n.homeAskOhara,
      child: GestureDetector(
        onTap: () => context.push(RoutePaths.stylist),
        child: ClipRRect(
          borderRadius: DsRadius.borderXxl,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: DsBlur.medium,
              sigmaY: DsBlur.medium,
            ),
            child: Container(
              height: DsSizes.controlXl,
              padding: const EdgeInsetsDirectional.only(
                start: DsSpacing.xs,
                end: DsSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: palette.glass,
                borderRadius: DsRadius.borderXxl,
                border: Border.all(color: palette.glassBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: DsSizes.controlMd,
                    height: DsSizes.controlMd,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: CustomerExperience.signatureGradient,
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.35),
                          blurRadius: DsBlur.light,
                          offset: const Offset(0, DsSpacing.xxs),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: DsColors.onMedia,
                      size: DsSizes.iconSm,
                    ),
                  ),
                  DsGaps.hSm,
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.homeAskOhara,
                          style: context.dsText.captionStrong.tint(
                            palette.inkMuted,
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: DsMotion.slow,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0, 0.35),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: Text(
                            '«$example»',
                            key: ValueKey(example),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.dsText.bodyStrong.tint(palette.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.homeAskPhoto,
                    onPressed: () => context.push(RoutePaths.visualSearch),
                    icon: Icon(Icons.photo_camera_outlined, color: palette.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three of the newest pieces, tilted and drifting on the sky.
///
/// Each floats on its own phase, so the trio never moves as one block; a tap
/// opens the piece. Nothing is drawn until there is something new to show.
class _FloatingCollage extends ConsumerStatefulWidget {
  const _FloatingCollage({required this.palette});

  final AuraPalette palette;

  @override
  ConsumerState<_FloatingCollage> createState() => _FloatingCollageState();
}

class _FloatingCollageState extends ConsumerState<_FloatingCollage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  static const double _cardWidth = DsSizes.thumbMd;
  static const double _cardHeight = DsSizes.thumbLg;

  /// Resting place (from the end edge, from the top), tilt and phase.
  static const _poses = [
    (Offset(DsSpacing.huge + DsSpacing.lg, DsSpacing.md), -0.16, 0.0),
    (Offset(DsSpacing.xxl, 0), 0.05, 0.35),
    (Offset(0, DsSpacing.lg), 0.17, 0.7),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
      _float.repeat();
    });
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pieces = ref.watch(
      homeNotifierProvider.select((s) {
        for (final collection in const [
          ProductCollection.newArrivals,
          ProductCollection.trending,
        ]) {
          final products = s
              .sectionOf(collection)
              .products
              .where((p) => (p.coverUrl ?? '').isNotEmpty)
              .take(3)
              .toList();
          if (products.length == 3) return products;
        }
        return const <Product>[];
      }),
    );
    if (pieces.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: DsSpacing.huge + DsSpacing.lg + _cardWidth + DsSpacing.xs,
      height: _cardHeight + DsSpacing.xl,
      child: AnimatedBuilder(
        animation: _float,
        builder: (context, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < pieces.length; i++)
              PositionedDirectional(
                end: _poses[i].$1.dx,
                top:
                    _poses[i].$1.dy +
                    DsSpacing.xxs *
                        math.sin((_float.value + _poses[i].$3) * 2 * math.pi),
                child: Transform.rotate(
                  angle: _poses[i].$2,
                  child: _Polaroid(product: pieces[i], palette: widget.palette),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Polaroid extends StatelessWidget {
  const _Polaroid({required this.product, required this.palette});

  final Product product;
  final AuraPalette palette;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: product.title,
      child: GestureDetector(
        onTap: () => context.push(RoutePaths.productDetailsOf(product.id)),
        child: Container(
          width: _FloatingCollageState._cardWidth,
          height: _FloatingCollageState._cardHeight,
          padding: const EdgeInsets.all(DsSpacing.xxs),
          decoration: BoxDecoration(
            color: palette.isDeep ? DsColors.secondary800 : DsColors.white,
            borderRadius: DsRadius.borderMd,
            boxShadow: context.shadowMedium,
          ),
          child: ClipRRect(
            borderRadius: DsRadius.borderSm,
            child: CachedNetworkImage(
              imageUrl: MediaVariants.thumb(product.coverUrl!),
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  ColoredBox(color: context.dsColors.shimmerBase),
              errorWidget: (_, _, _) => const DsMediaFallback(),
            ),
          ),
        ),
      ),
    );
  }
}
