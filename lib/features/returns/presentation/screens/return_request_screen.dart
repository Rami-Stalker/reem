import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_asset.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/returns/domain/entities/return_eligibility.dart';
import 'package:reem/features/returns/presentation/providers/returns_providers.dart';
import 'package:reem/features/seller_returns/domain/entities/return_request.dart';
import 'package:reem/features/seller_returns/presentation/return_labels.dart';

/// The customer's way to send a parcel back.
///
/// `POST /returns`, `GET /returns/eligibility/:id` and the rest of this module
/// shipped with the seller's desk and had no caller on this side: a boutique
/// could approve, refuse and receive a return that no shopper had any way to
/// open. The form asks the server what may go back *before* drawing itself, so
/// a line she cannot return is greyed with the reason rather than accepted and
/// refused after she has chosen a reason and typed a note.
class ReturnRequestScreen extends ConsumerWidget {
  const ReturnRequestScreen({super.key, required this.sellerOrderId});

  final String sellerOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibility = ref.watch(returnEligibilityProvider(sellerOrderId));

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(
          title: context.l10n.returnRequestTitle,
          showBack: true,
          actions: [
            // The rules she is about to be judged by, one tap from the form
            // that applies them. The eligibility card below explains what *her*
            // parcel can do; this explains why.
            IconButton(
              tooltip: context.l10n.policiesLinkReturns,
              onPressed: () =>
                  context.push(RoutePaths.policyDetailOf('returns')),
              icon: const Icon(Icons.help_outline_rounded),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.lg,
            DsSpacing.lg,
            DsSpacing.huge,
          ),
          sliver: SliverToBoxAdapter(
            child: eligibility.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: DsSpacing.xxxl),
                child: DsLoadingIndicator(),
              ),
              error: (error, _) => DsErrorState(
                message: messageOf(error),
                onRetry: () =>
                    ref.invalidate(returnEligibilityProvider(sellerOrderId)),
              ),
              data: (data) => _ReturnForm(eligibility: data),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReturnForm extends ConsumerStatefulWidget {
  const _ReturnForm({required this.eligibility});

  final ReturnEligibility eligibility;

  @override
  ConsumerState<_ReturnForm> createState() => _ReturnFormState();
}

class _ReturnFormState extends ConsumerState<_ReturnForm> {
  ReturnReason _reason = ReturnReason.changedMind;
  final _quantities = <String, int>{};
  final _noteController = TextEditingController();
  List<String> _evidence = const [];
  bool _uploading = false;
  bool _submitting = false;

  ReturnEligibility get _eligibility => widget.eligibility;

  bool get _needsEvidence => _reason.allegesFault;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// Lines this reason actually admits. Changing the reason can retract a line
  /// she had already chosen — a made-to-order dress excluded from a change of
  /// mind — so the selection is filtered through the reason, never trusted on
  /// its own.
  Iterable<ReturnEligibilityLine> get _allowedLines => _eligibility.lines.where(
    (line) => line.allows(isFaultReason: _needsEvidence),
  );

  Map<String, int> get _chosen => {
    for (final line in _allowedLines)
      if ((_quantities[line.orderItemId] ?? 0) > 0)
        line.orderItemId: _quantities[line.orderItemId]!,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    if (!_eligibility.isWindowOpen) {
      return DsEmptyState(
        icon: Icons.event_busy_rounded,
        title: l10n.returnWindowClosed,
      );
    }
    if (!_eligibility.hasReturnableLines) {
      return DsEmptyState(
        icon: Icons.inventory_2_outlined,
        title: l10n.returnNothingReturnable,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WindowNotice(eligibility: _eligibility),
        const SizedBox(height: DsSpacing.lg),

        Text(l10n.returnChooseReason, style: context.dsText.cardTitle),
        const SizedBox(height: DsSpacing.sm),
        Wrap(
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xs,
          children: [
            for (final reason in ReturnReason.values)
              ChoiceChip(
                label: Text(context.returnReasonLabel(reason)),
                selected: _reason == reason,
                onSelected: (_) => setState(() => _reason = reason),
              ),
          ],
        ),

        const SizedBox(height: DsSpacing.lg),
        Text(l10n.returnChooseItems, style: context.dsText.cardTitle),
        const SizedBox(height: DsSpacing.sm),
        for (final line in _eligibility.lines)
          _LineTile(
            line: line,
            isFaultReason: _needsEvidence,
            quantity: _quantities[line.orderItemId] ?? 0,
            onChanged: (value) =>
                setState(() => _quantities[line.orderItemId] = value),
          ),

        if (_needsEvidence) ...[
          const SizedBox(height: DsSpacing.lg),
          // A claim of fault moves money away from a boutique, so the server
          // refuses one that arrives without a photograph. Asking here is the
          // difference between a validation error and a form she can fill in.
          DsMediaField(
            label: l10n.returnEvidenceLabel,
            helperText: l10n.returnEvidenceHelper,
            purpose: MediaPurpose.returnEvidence,
            maxItems: 4,
            enabled: !_submitting,
            onChanged: (urls) => _evidence = urls,
            onUploadingChanged: (busy) => setState(() => _uploading = busy),
          ),
        ],

        const SizedBox(height: DsSpacing.lg),
        DsInputField(
          controller: _noteController,
          maxLines: 3,
          minLines: 3,
          maxLength: 500,
          enabled: !_submitting,
          label: l10n.returnNoteOptional,
        ),

        const SizedBox(height: DsSpacing.lg),
        DsButton(
          label: l10n.returnSubmit,
          isLoading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
        const SizedBox(height: DsSpacing.sm),
        Text(
          l10n.returnPolicy,
          textAlign: TextAlign.center,
          style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final chosen = _chosen;

    if (chosen.isEmpty) {
      DsSnackbar.show(
        context,
        message: l10n.returnSelectAtLeastOne,
        type: DsSnackbarType.warning,
      );
      return;
    }
    if (_uploading) {
      DsSnackbar.show(
        context,
        message: l10n.returnUploadingWait,
        type: DsSnackbarType.warning,
      );
      return;
    }
    if (_needsEvidence && _evidence.isEmpty) {
      DsSnackbar.show(
        context,
        message: l10n.returnEvidenceRequired,
        type: DsSnackbarType.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    final result = await ref
        .read(returnsRepositoryProvider)
        .request(
          sellerOrderId: _eligibility.sellerOrderId,
          reason: _reason,
          reasonNote: _noteController.text,
          evidence: _needsEvidence ? _evidence : null,
          items: [
            for (final entry in chosen.entries)
              (orderItemId: entry.key, quantity: entry.value),
          ],
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (failure) => DsSnackbar.show(
        context,
        message: failure.message,
        type: DsSnackbarType.error,
      ),
      (_) {
        // The parcel's eligibility has changed — those units are claimed now.
        ref.invalidate(returnEligibilityProvider(_eligibility.sellerOrderId));
        ref.invalidate(myReturnsProvider);
        DsSnackbar.show(
          context,
          message: l10n.returnSubmitted,
          type: DsSnackbarType.success,
        );
        Navigator.of(context).pop();
      },
    );
  }
}

/// How long she has, and why it is longer than the policy page says.
class _WindowNotice extends StatelessWidget {
  const _WindowNotice({required this.eligibility});

  final ReturnEligibility eligibility;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final closes = eligibility.windowClosesAt;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            closes == null
                ? l10n.returnRequestTitle
                : l10n.returnWindowUntil(_formatDate(closes)),
            style: context.dsText.body.semibold.tint(colors.onSurface),
          ),
          if (eligibility.extraWindowDays > 0) ...[
            const SizedBox(height: DsSpacing.xxs),
            Text(
              l10n.returnWindowExtraDays(eligibility.extraWindowDays),
              style: context.dsText.bodySmall.tint(colors.primary),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) =>
      '${value.year}/${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}

/// One line, with the count she is sending back.
class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.isFaultReason,
    required this.quantity,
    required this.onChanged,
  });

  final ReturnEligibilityLine line;
  final bool isFaultReason;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final allowed = line.allows(isFaultReason: isFaultReason);
    final blocker = line.blockerFor(isFaultReason: isFaultReason);

    return Opacity(
      opacity: allowed ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.only(bottom: DsSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.title,
                    style: context.dsText.body.tint(colors.onSurface),
                  ),
                  if (line.variant != null)
                    Text(
                      line.variant!,
                      style: context.dsText.bodySmall.tint(
                        colors.onSurfaceVariant,
                      ),
                    ),
                  if (line.quantityClaimed > 0)
                    Text(
                      l10n.returnAlreadyClaimed(line.quantityClaimed),
                      style: context.dsText.bodySmall.tint(
                        colors.onSurfaceVariant,
                      ),
                    ),
                  // The server's own sentence, not a guess at one: it knows
                  // whether this is a made-to-order piece, a hygiene
                  // exclusion, or a window that has passed for this line.
                  if (!allowed && blocker != null)
                    Text(
                      blocker,
                      style: context.dsText.bodySmall.tint(colors.error),
                    ),
                ],
              ),
            ),
            if (allowed)
              _QuantityStepper(
                value: quantity,
                max: line.quantityReturnable,
                onChanged: onChanged,
              ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
          tooltip: context.l10n.returnLineQuantity,
        ),
        Text(
          '$value',
          style: context.dsText.body.semibold.tint(colors.onSurface),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
          tooltip: context.l10n.returnLineQuantity,
        ),
      ],
    );
  }
}
