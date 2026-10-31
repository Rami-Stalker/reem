import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/auth/domain/entities/auth_account.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';

/// The outcome of a refusal the app tried to recover from.
enum StepUpOutcome {
  /// The action went through on the first attempt; nothing was asked of her.
  ///
  /// Distinct from [elevated] because the caller must not run it again. The
  /// two used to share a value, and the first real caller — submitting a
  /// seller application — would have posted it twice.
  succeeded,

  /// She proved it was her. Retry the action.
  elevated,

  /// She backed out.
  cancelled,

  /// Nothing she can do right now — a new-device cooldown, or the challenge
  /// could not be sent. The caller shows [StepUpResult.message] and stops.
  blocked,
}

class StepUpResult {
  const StepUpResult(this.outcome, [this.message]);

  final StepUpOutcome outcome;
  final String? message;

  /// Run the action again — and only then.
  bool get shouldRetry => outcome == StepUpOutcome.elevated;

  bool get didSucceed => outcome == StepUpOutcome.succeeded;
}

/// Turns an AAL3 refusal into a journey instead of a dead end.
///
/// The server refuses a sensitive action with `STEP_UP_REQUIRED` and names the
/// scope; without this the app could only show "confirm it is you" in a
/// snackbar and leave her stuck, because there is no way to *do* that from a
/// snackbar. `runWithStepUp` wraps the action: on that refusal it requests a
/// factor for the named scope, collects it, and reports whether the caller
/// should try again.
///
/// A refusal about the handset's key (`DEVICE_PROOF_REQUIRED`, or
/// `DEVICE_PROOF_INVALID` for a key the server does not know or files under
/// another account) is met by enrolling a fresh key and trying once more —
/// no amount of typing fixes it, but re-enrolment does.
///
/// `NEW_DEVICE_COOLDOWN` is deliberately **not** recoverable here: it is a
/// delay, not a challenge — for the first 24 hours on a handset the platform
/// has just met, the sensitive actions are refused outright, because every
/// second factor a shopper has arrives on the SIM a swapper would be holding,
/// so offering one would defeat the control.
Future<StepUpResult> runWithStepUp(
  BuildContext context,
  WidgetRef ref, {
  required Future<Result<Object?>> Function() action,
}) async {
  var first = await action();
  if (first is Success) return const StepUpResult(StepUpOutcome.succeeded);

  var failure = (first as Error).failure;

  // The server does not recognise this install's key — none was ever saved,
  // the server's record of it is gone, or it is filed under another account
  // that used this phone. Enrolling a fresh key for the signed-in account and
  // trying once more is the whole fix; telling her «sign this with your
  // registered device» was a dead end she could do nothing about.
  if (_needsReenrolment(failure)) {
    final reenrolled = await ref.read(authRepositoryProvider).reenrolDevice();
    if (reenrolled is Success) {
      first = await action();
      if (first is Success) return const StepUpResult(StepUpOutcome.succeeded);
      failure = (first as Error).failure;
    }
  }

  // The request has been awaited, so the screen that asked may already be
  // gone. Everything below reads `context` — for the localisations, and then
  // to raise the second-factor sheet — and doing that on a dead element
  // throws. The server's own message is the honest fallback.
  if (!context.mounted) {
    return StepUpResult(StepUpOutcome.blocked, failure.message);
  }

  switch (failure.code) {
    case 'STEP_UP_REQUIRED':
      break;
    case 'NEW_DEVICE_COOLDOWN':
      final availableAt = _detail(failure, 'available_at');
      return StepUpResult(
        StepUpOutcome.blocked,
        availableAt == null
            ? failure.message
            : context.l10n.newDeviceCooldown(_day(availableAt)),
      );
    default:
      return StepUpResult(StepUpOutcome.blocked, failure.message);
  }

  final scope = _detail(failure, 'scope');
  if (scope == null) {
    return StepUpResult(StepUpOutcome.blocked, failure.message);
  }

  final elevated = await _promptForFactor(context, ref, scope);
  return elevated
      ? const StepUpResult(StepUpOutcome.elevated)
      : const StepUpResult(StepUpOutcome.cancelled);
}

/// A refusal about the handset's key that a fresh key fixes. A *revoked* key
/// is deliberately not one: she, or support, switched that device off.
bool _needsReenrolment(Failure failure) {
  if (failure.code == 'DEVICE_PROOF_REQUIRED') return true;
  if (failure.code != 'DEVICE_PROOF_INVALID') return false;
  final reason = _detail(failure, 'reason');
  return reason == 'unknown_key' || reason == 'foreign_key';
}

/// Requests a factor for [scope] and collects it. True once the session is
/// elevated, so the caller can retry.
Future<bool> _promptForFactor(
  BuildContext context,
  WidgetRef ref,
  String scope,
) async {
  final repository = ref.read(authRepositoryProvider);

  final requested = await repository.requestStepUp(scope);
  if (!context.mounted) return false;
  if (requested case Error(:final failure)) {
    DsSnackbar.show(
      context,
      message: failure.message,
      type: DsSnackbarType.error,
    );
    return false;
  }
  final challenge = (requested as Success<OtpChallenge>).data;

  final code = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    builder: (sheetContext) => _StepUpSheet(challenge: challenge),
  );
  if (code == null || code.isEmpty || !context.mounted) return false;

  final verified = await repository.verifyStepUp(scope: scope, code: code);
  if (!context.mounted) return false;
  if (verified case Error(:final failure)) {
    DsSnackbar.show(
      context,
      message: failure.message,
      type: DsSnackbarType.error,
    );
    return false;
  }
  return true;
}

String? _detail(Failure failure, String key) {
  final value = failure.details?[key];
  return value is String ? value : null;
}

String _day(String iso) {
  final parsed = DateTime.tryParse(iso)?.toLocal();
  if (parsed == null) return iso;
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
}

class _StepUpSheet extends StatefulWidget {
  const _StepUpSheet({required this.challenge});

  final OtpChallenge challenge;

  @override
  State<_StepUpSheet> createState() => _StepUpSheetState();
}

class _StepUpSheetState extends State<_StepUpSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final challenge = widget.challenge;

    return Padding(
      padding: EdgeInsets.only(
        left: DsSpacing.lg,
        right: DsSpacing.lg,
        top: DsSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + DsSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.verifyToContinue, style: context.dsText.sectionTitle),
          const SizedBox(height: DsSpacing.xs),
          Text(
            l10n.codeSentToMasked(challenge.maskedDestination ?? ''),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (challenge.matchCode != null) ...[
            const SizedBox(height: DsSpacing.md),
            Row(
              children: [
                Text(
                  '${l10n.matchCodeLabel}: ',
                  style: context.dsText.cardSubtitle,
                ),
                Text(
                  challenge.matchCode!,
                  style: context.dsText.cardTitle.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: DsSpacing.lg),
          DsInputField(
            controller: _controller,
            label: l10n.verificationCode,
            keyboardType: TextInputType.number,
            autofocus: true,
            autofillHints: const [AutofillHints.oneTimeCode],
            onSubmitted: (value) => Navigator.pop(context, value.trim()),
          ),
          const SizedBox(height: DsSpacing.lg),
          PrimaryButton(
            label: l10n.verify,
            onPressed: () => Navigator.pop(context, _controller.text.trim()),
          ),
          const SizedBox(height: DsSpacing.sm),
        ],
      ),
    );
  }
}
