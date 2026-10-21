import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/platform/app_haptics.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/salons/domain/entities/appointment.dart';
import 'package:reem/features/salons/presentation/providers/salons_providers.dart';
import 'package:reem/features/salons/presentation/widgets/appointment_card.dart';

/// «المواعيد» — the salon's own queue.
///
/// Three tabs in the order the work happens: what is waiting on her, what is
/// coming, and what is done. «بانتظار التأكيد» is first because it is the only
/// tab with an obligation in it — a booking nobody confirms is cancelled by
/// the scheduler, and the woman who made it hears nothing until then.
class SalonQueueScreen extends ConsumerStatefulWidget {
  const SalonQueueScreen({super.key});

  @override
  ConsumerState<SalonQueueScreen> createState() => _SalonQueueScreenState();
}

class _SalonQueueScreenState extends ConsumerState<SalonQueueScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final async = ref.watch(mySalonProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: ReemAppBar(
        title: 'المواعيد',
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'بانتظار التأكيد'),
            Tab(text: 'القادمة'),
            Tab(text: 'السابقة'),
          ],
        ),
      ),
      body: async.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: 'ما قدرنا نفتح مواعيدك.',
          onRetry: () => ref.invalidate(mySalonProvider),
        ),
        data: (salon) {
          if (salon == null) {
            return const DsEmptyState(
              icon: Icons.storefront_outlined,
              title: 'ما في صالون بعد',
              message: 'افتحي صالونك أول شي، وبتبلّش تجيك الحجوزات.',
            );
          }
          return TabBarView(
            controller: _tabs,
            children: [
              _Queue(salonId: salon.id, filter: 'pending'),
              _Queue(salonId: salon.id, filter: 'upcoming'),
              _Queue(salonId: salon.id, filter: 'past'),
            ],
          );
        },
      ),
    );
  }
}

class _Queue extends ConsumerWidget {
  const _Queue({required this.salonId, required this.filter});

  final String salonId;
  final String filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (salonId: salonId, filter: filter);
    final async = ref.watch(salonQueueProvider(key));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(salonQueueProvider(key)),
      child: async.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: 'ما قدرنا نجيب المواعيد.',
          onRetry: () => ref.invalidate(salonQueueProvider(key)),
        ),
        data: (page) => page.items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: DsSpacing.xxxl),
                  DsEmptyState(
                    icon: switch (filter) {
                      'pending' => Icons.done_all_rounded,
                      'upcoming' => Icons.event_available_outlined,
                      _ => Icons.history_rounded,
                    },
                    title: switch (filter) {
                      'pending' => 'ما في شي بانتظارك',
                      'upcoming' => 'ما في مواعيد قادمة',
                      _ => 'ما في مواعيد سابقة',
                    },
                    message: switch (filter) {
                      'pending' => 'كل الحجوزات مأكّدة.',
                      'upcoming' => 'أول ما تحجز زبونة بتشوفيها هون.',
                      _ => 'هون بتلاقي المواعيد يلي خلصت.',
                    },
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(DsSpacing.lg),
                itemCount: page.items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: DsSpacing.md),
                itemBuilder: (context, index) {
                  final appointment = page.items[index];
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppointmentCard(
                        appointment: appointment,
                        showCustomer: true,
                        onTap: () => unawaited(
                          context.push(
                            RoutePaths.appointmentOf(appointment.id),
                          ),
                        ),
                      ),
                      // The one action the tab is about, on the card itself.
                      // Opening a booking to confirm it is a step too many
                      // when there are eleven of them waiting.
                      if (appointment.status == AppointmentStatus.pending)
                        _QuickConfirm(appointmentId: appointment.id),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _QuickConfirm extends ConsumerStatefulWidget {
  const _QuickConfirm({required this.appointmentId});

  final String appointmentId;

  @override
  ConsumerState<_QuickConfirm> createState() => _QuickConfirmState();
}

class _QuickConfirmState extends ConsumerState<_QuickConfirm> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: DsSpacing.xs),
      child: DsButton(
        label: 'أكّدي الحجز',
        size: DsButtonSize.sm,
        isLoading: _busy,
        onPressed: () => unawaited(_confirm()),
      ),
    );
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(appointmentActionsProvider)
          .confirm(widget.appointmentId);
      if (!mounted) return;
      AppHaptics.confirm();
      DsSnackbar.success(context, 'تم تأكيد الموعد');
    } catch (_) {
      if (!mounted) return;
      DsSnackbar.error(context, 'ما قدرنا نأكّد. جرّبي مرة تانية.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
