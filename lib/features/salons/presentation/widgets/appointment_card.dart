import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/salons/domain/entities/appointment.dart';
import 'package:reem/features/salons/presentation/widgets/salon_labels.dart';

/// One booking, on a list.
///
/// The status is the first thing on the card, because it is the first thing
/// she wants to know: whether she has an appointment on Thursday or merely
/// asked for one.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onTap,
    this.showCustomer = false,
  });

  final Appointment appointment;
  final VoidCallback? onTap;

  /// The salon's queue shows who is coming; her own list does not, because she
  /// knows who she is.
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final when = appointment.startsAt.toLocal();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SurfaceCard(
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                AppointmentStatusBadge(status: appointment.status),
                const Spacer(),
                Text(
                  appointment.reference,
                  style: context.dsText.micro.tint(c.onSurfaceVariant),
                ),
              ],
            ),
            DsGaps.vSm,
            Text(
              appointment.serviceName,
              style: context.dsText.tileTitle.semibold.tint(c.onSurface),
            ),
            DsGaps.vXxxs,
            Text(
              showCustomer
                  ? appointment.customer?.name ?? 'عميلة'
                  : appointment.salon?.name ?? '',
              style: context.dsText.cardSubtitle.tint(c.onSurfaceVariant),
            ),
            DsGaps.vSm,
            Row(
              children: [
                Icon(
                  Icons.event_rounded,
                  size: 15,
                  color: appointment.status.isLive ? c.primary : c.onSurfaceVariant,
                ),
                const SizedBox(width: DsSpacing.xxs),
                Expanded(
                  child: Text(
                    // «غداً · ٦:٣٠ م» for anything close, a full date beyond
                    // that. She does not need the word "Thursday" for tomorrow.
                    '${SalonLabels.relativeDay(when)} · ${SalonLabels.time(when)}',
                    style: context.dsText.body.semibold.tint(
                      appointment.status.isLive ? c.onSurface : c.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  appointment.price.format(),
                  style: DsTypography.price(
                    c.price,
                    size: DsTypography.bodySmall,
                  ),
                ),
              ],
            ),
            if (appointment.atHome) ...[
              DsGaps.vXs,
              Row(
                children: [
                  Icon(Icons.home_outlined, size: 14, color: c.primary),
                  const SizedBox(width: DsSpacing.xxs),
                  Text(
                    'خدمة منزلية',
                    style: context.dsText.caption.tint(c.primary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The status, as a badge.
///
/// Five states with five tones: a cancelled appointment must not look like a
/// confirmed one glanced at quickly.
class AppointmentStatusBadge extends StatelessWidget {
  const AppointmentStatusBadge({super.key, required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    return DsBadge(
      label: SalonLabels.status(status),
      tone: switch (status) {
        AppointmentStatus.pending => DsBadgeTone.warning,
        AppointmentStatus.confirmed => DsBadgeTone.success,
        AppointmentStatus.completed => DsBadgeTone.info,
        AppointmentStatus.cancelled => DsBadgeTone.neutral,
        AppointmentStatus.noShow => DsBadgeTone.sale,
      },
    );
  }
}
