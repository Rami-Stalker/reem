import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/closet/domain/entities/closet_look.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_look_card.dart';
import 'package:ohara/features/salons/presentation/providers/salons_providers.dart';
import 'package:ohara/features/salons/presentation/widgets/appointment_card.dart';

/// The two sheets an occasion links things through. Each pops the id of what
/// she chose, and the detail page writes it.

/// Her looks, the ones built for this kind of day first.
class OccasionLookPicker extends ConsumerWidget {
  const OccasionLookPicker({super.key, this.preferred});

  final String? preferred;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(closetLooksProvider(null));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(DsSpacing.xl),
        child: Center(child: DsLoadingIndicator()),
      ),
      error: (_, _) => DsErrorState(
        message: context.l10n.closetLooksLoadFailed,
        onRetry: () => ref.invalidate(closetLooksProvider),
      ),
      data: (looks) {
        if (looks.isEmpty) {
          return DsEmptyState(
            icon: Icons.auto_awesome_rounded,
            title: context.l10n.closetNoLooksTitle,
            message: context.l10n.occasionNoLooksBody,
            actionLabel: context.l10n.closetSeeWhatToWear,
            onAction: () {
              Navigator.of(context).pop();
              context.push(RoutePaths.closetToday);
            },
          );
        }
        final sorted = [...looks]..sort((a, b) => _rank(a).compareTo(_rank(b)));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final look in sorted) ...[
              ClosetLookCard(
                look: look,
                onTap: () => Navigator.of(context).pop(look.id),
              ),
              DsGaps.vSm,
            ],
          ],
        );
      },
    );
  }

  int _rank(ClosetLook look) =>
      look.occasion != null && look.occasion == preferred ? 0 : 1;
}

/// Her coming bookings, to attach one to this day.
class OccasionAppointmentPicker extends ConsumerWidget {
  const OccasionAppointmentPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAppointmentsProvider('upcoming'));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(DsSpacing.xl),
        child: Center(child: DsLoadingIndicator()),
      ),
      error: (_, _) => DsErrorState(
        message: context.l10n.salonBookingsLoadError,
        onRetry: () => ref.invalidate(myAppointmentsProvider('upcoming')),
      ),
      data: (page) {
        final live = page.items.where((item) => item.status.isLive).toList();
        if (live.isEmpty) {
          return DsEmptyState(
            icon: Icons.event_available_outlined,
            title: context.l10n.salonNoAppointmentsYou,
            message: context.l10n.salonFindAndBook,
            actionLabel: context.l10n.salonBrowseSalons,
            onAction: () {
              Navigator.of(context).pop();
              context.push(RoutePaths.salons);
            },
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final appointment in live) ...[
              AppointmentCard(
                appointment: appointment,
                onTap: () => Navigator.of(context).pop(appointment.id),
              ),
              DsGaps.vSm,
            ],
          ],
        );
      },
    );
  }
}
