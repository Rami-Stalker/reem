import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/courier/domain/entities/courier_assignment.dart';
import 'package:ohara/features/courier/presentation/providers/courier_provider.dart';
import 'package:ohara/features/courier/presentation/widgets/courier_parcel_card.dart';

/// Q55 / Q63 P1 — the courier's round for today.
///
/// Open parcels come first and closed ones sit below: someone opening this
/// standing next to their bike wants the next doorstep, not a record of the
/// morning. Express parcels lead the list because the backend orders them
/// that way, and the card outlines them so the order is visible rather than
/// merely true.
class CourierDayScreen extends ConsumerWidget {
  const CourierDayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(courierDayNotifierProvider);
    final notifier = ref.read(courierDayNotifierProvider.notifier);

    ref.listen(courierDayNotifierProvider.select((s) => s.error), (_, error) {
      if (error == null) return;
      DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      notifier.acknowledge();
    });

    return OharaScrollPage(
      onRefresh: notifier.load,
      slivers: [
        AtelierAppBar(
          icon: Icons.local_shipping_rounded,
          title: l10n.courierDay,
          showBack: true,
        ),
        // Air between the banner and the page.
        DsGaps.sliverMd,

        if (state.isLoading && state.assignments.isEmpty)
          const SliverToBoxAdapter(child: _Skeleton())
        else if (state.assignments.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
              child: DsEmptyState(
                icon: Icons.local_shipping_outlined,
                title: l10n.courierEmptyTitle,
                message: l10n.courierEmptyBody,
              ),
            ),
          )
        else ...[
          if (state.open.isNotEmpty) ...[
            _header(context, l10n.courierOpen, state.open.length),
            _list(context, ref, state.open, state.busyId),
            const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.xl)),
          ],
          if (state.closed.isNotEmpty) ...[
            _header(context, l10n.courierDone, state.closed.length),
            _list(context, ref, state.closed, state.busyId),
          ],
        ],

        DsGaps.sliverBottomSafe,
      ],
    );
  }

  Widget _header(BuildContext context, String title, int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.lg,
          DsSpacing.xxxs,
          DsSpacing.lg,
          DsSpacing.md,
        ),
        child: Row(
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: DsTypography.bold),
            ),
            const SizedBox(width: DsSpacing.xs),
            Text(
              '$count',
              style: context.dsText.body.bold.tint(context.dsColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<CourierAssignment> parcels,
    String? busyId,
  ) {
    final notifier = ref.read(courierDayNotifierProvider.notifier);

    return SliverList.separated(
      itemCount: parcels.length,
      separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.sm),
      itemBuilder: (context, index) {
        final parcel = parcels[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: CourierParcelCard(
            assignment: parcel,
            isBusy: busyId == parcel.id,
            onPickUp: () => notifier.pickUp(parcel.id),
            onStartDelivery: () => notifier.startDelivery(parcel.id),
            onDeliver: () => _confirmDelivery(context, notifier, parcel),
            onFail: () => _recordFailure(context, notifier, parcel),
          ),
        );
      },
    );
  }

  /// Q55 — «يسجّل مبلغ التحصيل».
  Future<void> _confirmDelivery(
    BuildContext context,
    CourierDayNotifier notifier,
    CourierAssignment parcel,
  ) async {
    final result = await showModalBottomSheet<_DeliveryResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeliverySheet(parcel: parcel),
    );
    if (result == null) return;

    await notifier.deliver(
      parcel.id,
      collected: result.collected,
      recipientNote: result.note,
    );
  }

  /// Q55 — «يسجّل سبب فشل التسليم».
  Future<void> _recordFailure(
    BuildContext context,
    CourierDayNotifier notifier,
    CourierAssignment parcel,
  ) async {
    final reason = await showModalBottomSheet<DeliveryFailureReason>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FailureSheet(),
    );
    if (reason == null) return;

    await notifier.fail(parcel.id, reason);
  }
}

class _DeliveryResult {
  const _DeliveryResult({this.collected, this.note});

  final String? collected;
  final String? note;
}

/// Confirms a delivery and records what was actually collected.
///
/// The amount field starts **empty**, not pre-filled with what is due. An
/// empty field means "the full amount", which is both the common case and the
/// honest default — pre-filling it would invite a courier to tap through
/// without looking, and a wrong figure here becomes a variance someone has to
/// chase down later.
class _DeliverySheet extends StatefulWidget {
  const _DeliverySheet({required this.parcel});

  final CourierAssignment parcel;

  @override
  State<_DeliverySheet> createState() => _DeliverySheetState();
}

class _DeliverySheetState extends State<_DeliverySheet> {
  final _collected = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _collected.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    return DsSheetScaffold(
      title: l10n.courierDeliverTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.parcel.isCod) ...[
            Row(
              children: [
                Text(
                  l10n.courierCollect,
                  style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  widget.parcel.codAmount!.format(),
                  style: context.dsText.cardTitle.bold.tint(colors.price),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),
            DsInputField(
              controller: _collected,
              label: l10n.courierCollectedAmount,
              hint: l10n.courierCollectedHint,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              // Money is a decimal string all the way to the ledger; letting a
              // thousands separator or an Arabic-Indic digit through here would
              // reach a Decimal parse that silently truncates.
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
            const SizedBox(height: DsSpacing.md),
          ],
          DsInputField(controller: _note, label: l10n.courierRecipientNote),
          const SizedBox(height: DsSpacing.lg),
          DsButton(
            label: l10n.courierConfirm,
            onPressed: () => Navigator.of(context).pop(
              _DeliveryResult(
                collected: _collected.text.trim().isEmpty
                    ? null
                    : _collected.text.trim(),
                note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Q55 — the reasons a delivery can fail, as the backend enumerates them.
class _FailureSheet extends StatelessWidget {
  const _FailureSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    String label(DeliveryFailureReason reason) => switch (reason) {
      DeliveryFailureReason.noAnswer => l10n.failNoAnswer,
      DeliveryFailureReason.wrongAddress => l10n.failWrongAddress,
      DeliveryFailureReason.customerRefused => l10n.failCustomerRefused,
      DeliveryFailureReason.postponed => l10n.failPostponed,
      DeliveryFailureReason.unreachableArea => l10n.failUnreachableArea,
      DeliveryFailureReason.other => l10n.failOther,
    };

    return DsSheetScaffold(
      title: l10n.courierFailTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final reason in DeliveryFailureReason.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label(reason)),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => Navigator.of(context).pop(reason),
            ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(DsSpacing.lg),
      child: DsShimmer(
        child: Column(
          children: [
            DsSkeleton.box(height: 190, borderRadius: DsRadius.card),
            SizedBox(height: DsSpacing.sm),
            DsSkeleton.box(height: 190, borderRadius: DsRadius.card),
          ],
        ),
      ),
    );
  }
}
