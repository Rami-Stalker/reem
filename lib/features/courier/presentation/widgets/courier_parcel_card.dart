import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/courier/domain/entities/courier_assignment.dart';
import 'package:reem/features/shipment_tracking/presentation/widgets/shipment_journey.dart';
import 'package:url_launcher/url_launcher.dart';

/// One parcel on the round.
///
/// Built for someone standing on a doorstep holding a phone in one hand: the
/// amount to collect and the address are the two things readable at a glance,
/// the call button is a thumb-sized target, and only the action that is
/// actually possible next is shown — a courier should never have to work out
/// which of four buttons applies.
class CourierParcelCard extends StatelessWidget {
  const CourierParcelCard({
    super.key,
    required this.assignment,
    required this.isBusy,
    required this.onPickUp,
    required this.onStartDelivery,
    required this.onDeliver,
    required this.onFail,
  });

  final CourierAssignment assignment;
  final bool isBusy;
  final VoidCallback onPickUp;
  final VoidCallback onStartDelivery;
  final VoidCallback onDeliver;
  final VoidCallback onFail;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: DsRadius.borderCard,
        border: Border.all(
          color: assignment.isExpress
              ? colors.primary.withValues(alpha: 0.45)
              : colors.border.withValues(alpha: 0.6),
          width: assignment.isExpress ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Who and where ────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            assignment.recipient.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.dsText.body.bold.tint(colors.onSurface),
                          ),
                        ),
                        if (assignment.isExpress) ...[
                          const SizedBox(width: DsSpacing.xs),
                          DsBadge(
                            label: l10n.trackExpress,
                            tone: DsBadgeTone.primary,
                          ),
                        ],
                      ],
                    ),
                    DsGaps.vXxxs,
                    Text(
                      assignment.address.oneLine,
                      style: context.dsText.bodySmall.tint(colors.onSurfaceVariant).copyWith(height: 1.4),
                    ),
                    if (assignment.address.landmark != null)
                      Text(
                        assignment.address.landmark!,
                        style: context.dsText.caption.tint(colors.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              _StageChip(assignment: assignment),
            ],
          ),

          // ── What to collect ──────────────────────────────────────────
          const SizedBox(height: DsSpacing.sm),
          _CollectionLine(assignment: assignment),

          // Q55 — «يرى ملاحظات التوصيل مثل اتصل قبل الوصول».
          if (assignment.deliveryInstructions != null &&
              assignment.deliveryInstructions!.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.xs),
            Container(
              padding: const EdgeInsets.all(DsSpacing.xs),
              decoration: BoxDecoration(
                color: colors.infoContainer,
                borderRadius: BorderRadius.circular(DsRadius.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_outlined,
                      size: 14, color: colors.info),
                  const SizedBox(width: DsSpacing.xxs),
                  Expanded(
                    child: Text(
                      assignment.deliveryInstructions!,
                      style: context.dsText.caption.tint(colors.onSurface).copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Q37 — a repeat visit is worth flagging before they set off again.
          if (assignment.hasFailedAttempt && !assignment.isClosed) ...[
            const SizedBox(height: DsSpacing.xs),
            Row(
              children: [
                Icon(Icons.replay_rounded, size: 14, color: colors.warning),
                const SizedBox(width: DsSpacing.xxs),
                Text(
                  l10n.trackAttempts(assignment.attemptCount),
                  style: context.dsText.caption.semibold.tint(colors.warning),
                ),
              ],
            ),
          ],

          // ── Actions ──────────────────────────────────────────────────
          if (!assignment.isClosed) ...[
            const SizedBox(height: DsSpacing.sm),
            Divider(height: 1, color: colors.divider),
            const SizedBox(height: DsSpacing.sm),
            _Actions(
              assignment: assignment,
              isBusy: isBusy,
              onPickUp: onPickUp,
              onStartDelivery: onStartDelivery,
              onDeliver: onDeliver,
              onFail: onFail,
            ),
          ],
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.assignment});

  final CourierAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final trouble = assignment.stage.isTrouble;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.xs,
        vertical: DsSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: trouble
            ? colors.warningContainer
            : (assignment.isClosed
                  ? colors.successContainer
                  : colors.primaryContainer),
        borderRadius: DsRadius.borderFull,
      ),
      child: Text(
        shipmentStageLabel(context, assignment.stage),
        style: context.dsText.caption.bold.tint(trouble
              ? colors.warning
              : (assignment.isClosed
                    ? colors.success
                    : colors.onPrimaryContainer)),
      ),
    );
  }
}

/// The amount due at the door — the single most consequential number on the
/// card, so it is the largest thing on it.
class _CollectionLine extends StatelessWidget {
  const _CollectionLine({required this.assignment});

  final CourierAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;

    if (!assignment.isCod) {
      return Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 15, color: colors.success),
          const SizedBox(width: DsSpacing.xxs),
          Text(
            l10n.courierPrepaid,
            style: context.dsText.bodySmall.semibold.tint(colors.success),
          ),
        ],
      );
    }

    return Row(
      children: [
        Text(
          l10n.courierCollect,
          style: context.dsText.caption.tint(colors.onSurfaceVariant),
        ),
        const SizedBox(width: DsSpacing.xs),
        Text(
          assignment.codAmount!.format(),
          style: context.dsText.tileTitle.bold.tint(colors.price),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.assignment,
    required this.isBusy,
    required this.onPickUp,
    required this.onStartDelivery,
    required this.onDeliver,
    required this.onFail,
  });

  final CourierAssignment assignment;
  final bool isBusy;
  final VoidCallback onPickUp;
  final VoidCallback onStartDelivery;
  final VoidCallback onDeliver;
  final VoidCallback onFail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (isBusy) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: DsSpacing.xs),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            // Q55 — «يتصل بالزبونة بضغطة». First, because it is what a courier
            // reaches for before anything else goes wrong.
            Expanded(
              child: _Secondary(
                icon: Icons.phone_rounded,
                label: l10n.courierCall,
                onTap: () => _launch('tel:${assignment.recipient.phone}'),
              ),
            ),
            const SizedBox(width: DsSpacing.xs),
            Expanded(
              child: _Secondary(
                icon: Icons.map_outlined,
                label: l10n.courierNavigate,
                onTap: () => _launch(
                  'https://www.google.com/maps/search/?api=1&query='
                  '${Uri.encodeComponent(assignment.address.oneLine)}',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.xs),

        // Only the transition the parcel can actually make next. Offering an
        // action the backend will refuse teaches a courier to distrust the app.
        if (assignment.canPickUp)
          _Primary(label: l10n.courierPickUp, onTap: onPickUp)
        else if (assignment.canStartDelivery)
          _Primary(label: l10n.courierStartDelivery, onTap: onStartDelivery)
        else if (assignment.canComplete)
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _Primary(label: l10n.courierDeliver, onTap: onDeliver),
              ),
              const SizedBox(width: DsSpacing.xs),
              Expanded(
                child: _Secondary(
                  icon: Icons.error_outline_rounded,
                  label: l10n.courierFail,
                  onTap: onFail,
                  isDanger: true,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _Primary extends StatelessWidget {
  const _Primary({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DsButton(label: label, onPressed: onTap);
  }
}

class _Secondary extends StatelessWidget {
  const _Secondary({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final accent = isDanger ? colors.error : colors.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(DsRadius.button),
      onTap: onTap,
      child: Container(
        // Tall enough to hit with a thumb while holding a parcel.
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DsRadius.button),
          border: Border.all(
            color: isDanger
                ? colors.error.withValues(alpha: 0.5)
                : colors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: DsSpacing.xxs),
            Text(
              label,
              style: context.dsText.labelMedium.semibold.tint(accent),
            ),
          ],
        ),
      ),
    );
  }
}
