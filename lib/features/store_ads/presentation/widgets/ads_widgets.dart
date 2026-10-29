import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/media/media_decode.dart';
import 'package:ohara/core/media/media_variants.dart';

/// A product photograph for the ads screens, decoded at the size it is drawn.
class AdProductThumb extends StatelessWidget {
  const AdProductThumb({
    super.key,
    required this.url,
    this.size = DsSizes.thumbSm,
  });

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.primarySoft, palette.goldSoft],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_mall_outlined,
          size: DsSizes.iconMd,
          color: palette.primary,
        ),
      ),
    );
    final image = url == null || url!.isEmpty
        ? fallback
        : CachedNetworkImage(
            imageUrl: MediaVariants.thumb(url!),
            fit: BoxFit.cover,
            memCacheWidth: MediaDecode.widthFor(context, size),
            placeholder: (_, _) => fallback,
            errorWidget: (_, _, _) => fallback,
          );
    return ClipRRect(
      borderRadius: DsRadius.borderMd,
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}

/// A small status pill coloured by meaning, never by hand.
class AdStatusPill extends StatelessWidget {
  const AdStatusPill({super.key, required this.label, required this.tone});

  final String label;
  final DsTone tone;

  @override
  Widget build(BuildContext context) {
    final color = context.toneColor(tone);
    return Container(
      padding: DsSpacing.badgePadding,
      decoration: BoxDecoration(
        color: context.toneContainer(tone),
        borderRadius: DsRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: DsSpacing.xs,
            height: DsSpacing.xs,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          DsGaps.hXxs,
          Text(label, style: context.dsText.badge.tint(color)),
        ],
      ),
    );
  }
}

/// One figure and what it measures.
class AdMetricTile extends StatelessWidget {
  const AdMetricTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final tint = accent ?? palette.primary;
    return Container(
      padding: DsSpacing.cardPadding,
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: DsSizes.iconSm, color: tint),
          DsGaps.vXs,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: context.dsText.metricSmall.tint(palette.ink),
            ),
          ),
          DsGaps.vXxs,
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.caption.tint(palette.muted),
          ),
        ],
      ),
    );
  }
}

/// A locked option's invitation: what it needs, as a door rather than a wall.
class AdLockTag extends StatelessWidget {
  const AdLockTag({super.key, required this.tier, required this.label});

  final DsTier tier;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: DsSizes.iconXs,
          color: context.atelier.muted,
        ),
        DsGaps.hXxs,
        Flexible(
          child: DsTierBadge(tier: tier, label: label),
        ),
      ],
    );
  }
}
