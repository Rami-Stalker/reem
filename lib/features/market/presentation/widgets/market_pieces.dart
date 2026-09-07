import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/market/domain/entities/market.dart';

/// The small parts the market screens share.
///
/// Shared because the vocabulary has to be. A disposition means the same
/// colour on the wardrobe list as it does on a piece's own page, and the
/// reason under a bundle item is styled the same as the reason under a drop —
/// they are the same kind of sentence and reading them as two different kinds
/// is how a coherent product starts to feel assembled.

/// A price, formatted the way every other price in Reem is.
String sypText(double? value) => value == null
    ? '—'
    : Money(raw: value.toString(), currency: Currency.syp).format();

/// The same figure without its symbol, for a column too narrow to hold one.
///
/// «3,500 ل.س» in a third of a card ellipsises to «3,500 ل....», which reads
/// as a broken number rather than a tight column. The symbol moves to the
/// label instead of being cut off.
String sypNumber(double? value) => value == null
    ? '—'
    : Money(
        raw: value.toString(),
        currency: Currency.syp,
      ).format(includeSymbol: false);

/// The one place a disposition becomes a colour.
///
/// Three steps, and the neutral one is the default: most of a wardrobe needs
/// nothing, and a palette that makes "leave it alone" look like a state would
/// turn a wardrobe into a to-do list.
Color dispositionColor(BuildContext context, Disposition disposition) {
  final colors = context.dsColors;
  return switch (disposition) {
    Disposition.keep => colors.onSurfaceVariant,
    Disposition.restyle => colors.info,
    Disposition.resell => colors.primary,
    Disposition.donate => colors.success,
  };
}

IconData dispositionIcon(Disposition disposition) => switch (disposition) {
  Disposition.keep => Icons.check_rounded,
  Disposition.restyle => Icons.auto_awesome_rounded,
  Disposition.resell => Icons.sell_outlined,
  Disposition.donate => Icons.volunteer_activism_outlined,
};

/// A sentence Reem is offering as a reason.
///
/// Always attributed by its shape — a soft dot and the muted ink — so a reason
/// never reads as a fact about the product. It is Reem talking.
class ReasonLine extends StatelessWidget {
  const ReasonLine({
    super.key,
    required this.text,
    this.icon = Icons.auto_awesome_rounded,
    this.tint,
  });

  final String text;
  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final colors = context.dsColors;
    final colour = tint ?? colors.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: colour),
        ),
        DsGaps.hXs,
        Expanded(child: Text(text, style: context.dsText.caption.tint(colour))),
      ],
    );
  }
}

/// A small square image with a graceful nothing.
class MarketThumb extends StatelessWidget {
  const MarketThumb({
    super.key,
    this.imageUrl,
    this.size = 56,
    this.icon = Icons.checkroom_rounded,
  });

  final String? imageUrl;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DsRadius.lg),
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl == null || imageUrl!.isEmpty
            ? ColoredBox(
                color: colors.surfaceVariant,
                child: Icon(
                  icon,
                  size: size * 0.4,
                  color: colors.onSurfaceVariant,
                ),
              )
            : AuthorizedMediaImage(
                url: imageUrl!,
                fallback: ColoredBox(
                  color: colors.surfaceVariant,
                  child: Icon(
                    icon,
                    size: size * 0.4,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
      ),
    );
  }
}

/// A bundle, as a card.
///
/// The shop count is given a line of its own rather than a badge. "من ٣ محلات"
/// is the claim that separates this from a seller's own upsell, and burying it
/// in a corner chip would waste the only sentence that makes the feature
/// interesting.
class BundleCard extends StatelessWidget {
  const BundleCard({super.key, required this.bundle, this.onTap});

  final Bundle bundle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return DsGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bundle.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.cardTitle.tint(colors.onSurface),
                ),
              ),
              if (bundle.occasionLabel != null) ...[
                DsGaps.hXs,
                DsBadge(label: bundle.occasionLabel!),
              ],
            ],
          ),
          DsGaps.vSm,
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bundle.items.length,
              separatorBuilder: (_, _) => DsGaps.hXs,
              itemBuilder: (_, index) =>
                  MarketThumb(imageUrl: bundle.items[index].imageUrl),
            ),
          ),
          DsGaps.vSm,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sypText(bundle.totalSyp),
                      style: DsTypography.price(
                        colors.price,
                        size: DsTypography.titleSmall,
                      ),
                    ),
                    if (bundle.crossesShops)
                      Text(
                        'من ${bundle.sellerCount} محلات — إطلالة كاملة',
                        style: context.dsText.micro.tint(
                          colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${bundle.items.length} قطع',
                style: context.dsText.micro.tint(colors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A drop, as a card.
///
/// When she was invited, the invitation's reason replaces the generic subtitle.
/// That substitution is the feature: a launch that says «لأنو ناقصك شي من
/// هالنوع» is an invitation, and the same launch with a countdown is an
/// advertisement.
class DropCard extends StatelessWidget {
  const DropCard({super.key, required this.drop, this.onTap});

  final Drop drop;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final reason = drop.invitation?.headline ?? '';

    return DsGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  drop.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.cardTitle.tint(colors.onSurface),
                ),
              ),
              if (drop.earlyAccessOnly) ...[
                DsGaps.hXs,
                DsBadge(label: 'وصول مبكر', tone: DsBadgeTone.primary),
              ],
            ],
          ),
          if (reason.isNotEmpty) ...[
            DsGaps.vXs,
            ReasonLine(text: reason, tint: colors.primary),
          ] else if (drop.note != null && drop.note!.isNotEmpty) ...[
            DsGaps.vXs,
            Text(
              drop.note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.dsText.caption.tint(colors.onSurfaceVariant),
            ),
          ],
          DsGaps.vSm,
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: drop.products.length,
              separatorBuilder: (_, _) => DsGaps.hXs,
              itemBuilder: (_, index) => MarketThumb(
                imageUrl: drop.products[index].imageUrl,
                size: 64,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
