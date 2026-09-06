import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';
import 'package:reem/features/auth/presentation/providers/auth_account_provider.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/utils/auth_form_validators.dart';
import 'package:reem/features/auth/presentation/widgets/step_up_sheet.dart';

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
  Future<void> _elevated(Future<Result<Object?>> Function() action) async {
    setState(() => _busy = true);
    final outcome = await runWithStepUp(context, ref, action: action);
    if (!mounted) return;

    if (outcome.shouldRetry) {
      final retried = await action();
      if (!mounted) return;
      setState(() => _busy = false);
      switch (retried) {
        case Success():
          ref.invalidate(authAccountProvider);
          ref.invalidate(accountSessionsProvider);
        case Error(:final failure):
          _error(failure.message);
      }
      return;
    }

    setState(() => _busy = false);
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
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: data.join('\n')),
                ),
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

  Future<bool> _confirm({required String title, required String body}) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.confirm),
          ),
        ],
      ),
    );
    return answer ?? false;
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
    final colors = context.dsColors;

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: l10n.securityCentre, showBack: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.huge,
            DsSpacing.lg,
            140,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text(
                l10n.securityCentreSubtitle,
                style: context.dsText.body.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DsSpacing.lg),

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

                    const SizedBox(height: DsSpacing.lg),

                    // ── Ways back in ────────────────────────────────────
                    _SectionHeader(title: l10n.recoveryCodes),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.confirmation_number_outlined,
                        color: data.security.hasOfflineRecovery
                            ? colors.success
                            : colors.warning,
                      ),
                      title: Text(
                        l10n.recoveryCodesRemaining(
                          data.security.recoveryCodesRemaining,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: _busy ? null : _generateRecoveryCodes,
                        child: Text(l10n.generateRecoveryCodes),
                      ),
                    ),

                    const SizedBox(height: DsSpacing.lg),

                    // ── Credentials ─────────────────────────────────────
                    _SectionHeader(title: l10n.passwordSignIn),
                    SwitchListTile(
                      value: data.security.passwordEnabled,
                      onChanged: _busy ? null : _togglePassword,
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: colors.primary,
                      title: Text(
                        data.security.passwordEnabled
                            ? l10n.passwordEnabled
                            : l10n.passwordDisabled,
                      ),
                      subtitle: Text(
                        l10n.passwordOnlyOnKnownDevice,
                        style: context.dsText.cardSubtitle.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.phone_iphone_rounded,
                        color: colors.primary,
                      ),
                      title: Text(l10n.changeAccountNumber),
                      subtitle: Text(
                        l10n.changeNumberExplainer,
                        style: context.dsText.cardSubtitle.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(RoutePaths.phoneChange),
                    ),
                    SwitchListTile(
                      value: data.security.mfaEnabled,
                      onChanged: (value) => _toggle(mfaEnabled: value),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: colors.primary,
                      title: Text(l10n.otpOnSensitive),
                      subtitle: Text(l10n.otpOnSensitiveDescription),
                    ),
                    SwitchListTile(
                      value: data.security.deviceVerificationRequired,
                      onChanged: (value) =>
                          _toggle(deviceVerificationRequired: value),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: colors.primary,
                      title: Text(l10n.verifyNewDevices),
                      subtitle: Text(l10n.flagNewDevices),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: DsSpacing.xl),

              // ── Who is signed in ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _SectionHeader(title: l10n.activeSessions)),
                  TextButton.icon(
                    onPressed: _busy ? null : _logoutEverywhere,
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(l10n.signOutEverywhere),
                  ),
                ],
              ),
              const SizedBox(height: DsSpacing.sm),
              sessions.when(
                loading: () => const DsLoadingIndicator(),
                error: (error, _) => Text(messageOf(error)),
                data: (items) {
                  final live = items.where((s) => s.isActive).toList();
                  if (live.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(DsSpacing.lg),
                      child: Text(l10n.noActiveSessions),
                    );
                  }
                  return Column(
                    children: [
                      for (final session in live)
                        _SessionTile(
                          session: session,
                          onRevoke: () => _revokeSession(session.id),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: DsSpacing.xl),

              // ── The handsets that hold a key ──────────────────────────
              _SectionHeader(title: l10n.devices),
              const SizedBox(height: DsSpacing.sm),
              devices.when(
                loading: () => const DsLoadingIndicator(),
                error: (error, _) => Text(messageOf(error)),
                data: (items) {
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(DsSpacing.lg),
                      child: Text(l10n.noDevicesYet),
                    );
                  }
                  return Column(
                    children: [
                      for (final device in items) _DeviceTile(device: device),
                      const SizedBox(height: DsSpacing.sm),
                      SecondaryButton(
                        label: l10n.devices,
                        onPressed: () =>
                            context.push(RoutePaths.deviceManagement),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: DsSpacing.xl),
              GhostButton(
                label: l10n.lostYourSim,
                onPressed: () => context.push(RoutePaths.accountRecovery),
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
    final colors = context.dsColors;
    final completes = openCase.completesAt;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(DsRadius.md),
        border: Border.all(color: colors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.error),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Text(
                  l10n.recoveryCaseOpenWarning,
                  style: context.dsText.tileTitle,
                ),
              ),
            ],
          ),
          if (completes != null) ...[
            const SizedBox(height: DsSpacing.sm),
            Text(
              l10n.recoveryCaseCoolOff(
                _SecuritySettingsScreenState._date(completes),
              ),
              style: context.dsText.cardSubtitle,
            ),
          ],
          const SizedBox(height: DsSpacing.md),
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
    final colors = context.dsColors;
    final (background, foreground) = switch (tone) {
      _NoticeTone.info => (colors.infoContainer, colors.info),
      _NoticeTone.warning => (colors.warningContainer, colors.warning),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: DsSpacing.sm),
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DsRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Text(text, style: context.dsText.cardSubtitle),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onRevoke});

  final AccountSession session;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(DsRadius.md),
        child: ListTile(
          leading: Icon(Icons.key_outlined, color: colors.primary),
          title: Text(session.deviceName ?? context.l10n.unknownDevice),
          subtitle: Text(
            // The absolute clock, not the idle one: "until" is a promise, and
            // the idle clock slides every time she opens the app.
            context.l10n.sessionExpiresOn(
              _SecuritySettingsScreenState._date(session.absoluteExpiresAt),
            ),
            style: context.dsText.cardSubtitle,
          ),
          trailing: IconButton(
            tooltip: context.l10n.revokeSession,
            icon: const Icon(Icons.close),
            onPressed: onRevoke,
          ),
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

  final AccountDevice device;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.smartphone_outlined,
        color: device.isTrusted ? colors.success : colors.onSurfaceVariant,
      ),
      title: Text(device.name),
      subtitle: Text(
        device.isTrusted
            ? context.l10n.deviceTrusted
            : context.l10n.deviceNotVerified,
        style: context.dsText.cardSubtitle.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
