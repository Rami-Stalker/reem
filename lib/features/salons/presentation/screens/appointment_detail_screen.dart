import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/platform/app_haptics.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/chat/domain/entities/chat_start_request.dart';
import 'package:reem/features/chat/presentation/widgets/message_seller_button.dart';
import 'package:reem/features/salons/domain/entities/appointment.dart';
import 'package:reem/features/salons/presentation/providers/salons_providers.dart';
import 'package:reem/features/salons/presentation/widgets/appointment_card.dart';
import 'package:reem/features/salons/presentation/widgets/salon_labels.dart';

/// One booking, in full — and everything either side can do to it.
///
/// The same screen for the customer and for the salon. The server decides who
/// may do what (`can_cancel`, and the salon's own verbs are refused for anyone
/// but its owner), so the screen draws what it is told rather than deciding;
/// a client that adjudicated would eventually offer a button the API refuses.
class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final async = ref.watch(appointmentProvider(appointmentId));

    return Scaffold(
      backgroundColor: c.background,
      appBar: ReemAppBar(
        title: 'تفاصيل الموعد',
        onBack: () => context.canPop()
            ? context.pop()
            : context.go(RoutePaths.appointments),
      ),
      body: async.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: 'ما قدرنا نفتح هالموعد.',
          onRetry: () => ref.invalidate(appointmentProvider(appointmentId)),
        ),
        data: (appointment) => _Body(appointment: appointment),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final me = ref.watch(authNotifierProvider).user?.id;
    // The salon's own copy carries the customer block; hers does not. That is
    // how this screen knows which side is looking at it, without the client
    // deciding anything about permission.
    final isSalonView = appointment.customer != null && appointment.customer!.id != me;
    final when = appointment.startsAt.toLocal();

    return ListView(
      padding: const EdgeInsets.all(DsSpacing.lg),
      children: [
        Center(child: AppointmentStatusBadge(status: appointment.status)),
        DsGaps.vXs,
        Center(
          child: Text(
            SalonLabels.statusHint(appointment.status),
            style: context.dsText.cardSubtitle.tint(c.onSurfaceVariant),
          ),
        ),
        DsGaps.vLg,

        SurfaceCard(
          padding: const EdgeInsets.all(DsSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Row(
                icon: Icons.spa_outlined,
                label: 'الخدمة',
                value: appointment.serviceName,
              ),
              _Row(
                icon: Icons.event_rounded,
                label: 'الموعد',
                value: SalonLabels.dateTime(when),
              ),
              _Row(
                icon: Icons.schedule_rounded,
                label: 'المدة',
                value: SalonLabels.duration(appointment.durationMinutes),
              ),
              _Row(
                icon: Icons.payments_outlined,
                label: 'السعر',
                value: '${appointment.price.format()} — تُدفع بالصالون',
              ),
              _Row(
                icon: Icons.confirmation_number_outlined,
                label: 'رقم الحجز',
                value: appointment.reference,
              ),
              if (isSalonView && appointment.customer != null)
                _Row(
                  icon: Icons.person_outline_rounded,
                  label: 'العميلة',
                  value: appointment.customer!.name,
                ),
              if (appointment.atHome && appointment.address != null)
                _Row(
                  icon: Icons.home_outlined,
                  label: 'خدمة منزلية',
                  value: appointment.address!.oneLine,
                ),
            ],
          ),
        ),

        if (appointment.customerNote != null &&
            appointment.customerNote!.isNotEmpty) ...[
          DsGaps.vMd,
          _Note(title: 'ملاحظة العميلة', body: appointment.customerNote!),
        ],
        if (appointment.salonNote != null &&
            appointment.salonNote!.isNotEmpty) ...[
          DsGaps.vMd,
          _Note(title: 'ملاحظة الصالون', body: appointment.salonNote!),
        ],

        if (appointment.status == AppointmentStatus.cancelled) ...[
          DsGaps.vMd,
          _Note(
            title: SalonLabels.cancelledBy(appointment.cancelledBy),
            body: appointment.cancellationReason ?? '',
            tone: c.error,
          ),
        ],

        DsGaps.vLg,

        // The salon owns its side of the conversation, and she owns hers.
        if (!isSalonView && appointment.salon?.owner != null)
          MessageSellerButton(
            label: 'راسلي الصالون',
            variant: DsButtonVariant.tonal,
            request: ChatStartRequest.peer(
              peerId: appointment.salon!.owner!.id,
            ),
          ),

        if (!isSalonView && appointment.salon != null) ...[
          DsGaps.vSm,
          DsButton(
            label: 'صفحة الصالون',
            icon: Icons.storefront_outlined,
            variant: DsButtonVariant.ghost,
            onPressed: () => unawaited(
              context.push(RoutePaths.salonOf(appointment.salon!.slug)),
            ),
          ),
        ],

        // The salon writes to her through the chat rather than telephoning
        // her: `serializePublicUser` strips the phone number on purpose, and
        // a booking is not a reason to hand a salon a woman's mobile.
        if (isSalonView && appointment.customer != null)
          MessageSellerButton(
            label: 'راسلي العميلة',
            variant: DsButtonVariant.tonal,
            request: ChatStartRequest.peer(peerId: appointment.customer!.id),
          ),

        DsGaps.vLg,
        _Actions(appointment: appointment, isSalonView: isSalonView),
      ],
    );
  }
}

class _Actions extends ConsumerStatefulWidget {
  const _Actions({required this.appointment, required this.isSalonView});

  final Appointment appointment;
  final bool isSalonView;

  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  bool _busy = false;

  Appointment get appointment => widget.appointment;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];

    if (widget.isSalonView) {
      if (appointment.status == AppointmentStatus.pending) {
        actions.add(
          DsButton(
            label: 'أكّدي الحجز',
            isLoading: _busy,
            onPressed: () => _run(
              () => ref
                  .read(appointmentActionsProvider)
                  .confirm(appointment.id),
              'تم تأكيد الموعد',
            ),
          ),
        );
      }
      if (appointment.status.isLive) {
        actions.addAll([
          DsGaps.vSm,
          DsButton(
            label: 'تمّت الزيارة',
            variant: DsButtonVariant.tonal,
            isLoading: _busy,
            onPressed: () => _run(
              () => ref
                  .read(appointmentActionsProvider)
                  .complete(appointment.id),
              'تم تسجيل الزيارة',
            ),
          ),
          DsGaps.vSm,
          DsButton(
            label: 'لم تحضر',
            variant: DsButtonVariant.ghost,
            isLoading: _busy,
            onPressed: () => _run(
              () =>
                  ref.read(appointmentActionsProvider).noShow(appointment.id),
              'تم التسجيل',
            ),
          ),
        ]);
      }
    }

    // `can_cancel` is the server's answer, not the screen's guess.
    if (appointment.canCancel) {
      if (actions.isNotEmpty) actions.add(DsGaps.vSm);
      actions.add(
        DsButton(
          label: 'ألغي الموعد',
          variant: DsButtonVariant.ghost,
          isLoading: _busy,
          onPressed: _confirmCancel,
        ),
      );
    }

    if (appointment.canReview && !widget.isSalonView) {
      if (actions.isNotEmpty) actions.add(DsGaps.vSm);
      actions.add(
        DsButton(
          label: 'قيّمي الصالون',
          icon: Icons.star_rounded,
          isLoading: _busy,
          onPressed: _review,
        ),
      );
    }

    if (appointment.review != null) {
      actions.addAll([
        DsGaps.vSm,
        _Note(
          title: 'تقييمك: ${appointment.review!.rating} ★',
          body: appointment.review!.body ?? '',
        ),
      ]);
    }

    return Column(mainAxisSize: MainAxisSize.min, children: actions);
  }

  Future<void> _confirmCancel() async {
    final salon = appointment.salon;
    final hours = salon?.cancellationHours ?? 4;
    final late =
        appointment.startsAt.difference(DateTime.now()).inHours < hours;

    final confirmed = await DsDialog.confirm(
      context,
      title: 'إلغاء الموعد',
      // Late is said rather than hidden, and it is still allowed: a woman who
      // cannot come cannot come, and the salon needs to know which it was.
      message: late
          ? 'باقي أقل من $hours ساعات على الموعد، فالإلغاء متأخر وبينسجل للصالون. متأكدة؟'
          : 'متأكدة إنك بدك تلغي هالموعد؟',
      confirmLabel: 'ألغي الموعد',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await _run(
      () => ref.read(appointmentActionsProvider).cancel(appointment.id),
      'تم إلغاء الموعد',
    );
  }

  Future<void> _review() async {
    final rating = await showDialog<int>(
      context: context,
      builder: (context) => const _RatingDialog(),
    );
    if (rating == null || !mounted) return;

    await _run(
      () => ref
          .read(appointmentActionsProvider)
          .review(appointment.id, rating: rating),
      'شكراً لتقييمك',
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      AppHaptics.confirm();
      DsSnackbar.success(context, success);
    } catch (_) {
      if (!mounted) return;
      DsSnackbar.error(context, 'ما قدرنا نكمّل. جرّبي مرة تانية.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Stars, and nothing else.
///
/// The written review is optional and deliberately not asked for here: making
/// a woman type before she can rate is how a salon ends up with three reviews.
class _RatingDialog extends StatefulWidget {
  const _RatingDialog();

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _rating = 5;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return AlertDialog(
      backgroundColor: c.surface,
      title: Text(
        'كيف كانت زيارتك؟',
        style: context.dsText.cardTitle.tint(c.onSurface),
      ),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var star = 1; star <= 5; star += 1)
            IconButton(
              onPressed: () => setState(() => _rating = star),
              icon: Icon(
                star <= _rating
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 32,
                color: c.warning,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('لاحقاً'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_rating),
          child: const Text('أرسلي'),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: c.onSurfaceVariant),
          const SizedBox(width: DsSpacing.sm),
          Text(
            label,
            style: context.dsText.caption.tint(c.onSurfaceVariant),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.dsText.body.semibold.tint(c.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.title, required this.body, this.tone});

  final String title;
  final String body;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: DsRadius.borderLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: context.dsText.labelMedium.semibold.tint(tone ?? c.primary),
          ),
          if (body.isNotEmpty) ...[
            DsGaps.vXxs,
            Text(body, style: context.dsText.body.tint(c.onSurface)),
          ],
        ],
      ),
    );
  }
}
