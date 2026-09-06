import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/utils/auth_form_validators.dart';

/// The last door: her SIM is gone.
///
/// Everything asked for here is something **the platform already holds** —
/// when she joined, what her last order came to, what one of her devices is
/// called. There is deliberately no upload field: a support queue full of
/// selfies and identity documents belonging to women on a women-only platform
/// in Syria is a liability whose worst case is not fraud, and those documents
/// answer the wrong question anyway. What does the work instead is two staff
/// approvals, seventy-two hours during which the number on file is warned, and
/// a week with the money frozen afterwards.
///
/// The screen says all of that out loud, because a recovery flow that looks
/// fast is a recovery flow people try to rush, and this one cannot be rushed.
class AccountRecoveryScreen extends ConsumerStatefulWidget {
  const AccountRecoveryScreen({super.key});

  @override
  ConsumerState<AccountRecoveryScreen> createState() =>
      _AccountRecoveryScreenState();
}

class _AccountRecoveryScreenState
    extends ConsumerState<AccountRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _claimedPhone = TextEditingController();
  final _contactPhone = TextEditingController();
  final _contactCode = TextEditingController();
  final _registrationMonth = TextEditingController();
  final _displayName = TextEditingController();
  final _city = TextEditingController();
  final _lastOrderMonth = TextEditingController();
  final _lastOrderTotal = TextEditingController();
  final _deviceLabel = TextEditingController();

  bool _busy = false;
  bool _codeSent = false;
  RecoveryCaseReceipt? _receipt;

  @override
  void dispose() {
    for (final controller in [
      _claimedPhone,
      _contactPhone,
      _contactCode,
      _registrationMonth,
      _displayName,
      _city,
      _lastOrderMonth,
      _lastOrderTotal,
      _deviceLabel,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The contact number is verified before the case is written, so the review
  /// queue only ever holds cases from someone who is actually reachable.
  Future<void> _sendContactCode() async {
    final phone = _contactPhone.text.trim();
    if (phone.isEmpty) return;
    setState(() => _busy = true);
    final challenge = await ref
        .read(authNotifierProvider.notifier)
        .requestOtp(phone: phone, purpose: OtpPurpose.accountRecovery);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _codeSent = challenge != null;
    });
    if (challenge == null) {
      final error = ref.read(authNotifierProvider).error;
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final result = await ref
        .read(authRepositoryProvider)
        .submitRecoveryCase(
          claimedPhone: _claimedPhone.text.trim(),
          contactPhone: _contactPhone.text.trim(),
          contactCode: _contactCode.text.trim(),
          registrationMonth: _emptyToNull(_registrationMonth.text),
          displayName: _emptyToNull(_displayName.text),
          city: _emptyToNull(_city.text),
          lastOrderMonth: _emptyToNull(_lastOrderMonth.text),
          lastOrderTotal: double.tryParse(_lastOrderTotal.text.trim()),
          deviceLabel: _emptyToNull(_deviceLabel.text),
        );

    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Success(:final data):
        setState(() => _receipt = data);
      case Error(:final failure):
        DsSnackbar.show(
          context,
          message: failure.message,
          type: DsSnackbarType.error,
        );
    }
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final receipt = _receipt;

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: l10n.lostYourSim, showBack: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.huge,
            DsSpacing.lg,
            120,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              receipt != null
                  ? [_Receipt(receipt: receipt)]
                  : [
                      Text(
                        l10n.lostSimExplainer,
                        style: context.dsText.body,
                      ),
                      const SizedBox(height: DsSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(DsSpacing.md),
                        decoration: BoxDecoration(
                          color: colors.infoContainer,
                          borderRadius: BorderRadius.circular(DsRadius.md),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined, color: colors.info),
                            const SizedBox(width: DsSpacing.sm),
                            Expanded(
                              child: Text(
                                l10n.recoveryNoDocuments,
                                style: context.dsText.cardSubtitle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DsSpacing.xl),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DsInputField(
                              controller: _claimedPhone,
                              label: l10n.phone,
                              // l10n-ignore: a dialling mask, not language
                              hint: '09XX XXX XXX',
                              keyboardType: TextInputType.phone,
                              validator: (value) =>
                                  AuthFormValidators.requiredPhone(
                                    l10n,
                                    value,
                                  ),
                            ),
                            const SizedBox(height: DsSpacing.md),
                            DsInputField(
                              controller: _contactPhone,
                              label: l10n.recoveryContactNumber,
                              keyboardType: TextInputType.phone,
                              validator: (value) =>
                                  AuthFormValidators.requiredPhone(
                                    l10n,
                                    value,
                                  ),
                            ),
                            const SizedBox(height: DsSpacing.sm),
                            SecondaryButton(
                              label: _codeSent
                                  ? l10n.resendCode
                                  : l10n.sendCode,
                              onPressed: _busy ? null : _sendContactCode,
                            ),
                            const SizedBox(height: DsSpacing.md),
                            DsInputField(
                              controller: _contactCode,
                              label: l10n.verificationCode,
                              keyboardType: TextInputType.number,
                              autofillHints: const [
                                AutofillHints.oneTimeCode,
                              ],
                              validator: (value) =>
                                  (value == null || value.trim().length < 4)
                                  ? l10n.enterVerificationCode
                                  : null,
                            ),
                            const SizedBox(height: DsSpacing.xl),
                            Text(
                              l10n.recoveryQuestionsTitle,
                              style: context.dsText.cardTitle,
                            ),
                            const SizedBox(height: DsSpacing.xs),
                            Text(
                              l10n.recoveryQuestionsHint,
                              style: context.dsText.cardSubtitle
                                  .copyWith(color: colors.onSurfaceVariant),
                            ),
                            const SizedBox(height: DsSpacing.md),
                            DsInputField(
                              controller: _registrationMonth,
                              label: l10n.recoveryRegistrationMonth,
                              hint: '2025-03',
                            ),
                            const SizedBox(height: DsSpacing.md),
                            DsInputField(
                              controller: _displayName,
                              label: l10n.fullName,
                            ),
                            const SizedBox(height: DsSpacing.md),
                            DsInputField(
                              controller: _city,
                              label: l10n.city,
                            ),
                            const SizedBox(height: DsSpacing.md),
                            DsInputField(
                              controller: _lastOrderMonth,
                              label: l10n.recoveryLastOrderMonth,
                              hint: '2026-01',
                            ),
                            const SizedBox(height: DsSpacing.md),
                            DsInputField(
                              controller: _lastOrderTotal,
                              label: l10n.recoveryLastOrderTotal,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: DsSpacing.md),
                            DsInputField(
                              controller: _deviceLabel,
                              label: l10n.recoveryDeviceLabel,
                            ),
                            const SizedBox(height: DsSpacing.xl),
                            PrimaryButton(
                              label: l10n.send,
                              onPressed: _busy ? null : _submit,
                              isLoading: _busy,
                            ),
                          ],
                        ),
                      ),
                    ],
            ),
          ),
        ),
      ],
    );
  }
}

/// What she leaves with: a reference she cannot recover if she loses it.
///
/// It is copyable and stated plainly, because she has no account to log into
/// and check the case from — that is the entire premise of being here.
class _Receipt extends StatelessWidget {
  const _Receipt({required this.receipt});

  final RecoveryCaseReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 48, color: colors.primary),
        const SizedBox(height: DsSpacing.lg),
        Text(
          l10n.recoverySubmitted,
          textAlign: TextAlign.center,
          style: context.dsText.screenTitle,
        ),
        const SizedBox(height: DsSpacing.sm),
        Text(
          receipt.message,
          textAlign: TextAlign.center,
          style: context.dsText.body,
        ),
        const SizedBox(height: DsSpacing.xl),
        Container(
          padding: const EdgeInsets.all(DsSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(DsRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.recoveryKeepSecret,
                style: context.dsText.cardSubtitle,
              ),
              const SizedBox(height: DsSpacing.sm),
              SelectableText(
                receipt.claimSecret,
                style: context.dsText.cardSubtitle.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: DsSpacing.sm),
              SecondaryButton(
                label: l10n.copy,
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: receipt.claimSecret),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
