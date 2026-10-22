import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/market/domain/entities/market.dart';
import 'package:reem/l10n/app_localizations.dart';

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

/// Her reason for an early invitation, in her language.
///
/// Rendered from the code rather than sent as prose because the codes are the
/// contract and a sentence is a presentation choice — the same code reads
/// differently on a card and in a notification.
String dropReasonLabel(AppLocalizations l10n, List<String> reasons) =>
    switch (reasons.isEmpty ? '' : reasons.first) {
      'OPEN_NEED' => l10n.marketReasonOpenNeed,
      'SEARCHED_FOR' => l10n.marketReasonSearchedFor,
      'OCCASION_MATCH' => l10n.marketReasonOccasion,
      'TASTE_MATCH' => l10n.marketReasonTaste,
      'SELLER_CUSTOMER' => l10n.marketReasonSellerCustomer,
      _ => '',
    };

String rotationLabel(AppLocalizations l10n, Rotation rotation) =>
    switch (rotation) {
      Rotation.active => l10n.marketRotationActive,
      Rotation.slowing => l10n.marketRotationSlowing,
      Rotation.dormant => l10n.marketRotationDormant,
      Rotation.unworn => l10n.marketRotationUnworn,
    };

/// Resale condition codes, best first.
const resaleConditions = ['NEW_WITH_TAGS', 'EXCELLENT', 'GOOD', 'FAIR'];

String resaleConditionLabel(AppLocalizations l10n, String code) =>
    switch (code) {
      'NEW_WITH_TAGS' => l10n.marketConditionNew,
      'EXCELLENT' => l10n.marketConditionExcellent,
      'GOOD' => l10n.marketConditionGood,
      'FAIR' => l10n.marketConditionFair,
      _ => code,
    };

String marketOccasionLabel(AppLocalizations l10n, String code) =>
    switch (code) {
      'wedding' => l10n.marketOccasionWedding,
      'evening' => l10n.marketOccasionEvening,
      'eid' => l10n.marketOccasionEid,
      'graduation' => l10n.marketOccasionGraduation,
      'work' => l10n.marketOccasionWork,
      'daily' => l10n.marketOccasionDaily,
      _ => code,
    };

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
                        context.l10n.marketLookFromShopsShort(
                          bundle.sellerCount,
                        ),
                        style: context.dsText.micro.tint(
                          colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                context.l10n.marketPieceCount(bundle.items.length),
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
    final reason = switch (drop.invitation) {
      final invitation? => dropReasonLabel(context.l10n, invitation.reasons),
      null => '',
    };

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
                DsBadge(
                  label: context.l10n.marketEarlyAccess,
                  tone: DsBadgeTone.primary,
                ),
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
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: drop.products.length,
              separatorBuilder: (_, _) => DsGaps.hXs,
              itemBuilder: (_, index) => MarketThumb(
                imageUrl: drop.products[index].imageUrl,
                size: 72,
              ),
            ),
          ),
          DsGaps.vSm,
          _DropTiming(drop: drop),
        ],
      ),
    );
  }
}

/// When the drop opens or closes, said as a span rather than a timestamp.
///
/// A date makes her do arithmetic; «يُفتح بعد ساعتين» is the thing she wants
/// to know, and an early-access invitation says how far ahead she is.
class _DropTiming extends StatelessWidget {
  const _DropTiming({required this.drop});

  final Drop drop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final now = DateTime.now();
    final opensAt = drop.earlyAccessOnly
        ? (drop.earlyAccessAt ?? drop.startsAt)
        : drop.startsAt;

    final (String line, Color tint) = switch (drop) {
      _ when drop.isLive && drop.endsAt != null && drop.endsAt!.isAfter(now) =>
        (
          l10n.marketDropEndsIn(
            timeSpanLabel(l10n, drop.endsAt!.difference(now)),
          ),
          colors.success,
        ),
      _ when drop.isLive || !opensAt.isAfter(now) => (
        l10n.marketDropOpenNow,
        colors.success,
      ),
      _ when drop.earlyAccessOnly && drop.earlyAccessAt != null => (
        l10n.marketDropEarlyBy(
          timeSpanLabel(l10n, drop.startsAt.difference(drop.earlyAccessAt!)),
        ),
        colors.primary,
      ),
      _ => (
        l10n.marketDropOpensIn(timeSpanLabel(l10n, opensAt.difference(now))),
        colors.primary,
      ),
    };
    final from = drop.totalFromSyp;

    return Row(
      children: [
        Container(
          width: DsSpacing.xs,
          height: DsSpacing.xs,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
        ),
        DsGaps.hXs,
        Expanded(
          child: Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.caption.semibold.tint(tint),
          ),
        ),
        if (from != null)
          Text(
            l10n.marketPriceFrom(sypText(from)),
            style: context.dsText.caption.tint(colors.price),
          ),
      ],
    );
  }
}

/// «ساعتين», «3 أيام» — the coarsest unit that still says something.
String timeSpanLabel(AppLocalizations l10n, Duration span) {
  if (span.inMinutes < 60) {
    return l10n.spanMinutes(span.inMinutes < 1 ? 1 : span.inMinutes);
  }
  if (span.inHours < 48) return l10n.spanHours(span.inHours);
  return l10n.spanDays(span.inDays);
}
