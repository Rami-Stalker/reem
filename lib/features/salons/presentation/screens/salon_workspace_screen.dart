import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/salons/data/datasources/salons_remote_datasource.dart';
import 'package:ohara/features/salons/domain/entities/salon.dart';
import 'package:ohara/features/salons/presentation/providers/salons_providers.dart';

/// «صالوني» — the owner's side of «الصالونات والجمال».
///
/// Deliberately a *hub* rather than a dashboard. An owner opens this to do one
/// of four things — see who is coming, change the menu, change the hours, or
/// fix her own details — so the screen is four doors and the numbers that tell
/// her which one to walk through.
///
/// It lives beside the seller workspace rather than replacing it: an account
/// can sell dresses and run a salon, and neither hides the other.
class SalonWorkspaceScreen extends ConsumerWidget {
  const SalonWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final async = ref.watch(mySalonProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: OharaAppBar(title: context.l10n.salonMySalon),
      body: async.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.salonWorkspaceLoadError,
          onRetry: () => ref.invalidate(mySalonProvider),
        ),
        // Null is the ordinary answer for an account that has not opened one,
        // not a failure — so it gets an invitation rather than an error.
        data: (salon) => salon == null
            ? const _NoSalonYet()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(mySalonProvider),
                child: _Hub(salon: salon),
              ),
      ),
    );
  }
}

class _NoSalonYet extends StatelessWidget {
  const _NoSalonYet();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: DsSpacing.xxxl),
        DsEmptyState(
          icon: Icons.storefront_outlined,
          title: context.l10n.salonOpenOnOhara,
          message: context.l10n.salonOpenOnOharaBody,
          actionLabel: context.l10n.salonStart,
          onAction: () => unawaited(context.push(RoutePaths.salonEditor)),
        ),
      ],
    );
  }
}

class _Hub extends ConsumerWidget {
  const _Hub({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final live = salon.services.where((service) => service.isActive).length;

    return ListView(
      padding: const EdgeInsets.all(DsSpacing.lg),
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(DsSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      salon.name,
                      style: context.dsText.sectionTitle.tint(c.onSurface),
                    ),
                  ),
                  DsBadge(
                    label: switch (salon.status) {
                      SalonStatus.active => context.l10n.salonPublished,
                      SalonStatus.draft => context.l10n.salonDraft,
                      SalonStatus.suspended => context.l10n.salonSuspended,
                    },
                    tone: switch (salon.status) {
                      SalonStatus.active => DsBadgeTone.success,
                      SalonStatus.draft => DsBadgeTone.neutral,
                      SalonStatus.suspended => DsBadgeTone.sale,
                    },
                  ),
                ],
              ),
              DsGaps.vXxxs,
              Text(
                salon.area,
                style: context.dsText.cardSubtitle.tint(c.onSurfaceVariant),
              ),
              DsGaps.vMd,
              Row(
                children: [
                  _Stat(
                    value: salon.rating > 0
                        ? salon.rating.toStringAsFixed(1)
                        : '—',
                    label: context.l10n.salonRating,
                  ),
                  _Stat(value: '$live', label: context.l10n.salonStatServices),
                  _Stat(
                    value: '${salon.appointmentsCount}',
                    label: context.l10n.salonStatBookings,
                  ),
                  _Stat(
                    value: '${salon.reviewsCount}',
                    label: context.l10n.salonStatReviews,
                  ),
                ],
              ),
            ],
          ),
        ),

        // A salon with no services or no hours cannot be booked. The hub says
        // so here rather than letting her discover it from silence.
        DsGaps.vMd,
        ..._blockers(context, ref, live),

        DsGaps.vLg,
        _Door(
          icon: Icons.event_note_rounded,
          title: context.l10n.salonAppointments,
          subtitle: context.l10n.salonAppointmentsSubtitle,
          onTap: () => unawaited(context.push(RoutePaths.salonQueue)),
        ),
        DsGaps.vSm,
        _Door(
          icon: Icons.spa_outlined,
          title: context.l10n.salonServicesAndPrices,
          subtitle: context.l10n.salonActiveServicesCount(live),
          onTap: () => unawaited(context.push(RoutePaths.salonServicesEditor)),
        ),
        DsGaps.vSm,
        _Door(
          icon: Icons.schedule_rounded,
          title: context.l10n.salonWorkingHours,
          subtitle: context.l10n.salonHoursSubtitle,
          onTap: () => unawaited(context.push(RoutePaths.salonHoursEditor)),
        ),
        DsGaps.vSm,
        _Door(
          icon: Icons.storefront_outlined,
          title: context.l10n.salonEditorTitle,
          subtitle: context.l10n.salonDetailsSubtitle,
          onTap: () => unawaited(context.push(RoutePaths.salonEditor)),
        ),

        DsGaps.vLg,
        DsButton(
          label: context.l10n.salonPreviewAsCustomer,
          icon: Icons.visibility_outlined,
          variant: DsButtonVariant.ghost,
          onPressed: () =>
              unawaited(context.push(RoutePaths.salonOf(salon.slug))),
        ),
      ],
    );
  }

  /// One blocker at a time, in the order they have to be solved: a salon with
  /// no services does not need to hear about its hours yet.
  List<Widget> _blockers(BuildContext context, WidgetRef ref, int live) {
    if (live == 0) {
      return [
        _Warning(
          message: context.l10n.salonNoActiveServices,
          actionLabel: context.l10n.salonAddService,
          onAction: () =>
              unawaited(context.push(RoutePaths.salonServicesEditor)),
        ),
      ];
    }
    if (salon.hours.isEmpty || salon.hours.every((day) => day.isClosed)) {
      return [
        _Warning(
          message: context.l10n.salonNoHoursSet,
          actionLabel: context.l10n.salonSetHours,
          onAction: () => unawaited(context.push(RoutePaths.salonHoursEditor)),
        ),
      ];
    }
    if (!salon.status.isLive) {
      return [
        _Warning(
          message: context.l10n.salonNotPublished,
          actionLabel: context.l10n.salonPublish,
          onAction: () => unawaited(_publish(context, ref)),
        ),
      ];
    }
    return const [];
  }

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    try {
      // Publishing is a one-field change, but the endpoint takes the whole
      // draft — so the current values go back beside it, untouched.
      await ref
          .read(salonOwnerActionsProvider)
          .save(
            SalonDraft(
              name: salon.name,
              governorate: salon.governorate,
              city: salon.city,
              addressLine: salon.addressLine ?? '',
              publish: true,
            ),
          );
      if (!context.mounted) return;
      DsSnackbar.success(context, context.l10n.salonPublishedDone);
    } catch (_) {
      if (!context.mounted) return;
      DsSnackbar.error(context, context.l10n.salonPublishFailed);
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: context.dsText.cardTitle.tint(c.onSurface)),
          DsGaps.vXxxs,
          Text(label, style: context.dsText.caption.tint(c.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.10),
        borderRadius: DsRadius.borderLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: c.warning),
              const SizedBox(width: DsSpacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: context.dsText.body.tint(c.onSurface),
                ),
              ),
            ],
          ),
          DsGaps.vXs,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DsButton(
              label: actionLabel,
              size: DsButtonSize.sm,
              isExpanded: false,
              variant: DsButtonVariant.tonal,
              onPressed: onAction,
            ),
          ),
        ],
      ),
    );
  }
}

class _Door extends StatelessWidget {
  const _Door({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.10),
              borderRadius: DsRadius.borderMd,
            ),
            child: Icon(icon, size: 20, color: c.primary),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.dsText.tileTitle.semibold.tint(c.onSurface),
                ),
                DsGaps.vXxxs,
                Text(
                  subtitle,
                  style: context.dsText.caption.tint(c.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: c.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
