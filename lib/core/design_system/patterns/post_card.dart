import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/value_objects/money_format.dart';
import 'package:ohara/core/utils/relative_time.dart';

/// Pieces shared by the post card ([DsImmersivePost]) and the product page:
/// the double-tap burst, the horizontal action bar the product page keeps
/// under its gallery, and the short "2h" time.

/// The double-tap reward: one big heart plus a scatter of petals and sparkles.
class DsLoveBurst extends StatelessWidget {
  const DsLoveBurst({super.key, required this.controller, required this.color});

  final AnimationController controller;
  final Color color;

  static const int _petals = 9;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final v = controller.value;
        if (v == 0) return const SizedBox.shrink();

        final pop = Curves.easeOutBack.transform((v / 0.42).clamp(0.0, 1.0));
        final fade =
            1 - Curves.easeIn.transform(((v - 0.5) / 0.5).clamp(0.0, 1.0));
        final spread = Curves.easeOutCubic.transform(v);

        return Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < _petals; i++) _petal(i, spread, fade),
            Opacity(
              opacity: fade,
              child: Transform.scale(
                scale: 0.45 + pop * 0.7,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 104,
                  color: DsColors.onMedia.withValues(alpha: 0.94),
                  shadows: [
                    Shadow(
                      blurRadius: 30,
                      color: color.withValues(alpha: 0.55),
                    ),
                    const Shadow(blurRadius: 18, color: DsColors.mediaScrim),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _petal(int i, double spread, double fade) {
    final angle = (i / _petals) * math.pi * 2 + 0.32;
    final distance = 34 + 82 * spread;
    final size = 9.0 + (i.isEven ? 7 : 3);
    return Transform.translate(
      offset: Offset(math.cos(angle) * distance, math.sin(angle) * distance),
      child: Opacity(
        opacity: fade * 0.9,
        child: Transform.rotate(
          angle: angle,
          child: Icon(
            i.isEven ? Icons.favorite_rounded : Icons.auto_awesome_rounded,
            size: size,
            color: i.isEven ? color : DsColors.onMedia,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

/// Heart, comments, share, «أضيفي إلى صفحتي» — and the bookmark at the end.
class DsPostActionBar extends StatelessWidget {
  const DsPostActionBar({
    super.key,
    required this.liked,
    required this.saved,
    required this.commentsCount,
    required this.sharesCount,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
    this.picked = false,
    this.onPick,
  });

  final bool liked;
  final bool saved;
  final int commentsCount;
  final int sharesCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;

  /// Whether she already added it to her page.
  final bool picked;

  /// «أضيفي إلى صفحتي». Null hides it — her own post cannot go on her page
  /// twice.
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.xs,
        DsSpacing.xs,
        DsSpacing.xs,
        DsSpacing.xxs,
      ),
      child: Row(
        children: [
          _ActionButton(
            icon: liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: liked ? c.favorite : c.onSurface,
            active: liked,
            label: l10n.a11yLike,
            onTap: onLike,
          ),
          _ActionButton(
            icon: Icons.mode_comment_outlined,
            color: c.onSurface,
            label: l10n.comments,
            count: commentsCount > 0 ? formatCount(commentsCount) : null,
            onTap: onComment,
          ),
          _ActionButton(
            icon: Icons.send_rounded,
            color: c.onSurface,
            label: l10n.contentShare,
            count: sharesCount > 0 ? formatCount(sharesCount) : null,
            onTap: onShare,
          ),
          if (onPick != null)
            _ActionButton(
              icon: picked
                  ? Icons.library_add_check_rounded
                  : Icons.add_to_photos_outlined,
              color: picked ? c.primary : c.onSurface,
              active: picked,
              label: l10n.contentAddToMyPage,
              onTap: onPick!,
            ),
          const Spacer(),
          _ActionButton(
            icon: saved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: saved ? c.secondary : c.onSurface,
            active: saved,
            label: l10n.a11ySave,
            onTap: onSave,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.count,
    this.active = false,
  });

  final IconData icon;
  final Color color;

  /// What a screen reader says; the glyph alone says nothing.
  final String label;
  final VoidCallback onTap;
  final String? count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Padding(
          padding: const EdgeInsets.all(DsSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: active ? 1.16 : 1,
                duration: DsMotion.fast,
                curve: DsMotion.softSpring,
                child: Icon(icon, size: DsConstraints.iconMd, color: color),
              ),
              if (count != null) ...[
                const SizedBox(width: DsSpacing.xxs),
                Text(
                  count!,
                  style: context.dsText.label.copyWith(
                    color: context.dsColors.onSurface,
                    fontWeight: DsTypography.medium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// «قبل ساعتين», «قبل 3 أيام» — the time beside a post's author.
///
/// It used to be the compact «2 س», «10 ي», which in a frosted capsule over a
/// photograph read as a stray letter. The full phrase costs a few characters
/// and is never misread.
String dsShortTimeAgo(BuildContext context, DateTime date) =>
    formatRelativeTime(context.l10n, date);
