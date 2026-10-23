import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/salons/presentation/providers/salons_providers.dart';
import 'package:reem/features/salons/presentation/widgets/appointment_card.dart';

/// «حجوزاتي».
///
/// Two tabs rather than four statuses, because that is how she thinks about
/// her own bookings: the ones that are coming, and the ones that have been.
/// The statuses are on the cards, where they belong.
class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: ReemAppBar(
        title: context.l10n.salonMyBookings,
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: context.l10n.salonUpcoming),
            Tab(text: context.l10n.salonPast),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _AppointmentList(filter: 'upcoming'),
          _AppointmentList(filter: 'past'),
        ],
      ),
    );
  }
}

class _AppointmentList extends ConsumerWidget {
  const _AppointmentList({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAppointmentsProvider(filter));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myAppointmentsProvider(filter)),
      child: async.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.salonBookingsLoadError,
          onRetry: () => ref.invalidate(myAppointmentsProvider(filter)),
        ),
        data: (page) => page.items.isEmpty
            ? _Empty(filter: filter)
            : ListView.separated(
                padding: const EdgeInsets.all(DsSpacing.lg),
                itemCount: page.items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: DsSpacing.md),
                itemBuilder: (context, index) {
                  final appointment = page.items[index];
                  return AppointmentCard(
                    appointment: appointment,
                    onTap: () =>
                        context.push(RoutePaths.appointmentOf(appointment.id)),
                  );
                },
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    // A scroll view, so pull-to-refresh still works on an empty list.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: DsSpacing.xxxl),
        DsEmptyState(
          icon: filter == 'upcoming'
              ? Icons.event_available_outlined
              : Icons.history_rounded,
          title: filter == 'upcoming'
              ? context.l10n.salonNoAppointmentsYou
              : context.l10n.salonNoPastAppointments,
          message: filter == 'upcoming'
              ? context.l10n.salonFindAndBook
              : context.l10n.salonPastHere,
          actionLabel: filter == 'upcoming'
              ? context.l10n.salonBrowseSalons
              : null,
          onAction: filter == 'upcoming'
              ? () => context.push(RoutePaths.salons)
              : null,
        ),
      ],
    );
  }
}
