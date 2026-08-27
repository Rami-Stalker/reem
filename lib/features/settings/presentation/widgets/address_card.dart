import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/settings/domain/entities/address_entity.dart';

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
                                style: TextStyle(
                                  fontWeight: DsTypography.bold,
                                  fontSize: DsTypography.titleSmall,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                            if (address.isDefault) ...[
                              const SizedBox(width: DsSpacing.sm),
                              _Pill(label: 'الافتراضي', color: colors.primary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          address.summary,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        if (landmark.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'قرب $landmark',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: DsTypography.labelSmall,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          '${address.recipientName} · ${address.recipientPhone}',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: DsTypography.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (onEdit != null || onDelete != null || onMakeDefault != null)
                Padding(
                  padding: const EdgeInsets.only(top: DsSpacing.md),
                  child: Row(
                    children: [
                      if (onMakeDefault != null && !address.isDefault)
                        _Action(
                          icon: Icons.star_outline_rounded,
                          label: 'اجعليه الافتراضي',
                          onTap: onMakeDefault!,
                        ),
                      const Spacer(),
                      if (onEdit != null)
                        _Action(
                          icon: Icons.edit_outlined,
                          label: 'تعديل',
                          onTap: onEdit!,
                        ),
                      if (onDelete != null) ...[
                        const SizedBox(width: DsSpacing.md),
                        _Action(
                          icon: Icons.delete_outline_rounded,
                          label: 'حذف',
                          onTap: onDelete!,
                          danger: true,
                        ),
                      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: DsRadius.borderFull,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: DsTypography.labelSmall,
          fontWeight: DsTypography.semiBold,
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: tint),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: tint,
                fontSize: DsTypography.labelSmall,
                fontWeight: DsTypography.semiBold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
