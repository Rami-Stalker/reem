import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_look_card.dart';
import 'package:ohara/features/occasions/domain/entities/occasion.dart';
import 'package:ohara/features/occasions/presentation/providers/occasions_providers.dart';
import 'package:ohara/features/occasions/presentation/widgets/occasion_card.dart';
import 'package:ohara/features/occasions/presentation/widgets/occasion_labels.dart';
import 'package:ohara/features/occasions/presentation/widgets/occasion_pickers.dart';
import 'package:ohara/features/occasions/presentation/widgets/occasion_repeat_warning.dart';
import 'package:ohara/features/salons/domain/entities/appointment.dart';
import 'package:ohara/features/salons/presentation/widgets/appointment_card.dart';

/// One occasion, and getting ready for it.
///
/// Read top to bottom the way she will use it: how long is left, whether the
/// people who will be there have seen this outfit, and then the checklist —
/// the look, what it is missing, the salon, the gift. Every step's state is
/// the server's; this page draws it and offers the one action that moves it.
class OccasionDetailScreen extends ConsumerWidget {
  const OccasionDetailScreen({super.key, required this.occasionId});

  final String occasionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final async = ref.watch(occasionProvider(occasionId));
    final occasion = async.asData?.value;

    return Scaffold(
      backgroundColor: c.background,
      appBar: OharaAppBar(
        title: occasion?.title ?? context.l10n.occasionsTitle,
        actions: [
          if (occasion != null) ...[
            IconButton(
              tooltip: context.l10n.occasionEdit,
              icon: const Icon(Icons.edit_rounded),
              onPressed: () =>
                  context.push(RoutePaths.occasionEditOf(occasion.id)),
            ),
            IconButton(
              tooltip: context.l10n.occasionDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _delete(context, ref, occasion),
            ),
          ],
        ],
      ),
      body: async.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.occasionLoadError,
          onRetry: () => ref.invalidate(occasionProvider(occasionId)),
        ),
        data: (occasion) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(occasionProvider(occasionId)),
          child: ListView(
            padding: const EdgeInsets.all(DsSpacing.md),
            children: [
              _Countdown(occasion: occasion),
              if (occasion.repeats.isNotEmpty) ...[
                DsGaps.vMd,
                OccasionRepeatWarning(occasion: occasion),
              ],
              DsGaps.vLg,
              if (occasion.isPast)
                _PastLook(occasion: occasion)
              else
                _Plan(occasion: occasion),
              if (occasion.note != null) ...[
                DsGaps.vLg,
                Text(
                  context.l10n.occasionNoteLabel,
                  style: context.dsText.sectionTitle,
                ),
                DsGaps.vXs,
                Text(occasion.note!, style: context.dsText.body),
              ],
              DsGaps.bottomSafe,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Occasion occasion,
  ) async {
    final confirmed = await DsDialog.confirm(
      context,
      title: context.l10n.occasionDeleteTitle,
      message: context.l10n.occasionDeleteBody,
      confirmLabel: context.l10n.occasionDelete,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(occasionActionsProvider).remove(occasion.id);
      if (!context.mounted) return;
      context.canPop() ? context.pop() : context.go(RoutePaths.occasions);
    } catch (_) {
      if (!context.mounted) return;
      DsSnackbar.error(context, context.l10n.occasionSaveFailed);
    }
  }
}

// ── The countdown ───────────────────────────────────────────────────────────

class _Countdown extends ConsumerWidget {
  const _Countdown({required this.occasion});

  final Occasion occasion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final l10n = context.l10n;

    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OccasionKindMark(
                kind: occasion.kind,
                muted: occasion.isPast,
                large: true,
              ),
              DsGaps.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      OccasionLabels.countdown(l10n, occasion.daysLeft),
                      style: context.dsText.metric.tint(
                        occasion.isPast ? c.onSurfaceVariant : c.primary,
                      ),
                    ),
                    DsGaps.vXxxs,
                    Text(
                      OccasionLabels.kind(l10n, occasion.kind),
                      style: context.dsText.caption.tint(c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          DsGaps.vMd,
          _Fact(
            icon: Icons.event_rounded,
            text: OccasionLabels.when(l10n, occasion),
          ),
          if (occasion.location != null)
            _Fact(icon: Icons.place_outlined, text: occasion.location!),
          if (occasion.circle != null)
            _Fact(icon: Icons.groups_rounded, text: occasion.circle!),
          if (!occasion.isPast && occasion.totalCount > 0) ...[
            DsGaps.vMd,
            DsMeter(
              value: occasion.progress,
              color: occasion.isReady ? c.success : c.primary,
              semanticLabel: l10n.occasionProgress(
                occasion.doneCount,
                occasion.totalCount,
              ),
            ),
            DsGaps.vXs,
            Text(
              OccasionLabels.nextUp(l10n, occasion),
              style: context.dsText.caption.tint(
                occasion.isReady ? c.success : c.onSurface,
              ),
            ),
          ],
          if (!occasion.isPast) ...[
            DsGaps.vSm,
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: occasion.remindersEnabled,
              onChanged: (value) => _run(
                context,
                () => ref
                    .read(occasionActionsProvider)
                    .setRemindersEnabled(occasion.id, value),
              ),
              title: Text(l10n.occasionReminders, style: context.dsText.body),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.xxs),
      child: Row(
        children: [
          Icon(icon, size: DsSizes.iconSm, color: c.onSurfaceVariant),
          DsGaps.hXs,
          Expanded(child: Text(text, style: context.dsText.body)),
        ],
      ),
    );
  }
}

// ── The plan ────────────────────────────────────────────────────────────────

class _Plan extends ConsumerWidget {
  const _Plan({required this.occasion});

  final Occasion occasion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.occasionPlanTitle,
          style: context.dsText.sectionTitle,
        ),
        DsGaps.vSm,
        for (final step in occasion.steps) ...[
          _StepTile(occasion: occasion, step: step),
          DsGaps.vSm,
        ],
      ],
    );
  }
}

class _StepTile extends ConsumerWidget {
  const _StepTile({required this.occasion, required this.step});

  final Occasion occasion;
  final OccasionStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final l10n = context.l10n;
    final hint = OccasionLabels.stepHint(l10n, step);

    final (IconData icon, Color tint) = switch (step.state) {
      OccasionStepState.done => (Icons.check_circle_rounded, c.success),
      OccasionStepState.waiting => (Icons.hourglass_top_rounded, c.info),
      OccasionStepState.todo =>
        step.urgent
            ? (Icons.error_outline_rounded, c.warning)
            : (Icons.radio_button_unchecked_rounded, c.onSurfaceVariant),
    };

    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: DsSizes.iconMd, color: tint),
              DsGaps.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      OccasionLabels.stepTitle(l10n, step),
                      style: context.dsText.bodyStrong,
                    ),
                    if (hint != null) ...[
                      DsGaps.vXxxs,
                      Text(
                        hint,
                        style: context.dsText.caption.tint(
                          step.urgent ? c.warning : c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (step.manual)
                Checkbox.adaptive(
                  value: step.isDone,
                  onChanged: (value) => _run(
                    context,
                    () => ref
                        .read(occasionActionsProvider)
                        .setStep(occasion.id, step.key, done: value ?? false),
                  ),
                ),
            ],
          ),
          ..._body(context, ref),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final actions = ref.read(occasionActionsProvider);

    switch (step.key) {
      case OccasionStepKey.look:
        final look = occasion.look;
        if (look == null) {
          return [
            DsGaps.vSm,
            DsButton(
              label: l10n.occasionChooseLook,
              icon: Icons.checkroom_rounded,
              variant: DsButtonVariant.tonal,
              size: DsButtonSize.md,
              onPressed: () => _chooseLook(context, ref),
            ),
          ];
        }
        return [
          DsGaps.vSm,
          ClosetLookCard(
            look: look,
            onTap: () => context.push(RoutePaths.closetLookOf(look.id)),
          ),
          DsGaps.vXs,
          Row(
            children: [
              TextButton(
                onPressed: () => _chooseLook(context, ref),
                child: Text(l10n.occasionChangeLook),
              ),
              TextButton(
                onPressed: () =>
                    _run(context, () => actions.setLook(occasion.id, null)),
                child: Text(l10n.occasionRemoveLook),
              ),
            ],
          ),
        ];

      case OccasionStepKey.pieces:
        final look = occasion.look;
        if (look == null) return const [];
        // The look's own page is where its gaps meet the shop — the closet
        // already finds what fills an empty slot, so the occasion sends her
        // there rather than recommending anything itself.
        return [
          DsGaps.vSm,
          DsButton(
            label: l10n.occasionCompleteLook,
            icon: Icons.shopping_bag_outlined,
            variant: DsButtonVariant.tonal,
            size: DsButtonSize.md,
            onPressed: () => context.push(RoutePaths.closetLookOf(look.id)),
          ),
        ];

      case OccasionStepKey.salon:
        final appointment = occasion.appointment;
        if (appointment == null ||
            !appointment.status.isLive &&
                appointment.status != AppointmentStatus.completed) {
          return [
            if (appointment != null) ...[
              DsGaps.vSm,
              Text(
                l10n.occasionSalonCancelled(appointment.salon?.name ?? ''),
                style: context.dsText.caption.tint(context.dsColors.warningInk),
              ),
            ],
            DsGaps.vSm,
            Row(
              children: [
                Expanded(
                  child: DsButton(
                    label: l10n.occasionFindSalon,
                    icon: Icons.content_cut_rounded,
                    variant: DsButtonVariant.tonal,
                    size: DsButtonSize.md,
                    onPressed: () => context.push(RoutePaths.salons),
                  ),
                ),
                DsGaps.hXs,
                Expanded(
                  child: DsButton(
                    label: l10n.occasionLinkBooking,
                    icon: Icons.link_rounded,
                    variant: DsButtonVariant.secondary,
                    size: DsButtonSize.md,
                    onPressed: () => _chooseAppointment(context, ref),
                  ),
                ),
              ],
            ),
          ];
        }
        return [
          DsGaps.vSm,
          AppointmentCard(
            appointment: appointment,
            onTap: () => context.push(RoutePaths.appointmentOf(appointment.id)),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => _run(
                context,
                () => actions.setAppointment(occasion.id, null),
              ),
              child: Text(l10n.occasionUnlinkBooking),
            ),
          ),
        ];

      case OccasionStepKey.gift:
        return const [];
    }
  }

  Future<void> _chooseLook(BuildContext context, WidgetRef ref) async {
    final lookId = await DsBottomSheet.showTitled<String>(
      context,
      title: context.l10n.occasionChooseLook,
      child: OccasionLookPicker(preferred: occasion.lookOccasion),
    );
    if (lookId == null || !context.mounted) return;
    await _run(
      context,
      () => ref.read(occasionActionsProvider).setLook(occasion.id, lookId),
    );
  }

  Future<void> _chooseAppointment(BuildContext context, WidgetRef ref) async {
    final appointmentId = await DsBottomSheet.showTitled<String>(
      context,
      title: context.l10n.occasionLinkBooking,
      child: const OccasionAppointmentPicker(),
    );
    if (appointmentId == null || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(occasionActionsProvider)
          .setAppointment(occasion.id, appointmentId),
    );
  }
}

// ── After the day ───────────────────────────────────────────────────────────

class _PastLook extends StatelessWidget {
  const _PastLook({required this.occasion});

  final Occasion occasion;

  @override
  Widget build(BuildContext context) {
    final look = occasion.look;
    if (look == null) {
      return Text(
        context.l10n.occasionPastNoLook,
        style: context.dsText.caption.tint(context.dsColors.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.occasionPastLookTitle,
          style: context.dsText.sectionTitle,
        ),
        DsGaps.vSm,
        ClosetLookCard(
          look: look,
          onTap: () => context.push(RoutePaths.closetLookOf(look.id)),
        ),
      ],
    );
  }
}

/// One write, with the failure said rather than swallowed.
Future<void> _run(
  BuildContext context,
  Future<Object?> Function() write,
) async {
  try {
    await write();
  } catch (_) {
    if (!context.mounted) return;
    DsSnackbar.error(context, context.l10n.occasionSaveFailed);
  }
}
