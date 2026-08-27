import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';
import 'package:reem/features/auth/presentation/providers/auth_account_provider.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/utils/auth_form_validators.dart';
import 'package:reem/features/auth/presentation/widgets/step_up_sheet.dart';

/// Moving the account to a different number.
///
/// Three steps, shown as three, because the middle one is the whole security
/// property and hiding it would make it look like a mistake. She proves the
/// number she is *leaving* first — the half a SIM swapper cannot produce — and
/// only then does any code go to the number she is moving to.
///
/// The screen is resumable: `pendingPhoneChange` restores a half-finished
/// change after an app restart, because a woman who closed the app between the
/// two codes should not have to start over and burn another pair of messages.
class PhoneChangeScreen extends ConsumerStatefulWidget {
  const PhoneChangeScreen({super.key});

  @override
  ConsumerState<PhoneChangeScreen> createState() => _PhoneChangeScreenState();
}

class _PhoneChangeScreenState extends ConsumerState<PhoneChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPhoneController = TextEditingController();
  final _codeController = TextEditingController();

  PhoneChangeRequest? _request;
  bool _busy = false;
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  @override
  void dispose() {
    _newPhoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final result = await ref.read(authRepositoryProvider).pendingPhoneChange();
    if (!mounted) return;
    setState(() {
      _restoring = false;
      if (result case Success(:final data)) _request = data;
    });
  }

  Future<void> _run(Future<Result<Object?>> Function() action) async {
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result case Error(:final failure)) {
      DsSnackbar.show(
        context,
        message: failure.message,
        type: DsSnackbarType.error,
      );
    }
  }

  Future<void> _start() async {
    if (!_formKey.currentState!.validate()) return;
    final newPhone = _newPhoneController.text.trim();
    action() =>
        ref.read(authRepositoryProvider).startPhoneChange(newPhone: newPhone);

    setState(() => _busy = true);
    // Moving the number is AAL3, so the first attempt usually comes back asking
    // her to prove it is her. That is a step in the journey, not an error.
    final outcome = await runWithStepUp(context, ref, action: action);
    if (!mounted) return;
    if (!outcome.shouldRetry) {
      setState(() => _busy = false);
      if (outcome.message != null) {
        DsSnackbar.show(
          context,
          message: outcome.message!,
          type: DsSnackbarType.error,
        );
      }
      return;
    }

    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Success(:final data):
        setState(() {
          _request = data;
          _codeController.clear();
        });
      case Error(:final failure):
        _stepUpAwareError(failure.code, failure.message);
    }
  }

  Future<void> _verifyCurrent() async {
    final request = _request;
    if (request == null) return;
    setState(() => _busy = true);
    final result = await ref
        .read(authRepositoryProvider)
        .verifyCurrentPhone(
          requestId: request.id,
          code: _codeController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Success(:final data):
        setState(() {
          _request = data;
          _codeController.clear();
        });
      case Error(:final failure):
        _stepUpAwareError(failure.code, failure.message);
    }
  }

  Future<void> _confirm() async {
    final request = _request;
    if (request == null) return;
    setState(() => _busy = true);
    final result = await ref
        .read(authRepositoryProvider)
        .confirmPhoneChange(
          requestId: request.id,
          code: _codeController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case Success(:final data):
        ref.invalidate(authAccountProvider);
        await ref.read(authNotifierProvider.notifier).refreshUser();
        if (!mounted) return;
        setState(() => _request = null);
        DsSnackbar.show(
          context,
          message: context.l10n.numberChanged,
          type: DsSnackbarType.success,
        );
        if (data != null) {
          // Not a warning she can act on, but one she must not be surprised
          // by: a seller who tries to withdraw tomorrow needs to know today.
          DsSnackbar.show(
            context,
            message: context.l10n.payoutsFrozenUntil(
              _formatDate(context, data),
            ),
            type: DsSnackbarType.info,
          );
        }
      case Error(:final failure):
        _stepUpAwareError(failure.code, failure.message);
    }
  }

  Future<void> _cancel() async {
    final request = _request;
    if (request == null) return;
    await _run(
      () => ref.read(authRepositoryProvider).cancelPhoneChange(request.id),
    );
    if (!mounted) return;
    setState(() => _request = null);
  }

  /// The two refusals that are not really errors get their own words.
  void _stepUpAwareError(String? code, String message) {
    final text = switch (code) {
      'NEW_DEVICE_COOLDOWN' => context.l10n.passwordOnlyOnKnownDevice,
      'STEP_UP_REQUIRED' => context.l10n.verifyToContinue,
      _ => message,
    };
    DsSnackbar.show(context, message: text, type: DsSnackbarType.error);
  }

  static String _formatDate(BuildContext context, DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final request = _request;

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: l10n.changeAccountNumber, showBack: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.huge,
            DsSpacing.lg,
            120,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (_restoring)
                const Center(child: DsLoadingIndicator())
              else if (request == null)
                _StartStep(
                  formKey: _formKey,
                  controller: _newPhoneController,
                  busy: _busy,
                  onSubmit: _start,
                )
              else
                _CodeStep(
                  request: request,
                  controller: _codeController,
                  busy: _busy,
                  onSubmit:
                      request.awaitingCurrent ? _verifyCurrent : _confirm,
                  onCancel: _cancel,
                ),
              const SizedBox(height: DsSpacing.xl),
              Text(
                l10n.changeNumberExplainer,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _StartStep extends StatelessWidget {
  const _StartStep({
    required this.formKey,
    required this.controller,
    required this.busy,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsInputField(
            controller: controller,
            label: context.l10n.newNumberLabel,
            hint: '09XX XXX XXX',
            keyboardType: TextInputType.phone,
            prefixIcon: Icon(Icons.phone_iphone_rounded, color: colors.primary),
            validator: (value) =>
                AuthFormValidators.requiredPhone(context.l10n, value),
          ),
          const SizedBox(height: DsSpacing.lg),
          PrimaryButton(
            label: context.l10n.continueLabel,
            onPressed: busy ? null : onSubmit,
            isLoading: busy,
          ),
        ],
      ),
    );
  }
}

class _CodeStep extends StatelessWidget {
  const _CodeStep({
    required this.request,
    required this.controller,
    required this.busy,
    required this.onSubmit,
    required this.onCancel,
  });

  final PhoneChangeRequest request;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final awaitingCurrent = request.awaitingCurrent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Step 1 of 2 / 2 of 2, so the second code does not read as a repeat
        // of the first one going wrong.
        Text(
          awaitingCurrent ? l10n.currentNumberCode : l10n.newNumberCode,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: DsSpacing.xs),
        Text(
          awaitingCurrent ? request.maskedCurrent : request.maskedNew,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        if (request.challenge?.matchCode != null) ...[
          const SizedBox(height: DsSpacing.md),
          Row(
            children: [
              Text(
                '${l10n.matchCodeLabel}: ',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                request.challenge!.matchCode!,
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
          controller: controller,
          label: l10n.verificationCode,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          prefixIcon: Icon(Icons.password_outlined, color: colors.primary),
        ),
        const SizedBox(height: DsSpacing.lg),
        PrimaryButton(
          label: l10n.continueLabel,
          onPressed: busy ? null : onSubmit,
          isLoading: busy,
        ),
        const SizedBox(height: DsSpacing.sm),
        GhostButton(label: l10n.cancel, onPressed: busy ? null : onCancel),
      ],
    );
  }
}
