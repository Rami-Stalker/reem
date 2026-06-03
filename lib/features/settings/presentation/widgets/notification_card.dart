import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

class NotificationCard extends StatefulWidget {
  const NotificationCard({
    super.key,
    required this.title,
    this.initialValue = true,
  });

  final String title;
  final bool initialValue;

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  late bool _enabled = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return ClipRRect(
      borderRadius: DsRadius.borderXxxl,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: DsBlur.light, sigmaY: DsBlur.light),
        child: Container(
          padding: DsSpacing.paddingLg,
          decoration: BoxDecoration(
            color: colors.glass.withValues(alpha: DsOpacity.medium),
            borderRadius: DsRadius.borderXxxl,
            border: Border.all(color: colors.glassBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: DsTypography.semiBold,
                      ),
                ),
              ),
              Switch(
                value: _enabled,
                activeThumbColor: colors.onPrimary,
                activeTrackColor: colors.primary,
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// @deprecated Use [NotificationCard].
typedef NotificationTile = NotificationCard;
