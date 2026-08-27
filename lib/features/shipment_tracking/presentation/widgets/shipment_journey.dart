import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../domain/entities/shipment_tracking.dart';

/// Arabic label for a stage.
String shipmentStageLabel(BuildContext context, ShipmentStage stage) {
  final l10n = context.l10n;
  return switch (stage) {
    ShipmentStage.created => l10n.shipStageCreated,
    ShipmentStage.assigned => l10n.shipStageAssigned,
    ShipmentStage.pickedUp => l10n.shipStagePickedUp,
    ShipmentStage.inTransit => l10n.shipStageInTransit,
    ShipmentStage.outForDelivery => l10n.shipStageOutForDelivery,
    ShipmentStage.delivered => l10n.shipStageDelivered,
    ShipmentStage.failed => l10n.shipStageFailed,
    ShipmentStage.returning => l10n.shipStageReturning,
    ShipmentStage.returned => l10n.shipStageReturned,
    ShipmentStage.cancelled => l10n.shipStageCancelled,
    ShipmentStage.unknown => l10n.shipStageCreated,
  };
}

IconData shipmentStageIcon(ShipmentStage stage) => switch (stage) {
  ShipmentStage.created => Icons.inventory_2_outlined,
  ShipmentStage.assigned => Icons.person_pin_circle_outlined,
  ShipmentStage.pickedUp => Icons.local_shipping_outlined,
  ShipmentStage.inTransit => Icons.alt_route_rounded,
  ShipmentStage.outForDelivery => Icons.directions_bike_rounded,
  ShipmentStage.delivered => Icons.check_circle_rounded,
  ShipmentStage.failed => Icons.error_outline_rounded,
  ShipmentStage.returning => Icons.u_turn_left_rounded,
  ShipmentStage.returned => Icons.assignment_return_outlined,
  ShipmentStage.cancelled => Icons.cancel_outlined,
  ShipmentStage.unknown => Icons.circle_outlined,
};

/// The parcel's progress along the happy path.
///
/// Shows the whole journey, not only the parts that have happened — a list of
/// past events answers "what happened" but not "how much longer", which is the
/// question someone opens a tracking screen to ask.
///
/// A parcel in trouble gets no position on the spine: drawing one would
/// suggest progress toward a delivery that is not coming. Those states are
/// surfaced by the banner above instead.
class ShipmentJourney extends StatelessWidget {
  const ShipmentJourney({super.key, required this.tracking});

  final ShipmentTracking tracking;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final current = tracking.journeyIndex;

    // A parcel in trouble has no position on the happy path; the banner above
    // says what happened instead.
    if (current == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: DsSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: DsRadius.borderCard,
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < kShipmentJourney.length; i++)
            Expanded(
              child: _Step(
                stage: kShipmentJourney[i],
                isDone: i <= current,
                isCurrent: i == current,
                // Each step draws the half-connector on either side of its own
                // dot, so two neighbours together span the whole gap. Drawing
                // only one side would leave every gap half empty.
                hasLeading: i > 0,
                hasTrailing: i < kShipmentJourney.length - 1,
                leadingDone: i <= current,
                trailingDone: i < current,
              ),
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.stage,
    required this.isDone,
    required this.isCurrent,
    required this.hasLeading,
    required this.hasTrailing,
    required this.leadingDone,
    required this.trailingDone,
  });

  final ShipmentStage stage;
  final bool isDone;
  final bool isCurrent;
  final bool hasLeading;
  final bool hasTrailing;
  final bool leadingDone;
  final bool trailingDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final accent = isDone ? colors.primary : colors.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: hasLeading
                  ? Container(
                      height: 2,
                      color: leadingDone ? colors.primary : colors.border,
                    )
                  : const SizedBox.shrink(),
            ),
            Container(
              width: isCurrent ? 34 : 28,
              height: isCurrent ? 34 : 28,
              decoration: BoxDecoration(
                color: isDone ? colors.primary : colors.surfaceVariant,
                shape: BoxShape.circle,
                border: isCurrent
                    ? Border.all(color: colors.primary, width: 2)
                    : null,
              ),
              child: Icon(
                shipmentStageIcon(stage),
                size: isCurrent ? 18 : 15,
                color: isDone ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: hasTrailing
                  ? Container(
                      height: 2,
                      color: trailingDone ? colors.primary : colors.border,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.xs),
        Text(
          shipmentStageLabel(context, stage),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            fontSize: DsTypography.labelSmall,
            fontWeight: isCurrent
                ? DsTypography.bold
                : DsTypography.regular,
            color: isCurrent ? colors.onSurface : accent,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
