import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/utils/relative_time.dart';
import 'package:reem/features/seller_earnings/domain/entities/seller_earnings.dart';
import 'package:reem/features/seller_earnings/presentation/providers/seller_earnings_provider.dart';

/// Asking to be paid — Q69 P1's «طلب سحب الأرباح».
///
/// The screen used to be a statement and nothing else: a seller could watch a
/// figure marked «متاح للسحب» grow and had no way to ask for a piastre of it.
///
/// The card is deliberately careful about one thing. Requesting is not being
/// paid: it creates a request the platform approves, and money leaves only
/// then (Q62 keeps that decision with the general manager). Every word here
/// says so, because a seller who thinks she has been paid will plan around it.
class PayoutRequestCard extends ConsumerWidget {
  const PayoutRequestCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerEarningsNotifierProvider);
    final availability = state.availability;
    if (availability == null) return const SizedBox.shrink();

    final open = availability.openRequest;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: open != null
          ? _OpenRequest(request: open, busy: state.isSubmittingPayout)
          : _Ask(availability: availability, busy: state.isSubmittingPayout),
    );
  }
}

/// Nothing outstanding — the amount, and the button, or the reason there is no
/// button.
class _Ask extends ConsumerWidget {
  const _Ask({required this.availability, required this.busy});

  final PayoutAvailability availability;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.atelier;

    return SellerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.payoutRequestTitle,
            style: context.dsText.tileTitle.bold.tint(palette.ink),
          ),
          const SizedBox(height: DsSpacing.sm),
          Text(
            l10n.payoutClaimable,
            style: context.dsText.caption.tint(palette.muted),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              availability.claimable.format(),
              maxLines: 1,
              softWrap: false,
              style: context.dsText.screenTitle.bold.tint(availability.canRequest ? palette.gold : palette.muted),
            ),
          ),
          if (availability.ordersIncluded > 0)
            Text(
              l10n.payoutFromOrders(availability.ordersIncluded),
              style: context.dsText.caption.tint(palette.muted),
            ),

          const SizedBox(height: DsSpacing.md),
          if (availability.canRequest)
            DsButton(
              label: l10n.payoutRequestAction,
              icon: Icons.account_balance_wallet_outlined,
              isLoading: busy,
              onPressed: busy ? null : () => _confirm(context, ref),
            )
          else
            _Blocked(availability: availability),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await DsBottomSheet.show<bool>(
      context,
      builder: (sheetContext) => DsSheetScaffold(
        title: l10n.payoutRequestConfirm(availability.claimable.format()),
        subtitle: l10n.payoutRequestBlurb,
        child: Column(
          children: [
            DsButton(
              label: l10n.payoutRequestAction,
              icon: Icons.account_balance_wallet_outlined,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: DsSpacing.sm),
            DsButton(
              label: l10n.cancel,
              variant: DsButtonVariant.ghost,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final error = await ref
        .read(sellerEarningsNotifierProvider.notifier)
        .requestPayout();
    if (!context.mounted) return;

    DsSnackbar.show(
      context,
      message: error ?? l10n.payoutRequested,
      type: error == null ? DsSnackbarType.success : DsSnackbarType.error,
    );
  }
}

/// A request already in the queue: what it is worth, where it has got to, and
/// — while nobody has approved it — the way back out.
class _OpenRequest extends ConsumerWidget {
  const _OpenRequest({required this.request, required this.busy});

  final PendingPayout request;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final approved = request.isApproved;

    return SellerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                approved
                    ? Icons.local_shipping_outlined
                    : Icons.hourglass_top_rounded,
                size: 18,
                color: approved ? palette.positive : palette.caution,
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Text(
                  approved ? l10n.payoutApprovedTitle : l10n.payoutPendingTitle,
                  style: context.dsText.tileTitle.bold.tint(palette.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              request.net.format(),
              maxLines: 1,
              softWrap: false,
              style: context.dsText.screenTitle.bold.tint(palette.gold),
            ),
          ),
          if (request.createdAt case final DateTime at)
            Text(
              l10n.payoutRequestedOn(formatCalendarDate(l10n, at)),
              style: context.dsText.caption.tint(palette.muted),
            ),

          if (request.status.isCancellable) ...[
            const SizedBox(height: DsSpacing.md),
            DsButton(
              label: l10n.payoutCancelAction,
              variant: DsButtonVariant.ghost,
              isLoading: busy,
              onPressed: busy ? null : () => _confirmCancel(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await DsBottomSheet.show<bool>(
      context,
      builder: (sheetContext) => DsSheetScaffold(
        title: l10n.payoutCancelConfirm,
        subtitle: l10n.payoutCancelBlurb,
        child: Column(
          children: [
            DsButton(
              label: l10n.payoutCancelAction,
              variant: DsButtonVariant.danger,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: DsSpacing.sm),
            DsButton(
              label: l10n.cancel,
              variant: DsButtonVariant.ghost,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final error = await ref
        .read(sellerEarningsNotifierProvider.notifier)
        .cancelPayout(request.id);
    if (!context.mounted) return;

    DsSnackbar.show(
      context,
      message: error ?? l10n.payoutCancelled,
      type: error == null ? DsSnackbarType.success : DsSnackbarType.error,
    );
  }
}

/// Why there is no button. A grey control with no sentence beside it is the
/// thing a seller writes to support about.
class _Blocked extends StatelessWidget {
  const _Blocked({required this.availability});

  final PayoutAvailability availability;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;

    final message = switch (availability.blockedBy) {
      PayoutBlocker.frozen =>
        availability.frozenUntil == null
            ? l10n.payoutBlockedFrozenNoDate
            : l10n.payoutBlockedFrozen(
                formatCalendarDate(l10n, availability.frozenUntil!),
              ),
      // The open-request case never reaches here; the card shows the request.
      PayoutBlocker.requestOpen => l10n.payoutPendingTitle,
      PayoutBlocker.nothingReleased || null => l10n.payoutBlockedNothing,
    };

    final isFreeze = availability.blockedBy == PayoutBlocker.frozen;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: DsRadius.borderMd,
        border: Border.all(color: palette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isFreeze ? Icons.lock_outline_rounded : Icons.schedule_rounded,
            size: 18,
            color: isFreeze ? palette.caution : palette.muted,
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: context.dsText.labelMedium.tint(palette.muted).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
