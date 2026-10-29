import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/failure_exception.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/auth/domain/entities/auth_account.dart';
import 'package:ohara/features/auth/presentation/providers/auth_account_provider.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/utils/auth_form_validators.dart';
import 'package:ohara/features/auth/presentation/widgets/step_up_sheet.dart';
import 'package:ohara/features/auth/presentation/widgets/totp_enrolment_sheet.dart';

/// The security centre.
///
/// One screen, ordered by urgency rather than by subsystem, because the woman
/// who opens it is usually here for one of three reasons: something is
/// happening to her account right now, she is about to lose her phone, or she
/// wants to know who else is signed in.
///
/// So an open recovery case comes first and cannot be scrolled past — during
/// its cool-off, one tap from her is the whole defence. Then the ways back in
/// (recovery codes, an authenticator), because the moment to set those up is
/// before she needs them. Then the credentials, then the sessions and devices.
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState
    extends ConsumerState<SecuritySettingsScreen> {
  bool _busy = false;

  Future<void> _toggle({
    bool? mfaEnabled,
    bool? deviceVerificationRequired,
  }) async {
    final result = await ref
        .read(authRepositoryProvider)
        .updateSecurity(
          mfaEnabled: mfaEnabled,
          deviceVerificationRequired: deviceVerificationRequired,
        );
    if (!mounted) return;
    switch (result) {
      case Success():
        ref.invalidate(authAccountProvider);
      case Error(:final failure):
        _error(failure.message);
    }
  }

  /// Turning a password on, or off.
  ///
  /// Both directions need a fresh second factor at the server, so a refusal
  /// here is usually "verify it is you" rather than a real failure.
  Future<void> _togglePassword(bool enabled) async {
    if (!enabled) {
      final confirmed = await _confirm(
        title: context.l10n.removePassword,
        body: context.l10n.passwordOptionalHint,
      );
      if (!confirmed || !mounted) return;
      await _elevated(() => ref.read(authRepositoryProvider).removePassword());
      return;
    }

    final password = await _askForNewPassword();
    if (password == null || !mounted) return;
    await _elevated(
      () => ref.read(authRepositoryProvider).setPassword(newPassword: password),
    );
  }

  /// Runs an AAL3 action, and if the server asks her to prove it is her,
  /// collects the factor and runs it again.
  ///
  /// Without this the whole assurance ladder was unreachable from the app: the
  /// server refused with `STEP_UP_REQUIRED`, the screen showed the sentence,
  /// and there was nowhere to actually confirm.
  Future<void> _elevated(
    Future<Result<Object?>> Function() action, {
    Future<void> Function()? onSuccess,
  }) async {
    setState(() => _busy = true);
    final outcome = await runWithStepUp(context, ref, action: action);
    if (!mounted) return;

    if (outcome.shouldRetry) {
      final retried = await action();
      if (!mounted) return;
      setState(() => _busy = false);
      switch (retried) {
        case Success():
          if (onSuccess != null) return onSuccess();
          ref.invalidate(authAccountProvider);
          ref.invalidate(accountSessionsProvider);
        case Error(:final failure):
          _error(failure.message);
      }
      return;
    }

    setState(() => _busy = false);
    if (outcome.outcome == StepUpOutcome.succeeded && onSuccess != null) {
      return onSuccess();
    }
    ref.invalidate(authAccountProvider);
    if (outcome.outcome == StepUpOutcome.blocked && outcome.message != null) {
      _error(outcome.message!);
    }
  }

  Future<String?> _askForNewPassword() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: DsSpacing.lg,
          right: DsSpacing.lg,
          top: DsSpacing.lg,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + DsSpacing.lg,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                sheetContext.l10n.setPassword,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: DsSpacing.xs),
              Text(
                sheetContext.l10n.passwordOnlyOnKnownDevice,
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                  color: sheetContext.dsColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DsSpacing.lg),
              DsInputField(
                controller: controller,
                label: sheetContext.l10n.newPassword,
                obscureText: true,
                autofocus: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) =>
                    AuthFormValidators.strongPassword(sheetContext.l10n, v),
              ),
              const SizedBox(height: DsSpacing.lg),
              PrimaryButton(
                label: sheetContext.l10n.save,
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(sheetContext, controller.text);
                  }
                },
              ),
              const SizedBox(height: DsSpacing.sm),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Ten codes, shown once. A fresh set silently cancels the previous one, so
  /// she is told that before it happens and shown them in a dialog she has to
  /// dismiss deliberately.
  Future<void> _enrolTotp() async {
    setState(() => _busy = true);
    final ok = await showTotpEnrolment(context, ref);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      DsSnackbar.show(
        context,
        message: context.l10n.totpConfirmed,
        type: DsSnackbarType.success,
      );
    }
  }

  Future<void> _generateRecoveryCodes() async {
    final confirmed = await _confirm(
      title: context.l10n.generateRecoveryCodes,
      body: context.l10n.recoveryCodesWarning,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    var result = await ref.read(authRepositoryProvider).generateRecoveryCodes();
    if (!mounted) return;

    // Generating a set is AAL3 — a fresh set silently cancels the old one, so
    // an intruder who could regenerate would lock the owner out of her own
    // fallback while handing herself a new one.
    if (result case Error(failure: final f) when f.code == 'STEP_UP_REQUIRED') {
      final outcome = await runWithStepUp(
        context,
        ref,
        action: () => ref.read(authRepositoryProvider).generateRecoveryCodes(),
      );
      if (!mounted) return;
      if (!outcome.shouldRetry) {
        setState(() => _busy = false);
        if (outcome.message != null) _error(outcome.message!);
        return;
      }
      result = await ref.read(authRepositoryProvider).generateRecoveryCodes();
      if (!mounted) return;
    }
    setState(() => _busy = false);

    switch (result) {
      case Success(:final data):
        ref.invalidate(authAccountProvider);
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(dialogContext.l10n.recoveryCodes),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(dialogContext.l10n.recoveryCodesWarning),
                  const SizedBox(height: DsSpacing.md),
                  SelectableText(
                    data.join('\n'),
                    // ds-ignore: no-hand-rolled-text-styles -- recovery codes
                    // are read character by character, so they need a
                    // monospaced family the type scale does not carry.
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      height: 1.8,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: data.join('\n'))),
                child: Text(dialogContext.l10n.copy),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(dialogContext.l10n.close),
              ),
            ],
          ),
        );
      case Error(:final failure):
        _error(failure.message);
    }
  }

  Future<void> _cancelRecoveryCase(String caseId) async {
    setState(() => _busy = true);
    final result = await ref
        .read(authRepositoryProvider)
        .cancelRecoveryCase(caseId);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Success():
        ref.invalidate(authAccountProvider);
        DsSnackbar.show(
          context,
          message: context.l10n.recoveryCaseCancelled,
          type: DsSnackbarType.success,
        );
      case Error(:final failure):
        _error(failure.message);
    }
  }

  /// Deleting the account.
  ///
  /// Asks the server first whether anything is in the way — an order on its
  /// way, money still owed to her — so she is never sent through a second
  /// factor only to be refused at the end. Then the plain-language account of
  /// what goes and what stays, then the step-up, then she is signed out here.
  Future<void> _deleteAccount() async {
    final repository = ref.read(authRepositoryProvider);
    setState(() => _busy = true);
    final status = await repository.accountDeletionStatus();
    if (!mounted) return;
    setState(() => _busy = false);

    switch (status) {
      case Error(:final failure):
        _error(failure.message);
        return;
      case Success(:final data) when !data.canDelete:
        await DsDialog.alert(
          context,
          title: context.l10n.deleteAccountBlockedTitle,
          message: [
            for (final blocker in data.blockers) '• ${_blockerText(blocker)}',
            context.l10n.deleteAccountBlockedHint,
          ].join('\n'),
          icon: Icons.info_outline,
          tone: DsDialogTone.warning,
        );
        return;
      case Success():
        break;
    }
    if (!mounted) return;

    final confirmed = await DsDialog.confirm(
      context,
      title: context.l10n.deleteAccountConfirmTitle,
      message: context.l10n.deleteAccountConfirmBody,
      confirmLabel: context.l10n.deleteAccountConfirmButton,
      icon: Icons.delete_forever_outlined,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await _elevated(
      () => ref.read(authRepositoryProvider).deleteAccount(),
      onSuccess: _afterDeletion,
    );
  }

  /// The server has already ended every session; this forgets the local one
  /// and leaves the screens that only exist for a signed-in account.
  Future<void> _afterDeletion() async {
    DsSnackbar.show(
      context,
      message: context.l10n.accountDeleted,
      type: DsSnackbarType.success,
    );
    final auth = ref.read(authNotifierProvider.notifier);
    context.go(RoutePaths.home);
    await auth.logout();
  }

  String _blockerText(AccountDeletionBlocker blocker) {
    final l10n = context.l10n;
    return switch (blocker.code) {
      'STAFF_ACCOUNT' => l10n.deletionBlockerStaff,
      'OPEN_ORDERS' => l10n.deletionBlockerOpenOrders(blocker.count),
      'OPEN_SALES' => l10n.deletionBlockerOpenSales(blocker.count),
      'WALLET_BALANCE' => l10n.deletionBlockerWallet,
      'PENDING_PAYOUTS' => l10n.deletionBlockerPayouts(blocker.count),
      'UPCOMING_APPOINTMENTS' => l10n.deletionBlockerAppointments(
        blocker.count,
      ),
      _ => l10n.deleteAccountBlockedHint,
    };
  }

  /// Cutting every other session is AAL3: it is the intruder's best move as
  /// much as the owner's.
  Future<void> _logoutEverywhere() async {
    await _elevated(() => ref.read(authRepositoryProvider).logoutAll());
    if (!mounted) return;
    DsSnackbar.show(
      context,
      message: context.l10n.otherSessionsEnded,
      type: DsSnackbarType.success,
    );
  }

  Future<void> _revokeSession(String id) async {
    final result = await ref.read(authRepositoryProvider).revokeSession(id);
    if (!mounted) return;
    switch (result) {
      case Success():
        ref.invalidate(accountSessionsProvider);
      case Error(:final failure):
        _error(failure.message);
    }
  }

  Future<bool> _confirm({required String title, required String body}) {
    return DsDialog.confirm(
      context,
      title: title,
      message: body,
      confirmLabel: context.l10n.confirm,
    );
  }

  void _error(String message) {
    DsSnackbar.show(context, message: message, type: DsSnackbarType.error);
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final account = ref.watch(authAccountProvider);
    final sessions = ref.watch(accountSessionsProvider);
    final devices = ref.watch(accountDevicesProvider);
    final palette = context.boutique;
    final gutter = vanityGutter(context);

    return OharaScrollPage(
      slivers: [
        VanityAppBar(
          title: l10n.securityCentre,
          subtitle: l10n.securityCentreSubtitle,
          icon: Icons.shield_outlined,
          showBack: true,
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, DsSpacing.xl, gutter, 140),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              account.when(
                loading: () => const DsLoadingIndicator(),
                error: (error, _) => Text(messageOf(error)),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── The live threat, first and unmissable ────────────
                    for (final openCase in data.openRecoveryCases)
                      Padding(
                        padding: const EdgeInsets.only(bottom: DsSpacing.md),
                        child: _RecoveryCaseAlert(
                          openCase: openCase,
                          busy: _busy,
                          onStop: () => _cancelRecoveryCase(openCase.caseId),
                        ),
                      ),

                    if (data.security.payoutsFrozen)
                      _Notice(
                        icon: Icons.account_balance_wallet_outlined,
                        tone: _NoticeTone.warning,
                        text: l10n.payoutsFrozenUntil(
                          _date(data.security.payoutFrozenUntil!),
                        ),
                      ),
                    if (data.security.inNewDeviceCooldown)
                      _Notice(
                        icon: Icons.hourglass_bottom_rounded,
                        tone: _NoticeTone.info,
                        text: l10n.newDeviceCooldown(
                          _date(data.security.newDeviceCooldownUntil!),
                        ),
                      ),

                    // ── Ways back in ────────────────────────────────────
                    VanityTray(
                      title: l10n.recoveryCodes,
                      children: [
                        VanityRow(
                          icon: Icons.confirmation_number_outlined,
                          color: data.security.hasOfflineRecovery
                              ? palette.positive
                              : palette.caution,
                          tintTitle: false,
                          title: l10n.recoveryCodesRemaining(
                            data.security.recoveryCodesRemaining,
                          ),
                          trailing: TextButton(
                            onPressed: _busy ? null : _generateRecoveryCodes,
                            child: Text(l10n.generateRecoveryCodes),
                          ),
                        ),
                      ],
                    ),
                    DsGaps.vXl,

                    // ── An authenticator app ────────────────────────────
                    // The server has answered `totp_enabled` and
                    // `totp_required` on every account payload since Identity
                    // v2, and the client parsed both and drew neither — so an
                    // account *required* to hold an authenticator had no way
                    // to enrol one.
                    VanityTray(
                      title: l10n.totpTitle,
                      children: [
                        VanityRow(
                          icon: Icons.smartphone_rounded,
                          color: data.security.totpEnabled
                              ? palette.positive
                              : data.security.totpRequired
                              ? palette.caution
                              : palette.muted,
                          tintTitle: false,
                          title: data.security.totpEnabled
                              ? l10n.totpEnabled
                              : l10n.totpDisabled,
                          subtitle:
                              data.security.totpRequired &&
                                  !data.security.totpEnabled
                              ? l10n.totpRequired
                              : null,
                          trailing: data.security.totpEnabled
                              ? Icon(
                                  Icons.verified_rounded,
                                  color: palette.positive,
                                )
                              : TextButton(
                                  onPressed: _busy ? null : _enrolTotp,
                                  child: Text(l10n.totpEnrol),
                                ),
                        ),
                      ],
                    ),
                    DsGaps.vXl,

                    // ── Credentials ─────────────────────────────────────
                    VanityTray(
                      title: l10n.passwordSignIn,
                      children: [
                        VanityRow(
                          icon: Icons.password_rounded,
                          title: data.security.passwordEnabled
                              ? l10n.passwordEnabled
                              : l10n.passwordDisabled,
                          subtitle: l10n.passwordOnlyOnKnownDevice,
                          trailing: PearlSwitch(
                            value: data.security.passwordEnabled,
                            onChanged: _busy ? null : _togglePassword,
                            semanticLabel: l10n.passwordSignIn,
                          ),
                        ),
                        VanityRow(
                          icon: Icons.phone_iphone_rounded,
                          title: l10n.changeAccountNumber,
                          subtitle: l10n.changeNumberExplainer,
                          onTap: () => context.push(RoutePaths.phoneChange),
                        ),
                        VanityRow(
                          icon: Icons.sms_outlined,
                          title: l10n.otpOnSensitive,
                          subtitle: l10n.otpOnSensitiveDescription,
                          trailing: PearlSwitch(
                            value: data.security.mfaEnabled,
                            onChanged: (value) => _toggle(mfaEnabled: value),
                            semanticLabel: l10n.otpOnSensitive,
                          ),
                        ),
                        VanityRow(
                          icon: Icons.phonelink_lock_outlined,
                          title: l10n.verifyNewDevices,
                          subtitle: l10n.flagNewDevices,
                          trailing: PearlSwitch(
                            value: data.security.deviceVerificationRequired,
                            onChanged: (value) =>
                                _toggle(deviceVerificationRequired: value),
                            semanticLabel: l10n.verifyNewDevices,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              DsGaps.vXl,

              // ── Who is signed in ──────────────────────────────────────
              VanityTray(
                title: l10n.activeSessions,
                children: [
                  ...sessions.when(
                    loading: () => const [
                      Padding(
                        padding: DsSpacing.paddingLg,
                        child: DsLoadingIndicator(),
                      ),
                    ],
                    error: (error, _) => [
                      Padding(
                        padding: DsSpacing.paddingLg,
                        child: Text(messageOf(error)),
                      ),
                    ],
                    data: (items) {
                      final live = items.where((s) => s.isActive).toList();
                      if (live.isEmpty) {
                        return [
                          Padding(
                            padding: DsSpacing.paddingLg,
                            child: Text(
                              l10n.noActiveSessions,
                              style: context.dsText.body.tint(palette.muted),
                            ),
                          ),
                        ];
                      }
                      return [
                        for (final session in live)
                          _SessionTile(
                            session: session,
                            onRevoke: () => _revokeSession(session.id),
                          ),
                      ];
                    },
                  ),
                  VanityRow(
                    icon: Icons.logout,
                    color: palette.critical,
                    title: l10n.signOutEverywhere,
                    showChevron: false,
                    onTap: _busy ? null : _logoutEverywhere,
                  ),
                ],
              ),

              DsGaps.vXl,

              // ── The handsets that hold a key ──────────────────────────
              VanityTray(
                title: l10n.devices,
                children: [
                  ...devices.when(
                    loading: () => const [
                      Padding(
                        padding: DsSpacing.paddingLg,
                        child: DsLoadingIndicator(),
                      ),
                    ],
                    error: (error, _) => [
                      Padding(
                        padding: DsSpacing.paddingLg,
                        child: Text(messageOf(error)),
                      ),
                    ],
                    data: (items) => [
                      if (items.isEmpty)
                        Padding(
                          padding: DsSpacing.paddingLg,
                          child: Text(
                            l10n.noDevicesYet,
                            style: context.dsText.body.tint(palette.muted),
                          ),
                        ),
                      for (final device in items) _DeviceTile(device: device),
                      if (items.isNotEmpty)
                        VanityRow(
                          icon: Icons.tune_rounded,
                          title: l10n.devices,
                          onTap: () =>
                              context.push(RoutePaths.deviceManagement),
                        ),
                    ],
                  ),
                ],
              ),

              DsGaps.vXl,
              VanityTray(
                children: [
                  VanityRow(
                    icon: Icons.sim_card_alert_outlined,
                    title: l10n.lostYourSim,
                    onTap: () => context.push(RoutePaths.accountRecovery),
                  ),
                ],
              ),

              // ── Leaving ───────────────────────────────────────────────
              // Last, and on its own: the one control on the screen that
              // cannot be undone.
              DsGaps.vHuge,
              Container(
                decoration: BoxDecoration(
                  borderRadius: DsRadius.borderXxl,
                  border: Border.all(
                    color: palette.critical.withValues(alpha: 0.35),
                  ),
                ),
                child: VanityRow(
                  icon: Icons.delete_forever_outlined,
                  color: palette.critical,
                  title: l10n.deleteAccount,
                  subtitle: l10n.deleteAccountSubtitle,
                  onTap: _busy ? null : _deleteAccount,
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

/// The banner that stops a hand-over.
///
/// Deliberately loud and deliberately at the top: during the 72-hour cool-off
/// this one button is the difference between her keeping the account and
/// losing it, and it is the only control in the design that a genuine owner
/// will always be able to reach.
class _RecoveryCaseAlert extends StatelessWidget {
  const _RecoveryCaseAlert({
    required this.openCase,
    required this.busy,
    required this.onStop,
  });

  final OpenRecoveryCase openCase;
  final bool busy;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.boutique;
    final completes = openCase.completesAt;

    return Container(
      padding: DsSpacing.paddingLg,
      decoration: BoxDecoration(
        color: palette.critical.withValues(alpha: 0.1),
        borderRadius: DsRadius.borderXxl,
        border: Border.all(color: palette.critical, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              VanityPearl(
                icon: Icons.warning_amber_rounded,
                color: palette.critical,
              ),
              DsGaps.hMd,
              Expanded(
                child: Text(
                  l10n.recoveryCaseOpenWarning,
                  style: context.dsText.bodyStrong.tint(palette.ink),
                ),
              ),
            ],
          ),
          if (completes != null) ...[
            DsGaps.vSm,
            Text(
              l10n.recoveryCaseCoolOff(
                _SecuritySettingsScreenState._date(completes),
              ),
              style: context.dsText.bodySmall.tint(palette.muted),
            ),
          ],
          DsGaps.vMd,
          PrimaryButton(
            label: l10n.stopThisRequest,
            onPressed: busy ? null : onStop,
          ),
        ],
      ),
    );
  }
}

enum _NoticeTone { info, warning }

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.tone, required this.text});

  final IconData icon;
  final _NoticeTone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final tint = switch (tone) {
      _NoticeTone.info => palette.primary,
      _NoticeTone.warning => palette.caution,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: DsSpacing.lg),
      padding: DsSpacing.paddingMd,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: DsRadius.borderXxl,
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          VanityPearl(icon: icon, color: tint, size: DsSizes.controlSm + 4),
          DsGaps.hMd,
          Expanded(
            child: Text(
              text,
              style: context.dsText.bodySmall.tint(palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onRevoke});

  final AccountSession session;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return VanityRow(
      icon: Icons.key_outlined,
      title: session.deviceName ?? context.l10n.unknownDevice,
      // The absolute clock, not the idle one: "until" is a promise, and the
      // idle clock slides every time she opens the app.
      subtitle: context.l10n.sessionExpiresOn(
        _SecuritySettingsScreenState._date(session.absoluteExpiresAt),
      ),
      trailing: IconButton(
        tooltip: context.l10n.revokeSession,
        icon: Icon(Icons.close_rounded, color: palette.muted),
        onPressed: onRevoke,
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

  final AccountDevice device;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return VanityRow(
      icon: Icons.smartphone_outlined,
      color: device.isTrusted ? palette.positive : palette.muted,
      tintTitle: false,
      title: device.name,
      subtitle: device.isTrusted
          ? context.l10n.deviceTrusted
          : context.l10n.deviceNotVerified,
    );
  }
}
