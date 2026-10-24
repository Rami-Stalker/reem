import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `intl` exports a TextDirection of its own; the one meant here is the
// framework's, used to pin document codes left-to-right.
import 'package:intl/intl.dart' hide TextDirection;

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/utils/arabic_numerals.dart';
import 'package:ohara/features/shipment_tracking/domain/entities/shipment_tracking.dart';
import 'package:ohara/features/shipment_tracking/presentation/providers/shipment_tracking_provider.dart';
import 'package:ohara/features/shipment_tracking/presentation/widgets/shipment_journey.dart';

/// Q64 — «تتبع الشحنة للزبونة».
///
/// Answers three questions in the order they are asked: where is it, when will
/// it arrive, and what has happened so far. A parcel in trouble says so at the
/// top rather than leaving her to infer it from a timeline.
class ShipmentTrackingScreen extends ConsumerWidget {
  const ShipmentTrackingScreen({super.key, required this.trackingCode});

  final String trackingCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(shipmentTrackingProvider(trackingCode));

    return OharaScrollPage(
      onRefresh: () async =>
          ref.invalidate(shipmentTrackingProvider(trackingCode)),
      slivers: [
        PremiumAppBar(title: l10n.trackShipment, showBack: true),
        ...async.when(
          loading: () => const [
            SliverToBoxAdapter(child: _TrackingSkeleton()),
          ],
          error: (_, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
                child: DsErrorState(
                  message: l10n.trackNotFound,
                  onRetry: () =>
                      ref.invalidate(shipmentTrackingProvider(trackingCode)),
                ),
              ),
            ),
          ],
          data: (tracking) => _content(context, tracking),
        ),
        DsGaps.sliverBottomSafe,
      ],
    );
  }

  List<Widget> _content(BuildContext context, ShipmentTracking tracking) {
    return [
      SliverToBoxAdapter(child: _StatusHeader(tracking: tracking)),
      const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.lg)),

      if (tracking.journeyIndex != null) ...[
        _sectionTitle(context, context.l10n.trackJourney),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            child: ShipmentJourney(tracking: tracking),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.xl)),
      ],

      if (tracking.events.isNotEmpty) ...[
        _sectionTitle(context, context.l10n.trackHistory),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            child: _History(events: tracking.events),
          ),
        ),
      ],
    ];
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.lg,
          DsSpacing.xxxs,
          DsSpacing.lg,
          DsSpacing.md,
        ),
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: DsTypography.bold),
        ),
      ),
    );
  }
}

/// Where it is now, and the code she can quote down a phone line.
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.tracking});

  final ShipmentTracking tracking;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    final trouble = tracking.stage.isTrouble;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(DsSpacing.lg),
        decoration: BoxDecoration(
          color: trouble
              ? colors.warningContainer
              : (tracking.isDelivered
                    ? colors.successContainer
                    : colors.surfaceElevated),
          borderRadius: DsRadius.borderCard,
          border: Border.all(
            color: trouble
                ? colors.warning.withValues(alpha: 0.4)
                : colors.border.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  shipmentStageIcon(tracking.stage),
                  size: 22,
                  color: trouble
                      ? colors.warning
                      : (tracking.isDelivered
                            ? colors.success
                            : colors.primary),
                ),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: Text(
                    shipmentStageLabel(context, tracking.stage),
                    style: context.dsText.cardTitle.bold.tint(colors.onSurface),
                  ),
                ),
                if (tracking.isExpress)
                  DsBadge(
                    label: l10n.trackExpress,
                    tone: DsBadgeTone.info,
                  ),
              ],
            ),

            const SizedBox(height: DsSpacing.md),
            _Row(
              label: l10n.trackingCode,
              // A code is read out loud; forcing it left-to-right stops the
              // letters and digits reordering against the Arabic around them.
              value: tracking.trackingCode,
              isCode: true,
            ),
            _Row(
              label: l10n.invoiceOrderNumber,
              value: tracking.orderNumber,
              isCode: true,
            ),
            // The company carrying it, and their own number for her box. Ohara
            // hands the parcel over; from there the answer to "where is it" is
            // partly theirs, and she should be able to ask them directly.
            if (tracking.carrier != null) ...[
              _Row(
                label: l10n.deliveryCarrier,
                value: tracking.carrier!.name,
              ),
              if (tracking.carrier!.trackingNumber != null)
                _Row(
                  label: l10n.deliveryCarrierTracking,
                  value: tracking.carrier!.trackingNumber!,
                  isCode: true,
                ),
            ],
            if (tracking.scheduledFor != null)
              _Row(
                label: l10n.trackScheduledFor,
                value: _formatDate(context, tracking.scheduledFor!),
              ),
            if (tracking.deliveredAt != null)
              _Row(
                label: l10n.trackDeliveredAt,
                value: _formatDate(context, tracking.deliveredAt!),
              ),

            // Q37 — she should know the courier has already been.
            if (tracking.hasFailedAttempt) ...[
              const SizedBox(height: DsSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.replay_rounded,
                    size: 15,
                    color: colors.warning,
                  ),
                  const SizedBox(width: DsSpacing.xxs),
                  Text(
                    l10n.trackAttempts(tracking.attemptCount),
                    style: context.dsText.caption.semibold.tint(colors.warning),
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

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.isCode = false});

  final String label;
  final String value;
  final bool isCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.xxs),
      child: Row(
        children: [
          Text(
            label,
            style: context.dsText.caption.tint(colors.onSurfaceVariant),
          ),
          const Spacer(),
          if (isCode)
            Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                value,
                style: context.dsText.bodySmall.bold.tint(colors.onSurface).copyWith(letterSpacing: 0.5),
              ),
            )
          else
            Text(
              value,
              style: context.dsText.bodySmall.semibold.tint(colors.onSurface),
            ),
        ],
      ),
    );
  }
}

/// Everything that has happened, newest last so it reads as a story.
class _History extends StatelessWidget {
  const _History({required this.events});

  final List<ShipmentEvent> events;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: DsSpacing.xxs),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i < events.length - 1)
                      Expanded(
                        child: Container(width: 2, color: colors.divider),
                      ),
                  ],
                ),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: DsSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shipmentStageLabel(context, events[i].stage),
                          style: context.dsText.bodySmall.semibold.tint(colors.onSurface),
                        ),
                        Text(
                          _formatDateTime(context, events[i].at),
                          style: context.dsText.caption.tint(colors.onSurfaceVariant),
                        ),
                        if (events[i].note != null &&
                            events[i].note!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: DsSpacing.xxxs),
                            child: Text(
                              events[i].note!,
                              style: context.dsText.caption.tint(colors.onSurfaceVariant).copyWith(height: 1.4),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrackingSkeleton extends StatelessWidget {
  const _TrackingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(DsSpacing.lg),
      child: DsShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsSkeleton.box(height: 140, borderRadius: DsRadius.card),
            SizedBox(height: DsSpacing.xl),
            DsSkeleton.box(height: 110, borderRadius: DsRadius.card),
            SizedBox(height: DsSpacing.xl),
            DsSkeleton.line(width: 100),
            SizedBox(height: DsSpacing.md),
            DsSkeleton.box(height: 60, borderRadius: DsRadius.lg),
          ],
        ),
      ),
    );
  }
}

String _formatDate(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).languageCode;
  return toWesternDigits(DateFormat.yMMMd(locale).format(value));
}

String _formatDateTime(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).languageCode;
  return toWesternDigits(DateFormat.yMMMd(locale).add_jm().format(value));
}
