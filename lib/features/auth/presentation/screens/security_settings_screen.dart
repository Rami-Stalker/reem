import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/design_system/components/snackbars/app_snackbar.dart'
    show DsSnackbar, DsSnackbarType;
import 'package:reem/core/result/result.dart';
import 'package:reem/core/router/route_paths.dart';

import '../providers/auth_account_provider.dart';
import '../providers/auth_provider.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  bool _savingPassword = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _toggle({
    bool? mfaEnabled,
    bool? deviceVerificationRequired,
  }) async {
    final result = await ref.read(authRepositoryProvider).updateSecurity(
          mfaEnabled: mfaEnabled,
          deviceVerificationRequired: deviceVerificationRequired,
        );
    if (!mounted) return;
    switch (result) {
      case Success():
        ref.invalidate(authAccountProvider);
      case Error(:final failure):
        DsSnackbar.show(
          context,
          message: failure.message,
          type: DsSnackbarType.error,
        );
    }
  }

  Future<void> _changePassword() async {
    setState(() => _savingPassword = true);
    final result = await ref.read(authRepositoryProvider).changePassword(
          currentPassword: _currentPassword.text.isEmpty
              ? null
              : _currentPassword.text,
          newPassword: _newPassword.text,
        );
    if (!mounted) return;
    setState(() => _savingPassword = false);
    switch (result) {
      case Success():
        _currentPassword.clear();
        _newPassword.clear();
        DsSnackbar.show(
          context,
          message: 'Password changed.',
          type: DsSnackbarType.success,
        );
      case Error(:final failure):
        DsSnackbar.show(
          context,
          message: failure.message,
          type: DsSnackbarType.error,
        );
    }
  }

  Future<void> _logoutEverywhere() async {
    final result = await ref.read(authRepositoryProvider).logoutAll();
    if (!mounted) return;
    switch (result) {
      case Success():
        await ref.read(authNotifierProvider.notifier).logout();
        if (mounted) context.go(RoutePaths.login);
      case Error(:final failure):
        DsSnackbar.show(
          context,
          message: failure.message,
          type: DsSnackbarType.error,
        );
    }
  }

  Future<void> _revokeSession(String id) async {
    final result = await ref.read(authRepositoryProvider).revokeSession(id);
    if (!mounted) return;
    switch (result) {
      case Success():
        ref.invalidate(accountSessionsProvider);
      case Error(:final failure):
        DsSnackbar.show(
          context,
          message: failure.message,
          type: DsSnackbarType.error,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(authAccountProvider);
    final sessions = ref.watch(accountSessionsProvider);
    final colors = context.dsColors;

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: 'Security', showBack: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.huge,
            DsSpacing.lg,
            140,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              account.when(
                loading: () => const DsLoadingIndicator(),
                error: (error, _) => Text(error.toString()),
                data: (data) => Column(
                  children: [
                    SwitchListTile(
                      value: data.security.mfaEnabled,
                      onChanged: (value) => _toggle(mfaEnabled: value),
                      title: const Text('OTP on sensitive actions'),
                      subtitle: const Text('Require an OTP for risky changes.'),
                    ),
                    SwitchListTile(
                      value: data.security.deviceVerificationRequired,
                      onChanged: (value) =>
                          _toggle(deviceVerificationRequired: value),
                      title: const Text('Verify new devices'),
                      subtitle: const Text('Flag new devices for verification.'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DsSpacing.xl),
              Text(
                'Change password',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: DsSpacing.md),
              DsInputField(
                controller: _currentPassword,
                label: 'Current password',
                obscureText: true,
                prefixIcon: Icon(Icons.lock_open_outlined, color: colors.primary),
              ),
              const SizedBox(height: DsSpacing.md),
              DsInputField(
                controller: _newPassword,
                label: 'New password',
                obscureText: true,
                prefixIcon: Icon(Icons.lock_outline, color: colors.primary),
              ),
              const SizedBox(height: DsSpacing.md),
              PrimaryButton(
                label: 'Update password',
                icon: Icons.password_outlined,
                onPressed: _savingPassword ? null : _changePassword,
                isLoading: _savingPassword,
              ),
              const SizedBox(height: DsSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sessions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton.icon(
                    onPressed: _logoutEverywhere,
                    icon: const Icon(Icons.logout),
                    label: const Text('Log out all'),
                  ),
                ],
              ),
              const SizedBox(height: DsSpacing.sm),
              sessions.when(
                loading: () => const DsLoadingIndicator(),
                error: (error, _) => Text(error.toString()),
                data: (items) => Column(
                  children: [
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(DsSpacing.lg),
                        child: Text('No active sessions.'),
                      ),
                    for (final session in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: DsSpacing.sm),
                        child: Material(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(DsRadius.md),
                          child: ListTile(
                            leading: Icon(
                              Icons.key_outlined,
                              color: colors.primary,
                            ),
                            title: Text(session.deviceName ?? 'Unknown device'),
                            subtitle: Text(
                              '${session.status} • ${session.platform ?? 'unknown'}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Revoke session',
                              icon: const Icon(Icons.close),
                              onPressed: () => _revokeSession(session.id),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
