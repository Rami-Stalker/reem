import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/auth_account.dart';
import '../providers/auth_provider.dart';

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
/// Two refusals are deliberately **not** recoverable here. `NEW_DEVICE_COOLDOWN`
/// is a delay, not a challenge — for the first 24 hours on a handset the
/// platform has just met, the sensitive actions are refused outright, because
/// every second factor a shopper has arrives on the SIM a swapper would be
/// holding, so offering one would defeat the control. And `DEVICE_PROOF_REQUIRED`
/// means this install has not enrolled a key at all, which no amount of typing
/// fixes.
Future<StepUpResult> runWithStepUp(
  BuildContext context,
  WidgetRef ref, {
  required Future<Result<Object?>> Function() action,
}) async {
  final first = await action();
  if (first is Success) return const StepUpResult(StepUpOutcome.succeeded);

  final failure = (first as Error).failure;
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
  if (scope == null || !context.mounted) {
    return StepUpResult(StepUpOutcome.blocked, failure.message);
  }

  final elevated = await _promptForFactor(context, ref, scope);
  return elevated
      ? const StepUpResult(StepUpOutcome.elevated)
      : const StepUpResult(StepUpOutcome.cancelled);
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
          Text(
            l10n.verifyToContinue,
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  challenge.matchCode!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
