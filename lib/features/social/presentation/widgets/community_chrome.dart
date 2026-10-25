import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/open_route.dart';

/// The community's frosted crown: the way back, the gradient title, a door to
/// the reels, and the «اكتشفي / أتابع» switch.
///
/// It floats over the feed rather than pushing it down, so the photographs
/// run up under the glass the way a magazine bleeds its cover — and the
/// switch is always one thumb away, wherever she has scrolled to.
class CommunityHeader extends StatelessWidget {
  const CommunityHeader({
    super.key,
    required this.pages,
    required this.onSelect,
    required this.onOpenReels,
  });

  /// The feed's page controller; the switch's pill follows it while she swipes.
  final PageController pages;
  final ValueChanged<int> onSelect;
  final VoidCallback onOpenReels;

  static const double barHeight = DsSizes.appBarHeight;
  static const double switchHeight = DsSizes.controlMd;

  /// How much of the screen the header covers below the status bar.
  static const double extent = barHeight + switchHeight + DsSpacing.md;

  @override
  Widget build(BuildContext context) {
    final p = context.boutique;
    final text = context.dsText;
    final l10n = context.l10n;
    final top = MediaQuery.paddingOf(context).top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: DsBlur.heavy, sigmaY: DsBlur.heavy),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                p.surface.withValues(alpha: 0.94),
                p.surface.withValues(alpha: 0.72),
              ],
            ),
            border: Border(
              bottom: BorderSide(color: p.line.withValues(alpha: 0.6)),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: barHeight,
                  child: Row(
                    children: [
                      DsGaps.hXs,
                      DsIconButton(
                        icon: DsIcons.back,
                        variant: DsIconButtonVariant.ghost,
                        iconSize: DsSizes.iconSm,
                        color: p.ink,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        onPressed: () => popOrHome(context),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DsSparkle(
                                  size: DsSizes.iconXxs,
                                  color: p.gold,
                                ),
                                DsGaps.hXs,
                                Flexible(
                                  child: DsGradientText(
                                    l10n.socialFeedTitle,
                                    gradient: p.signatureGradient,
                                    style: text.sectionTitle.displayFamily.bold,
                                  ),
                                ),
                                DsGaps.hXs,
                                DsSparkle(
                                  size: DsSizes.iconXxs,
                                  color: p.gold,
                                ),
                              ],
                            ),
                            Text(
                              l10n.socialFeedSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.caption.tint(p.muted),
                            ),
                          ],
                        ),
                      ),
                      DsIconButton(
                        icon: Icons.movie_filter_rounded,
                        variant: DsIconButtonVariant.tonal,
                        iconSize: DsSizes.iconSm,
                        tooltip: l10n.reelsTitle,
                        onPressed: onOpenReels,
                      ),
                      DsGaps.hSm,
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DsSpacing.gutter,
                    DsSpacing.none,
                    DsSpacing.gutter,
                    DsSpacing.md,
                  ),
                  child: CommunitySwitch(
                    pages: pages,
                    onSelect: onSelect,
                    labels: [l10n.socialFeedDiscover, l10n.socialFeedFollowing],
                    icons: const [
                      Icons.auto_awesome_rounded,
                      Icons.favorite_rounded,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A glass capsule with a rose-to-champagne pill that slides between the two
/// halves — and follows her finger while she swipes between them, rather than
/// jumping once the page has settled.
class CommunitySwitch extends StatelessWidget {
  const CommunitySwitch({
    super.key,
    required this.pages,
    required this.onSelect,
    required this.labels,
    required this.icons,
  });

  final PageController pages;
  final ValueChanged<int> onSelect;
  final List<String> labels;
  final List<IconData> icons;

  double _position() {
    if (!pages.hasClients || !pages.position.hasContentDimensions) {
      return pages.initialPage.toDouble();
    }
    return pages.page ?? pages.initialPage.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.boutique;
    final text = context.dsText;
    final count = labels.length;

    return Container(
      height: CommunityHeader.switchHeight,
      padding: const EdgeInsets.all(DsSpacing.xxs),
      decoration: BoxDecoration(
        color: p.primarySoft.withValues(alpha: 0.45),
        borderRadius: DsRadius.borderPill,
        border: Border.all(color: p.primary.withValues(alpha: 0.14)),
      ),
      child: AnimatedBuilder(
        animation: pages,
        builder: (context, _) {
          final position = _position().clamp(0.0, count - 1.0);
          return Stack(
            children: [
              // The pill. Start-to-end, so it reads right-to-left in Arabic
              // exactly as the pages do.
              Align(
                alignment: AlignmentDirectional(
                  count == 1 ? 0 : -1 + 2 * position / (count - 1),
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: p.signatureGradient,
                      borderRadius: DsRadius.borderPill,
                      boxShadow: [
                        BoxShadow(
                          color: p.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: _SwitchSegment(
                        label: labels[i],
                        icon: icons[i],
                        // How much of the pill sits under this half, 0 to 1,
                        // so the ink crossfades as the pill passes.
                        emphasis: (1 - (position - i).abs()).clamp(0.0, 1.0),
                        selected: position.round() == i,
                        onTap: () => onSelect(i),
                        idleColor: p.muted,
                        style: text.labelStrong,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SwitchSegment extends StatelessWidget {
  const _SwitchSegment({
    required this.label,
    required this.icon,
    required this.emphasis,
    required this.selected,
    required this.onTap,
    required this.idleColor,
    required this.style,
  });

  final String label;
  final IconData icon;
  final double emphasis;
  final bool selected;
  final VoidCallback onTap;
  final Color idleColor;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(idleColor, DsColors.onMedia, emphasis)!;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: DsSizes.iconXs, color: color),
              DsGaps.hXs,
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.tint(color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An eyebrow in champagne over a serif heading, closed by a hairline that
/// fades out toward the edge — the community's section voice.
class CommunitySectionHeading extends StatelessWidget {
  const CommunitySectionHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.live = false,
  });

  final String eyebrow;
  final String title;

  /// A pulsing dot before the eyebrow, for what is happening right now.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final p = context.boutique;
    final text = context.dsText;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.none,
        DsSpacing.lg,
        DsSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (live) ...[
                const _LiveDot(),
                DsGaps.hXs,
              ],
              Text(
                eyebrow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.overline.tint(p.gold),
              ),
              DsGaps.hSm,
              Expanded(
                child: Container(
                  height: DsSizes.dividerThickness,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        p.gold.withValues(alpha: 0.7),
                        p.gold.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          DsGaps.vXxxs,
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.sectionTitle.displayFamily.tint(p.ink),
          ),
        ],
      ),
    );
  }
}

/// A rose dot that breathes, for «مباشر الآن».
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: DsDurations.slowest * 2,
  );

  @override
  void initState() {
    super.initState();
    if (!DsReducedMotion.isEnabled) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.boutique;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Container(
        width: DsSpacing.xs,
        height: DsSpacing.xs,
        decoration: BoxDecoration(
          color: p.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: p.primary.withValues(alpha: 0.2 + 0.35 * _pulse.value),
              blurRadius: 2 + 6 * _pulse.value,
              spreadRadius: 1 + 2 * _pulse.value,
            ),
          ],
        ),
      ),
    );
  }
}

/// A card for a moment with nothing to scroll: signed out of «أتابع», or
/// following nobody yet. A gradient medallion, two lines, and the way on.
class CommunityInviteCard extends StatelessWidget {
  const CommunityInviteCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.actionIcon,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final IconData? actionIcon;
  final VoidCallback onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  static const double _medallion = DsSizes.avatarHero;

  @override
  Widget build(BuildContext context) {
    final p = context.boutique;
    final text = context.dsText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.xl,
          DsSpacing.xxl,
          DsSpacing.xl,
          DsSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.86),
          borderRadius: DsRadius.borderXxxl,
          border: Border.all(color: p.gold.withValues(alpha: 0.35)),
          boxShadow: p.shadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _medallion,
              height: _medallion,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: p.signatureGradient,
                boxShadow: DsShadows.glow(p.primary, blur: 28, alpha: 0.35),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: DsSizes.iconXl, color: DsColors.onMedia),
                  PositionedDirectional(
                    top: DsSpacing.md,
                    end: DsSpacing.md,
                    child: DsSparkle(
                      size: DsSizes.iconXxs,
                      color: DsColors.onMedia,
                    ),
                  ),
                ],
              ),
            ),
            DsGaps.vLg,
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.screenTitle.displayFamily.tint(p.ink),
            ),
            DsGaps.vXs,
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMuted,
            ),
            DsGaps.vXl,
            DsButton(
              label: actionLabel,
              icon: actionIcon,
              onPressed: onAction,
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              DsGaps.vXs,
              DsButton(
                label: secondaryLabel!,
                variant: DsButtonVariant.ghost,
                onPressed: onSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What sits under the last card: the next page arriving, a way to ask for it
/// again when it did not, or a quiet ornament that says she has seen it all.
class CommunityFeedFooter extends StatelessWidget {
  const CommunityFeedFooter({
    super.key,
    required this.isLoadingMore,
    required this.hasMore,
    required this.failed,
    required this.onRetry,
    required this.onBackToTop,
  });

  final bool isLoadingMore;
  final bool hasMore;
  final bool failed;
  final VoidCallback onRetry;
  final VoidCallback onBackToTop;

  @override
  Widget build(BuildContext context) {
    final p = context.boutique;
    final text = context.dsText;
    final l10n = context.l10n;

    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(DsSpacing.xl),
        child: DsLoadingIndicator(),
      );
    }

    if (failed && hasMore) {
      return Padding(
        padding: const EdgeInsets.all(DsSpacing.xl),
        child: Column(
          children: [
            Text(l10n.socialFeedLoadMoreFailed, style: text.bodyMuted),
            DsGaps.vSm,
            DsButton(
              label: l10n.retry,
              icon: Icons.refresh_rounded,
              variant: DsButtonVariant.secondary,
              size: DsButtonSize.sm,
              isExpanded: false,
              onPressed: onRetry,
            ),
          ],
        ),
      );
    }

    if (hasMore) return DsGaps.vXl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.xl,
        DsSpacing.lg,
        DsSpacing.xl,
        DsSpacing.none,
      ),
      child: Column(
        children: [
          DsOrnamentDivider(color: p.gold),
          Text(
            l10n.socialFeedCaughtUp,
            style: text.cardTitle.displayFamily.tint(p.ink),
          ),
          DsGaps.vXxs,
          Text(
            l10n.socialFeedCaughtUpBody,
            textAlign: TextAlign.center,
            style: text.caption,
          ),
          DsGaps.vSm,
          DsButton(
            label: l10n.socialFeedBackToTop,
            icon: Icons.arrow_upward_rounded,
            variant: DsButtonVariant.ghost,
            size: DsButtonSize.sm,
            isExpanded: false,
            onPressed: onBackToTop,
          ),
        ],
      ),
    );
  }
}

/// «شاركي إطلالتك» — the community's one loud control, a rose-to-champagne
/// pill that steps aside while she reads and comes back when she pauses.
class ShareLookButton extends StatelessWidget {
  const ShareLookButton({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.boutique;
    final text = context.dsText;
    final label = context.l10n.socialFeedShareLook;

    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 2),
      duration: DsReducedMotion.duration(DsDurations.moderate),
      curve: DsCurves.emphasized,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: DsReducedMotion.duration(DsDurations.normal),
        child: IgnorePointer(
          ignoring: !visible,
          child: DsScaleAnimations.tapScale(
            onTap: onPressed,
            semanticLabel: label,
            child: Container(
              height: DsSizes.controlLg,
              padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
              decoration: BoxDecoration(
                gradient: p.signatureGradient,
                borderRadius: DsRadius.borderPill,
                border: Border.all(
                  color: DsColors.onMedia.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: p.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_a_photo_rounded,
                    size: DsSizes.iconSm,
                    color: DsColors.onMedia,
                  ),
                  DsGaps.hXs,
                  Text(label, style: text.button.tint(DsColors.onMedia)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
