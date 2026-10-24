import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/settings/domain/entities/address_entity.dart';

/// One saved address.
///
/// This used to render a hardcoded «123 Rose Avenue, Beauty District» four
/// times over, which read as a working address book and was not one. It now
/// shows what she actually saved, in the order the parts of a Syrian address
/// are usually given: the place, then what it is near.
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
    final colors = context.dsColors;
    final landmark = address.landmark?.trim() ?? '';

    return ClipRRect(
      borderRadius: DsRadius.borderXxxl,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: DsBlur.light, sigmaY: DsBlur.light),
        child: Container(
          padding: const EdgeInsets.all(DsSpacing.lg),
          decoration: BoxDecoration(
            gradient: context.ds.glassGradient,
            borderRadius: DsRadius.borderXxxl,
            border: Border.all(
              color: address.isDefault ? colors.primary : colors.glassBorder,
              width: address.isDefault ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      address.isRural
                          ? Icons.holiday_village_rounded
                          : Icons.location_on_rounded,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: DsSpacing.md),
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
                                style: context.dsText.tileTitle.bold.tint(colors.onSurface),
                              ),
                            ),
                            if (address.isDefault) ...[
                              const SizedBox(width: DsSpacing.sm),
                              _Pill(
                                label: context.l10n.settingsAddressDefault,
                                color: colors.primary,
                              ),
                            ],
                          ],
                        ),
                        DsGaps.vXs,
                        Text(
                          address.summary,
                          style: context.dsText.body.tint(colors.onSurfaceVariant).copyWith(height: 1.4),
                        ),
                        if (landmark.isNotEmpty) ...[
                          DsGaps.vXxs,
                          Text(
                            context.l10n.settingsAddressNear(landmark),
                            style: context.dsText.caption.tint(colors.onSurfaceVariant),
                          ),
                        ],
                        DsGaps.vXs,
                        Text(
                          '${address.recipientName} · ${address.recipientPhone}',
                          style: context.dsText.caption.tint(colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (onEdit != null || onDelete != null || onMakeDefault != null)
                Padding(
                  padding: const EdgeInsets.only(top: DsSpacing.md),
                  // A `Row` with a `Spacer` between «اجعليه الافتراضي» and the
                  // two edit/delete actions ran off both edges of a narrow
                  // phone — three labelled buttons do not fit on one line in
                  // Arabic. A `Wrap` puts the third on its own line instead of
                  // painting the overflow stripe.
                  child: Wrap(
                    spacing: DsSpacing.md,
                    runSpacing: DsSpacing.xs,
                    children: [
                      if (onMakeDefault != null && !address.isDefault)
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
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm, vertical: DsSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: DsRadius.borderFull,
      ),
      child: Text(
        label,
        style: context.dsText.caption.semibold.tint(color),
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
    final colors = context.dsColors;
    final tint = danger ? colors.error : colors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: DsRadius.borderFull,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs, vertical: DsSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: tint),
            DsGaps.hXs,
            Text(
              label,
              style: context.dsText.caption.semibold.tint(tint),
            ),
          ],
        ),
      ),
    );
  }
}
