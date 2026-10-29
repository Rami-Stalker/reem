import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/settings/domain/entities/address_entity.dart';

/// One saved address, as a keepsake card on her vanity.
///
/// It shows what she actually saved, in the order the parts of a Syrian
/// address are usually given: the place, then what it is near. Its mark is a
/// small arched window holding a house or a village; the one she ships to by
/// default wears a champagne frame and a gold seal.
class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.address,
    this.onEdit,
    this.onDelete,
    this.onMakeDefault,
  });

  final AddressEntity address;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMakeDefault;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final landmark = address.landmark?.trim() ?? '';
    final chosen = address.isDefault;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderXxl,
        border: Border.all(
          color: chosen ? palette.gold : palette.line,
          width: chosen ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (chosen ? palette.gold : palette.primary).withValues(
              alpha: 0.12,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: DsSpacing.paddingMd,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Window(rural: address.isRural, chosen: chosen),
                DsGaps.hMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              address.label,
                              overflow: TextOverflow.ellipsis,
                              style: context
                                  .dsText
                                  .sectionTitle
                                  .displayFamily
                                  .bold
                                  .tint(palette.ink),
                            ),
                          ),
                          if (chosen) ...[
                            DsGaps.hSm,
                            _Seal(label: context.l10n.settingsAddressDefault),
                          ],
                        ],
                      ),
                      DsGaps.vXs,
                      Text(
                        address.summary,
                        style: context.dsText.body
                            .tint(palette.ink)
                            .copyWith(height: 1.45),
                      ),
                      if (landmark.isNotEmpty) ...[
                        DsGaps.vXxs,
                        Row(
                          children: [
                            Icon(
                              Icons.near_me_outlined,
                              size: DsSizes.iconXs,
                              color: palette.gold,
                            ),
                            DsGaps.hXxs,
                            Expanded(
                              child: Text(
                                context.l10n.settingsAddressNear(landmark),
                                style: context.dsText.caption.tint(
                                  palette.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      DsGaps.vXs,
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: DsSizes.iconXs,
                            color: palette.gold,
                          ),
                          DsGaps.hXxs,
                          Expanded(
                            child: Text(
                              '${address.recipientName} · '
                              '\u2066${address.recipientPhone}\u2069',
                              style: context.dsText.caption.tint(palette.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null || onDelete != null || onMakeDefault != null)
            Container(
              decoration: BoxDecoration(
                color: palette.primarySoft.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(DsRadius.xxl),
                ),
                border: Border(top: BorderSide(color: palette.line)),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.sm,
                vertical: DsSpacing.xxs,
              ),
              // Three labelled actions do not fit on one line of a narrow
              // phone in Arabic, so they wrap rather than overflow.
              child: Wrap(
                spacing: DsSpacing.xs,
                children: [
                  if (onMakeDefault != null && !chosen)
                    _Action(
                      icon: Icons.star_outline_rounded,
                      label: context.l10n.settingsMakeDefault,
                      onTap: onMakeDefault!,
                    ),
                  if (onEdit != null)
                    _Action(
                      icon: Icons.edit_outlined,
                      label: context.l10n.settingsEdit,
                      onTap: onEdit!,
                    ),
                  if (onDelete != null)
                    _Action(
                      icon: Icons.delete_outline_rounded,
                      label: context.l10n.settingsDelete,
                      onTap: onDelete!,
                      danger: true,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The card's mark: a small arched window with a house or a village in it.
class _Window extends StatelessWidget {
  const _Window({required this.rural, required this.chosen});

  final bool rural;
  final bool chosen;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return SizedBox(
      width: 52,
      height: 62,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(
            clipper: const DsArchClipper(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [palette.primarySoft, palette.goldSoft],
                ),
              ),
              child: Icon(
                rural ? Icons.holiday_village_rounded : Icons.home_rounded,
                color: palette.primary,
                size: DsSizes.iconMd,
              ),
            ),
          ),
          CustomPaint(
            painter: _ArchFrame(color: chosen ? palette.gold : palette.line),
          ),
        ],
      ),
    );
  }
}

class _ArchFrame extends CustomPainter {
  const _ArchFrame({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      dsArchPath(Offset.zero & size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ArchFrame old) => old.color != color;
}

/// The gold seal on the address she ships to by default.
class _Seal extends StatelessWidget {
  const _Seal({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: DsSpacing.xxxs,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DsColors.gold200, DsColors.gold400],
        ),
        borderRadius: DsRadius.borderPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            size: DsSizes.iconXs,
            color: DsColors.gold700,
          ),
          DsGaps.hXxs,
          Text(
            label,
            style: context.dsText.caption.semibold.tint(DsColors.gold700),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final tint = danger ? palette.critical : palette.primary;

    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: tint,
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: DsSizes.iconXs),
      label: Text(label, style: context.dsText.caption.semibold.tint(tint)),
    );
  }
}
